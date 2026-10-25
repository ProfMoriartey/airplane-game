class_name PauseMenu
extends CanvasLayer
## Pauses the game with Esc (or Start on a gamepad). It also pauses by itself
## when the game window loses focus (if that setting is on) or a controller is
## unplugged, so nobody gets shot down while they're away.

signal restart_requested

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

## Turned off while other screens (briefing, debrief) are showing.
var enabled := true

@onready var _resume_button: Button = %ResumeButton
var _reason: Label


func _ready() -> void:
	visible = false
	%ResumeButton.pressed.connect(close)
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%MainMenuButton.pressed.connect(SceneLoader.go_to_main_menu)
	%SettingsButton.pressed.connect(_open_settings)
	_reason = Label.new()
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.add_theme_font_size_override("font_size", 15)
	_reason.add_theme_color_override("font_color", Color(1, 0.6, 0.45))
	$Box/Title.add_sibling(_reason)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Settings.pause_on_focus_loss and not visible and enabled:
		open()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not enabled or not is_inside_tree():
		return
	if connected:
		if visible and _reason.text != "":
			_reason.text = "Controller reconnected - press Resume when you're ready."
		return
	if not visible:
		open()
	_reason.text = tr("Controller %d was disconnected.\nPlug it back in, or carry on with another device.") % (device + 1)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	elif enabled:
		open()
	get_viewport().set_input_as_handled()


func _open_settings() -> void:
	var settings := SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.closed.connect(func() -> void:
		%SettingsButton.grab_focus()
		# The HUD's help box follows the setting.
		get_tree().call_group("hud", "refresh_settings"))


func open() -> void:
	_reason.text = ""
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
