class_name Mission
extends Node
## Runs a mission's objectives (its child nodes) in order.
##
## Each required objective must be completed before the next one starts.
## Optional objectives start alongside the next required one and never block.
## The mission succeeds when every required objective is done, and fails if
## one fails or fail() is called (e.g. when the player is shot down).

signal objective_started(objective: Objective)
signal objective_completed(objective: Objective)
signal completed
signal failed(reason: String)

## Matches the mission's id in the campaign, for saving progress.
@export var mission_id := ""
@export var title := "Mission"
@export_multiline var briefing := ""
## Radio lines played as the mission starts. Write each as "Speaker: message".
@export var intro_radio: PackedStringArray

var objectives: Array[Objective] = []
var player: Aircraft
var is_finished := false

var _next_index := 0


func _ready() -> void:
	for child in get_children():
		if child is Objective:
			objectives.append(child)
			child.mission = self
			child.completed.connect(_on_objective_completed)
			child.failed.connect(_on_objective_failed)


func start(mission_player: Aircraft) -> void:
	player = mission_player
	_advance()


func fail(reason: String) -> void:
	if is_finished:
		return
	is_finished = true
	failed.emit(reason)


func get_active_objectives() -> Array[Objective]:
	var active: Array[Objective] = []
	for objective in objectives:
		if objective.is_active():
			active.append(objective)
	return active


func count_objectives(optional: bool, completed_only: bool) -> int:
	var total := 0
	for objective in objectives:
		if objective.optional != optional:
			continue
		if completed_only and objective.status != Objective.Status.COMPLETED:
			continue
		total += 1
	return total


## Starts objectives until reaching a required one that must be finished first.
func _advance() -> void:
	while _next_index < objectives.size():
		var objective := objectives[_next_index]
		_next_index += 1
		objective.activate()
		objective_started.emit(objective)
		if not objective.optional:
			return
	if not is_finished:
		is_finished = true
		completed.emit()


func _on_objective_completed(objective: Objective) -> void:
	if is_finished:
		return
	objective_completed.emit(objective)
	if not objective.optional:
		_advance()


func _on_objective_failed(objective: Objective) -> void:
	if not objective.optional:
		fail(tr("Objective failed: %s") % Settings.fill_keys(objective.description))
