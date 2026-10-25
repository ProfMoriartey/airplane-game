# Red Ace (working title)

A WWI-inspired arcade dogfighting game made with [Godot 4.7](https://godotengine.org/).

The current sandbox level sends endless waves of enemy fighters at you, getting tougher every few waves.

## Running the game

1. Open Godot and click **Import**, then select this folder's `project.godot`.
2. Press **F5** (or the ▶ button at the top right) to play.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Fire guns | Space / left mouse | A |
| Nose down / up | W / S | Left stick up / down |
| Roll left / right | A / D | Left stick left / right |
| Rudder left / right | Q / E | LB / RB |
| Throttle up / down | Shift / Ctrl | RT / LT |
| Chase / cockpit view | C | Y |
| Look around | Hold right mouse + move | Right stick |
| Restart | R | Back |
| Show / hide help | F1 | |
| Debug info | F3 | |

## Project layout

- `scenes/` – levels, aircraft, UI scenes
- `scripts/` – game code, organised the same way
- `data/aircraft/` – per-aircraft flight stats (edit these to tune handling)
- `assets/` – textures and other art

See [ROADMAP.md](ROADMAP.md) for the full development plan.
