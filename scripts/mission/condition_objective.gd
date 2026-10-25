class_name ConditionObjective
extends Objective
## Complete when the player does something: open the throttle, climb, turn,
## change view, fire... Used to teach the controls in the training mission.

enum Condition {
	THROTTLE_FULL, ## Throttle at (nearly) 100%.
	CLIMB_TO, ## Altitude of at least `amount` metres.
	TURN, ## Turn through `amount` degrees in total.
	COCKPIT_VIEW,
	CHASE_VIEW,
	LOOK_AROUND,
	FIRE_GUNS, ## Fire `amount` rounds.
	DROP_BOMB,
}

@export var condition := Condition.THROTTLE_FULL
@export var amount := 0.0

var _turned := 0.0
var _last_heading := 0.0
var _shots_at_start := 0
var _bombs_at_start := 0


func _on_activated() -> void:
	var plane := mission.player
	_last_heading = _heading()
	_shots_at_start = plane.guns.shots_fired
	_bombs_at_start = plane.bombs.count


func get_progress_text() -> String:
	match condition:
		Condition.CLIMB_TO:
			return "%d / %d m" % [roundi(mission.player.global_position.y), roundi(amount)]
		Condition.TURN:
			return "%d / %d°" % [roundi(_turned), roundi(amount)]
		Condition.FIRE_GUNS:
			return "%d / %d" % [mission.player.guns.shots_fired - _shots_at_start, roundi(amount)]
	return ""


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	var heading := _heading()
	_turned += absf(wrapf(heading - _last_heading, -PI, PI)) * 180.0 / PI
	_last_heading = heading
	if _met():
		complete()


func _met() -> bool:
	var plane := mission.player
	var camera := get_viewport().get_camera_3d() as ChaseCamera
	match condition:
		Condition.THROTTLE_FULL:
			return plane.throttle > 0.97
		Condition.CLIMB_TO:
			return plane.global_position.y >= amount
		Condition.TURN:
			return _turned >= amount
		Condition.COCKPIT_VIEW:
			return camera and camera.view == ChaseCamera.View.COCKPIT
		Condition.CHASE_VIEW:
			return camera and camera.view == ChaseCamera.View.CHASE
		Condition.LOOK_AROUND:
			return camera and camera.is_looking_around()
		Condition.FIRE_GUNS:
			return plane.guns.shots_fired - _shots_at_start >= amount
		Condition.DROP_BOMB:
			return plane.bombs.count < _bombs_at_start
	return false


func _heading() -> float:
	var forward := -mission.player.global_basis.z
	return atan2(forward.x, -forward.z)
