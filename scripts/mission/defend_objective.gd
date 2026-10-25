class_name DefendObjective
extends Objective
## Protect friendly targets from an attack.
##
## When the objective starts, the `attackers` squadron takes off. It's complete
## once every attacker is shot down, and fails if more than `allowed_losses`
## of the targets under `protected` are destroyed.

@export var protected: Node
@export var attackers: EnemySquadron
@export var allowed_losses := 0

var _protected: Array[GroundTarget] = []
var _attackers: Array[Aircraft] = []
var _losses := 0
var _attackers_down := 0


func _on_activated() -> void:
	for node in protected.find_children("*", "", true, false):
		if node is GroundTarget and node.is_alive():
			_protected.append(node)
			node.destroyed.connect(_on_protected_destroyed)
	_attackers = attackers.spawn()
	for attacker in _attackers:
		attacker.destroyed.connect(_on_attacker_destroyed)


func get_progress_text() -> String:
	return "%d/%d" % [_attackers_down, _attackers.size()]


## Point the player at the attackers, the actual threat.
func get_markers() -> Array[Vector3]:
	var markers: Array[Vector3] = []
	for attacker in _attackers:
		if is_instance_valid(attacker) and attacker.is_alive():
			markers.append(attacker.global_position)
	return markers


func get_map_position() -> Vector3:
	var children := protected.get_children().filter(func(child: Node) -> bool: return child is Node3D)
	var sum := Vector3.ZERO
	for child: Node3D in children:
		sum += child.global_position
	return sum / maxi(children.size(), 1)


func _on_protected_destroyed(_attacker: Aircraft) -> void:
	_losses += 1
	if _losses > allowed_losses:
		fail()


func _on_attacker_destroyed(_attacker: Aircraft) -> void:
	_attackers_down += 1
	if _attackers_down >= _attackers.size():
		complete()
