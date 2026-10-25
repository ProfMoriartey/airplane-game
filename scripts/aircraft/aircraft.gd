class_name Aircraft
extends CharacterBody3D
## Arcade flight model shared by the player's and (later) enemy aircraft.
##
## Speed is a single number along the nose. Engine thrust, air drag and gravity
## (when climbing or diving) change it. Below stall speed the wings lose lift,
## the plane sinks and its nose drops until it gains speed again.

signal crashed

const GRAVITY := 9.8
const THROTTLE_CHANGE_RATE := 0.6
const MAX_STALL_SINK := 25.0
## Extra sink at a 90° bank, so steep turns need back-pressure on the stick.
const BANK_SINK := 8.0
const PROPELLER_MAX_SPIN := 60.0

@export var stats: AircraftStats
@export var player_controlled := true
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
var is_crashed := false

var _rates := Vector3.ZERO
var _sink_speed := 0.0

@onready var _propeller: Node3D = $Model/Propeller
@onready var _cockpit: Marker3D = $CockpitPoint


func _ready() -> void:
	speed = stats.start_speed


func _physics_process(delta: float) -> void:
	if is_crashed:
		return
	if player_controlled:
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


func get_cockpit_transform() -> Transform3D:
	return _cockpit.global_transform


func _read_player_input(delta: float) -> void:
	pitch_input = Input.get_axis("pitch_down", "pitch_up")
	roll_input = Input.get_axis("roll_left", "roll_right")
	yaw_input = Input.get_axis("yaw_left", "yaw_right")
	var throttle_change := Input.get_axis("throttle_down", "throttle_up")
	throttle = clampf(throttle + throttle_change * THROTTLE_CHANGE_RATE * delta, 0.0, 1.0)


func _update_speed(delta: float) -> void:
	# Sine of the nose angle: climbing costs speed, diving gains it.
	var climb := -global_basis.z.y
	# Drag grows with the square of speed, balancing full thrust exactly at max_speed.
	var drag := stats.thrust * pow(speed / stats.max_speed, 2.0)
	var acceleration := stats.thrust * throttle - drag - GRAVITY * climb
	speed = maxf(speed + acceleration * delta, 0.0)


func _update_rotation(delta: float) -> void:
	var authority := get_control_authority()
	var target_rates := Vector3(
		pitch_input * stats.pitch_rate,
		-roll_input * stats.roll_rate,
		-yaw_input * stats.yaw_rate,
	) * authority
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
	if move_and_collide(velocity * delta):
		_crash()


func _crash() -> void:
	is_crashed = true
	velocity = Vector3.ZERO
	speed = 0.0
	crashed.emit()
