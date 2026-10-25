extends Level
## A level that runs a Mission: briefing first, then objectives, scoring,
## radio messages, and a debrief when it's over.

const BRIEFING_SCENE := preload("res://scenes/ui/briefing.tscn")
const DEBRIEF_SCENE := preload("res://scenes/ui/debrief.tscn")
const DEBRIEF_DELAY := 3.0
const AIRCRAFT_SCORE := 100

var _elapsed := 0.0
var _air_kills := 0
var _ground_kills := 0
var _score := 0

@onready var mission: Mission = $Mission


func _ready() -> void:
	super()
	mission.objective_started.connect(_on_objective_started)
	mission.objective_completed.connect(_on_objective_completed)
	mission.completed.connect(_on_mission_completed)
	mission.failed.connect(_on_mission_failed)
	Events.aircraft_destroyed.connect(_on_aircraft_destroyed)
	Events.ground_target_destroyed.connect(_on_ground_target_destroyed)
	_show_briefing()


func _process(delta: float) -> void:
	if mission.player == null:
		return
	if not mission.is_finished:
		_elapsed += delta

	var lines: PackedStringArray = []
	var markers: Array[Vector3] = []
	for objective in mission.get_active_objectives():
		var line := objective.description
		var progress := objective.get_progress_text()
		if progress != "":
			line += "  %s" % progress
		lines.append("(Bonus) %s" % line if objective.optional else line)
		if not objective.optional:
			markers.append_array(objective.get_markers())
	hud.set_objectives(lines)
	hud.set_objective_markers(markers)
	hud.set_status_text("TIME %s     SCORE %d" % [_format_time(_elapsed), _score])


func _show_briefing() -> void:
	var briefing := BRIEFING_SCENE.instantiate()
	add_child(briefing)
	briefing.setup(mission, terrain, player)
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
	mission.start(player)


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
		hud.flash_banner("ENEMY DOWN")


func _on_ground_target_destroyed(target: GroundTarget, attacker: Aircraft) -> void:
	if attacker == player:
		_ground_kills += 1
		_score += target.score_value
		hud.flash_banner("%s DESTROYED" % target.display_name.to_upper())


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
	pause_menu.close()
	pause_menu.enabled = false
	hud.visible = false
	get_tree().paused = true

	var shots := player.guns.shots_fired
	var accuracy := "-" if shots == 0 else "%d%%" % roundi(100.0 * player_hits / shots)
	var debrief := DEBRIEF_SCENE.instantiate()
	add_child(debrief)
	debrief.setup(success, reason, [
		["Time", _format_time(_elapsed)],
		["Objectives", "%d / %d" % [mission.count_objectives(false, true), mission.count_objectives(false, false)]],
		["Bonus objectives", "%d / %d" % [mission.count_objectives(true, true), mission.count_objectives(true, false)]],
		["Aircraft shot down", _air_kills],
		["Ground targets destroyed", _ground_kills],
		["Gun accuracy", accuracy],
		["Score", _score],
	])
	debrief.retry_pressed.connect(restart)


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
