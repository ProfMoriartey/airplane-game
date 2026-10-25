extends Node
## Game-wide events, so systems like scoring can react without knowing who caused them.

signal aircraft_destroyed(aircraft: Aircraft, attacker: Aircraft)
signal ground_target_destroyed(target: GroundTarget, attacker: Aircraft)
