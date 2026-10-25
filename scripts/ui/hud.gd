extends CanvasLayer
## Flight instruments, weapon and damage status, warnings and on-screen messages.

const MS_TO_KMH := 3.6
const HEAT_BAR_LENGTH := 10
const BANNER_TIME := 2.0
const DAMAGED_PART := 0.6

var _plane: Aircraft
var _boundary_warning := false
var _banner_timer := 0.0

@onready var _overlay: Control = $CombatOverlay
@onready var _flight_info: Label = $FlightInfo
@onready var _score: Label = $Score
@onready var _warning: Label = $Warning
@onready var _banner: Label = $Banner
@onready var _message: Label = $Message
@onready var _help: Label = $Help
@onready var _debug: Label = $DebugInfo


func setup(plane: Aircraft) -> void:
	_plane = plane
	_overlay.plane = plane


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


func set_score(wave: int, kills: int) -> void:
	_score.text = "WAVE %d     KILLS %d" % [wave, kills]


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

	if _plane == null:
		return

	var guns := _plane.guns
	var heat_bars := roundi(guns.heat * HEAT_BAR_LENGTH)
	_flight_info.text = "SPEED  %d km/h\nALT    %d m\nTHR    %d%%\n\nHULL   %d%%\nAMMO   %d\nHEAT   [%s%s]" % [
		roundi(_plane.speed * MS_TO_KMH),
		roundi(_plane.global_position.y),
		roundi(_plane.throttle * 100.0),
		roundi(_plane.get_health_ratio() * 100.0),
		guns.ammo,
		"#".repeat(heat_bars),
		"-".repeat(HEAT_BAR_LENGTH - heat_bars),
	]

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
