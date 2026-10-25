extends Node
## The player's options: difficulty, assists, controls, audio and graphics.
## Saved to the user data folder and applied as soon as they change.

signal changed

const SAVE_PATH := "user://settings.cfg"

enum Difficulty { EASY, NORMAL, HARD, ACE }
enum Quality { LOW, MEDIUM, HIGH }
enum WindowMode { WINDOWED, FULLSCREEN }

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
## Actions the player can rebind on the keyboard, with their names in the menu.
const REBINDABLE := {
	pitch_up = "Nose up", pitch_down = "Nose down", roll_left = "Roll left", roll_right = "Roll right",
	yaw_left = "Rudder left", yaw_right = "Rudder right", throttle_up = "Throttle up", throttle_down = "Throttle down",
	fire = "Fire guns", bomb = "Drop bomb", camera_toggle = "Change view", pause = "Pause",
}
const BUSES := ["Master", "Music", "SFX", "UI"]
## Settings written to the save file.
const SAVED := [
	"difficulty", "auto_level", "show_lead_indicator", "show_bomb_sight", "show_markers", "show_help",
	"invert_pitch", "mouse_sensitivity", "key_bindings", "volumes",
	"window_mode", "vsync", "max_fps", "render_scale", "quality", "film_grain",
]

# Gameplay
var difficulty := Difficulty.NORMAL
var auto_level := true
var show_lead_indicator := true
var show_bomb_sight := true
var show_markers := true
var show_help := true
# Controls
var invert_pitch := false
var mouse_sensitivity := 1.0
## action -> physical keycode, only for actions the player has changed.
var key_bindings := {}
# Audio: bus name -> volume from 0 to 1.
var volumes := {Master = 0.8, Music = 0.6, SFX = 0.9, UI = 0.8}
# Graphics
var window_mode := WindowMode.WINDOWED
var vsync := true
var max_fps := 0 ## 0 means unlimited.
var render_scale := 1.0
var quality := Quality.HIGH
var film_grain := true

var _default_keys := {}


func _ready() -> void:
	# Remember the default keys (InputSetup runs first) so they can be restored.
	for action: String in REBINDABLE:
		_default_keys[action] = InputMap.action_get_events(action)
	_load()
	apply()


func difficulty_value(key: String) -> float:
	return DIFFICULTY_SETTINGS[difficulty][key]


func quality_value(key: String) -> Variant:
	return QUALITY_SETTINGS[quality][key]


## Applies everything and saves. Call after changing any setting.
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
	_apply_key_bindings()
	_save()
	changed.emit()


## Rebinds an action to a single key (mouse and gamepad bindings are kept).
func bind_key(action: String, keycode: Key) -> void:
	key_bindings[action] = keycode
	apply()


func reset_controls() -> void:
	key_bindings.clear()
	invert_pitch = false
	mouse_sensitivity = 1.0
	apply()


## The key currently bound to an action, as text for the menu.
func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "-"


func _apply_key_bindings() -> void:
	for action: String in REBINDABLE:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_keys[action]:
			if event is InputEventKey and key_bindings.has(action):
				continue
			InputMap.action_add_event(action, event)
		if key_bindings.has(action):
			var key := InputEventKey.new()
			key.physical_keycode = key_bindings[action]
			InputMap.action_add_event(action, key)


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
