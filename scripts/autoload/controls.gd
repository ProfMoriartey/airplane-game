extends Node
## Builds the input actions every player flies with, from the default controls
## (InputSetup) and whatever the player has rebound (Settings).
##
## Each player reads actions with their own prefix: "" when playing alone (the
## keyboard and every controller work), or "p1_" / "p2_" in split-screen, where
## each player's actions only listen to that player's own device.

## Every rebuildable control, with its name in the settings menu.
const CONTROLS := {
	pitch_up = "Nose up", pitch_down = "Nose down", roll_left = "Roll left", roll_right = "Roll right",
	yaw_left = "Rudder left", yaw_right = "Rudder right", throttle_up = "Throttle up", throttle_down = "Throttle down",
	throttle_lever_low = "Throttle lever (back)", throttle_lever_high = "Throttle lever (forward)",
	fire = "Fire guns", bomb = "Drop bomb", camera_toggle = "Change view", map_zoom = "Minimap zoom",
	look_left = "Look left", look_right = "Look right", look_up = "Look up", look_down = "Look down",
	restart = "Restart",
}
## Use any connected controller.
const ANY_PAD := -1
## Use no controller.
const NO_PAD := -2
## The throttle lever counts as moved once it travels this far.
const LEVER_MOVE := 0.02
const LEVER_DEADZONE := 0.01

## Split-screen players: prefix -> {keyboard: bool, pad: int}.
var _players := {}
var _lever_last := {}


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: rebuild())


## Sets up split-screen players, e.g. {"p1_": {keyboard = true, pad = NO_PAD}, "p2_": {keyboard = false, pad = 0}}.
func set_players(players: Dictionary) -> void:
	_players = players
	rebuild()


func clear_players() -> void:
	_players.clear()
	rebuild()


func rebuild() -> void:
	_build("", true, ANY_PAD)
	for prefix: String in _players:
		_build(prefix, _players[prefix].keyboard, _players[prefix].pad)


## The throttle lever's position (0 to 1) if it has just been moved, else -1.
## Movement-based so a parked lever never fights the keyboard.
func throttle_lever(prefix: String) -> float:
	if not InputMap.has_action(prefix + "throttle_lever_high"):
		return -1.0
	var position := (Input.get_axis(prefix + "throttle_lever_low", prefix + "throttle_lever_high") + 1.0) * 0.5
	var last: float = _lever_last.get(prefix, position)
	_lever_last[prefix] = position
	return position if absf(position - last) > LEVER_MOVE else -1.0


## Shakes the controller(s) a player is using, if they rumble.
func vibrate(prefix: String, weak: float, strong: float, seconds: float) -> void:
	var pad: int = _players[prefix].pad if _players.has(prefix) else ANY_PAD
	if pad == NO_PAD:
		return
	var devices: Array = Input.get_connected_joypads() if pad == ANY_PAD else [pad]
	for device in devices:
		Input.start_joy_vibration(device, weak, strong, seconds)


## A controller binding as text for the menu, e.g. "A", "Left stick up", "Axis 3+".
func binding_name(binding: Dictionary) -> String:
	if binding.is_empty():
		return "-"
	if Settings.pad_scheme == InputSetup.PadScheme.GAMEPAD:
		if binding.has("button"):
			return BUTTON_NAMES.get(binding.button, "Button %d" % binding.button)
		return AXIS_NAMES.get(Vector2i(binding.axis, binding.dir), "Axis %d%s" % [binding.axis, "+" if binding.dir > 0 else "-"])
	if binding.has("button"):
		return "Button %d" % (binding.button + 1)
	return "Axis %d%s" % [binding.axis + 1, "+" if binding.dir > 0 else "-"]


## The binding for a control in the current controller scheme.
func pad_binding(control: String) -> Dictionary:
	var overrides: Dictionary = Settings.pad_bindings.get(str(Settings.pad_scheme), {})
	if overrides.has(control):
		return overrides[control]
	return InputSetup.PADS[Settings.pad_scheme].get(control, {})


const BUTTON_NAMES := {
	JOY_BUTTON_A: "A / Cross", JOY_BUTTON_B: "B / Circle", JOY_BUTTON_X: "X / Square", JOY_BUTTON_Y: "Y / Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "Left bumper", JOY_BUTTON_RIGHT_SHOULDER: "Right bumper",
	JOY_BUTTON_BACK: "Back / Select", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "Left stick click",
	JOY_BUTTON_RIGHT_STICK: "Right stick click", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const AXIS_NAMES := {
	Vector2i(JOY_AXIS_LEFT_X, -1): "Left stick left", Vector2i(JOY_AXIS_LEFT_X, 1): "Left stick right",
	Vector2i(JOY_AXIS_LEFT_Y, -1): "Left stick up", Vector2i(JOY_AXIS_LEFT_Y, 1): "Left stick down",
	Vector2i(JOY_AXIS_RIGHT_X, -1): "Right stick left", Vector2i(JOY_AXIS_RIGHT_X, 1): "Right stick right",
	Vector2i(JOY_AXIS_RIGHT_Y, -1): "Right stick up", Vector2i(JOY_AXIS_RIGHT_Y, 1): "Right stick down",
	Vector2i(JOY_AXIS_TRIGGER_LEFT, 1): "Left trigger", Vector2i(JOY_AXIS_TRIGGER_RIGHT, 1): "Right trigger",
}


func _build(prefix: String, keyboard: bool, pad: int) -> void:
	for control: String in CONTROLS:
		var action := prefix + control
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		# A throttle lever stays where it's put, so it needs no dead zone.
		InputMap.action_set_deadzone(action, LEVER_DEADZONE if control.begins_with("throttle_lever") else Settings.pad_deadzone)
		if keyboard:
			for event: InputEvent in InputSetup.keyboard[control]:
				if event is InputEventKey and Settings.key_bindings.has(control):
					continue
				InputMap.action_add_event(action, event)
			if Settings.key_bindings.has(control):
				var key := InputEventKey.new()
				key.physical_keycode = Settings.key_bindings[control]
				InputMap.action_add_event(action, key)
		if pad != NO_PAD:
			var event := _pad_event(pad_binding(control), pad)
			if event:
				InputMap.action_add_event(action, event)


func _pad_event(binding: Dictionary, device: int) -> InputEvent:
	if binding.has("button"):
		var button := InputEventJoypadButton.new()
		button.button_index = binding.button
		button.device = device
		return button
	if binding.has("axis"):
		var motion := InputEventJoypadMotion.new()
		motion.axis = binding.axis
		motion.axis_value = binding.dir
		motion.device = device
		return motion
	return null
