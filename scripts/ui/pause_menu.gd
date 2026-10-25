class_name PauseMenu
extends CanvasLayer
## Pauses the game with Esc (or Start on a gamepad).

signal restart_requested

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

## Turned off while other screens (briefing, debrief) are showing.
var enabled := true

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	visible = false
	%ResumeButton.pressed.connect(close)
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%MainMenuButton.pressed.connect(SceneLoader.go_to_main_menu)
	%SettingsButton.pressed.connect(_open_settings)


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
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
