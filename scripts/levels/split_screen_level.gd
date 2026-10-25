extends Level
## Local split-screen for two players, each with their own device, camera and HUD.
##
## Co-op: both fight endless enemy waves together, sharing the score.
## Versus: the players fight each other; first to VERSUS_TARGET kills wins.
## A downed player comes back after a few seconds.

const PLAYER_SCENE := preload("res://scenes/aircraft/player_plane.tscn")
const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PREFIXES := ["p1_", "p2_"]
const RESPAWN_TIME := 5.0
const WRECK_CLEANUP_TIME := 8.0
const VERSUS_TARGET := 5
## Versus players start this far apart, flying at each other.
const VERSUS_DISTANCE := 1800.0
const WAVE_DELAY := 4.0
const MAX_WAVE_SIZE := 8
const SPAWN_DISTANCE := 1200.0

var _planes: Array[Aircraft] = [null, null]
var _cameras: Array[ChaseCamera] = []
var _huds: Array[HUD] = []
var _starts: Array[Transform3D] = []
var _scores := [0, 0]
var _finished := false
var _wave := 0
var _kills := 0
var _enemies_alive := 0


func _enter_tree() -> void:
	TheaterPresets.apply(TwoPlayer.theater, $Terrain)
	var weather := $Weather as Weather
	weather.time_of_day = TwoPlayer.time_of_day
	weather.kind = TwoPlayer.weather
	weather.cloud_altitude = TheaterPresets.THEATERS[TwoPlayer.theater].cloud_altitude
	$PlayerPlane.position.y = TheaterPresets.THEATERS[TwoPlayer.theater].start_height
	# Give each player their own actions before anything reads them.
	var players := {}
	for index in 2:
		var device: int = TwoPlayer.devices[index]
		players[PREFIXES[index]] = {keyboard = device == TwoPlayer.KEYBOARD, pad = Controls.NO_PAD if device == TwoPlayer.KEYBOARD else device}
	Controls.set_players(players)


func _exit_tree() -> void:
	Controls.clear_players()


func _ready() -> void:
	super()
	_build_screens()

	# Where each player starts (and comes back after being shot down).
	var first := player.global_transform
	if TwoPlayer.mode == TwoPlayer.Mode.COOP:
		_starts = [first, first.translated_local(Vector3(60, 0, 15))]
	else:
		var facing_back := Transform3D(Basis.IDENTITY, first.origin - first.basis.z * VERSUS_DISTANCE).looking_at(first.origin, Vector3.UP)
		_starts = [first, facing_back]

	_take_over(0, player)
	_spawn_player(1)
	Sound.start_flight_music()
	if TwoPlayer.mode == TwoPlayer.Mode.COOP:
		_announce("ENEMY FIGHTERS INBOUND")
		get_tree().create_timer(3.0, false).timeout.connect(_start_next_wave)
	else:
		_announce("FIRST TO %d WINS" % VERSUS_TARGET)
	_update_status()


func _physics_process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_planes[1]):
		var distance := Vector2(_planes[1].global_position.x, _planes[1].global_position.z).length()
		_huds[1].set_boundary_warning(distance > play_radius)


## Two views side by side (or stacked), each with its own camera and HUD,
## both looking into the same world.
func _build_screens() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -5
	add_child(layer)
	var split: BoxContainer = HBoxContainer.new() if TwoPlayer.layout == TwoPlayer.Layout.SIDE_BY_SIDE else VBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 4)
	layer.add_child(split)
	for index in 2:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_child(container)
		var view := SubViewport.new()
		view.world_3d = get_viewport().find_world_3d()
		view.msaa_3d = get_viewport().msaa_3d
		# Only one listener, or every sound would play twice.
		view.audio_listener_enable_3d = index == 0
		container.add_child(view)
		if index == 0:
			# Player 1 keeps the level's own camera and HUD.
			camera.reparent(view)
			hud.reparent(view)
			_cameras.append(camera)
			_huds.append(hud)
		else:
			var second_camera := ChaseCamera.new()
			second_camera.far = camera.far
			view.add_child(second_camera)
			var second_hud := HUD_SCENE.instantiate() as HUD
			view.add_child(second_hud)
			_cameras.append(second_camera)
			_huds.append(second_hud)
	for index in 2:
		_huds[index].set_compact()
		_cameras[index].controls = PREFIXES[index]
		_cameras[index].mouse_look = TwoPlayer.devices[index] == TwoPlayer.KEYBOARD


func _spawn_player(index: int) -> void:
	var plane := PLAYER_SCENE.instantiate() as Aircraft
	plane.transform = _starts[index]
	if TwoPlayer.mode == TwoPlayer.Mode.VERSUS and index == 1:
		plane.team = Aircraft.Team.CENTRAL
		# Player 2's plane must be hittable by player 1's bullets, and vice versa.
		plane.collision_layer = 4
		plane.collision_mask = 1 | 2 | 16
	add_child(plane)
	_take_over(index, plane)


## Hands a plane to a player: their controls, camera and HUD.
func _take_over(index: int, plane: Aircraft) -> void:
	_planes[index] = plane
	plane.controls = PREFIXES[index]
	plane.add_to_group("player")
	var aircraft := Profile.selected_aircraft() if index == 0 else _second_aircraft()
	plane.set_stats(aircraft, Profile.livery_of(aircraft.id) if index == 0 else 0)
	if index == 0:
		player = plane
	_cameras[index].set_target(plane)
	_huds[index].setup(plane)
	_huds[index].get_node("Help").visible = false
	plane.damaged.connect(func(amount: float, _attacker: Aircraft) -> void: _cameras[index].add_shake(minf(amount / 20.0, 0.5)))
	plane.destroyed.connect(_on_player_plane_destroyed.bind(index))
	plane.crashed.connect(_on_player_plane_crashed.bind(index, plane))


func _second_aircraft() -> AircraftStats:
	for aircraft in Profile.unlocked_aircraft():
		if aircraft.id == TwoPlayer.second_aircraft:
			return aircraft
	return Profile.PLAYER_AIRCRAFT[0]


func _on_player_plane_destroyed(attacker: Aircraft, index: int) -> void:
	if _finished:
		return
	_huds[index].show_message("SHOT DOWN\nBack in the air shortly..." if attacker else "CRASHED\nBack in the air shortly...")
	if TwoPlayer.mode == TwoPlayer.Mode.VERSUS and attacker:
		var winner := 1 - index
		_scores[winner] += 1
		_update_status()
		if _scores[winner] >= VERSUS_TARGET:
			_finish(winner)
			return
	get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn.bind(index))


func _on_player_plane_crashed(index: int, plane: Aircraft) -> void:
	_cameras[index].add_shake(1.0)
	get_tree().create_timer(WRECK_CLEANUP_TIME, false).timeout.connect(plane.queue_free)


func _respawn(index: int) -> void:
	if _finished:
		return
	var old := _planes[index]
	# In co-op, come back alongside your partner if they're still flying.
	var partner := _planes[1 - index]
	if TwoPlayer.mode == TwoPlayer.Mode.COOP and is_instance_valid(partner) and partner.is_alive():
		_starts[index] = partner.global_transform.translated_local(Vector3(60, 0, 15))
	if is_instance_valid(old):
		old.remove_from_group("player")
	_spawn_player(index)
	_huds[index].show_message("")


func _finish(winner: int) -> void:
	_finished = true
	for index in 2:
		_huds[index].show_message("PLAYER %d WINS!\n%d - %d\nPause to restart or quit" % [winner + 1, _scores[0], _scores[1]])
	Sound.stop_flight_music()
	Sound.play_music("victory")


## --- Co-op waves ---

func _start_next_wave() -> void:
	if _finished:
		return
	_wave += 1
	var skill := AircraftAI.Skill.ROOKIE
	if _wave > 6:
		skill = AircraftAI.Skill.ACE
	elif _wave > 3:
		skill = AircraftAI.Skill.VETERAN
	var center := _players_center()
	var angle := randf() * TAU
	for index in mini(_wave + 1, MAX_WAVE_SIZE):
		_spawn_enemy(skill, center, angle + index * 0.08)
	_announce("WAVE %d" % _wave)
	_update_status()


func _spawn_enemy(skill: AircraftAI.Skill, center: Vector3, angle: float) -> void:
	var spawn := center + Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_DISTANCE
	spawn.y = maxf(center.y, terrain.get_height(spawn.x, spawn.z) + 250.0) + randf_range(-40.0, 80.0)
	var enemy := ENEMY_SCENE.instantiate() as Aircraft
	enemy.transform = Transform3D(Basis.IDENTITY, spawn).looking_at(center, Vector3.UP)
	var ai := enemy.get_node("AI") as AircraftAI
	ai.skill = skill
	ai.patrol_center = Vector3(0.0, spawn.y, 0.0)
	enemy.destroyed.connect(_on_enemy_destroyed)
	add_child(enemy)
	_enemies_alive += 1


func _on_enemy_destroyed(attacker: Aircraft) -> void:
	_enemies_alive -= 1
	if attacker in _planes:
		_kills += 1
		_huds[_planes.find(attacker)].flash_banner("ENEMY DOWN")
	_update_status()
	if _enemies_alive == 0:
		for plane in _planes:
			if is_instance_valid(plane):
				plane.repair()
		_announce("WAVE CLEARED - REPAIRED AND REARMED")
		get_tree().create_timer(WAVE_DELAY, false).timeout.connect(_start_next_wave)


func _players_center() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for plane in _planes:
		if is_instance_valid(plane) and plane.is_alive():
			sum += plane.global_position
			count += 1
	return sum / count if count > 0 else _starts[0].origin


## --- Shared ---

func _announce(text: String) -> void:
	for each_hud in _huds:
		each_hud.flash_banner(text)


func _update_status() -> void:
	var text := "WAVE %d     KILLS %d" % [_wave, _kills] if TwoPlayer.mode == TwoPlayer.Mode.COOP \
		else "PLAYER 1   %d  -  %d   PLAYER 2" % [_scores[0], _scores[1]]
	for each_hud in _huds:
		each_hud.set_status_text(text)


func _on_hit_landed(shooter: Aircraft, _target: Node3D, _position: Vector3) -> void:
	var index := _planes.find(shooter)
	if index >= 0:
		_huds[index].show_hit_marker()


## Player 1's plane is handled through _take_over like player 2's.
func _on_player_destroyed(_attacker: Aircraft) -> void:
	pass


func _on_player_damaged(_amount: float, _attacker: Aircraft) -> void:
	pass


func _on_player_crashed() -> void:
	pass
