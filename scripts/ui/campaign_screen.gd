extends Control
## The campaign map: theaters and missions, the pilot's rank, and the service record.

const LOCKED_COLOR := Color(0.5, 0.48, 0.44)

var _selected: MissionInfo


func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%RecordButton.pressed.connect(_show_record)
	%CloseRecordButton.pressed.connect(func() -> void: %RecordPanel.visible = false)
	%ResetButton.pressed.connect(func() -> void: %ResetDialog.popup_centered())
	%ResetDialog.confirmed.connect(_reset)
	%FlyButton.pressed.connect(func() -> void: SceneLoader.change_scene(_selected.scene))
	_refresh()
	Sound.stop_flight_music()
	Sound.play_music("menu_theme")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if %RecordPanel.visible:
		%RecordPanel.visible = false
	else:
		SceneLoader.go_to_main_menu()


func _refresh() -> void:
	_show_pilot()
	_build_mission_list()
	_select(Profile.next_mission())


func _show_pilot() -> void:
	var points := Profile.career_points()
	var rank := Profile.rank()
	%RankLabel.text = Ranks.name_of(rank)
	var next := Ranks.next_threshold(rank)
	if next < 0:
		%PointsBar.value = 100.0
		%PointsLabel.text = "%d career points - highest rank" % points
	else:
		var floor_points: int = Ranks.RANKS[rank].points
		%PointsBar.value = 100.0 * (points - floor_points) / (next - floor_points)
		%PointsLabel.text = "%d / %d points to %s" % [points, next, Ranks.name_of(rank + 1)]


func _build_mission_list() -> void:
	for child in %MissionList.get_children():
		child.queue_free()
	var number := 0
	for theater in Profile.CAMPAIGN.theaters:
		var header := Label.new()
		header.text = theater.title.to_upper()
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", Color(0.85, 0.7, 0.45))
		%MissionList.add_child(header)
		for mission in theater.missions:
			number += 1
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, 38)
			button.add_theme_font_size_override("font_size", 16)
			if not Profile.is_unlocked(mission.id):
				button.text = "%d. %s   (locked)" % [number, mission.title]
				button.disabled = true
			elif Profile.is_completed(mission.id):
				button.text = "%d. %s   - %d" % [number, mission.title, Profile.best_score(mission.id)]
			else:
				button.text = "%d. %s   - NEW" % [number, mission.title]
			button.pressed.connect(_select.bind(mission))
			%MissionList.add_child(button)


func _select(mission: MissionInfo) -> void:
	_selected = mission
	var theater: TheaterInfo = Profile.CAMPAIGN.theaters[Profile.CAMPAIGN.theater_index_of(mission.id)]
	%TheaterTitle.text = theater.title.to_upper()
	%TheaterIntro.text = theater.intro
	%MissionTitle.text = mission.title
	%MissionSummary.text = mission.summary
	if Profile.is_completed(mission.id):
		%MissionBest.text = "Completed - best score %d" % Profile.best_score(mission.id)
	else:
		%MissionBest.text = ""
	%FlyButton.disabled = not Profile.is_unlocked(mission.id)
	%FlyButton.grab_focus()


func _show_record() -> void:
	var totals := Profile.totals()
	var accuracy := "-" if totals.shots == 0 else "%d%%" % roundi(100.0 * totals.hits / totals.shots)
	var lines: PackedStringArray = [
		"[b]%s[/b] - %d career points" % [Ranks.name_of(Profile.rank()), Profile.career_points()],
		"",
		"Missions flown: %d   (won %d)" % [totals.missions_flown, totals.missions_won],
		"Aircraft shot down: %d" % totals.air_kills,
		"Ground targets destroyed: %d   (balloons %d)" % [totals.ground_kills, totals.balloons],
		"Gun accuracy: %s" % accuracy,
		"",
		"[b]MEDALS[/b]  (%d / %d)" % [Profile.medals().size(), Medals.MEDALS.size()],
	]
	for medal in Medals.MEDALS:
		if Profile.medals().has(medal.id):
			lines.append("[color=#f2cc80]%s[/color] - %s" % [medal.name, medal.description])
		else:
			lines.append("[color=#77746c]%s - %s[/color]" % [medal.name, medal.description])
	lines.append("")
	lines.append("[b]AIRCRAFT[/b]")
	for aircraft in Profile.PLAYER_AIRCRAFT:
		if aircraft.unlock_rank <= Profile.rank():
			lines.append("[color=#f2cc80]%s[/color] - %s" % [aircraft.display_name, aircraft.description])
		else:
			lines.append("[color=#77746c]%s - unlocks at %s[/color]" % [aircraft.display_name, Ranks.name_of(aircraft.unlock_rank)])
	%RecordText.text = "\n".join(lines)
	%RecordPanel.visible = true
	%CloseRecordButton.grab_focus()


func _reset() -> void:
	Profile.reset()
	_refresh()
