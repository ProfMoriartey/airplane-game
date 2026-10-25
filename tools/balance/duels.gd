extends SceneTree
## Balance testing: AI pilots fly one-on-one duels, many times over, to measure
## how strong each aircraft really is. Nothing is drawn, and time runs as fast
## as the computer allows.
##
## Run from the project folder (results are printed at the end):
##   godot --headless --fixed-fps 60 --path . -s res://tools/balance/duels.gd -- <set> [rounds]
## Sets:
##   fighters  every player aircraft against the standard enemy fighter
##   roster    every player aircraft against the Scout (the starting plane)
##   aces      the named aces against a skilled pilot in each player aircraft
##   skills    a Scout against enemy fighters flown by rookies, veterans and aces

## Game files are loaded on the first frame: the game's autoloads (Settings
## and so on) don't exist yet while this script itself is being set up.
var _plane_scene: PackedScene
const PLAYER_AIRCRAFT := ["scout", "lark", "hornet", "falcon", "kestrel"]
const ACES := ["ace_hussar", "ace_black", "ace_iron", "enemy_ace"]
const ROOKIE := 0
const VETERAN := 1
const ACE := 2
const SKILL_NAMES := ["rookie", "veteran", "ace"]
## Duels longer than this count as a draw.
const TIME_LIMIT := 150.0
## Starting distance, flying towards each other.
const START_DISTANCE := 1200.0
const START_HEIGHT := 450.0

var _queue: Array[Dictionary] = []
var _results := {}
var _order: Array[String] = []
var _current: Dictionary
var _planes: Array = []
var _elapsed := 0.0
var _outcome := ""
var _cooldown := 0
var _terrain: Node3D
var _started_at := 0


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	var set_name: String = args[0] if args.size() > 0 else "fighters"
	var rounds := int(args[1]) if args.size() > 1 else 20
	_build_matchups(set_name, rounds)
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
	_started_at = Time.get_ticks_msec()
	print("Running %d duels (%s)..." % [_queue.size(), set_name])


func _build_matchups(set_name: String, rounds: int) -> void:
	var pairs := []
	match set_name:
		"fighters":
			for id in PLAYER_AIRCRAFT:
				pairs.append([id, VETERAN, "enemy_fighter", VETERAN])
		"roster":
			for id in PLAYER_AIRCRAFT:
				pairs.append([id, VETERAN, "scout", VETERAN])
		"aces":
			for ace in ACES:
				for id in PLAYER_AIRCRAFT:
					pairs.append([id, ACE, ace, ACE])
		"skills":
			for skill in [ROOKIE, VETERAN, ACE]:
				pairs.append(["scout", VETERAN, "enemy_fighter", skill])
	for pair in pairs:
		var key := "%s (%s) vs %s (%s)" % [pair[0], SKILL_NAMES[pair[1]], pair[2], SKILL_NAMES[pair[3]]]
		_order.append(key)
		_results[key] = {wins = 0, losses = 0, draws = 0, crashes = 0, kill_time = 0.0, health_left = 0.0}
		for round in rounds:
			_queue.append({key = key, a = pair[0], a_skill = pair[1], b = pair[2], b_skill = pair[3]})


func _process(delta: float) -> bool:
	if _terrain == null:
		_setup()
		return false
	if _cooldown > 0:
		_cooldown -= 1
		return false
	if _planes.is_empty():
		if _queue.is_empty():
			_report()
			return true
		_start(_queue.pop_front())
		return false
	_elapsed += delta
	if _outcome == "" and _elapsed > TIME_LIMIT:
		_outcome = "draw"
	if _outcome != "":
		_finish()
	return false


func _start(matchup: Dictionary) -> void:
	_current = matchup
	_elapsed = 0.0
	_outcome = ""
	var center := Vector3(randf_range(-400, 400), 0, randf_range(-400, 400))
	center.y = _terrain.get_height(center.x, center.z) + START_HEIGHT
	var offset := Vector3(START_DISTANCE * 0.5, 0, randf_range(-150, 150))
	_planes = [
		_spawn(matchup.a, matchup.a_skill, 0, center - offset, center + offset),
		_spawn(matchup.b, matchup.b_skill, 1, center + offset, center - offset),
	]
	for index in 2:
		_planes[index].destroyed.connect(_on_destroyed.bind(index))


func _spawn(id: String, skill: int, team: int, at: Vector3, facing: Vector3) -> Node3D:
	var plane := _plane_scene.instantiate()
	plane.stats = load("res://data/aircraft/%s.tres" % id)
	plane.team = team
	if team == 0:
		# Same collision layers as the player's side.
		plane.collision_layer = 2
		plane.collision_mask = 1 | 4 | 16
	var ai := plane.get_node("AI")
	ai.skill = skill
	ai.patrol_center = at
	plane.transform = Transform3D(Basis.IDENTITY, at).looking_at(facing + Vector3(randf_range(-60, 60), 0, 0), Vector3.UP)
	root.get_node("Arena").add_child(plane)
	return plane


func _on_destroyed(attacker: Node3D, index: int) -> void:
	if _outcome != "":
		return
	var other: Node3D = _planes[1 - index]
	if attacker == other:
		_outcome = "a" if index == 1 else "b"
	else:
		_outcome = "crash_a" if index == 0 else "crash_b"


func _finish() -> void:
	var result: Dictionary = _results[_current.key]
	match _outcome:
		"a":
			result.wins += 1
			result.kill_time += _elapsed
			result.health_left += _planes[0].get_health_ratio()
		"b":
			result.losses += 1
		"crash_a":
			result.losses += 1
			result.crashes += 1
		"crash_b":
			result.wins += 1
			result.crashes += 1
		_:
			result.draws += 1
	for plane in _planes:
		if is_instance_valid(plane):
			plane.queue_free()
	_planes = []
	_cooldown = 5


func _report() -> void:
	print("")
	print("%-44s %6s %6s %6s %8s %9s %8s" % ["matchup (first plane's view)", "win%", "loss%", "draw%", "crashes", "kill time", "hp left"])
	for key in _order:
		var r: Dictionary = _results[key]
		var total: int = maxi(r.wins + r.losses + r.draws, 1)
		print("%-44s %5d%% %5d%% %5d%% %8d %8.0fs %7d%%" % [
			key, 100 * r.wins / total, 100 * r.losses / total, 100 * r.draws / total, r.crashes,
			r.kill_time / maxi(r.wins, 1), 100.0 * r.health_left / maxi(r.wins, 1),
		])
	print("(%d s)" % ((Time.get_ticks_msec() - _started_at) / 1000))
