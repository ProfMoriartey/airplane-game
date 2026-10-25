extends Node
## The player's saved career: campaign progress, totals, medals and chosen plane.
## Saved as JSON in the user data folder after every mission.

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1
const CAMPAIGN := preload("res://data/campaign/campaign.tres")
const PLAYER_AIRCRAFT: Array[AircraftStats] = [
	preload("res://data/aircraft/scout.tres"),
	preload("res://data/aircraft/lark.tres"),
	preload("res://data/aircraft/hornet.tres"),
	preload("res://data/aircraft/falcon.tres"),
	preload("res://data/aircraft/kestrel.tres"),
]

var _data := {}


func _ready() -> void:
	_load()


## --- Campaign progress ---

func is_unlocked(mission_id: String) -> bool:
	var previous := CAMPAIGN.previous_of(mission_id)
	return previous == null or is_completed(previous.id)


func is_completed(mission_id: String) -> bool:
	return _mission_record(mission_id).completed


func best_score(mission_id: String) -> int:
	return _mission_record(mission_id).best_score


## The first unlocked mission that hasn't been completed, or the last mission.
func next_mission() -> MissionInfo:
	var missions := CAMPAIGN.all_missions()
	for mission in missions:
		if not is_completed(mission.id):
			return mission
	return missions[-1]


func is_theater_complete(index: int) -> bool:
	for mission in CAMPAIGN.theaters[index].missions:
		if not is_completed(mission.id):
			return false
	return true


## --- Career ---

func career_points() -> int:
	var points: int = _data.medals.size() * Medals.MEDAL_POINTS
	for id: String in _data.missions:
		if _data.missions[id].completed:
			points += int(_data.missions[id].best_score)
	return points


func rank() -> int:
	return Ranks.rank_for(career_points())


func totals() -> Dictionary:
	return _data.totals


func medals() -> Array:
	return _data.medals


## --- Hangar ---

func unlocked_aircraft() -> Array[AircraftStats]:
	var current_rank := rank()
	var unlocked: Array[AircraftStats] = []
	for aircraft in PLAYER_AIRCRAFT:
		if aircraft.unlock_rank <= current_rank:
			unlocked.append(aircraft)
	return unlocked


func selected_aircraft() -> AircraftStats:
	for aircraft in unlocked_aircraft():
		if aircraft.id == _data.selected_aircraft:
			return aircraft
	return PLAYER_AIRCRAFT[0]


func select_aircraft(id: String) -> void:
	_data.selected_aircraft = id
	_save()


## --- Recording results ---

## Records a finished mission and returns what changed:
## points_before/after, rank_before/after, new_medals, new_aircraft, new_best.
func record_mission(mission_id: String, result: Dictionary) -> Dictionary:
	var points_before := career_points()
	var rank_before := rank()
	var aircraft_before := unlocked_aircraft()

	var totals: Dictionary = _data.totals
	totals.missions_flown += 1
	totals.air_kills += result.air_kills
	totals.ground_kills += result.ground_kills
	totals.balloons += result.balloons
	totals.shots += result.shots
	totals.hits += result.hits

	var record := _mission_record(mission_id)
	var new_best := false
	if result.success:
		totals.missions_won += 1
		new_best = not record.completed or result.score > record.best_score
		record.completed = true
		record.best_score = maxi(record.best_score, result.score)
	_data.missions[mission_id] = record

	var theaters_complete := []
	for index in CAMPAIGN.theaters.size():
		if is_theater_complete(index):
			theaters_complete.append(index)
	var new_medals := Medals.evaluate(totals, result, theaters_complete, _data.medals)
	_data.medals.append_array(new_medals)
	_save()

	var new_aircraft: Array[AircraftStats] = []
	for aircraft in unlocked_aircraft():
		if not aircraft_before.has(aircraft):
			new_aircraft.append(aircraft)

	return {
		points_before = points_before,
		points_after = career_points(),
		rank_before = rank_before,
		rank_after = rank(),
		new_medals = new_medals,
		new_aircraft = new_aircraft,
		new_best = new_best,
	}


func reset() -> void:
	_data = _new_profile()
	_save()


## --- Saving and loading ---

func _mission_record(mission_id: String) -> Dictionary:
	var record: Dictionary = _data.missions.get(mission_id, {})
	return {
		completed = record.get("completed", false),
		best_score = int(record.get("best_score", 0)),
	}


func _new_profile() -> Dictionary:
	return {
		version = SAVE_VERSION,
		missions = {},
		totals = {missions_flown = 0, missions_won = 0, air_kills = 0, ground_kills = 0, balloons = 0, shots = 0, hits = 0},
		medals = [],
		selected_aircraft = "scout",
	}


func _load() -> void:
	_data = _new_profile()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary:
		push_warning("Save file is unreadable; starting a new profile.")
		return
	# Merge onto a fresh profile so saves from older versions get any new fields.
	_data.missions = parsed.get("missions", {})
	_data.medals = parsed.get("medals", [])
	_data.selected_aircraft = parsed.get("selected_aircraft", "scout")
	var saved_totals: Dictionary = parsed.get("totals", {})
	for key: String in _data.totals:
		# JSON stores every number as a float.
		_data.totals[key] = int(saved_totals.get(key, 0))


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save profile: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_data, "\t"))
