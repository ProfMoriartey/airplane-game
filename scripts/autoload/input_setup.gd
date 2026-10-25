extends Node
## The game's default controls: keyboard and mouse keys, plus two controller
## layouts (a gamepad, and a flight stick with a throttle lever).
##
## The Controls autoload turns these, plus anything the player has rebound,
## into input actions. Only the pause key and a few debug keys are registered
## here directly, because every player shares them.

const DEADZONE := 0.2

enum PadScheme { GAMEPAD, FLIGHT_STICK }

## Controller defaults, per scheme. Each binding is {axis, dir} or {button}.
## Pitch follows flight-stick convention: pull back (stick down) to climb.
const PADS := {
	PadScheme.GAMEPAD: {
		pitch_up = {axis = JOY_AXIS_LEFT_Y, dir = 1}, pitch_down = {axis = JOY_AXIS_LEFT_Y, dir = -1},
		roll_left = {axis = JOY_AXIS_LEFT_X, dir = -1}, roll_right = {axis = JOY_AXIS_LEFT_X, dir = 1},
		yaw_left = {button = JOY_BUTTON_LEFT_SHOULDER}, yaw_right = {button = JOY_BUTTON_RIGHT_SHOULDER},
		throttle_up = {axis = JOY_AXIS_TRIGGER_RIGHT, dir = 1}, throttle_down = {axis = JOY_AXIS_TRIGGER_LEFT, dir = 1},
		fire = {button = JOY_BUTTON_A}, bomb = {button = JOY_BUTTON_B},
		camera_toggle = {button = JOY_BUTTON_Y}, map_zoom = {button = JOY_BUTTON_DPAD_DOWN},
		restart = {button = JOY_BUTTON_BACK},
		look_left = {axis = JOY_AXIS_RIGHT_X, dir = -1}, look_right = {axis = JOY_AXIS_RIGHT_X, dir = 1},
		look_up = {axis = JOY_AXIS_RIGHT_Y, dir = -1}, look_down = {axis = JOY_AXIS_RIGHT_Y, dir = 1},
	},
	# Typical joystick: X/Y axes for the stick, a twist axis for the rudder, a
	# throttle lever, and the trigger and thumb buttons. Sticks differ a lot, so
	# players can rebind every one of these in Settings.
	PadScheme.FLIGHT_STICK: {
		pitch_up = {axis = 1, dir = 1}, pitch_down = {axis = 1, dir = -1},
		roll_left = {axis = 0, dir = -1}, roll_right = {axis = 0, dir = 1},
		yaw_left = {axis = 2, dir = -1}, yaw_right = {axis = 2, dir = 1},
		throttle_lever_low = {axis = 3, dir = 1}, throttle_lever_high = {axis = 3, dir = -1},
		fire = {button = 0}, bomb = {button = 1},
		camera_toggle = {button = 2}, map_zoom = {button = 3},
		restart = {button = 6},
		look_left = {button = JOY_BUTTON_DPAD_LEFT}, look_right = {button = JOY_BUTTON_DPAD_RIGHT},
		look_up = {button = JOY_BUTTON_DPAD_UP}, look_down = {button = JOY_BUTTON_DPAD_DOWN},
	},
}

## Keyboard and mouse defaults for each control (filled in when the game starts).
var keyboard := {}


func _enter_tree() -> void:
	keyboard = {
		pitch_up = [_key(KEY_S), _key(KEY_DOWN)],
		pitch_down = [_key(KEY_W), _key(KEY_UP)],
		roll_left = [_key(KEY_A), _key(KEY_LEFT)],
		roll_right = [_key(KEY_D), _key(KEY_RIGHT)],
		yaw_left = [_key(KEY_Q)],
		yaw_right = [_key(KEY_E)],
		throttle_up = [_key(KEY_SHIFT)],
		throttle_down = [_key(KEY_CTRL)],
		fire = [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT)],
		bomb = [_key(KEY_B)],
		camera_toggle = [_key(KEY_C)],
		map_zoom = [_key(KEY_M)],
		restart = [_key(KEY_R)],
		look_left = [], look_right = [], look_up = [], look_down = [],
		throttle_lever_low = [], throttle_lever_high = [],
	}
	# Shared by everyone: any keyboard or controller can pause the game.
	_add("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_add("toggle_help", [_key(KEY_F1)])
	_add("toggle_debug", [_key(KEY_F3)])


func _add(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


func _key(keycode: Key) -> InputEvent:
	var event := InputEventKey.new()
	# Physical keycodes keep the same key positions on non-QWERTY layouts.
	event.physical_keycode = keycode
	return event


func _mouse(button: MouseButton) -> InputEvent:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _button(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
