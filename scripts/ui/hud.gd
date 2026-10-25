extends CanvasLayer
## Flight instruments, warnings and on-screen messages.

const MS_TO_KMH := 3.6

var _plane: Aircraft
var _boundary_warning := false

@onready var _flight_info: Label = $FlightInfo
@onready var _warning: Label = $Warning
@onready var _message: Label = $Message
@onready var _help: Label = $Help
@onready var _debug: Label = $DebugInfo


func setup(plane: Aircraft) -> void:
	_plane = plane


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


func set_boundary_warning(active: bool) -> void:
	_boundary_warning = active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible
	elif event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible


func _process(_delta: float) -> void:
	if _plane == null:
		return

	_flight_info.text = "SPEED  %d km/h\nALT    %d m\nTHR    %d%%" % [
		roundi(_plane.speed * MS_TO_KMH),
		roundi(_plane.global_position.y),
		roundi(_plane.throttle * 100.0),
	]

	var warnings: PackedStringArray = []
	if _plane.is_stalled and not _plane.is_crashed:
		warnings.append("STALL")
	if _boundary_warning:
		warnings.append("LEAVING THE AREA - TURN BACK")
	_warning.text = "\n".join(warnings)

	if _debug.visible:
		_debug.text = "FPS %d\nauthority %.2f\npitch %.2f  roll %.2f  yaw %.2f" % [
			Engine.get_frames_per_second(),
			_plane.get_control_authority(),
			_plane.pitch_input,
			_plane.roll_input,
			_plane.yaw_input,
		]
