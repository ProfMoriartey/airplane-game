class_name PathMover
extends Node
## Drives its parent vehicle along a Path3D, following the shape of the ground.
## Stops when the vehicle is destroyed or reaches the end of the road.

@export var path: Path3D
@export var speed := 7.0
## How far along the path this vehicle starts, so a convoy can be spaced out.
@export var start_distance := 0.0

var _distance := 0.0
var _vehicle: GroundTarget
var _terrain: Terrain


func _ready() -> void:
	_vehicle = get_parent() as GroundTarget
	_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	_distance = start_distance
	_place()


func _physics_process(delta: float) -> void:
	if not _vehicle.is_alive():
		return
	var length := path.curve.get_baked_length()
	if _distance >= length:
		return
	_distance = minf(_distance + speed * delta, length)
	_place()


func _place() -> void:
	var curve := path.curve
	var here := path.to_global(curve.sample_baked(_distance))
	var ahead := path.to_global(curve.sample_baked(minf(_distance + 3.0, curve.get_baked_length())))
	here.y = _terrain.get_height(here.x, here.z) + _vehicle.ground_offset
	_vehicle.global_position = here
	var direction := ahead - here
	if Vector2(direction.x, direction.z).length_squared() > 0.01:
		_vehicle.global_rotation.y = atan2(-direction.x, -direction.z)
