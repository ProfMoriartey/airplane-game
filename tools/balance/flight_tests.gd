extends SceneTree
## Balance testing: flies every aircraft through the same set of manoeuvres
## with the real flight model and prints a comparison table.
##
##   godot --headless --fixed-fps 60 --path . -s res://tools/balance/flight_tests.gd
##
## Columns:
##   top speed    level flight at full throttle (km/h)
##   0-95%        seconds from mission start speed to 95% of top speed
##   turn         seconds for a full-throttle 360° turn, and its diameter
##   climb        metres per second climbing at full throttle, nose 20° up
##   dps          damage per second with every bullet hitting
##   kill F / A   seconds of hits to shoot down an enemy fighter / an enemy ace (Iron Baron)
##   survive      seconds an enemy fighter needs, every bullet hitting, to shoot it down

const AIRCRAFT := [
	"scout", "lark", "hornet", "falcon", "kestrel",
	"enemy_fighter", "enemy_ace", "ace_hussar", "ace_black", "ace_iron", "allied_bomber",
]
const START_HEIGHT := 1500.0

var _plane_scene: PackedScene
var _arena: Node3D
var _plane: Node3D
var _queue: Array = []
var _test := ""
var _time := 0.0
var _data := {}
var _rows := {}
var _id := ""


func _process(delta: float) -> bool:
	if _arena == null:
		_setup()
		return false
	if _plane == null:
		if _queue.is_empty():
			_report()
			return true
		var next: Array = _queue.pop_front()
		_start(next[0], next[1])
		return false
	_time += delta
	if _step(delta):
		_plane.queue_free()
		_plane = null
	return false


func _setup() -> void:
	_plane_scene = load("res://scenes/aircraft/enemy_plane.tscn")
	_arena = Node3D.new()
	root.add_child(_arena)
	current_scene = _arena
	for id in AIRCRAFT:
		for test in ["speed", "turn", "climb"]:
			_queue.append([id, test])
		_rows[id] = {}


func _start(id: String, test: String) -> void:
	_id = id
	_test = test
	_time = 0.0
	_data = {}
	_plane = _plane_scene.instantiate()
	_plane.get_node("AI").free()
	_plane.stats = load("res://data/aircraft/%s.tres" % id)
	_plane.transform = Transform3D(Basis.IDENTITY, Vector3(0, START_HEIGHT, 0))
	_arena.add_child(_plane)
	_plane.throttle = 1.0
	if test != "speed":
		_plane.speed = _plane.stats.max_speed


## Flies one frame of the current test. Returns true when the test is done.
func _step(_delta: float) -> bool:
	var nose: Vector3 = -_plane.global_basis.z
	# Positive when banked to the right (right wing down).
	var bank: float = -asin(clampf(_plane.global_basis.x.y, -1.0, 1.0))
	var row: Dictionary = _rows[_id]
	match _test:
		"speed":
			# Hold the nose level.
			_plane.pitch_input = clampf(-nose.y * 8.0, -1.0, 1.0)
			_plane.roll_input = clampf(-bank * 3.0, -1.0, 1.0)
			if not _data.has("reached") and _plane.speed >= _plane.stats.max_speed * 0.95:
				_data.reached = _time
			if _time > 60.0:
				row.top_speed = _plane.speed * 3.6
				row.accel = _data.get("reached", 99.0)
				return true
		"turn":
			# Bank to 75° and pull all the way round.
			var heading := atan2(nose.x, nose.z)
			if _data.is_empty():
				_data = {last = heading, turned = 0.0, start = _plane.global_position, far = 0.0}
			_plane.roll_input = clampf((deg_to_rad(75.0) - bank) * 3.0, -1.0, 1.0)
			_plane.pitch_input = 1.0
			_data.turned += absf(wrapf(heading - _data.last, -PI, PI))
			_data.last = heading
			var flat: Vector3 = _plane.global_position - _data.start
			_data.far = maxf(_data.far, Vector2(flat.x, flat.z).length())
			if _data.turned >= TAU:
				row.turn = _time
				row.turn_diameter = _data.far
				return true
			if _time > 60.0:
				row.turn = 99.0
				row.turn_diameter = _data.far
				return true
		"climb":
			_plane.pitch_input = clampf((deg_to_rad(20.0) - asin(nose.y)) * 4.0, -1.0, 1.0)
			_plane.roll_input = clampf(-bank * 3.0, -1.0, 1.0)
			if _time > 4.0 and not _data.has("height"):
				_data.height = _plane.global_position.y
			if _time > 14.0:
				row.climb = (_plane.global_position.y - _data.height) / 10.0
				return true
	return false


func _report() -> void:
	var fighter: AircraftStats = load("res://data/aircraft/enemy_fighter.tres")
	var baron: AircraftStats = load("res://data/aircraft/ace_iron.tres")
	var fighter_dps := fighter.gun_fire_rate * fighter.gun_damage
	print("")
	print("%-14s %5s %6s %5s %7s %6s %5s %4s %7s %7s %7s %6s" % ["aircraft", "rank", "km/h", "0-95%", "turn", "diam", "climb", "hp", "dps", "kill F", "kill A", "survive"])
	for id in AIRCRAFT:
		var stats: AircraftStats = load("res://data/aircraft/%s.tres" % id)
		var row: Dictionary = _rows[id]
		var dps := stats.gun_fire_rate * stats.gun_damage
		print("%-14s %5s %6d %4.0fs %6.1fs %5dm %4.1f %4d %7.0f %6.1fs %6.1fs %6.1fs" % [
			id, str(stats.unlock_rank) if stats.unlock_rank < 99 else "-", row.top_speed, row.accel,
			row.turn, row.turn_diameter, row.climb, stats.max_health, dps,
			fighter.max_health / dps, baron.max_health / dps, stats.max_health / fighter_dps,
		])
