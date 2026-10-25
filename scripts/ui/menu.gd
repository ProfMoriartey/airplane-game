extends Control
## The main menu.

const CAMPAIGN_SCREEN := "res://scenes/ui/campaign_screen.tscn"
const QUICK_BATTLE := "res://scenes/ui/quick_battle_screen.tscn"
const HANGAR := "res://scenes/ui/hangar.tscn"
const CREDITS := "res://scenes/ui/credits.tscn"
const TRAINING := "res://scenes/levels/training.tscn"
const DUELS := "res://scenes/ui/duels_screen.tscn"
const TWO_PLAYERS := "res://scenes/ui/two_player_screen.tscn"
const PILOTS := "res://scenes/ui/pilots_screen.tscn"
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
	_add_pilot_button()
	# New pilots start with training; everyone else goes straight to the campaign.
	if Profile.totals().missions_flown == 0:
		%TrainingButton.grab_focus()
	else:
		%CampaignButton.grab_focus()
	Sound.stop_flight_music()
	Sound.play_music("menu_theme")
	if SceneLoader.session.crashed_last_time and not SceneLoader.session.crash_reported:
		_report_crash.call_deferred()


## Who is flying, and a way to switch pilots, in place of the plain pilot label.
func _add_pilot_button() -> void:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = tr("%s  -  %s  -  %d pts    (change)") % [Profile.pilot_name(), Ranks.name_of(Profile.rank()), Profile.career_points()]
	button.tooltip_text = "Change pilot"
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 16)
	# Line the text up with the title, like the label it replaces.
	for style in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxEmpty.new() if style != "focus" else button.get_theme_stylebox("focus").duplicate()
		box.content_margin_left = 0
		button.add_theme_stylebox_override(style, box)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, %PilotLabel.get_theme_color("font_color"))
	button.pressed.connect(SceneLoader.change_scene.bind(PILOTS))
	%PilotLabel.add_sibling(button)
	%PilotLabel.visible = false


## Says sorry if the game closed unexpectedly last time, and offers the logs.
func _report_crash() -> void:
	SceneLoader.session.crash_reported = true
	var dialog := AcceptDialog.new()
	dialog.title = "Sorry about that"
	dialog.dialog_text = "The game closed unexpectedly last time.\nYour progress is saved after every mission, so nothing should be lost.\n\nIf this keeps happening, please send us the log files from the log folder."
	dialog.add_button("Open log folder", false, "logs")
	dialog.custom_action.connect(func(_action: StringName) -> void: SceneLoader.session.open_log_folder())
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	dialog.get_ok_button().grab_focus()


func _open_settings() -> void:
	var settings := SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.closed.connect(%SettingsButton.grab_focus)
