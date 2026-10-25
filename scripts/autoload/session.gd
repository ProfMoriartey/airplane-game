extends Node
## Keeps track of each run of the game, for bug reports:
## - writes a short header (game version, system, graphics card) to the log
##   file Godot keeps in the user data folder;
## - notices when the last run didn't close normally (a crash or forced quit),
##   so the main menu can say so and point at the logs.

const LOCK_PATH := "user://session.lock"
const LOG_FOLDER := "user://logs"

## True if the previous run ended without closing normally.
var crashed_last_time := false
## Set once the main menu has mentioned the crash, so it only says it once.
var crash_reported := false


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
