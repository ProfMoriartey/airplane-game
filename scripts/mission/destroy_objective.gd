class_name DestroyObjective
extends Objective
## Complete when enough of the targets under the `targets` node are destroyed.
##
## Targets can be ground targets or aircraft. If `targets` is an EnemySquadron,
## its planes take off when this objective starts.

@export var targets: Node
## How many must be destroyed. 0 means all of them.
@export var required := 0

var _tracked: Array[Node3D] = []
var _destroyed := 0


func _on_activated() -> void:
	if targets.has_method("spawn"):
		targets.spawn()
	for node in targets.find_children("*", "", true, false):
		if node is GroundTarget or node is Aircraft:
			_tracked.append(node)
			if node.is_alive():
				node.destroyed.connect(_on_target_destroyed)
			else:
				_destroyed += 1
	_check()


func get_progress_text() -> String:
	return "%d/%d" % [_destroyed, _needed()]


func get_markers() -> Array[Vector3]:
	var markers: Array[Vector3] = []
	for target in _tracked:
		if is_instance_valid(target) and target.is_alive():
			markers.append(target.global_position)
	return markers


func get_map_position() -> Vector3:
	if _tracked.is_empty() and targets is Node3D:
		# Before activation (e.g. on the briefing map), use where the targets are placed.
		var children := targets.get_children().filter(func(child: Node) -> bool: return child is Node3D)
		if children.is_empty():
			return targets.global_position
		var sum := Vector3.ZERO
		for child: Node3D in children:
			sum += child.global_position
		return sum / children.size()
	return super()


func _needed() -> int:
	return required if required > 0 else _tracked.size()


func _on_target_destroyed(_attacker: Aircraft) -> void:
	_destroyed += 1
	_check()


func _check() -> void:
	if _destroyed >= _needed():
		complete()
