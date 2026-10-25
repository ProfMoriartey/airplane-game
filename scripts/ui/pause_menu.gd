class_name PauseMenu
extends CanvasLayer
## Pauses the game with Esc (or Start on a gamepad).

signal restart_requested

## Turned off while other screens (briefing, debrief) are showing.
var enabled := true

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	visible = false
	%ResumeButton.pressed.connect(close)
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%MainMenuButton.pressed.connect(SceneLoader.go_to_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	elif enabled:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
