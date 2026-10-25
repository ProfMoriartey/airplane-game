class_name HUD
extends CanvasLayer
## Flight instruments, weapon and damage status, objectives, radio messages and warnings.

const MS_TO_KMH := 3.6
const BAR_OK := Color(0.75, 0.62, 0.32)
const BAR_DANGER := Color(0.9, 0.25, 0.15)
const BANNER_TIME := 2.0
const DAMAGED_PART := 0.6
## How long each radio message stays up: a base time plus reading time per character.
const RADIO_BASE_TIME := 2.5
const RADIO_TIME_PER_CHARACTER := 0.045
## With this many messages waiting, each one is shown for half as long, to catch up.
const RADIO_BACKLOG := 2

var _plane: Aircraft
var _boundary_warning := false
var _banner_timer := 0.0
var _radio_queue: Array[String] = []
var _radio_timer := 0.0
var _values := {}
var _bars := {}

@onready var _overlay: Control = $CombatOverlay
@onready var _rows: GridContainer = %Rows
@onready var _status: Label = $Status
@onready var _warning: Label = $Warning
@onready var _banner: Label = $Banner
@onready var _message: Label = $Message
@onready var _help: Label = $Help
@onready var _debug: Label = $DebugInfo
@onready var _objectives: Label = $Objectives
@onready var _radio: PanelContainer = $Radio
@onready var _radio_text: Label = $Radio/Text
@onready var _minimap: Minimap = $Minimap


func _ready() -> void:
	for row: String in ["SPEED", "ALTITUDE"]:
		_values[row] = _add_row(row, Label.new())
	for row: String in ["THROTTLE", "HULL", "GUN HEAT"]:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(130, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", _bar_style(BAR_OK))
		_bars[row] = _add_row(row, bar)
	for row: String in ["AMMO", "BOMBS"]:
		_values[row] = _add_row(row, Label.new())


func setup(plane: Aircraft) -> void:
	_plane = plane
	_overlay.plane = plane
	_minimap.plane = plane
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if terrain:
		_minimap.set_terrain(terrain)
	refresh_settings()


## Shows or hides parts of the HUD to match the settings, and lists the
## player's current keys in the controls help.
func refresh_settings() -> void:
	_help.visible = Settings.show_help
	var key := Settings.key_name
	_help.text = "\n".join([
		"%s  -  fire guns" % key.call("fire"),
		"%s  -  drop bomb" % key.call("bomb"),
		"%s / %s  -  nose down / up" % [key.call("pitch_down"), key.call("pitch_up")],
		"%s / %s  -  roll left / right" % [key.call("roll_left"), key.call("roll_right")],
		"%s / %s  -  rudder left / right" % [key.call("yaw_left"), key.call("yaw_right")],
		"%s / %s  -  throttle up / down" % [key.call("throttle_up"), key.call("throttle_down")],
		"%s  -  chase / cockpit view" % key.call("camera_toggle"),
		"%s  -  minimap zoom" % key.call("map_zoom"),
		"Hold right mouse  -  look around",
		"%s  -  pause      F1  -  hide help" % key.call("pause"),
	])


## A message that stays until replaced, e.g. "CRASHED".
func show_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


## A short message that fades by itself, e.g. "ENEMY DOWN".
func flash_banner(text: String) -> void:
	_banner.text = text
	_banner_timer = BANNER_TIME


func show_hit_marker() -> void:
	_overlay.show_hit_marker()


## The line at the top centre, e.g. the wave and kill count, or mission time and score.
func set_status_text(text: String) -> void:
	_status.text = text


func set_objectives(lines: PackedStringArray) -> void:
	_objectives.text = "\n".join(lines)


## Called every frame with the world positions the player should head for.
func set_objective_markers(markers: Array[Vector3]) -> void:
	_overlay.objective_markers = markers
	_minimap.objective_markers = markers


## Queues a radio message, written as "Speaker: message". Action names in
## braces, like {fire}, become the player's key for that action.
func radio(line: String) -> void:
	_radio_queue.append(Settings.fill_keys(line))


func set_boundary_warning(active: bool) -> void:
	_boundary_warning = active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible
	elif event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible


func _process(delta: float) -> void:
	_banner_timer = maxf(_banner_timer - delta, 0.0)
	_banner.modulate.a = clampf(_banner_timer / 0.5, 0.0, 1.0)
	_update_radio(delta)

	if _plane == null:
		return

	var guns := _plane.guns
	_values.SPEED.text = "%d km/h" % roundi(_plane.speed * MS_TO_KMH)
	_values.ALTITUDE.text = "%d m" % roundi(_plane.global_position.y)
	_values.AMMO.text = str(guns.ammo)
	_values.BOMBS.text = str(_plane.bombs.count)
	_set_bar("THROTTLE", _plane.throttle, false)
	_set_bar("HULL", _plane.get_health_ratio(), _plane.get_health_ratio() < 0.35)
	_set_bar("GUN HEAT", guns.heat, guns.heat > 0.8 or guns.is_overheated)

	_warning.text = "\n".join(_collect_warnings())

	if _debug.visible:
		_debug.text = "FPS %d\nauthority %.2f\npitch %.2f  roll %.2f  yaw %.2f\nengine %.2f  wings %.2f/%.2f  tail %.2f" % [
			Engine.get_frames_per_second(),
			_plane.get_control_authority(),
			_plane.pitch_input,
			_plane.roll_input,
			_plane.yaw_input,
			_plane.engine_condition,
			_plane.left_wing_condition,
			_plane.right_wing_condition,
			_plane.tail_condition,
		]


func _add_row(title: String, value: Control) -> Control:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	_rows.add_child(label)
	if value is Label:
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_outline_color", Color.BLACK)
		value.add_theme_constant_override("outline_size", 4)
	_rows.add_child(value)
	return value


func _set_bar(title: String, ratio: float, danger: bool) -> void:
	var bar: ProgressBar = _bars[title]
	bar.value = ratio * 100.0
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = BAR_DANGER if danger else BAR_OK


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func _update_radio(delta: float) -> void:
	_radio_timer -= delta
	if _radio_timer > 0.0:
		return
	if _radio_queue.is_empty():
		_radio.visible = false
		return
	var line: String = _radio_queue.pop_front()
	var parts := line.split(": ", true, 1)
	_radio_text.text = "%s\n%s" % [parts[0].to_upper(), parts[1]] if parts.size() == 2 else line
	_radio.visible = true
	Sound.play_ui("radio", -6.0)
	_radio_timer = RADIO_BASE_TIME + line.length() * RADIO_TIME_PER_CHARACTER
	if _radio_queue.size() >= RADIO_BACKLOG:
		_radio_timer *= 0.5


func _collect_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _plane.is_alive():
		return warnings
	var guns := _plane.guns
	if _plane.is_stalled:
		warnings.append("STALL")
	if guns.is_overheated:
		warnings.append("GUNS OVERHEATED")
	elif guns.is_jammed:
		warnings.append("GUNS JAMMED")
	elif guns.ammo == 0:
		warnings.append("OUT OF AMMO")
	if _plane.engine_condition < DAMAGED_PART:
		warnings.append("ENGINE DAMAGED")
	if minf(_plane.left_wing_condition, _plane.right_wing_condition) < DAMAGED_PART:
		warnings.append("WING DAMAGED")
	if _plane.tail_condition < DAMAGED_PART:
		warnings.append("TAIL DAMAGED")
	if _boundary_warning:
		warnings.append("LEAVING THE AREA - TURN BACK")
	return warnings
