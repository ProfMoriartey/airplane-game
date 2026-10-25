extends Node
## Keeps track of each run of the game, for bug reports:
## - writes a short header (game version, system, graphics card) to the log
##   file Godot keeps in the user data folder;
## - notices when the last run didn't close normally (a crash or forced quit),
##   so the main menu can say so and point at the logs;
## - keeps a playtest record: a line in playtest/results.csv after every flight,
##   and whatever players write in the feedback form, in playtest/feedback.txt.

const LOCK_PATH := "user://session.lock"
const LOG_FOLDER := "user://logs"
const PLAYTEST_FOLDER := "user://playtest"
const RESULTS_PATH := "user://playtest/results.csv"
const FEEDBACK_PATH := "user://playtest/feedback.txt"
## The columns of results.csv, in order.
const RESULT_COLUMNS := [
	"date", "version", "pilot", "mode", "name", "result", "seconds", "score", "air_kills",
	"ground_kills", "damage_taken", "shots", "hits", "difficulty", "aim_assist", "aircraft",
]

## True if the previous run ended without closing normally.
var crashed_last_time := false
## Set once the main menu has mentioned the crash, so it only says it once.
var crash_reported := false
## The last flight recorded, so feedback can say what it's about.
var last_flight := {}


func _enter_tree() -> void:
	crashed_last_time = FileAccess.file_exists(LOCK_PATH)
	var lock := FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if lock:
		lock.store_string(Time.get_datetime_string_from_system())
	print("%s %s | Godot %s | %s %s | %s | %s" % [
		ProjectSettings.get_setting("application/config/name"), version(), Engine.get_version_info().string,
		OS.get_name(), OS.get_version(), OS.get_processor_name(), Time.get_datetime_string_from_system(),
	])
	if crashed_last_time:
		print("The previous session did not close normally.")


func _ready() -> void:
	# The graphics card is only known once rendering has started.
	print("Graphics: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])


func _exit_tree() -> void:
	# Reached on every normal quit; a crash never gets here.
	DirAccess.remove_absolute(LOCK_PATH)


func version() -> String:
	var number := str(ProjectSettings.get_setting("application/config/version", ""))
	return number if number != "" else "0.1.0-dev"


## Opens the folder holding the log files, so players can attach them to a bug report.
func open_log_folder() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_FOLDER)
	OS.shell_open(ProjectSettings.globalize_path(LOG_FOLDER))


func open_playtest_folder() -> void:
	DirAccess.make_dir_recursive_absolute(PLAYTEST_FOLDER)
	OS.shell_open(ProjectSettings.globalize_path(PLAYTEST_FOLDER))


## Adds a finished flight to results.csv. Takes any of RESULT_COLUMNS (mode,
## name, result, seconds, score, ...); the date, version, pilot, difficulty
## and aim assist are filled in here.
func record_flight(details: Dictionary) -> void:
	last_flight = details.duplicate()
	last_flight.merge({
		date = Time.get_datetime_string_from_system(), version = version(), pilot = Profile.pilot_name(),
		difficulty = Settings.DIFFICULTY_SETTINGS[Settings.difficulty].name,
		aim_assist = ["off", "light", "strong"][Settings.aim_assist],
	})
	if "seconds" in last_flight:
		last_flight.seconds = roundi(last_flight.seconds)
	var is_new := not FileAccess.file_exists(RESULTS_PATH)
	DirAccess.make_dir_recursive_absolute(PLAYTEST_FOLDER)
	var file := FileAccess.open(RESULTS_PATH, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	if is_new:
		file.store_csv_line(PackedStringArray(RESULT_COLUMNS))
	file.store_csv_line(PackedStringArray(RESULT_COLUMNS.map(func(column: String) -> String: return str(last_flight.get(column, "")))))


## Adds a player's feedback, with the flight it's about, to feedback.txt.
func record_feedback(about: String, difficulty: String, fun: String, comment: String) -> void:
	DirAccess.make_dir_recursive_absolute(PLAYTEST_FOLDER)
	var file := FileAccess.open(FEEDBACK_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(FEEDBACK_PATH) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var flight := ", ".join(RESULT_COLUMNS.filter(func(c: String) -> bool: return last_flight.has(c)).map(func(c: String) -> String: return "%s=%s" % [c, last_flight[c]]))
	file.store_string("--- %s (version %s)\n" % [Time.get_datetime_string_from_system(), version()])
	file.store_string("About: %s\n" % about)
	file.store_string("Last finished flight: %s\n" % (flight if flight != "" else "none"))
	file.store_string("Difficulty felt: %s\nFun: %s\n" % [difficulty, fun])
	if comment.strip_edges() != "":
		file.store_string("Comments: %s\n" % comment.strip_edges())
	file.store_string("\n")
