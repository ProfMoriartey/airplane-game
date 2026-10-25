class_name Objective
extends Node
## One step of a mission. Add objectives as children of a Mission node, in order.
##
## Subclasses decide when the objective is complete. Optional objectives give
## bonus score, and the mission moves on without waiting for them.

signal completed(objective: Objective)
signal failed(objective: Objective)

enum Status { WAITING, ACTIVE, COMPLETED, FAILED }

## Short instruction shown on the HUD, e.g. "Shoot down the balloons".
@export var description := ""
@export var optional := false
@export var score_bonus := 250
## Radio lines played when this objective starts and when it's completed.
## Write each line as "Speaker: message".
@export var radio_on_start: PackedStringArray
@export var radio_on_complete: PackedStringArray

var status := Status.WAITING
var mission: Mission


func activate() -> void:
	status = Status.ACTIVE
	_on_activated()


func is_active() -> bool:
	return status == Status.ACTIVE


func complete() -> void:
	if status != Status.ACTIVE:
		return
	status = Status.COMPLETED
	# Deferred, so an objective that completes the moment it starts doesn't
	# re-enter the mission while it's still activating objectives.
	completed.emit.call_deferred(self)


func fail() -> void:
	if status != Status.ACTIVE:
		return
	status = Status.FAILED
	failed.emit.call_deferred(self)


## Extra text after the description, e.g. "2/3".
func get_progress_text() -> String:
	return ""


## World positions the HUD should point the player towards.
func get_markers() -> Array[Vector3]:
	return []


## Where to show this objective on the briefing map.
func get_map_position() -> Vector3:
	var markers := get_markers()
	if markers.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for marker in markers:
		sum += marker
	return sum / markers.size()


func _on_activated() -> void:
	pass
