extends Control
## The main menu.

const CAMPAIGN_SCREEN := "res://scenes/ui/campaign_screen.tscn"
const QUICK_BATTLE := "res://scenes/ui/quick_battle_screen.tscn"
const HANGAR := "res://scenes/ui/hangar.tscn"
const CREDITS := "res://scenes/ui/credits.tscn"
const TRAINING := "res://scenes/levels/training.tscn"
const DUELS := "res://scenes/ui/duels_screen.tscn"
const TWO_PLAYERS := "res://scenes/ui/two_player_screen.tscn"
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")


func _ready() -> void:
	%TrainingButton.pressed.connect(SceneLoader.change_scene.bind(TRAINING))
	%CampaignButton.pressed.connect(SceneLoader.change_scene.bind(CAMPAIGN_SCREEN))
	%DuelsButton.pressed.connect(SceneLoader.change_scene.bind(DUELS))
	%QuickBattleButton.pressed.connect(SceneLoader.change_scene.bind(QUICK_BATTLE))
	%HangarButton.pressed.connect(SceneLoader.change_scene.bind(HANGAR))
	%TwoPlayerButton.pressed.connect(SceneLoader.change_scene.bind(TWO_PLAYERS))
	%SettingsButton.pressed.connect(_open_settings)
	%CreditsButton.pressed.connect(SceneLoader.change_scene.bind(CREDITS))
	%QuitButton.pressed.connect(get_tree().quit)
	# There's nothing to quit to on the web.
	%QuitButton.visible = OS.get_name() != "Web"
	%PilotLabel.text = "%s  -  %d career points" % [Ranks.name_of(Profile.rank()), Profile.career_points()]
	# New pilots start with training; everyone else goes straight to the campaign.
	if Profile.totals().missions_flown == 0:
		%TrainingButton.grab_focus()
	else:
		%CampaignButton.grab_focus()
	Sound.stop_flight_music()
	Sound.play_music("menu_theme")


func _open_settings() -> void:
	var settings := SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.closed.connect(%SettingsButton.grab_focus)
