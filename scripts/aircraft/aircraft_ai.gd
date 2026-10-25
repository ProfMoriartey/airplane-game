class_name AircraftAI
extends Node
## Flies its parent Aircraft as an enemy (or friendly) pilot.
##
## The pilot patrols until it spots a hostile plane, then chases it and fires
## when its guns line up. When it's being shot at it may break away for a few
## seconds. Whatever it's doing, it pulls up if the ground gets too close.

enum State { PATROL, ENGAGE, EVADE }
enum Skill { ROOKIE, VETERAN, ACE }

const SKILL_SETTINGS := {
	Skill.ROOKIE: {reaction_time = 0.6, aim_error = 10.0, fire_cone = 7.0, evade_chance = 0.15},
	Skill.VETERAN: {reaction_time = 0.35, aim_error = 5.0, fire_cone = 5.0, evade_chance = 0.4},
	Skill.ACE: {reaction_time = 0.15, aim_error = 2.0, fire_cone = 3.5, evade_chance = 0.75},
}
const DETECT_RANGE := 2000.0
const FIRE_RANGE := 450.0
const EVADE_DURATION := 3.0
## Keep at least this far above the ground, now and a few seconds ahead.
const MIN_CLEARANCE := 100.0
const LOOK_AHEAD_TIME := 3.0
## Closer than this to the target, and still closing, the pilot swerves to avoid a collision.
const COLLISION_RANGE := 90.0
## Within this angle of the target the pilot stops banking and aims with the rudder.
const FINE_AIM_ANGLE := deg_to_rad(8.0)
## Beyond this angle the pilot pulls into a hard turn.
const HARD_TURN_ANGLE := deg_to_rad(60.0)

@export var skill := Skill.ROOKIE
@export var patrol_center := Vector3(0.0, 350.0, 0.0)
@export var patrol_radius := 800.0

var state := State.PATROL
var target: Aircraft

var _plane: Aircraft
var _terrain: Terrain
var _settings: Dictionary
var _think_timer := 0.0
var _evade_timer := 0.0
var _evade_point := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _roll_sign := 1.0


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

	_evade_timer -= delta
	if state == State.EVADE and _evade_timer <= 0.0:
		state = State.ENGAGE if _has_target() else State.PATROL

	if _ground_too_close():
		_avoid_ground()
		_plane.guns.trigger = false
		return

	match state:
		State.PATROL:
			_plane.throttle = 0.7
			_fly_towards(_patrol_point())
			_plane.guns.trigger = false
		State.ENGAGE:
			_plane.throttle = 1.0
			if _collision_likely():
				_fly_towards(_swerve_point())
				_plane.guns.trigger = false
				return
			var aim_point := _lead_point() + _aim_offset
			_fly_towards(aim_point)
			_plane.guns.trigger = _should_fire(aim_point)
		State.EVADE:
			_plane.throttle = 1.0
			_fly_towards(_evade_point)
			_plane.guns.trigger = false


## Slow decisions, made every reaction_time seconds.
func _think() -> void:
	if not _has_target():
		target = _find_target()
	if state != State.EVADE:
		state = State.ENGAGE if _has_target() else State.PATROL
	# A new aiming mistake each time, smaller for better pilots.
	_aim_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _settings.aim_error


func _has_target() -> bool:
	return is_instance_valid(target) and target.is_alive()


func _find_target() -> Aircraft:
	var best: Aircraft = null
	var best_distance := DETECT_RANGE
	for node in get_tree().get_nodes_in_group("aircraft"):
		var other := node as Aircraft
		if other == _plane or not other.is_alive() or not _plane.is_hostile_to(other):
			continue
		var distance := _plane.global_position.distance_to(other.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


## Where to aim so bullets and target arrive at the same place.
func _lead_point() -> Vector3:
	var distance := _plane.global_position.distance_to(target.global_position)
	var flight_time := distance / _plane.guns.muzzle_speed
	return target.global_position + (target.velocity - _plane.velocity) * flight_time


func _should_fire(aim_point: Vector3) -> bool:
	var to_aim := aim_point - _plane.global_position
	if to_aim.length() > FIRE_RANGE:
		return false
	var nose := -_plane.global_basis.z
	return nose.angle_to(to_aim) < deg_to_rad(_settings.fire_cone)


func _collision_likely() -> bool:
	var offset := target.global_position - _plane.global_position
	var closing_speed := (_plane.velocity - target.velocity).dot(offset.normalized())
	return offset.length() < COLLISION_RANGE and closing_speed > 0.0


## A point beside and above the target, to pass it safely.
func _swerve_point() -> Vector3:
	var offset := target.global_position - _plane.global_position
	var side := offset.cross(Vector3.UP).normalized()
	if side.dot(_plane.global_basis.x) < 0.0:
		side = -side
	return target.global_position + side * 80.0 + Vector3.UP * 40.0


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
	return minf(clearance_now, clearance_ahead) < MIN_CLEARANCE


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
	if attacker and not _has_target():
		target = attacker
	if state == State.EVADE or randf() > _settings.evade_chance:
		return
	state = State.EVADE
	_evade_timer = EVADE_DURATION
	# Break hard to one side and down.
	var side := _plane.global_basis.x * (1.0 if randf() < 0.5 else -1.0)
	_evade_point = _plane.global_position + side * 400.0 - _plane.global_basis.z * 200.0 + Vector3.DOWN * 120.0
