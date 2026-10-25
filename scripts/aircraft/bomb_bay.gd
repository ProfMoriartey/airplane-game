class_name BombBay
extends Node3D
## Carries a plane's bombs and releases them one at a time.

const BOMB_SCENE := preload("res://scenes/combat/bomb.tscn")

@export var capacity := 6
## Minimum time between two drops.
@export var release_interval := 0.4

var count := 0

var _cooldown := 0.0

@onready var _owner_aircraft := get_parent() as Aircraft


func _ready() -> void:
	count = capacity


func _physics_process(delta: float) -> void:
	_cooldown -= delta


func reload() -> void:
	count = capacity


func drop() -> void:
	if count <= 0 or _cooldown > 0.0:
		return
	count -= 1
	_cooldown = release_interval

	var bomb := BOMB_SCENE.instantiate() as Bomb
	bomb.velocity = _owner_aircraft.velocity
	bomb.dropped_by = _owner_aircraft
	# The level sits at the world origin, so its local space is world space.
	bomb.transform = global_transform
	get_tree().current_scene.add_child(bomb)


## Where a bomb dropped right now would land, or null.
func predict_impact(terrain: Terrain) -> Variant:
	return Bomb.predict_impact(global_position, _owner_aircraft.velocity, terrain)
