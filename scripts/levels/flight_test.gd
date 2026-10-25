extends Node3D
## Sandbox level: free flight against endless, growing waves of enemy fighters.

const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")
const FIRST_WAVE_DELAY := 3.0
const WAVE_DELAY := 4.0
const MAX_WAVE_SIZE := 6
const SPAWN_DISTANCE := 1100.0
## Wrecks are removed this long after hitting the ground, once their smoke has drifted away.
const WRECK_CLEANUP_TIME := 6.0

## Distance from the map centre where the "turn back" warning appears.
@export var play_radius := 2200.0

var _wave := 0
var _kills := 0
var _enemies_alive := 0

@onready var _plane: Aircraft = $PlayerPlane
@onready var _camera: ChaseCamera = $ChaseCamera
@onready var _hud := $HUD
@onready var _terrain: Terrain = $Terrain


func _ready() -> void:
	Projectiles.clear()
	Projectiles.hit_landed.connect(_on_hit_landed)
	_hud.setup(_plane)
	_hud.set_score(0, 0)
	_plane.damaged.connect(_on_player_damaged)
	_plane.destroyed.connect(_on_player_destroyed)
	_plane.crashed.connect(_on_player_crashed)
	_hud.flash_banner("ENEMY FIGHTERS INBOUND")
	get_tree().create_timer(FIRST_WAVE_DELAY).timeout.connect(_start_next_wave)


func _physics_process(_delta: float) -> void:
	var distance := Vector2(_plane.global_position.x, _plane.global_position.z).length()
	_hud.set_boundary_warning(distance > play_radius)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _start_next_wave() -> void:
	if not _plane.is_alive():
		return
	_wave += 1
	var skill := AircraftAI.Skill.ROOKIE
	if _wave > 6:
		skill = AircraftAI.Skill.ACE
	elif _wave > 3:
		skill = AircraftAI.Skill.VETERAN

	var spawn_angle := randf() * TAU
	for index in mini(_wave, MAX_WAVE_SIZE):
		_spawn_enemy(skill, spawn_angle + index * 0.08)
	_hud.set_score(_wave, _kills)
	_hud.flash_banner("WAVE %d" % _wave)


func _spawn_enemy(skill: AircraftAI.Skill, angle: float) -> void:
	var spawn := _plane.global_position + Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_DISTANCE
	var ground := _terrain.get_height(spawn.x, spawn.z)
	spawn.y = maxf(_plane.global_position.y, ground + 250.0) + randf_range(-40.0, 80.0)

	var enemy := ENEMY_SCENE.instantiate() as Aircraft
	enemy.transform = Transform3D(Basis.IDENTITY, spawn).looking_at(_plane.global_position, Vector3.UP)
	var ai := enemy.get_node("AI") as AircraftAI
	ai.skill = skill
	ai.patrol_center = Vector3(0.0, spawn.y, 0.0)
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.crashed.connect(_on_enemy_crashed.bind(enemy))
	add_child(enemy)
	_enemies_alive += 1


func _on_enemy_destroyed(attacker: Aircraft) -> void:
	_enemies_alive -= 1
	if attacker == _plane:
		_kills += 1
		_hud.flash_banner("ENEMY DOWN")
	_hud.set_score(_wave, _kills)
	if _enemies_alive == 0 and _plane.is_alive():
		_plane.repair()
		_hud.flash_banner("WAVE CLEARED - REPAIRED AND REARMED")
		get_tree().create_timer(WAVE_DELAY).timeout.connect(_start_next_wave)


func _on_enemy_crashed(enemy: Aircraft) -> void:
	get_tree().create_timer(WRECK_CLEANUP_TIME).timeout.connect(enemy.queue_free)


func _on_hit_landed(shooter: Aircraft, _target: Aircraft, _position: Vector3) -> void:
	if shooter == _plane:
		_hud.show_hit_marker()


func _on_player_damaged(amount: float, _attacker: Aircraft) -> void:
	_camera.add_shake(minf(amount / 20.0, 0.5))


func _on_player_destroyed(attacker: Aircraft) -> void:
	var reason := "SHOT DOWN" if attacker else "CRASHED"
	_hud.show_message("%s\nPress R to restart" % reason)


func _on_player_crashed() -> void:
	_camera.add_shake(1.0)
