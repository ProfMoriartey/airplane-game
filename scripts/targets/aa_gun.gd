class_name AAGun
extends GroundTarget
## Anti-aircraft gun. Swings round to hostile planes in range and fires flak
## shells that burst near where the plane is heading.

const FLAK_SCENE := preload("res://scenes/effects/flak_burst.tscn")

@export var fire_range := 1000.0
@export var fire_interval := 1.8
@export var shell_speed := 450.0
## How far off a typical shell bursts, in metres.
@export var aim_error := 35.0
@export var flak_radius := 20.0
@export var flak_damage := 16.0

var _fire_timer := 0.0

@onready var _turret: Node3D = $Model/Turret
@onready var _barrel: Node3D = $Model/Turret/Barrel


func _ready() -> void:
	super()
	_fire_timer = randf() * fire_interval


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	var target := _find_target()
	if target == null:
		return

	# Turn the turret, then raise the barrel.
	var to_target := target.global_position - _barrel.global_position
	_turret.global_rotation.y = atan2(-to_target.x, -to_target.z)
	_barrel.rotation.x = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire_at(target)


func _find_target() -> Aircraft:
	for node in get_tree().get_nodes_in_group("aircraft"):
		var plane := node as Aircraft
		if plane.is_alive() and plane.team != team \
				and plane.global_position.distance_to(global_position) < fire_range:
			return plane
	return null


func _fire_at(target: Aircraft) -> void:
	var flight_time := _barrel.global_position.distance_to(target.global_position) / shell_speed
	var aim := target.global_position + target.velocity * flight_time
	aim += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * aim_error
	# The shell bursts when it would arrive. The timer pauses with the game.
	get_tree().create_timer(flight_time, false, true).timeout.connect(_burst.bind(aim))


func _burst(at: Vector3) -> void:
	var flak := FLAK_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(flak)
	flak.global_position = at
	Damage.explode(get_tree(), at, flak_radius, flak_damage, null, team)
