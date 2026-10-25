# Red Ace — Development Roadmap

A WWI-inspired arcade dogfighting game built in Godot 4.7 (3D, Jolt physics), loosely inspired by *Master of the Skies: The Red Ace*.

**Goal: a complete, commercial release on Steam.**

Check items off as they're completed. Milestones are ordered so that each one produces something playable.

---

## 0. Pre-production & Foundations

### Design
- [ ] Write a one-page game pitch (tone, setting, target platform, scope)
- [ ] Decide fictional vs. historical setting (factions, nations, plane names)
- [ ] Define core pillars (e.g. "dogfights feel great", "missions are short and varied", "progression keeps you going")
- [ ] Define control schemes: keyboard+mouse, gamepad, joystick
- [ ] Decide target platforms — Steam release: Windows (primary), Steam Deck, optionally Linux / macOS
- [ ] Define difficulty philosophy (arcade assists vs. realistic toggles)
- [ ] Create a rough art direction moodboard (palette, low-poly vs. realistic, sky style)
- [ ] Create an audio direction reference (engine sounds, music style)

### Project setup
- [x] Initialize git repository and first commit
- [x] Set up folder structure (`scenes/`, `scripts/`, `assets/`, `data/`, `ui/`, `audio/`)
- [x] Configure input map (pitch, roll, yaw, throttle, fire, bomb, camera, pause)
- [ ] Set up autoload singletons (GameState, SaveManager, AudioManager, SceneLoader)
- [ ] Choose code conventions (GDScript style, naming, signals vs. direct calls)
- [x] Set up physics layers and collision masks (player, enemy, bullets, ground, targets)
- [x] Set up a debug overlay (FPS, speed, altitude, AI state, toggles)
- [x] Set up a test/sandbox scene for rapid iteration

---

## 1. Milestone: Flight Prototype ("Does flying feel good?")

### Flight model
- [x] Plane controller script (arcade physics: thrust, drag, lift, gravity)
- [x] Pitch / roll / yaw control with tunable rates
- [x] Throttle control with min/max speed
- [x] Speed-dependent control authority (sluggish when slow)
- [x] Stall behavior at low speed (nose drop, recovery)
- [x] Ground collision and crash detection
- [ ] Takeoff and landing support (or air-start option)
- [x] Tunable per-aircraft stats resource (speed, turn rate, climb rate, health)
- [ ] Optional assists: auto-level ✅, stall warning ✅, auto-throttle

### Camera
- [x] Chase camera with smoothing/lag
- [x] Cockpit camera
- [x] Free look (mouse/right stick)
- [ ] Target-lock camera (look at nearest enemy / padlock view)
- [x] Camera shake on damage and gunfire
- [x] Field-of-view change with speed

### Test environment
- [x] Simple heightmap terrain
- [x] Sky (procedural sky / skybox) and sun lighting
- [x] Distance fog
- [x] World boundary handling (turn-back warning or invisible wall)
- [x] Placeholder biplane model built from primitives

---

## 2. Milestone: Combat Prototype ("Is dogfighting fun?")

### Weapons
- [x] Machine guns (fast projectiles or raycasts) with tracers
- [x] Fire rate, spread, and bullet travel time
- [x] Gun overheating / jamming mechanic
- [x] Ammo count
- [ ] Ammo resupply rules (e.g. land at friendly airfield)
- [x] Bombs (drop physics, explosion radius) with a bomb sight
- [ ] Optional: rockets (Le Prieur style) for balloon busting
- [x] Hit detection and hit feedback (sparks, hit marker)
- [x] Hit sounds (see Audio)

### Damage model
- [x] Health system per aircraft
- [x] Component damage (engine, wings, tail, pilot) affecting handling
- [x] Visual damage states: smoke and fire
- [ ] Visual damage states: bullet holes, missing parts
- [x] Death states: explode, spiral down, crash-land
- [x] Player bail-out / mission failure on death

### Enemy AI (air)
- [x] AI state machine: patrol → detect → engage → evade → flee/retreat
- [x] Pursuit steering (lead target, get on tail)
- [x] Defensive maneuvers (break turns, climbs, dives)
- [x] Terrain avoidance
- [x] Accuracy / reaction tuned by skill level (rookie, veteran, ace)
- [ ] Wingman/formation flying
- [x] Target selection (player vs. allies)
- [x] Named enemy aces with unique behavior (boss fights)
- [ ] Smarter tactics: climbing/diving attacks, energy fighting (evenly matched AIs currently circle forever)

### HUD (prototype)
- [x] Speed and altitude indicators
- [x] Throttle indicator
- [x] Gun heat / ammo gauge
- [x] Health / damage indicator
- [x] Crosshair and lead indicator (optional assist)
- [x] Off-screen enemy arrows
- [x] Minimap: rotates with the plane, north marker, enemies, friends and objectives, zoomable

---

## 3. Milestone: Mission System ("One complete mission")

### Mission framework
- [x] Mission format: each mission is a scene with Objective nodes, built in the editor
- [ ] Objective types:
  - [x] Destroy all enemy aircraft
  - [x] Destroy ground targets (tanks, AA guns, trucks, trains)
  - [x] Bomb a structure (factory, bridge, depot)
  - [x] Destroy observation balloons
  - [x] Escort / protect a friendly (bomber, recon plane)
  - [x] Defend a location (airfield, trench line)
  - [x] Reach waypoint
  - [ ] Recon photo
  - [ ] Rescue / cover downed pilot
  - [x] Duel a named ace
- [x] Primary vs. optional (bonus) objectives
- [x] Objective-complete triggers (next objective starts, enemies spawn)
- [ ] More triggers: area enter, timers
- [x] Wave/spawn system for enemies
- [x] Mission success/failure conditions
- [x] Mission timer and scoring
- [x] In-mission radio messages / dialogue lines

### Ground units & structures
- [x] Tanks (moving along paths)
- [x] AA guns with flak bursts (shoot at player)
- [x] Trucks / convoys
- [ ] Trains
- [x] Observation balloons
- [x] Buildings: supply sheds, fuel tanks (destructible)
- [ ] More buildings: factories, hangars, bridges
- [ ] Trenches and infantry (visual dressing)
- [ ] Friendly airfield (landing/repair zone)

### Mission flow
- [x] Briefing screen (map, objectives)
- [x] Plane select on briefing
- [x] Loading screen
- [x] In-mission pause menu (resume, restart, settings, quit)
- [x] Debriefing screen (score, kills, accuracy, rank progress)

---

## 4. Milestone: Campaign & Progression ("Vertical slice")

### Campaign
- [x] Campaign structure: 3 theaters, missions unlock in order
- [ ] Grow the campaign to ~25 missions (9 so far: 3 per theater)
- [x] Mission unlock order
- [x] Story outline (protagonist, rival ace, war arc)
- [x] Inter-mission story text (theater intros, briefings, radio)
- [ ] Cutscene stills
- [x] Theater 1 missions (The Quiet Sector)
- [x] Theater 2 missions (Mud and Wire: defend, escort)
- [x] Theater 3 missions (The High Passes: airfield raid, final ace duel)
- [x] Final boss mission

### Progression
- [x] Rank system (e.g. Corporal → Colonel) with thresholds
- [x] Medals / awards for achievements
- [x] Aircraft unlocks tied to rank/campaign progress
- [ ] Optional: aircraft upgrades (engine, guns, armor)
- [x] Plane paint schemes / liveries
- [x] Pilot stats tracking (kills, missions, accuracy)

### Aircraft roster (fictionalized WWI-inspired)
- [x] Starter pusher fighter (DH.2-inspired)
- [x] Light agile scout (Bristol Scout-inspired)
- [x] Nimble dogfighter (Camel-inspired)
- [x] Fast sturdy fighter (SPAD-inspired)
- [x] Late-game top fighter
- [ ] Two-seater with rear gunner (optional)
- [x] Code-built aircraft models with per-type colours, size and triplane option
- [ ] Optional: hand-made models (Blender) for each aircraft type
- [x] Enemy fighter and the ace's red triplane
- [ ] More enemy fighter types
- [x] Allied bomber (escorted)
- [ ] Enemy bombers and zeppelins
- [x] Distinct handling stats for each

---

## 5. World & Environments

- [x] Terrain generator: hills, rivers, lakes, forests, snow, edge hills — tuned per theater
- [ ] Optional: hand-painted heightmaps for special maps
- [x] Theater 1 map (green farmland)
- [x] Theater 2 map (e.g. muddy trench front / no man's land)
- [x] Theater 3 map (e.g. mountains, coastline, or snow)
- [x] Terrain texturing: field patchwork, rock on slopes, sandy shores, snow, detail noise shader
- [x] Dirt roads (between villages, and convoy routes)
- [x] Trees (pines and broadleaf) in multimesh chunks with distance culling
- [ ] Hedgerows between fields
- [x] Villages, farms, churches, windmills
- [x] Rivers and lakes (water shader)
- [x] Billboard clouds you can fly through (screen mists over)
- [x] Time of day variants (dawn, noon, dusk)
- [x] Weather variants (clear, overcast, rain, fog)
- [x] Map boundaries that look natural

---

## 6. Art & Visual Effects

### Models
- [x] Final player aircraft models (low-poly, consistent style)
- [x] Enemy aircraft models
- [x] Animated parts: propeller, control surfaces, pilot head
- [x] Ground vehicles (rhomboid tank, lorry), AA guns with shields, balloons, zeppelin
- [x] Buildings and props (collapse into rubble when destroyed)
- [x] Cockpit interiors with gauges

### VFX
- [x] Muzzle flash and tracers
- [x] Bullet impacts: sparks, dirt, water splashes
- [ ] Bullet impacts: wood splinters
- [x] Explosions (air and ground)
- [x] Flak bursts
- [x] Smoke and fire trails from damaged planes
- [x] Engine exhaust
- [x] Wingtip vapour trails in hard turns
- [x] Debris and falling parts
- [x] Crash dust/fire on ground

### Rendering
- [x] Lighting and shadow setup per map
- [x] Post-processing (bloom, color grading, slight film grain for period feel)
- [x] Tree detail levels (simple distant trees, no distant shadows)
- [ ] LOD for aircraft and terrain
- [ ] Performance budget (draw calls, poly counts) — currently ~1.25M triangles and ~250 draw calls in free flight, 60 FPS on an M1

---

## 7. Audio

All sounds and music are synthesised by `tools/generate_audio.py` – no samples or third-party audio, so there are no licensing issues.


- [x] Engine sound loop with pitch/volume tied to throttle and speed
- [ ] Unique engine sounds per aircraft type (all share one synthesised engine, pitched by revs)
- [x] Machine gun sounds (player and enemy, distance falloff)
- [x] Bullet hits / ricochets / whizz-by sounds
- [x] Explosions, flak, bombs
- [x] Wind noise based on speed
- [x] Stall / damage warnings, engine sputter
- [x] 3D positional audio for enemies
- [x] UI sounds (menu clicks, rank up, medal)
- [x] Music: main menu theme
- [x] Music: in-mission (calm/combat dynamic switching)
- [x] Music: victory / defeat stingers
- [x] Radio messages: text with a radio blip
- [ ] Radio voice lines (optional)
- [x] Audio bus setup and mixing (Master, Music, SFX, Voice)

---

## 8. UI & Menus

- [x] Title / splash screen
- [x] Basic main menu (Mission 1, Free flight, Quit)
- [x] Full main menu (Campaign, Quick Battle, Hangar, Settings, Credits, Quit) over a live 3D flyby
- [x] Campaign / mission select screen
- [x] Hangar screen (choose plane, view stats, liveries)
- [ ] Briefing and debriefing screens (final art)
- [x] Pilot profile / service record (rank, medals, stats)
- [x] Settings menu:
  - [x] Graphics (resolution, fullscreen, quality presets, vsync)
  - [x] Audio (volume sliders per bus)
  - [x] Controls (rebinding, sensitivity, invert Y)
  - [x] Separate Keyboard & Mouse and Controller tabs: two keys per control, mouse buttons, conflict handling, per-tab reset
  - [x] Gameplay (difficulty, assists, HUD options)
- [x] Final HUD art and layout
- [x] Controller-navigable menus
- [x] Credits screen
- [x] Consistent UI theme (khaki panels, brass trim)
- [ ] Period-style font (an OFL-licensed typeface would suit)

---

## 9. Extra Game Modes (post-campaign)

- [x] Quick Battle / Instant Action (pick plane, enemies, map)
- [x] Survival / endless waves mode
- [x] Ace duel mode (1v1 against named aces)
- [x] Training / tutorial missions
- [x] Optional: play the enemy side (like *Red Ace Squadron*)
- [x] Local split-screen: co-op waves and versus, side by side or stacked, one device per player
  - [x] Both players choose aircraft and paint on the two-player screen (with previews)
- [ ] Optional: online multiplayer (dogfight, co-op)

---

## 10. Systems & Tech

- [x] Save/load system (campaign progress, unlocks, settings)
- [ ] Multiple save slots
- [x] Scene loading with progress (threaded loading)
- [x] Object pooling for bullets, effects, debris
- [x] Input handling for keyboard/mouse, gamepad, joystick (with dead zones)
- [x] Rumble / haptics for gamepad
- [ ] Pause handling (process modes)
- [ ] Localization support (string tables) — even if English only at first
- [ ] Accessibility: subtitles, colorblind-safe HUD, remappable controls
- [ ] Error logging and crash handling

---

## 11. Balancing & Playtesting

- [ ] Tune flight model per aircraft
- [ ] Tune AI difficulty curve across campaign
- [ ] Tune weapon damage, heat, and ammo
- [ ] Tune scoring and rank progression pace
- [x] Difficulty levels (Easy / Normal / Hard / Ace)
- [ ] Internal playtest passes per milestone
- [ ] External playtests with feedback form
- [ ] Fix pacing issues in missions (too long, too empty, too hard)

---

## 12. Optimization & QA

- [ ] Profile CPU (AI, physics, bullets)
- [ ] Profile GPU (terrain, vegetation, clouds, particles)
- [ ] Hit target framerate on minimum-spec hardware
- [ ] Test on all target platforms
- [ ] Test all input devices on real hardware (keyboard/mouse, Xbox, PlayStation, flight sticks) — routing tested with simulated input
- [ ] Bug tracking list and triage
- [ ] Full campaign playthrough without blockers
- [ ] Save compatibility testing
- [ ] Edge cases: alt-tab, resolution changes, controller disconnect

---

## 13. Legal & Business (start early)

- [ ] Final game name — check it doesn't conflict with existing trademarks or Steam titles ("Red Ace" is taken by the original series)
- [ ] Use fictional names for aircraft/factions, or verify real manufacturer names are safe to use
- [ ] Every third-party asset (models, textures, sounds, music, fonts) has a license allowing commercial use — keep a license log
- [x] Godot engine MIT license notice included in credits/about
- [ ] Decide release as individual or registered business
- [ ] Privacy policy (needed if any data/analytics is collected)
- [ ] EULA (Steam's default is fine unless you need more)

---

## 14. Steam Integration

- [ ] Steamworks partner account (identity, bank and tax info)
- [ ] Pay Steam Direct app fee ($100 per game, recouped after $1,000 in revenue)
- [ ] Integrate Steamworks SDK (e.g. GodotSteam addon)
- [ ] Steam achievements (design list, icons, wire up triggers)
- [ ] Steam Cloud saves
- [ ] Steam Input / controller configuration
- [ ] Steam leaderboards (optional: score per mission, survival mode)
- [ ] Steam Deck: test, readable UI at 1280×800, gamepad-only playable, aim for "Verified"
- [ ] Rich presence (optional)
- [ ] Set up depots and upload builds via SteamPipe
- [ ] Beta branch for testers
- [ ] Content survey and age ratings questionnaire completed

---

## 15. Steam Store Page & Marketing

- [ ] Capsule art in all required sizes (header, small, main, vertical, library hero, logo)
- [ ] 5+ screenshots that show gameplay (not menus)
- [ ] Gameplay trailer (first 5 seconds show action)
- [ ] Short and long descriptions, tags, system requirements
- [ ] Publish a "Coming Soon" page early (months before launch) to collect wishlists
- [ ] Playable demo
- [ ] Join a Steam Next Fest with the demo
- [ ] Devlog / social media presence (YouTube, X/Bluesky, Reddit, TikTok)
- [ ] Discord server for community and playtesters
- [ ] Press kit and outreach to content creators / press
- [ ] Decide price, regional pricing, and launch discount
- [ ] Store page submitted for Valve review (allow several business days)
- [ ] Build submitted for Valve review before launch (allow several business days)

---

## 16. Release

- [ ] Game icon, window title, and version number
- [ ] Windows export (primary), plus Linux / macOS if supporting them (macOS needs code signing + notarization)
- [ ] Credits including all third-party asset attributions
- [ ] Release candidate build passes full QA checklist
- [ ] Changelog / patch notes
- [ ] Launch day: set release live, post announcement, monitor reviews and forums
- [ ] Hotfix plan for the first week

---

## 17. Post-Launch (optional)

- [ ] Bug fix patches based on player reports
- [ ] Respond to Steam reviews and community discussions
- [ ] New missions / theater DLC
- [ ] New aircraft
- [ ] Mod support / Steam Workshop (custom missions via data files)
- [ ] Seasonal sales participation
