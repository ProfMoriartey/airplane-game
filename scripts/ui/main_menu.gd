extends Control
## The title screen.

const CAMPAIGN_SCREEN := "res://scenes/ui/campaign_screen.tscn"
const FREE_FLIGHT := "res://scenes/levels/free_flight.tscn"


func _ready() -> void:
	%MissionButton.pressed.connect(SceneLoader.change_scene.bind(CAMPAIGN_SCREEN))
	%FreeFlightButton.pressed.connect(SceneLoader.change_scene.bind(FREE_FLIGHT))
	%QuitButton.pressed.connect(get_tree().quit)
	%PilotLabel.text = "%s  -  %d career points" % [Ranks.name_of(Profile.rank()), Profile.career_points()]
	%MissionButton.grab_focus()
	Sound.stop_flight_music()
	Sound.play_music("menu_theme")
