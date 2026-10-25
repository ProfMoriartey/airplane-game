extends Node
## The player's saved career: campaign progress, totals, medals and chosen plane.
## There are SLOT_COUNT pilots, each saved as JSON in the user data folder after
## every mission. Saves are written to a temporary file first, and the previous
## save is kept as a backup, so a crash mid-save can't lose a career.

signal pilot_changed

const SLOT_COUNT := 3
const SAVE_FOLDER := "user://pilots"
const CURRENT_PATH := "user://pilots/current.txt"
## Where saves lived before there were save slots.
const OLD_SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 2
const MAX_NAME_LENGTH := 20
const CAMPAIGN := preload("res://data/campaign/campaign.tres")
const PLAYER_AIRCRAFT: Array[AircraftStats] = [
	preload("res://data/aircraft/scout.tres"),
	preload("res://data/aircraft/lark.tres"),
	preload("res://data/aircraft/hornet.tres"),
	preload("res://data/aircraft/falcon.tres"),
	preload("res://data/aircraft/kestrel.tres"),
]

var _data := {}
## Which save slot is in use.
var current_slot := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	_move_old_save()
	if FileAccess.file_exists(CURRENT_PATH):
		current_slot = clampi(FileAccess.get_file_as_string(CURRENT_PATH).to_int(), 0, SLOT_COUNT - 1)
	_data = _read(current_slot)
	if _data.is_empty():
		_data = _new_profile(default_name(current_slot))


## --- Pilots (save slots) ---

func pilot_name() -> String:
	return _data.name


func default_name(slot: int) -> String:
	return tr("Pilot %d") % (slot + 1)


func slot_exists(slot: int) -> bool:
	return slot == current_slot or FileAccess.file_exists(_slot_path(slot))


## A short summary of a slot for the pilots screen, or {} if it's empty.
func slot_summary(slot: int) -> Dictionary:
	var data := _data if slot == current_slot else _read(slot)
	if data.is_empty():
		return {}
	var completed := 0
	for id: String in data.missions:
		if data.missions[id].get("completed", false):
			completed += 1
	var points := _points_of(data)
	return {
		name = data.name,
		rank = Ranks.rank_for(points),
		points = points,
		missions_completed = completed,
		missions_total = CAMPAIGN.all_missions().size(),
		medals = data.medals.size(),
		last_played = int(data.get("last_played", 0)),
	}


## Switches to another pilot, creating them (with this name) if the slot is empty.
func use_slot(slot: int, new_name := "") -> void:
	_save()
	current_slot = slot
	_data = _read(slot)
	if _data.is_empty():
		_data = _new_profile(clean_name(new_name, slot))
	_save()
	_write_text(CURRENT_PATH, str(slot))
	pilot_changed.emit()


func rename_slot(slot: int, new_name: String) -> void:
	if slot == current_slot:
		_data.name = clean_name(new_name, slot)
		_save()
		pilot_changed.emit()
		return
	var data := _read(slot)
	if not data.is_empty():
		data.name = clean_name(new_name, slot)
		_write_slot(slot, data)


## Deletes a pilot. Deleting the current pilot starts them afresh.
func delete_slot(slot: int) -> void:
	for path in [_slot_path(slot), _slot_path(slot) + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if slot == current_slot:
		_data = _new_profile(default_name(slot))
		_save()
		pilot_changed.emit()


## Trims a typed name and falls back to "Pilot N" if nothing's left.
func clean_name(text: String, slot: int) -> String:
	text = text.strip_edges().left(MAX_NAME_LENGTH)
	return text if text != "" else default_name(slot)


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
	return _points_of(_data)


func _points_of(data: Dictionary) -> int:
	var points: int = data.medals.size() * Medals.MEDAL_POINTS
	for id: String in data.missions:
		if data.missions[id].get("completed", false):
			points += int(data.missions[id].get("best_score", 0))
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


## The paint scheme chosen for an aircraft type.
func livery_of(aircraft_id: String) -> int:
	return int(_data.liveries.get(aircraft_id, 0))


func set_livery(aircraft_id: String, livery: int) -> void:
	_data.liveries[aircraft_id] = livery
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


## --- Ace Duels ---

func has_won_duel(ace_id: String) -> bool:
	return _data.duels.has(ace_id)


## Records a duel victory. Returns the ids of any medals it earned.
func record_duel_win(ace_id: String) -> Array[String]:
	var earned: Array[String] = []
	if not _data.duels.has(ace_id):
		_data.duels.append(ace_id)
	var all_won := Aces.ACES.all(func(ace: Dictionary) -> bool: return _data.duels.has(ace.id))
	if all_won and not _data.medals.has("duellist"):
		_data.medals.append("duellist")
		earned.append("duellist")
	_save()
	return earned


func reset() -> void:
	_data = _new_profile(_data.name)
	_save()


## --- Saving and loading ---

func _mission_record(mission_id: String) -> Dictionary:
	var record: Dictionary = _data.missions.get(mission_id, {})
	return {
		completed = record.get("completed", false),
		best_score = int(record.get("best_score", 0)),
	}


func _new_profile(pilot: String) -> Dictionary:
	return {
		version = SAVE_VERSION,
		name = pilot,
		last_played = 0,
		missions = {},
		totals = {missions_flown = 0, missions_won = 0, air_kills = 0, ground_kills = 0, balloons = 0, shots = 0, hits = 0},
		medals = [],
		selected_aircraft = "scout",
		liveries = {},
		duels = [],
	}


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_FOLDER, slot + 1]


## Reads a slot, falling back to its backup if the save is damaged.
## Returns {} if the slot is empty.
func _read(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			if candidate != path:
				push_warning("Save %s was damaged; using its backup." % path)
			return _upgrade(parsed, slot)
		push_warning("Save %s is unreadable." % candidate)
	return {}


## Merges a loaded save onto a fresh profile so saves from older versions get
## any new fields.
func _upgrade(parsed: Dictionary, slot: int) -> Dictionary:
	var data := _new_profile(clean_name(str(parsed.get("name", "")), slot))
	data.last_played = int(parsed.get("last_played", 0))
	data.missions = parsed.get("missions", {})
	data.medals = parsed.get("medals", [])
	data.selected_aircraft = parsed.get("selected_aircraft", "scout")
	data.liveries = parsed.get("liveries", {})
	data.duels = parsed.get("duels", [])
	var saved_totals: Dictionary = parsed.get("totals", {})
	for key: String in data.totals:
		# JSON stores every number as a float.
		data.totals[key] = int(saved_totals.get(key, 0))
	return data


## Saves from before there were slots become the first pilot.
func _move_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not FileAccess.file_exists(_slot_path(0)):
		DirAccess.rename_absolute(OLD_SAVE_PATH, _slot_path(0))


func _save() -> void:
	_data.last_played = int(Time.get_unix_time_from_system())
	_write_slot(current_slot, _data)


func _write_slot(slot: int, data: Dictionary) -> void:
	var path := _slot_path(slot)
	# Write the new save beside the old one, keep the old one as a backup, then
	# swap the new one in. A crash at any point leaves a readable save.
	if not _write_text(path + ".tmp", JSON.stringify(data, "\t")):
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	DirAccess.rename_absolute(path + ".tmp", path)


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	return true
