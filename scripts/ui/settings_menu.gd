extends CanvasLayer
## The settings screen: gameplay, controls, audio and graphics tabs.
## Changes apply (and save) immediately. Works over menus and the pause menu.

signal closed

const PANEL_WIDTH := 920.0
const BINDING_WIDTH := 170.0
const HEADER_COLOR := Color(0.85, 0.7, 0.45)
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

## Keyboard controls that can't use a key: the throttle lever is a controller axis.
const NOT_ON_KEYBOARD := ["throttle_lever_low", "throttle_lever_high"]
## The right mouse button looks around, so it can't be bound.
const RESERVED_MOUSE := [MOUSE_BUTTON_RIGHT]
## An axis must move this far from where it was resting to be picked up.
const AXIS_CAPTURE := 0.6
## The tabs with a reset button, and what it says.
const RESET_LABELS := {"Keyboard & Mouse": "Reset keyboard", "Controller": "Reset controller"}

## The keyboard control and slot waiting for a new key, while rebinding.
var _rebinding := ""
var _rebinding_slot := 0
var _key_buttons := {}
## The control waiting for a controller button or axis, while rebinding.
var _rebinding_pad := ""
var _pad_buttons := {}
## Where each controller axis was resting when rebinding started.
var _axis_rest := {}
var _key_note: Label
var _pad_note: Label
var _connected_note: Label


func _ready() -> void:
	# Wide enough for every tab title.
	$Panel.offset_left = -PANEL_WIDTH / 2
	$Panel.offset_right = PANEL_WIDTH / 2
	%BackButton.pressed.connect(close)
	%ResetButton.pressed.connect(_reset_current_tab)
	%Tabs.tab_changed.connect(func(_tab: int) -> void: _update_reset_button())
	_build_gameplay()
	_build_accessibility()
	_build_keyboard()
	_build_controller()
	_build_audio()
	_build_graphics()
	_update_reset_button()
	_add_controller_hint()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _refresh_connected())
	%Tabs.get_tab_bar().grab_focus()


## A reminder of the controller buttons, next to Reset and Back.
func _add_controller_hint() -> void:
	var hint := Label.new()
	hint.text = "Controller:  LB / RB  change tab    A  choose    B  back"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	%BackButton.get_parent().add_child(hint)
	%BackButton.get_parent().move_child(hint, 0)


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _rebinding != "":
		_capture_key(event)
		return
	if _rebinding_pad != "":
		_capture_pad(event)
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_tab_previous") or event.is_action_pressed("ui_tab_next"):
		get_viewport().set_input_as_handled()
		var step := -1 if event.is_action_pressed("ui_tab_previous") else 1
		%Tabs.current_tab = wrapi(%Tabs.current_tab + step, 0, %Tabs.get_tab_count())
		%Tabs.get_tab_bar().grab_focus()


## Waiting for a key: Esc (or B / Start on a controller) cancels, Delete empties the slot.
func _capture_key(event: InputEvent) -> void:
	var binding := {}
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
		_stop_rebinding("")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_stop_rebinding("")
		elif event.physical_keycode == KEY_DELETE:
			_finish_key({})
		else:
			binding = {key = event.physical_keycode}
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in RESERVED_MOUSE:
			_key_note.text = "The right mouse button is used to look around - pick another."
		else:
			binding = {mouse = event.button_index}
	if not binding.is_empty():
		_finish_key(binding)
	get_viewport().set_input_as_handled()


func _finish_key(binding: Dictionary) -> void:
	var taken := Settings.bind_key(_rebinding, _rebinding_slot, binding)
	_stop_rebinding(tr("%s was used for %s - that slot is empty now.") % [Settings.binding_text(binding), taken] if taken != "" else "")


## Waiting for a controller: a button press, or an axis moved well away from
## where it was resting (so a lever or trigger that sits off-centre isn't
## picked up by accident). Esc or Start cancels, Delete clears.
func _capture_pad(event: InputEvent) -> void:
	var binding := {}
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_stop_rebinding("")
		else:
			binding = {button = event.button_index}
	elif event is InputEventJoypadMotion:
		var moved: float = event.axis_value - _axis_rest.get(Vector2i(event.device, event.axis), 0.0)
		if absf(moved) > AXIS_CAPTURE:
			binding = {axis = event.axis, dir = int(signf(moved))}
	elif event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE:
			_stop_rebinding("")
		elif event.physical_keycode == KEY_DELETE:
			Settings.bind_pad(_rebinding_pad, {})
			_stop_rebinding("")
	if not binding.is_empty():
		var taken := Settings.bind_pad(_rebinding_pad, binding)
		_stop_rebinding(tr("%s was used for %s - that control is empty now.") % [Controls.binding_name(binding), taken] if taken != "" else "")
	get_viewport().set_input_as_handled()


func _stop_rebinding(message: String) -> void:
	_rebinding = ""
	_rebinding_pad = ""
	_refresh_keys()
	_refresh_pads()
	_key_note.text = message
	_pad_note.text = message


## --- Tabs ---

func _build_gameplay() -> void:
	var tab := _tab("Gameplay")
	var difficulties: Array[String] = []
	for level in Settings.DIFFICULTY_SETTINGS.values():
		difficulties.append(level.name)
	_choice(tab, "Difficulty", difficulties, Settings.difficulty, func(index: int) -> void: Settings.difficulty = index)
	_note(tab, "Easy: enemies aim worse and you take less damage. Ace: the opposite.")
	_toggle(tab, "Invert pitch (nose up/down swapped)", Settings.invert_pitch, func(on: bool) -> void: Settings.invert_pitch = on)
	_toggle(tab, "Auto-level wings", Settings.auto_level, func(on: bool) -> void: Settings.auto_level = on)
	_toggle(tab, "Show aiming circle (lead indicator)", Settings.show_lead_indicator, func(on: bool) -> void: Settings.show_lead_indicator = on)
	_toggle(tab, "Show bomb sight", Settings.show_bomb_sight, func(on: bool) -> void: Settings.show_bomb_sight = on)
	_toggle(tab, "Show target markers and arrows", Settings.show_markers, func(on: bool) -> void: Settings.show_markers = on)
	_toggle(tab, "Show controls help", Settings.show_help, func(on: bool) -> void: Settings.show_help = on)
	_toggle(tab, "Show minimap", Settings.show_minimap, func(on: bool) -> void: Settings.show_minimap = on)
	var codes := Settings.languages()
	var names: Array[String] = ["Automatic (same as the computer)"]
	for code in codes:
		names.append(TranslationServer.get_locale_name(code))
	_choice(tab, "Language", names, codes.find(Settings.language) + 1, func(index: int) -> void:
		Settings.language = codes[index - 1] if index > 0 else "")
	_toggle(tab, "Pause when the game window loses focus", Settings.pause_on_focus_loss, func(on: bool) -> void: Settings.pause_on_focus_loss = on)
	var logs := Button.new()
	logs.text = "Open log folder"
	logs.custom_minimum_size = Vector2(200, 0)
	logs.pressed.connect(SceneLoader.session.open_log_folder)
	_row(tab, "Found a bug? Send us the log files", logs)
	_note(tab, tr("Version %s") % SceneLoader.session.version())


func _build_accessibility() -> void:
	var tab := _tab("Accessibility")
	var palettes: Array[String] = []
	for palette in Settings.PALETTES.values():
		palettes.append(palette.name)
	_choice(tab, "Marker colours", palettes, Settings.palette, func(index: int) -> void: Settings.palette = index)
	_note(tab, "Enemy, friendly and objective colours on the HUD, minimap and briefing map.")
	_choice(tab, "Radio and objective text size", ["Normal", "Large", "Extra large"], Settings.text_size, func(index: int) -> void: Settings.text_size = index)
	_slider(tab, "How long radio messages stay", 1.0, 2.5, Settings.radio_duration, func(value: float) -> void: Settings.radio_duration = value)
	_slider(tab, "Screen shake", 0.0, 1.0, Settings.screen_shake, func(value: float) -> void: Settings.screen_shake = value)
	_note(tab, "Every key and button can be changed in the Keyboard & Mouse and Controller tabs. The old-film grain can be turned off under Graphics.")


func _build_keyboard() -> void:
	var tab := _tab("Keyboard & Mouse")
	_slider(tab, "Mouse look sensitivity", 0.3, 2.0, Settings.mouse_sensitivity, func(value: float) -> void: Settings.mouse_sensitivity = value)
	_note(tab, "Each control can have two keys or mouse buttons. Click one, then press the new key or mouse button. Esc cancels, Delete empties it. Hold the right mouse button to look around.")
	_key_note = _warning(tab)
	_header(tab, ["Control", "Primary", "Secondary"])
	for control: String in Controls.CONTROLS:
		if control in NOT_ON_KEYBOARD:
			continue
		var buttons: Array[Button] = []
		for slot in Settings.KEY_SLOTS:
			var button := _binding_button()
			button.pressed.connect(func() -> void:
				_stop_rebinding("")
				_rebinding = control
				_rebinding_slot = slot
				button.text = "Press a key...")
			buttons.append(button)
		_key_buttons[control] = buttons
		_row(tab, Controls.CONTROLS[control], buttons)
	_refresh_keys()


func _build_controller() -> void:
	var tab := _tab("Controller")
	_connected_note = _note(tab, "")
	_refresh_connected()
	_choice(tab, "Layout", ["Gamepad", "Flight stick (with throttle lever)"], Settings.pad_scheme, func(index: int) -> void:
		Settings.pad_scheme = index
		_refresh_pads.call_deferred())
	_slider(tab, "Stick dead zone", 0.05, 0.5, Settings.pad_deadzone, func(value: float) -> void: Settings.pad_deadzone = value)
	_toggle(tab, "Rumble when hit", Settings.rumble, func(on: bool) -> void: Settings.rumble = on)
	_note(tab, "These controls are saved for the chosen layout and work on every controller you connect, in single player and split-screen. Click a control, then press a button or move a stick, trigger or lever. Esc or Start cancels, Delete clears.")
	_pad_note = _warning(tab)
	_header(tab, ["Control", "Button or axis"])
	for control: String in Controls.CONTROLS:
		var button := _binding_button()
		button.pressed.connect(func() -> void:
			_stop_rebinding("")
			_rebinding_pad = control
			_axis_rest.clear()
			for device in Input.get_connected_joypads():
				for axis in JOY_AXIS_MAX:
					_axis_rest[Vector2i(device, axis)] = Input.get_joy_axis(device, axis)
			button.text = "Press or move...")
		_pad_buttons[control] = button
		_row(tab, Controls.CONTROLS[control], [button])
	_refresh_pads()


func _refresh_connected() -> void:
	var connected := Input.get_connected_joypads().map(func(device: int) -> String: return Input.get_joy_name(device))
	_connected_note.text = tr("Connected: %s") % (", ".join(connected) if not connected.is_empty() else tr("none - plug one in to use it"))


func _refresh_pads() -> void:
	for control: String in _pad_buttons:
		_pad_buttons[control].text = Controls.binding_name(Controls.pad_binding(control))


func _refresh_keys() -> void:
	for control: String in _key_buttons:
		var slots := Settings.key_slots(control)
		for slot in Settings.KEY_SLOTS:
			_key_buttons[control][slot].text = Settings.binding_text(slots[slot])


func _update_reset_button() -> void:
	var title: String = %Tabs.get_tab_title(%Tabs.current_tab)
	%ResetButton.visible = RESET_LABELS.has(title)
	%ResetButton.text = RESET_LABELS.get(title, "")


func _reset_current_tab() -> void:
	_stop_rebinding("")
	if %Tabs.get_tab_title(%Tabs.current_tab) == "Controller":
		Settings.reset_controller()
	else:
		Settings.reset_keyboard()
	_refresh_keys()
	_refresh_pads()


func _build_audio() -> void:
	var tab := _tab("Audio")
	var names := {Master = "Master volume", Music = "Music", SFX = "Sound effects", UI = "Menus and radio"}
	for bus: String in Settings.BUSES:
		_slider(tab, names[bus], 0.0, 1.0, Settings.volumes[bus], func(value: float) -> void: Settings.volumes[bus] = value)


func _build_graphics() -> void:
	var tab := _tab("Graphics")
	_toggle(tab, "Fullscreen", Settings.window_mode == Settings.WindowMode.FULLSCREEN, func(on: bool) -> void:
		Settings.window_mode = Settings.WindowMode.FULLSCREEN if on else Settings.WindowMode.WINDOWED)
	var sizes: Array[String] = []
	for size in WINDOW_SIZES:
		sizes.append("%d x %d" % [size.x, size.y])
	_choice(tab, "Window size", sizes, _closest_window_size(), func(index: int) -> void:
		DisplayServer.window_set_size(WINDOW_SIZES[index])
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - WINDOW_SIZES[index]) / 2))
	var qualities: Array[String] = []
	for level in Settings.QUALITY_SETTINGS.values():
		qualities.append(level.name)
	_choice(tab, "Quality", qualities, Settings.quality, func(index: int) -> void: Settings.quality = index)
	_note(tab, "Quality changes shadows, smoothing and how many trees there are (trees change on the next mission).")
	_slider(tab, "Render resolution", 0.5, 1.0, Settings.render_scale, func(value: float) -> void: Settings.render_scale = value)
	_toggle(tab, "V-Sync", Settings.vsync, func(on: bool) -> void: Settings.vsync = on)
	var limits := [0, 30, 60, 120, 144]
	_choice(tab, "Frame rate limit", ["Unlimited", "30", "60", "120", "144"], maxi(limits.find(Settings.max_fps), 0), func(index: int) -> void:
		Settings.max_fps = limits[index])
	_toggle(tab, "Old-film grain and vignette", Settings.film_grain, func(on: bool) -> void: Settings.film_grain = on)


func _closest_window_size() -> int:
	var current := DisplayServer.window_get_size()
	var best := 0
	for index in WINDOW_SIZES.size():
		if absi(WINDOW_SIZES[index].x - current.x) < absi(WINDOW_SIZES[best].x - current.x):
			best = index
	return best


## --- Row builders ---

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	%Tabs.add_child(scroll)
	return box


## A label on the left and one or more controls on the right.
func _row(tab: VBoxContainer, label_text: String, controls: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	for control: Control in (controls if controls is Array else [controls]):
		control.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(control)
	tab.add_child(row)


## Column titles above a binding table, lined up with the rows below.
func _header(tab: VBoxContainer, titles: Array) -> void:
	var columns: Array[Label] = []
	for title: String in titles.slice(1):
		var column := _header_label(title)
		column.custom_minimum_size = Vector2(BINDING_WIDTH, 0)
		column.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.append(column)
	_row(tab, "", columns)
	var first := tab.get_child(-1).get_child(0) as Label
	first.text = tr(titles[0]).to_upper()
	first.add_theme_font_size_override("font_size", 14)
	first.add_theme_color_override("font_color", HEADER_COLOR)


func _header_label(title: String) -> Label:
	var label := Label.new()
	label.text = tr(title).to_upper()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _binding_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BINDING_WIDTH, 0)
	button.clip_text = true
	return button


func _note(tab: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	tab.add_child(label)
	return label


## An (initially empty) line for messages like "that key was moved".
func _warning(tab: VBoxContainer) -> Label:
	var label := _note(tab, "")
	label.add_theme_color_override("font_color", Color(1, 0.6, 0.45))
	return label


func _toggle(tab: VBoxContainer, label_text: String, value: bool, on_change: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		Settings.apply())
	_row(tab, label_text, toggle)


func _choice(tab: VBoxContainer, label_text: String, options: Array, selected: int, on_change: Callable) -> void:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(200, 0)
	for option: String in options:
		picker.add_item(option)
	picker.select(selected)
	picker.item_selected.connect(func(index: int) -> void:
		on_change.call(index)
		Settings.apply())
	_row(tab, label_text, picker)


func _slider(tab: VBoxContainer, label_text: String, minimum: float, maximum: float, value: float, on_change: Callable) -> void:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(220, 24)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void:
		on_change.call(new_value)
		Settings.apply())
	_row(tab, label_text, slider)
