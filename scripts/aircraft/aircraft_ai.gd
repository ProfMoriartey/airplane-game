class_name AircraftAI
extends Node
## Flies its parent Aircraft as an enemy (or friendly) pilot.
##
## The pilot patrols (or follows a route) until it spots something hostile, then
## chases it and fires when its guns line up. When it's being shot at it may
## break away for a few seconds. Whatever it's doing, it pulls up if the ground
## gets too close.
##
## Passive pilots, like bombers, never attack: they fly their route and drop
## bombs when they'd land on one of their bomb targets.

enum State { PATROL, ENGAGE, EVADE }
enum Skill { ROOKIE, VETERAN, ACE }

## burst_time / burst_pause: seconds of firing, then seconds of holding fire.
## throttle: how hard the pilot pushes the engine in a fight.
const SKILL_SETTINGS := {
	Skill.ROOKIE: {
		reaction_time = 0.8, aim_error = 12.0, fire_cone = 5.0, evade_chance = 0.15,
		burst_time = 0.8, burst_pause = 2.0, throttle = 0.85,
	},
	Skill.VETERAN: {
		reaction_time = 0.5, aim_error = 9.0, fire_cone = 5.0, evade_chance = 0.4,
		burst_time = 1.2, burst_pause = 1.2, throttle = 0.95,
	},
	Skill.ACE: {
		reaction_time = 0.25, aim_error = 4.0, fire_cone = 4.0, evade_chance = 0.75,
		burst_time = 1.5, burst_pause = 0.8, throttle = 1.0,
	},
}
## Emitted when a route-following pilot reaches its last waypoint.
signal route_finished

const DETECT_RANGE := 2000.0
const FIRE_RANGE := 450.0
const EVADE_DURATION := 3.0
## Keep at least this far above the ground, now and a few seconds ahead.
const MIN_CLEARANCE := 100.0
## Lower limit while attacking something on the ground, so strafing runs get close.
const ATTACK_CLEARANCE := 40.0
## A waypoint counts as reached within this distance (height doesn't matter).
const WAYPOINT_RADIUS := 150.0
## Targets in this group, or on the ground when attacking ground targets, look
## this much closer than they are, so pilots go for them first.
const PRIORITY_DISTANCE_SCALE := 0.4
## Drop a bomb when it would land this close to a bomb target.
const BOMB_ACCURACY := 30.0
const LOOK_AHEAD_TIME := 3.0
## Swerve from any plane that will pass closer than this within the warning time.
const MISS_DISTANCE := 40.0
## Once swerving, keep at it this long instead of turning straight back.
const SWERVE_TIME := 1.5
const COLLISION_WARNING_TIME := 3.0
## Only planes this close are checked for collisions.
const COLLISION_SCAN_RANGE := 350.0
## Within this angle of the target the pilot stops banking and aims with the rudder.
const FINE_AIM_ANGLE := deg_to_rad(8.0)
## Beyond this angle the pilot pulls into a hard turn.
const HARD_TURN_ANGLE := deg_to_rad(60.0)

@export var skill := Skill.ROOKIE
@export var patrol_center := Vector3(0.0, 350.0, 0.0)
@export var patrol_radius := 800.0
## Also attack hostile ground targets, such as balloons and guns.
@export var attack_ground_targets := false
## Never attack anything; just fly (e.g. bombers).
@export var passive := false
## If set, fly through this node's children in order instead of patrolling.
@export var route: Node3D
## Bombs are dropped when they'd land on a ground target under this node.
@export var bomb_targets: Node

var state := State.PATROL
## The aircraft or ground target being attacked.
var target: Node3D

var _plane: Aircraft
var _terrain: Terrain
var _settings: Dictionary
var _think_timer := 0.0
var _evade_timer := 0.0
var _evade_point := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _roll_sign := 1.0
var _burst_timer := 0.0
var _burst_cooldown := 0.0
var _waypoint := 0
var _swerve_from: Aircraft
var _swerve_timer := 0.0


func _ready() -> void:
	_plane = get_parent() as Aircraft
	_plane.player_controlled = false
	_plane.auto_level = false
	_plane.damaged.connect(_on_damaged)
	_settings = SKILL_SETTINGS[skill]
	_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	# Stagger thinking so a group of pilots doesn't all decide on the same frame.
	_think_timer = randf() * _settings.reaction_time


func _physics_process(delta: float) -> void:
	if not _plane.is_alive():
		return

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _settings.reaction_time
		_think()

	_burst_cooldown -= delta
	_evade_timer -= delta
	if state == State.EVADE and _evade_timer <= 0.0:
		state = State.ENGAGE if _has_target() else State.PATROL

	if bomb_targets:
		_try_bombing()

	if _ground_too_close():
		_avoid_ground()
		_plane.guns.trigger = false
		return

	_swerve_timer -= delta
	var threat := _collision_threat()
	if threat:
		_swerve_from = threat
		_swerve_timer = SWERVE_TIME
	if _swerve_timer > 0.0 and is_instance_valid(_swerve_from):
		_fly_towards(_swerve_point(_swerve_from))
		_plane.guns.trigger = false
		return

	match state:
		State.PATROL:
			_plane.guns.trigger = false
			if route:
				_plane.throttle = 1.0
				_fly_route()
			else:
				_plane.throttle = 0.7
				_fly_towards(_patrol_point())
		State.ENGAGE:
			_plane.throttle = _settings.throttle
			var aim_point := _lead_point() + _aim_offset
			_fly_towards(aim_point)
			_plane.guns.trigger = _update_burst(_should_fire(aim_point), delta)
		State.EVADE:
			_plane.throttle = 1.0
			_fly_towards(_evade_point)
			_plane.guns.trigger = false


## Slow decisions, made every reaction_time seconds.
func _think() -> void:
	if passive:
		return
	if not _has_target():
		target = _find_target()
	if state != State.EVADE:
		state = State.ENGAGE if _has_target() else State.PATROL
	# A new aiming mistake each time, smaller for better pilots.
	_aim_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _settings.aim_error


func _has_target() -> bool:
	return is_instance_valid(target) and target.is_alive()


func _find_target() -> Node3D:
	var candidates := get_tree().get_nodes_in_group("aircraft")
	if attack_ground_targets:
		candidates += get_tree().get_nodes_in_group("ground_targets")
	var best: Node3D = null
	var best_score := DETECT_RANGE
	for node in candidates:
		var other := node as Node3D
		if other == _plane or not other.is_alive() or other.team == _plane.team:
			continue
		var score := _plane.global_position.distance_to(other.global_position)
		if other.is_in_group("priority_target") or (attack_ground_targets and other is GroundTarget):
			score *= PRIORITY_DISTANCE_SCALE
		if score < best_score:
			best = other
			best_score = score
	return best


func _target_velocity() -> Vector3:
	return target.velocity if target is Aircraft else Vector3.ZERO


## Where to aim so bullets and target arrive at the same place.
func _lead_point() -> Vector3:
	var distance := _plane.global_position.distance_to(target.global_position)
	var flight_time := distance / _plane.guns.muzzle_speed
	return target.global_position + (_target_velocity() - _plane.velocity) * flight_time


func _should_fire(aim_point: Vector3) -> bool:
	var to_aim := aim_point - _plane.global_position
	if to_aim.length() > FIRE_RANGE:
		return false
	var nose := -_plane.global_basis.z
	return nose.angle_to(to_aim) < deg_to_rad(_settings.fire_cone)


## Turns "want to fire" into short bursts with pauses, like a real pilot saving ammo.
func _update_burst(wants_to_fire: bool, delta: float) -> bool:
	if not wants_to_fire or _burst_cooldown > 0.0:
		return false
	_burst_timer += delta
	if _burst_timer >= _settings.burst_time:
		_burst_timer = 0.0
		_burst_cooldown = _settings.burst_pause
	return true


## Any plane, friend or foe, that we're about to fly into: one that will pass
## within MISS_DISTANCE of us in the next COLLISION_WARNING_TIME seconds.
func _collision_threat() -> Aircraft:
	for node in get_tree().get_nodes_in_group("aircraft"):
		var other := node as Aircraft
		if other == _plane or not other.is_alive():
			continue
		var offset := other.global_position - _plane.global_position
		if offset.length() > COLLISION_SCAN_RANGE:
			continue
		# Already too close, e.g. two wingmen drifting together.
		if offset.length() < MISS_DISTANCE:
			return other
		var relative_velocity := other.velocity - _plane.velocity
		var speed_squared := relative_velocity.length_squared()
		if speed_squared < 0.01:
			continue
		# When the two planes will be closest, and how close that is.
		var time := -offset.dot(relative_velocity) / speed_squared
		if time < 0.0 or time > COLLISION_WARNING_TIME:
			continue
		if (offset + relative_velocity * time).length() < MISS_DISTANCE:
			return other
	return null


## A point to fly to that takes us away from the other plane. The higher of the
## two climbs and the lower one dives, so they can't both swerve the same way.
func _swerve_point(other: Aircraft) -> Vector3:
	var away := _plane.global_position - other.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else _plane.global_basis.x
	var higher := _plane.global_position.y > other.global_position.y
	if is_equal_approx(_plane.global_position.y, other.global_position.y):
		higher = _plane.get_instance_id() > other.get_instance_id()
	var vertical := Vector3.UP if higher else Vector3.DOWN
	return _plane.global_position - _plane.global_basis.z * 80.0 + away * 150.0 + vertical * 60.0


func _fly_route() -> void:
	var points := route.get_children()
	var point := (points[mini(_waypoint, points.size() - 1)] as Node3D).global_position
	var offset := point - _plane.global_position
	if _waypoint < points.size() and Vector2(offset.x, offset.z).length() < WAYPOINT_RADIUS:
		_waypoint += 1
		if _waypoint == points.size():
			# Circle the last waypoint from now on.
			patrol_center = point
			route_finished.emit()
	if _waypoint >= points.size():
		_fly_towards(_patrol_point())
	else:
		_fly_towards(point)


func _try_bombing() -> void:
	if _plane.bombs.count == 0 or _terrain == null:
		return
	var impact: Variant = _plane.bombs.predict_impact(_terrain)
	if impact == null:
		return
	for node in bomb_targets.find_children("*", "", true, false):
		var bomb_target := node as GroundTarget
		if bomb_target and bomb_target.is_alive() and bomb_target.global_position.distance_to(impact) < BOMB_ACCURACY:
			_plane.bombs.drop()
			return


func _patrol_point() -> Vector3:
	# Aim a little further around the patrol circle than where we are now.
	var offset := _plane.global_position - patrol_center
	var angle := atan2(offset.z, offset.x) + 0.4
	return patrol_center + Vector3(cos(angle), 0.0, sin(angle)) * patrol_radius


func _ground_too_close() -> bool:
	if _terrain == null:
		return false
	var now := _plane.global_position
	var ahead := now + _plane.velocity * LOOK_AHEAD_TIME
	var clearance_now := now.y - _terrain.get_height(now.x, now.z)
	var clearance_ahead := ahead.y - _terrain.get_height(ahead.x, ahead.z)
	var attacking_ground := state == State.ENGAGE and target is GroundTarget
	return minf(clearance_now, clearance_ahead) < (ATTACK_CLEARANCE if attacking_ground else MIN_CLEARANCE)


func _avoid_ground() -> void:
	_plane.throttle = 1.0
	var forward := -_plane.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	_fly_towards(_plane.global_position + forward.normalized() * 200.0 + Vector3.UP * 150.0)


## Steers like a pilot: roll so the target is "above" the cockpit, then pull.
func _fly_towards(point: Vector3) -> void:
	var to_point := (point - _plane.global_position).normalized()
	var local := _plane.global_basis.inverse() * to_point
	var angle_off := (-_plane.global_basis.z).angle_to(to_point)

	_plane.pitch_input = clampf(local.y * 4.0, -1.0, 1.0)

	if angle_off > FINE_AIM_ANGLE:
		var roll_error := atan2(local.x, local.y)
		# Near ±180° the error flips sign every frame; stick with the current direction.
		if absf(roll_error) > 2.8:
			roll_error = absf(roll_error) * _roll_sign
		_roll_sign = signf(roll_error) if roll_error != 0.0 else _roll_sign
		_plane.roll_input = clampf(roll_error * 1.5, -1.0, 1.0)
		_plane.yaw_input = 0.0
		# Far off the nose (e.g. behind us): once rolled towards it, pull hard to turn around.
		if angle_off > HARD_TURN_ANGLE:
			_plane.pitch_input = 1.0 if absf(roll_error) < 1.2 else 0.3
	else:
		# Nearly lined up: level the wings and make small corrections with the rudder.
		_plane.roll_input = clampf(_plane.global_basis.x.y * 3.0, -1.0, 1.0)
		_plane.yaw_input = clampf(local.x * 6.0, -1.0, 1.0)


func _on_damaged(_amount: float, attacker: Aircraft) -> void:
	if passive:
		return
	if attacker and not _has_target():
		target = attacker
	if state == State.EVADE or randf() > _settings.evade_chance:
		return
	state = State.EVADE
	_evade_timer = EVADE_DURATION
	# Break hard to one side and down.
	var side := _plane.global_basis.x * (1.0 if randf() < 0.5 else -1.0)
	_evade_point = _plane.global_position + side * 400.0 - _plane.global_basis.z * 200.0 + Vector3.DOWN * 120.0
