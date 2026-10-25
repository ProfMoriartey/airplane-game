class_name Damage
## Shared damage rules: the kinds of damage, and explosions that hurt everything nearby.
##
## Anything that can be damaged joins the "damageable" group and has a `team`,
## `is_alive()` and `take_damage(amount, hit_position, attacker, kind)`.

enum Kind { BULLET, EXPLOSION, COLLISION }

## Use as source_team when an explosion should hurt every side.
const NO_TEAM := -1


## Damages everything within radius, less the further from the centre.
## Targets on source_team are spared, so a side's own flak doesn't hit its own planes.
static func explode(
	tree: SceneTree,
	center: Vector3,
	radius: float,
	damage: float,
	attacker: Aircraft,
	source_team: int = NO_TEAM,
) -> void:
	for node in tree.get_nodes_in_group("damageable"):
		var target := node as Node3D
		if not target.is_alive() or target.team == source_team:
			continue
		var distance := target.global_position.distance_to(center)
		if distance < radius:
			target.take_damage(damage * (1.0 - distance / radius), center, attacker, Kind.EXPLOSION)
