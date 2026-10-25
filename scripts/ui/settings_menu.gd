extends CanvasLayer
## The settings screen: gameplay, controls, audio and graphics tabs.
## Changes apply (and save) immediately. Works over menus and the pause menu.

signal closed

const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

## The action waiting for a new key, while rebinding.
var _rebinding := ""
var _key_buttons := {}


func _ready() -> void:
	%BackButton.pressed.connect(close)
	%ResetButton.pressed.connect(func() -> void:
		Settings.reset_controls()
		_refresh_keys())
	_build_gameplay()
	_build_controls()
	_build_audio()
	_build_graphics()
	%Tabs.get_tab_bar().grab_focus()


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _rebinding != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode != KEY_ESCAPE:
				Settings.bind_key(_rebinding, event.physical_keycode)
			_rebinding = ""
			_refresh_keys()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


## --- Tabs ---

func _build_gameplay() -> void:
	var tab := _tab("Gameplay")
	var difficulties: Array[String] = []
	for level in Settings.DIFFICULTY_SETTINGS.values():
		difficulties.append(level.name)
	_choice(tab, "Difficulty", difficulties, Settings.difficulty, func(index: int) -> void: Settings.difficulty = index)
	_note(tab, "Easy: enemies aim worse and you take less damage. Ace: the opposite.")
	_toggle(tab, "Auto-level wings", Settings.auto_level, func(on: bool) -> void: Settings.auto_level = on)
	_toggle(tab, "Show aiming circle (lead indicator)", Settings.show_lead_indicator, func(on: bool) -> void: Settings.show_lead_indicator = on)
	_toggle(tab, "Show bomb sight", Settings.show_bomb_sight, func(on: bool) -> void: Settings.show_bomb_sight = on)
	_toggle(tab, "Show target markers and arrows", Settings.show_markers, func(on: bool) -> void: Settings.show_markers = on)
	_toggle(tab, "Show controls help", Settings.show_help, func(on: bool) -> void: Settings.show_help = on)


func _build_controls() -> void:
	var tab := _tab("Controls")
	_toggle(tab, "Invert pitch (W / stick up climbs)", Settings.invert_pitch, func(on: bool) -> void: Settings.invert_pitch = on)
	_slider(tab, "Mouse look sensitivity", 0.3, 2.0, Settings.mouse_sensitivity, func(value: float) -> void: Settings.mouse_sensitivity = value)
	_note(tab, "Click a key, then press the new key (Esc cancels). Gamepad controls stay as they are.")
	for action: String in Settings.REBINDABLE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 0)
		button.pressed.connect(func() -> void:
			_rebinding = action
			button.text = "Press a key...")
		_key_buttons[action] = button
		_row(tab, Settings.REBINDABLE[action], button)
	_refresh_keys()


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


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		_key_buttons[action].text = Settings.key_name(action)


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


func _row(tab: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(control)
	tab.add_child(row)


func _note(tab: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	tab.add_child(label)


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
