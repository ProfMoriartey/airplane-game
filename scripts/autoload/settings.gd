extends Node
## The player's options: difficulty, assists, controls, audio and graphics.
## Saved to the user data folder and applied as soon as they change.

signal changed

const SAVE_PATH := "user://settings.cfg"
## Translations (.po files, one per language) are loaded from here.
const LANGUAGE_FOLDER := "res://localization"
## The language the game is written in.
const SOURCE_LANGUAGE := "en"

enum Difficulty { EASY, NORMAL, HARD, ACE }
enum Quality { LOW, MEDIUM, HIGH }
enum WindowMode { WINDOWED, FULLSCREEN }
enum Palette { STANDARD, COLORBLIND }
enum TextSize { NORMAL, LARGE, EXTRA_LARGE }

## How each difficulty changes the enemy: aim error, pause between bursts, and
## how much damage the player takes.
const DIFFICULTY_SETTINGS := {
	Difficulty.EASY: {name = "Easy", enemy_aim = 1.6, enemy_bursts = 1.6, damage_taken = 0.6},
	Difficulty.NORMAL: {name = "Normal", enemy_aim = 1.0, enemy_bursts = 1.0, damage_taken = 1.0},
	Difficulty.HARD: {name = "Hard", enemy_aim = 0.75, enemy_bursts = 0.8, damage_taken = 1.3},
	Difficulty.ACE: {name = "Ace", enemy_aim = 0.5, enemy_bursts = 0.6, damage_taken = 1.6},
}
## Per quality level: shadows, anti-aliasing, how many trees, and how far they're drawn.
const QUALITY_SETTINGS := {
	Quality.LOW: {name = "Low", shadows = false, msaa = Viewport.MSAA_DISABLED, trees = 0.4, tree_distance = 1500.0},
	Quality.MEDIUM: {name = "Medium", shadows = true, msaa = Viewport.MSAA_2X, trees = 0.7, tree_distance = 2100.0},
	Quality.HIGH: {name = "High", shadows = true, msaa = Viewport.MSAA_4X, trees = 1.0, tree_distance = 2600.0},
}
## How many keys or mouse buttons each control can have.
const KEY_SLOTS := 2
## Marker colours. The colour-blind palette swaps red / green for orange / blue
## (from the Okabe-Ito set), which stay apart with every common colour blindness.
const PALETTES := {
	Palette.STANDARD: {
		name = "Standard", enemy = Color(1.0, 0.35, 0.25), friend = Color(0.45, 0.95, 0.5),
		objective = Color(1.0, 0.85, 0.3), optional = Color(0.7, 0.85, 1.0),
	},
	Palette.COLORBLIND: {
		name = "Colour-blind friendly (orange / blue)", enemy = Color(0.95, 0.45, 0.05), friend = Color(0.35, 0.72, 0.95),
		objective = Color(0.95, 0.9, 0.3), optional = Color(0.92, 0.92, 0.92),
	},
}
const TEXT_SCALES := {TextSize.NORMAL: 1.0, TextSize.LARGE: 1.3, TextSize.EXTRA_LARGE: 1.6}
const BUSES := ["Master", "Music", "SFX", "UI"]
## Settings written to the save file.
const SAVED := [
	"difficulty", "auto_level", "show_lead_indicator", "show_bomb_sight", "show_markers", "show_help", "show_minimap", "pause_on_focus_loss",
	"palette", "text_size", "radio_duration", "screen_shake", "language",
	"invert_pitch", "mouse_sensitivity", "key_bindings", "volumes",
	"pad_scheme", "pad_bindings", "pad_deadzone", "rumble",
	"window_mode", "vsync", "max_fps", "render_scale", "quality", "film_grain",
]

# Gameplay
var difficulty := Difficulty.NORMAL
var auto_level := true
var show_lead_indicator := true
var show_bomb_sight := true
var show_markers := true
var show_help := true
var show_minimap := true
var pause_on_focus_loss := true
## Language code like "fr", or "" to follow the computer's language.
var language := ""
# Accessibility
var palette := Palette.STANDARD
var text_size := TextSize.NORMAL
## How long radio messages stay on screen (1 = normal).
var radio_duration := 1.0
## How strongly the camera shakes (0 = never).
var screen_shake := 1.0
# Controls
var invert_pitch := false
var mouse_sensitivity := 1.0
## Keyboard rebinds, only for controls the player has changed:
## control -> KEY_SLOTS bindings, each {key}, {mouse} or {} for none.
var key_bindings := {}
## Which controller layout to use (see InputSetup.PadScheme).
var pad_scheme := 0
## Controller rebinds: scheme number (as text) -> control -> {axis, dir} or {button}.
var pad_bindings := {}
var pad_deadzone := 0.2
var rumble := true
# Audio: bus name -> volume from 0 to 1.
var volumes := {Master = 0.8, Music = 0.6, SFX = 0.9, UI = 0.8}
# Graphics
var window_mode := WindowMode.WINDOWED
var vsync := true
var max_fps := 0 ## 0 means unlimited.
var render_scale := 1.0
var quality := Quality.HIGH
var film_grain := true

func _ready() -> void:
	_load_translations()
	_load()
	apply()


## Every language the game can show: the original English plus each translation found.
func languages() -> Array[String]:
	var codes: Array[String] = [SOURCE_LANGUAGE]
	for code in TranslationServer.get_loaded_locales():
		if not codes.has(code):
			codes.append(code)
	return codes


func _load_translations() -> void:
	for file in ResourceLoader.list_directory(LANGUAGE_FOLDER):
		if file.get_extension() == "po":
			var translation := load(LANGUAGE_FOLDER.path_join(file)) as Translation
			if translation:
				TranslationServer.add_translation(translation)


func difficulty_value(key: String) -> float:
	return DIFFICULTY_SETTINGS[difficulty][key]


## A marker colour from the chosen palette: enemy, friend, objective or optional.
func color(role: String) -> Color:
	return PALETTES[palette][role]


func text_scale() -> float:
	return TEXT_SCALES[text_size]


func quality_value(key: String) -> Variant:
	return QUALITY_SETTINGS[quality][key]


## Applies everything, so a change shows straight away. It isn't kept for the
## next time the game starts until save() is called.
func apply() -> void:
	for bus: String in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == WindowMode.FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	var viewport := get_viewport()
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = quality_value("msaa")
	TranslationServer.set_locale(language if language != "" else OS.get_locale())
	Controls.rebuild()
	changed.emit()


## Writes the current settings to disk.
func save() -> void:
	_save()


## A copy of every saved setting, to compare against or go back to.
func snapshot() -> Dictionary:
	var values := {}
	for key: String in SAVED:
		var value: Variant = get(key)
		values[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return values


## Puts every setting back the way a snapshot had it.
func restore(values: Dictionary) -> void:
	for key: String in values:
		var value: Variant = values[key]
		set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	apply()


func differs_from(values: Dictionary) -> bool:
	return snapshot() != values


## The keys or mouse buttons a control uses, one per slot ({} for an empty slot).
func key_slots(control: String) -> Array:
	if key_bindings.has(control):
		return key_bindings[control]
	var slots := []
	for event: InputEvent in InputSetup.keyboard.get(control, []):
		if slots.size() < KEY_SLOTS:
			slots.append({key = event.physical_keycode} if event is InputEventKey else {mouse = event.button_index})
	while slots.size() < KEY_SLOTS:
		slots.append({})
	return slots


## Puts a key or mouse button ({key} or {mouse}, or {} to clear) in one of a
## control's slots. Returns the name of the control it was taken from, if any.
func bind_key(control: String, slot: int, binding: Dictionary) -> String:
	var taken_from := ""
	if not binding.is_empty():
		for other: String in Controls.CONTROLS:
			var slots := key_slots(other).duplicate()
			var index := slots.find(binding)
			if index >= 0 and not (other == control and index == slot):
				slots[index] = {}
				key_bindings[other] = slots
				taken_from = Controls.CONTROLS[other] if other != control else ""
	var slots := key_slots(control).duplicate()
	slots[slot] = binding
	key_bindings[control] = slots
	apply()
	return taken_from


## Rebinds a controller control (in the current scheme) to a button or axis,
## or clears it with {}. Returns the name of the control it was taken from, if any.
func bind_pad(control: String, binding: Dictionary) -> String:
	var scheme := str(pad_scheme)
	if not pad_bindings.has(scheme):
		pad_bindings[scheme] = {}
	var taken_from := ""
	if not binding.is_empty():
		for other: String in Controls.CONTROLS:
			if other != control and Controls.pad_binding(other) == binding:
				pad_bindings[scheme][other] = {}
				taken_from = Controls.CONTROLS[other]
	pad_bindings[scheme][control] = binding
	# Both ends of the throttle lever are the same axis, so set them together.
	var other_end: String = {throttle_lever_low = "throttle_lever_high", throttle_lever_high = "throttle_lever_low"}.get(control, "")
	if other_end != "" and binding.has("axis"):
		pad_bindings[scheme][other_end] = {axis = binding.axis, dir = -binding.dir}
	apply()
	return taken_from


func reset_keyboard() -> void:
	key_bindings.clear()
	mouse_sensitivity = 1.0
	apply()


func reset_controller() -> void:
	pad_bindings.erase(str(pad_scheme))
	pad_deadzone = 0.2
	apply()


## Replaces action names in braces, like {fire}, with the player's keys.
func fill_keys(text: String) -> String:
	text = tr(text)
	for action: String in Controls.CONTROLS:
		text = text.replace("{%s}" % action, key_name(action))
	return text


## The first key or mouse button bound to an action, as text.
func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
		if event is InputEventMouseButton:
			return binding_text({mouse = event.button_index})
	return "-"


## A keyboard binding ({key} or {mouse}) as text for the menu.
static func binding_text(binding: Dictionary) -> String:
	if binding.has("key"):
		return OS.get_keycode_string(binding.key)
	if binding.has("mouse"):
		return MOUSE_NAMES.get(binding.mouse, TranslationServer.translate("Mouse %d") % binding.mouse)
	return "-"


const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_RIGHT: "Right mouse", MOUSE_BUTTON_MIDDLE: "Middle mouse",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_XBUTTON1: "Mouse back", MOUSE_BUTTON_XBUTTON2: "Mouse forward",
}


func _save() -> void:
	var file := ConfigFile.new()
	for key: String in SAVED:
		file.set_value("settings", key, get(key))
	file.save(SAVE_PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for key: String in SAVED:
		if file.has_section_key("settings", key):
			var value: Variant = file.get_value("settings", key)
			if typeof(value) == typeof(get(key)):
				set(key, value)
	# Older saves kept one keycode per control.
	for control: String in key_bindings.keys():
		if typeof(key_bindings[control]) == TYPE_INT:
			key_bindings[control] = [{key = key_bindings[control]}, {}]
