# Balance tools

Headless test scripts that measure the game instead of guessing. Run them from the
project folder (`godot` is `/Applications/Godot.app/Contents/MacOS/Godot` on this Mac).
`--fixed-fps 60` makes time run as fast as the computer allows.

| Tool | Command | What it tells you |
|---|---|---|
| Flight tests | `godot --headless --fixed-fps 60 --path . -s res://tools/balance/flight_tests.gd` | Top speed, acceleration, turn time and size, climb, firepower and toughness for every aircraft |
| Pressure test | `godot --headless --fixed-fps 60 --path . -s res://tools/balance/pressure.gd -- 15` | How long a pretend player survives enemy fighters at each difficulty and skill |
| Campaign report | `godot --headless --path . -s res://tools/balance/campaign_report.gd` | Enemies and threat per mission, points on offer, when ranks and aircraft unlock |
| Duels | `godot --headless --fixed-fps 60 --path . -s res://tools/balance/duels.gd -- fighters 20` | AI against AI. Equal AI pilots mostly joust (loop, meet head-on, repeat), so expect many draws |

Aircraft are tuned in `data/aircraft/*.tres`, pilot skills in `scripts/aircraft/aircraft_ai.gd`
(`SKILL_SETTINGS`), difficulty levels in `scripts/autoload/settings.gd` (`DIFFICULTY_SETTINGS`),
ranks in `scripts/campaign/ranks.gd`, and mission enemies in each mission scene's squadrons
(`count`, `skill`, `veterans`).

## Findings from the first balance pass (milestone 11)

- **The Lark was a downgrade** from the starting Scout (slower, weaker, lower firepower).
  Now it is faster, rolls and climbs best, and trades that for armour.
- **Gun heat never built up**: cooling (0.35/s) beat heating at every fire rate. Heat is now
  set per second of firing, so holding the trigger overheats any plane in about 6 seconds.
- **Mission 4 was the hardest mission** in the campaign (threat 11, the first veterans).
  Squadrons can now mix pilots (`veterans`); the threat curve is 4, 3, 5, 8, 5, 8, 8, 9, 8.
- **The best plane arrived before the last mission.** Unlocks moved one rank earlier:
  Lark after mission 1, Hornet after 3, Falcon after 4, Kestrel after 6 (typical player).
- **Enemy fire is fair**: one rookie lands about 7 hits in two minutes on a beginner who
  never dodges (about 3 on Easy); three rookies, or one ace, is where beginners start
  dying. Hitting the enemy is the harder part for new players, so **aim assist** (Light by
  default) lets bullets that only just miss still count.
