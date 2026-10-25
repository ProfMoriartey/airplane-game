extends Level
## Quick Battle: endless, growing waves of enemy fighters, over the landscape,
## weather and time of day chosen on the Quick Battle screen.

const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")
const FIRST_WAVE_DELAY := 3.0
const WAVE_DELAY := 4.0
const MAX_WAVE_SIZE := 6
const SPAWN_DISTANCE := 1100.0
## Planes the Allies send against a player flying for the Central Powers.
const ALLIED_FIGHTERS: Array[AircraftStats] = [
	preload("res://data/aircraft/scout.tres"),
	preload("res://data/aircraft/lark.tres"),
	preload("res://data/aircraft/hornet.tres"),
]

var _wave := 0
var _kills := 0
var _enemies_alive := 0


func _enter_tree() -> void:
	# Before the terrain and weather build themselves.
	TheaterPresets.apply(QuickBattle.theater, $Terrain)
	var weather := $Weather as Weather
	weather.time_of_day = QuickBattle.time_of_day
	weather.kind = QuickBattle.weather
	weather.cloud_altitude = TheaterPresets.THEATERS[QuickBattle.theater].cloud_altitude
	$PlayerPlane.position.y = TheaterPresets.THEATERS[QuickBattle.theater].start_height


func _ready() -> void:
	super()
	var aircraft := Profile.selected_aircraft()
	# Flying for the other side: change team (and markings) before the plane is rebuilt.
	player.team = QuickBattle.side
	player.set_stats(aircraft, Profile.livery_of(aircraft.id))
	Sound.start_flight_music()
	_update_status()
	hud.flash_banner("ALLIED FIGHTERS INBOUND" if _flying_for_central() else "ENEMY FIGHTERS INBOUND")
	get_tree().create_timer(FIRST_WAVE_DELAY, false).timeout.connect(_start_next_wave)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not player.is_alive():
		restart()


func _start_next_wave() -> void:
	if not player.is_alive():
		return
	_wave += 1
	var skill := AircraftAI.Skill.ROOKIE
	if QuickBattle.enemy_skill >= 0:
		skill = QuickBattle.enemy_skill
	elif _wave > 6:
		skill = AircraftAI.Skill.ACE
	elif _wave > 3:
		skill = AircraftAI.Skill.VETERAN

	var spawn_angle := randf() * TAU
	for index in mini(_wave, MAX_WAVE_SIZE):
		_spawn_enemy(skill, spawn_angle + index * 0.08)
	_update_status()
	hud.flash_banner("WAVE %d" % _wave)


func _spawn_enemy(skill: AircraftAI.Skill, angle: float) -> void:
	var spawn := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_DISTANCE
	var ground := terrain.get_height(spawn.x, spawn.z)
	spawn.y = maxf(player.global_position.y, ground + 250.0) + randf_range(-40.0, 80.0)

	var enemy := ENEMY_SCENE.instantiate() as Aircraft
	if _flying_for_central():
		enemy.team = Aircraft.Team.ALLIES
		enemy.stats = ALLIED_FIGHTERS.pick_random()
	enemy.transform = Transform3D(Basis.IDENTITY, spawn).looking_at(player.global_position, Vector3.UP)
	var ai := enemy.get_node("AI") as AircraftAI
	ai.skill = skill
	ai.patrol_center = Vector3(0.0, spawn.y, 0.0)
	enemy.destroyed.connect(_on_enemy_destroyed)
	add_child(enemy)
	_enemies_alive += 1


func _flying_for_central() -> bool:
	return QuickBattle.side == Aircraft.Team.CENTRAL


func _update_status() -> void:
	hud.set_status_text("WAVE %d     KILLS %d" % [_wave, _kills])


func _on_enemy_destroyed(attacker: Aircraft) -> void:
	_enemies_alive -= 1
	if attacker == player:
		_kills += 1
		hud.flash_banner("ENEMY DOWN")
	_update_status()
	if _enemies_alive == 0 and player.is_alive():
		player.repair()
		hud.flash_banner("WAVE CLEARED - REPAIRED AND REARMED")
		get_tree().create_timer(WAVE_DELAY, false).timeout.connect(_start_next_wave)


func _on_player_destroyed(attacker: Aircraft) -> void:
	var reason := "SHOT DOWN" if attacker else "CRASHED"
	hud.show_message("%s\nPress R to restart" % reason)
