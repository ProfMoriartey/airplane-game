class_name Aircraft
extends CharacterBody3D
## Arcade flight model and damage model shared by the player's and enemy aircraft.
##
## Speed is a single number along the nose. Engine thrust, air drag and gravity
## (when climbing or diving) change it. Below stall speed the wings lose lift,
## the plane sinks and its nose drops until it gains speed again.
##
## Bullet hits damage the whole plane and the part they strike: a hit engine
## loses power, hit wings roll and turn worse, a hit tail pitches and yaws worse.

signal damaged(amount: float, attacker: Aircraft)
## Emitted once when the plane is shot down or crashes. attacker is null for a crash.
signal destroyed(attacker: Aircraft)
## Emitted when the plane hits the ground (or another plane).
signal crashed

enum Team { ALLIES, CENTRAL }

const GRAVITY := 9.8
const THROTTLE_CHANGE_RATE := 0.6
const MAX_STALL_SINK := 25.0
## Extra sink at a 90° bank, so steep turns need back-pressure on the stick.
const BANK_SINK := 8.0
const PROPELLER_MAX_SPIN := 60.0
## Below this fraction of health the plane trails smoke.
const SMOKE_HEALTH := 0.5
## How hard an uneven wing pulls the plane into a roll.
const WING_DAMAGE_ROLL := 0.5
## Enemy wrecks are removed this long after hitting the ground, once their smoke has cleared.
const WRECK_CLEANUP_TIME := 6.0
const EXPLOSION_SCENE := preload("res://scenes/effects/explosion.tscn")

@export var stats: AircraftStats
@export var team := Team.ALLIES
@export var player_controlled := false
## Shown next to the plane's marker, for named enemy aces.
@export var pilot_name := ""
## Beginner assist: gently rolls the wings level when no roll input is given.
@export var auto_level := true
@export var auto_level_strength := 1.2

## Control inputs, each from -1 to 1. Set by the player or by AI.
var pitch_input := 0.0 ## + is nose up.
var roll_input := 0.0 ## + is right wing down.
var yaw_input := 0.0 ## + is nose right.
var throttle := 0.75
var speed := 0.0
var is_stalled := false
var is_destroyed := false
var is_crashed := false

var health := 0.0
## Condition of each part, from 1 (intact) to 0 (shot to pieces).
var engine_condition := 1.0
var left_wing_condition := 1.0
var right_wing_condition := 1.0
var tail_condition := 1.0

var _rates := Vector3.ZERO
var _sink_speed := 0.0

@onready var guns: Guns = $Guns
@onready var bombs: BombBay = $BombBay
@onready var _model: Node3D = $Model
@onready var _propeller: Node3D = $Model/Propeller
@onready var _cockpit: Marker3D = $CockpitPoint
@onready var _smoke: CPUParticles3D = $Smoke
@onready var _fire: CPUParticles3D = $Fire


func _ready() -> void:
	add_to_group("aircraft")
	add_to_group("damageable")
	_apply_stats()


## Swaps this plane for another type, e.g. the one picked in the hangar.
func set_stats(new_stats: AircraftStats) -> void:
	stats = new_stats
	_apply_stats()


func _physics_process(delta: float) -> void:
	if is_crashed:
		return
	if player_controlled and not is_destroyed:
		_read_player_input(delta)
	_update_speed(delta)
	_update_rotation(delta)
	_update_lift(delta)
	_move(delta)


func _process(delta: float) -> void:
	if not is_crashed:
		_propeller.rotate_object_local(Vector3.BACK, (0.2 + throttle) * PROPELLER_MAX_SPIN * delta)


## How well the control surfaces work: weak when slow, full at normal speed.
func get_control_authority() -> float:
	return clampf(inverse_lerp(stats.stall_speed * 0.5, stats.stall_speed * 1.3, speed), 0.2, 1.0)


## 0 near stall speed, 1 at (and above) a fast dive.
func get_speed_ratio() -> float:
	return clampf(inverse_lerp(stats.stall_speed, stats.max_speed * 1.2, speed), 0.0, 1.0)


func get_health_ratio() -> float:
	return health / stats.max_health


func get_cockpit_transform() -> Transform3D:
	return _cockpit.global_transform


func is_alive() -> bool:
	return not is_destroyed


func is_hostile_to(other: Aircraft) -> bool:
	return other.team != team


func take_damage(
	amount: float,
	hit_position: Vector3,
	attacker: Aircraft,
	_kind := Damage.Kind.BULLET,
) -> void:
	if is_destroyed:
		return
	health = maxf(health - amount, 0.0)
	_damage_part(to_local(hit_position), amount / stats.max_health * 2.0)
	_smoke.emitting = get_health_ratio() < SMOKE_HEALTH or engine_condition < SMOKE_HEALTH
	damaged.emit(amount, attacker)
	if health <= 0.0:
		_destroy(attacker)


## Restores full health, fixes every part and refills the guns.
func repair() -> void:
	if is_destroyed:
		return
	health = stats.max_health
	engine_condition = 1.0
	left_wing_condition = 1.0
	right_wing_condition = 1.0
	tail_condition = 1.0
	_smoke.emitting = false
	guns.reload()
	bombs.reload()


func _damage_part(local_hit: Vector3, part_damage: float) -> void:
	if local_hit.z < -1.8:
		engine_condition = maxf(engine_condition - part_damage, 0.0)
	elif local_hit.z > 1.8:
		tail_condition = maxf(tail_condition - part_damage, 0.0)
	elif local_hit.x < -1.2:
		left_wing_condition = maxf(left_wing_condition - part_damage, 0.0)
	elif local_hit.x > 1.2:
		right_wing_condition = maxf(right_wing_condition - part_damage, 0.0)


func _destroy(attacker: Aircraft) -> void:
	is_destroyed = true
	health = 0.0
	guns.trigger = false
	_smoke.emitting = true
	_fire.emitting = true
	# The pilot has lost control: the plane spirals towards the ground.
	throttle = 0.0
	pitch_input = -0.3
	roll_input = 0.6 if randf() < 0.5 else -0.6
	yaw_input = 0.0
	auto_level = false
	destroyed.emit(attacker)
	Events.aircraft_destroyed.emit(self, attacker)


func _read_player_input(delta: float) -> void:
	pitch_input = Input.get_axis("pitch_down", "pitch_up")
	roll_input = Input.get_axis("roll_left", "roll_right")
	yaw_input = Input.get_axis("yaw_left", "yaw_right")
	var throttle_change := Input.get_axis("throttle_down", "throttle_up")
	throttle = clampf(throttle + throttle_change * THROTTLE_CHANGE_RATE * delta, 0.0, 1.0)
	guns.trigger = Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("bomb"):
		bombs.drop()


func _update_speed(delta: float) -> void:
	# Sine of the nose angle: climbing costs speed, diving gains it.
	var climb := -global_basis.z.y
	# Drag grows with the square of speed, balancing full thrust exactly at max_speed.
	var drag := stats.thrust * pow(speed / stats.max_speed, 2.0)
	var thrust := stats.thrust * throttle * lerpf(0.3, 1.0, engine_condition)
	var acceleration := thrust - drag - GRAVITY * climb
	speed = maxf(speed + acceleration * delta, 0.0)


func _update_rotation(delta: float) -> void:
	var authority := get_control_authority()
	var wings := (left_wing_condition + right_wing_condition) * 0.5
	var tail := lerpf(0.4, 1.0, tail_condition)
	var target_rates := Vector3(
		pitch_input * stats.pitch_rate * tail,
		-roll_input * stats.roll_rate * lerpf(0.4, 1.0, wings),
		-yaw_input * stats.yaw_rate * tail,
	) * authority
	# A damaged wing lifts less, so the plane rolls towards that side.
	target_rates.y += (right_wing_condition - left_wing_condition) * WING_DAMAGE_ROLL
	# Ease towards the target rates so the plane has a little weight to it.
	_rates = _rates.lerp(target_rates, 1.0 - exp(-stats.control_response * delta))

	rotate_object_local(Vector3.RIGHT, _rates.x * delta)
	rotate_object_local(Vector3.BACK, _rates.y * delta)
	rotate_object_local(Vector3.UP, _rates.z * delta)

	if auto_level and is_zero_approx(roll_input) and global_basis.y.y > 0.0:
		rotate_object_local(Vector3.BACK, -global_basis.x.y * auto_level_strength * authority * delta)

	# Banked wings tilt the lift sideways, which swings the nose round into a turn.
	rotate(Vector3.UP, global_basis.x.y * stats.bank_turn_rate * authority * delta)

	global_basis = global_basis.orthonormalized()


func _update_lift(delta: float) -> void:
	is_stalled = speed < stats.stall_speed

	# Lift fades out as the plane slows, so it starts to sink.
	var lift := clampf(inverse_lerp(stats.stall_speed * 0.5, stats.stall_speed * 1.25, speed), 0.0, 1.0)
	if is_destroyed:
		lift *= 0.3
	var bank := 1.0 - absf(global_basis.y.y)
	var target_sink := (1.0 - lift) * MAX_STALL_SINK + bank * BANK_SINK
	_sink_speed = move_toward(_sink_speed, target_sink, GRAVITY * delta)

	if is_stalled:
		# Swing the nose towards the ground so the plane can dive and regain speed.
		var nose := -global_basis.z
		var axis := nose.cross(Vector3.DOWN)
		if axis.length_squared() > 0.0001:
			var stall_depth := 1.0 - speed / stats.stall_speed
			rotate(axis.normalized(), stats.stall_nose_drop * (0.3 + stall_depth) * delta)


func _move(delta: float) -> void:
	velocity = -global_basis.z * speed + Vector3.DOWN * _sink_speed
	var collision := move_and_collide(velocity * delta)
	if collision:
		var other := collision.get_collider()
		if other.has_method("take_damage"):
			other.take_damage(INF, collision.get_position(), self, Damage.Kind.COLLISION)
		_crash()


func _crash() -> void:
	if not is_destroyed:
		_destroy(null)
	is_crashed = true
	velocity = Vector3.ZERO
	speed = 0.0
	_model.visible = false
	_fire.emitting = false
	collision_layer = 0
	collision_mask = 0

	var explosion := EXPLOSION_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	crashed.emit()
	if not player_controlled:
		get_tree().create_timer(WRECK_CLEANUP_TIME, false).timeout.connect(queue_free)


func _apply_stats() -> void:
	speed = stats.start_speed
	health = stats.max_health
	guns.fire_rate = stats.gun_fire_rate
	guns.damage = stats.gun_damage
	bombs.capacity = stats.bomb_capacity
	bombs.reload()
	_apply_look()


func _apply_look() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = stats.paint_color
	paint.roughness = 0.85
	for part: MeshInstance3D in [$Model/Fuselage, $Model/Fin]:
		part.material_override = paint

	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = stats.wing_color
	canvas.roughness = 0.9
	for wing: MeshInstance3D in [$Model/UpperWing, $Model/LowerWing, $Model/MiddleWing, $Model/Tailplane]:
		wing.material_override = canvas
	for wing: Node3D in [$Model/UpperWing, $Model/LowerWing, $Model/MiddleWing]:
		wing.scale.x = stats.wing_span
	$Model/StrutLeft.position.x = -3.0 * stats.wing_span
	$Model/StrutRight.position.x = 3.0 * stats.wing_span
	$Model/MiddleWing.visible = stats.triplane

	_model.scale = Vector3.ONE * stats.model_scale
	$CollisionShape3D.scale = Vector3(stats.wing_span, 1.0, 1.0) * stats.model_scale
