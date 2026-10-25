# Red Ace (working title)

A WWI-inspired arcade dogfighting game made with [Godot 4.7](https://godotengine.org/).

From the main menu you can play the **Campaign** – 9 missions across three theaters, ending in a duel with the Crimson Crow – or **Free flight** with endless waves of enemy fighters. Campaign progress, ranks, medals and unlocked aircraft are saved automatically.

## Running the game

1. Open Godot and click **Import**, then select this folder's `project.godot`.
2. Press **F5** (or the ▶ button at the top right) to play.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Fire guns | Space / left mouse | A |
| Drop bomb | B | B |
| Nose down / up | W / S | Left stick up / down |
| Roll left / right | A / D | Left stick left / right |
| Rudder left / right | Q / E | LB / RB |
| Throttle up / down | Shift / Ctrl | RT / LT |
| Chase / cockpit view | C | Y |
| Look around | Hold right mouse + move | Right stick |
| Pause | Esc | Start |
| Restart (after being shot down, free flight) | R | Back |
| Show / hide help | F1 | |
| Debug info | F3 | |

## Project layout

- `scenes/` – levels, aircraft, ground targets, effects and UI scenes
- `scripts/` – game code, organised the same way

## Making a mission

Missions are scenes that inherit `scenes/levels/base_level.tscn` (see `mission_01.tscn`). Add a `Mission` node, then give it objective children in the order they should happen:

- `ReachAreaObjective` – fly to a marker
- `DestroyObjective` – destroy everything under a node: ground targets, or an `EnemySquadron` whose fighters take off when the objective starts
- `DefendObjective` – protect friendly ground targets from an attacking squadron
- `EscortObjective` – keep friendly aircraft (e.g. `allied_bomber.tscn` with a route) alive until they reach a destination

Tick **optional** for bonus objectives. Radio lines are written as `Speaker: message`. Give the Mission a `mission_id`, then add the mission to `data/campaign/campaign.tres` to put it in the campaign.

Aircraft are defined in `data/aircraft/*.tres` – flight handling, guns, bombs, colours, size, and the rank that unlocks them.
- `data/aircraft/` – per-aircraft flight stats (edit these to tune handling)
- `assets/` – textures and other art

See [ROADMAP.md](ROADMAP.md) for the full development plan.
