extends Node
## Registers the game's input actions with default keyboard, mouse and gamepad bindings.
##
## Keeping every default binding here, in code, makes them easy to read and lets a
## future controls menu reset bindings back to these defaults.

const DEADZONE := 0.2


func _enter_tree() -> void:
	# Flight controls. Pitch follows flight-stick convention: pull back (S / stick down) to climb.
	_add("pitch_up", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("pitch_down", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("roll_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("roll_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("yaw_left", [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_add("yaw_right", [_key(KEY_E), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("throttle_up", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add("throttle_down", [_key(KEY_CTRL), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])

	# Weapons (used from the combat milestone onward).
	_add("fire", [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_A)])
	_add("bomb", [_key(KEY_B), _button(JOY_BUTTON_B)])

	# Camera.
	_add("camera_toggle", [_key(KEY_C), _button(JOY_BUTTON_Y)])
	_add("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	# General.
	_add("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_add("restart", [_key(KEY_R), _button(JOY_BUTTON_BACK)])
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


func _axis(axis: JoyAxis, direction: float) -> InputEvent:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
