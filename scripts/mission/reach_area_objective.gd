class_name ReachAreaObjective
extends Objective
## Complete when the player flies within `radius` of a marker (height doesn't matter).

@export var area: Node3D
@export var radius := 300.0


func _physics_process(_delta: float) -> void:
	if not is_active() or not mission.player.is_alive():
		return
	var offset := mission.player.global_position - area.global_position
	if Vector2(offset.x, offset.z).length() < radius:
		complete()


func get_markers() -> Array[Vector3]:
	return [area.global_position]
