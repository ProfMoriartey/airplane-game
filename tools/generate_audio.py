#!/usr/bin/env python3
"""Synthesises every sound effect and music track in the game from scratch.

Nothing here is sampled or recorded: each sound is built from oscillators,
filtered noise and envelopes, so the results are fully original and safe to
ship. Run it from the project root to (re)build assets/audio:

    python3 tools/generate_audio.py            (every sound and piece of music)
    python3 tools/generate_audio.py gunshot    (only the ones named)

It uses only the Python standard library. Looping sounds get a WAV "smpl"
chunk, which Godot reads as loop points when importing.
"""

import math
import os
import random
import sys
import struct
import wave

RATE = 32000
OUT_SFX = "assets/audio/sfx"
OUT_MUSIC = "assets/audio/music"
TAU = math.tau

rng = random.Random(1914)


# ---------------------------------------------------------------------------
# Basic building blocks
# ---------------------------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def noise(seconds):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def lowpass(samples, cutoff):
    """One-pole low-pass filter. cutoff may be a number or a per-sample list."""
    out = []
    y = 0.0
    if isinstance(cutoff, (int, float)):
        a = 1.0 - math.exp(-TAU * cutoff / RATE)
        for x in samples:
            y += a * (x - y)
            out.append(y)
    else:
        for x, c in zip(samples, cutoff):
            y += (1.0 - math.exp(-TAU * c / RATE)) * (x - y)
            out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def bandpass(samples, low_cut, high_cut):
    return lowpass(highpass(samples, low_cut), high_cut)


def envelope(length, attack, decay_time, curve=4.0):
    """Fast attack, then exponential decay over decay_time seconds."""
    out = []
    attack_samples = max(int(attack * RATE), 1)
    for i in range(length):
        t = i / RATE
        if i < attack_samples:
            out.append(i / attack_samples)
        else:
            out.append(math.exp(-curve * (t - attack) / decay_time))
    return out


def multiply(a, b):
    return [x * y for x, y in zip(a, b)]


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, x in enumerate(track):
            out[i] += x
    return out


def scale(samples, gain):
    return [x * gain for x in samples]


def sine_sweep(seconds, start_hz, end_hz, curve=1.0):
    out = []
    phase = 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = (i / count) ** curve
        phase += TAU * (start_hz + (end_hz - start_hz) * t) / RATE
        out.append(math.sin(phase))
    return out


def normalize(samples, peak=0.89):
    top = max(abs(x) for x in samples) or 1.0
    return [x * peak / top for x in samples]


def fade_edges(samples, fade_in=0.002, fade_out=0.01):
    out = list(samples)
    n_in = int(fade_in * RATE)
    n_out = int(fade_out * RATE)
    for i in range(min(n_in, len(out))):
        out[i] *= i / n_in
    for i in range(min(n_out, len(out))):
        out[-1 - i] *= i / n_out
    return out


def crossfade_loop(samples, overlap_seconds):
    """Makes a sound loop seamlessly by blending its tail into its start."""
    n = int(overlap_seconds * RATE)
    body = samples[:-n]
    tail = samples[-n:]
    for i in range(n):
        w = i / n
        body[i] = body[i] * w + tail[i] * (1.0 - w)
    return body


def reverb(samples, wet=0.25, room=0.82):
    """A small Schroeder reverb: parallel feedback combs into all-pass filters."""
    delays = [1557, 1617, 1491, 1422]
    combs = []
    for delay in delays:
        d = int(delay * RATE / 44100)
        buffer = [0.0] * d
        out = []
        index = 0
        filtered = 0.0
        for x in samples:
            y = buffer[index]
            filtered = y * 0.7 + filtered * 0.3
            buffer[index] = x + filtered * room
            index = (index + 1) % d
            out.append(y)
        combs.append(out)
    wet_signal = [sum(values) * 0.25 for values in zip(*combs)]
    for delay in (225, 556):
        d = int(delay * RATE / 44100)
        buffer = [0.0] * d
        index = 0
        out = []
        for x in wet_signal:
            b = buffer[index]
            y = -x + b
            buffer[index] = x + b * 0.5
            index = (index + 1) % d
            out.append(y)
        wet_signal = out
    return [x * (1.0 - wet) + w * wet for x, w in zip(samples, wet_signal)]


def write_wav(path, samples, loop=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    samples = normalize(samples)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in samples)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)
    if loop:
        # Append a "smpl" chunk with one forward loop over the whole file.
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        with open(path, "r+b") as handle:
            handle.seek(0, 2)
            handle.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = handle.tell()
            handle.seek(4)
            handle.write(struct.pack("<I", size - 8))
    print("  wrote %s (%.1fs)" % (path, len(samples) / RATE))


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def engine_loop():
    """A rotary engine: a train of firing pulses with a rough, uneven rhythm."""
    firing_hz = 55
    pulses = 110  # exactly 2 seconds, so the loop is seamless
    period = RATE // firing_hz
    total = pulses * period
    out = [0.0] * total
    for p in range(pulses):
        strength = 0.75 + 0.25 * rng.random()
        start = p * period
        # Each pulse rings for three firing periods; tails past the end wrap
        # round to the start, so the loop has no seam.
        for i in range(period * 3):
            t = i / RATE
            decay = math.exp(-t * 90.0)
            body = math.sin(TAU * 110 * t) * 0.6 + math.sin(TAU * 230 * t) * 0.3
            out[(start + i) % total] += (body + rng.uniform(-0.5, 0.5)) * decay * strength
    drone = [math.sin(TAU * 27.5 * i / RATE) * 0.35 for i in range(total)]
    # Filter two copies back to back and keep the second, so the filters start
    # already settled and the result still loops cleanly.
    rough = lowpass(out + out, 1600)[total:]
    shaped = mix(rough, drone)
    mean = sum(shaped) / total
    return [x - mean for x in shaped]


def wind_loop():
    base = noise(4.5)
    gusts = [0.7 + 0.3 * math.sin(TAU * i / (4.0 * RATE)) for i in range(len(base))]
    shaped = multiply(bandpass(base, 150, 900), gusts)
    return crossfade_loop(shaped, 0.5)


def gunshot():
    """One round from a WWI machine gun: a deep thump and a mid-range bark give
    it weight (so it carries over the engine), a short crack gives it bite, and
    the action clacks just after. Soft clipping makes it dense and loud."""
    seconds = 0.16
    length = int(seconds * RATE)
    thump = multiply(sine_sweep(seconds, 190, 55), envelope(length, 0.001, 0.07))
    bark = multiply(bandpass(noise(seconds), 250, 1800), envelope(length, 0.0008, 0.045))
    crack = multiply(highpass(noise(seconds), 1800), envelope(length, 0.0004, 0.01))
    delay = int(0.035 * RATE)
    clack = multiply(bandpass(noise(seconds), 2200, 4500), [0.0] * delay + envelope(length - delay, 0.0005, 0.012))
    shot = mix(scale(thump, 1.0), scale(bark, 0.9), scale(crack, 0.45), scale(clack, 0.2))
    return fade_edges(normalize(saturate(shot, 2.2)))


def bullet_hit():
    length = int(0.18 * RATE)
    tick = multiply(highpass(noise(0.18), 2000), envelope(length, 0.0003, 0.008))
    ring = multiply([math.sin(TAU * 2350 * i / RATE) + 0.5 * math.sin(TAU * 3780 * i / RATE) for i in range(length)], envelope(length, 0.0005, 0.06))
    thud = multiply(lowpass(noise(0.18), 400), envelope(length, 0.001, 0.04))
    return fade_edges(mix(tick, scale(ring, 0.35), scale(thud, 0.8)))


def whizz():
    length = int(0.4 * RATE)
    cutoff = [3500 - 2500 * i / length for i in range(length)]
    swoosh = lowpass(highpass(noise(0.4), 700), cutoff)
    shape = [math.sin(math.pi * i / length) ** 2 for i in range(length)]
    return fade_edges(multiply(swoosh, shape))


def saturate(samples, drive):
    """Soft clipping: makes a sound denser and louder without harsh distortion."""
    return [math.tanh(x * drive) for x in normalize(samples, 1.0)]


def explosion(length_seconds=2.6, depth=1.0):
    length = int(length_seconds * RATE)
    cutoff = [120 + 900 * math.exp(-5.0 * i / length) for i in range(length)]
    rumble = multiply(lowpass(lowpass(noise(length_seconds), cutoff), cutoff), envelope(length, 0.004, length_seconds * 0.55, 3.0))
    thump = multiply(sine_sweep(length_seconds, 70 * depth, 30 * depth, 0.4), envelope(length, 0.002, 0.5))
    crackle = [0.0] * length
    for _ in range(30):
        at = int(rng.uniform(0.05, 0.6) * length)
        for i in range(min(300, length - at)):
            crackle[at + i] += rng.uniform(-1, 1) * math.exp(-i / 40.0)
    body = mix(scale(normalize(rumble, 1.0), 1.0), scale(normalize(thump, 1.0), 0.8), scale(normalize(highpass(crackle, 1500), 1.0), 0.12))
    return fade_edges(saturate(body, 2.5), 0.001, 0.2)


def flak():
    length = int(1.5 * RATE)
    crack = multiply(highpass(noise(1.5), 1500), envelope(length, 0.0003, 0.02))
    boom = explosion(1.5, 1.4)
    return saturate(mix(scale(normalize(crack, 1.0), 0.6), boom), 1.5)


def bomb_whistle():
    seconds = 2.8
    length = int(seconds * RATE)
    phase = 0.0
    out = []
    for i in range(length):
        t = i / length
        hz = 1500 - 800 * t + 12 * math.sin(TAU * 6 * i / RATE)
        phase += TAU * hz / RATE
        out.append(math.sin(phase) * (0.3 + 0.7 * t))
    air = scale(bandpass(noise(seconds), 600, 2500), 0.2)
    return fade_edges(mix(out, air), 0.2, 0.02)


def splash():
    length = int(0.9 * RATE)
    body = multiply(lowpass(noise(0.9), 1800), envelope(length, 0.003, 0.3))
    bubbles = [0.0] * length
    for _ in range(12):
        at = int(rng.uniform(0.05, 0.5) * length)
        hz = rng.uniform(500, 1400)
        for i in range(min(1200, length - at)):
            t = i / RATE
            bubbles[at + i] += math.sin(TAU * hz * (1 + t * 3) * t) * math.exp(-t * 40) * 0.3
    return fade_edges(mix(body, bubbles))


def click():
    length = int(0.05 * RATE)
    return fade_edges(multiply(bandpass(noise(0.05), 1500, 5000), envelope(length, 0.0003, 0.006)), 0.0003, 0.005)


def radio_blip():
    out = []
    for burst in range(2):
        for i in range(int(0.06 * RATE)):
            out.append(math.sin(TAU * 1050 * i / RATE) * 0.6)
        out.extend([0.0] * int(0.04 * RATE))
    static = scale(bandpass(noise(len(out) / RATE), 800, 3000), 0.15)
    return fade_edges(mix(out, static))


# ---------------------------------------------------------------------------
# Music: a tiny wavetable synthesiser and sequencer
# ---------------------------------------------------------------------------

TABLE_SIZE = 2048


def make_table(harmonics):
    """A single wave cycle built from (harmonic number, amplitude) pairs."""
    table = [0.0] * TABLE_SIZE
    for n, amplitude in harmonics:
        for i in range(TABLE_SIZE):
            table[i] += amplitude * math.sin(TAU * n * i / TABLE_SIZE)
    top = max(abs(x) for x in table)
    return [x / top for x in table]


TABLES = {
    "brass": make_table([(n, 1.0 / n) for n in range(1, 12)]),
    "brass_dark": make_table([(n, 1.0 / (n * n)) for n in range(1, 8)]),
    "strings": make_table([(n, 1.0 / n) for n in range(1, 9)]),
    "flute": make_table([(1, 1.0), (2, 0.25), (3, 0.08)]),
    "bass": make_table([(n, 1.0 / (n * n)) for n in range(1, 9, 2)]),
}

# Instrument: wavetables (bright, dark), attack, release, vibrato depth, detuned voices.
INSTRUMENTS = {
    "brass": ("brass", "brass_dark", 0.04, 0.12, 0.004, 1),
    "strings": ("strings", "strings", 0.35, 0.5, 0.006, 3),
    "flute": ("flute", "flute", 0.06, 0.15, 0.008, 1),
    "bass": ("bass", "bass", 0.01, 0.1, 0.0, 1),
}

NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_hz(name):
    """'A4', 'F#3', 'Bb2' -> frequency."""
    letter = name[0]
    accidental = 1 if "#" in name else -1 if "b" in name[1:] else 0
    octave = int(name[-1])
    semitone = NOTE_INDEX[letter] + accidental + (octave + 1) * 12
    return 440.0 * 2 ** ((semitone - 69) / 12)


def render_note(instrument, hz, seconds, velocity):
    bright_name, dark_name, attack, release, vibrato, voices = INSTRUMENTS[instrument]
    bright = TABLES[bright_name]
    dark = TABLES[dark_name]
    total = int((seconds + release) * RATE)
    held = int(seconds * RATE)
    attack_n = max(int(attack * RATE), 1)
    release_n = max(int(release * RATE), 1)
    out = [0.0] * total
    for voice in range(voices):
        detune = 1.0 + (voice - (voices - 1) / 2) * 0.004
        phase = rng.random() * TABLE_SIZE
        step = hz * detune * TABLE_SIZE / RATE
        for i in range(total):
            if i < attack_n:
                level = i / attack_n
            elif i < held:
                level = 1.0
            else:
                level = max(0.0, 1.0 - (i - held) / release_n)
            # Brassy notes start bright and mellow as they're held.
            brightness = math.exp(-i / (0.25 * RATE)) if bright is not dark else 0.0
            wobble = 1.0 + vibrato * math.sin(TAU * 5.5 * i / RATE) if i > attack_n else 1.0
            index = int(phase) % TABLE_SIZE
            sample = bright[index] * brightness + dark[index] * (1.0 - brightness)
            out[i] += sample * level * velocity / voices
            phase += step * wobble
    return out


def drum(kind, velocity):
    if kind == "snare":
        length = int(0.25 * RATE)
        rattle = multiply(highpass(noise(0.25), 1200), envelope(length, 0.001, 0.12))
        body = multiply([math.sin(TAU * 190 * i / RATE) for i in range(length)], envelope(length, 0.001, 0.05))
        return scale(mix(rattle, scale(body, 0.6)), velocity)
    if kind == "timpani":
        length = int(1.2 * RATE)
        tone = multiply(sine_sweep(1.2, 95, 80, 0.3), envelope(length, 0.003, 0.9))
        return scale(mix(tone, scale(multiply(lowpass(noise(1.2), 300), envelope(length, 0.002, 0.1)), 0.5)), velocity)
    if kind == "cymbal":
        length = int(1.5 * RATE)
        return scale(multiply(highpass(noise(1.5), 4000), envelope(length, 0.002, 1.2)), velocity * 0.4)
    raise ValueError(kind)


class Track:
    def __init__(self, bars, bpm, beats_per_bar=4):
        self.beat = 60.0 / bpm
        self.length = bars * beats_per_bar * self.beat
        self.buffer = [0.0] * int(self.length * RATE + 2 * RATE)

    def add(self, samples, beat_time, gain=1.0):
        start = int(beat_time * self.beat * RATE)
        buffer = self.buffer
        for i, x in enumerate(samples):
            j = start + i
            if j >= len(buffer):
                break
            buffer[j] += x * gain

    def note(self, instrument, name, beat_time, beats, velocity=0.5):
        self.add(render_note(instrument, note_hz(name), beats * self.beat, velocity), beat_time)

    def chord(self, instrument, names, beat_time, beats, velocity=0.3):
        for name in names:
            self.note(instrument, name, beat_time, beats, velocity)

    def melody(self, instrument, notes, start_beat, velocity=0.5):
        """notes: list of (name or None for a rest, beats)."""
        at = start_beat
        for name, beats in notes:
            if name:
                self.note(instrument, name, at, beats * 0.95, velocity)
            at += beats
        return at

    def finish(self, loop):
        out = reverb(self.buffer, 0.22)
        n = int(self.length * RATE)
        if loop:
            # Fold the ringing tail back onto the start so the loop is seamless.
            body = out[:n]
            for i, x in enumerate(out[n:]):
                if i < n:
                    body[i] += x
            return body
        return fade_edges(out, 0.001, 0.5)


def menu_theme():
    """A martial march in D minor: snare, brass melody, strings and bass."""
    t = Track(bars=16, bpm=96)
    progression = [
        ["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["F3", "A3", "C4"], ["A2", "C#3", "E3"],
        ["D3", "F3", "A3"], ["G2", "Bb2", "D3"], ["A2", "C#3", "E3"], ["D3", "F3", "A3"],
    ]
    bass_notes = ["D2", "Bb1", "F2", "A1", "D2", "G1", "A1", "D2"]
    for bar in range(16):
        chord = progression[bar % 8]
        t.chord("strings", [n[:-1] + str(int(n[-1]) + 1) for n in chord], bar * 4, 4, 0.12)
        t.note("bass", bass_notes[bar % 8], bar * 4, 1.8, 0.45)
        t.note("bass", bass_notes[bar % 8], bar * 4 + 2, 1.8, 0.4)
        # Military snare: a flam on the downbeat and running eighths.
        for eighth in range(8):
            velocity = 0.55 if eighth in (0, 4) else 0.3
            t.add(drum("snare", velocity), bar * 4 + eighth * 0.5)
        t.add(drum("snare", 0.2), bar * 4 + 3.75)
        if bar % 4 == 0:
            t.add(drum("timpani", 0.7), bar * 4)
    tune = [
        ("D4", 1.5), ("D4", 0.5), ("F4", 1), ("A4", 1), ("Bb4", 2), ("A4", 1), ("F4", 1),
        ("C5", 1.5), ("A4", 0.5), ("F4", 1), ("A4", 1), ("E4", 3), (None, 1),
        ("D4", 1.5), ("D4", 0.5), ("F4", 1), ("A4", 1), ("G4", 2), ("Bb4", 1), ("G4", 1),
        ("E4", 1.5), ("F4", 0.5), ("G4", 1), ("E4", 1), ("D4", 3), (None, 1),
    ]
    t.melody("brass", tune, 0, 0.5)
    t.melody("brass", tune, 32, 0.5)
    t.add(drum("cymbal", 0.8), 32)
    return t.finish(loop=True)


def flight_calm():
    """Slow, airy strings with a lonely flute: flying above the clouds."""
    t = Track(bars=16, bpm=72)
    progression = [
        ["E3", "G3", "B3", "D4"], ["C3", "E3", "G3", "B3"], ["A2", "C3", "E3", "G3"], ["B2", "D#3", "F#3", "A3"],
    ]
    for bar in range(16):
        t.chord("strings", progression[(bar // 2) % 4], bar * 4, 4, 0.1)
        if bar % 2 == 0:
            t.note("bass", ["E2", "C2", "A1", "B1"][(bar // 2) % 4], bar * 4, 7.5, 0.3)
    tune = [
        (None, 8), ("B4", 2), ("A4", 1), ("G4", 1), ("E4", 4), ("G4", 2), ("A4", 2), ("B4", 4), (None, 4),
        ("D5", 2), ("C5", 1), ("B4", 1), ("A4", 4), ("G4", 2), ("F#4", 2), ("E4", 6),
    ]
    t.melody("flute", tune, 0, 0.32)
    return t.finish(loop=True)


def combat_theme():
    """Driving strings ostinato, timpani and brass stabs."""
    t = Track(bars=16, bpm=132)
    roots = ["A2", "A2", "F2", "G2", "A2", "A2", "C3", "E2"]
    chords = [["A3", "C4", "E4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"],
              ["A3", "C4", "E4"], ["A3", "C4", "E4"], ["C4", "E4", "G4"], ["E3", "G#3", "B3"]]
    for bar in range(16):
        root = roots[bar % 8]
        octave_up = root[:-1] + str(int(root[-1]) + 1)
        for eighth in range(8):
            t.note("bass", root if eighth % 2 == 0 else octave_up, bar * 4 + eighth * 0.5, 0.45, 0.4)
            t.add(drum("snare", 0.45 if eighth % 2 else 0.25), bar * 4 + eighth * 0.5)
        t.add(drum("timpani", 0.8), bar * 4)
        t.add(drum("timpani", 0.6), bar * 4 + 2.5)
        t.chord("brass", chords[bar % 8], bar * 4, 0.5, 0.22)
        t.chord("brass", chords[bar % 8], bar * 4 + 1.5, 0.5, 0.18)
        t.chord("strings", chords[bar % 8], bar * 4, 4, 0.08)
        if bar % 8 == 0:
            t.add(drum("cymbal", 0.9), bar * 4)
    return t.finish(loop=True)


def victory():
    t = Track(bars=3, bpm=100)
    t.melody("brass", [("C4", 0.5), ("E4", 0.5), ("G4", 0.5), ("C5", 2.5)], 0, 0.5)
    t.melody("brass", [("G3", 0.5), ("C4", 0.5), ("E4", 0.5), ("G4", 2.5)], 0, 0.4)
    t.chord("strings", ["C3", "G3", "C4", "E4"], 1.5, 6, 0.15)
    t.note("bass", "C2", 1.5, 6, 0.5)
    t.add(drum("timpani", 0.9), 1.5)
    t.add(drum("cymbal", 0.9), 1.5)
    for i in range(6):
        t.add(drum("snare", 0.3 + i * 0.05), i * 0.25)
    return t.finish(loop=False)


def defeat():
    t = Track(bars=3, bpm=60)
    t.chord("strings", ["D3", "F3", "A3"], 0, 4, 0.15)
    t.chord("strings", ["Bb2", "D3", "G3"], 4, 4, 0.13)
    t.melody("brass", [("A3", 1.5), ("G3", 0.5), ("F3", 1), ("D3", 4)], 1, 0.3)
    t.note("bass", "D2", 0, 8, 0.4)
    t.add(drum("timpani", 0.7), 0)
    t.add(drum("timpani", 0.5), 4)
    return t.finish(loop=False)


def promotion():
    t = Track(bars=2, bpm=120)
    t.melody("brass", [("G4", 0.33), ("G4", 0.33), ("G4", 0.33), ("C5", 1.5), ("E5", 0.5), ("G5", 2)], 0, 0.5)
    t.chord("strings", ["C4", "E4", "G4"], 2.5, 3, 0.15)
    t.add(drum("cymbal", 0.7), 2.5)
    return t.finish(loop=False)


def medal():
    t = Track(bars=1, bpm=120)
    for i, name in enumerate(["E5", "G5", "C6"]):
        t.note("flute", name, i * 0.33, 1.5, 0.4)
    return t.finish(loop=False)


# ---------------------------------------------------------------------------

def main():
    sfx = {
        "engine_loop": (engine_loop, True),
        "wind_loop": (wind_loop, True),
        "gunshot": (gunshot, False),
        "bullet_hit": (bullet_hit, False),
        "whizz": (whizz, False),
        "explosion": (explosion, False),
        "flak": (flak, False),
        "bomb_whistle": (bomb_whistle, False),
        "splash": (splash, False),
        "click": (click, False),
        "radio": (radio_blip, False),
    }
    music = {
        "menu_theme": (menu_theme, True),
        "flight_calm": (flight_calm, True),
        "combat": (combat_theme, True),
        "victory": (victory, False),
        "defeat": (defeat, False),
        "promotion": (promotion, False),
        "medal": (medal, False),
    }
    # Name sounds on the command line to remake only those, e.g. "gunshot".
    # The noise is random, so remaking a sound always changes it a little.
    only = set(sys.argv[1:])
    print("Sound effects:")
    for name, (make, loop) in sfx.items():
        if not only or name in only:
            write_wav(os.path.join(OUT_SFX, name + ".wav"), make(), loop)
    print("Music:")
    for name, (make, loop) in music.items():
        if not only or name in only:
            write_wav(os.path.join(OUT_MUSIC, name + ".wav"), make(), loop)


if __name__ == "__main__":
    main()
