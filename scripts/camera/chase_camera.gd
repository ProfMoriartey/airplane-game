class_name ChaseCamera
extends Camera3D
## Follows a plane from behind (chase view) or from the pilot's seat (cockpit view).
##
## Hold the right mouse button and move the mouse, or use the right stick, to look
## around. The view springs back to straight ahead when released.

enum View { CHASE, COCKPIT }

@export var target_path: NodePath
@export var chase_offset := Vector3(0.0, 3.5, 14.0)
## How far ahead of the plane the chase camera aims.
@export var look_ahead := 25.0
## How tightly the chase camera keeps up with the plane. Lower feels looser.
@export var follow_sharpness := 8.0
@export var base_fov := 70.0
## Extra field of view at high speed, for a sense of speed.
@export var max_fov_boost := 12.0
@export var mouse_look_sensitivity := 0.005
@export var look_return_speed := 4.0

const MAX_LOOK_YAW := 2.6
const MAX_LOOK_PITCH := 1.2
const SHAKE_DECAY := 1.5
const SHAKE_STRENGTH := 0.4

var view := View.CHASE
## Prefix of this camera's player's input actions (see Aircraft.controls).
var controls := ""
## Off for split-screen players using a controller, so the mouse is the keyboard player's.
var mouse_look := true

var _target: Aircraft
var _look := Vector2.ZERO ## x is yaw (+ left), y is pitch (+ up), in radians.
var _mouse_looking := false
var _shake := 0.0


func _ready() -> void:
	top_level = true
	# Lets passing planes' engines rise and fall in pitch.
	doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	fov = base_fov
	if not target_path.is_empty():
		set_target(get_node(target_path))


## Follows a different plane, e.g. a respawned one in split-screen.
func set_target(plane: Aircraft) -> void:
	_target = plane
	view = View.CHASE
	_look = Vector2.ZERO
	global_transform = _desired_transform()


## Whether the player is currently looking well away from straight ahead.
func is_looking_around() -> bool:
	return _look.length() > 0.8


## Adds camera shake, from 0 (none) to 1 (violent).
func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(controls + "camera_toggle"):
		view = View.COCKPIT if view == View.CHASE else View.CHASE
		_target.model.set_cockpit_view(view == View.COCKPIT)
	elif not mouse_look:
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_looking = event.pressed
	elif event is InputEventMouseMotion and _mouse_looking:
		_look -= event.relative * mouse_look_sensitivity * Settings.mouse_sensitivity
		_look = _look.clamp(Vector2(-MAX_LOOK_YAW, -MAX_LOOK_PITCH), Vector2(MAX_LOOK_YAW, MAX_LOOK_PITCH))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	_update_look(delta)
	_target.model.set_head_turn(_look.x)

	var desired := _desired_transform()
	if view == View.COCKPIT:
		global_transform = desired
	else:
		global_transform = global_transform.interpolate_with(desired, 1.0 - exp(-follow_sharpness * delta))

	var target_fov := base_fov + max_fov_boost * _target.get_speed_ratio()
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta))
	_update_shake(delta)


func _update_look(delta: float) -> void:
	var stick := Input.get_vector(controls + "look_left", controls + "look_right", controls + "look_down", controls + "look_up")
	if stick != Vector2.ZERO:
		_look = Vector2(-stick.x * MAX_LOOK_YAW, stick.y * MAX_LOOK_PITCH)
	elif not _mouse_looking:
		_look = _look.lerp(Vector2.ZERO, 1.0 - exp(-look_return_speed * delta))


func _desired_transform() -> Transform3D:
	var look_basis := Basis(Vector3.UP, _look.x) * Basis(Vector3.RIGHT, _look.y)

	if view == View.COCKPIT:
		var cockpit := _target.get_cockpit_transform()
		return Transform3D(cockpit.basis * look_basis, cockpit.origin)

	var plane := _target.global_transform
	var camera_position := plane * (look_basis * chase_offset)
	# Aim ahead of the plane normally, but at the plane itself while looking around.
	var ahead := look_ahead * clampf(1.0 - _look.length(), 0.0, 1.0)
	var focus := plane * Vector3(0.0, 1.5, -ahead)
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(focus, plane.basis.y)


func _update_shake(delta: float) -> void:
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	var strength := _shake * _shake * SHAKE_STRENGTH
	h_offset = randf_range(-strength, strength)
	v_offset = randf_range(-strength, strength)
