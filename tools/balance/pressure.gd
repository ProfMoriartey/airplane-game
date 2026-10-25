extends SceneTree
## Balance testing: how long does a pretend player survive when enemy fighters
## hunt them? This is the number that decides whether a difficulty feels fair.
##
##   godot --headless --fixed-fps 60 --path . -s res://tools/balance/pressure.gd -- [rounds]
##
## The pretend player flies a Scout and never shoots back:
##   beginner  wanders in gentle turns and climbs, never reacting to enemies
##   evasive   flies like the beginner, but breaks hard when an enemy gets behind
## Enemy aim and the damage the player takes follow the difficulty, as in the game.

## Seconds without being shot down that count as surviving the whole test.
const TIME_LIMIT := 120.0
const SPAWN_DISTANCE := 1100.0
const START_HEIGHT := 450.0
const SKILL_NAMES := ["rookie", "veteran", "ace"]
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard", "Ace"]
## [profile, difficulty, enemy skill, enemy count]
const CASES := [
	["beginner", 0, 0, 1], ["beginner", 1, 0, 1], ["beginner", 1, 1, 1], ["beginner", 1, 2, 1],
	["beginner", 0, 0, 2], ["beginner", 1, 0, 2], ["beginner", 1, 0, 3],
	["evasive", 0, 0, 1], ["evasive", 1, 0, 1], ["evasive", 1, 1, 1], ["evasive", 1, 2, 1],
	["evasive", 1, 0, 2], ["evasive", 1, 0, 3],
]

var _plane_scene: PackedScene
var _terrain: Node3D
var _queue: Array = []
var _results := {}
var _player: Node3D
var _enemies: Array = []
var _case: Array
var _time := 0.0
var _done := false
var _cooldown := 0
## The beginner's current manoeuvre: bank angle, nose angle (or a hard pull
## when breaking) and how long to hold it.
var _bank := 0.0
var _nose := 0.0
var _hard_pull := false
var _hold := 0.0
var _break_time := 0.0


func _process(delta: float) -> bool:
	if _terrain == null:
		_setup()
		return false
	if _cooldown > 0:
		_cooldown -= 1
		return false
	if _player == null:
		if _queue.is_empty():
			_report()
			return true
		_start(_queue.pop_front())
		return false
	_time += delta
	if not _done and _time > TIME_LIMIT:
		_done = true
	if _done:
		_finish()
	else:
		_fly(delta)
	return false


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	var rounds := int(args[0]) if args.size() > 0 else 20
	_plane_scene = load("res://scenes/aircraft/enemy_plane.tscn")
	var arena := Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	current_scene = arena
	_terrain = StaticBody3D.new()
	_terrain.set_script(load("res://scripts/world/terrain.gd"))
	_terrain.tree_count = 0
	_terrain.add_to_group("terrain")
	arena.add_child(_terrain)
	for case in CASES:
		_results[case] = {survived = 0, times = [], collisions = 0, hits = 0, crashes = 0}
		for round in rounds:
			_queue.append(case)


func _start(case: Array) -> void:
	_case = case
	_time = 0.0
	_done = false
	_hold = 0.0
	_break_time = 0.0
	root.get_node("Settings").difficulty = case[1]
	var settings := root.get_node("Settings")
	var center := Vector3(randf_range(-300, 300), 0, randf_range(-300, 300))
	center.y = _terrain.get_height(center.x, center.z) + START_HEIGHT
	_player = _plane_scene.instantiate()
	_player.get_node("AI").free()
	var stats: AircraftStats = load("res://data/aircraft/scout.tres").duplicate()
	# The difficulty's "damage taken" applies to the player; tougher is the same thing.
	stats.max_health /= settings.difficulty_value("damage_taken")
	_player.stats = stats
	_player.team = 0
	_player.collision_layer = 2
	_player.collision_mask = 1 | 4 | 16
	_player.transform = Transform3D(Basis.IDENTITY, center).looking_at(center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Vector3.UP)
	_player.destroyed.connect(func(attacker: Node3D) -> void:
		_done = true
		if attacker == null:
			_results[_case].crashes += 1)
	_player.damaged.connect(_on_player_damaged)
	root.get_node("Arena").add_child(_player)
	_player.throttle = 0.8
	_enemies = []
	var angle := randf() * TAU
	for index in case[3]:
		var spawn := center + Vector3(cos(angle + index * 0.08), 0, sin(angle + index * 0.08)) * SPAWN_DISTANCE
		spawn.y = maxf(center.y, _terrain.get_height(spawn.x, spawn.z) + 250.0) + randf_range(-40, 80)
		var enemy := _plane_scene.instantiate()
		enemy.transform = Transform3D(Basis.IDENTITY, spawn).looking_at(center, Vector3.UP)
		enemy.get_node("AI").skill = case[2]
		enemy.get_node("AI").patrol_center = center
		root.get_node("Arena").add_child(enemy)
		_enemies.append(enemy)


func _on_player_damaged(amount: float, _attacker: Node3D) -> void:
	if is_inf(amount):
		_results[_case].collisions += 1
	else:
		_results[_case].hits += 1


## The pretend player's flying for one frame.
func _fly(delta: float) -> void:
	var nose: Vector3 = -_player.global_basis.z
	# Positive when banked to the right (right wing down).
	var bank: float = -asin(clampf(_player.global_basis.x.y, -1.0, 1.0))
	var height: float = _player.global_position.y - _terrain.get_height(_player.global_position.x, _player.global_position.z)
	_hold -= delta
	_break_time -= delta
	if _case[0] == "evasive" and _break_time <= 0.0 and _enemy_behind():
		# Break hard to one side for a couple of seconds.
		_bank = deg_to_rad(80.0) * (1.0 if randf() < 0.5 else -1.0)
		_hard_pull = true
		_hold = 2.5
		_break_time = 2.5
		_player.throttle = 1.0
	elif _hold <= 0.0:
		# A new gentle manoeuvre: straight, a lazy turn, or a mild climb or dive.
		_hard_pull = false
		_nose = 0.0
		match randi() % 4:
			0:
				_bank = 0.0
			1, 2:
				_bank = deg_to_rad(randf_range(20.0, 40.0)) * (1.0 if randf() < 0.5 else -1.0)
			3:
				_bank = 0.0
				_nose = deg_to_rad(randf_range(-8.0, 10.0))
		_hold = randf_range(3.0, 6.0)
		_player.throttle = 0.8
	# Keep away from the ground and don't climb for ever, like any player would.
	var target_nose := _nose
	if height < 200.0:
		target_nose = deg_to_rad(15.0)
	elif height > 900.0:
		target_nose = deg_to_rad(-8.0)
	var pull := 1.0 if _hard_pull and height > 150.0 else clampf((target_nose - asin(nose.y)) * 2.0, -1.0, 1.0)
	_player.roll_input = clampf((_bank - bank) * 3.0, -1.0, 1.0)
	_player.pitch_input = pull


func _enemy_behind() -> bool:
	for enemy in _enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var offset: Vector3 = _player.global_position - enemy.global_position
		if offset.length() < 500.0 and (-enemy.global_basis.z).angle_to(offset) < deg_to_rad(25.0):
			return true
	return false


func _finish() -> void:
	var result: Dictionary = _results[_case]
	if _player.is_alive():
		result.survived += 1
	result.times.append(_time)
	_player.queue_free()
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_player = null
	_cooldown = 5


func _report() -> void:
	print("")
	print("%-9s %-7s %-8s %7s %10s %13s %10s %8s %8s" % ["player", "level", "enemies", "survive", "median", "first 25% die", "collided", "hits/run", "crashed"])
	for case in CASES:
		var r: Dictionary = _results[case]
		var times: Array = r.times.duplicate()
		times.sort()
		print("%-9s %-7s %d x %-6s %6d%% %9.0fs %12.0fs %9d%% %8.1f %7d%%" % [
			case[0], DIFFICULTY_NAMES[case[1]], case[3], SKILL_NAMES[case[2]],
			100 * r.survived / times.size(), times[times.size() / 2], times[times.size() / 4],
			100 * r.collisions / times.size(), float(r.hits) / times.size(), 100 * r.crashes / times.size(),
		])
