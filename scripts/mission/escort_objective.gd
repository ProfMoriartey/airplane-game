class_name EscortObjective
extends Objective
## Keep friendly aircraft alive until they reach their destination.
##
## The escorted planes (children of `escorts`) start flying when the objective
## starts. It's complete when `required` of them get within `radius` of the
## destination, and fails if too many are shot down for that to happen.

@export var escorts: Node
@export var destination: Node3D
@export var radius := 400.0
## How many must survive. 0 means all of them.
@export var required := 0

var _escorts: Array[Aircraft] = []


func _ready() -> void:
	# Escorted planes wait on the runway, so to speak, until the objective starts.
	for node in escorts.get_children():
		if node is Aircraft:
			_escorts.append(node)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.add_to_group("priority_target")


func _on_activated() -> void:
	for escort in _escorts:
		escort.process_mode = Node.PROCESS_MODE_INHERIT
		escort.destroyed.connect(_on_escort_destroyed)


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	var arrived := 0
	for escort in _escorts:
		if not is_instance_valid(escort) or not escort.is_alive():
			continue
		var offset := escort.global_position - destination.global_position
		if Vector2(offset.x, offset.z).length() < radius:
			arrived += 1
	if arrived >= _needed():
		complete()


func get_progress_text() -> String:
	return tr("%d/%d alive") % [_alive(), _escorts.size()]


func get_markers() -> Array[Vector3]:
	var markers: Array[Vector3] = []
	for escort in _escorts:
		if is_instance_valid(escort) and escort.is_alive():
			markers.append(escort.global_position)
	return markers


func get_map_position() -> Vector3:
	return destination.global_position


func _needed() -> int:
	return required if required > 0 else _escorts.size()


func _alive() -> int:
	var alive := 0
	for escort in _escorts:
		# Wrecks are freed after a while, so check the plane still exists.
		if is_instance_valid(escort) and escort.is_alive():
			alive += 1
	return alive


func _on_escort_destroyed(_attacker: Aircraft) -> void:
	if _alive() < _needed():
		fail()
