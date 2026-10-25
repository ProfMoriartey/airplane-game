extends Control
## The title screen.

const MISSION_1 := "res://scenes/levels/mission_01.tscn"
const FREE_FLIGHT := "res://scenes/levels/free_flight.tscn"


func _ready() -> void:
	%MissionButton.pressed.connect(SceneLoader.change_scene.bind(MISSION_1))
	%FreeFlightButton.pressed.connect(SceneLoader.change_scene.bind(FREE_FLIGHT))
	%QuitButton.pressed.connect(get_tree().quit)
	%MissionButton.grab_focus()
