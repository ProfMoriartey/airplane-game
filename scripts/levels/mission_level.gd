extends Level
## A level that runs a Mission: briefing first, then objectives, scoring,
## radio messages, and a debrief when it's over. The result is saved to the
## player's career.

const BRIEFING_SCENE := preload("res://scenes/ui/briefing.tscn")
const DEBRIEF_SCENE := preload("res://scenes/ui/debrief.tscn")
const DEBRIEF_DELAY := 3.0
const AIRCRAFT_SCORE := 100

var _elapsed := 0.0
var _air_kills := 0
var _ground_kills := 0
var _score := 0
var _balloons := 0
var _damage_taken := 0.0
var _aces_downed: Array[String] = []

@onready var mission: Mission = $Mission


func _ready() -> void:
	super()
	mission.objective_started.connect(_on_objective_started)
	mission.objective_completed.connect(_on_objective_completed)
	mission.completed.connect(_on_mission_completed)
	mission.failed.connect(_on_mission_failed)
	Events.aircraft_destroyed.connect(_on_aircraft_destroyed)
	Events.ground_target_destroyed.connect(_on_ground_target_destroyed)
	var aircraft := Profile.selected_aircraft()
	player.set_stats(aircraft, Profile.livery_of(aircraft.id))
	Sound.play_music("menu_theme")
	_show_briefing()


func _process(delta: float) -> void:
	if mission.player == null:
		return
	if not mission.is_finished:
		_elapsed += delta

	var lines: PackedStringArray = []
	var markers: Array[Vector3] = []
	for objective in mission.get_active_objectives():
		var line := Settings.fill_keys(objective.description)
		var progress := objective.get_progress_text()
		if progress != "":
			line += "  %s" % progress
		lines.append(tr("(Bonus) %s") % line if objective.optional else line)
		if not objective.optional:
			markers.append_array(objective.get_markers())
	hud.set_objectives(lines)
	hud.set_objective_markers(markers)
	hud.set_status_text(tr("TIME %s     SCORE %d") % [_format_time(_elapsed), _score])


func _show_briefing() -> void:
	var briefing := BRIEFING_SCENE.instantiate()
	add_child(briefing)
	briefing.setup(mission, terrain, player)
	briefing.aircraft_selected.connect(_on_aircraft_selected)
	pause_menu.enabled = false
	hud.visible = false
	get_tree().paused = true
	await briefing.start_pressed
	briefing.queue_free()
	get_tree().paused = false
	pause_menu.enabled = true
	hud.visible = true
	for line in mission.intro_radio:
		hud.radio(line)
	Sound.start_flight_music()
	mission.start(player)


func _on_aircraft_selected(aircraft: AircraftStats) -> void:
	Profile.select_aircraft(aircraft.id)
	player.set_stats(aircraft, Profile.livery_of(aircraft.id))


func _on_objective_started(objective: Objective) -> void:
	for line in objective.radio_on_start:
		hud.radio(line)


func _on_objective_completed(objective: Objective) -> void:
	_score += objective.score_bonus
	hud.flash_banner("BONUS COMPLETE" if objective.optional else "OBJECTIVE COMPLETE")
	for line in objective.radio_on_complete:
		hud.radio(line)


func _on_aircraft_destroyed(aircraft: Aircraft, attacker: Aircraft) -> void:
	if aircraft != player and attacker == player:
		_air_kills += 1
		_score += AIRCRAFT_SCORE
		if aircraft.pilot_name != "":
			_aces_downed.append(aircraft.pilot_name)
			hud.flash_banner(tr("%s SHOT DOWN!") % tr(aircraft.pilot_name).to_upper())
		else:
			hud.flash_banner("ENEMY DOWN")


func _on_ground_target_destroyed(target: GroundTarget, attacker: Aircraft) -> void:
	if attacker == player:
		_ground_kills += 1
		_score += target.score_value
		if target is Balloon:
			_balloons += 1
		hud.flash_banner(tr("%s DESTROYED") % tr(target.display_name).to_upper())


func _on_player_damaged(amount: float, attacker: Aircraft) -> void:
	super(amount, attacker)
	_damage_taken += amount


func _on_player_destroyed(attacker: Aircraft) -> void:
	mission.fail("You were shot down." if attacker else "You crashed.")


func _on_mission_completed() -> void:
	hud.flash_banner("MISSION COMPLETE")
	_show_debrief(true, "")


func _on_mission_failed(reason: String) -> void:
	hud.flash_banner("MISSION FAILED")
	_show_debrief(false, reason)


func _show_debrief(success: bool, reason: String) -> void:
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	Sound.stop_flight_music()
	Sound.play_music("victory" if success else "defeat")
	pause_menu.close()
	pause_menu.enabled = false
	hud.visible = false
	get_tree().paused = true

	var shots := player.guns.shots_fired
	var accuracy := "-" if shots == 0 else "%d%%" % roundi(100.0 * player_hits / shots)
	var stats := [
		["Time", _format_time(_elapsed)],
		["Objectives", "%d / %d" % [mission.count_objectives(false, true), mission.count_objectives(false, false)]],
		["Bonus objectives", "%d / %d" % [mission.count_objectives(true, true), mission.count_objectives(true, false)]],
		["Aircraft shot down", _air_kills],
		["Ground targets destroyed", _ground_kills],
		["Gun accuracy", accuracy],
		["Score", _score],
	]

	var career := {}
	var next_mission: MissionInfo = null
	if mission.mission_id != "":
		career = Profile.record_mission(mission.mission_id, {
			success = success,
			score = _score,
			air_kills = _air_kills,
			ground_kills = _ground_kills,
			balloons = _balloons,
			shots = shots,
			hits = player_hits,
			damage_taken = _damage_taken,
			bonus_done = mission.count_objectives(true, true),
			bonus_total = mission.count_objectives(true, false),
			aces_downed = _aces_downed,
		})
		next_mission = Profile.CAMPAIGN.next_after(mission.mission_id)

	var debrief := DEBRIEF_SCENE.instantiate()
	add_child(debrief)
	debrief.setup(success, reason, stats, career, next_mission if success else null)
	debrief.retry_pressed.connect(restart)


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
