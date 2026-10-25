class_name Level
extends Node3D
## Shared setup for every playable level: the player's plane, camera, HUD,
## pause menu and the edge-of-map warning. Free flight and missions build on this.

const WIND_SOUND := preload("res://assets/audio/sfx/wind_loop.wav")
const RENDER_DIAGNOSTICS := preload("res://scripts/debug/render_diagnostics.gd")
## Enemies closer than this switch the music to the combat theme.
const COMBAT_MUSIC_RANGE := 1300.0

## Distance from the map centre where the "turn back" warning appears.
@export var play_radius := 2200.0

## Bullets the player has landed on enemies, for accuracy stats.
var player_hits := 0

var _wind: AudioStreamPlayer

@onready var player: Aircraft = $PlayerPlane
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: HUD = $HUD
@onready var terrain: Terrain = $Terrain
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	Projectiles.clear()
	Projectiles.hit_landed.connect(_on_hit_landed)
	player.add_to_group("player")
	hud.setup(player)
	player.damaged.connect(_on_player_damaged)
	player.destroyed.connect(_on_player_destroyed)
	player.crashed.connect(_on_player_crashed)
	pause_menu.restart_requested.connect(restart)
	# Created here rather than where it's declared: levels swap in their own
	# script, and anything made before that would be thrown away and leak.
	_wind = AudioStreamPlayer.new()
	_wind.stream = WIND_SOUND
	_wind.bus = &"SFX"
	_wind.volume_db = -30.0
	add_child(_wind)
	_wind.play()
	var diagnostics := RENDER_DIAGNOSTICS.new()
	add_child(diagnostics)
	diagnostics.setup(hud)


func _physics_process(_delta: float) -> void:
	var distance := Vector2(player.global_position.x, player.global_position.z).length()
	hud.set_boundary_warning(distance > play_radius)
	_update_wind()
	if _enemy_nearby():
		Sound.report_combat()


## Wind rushes louder and higher as the plane speeds up.
func _update_wind() -> void:
	var rush := player.get_speed_ratio() if player.is_alive() else 0.0
	_wind.volume_db = lerpf(-24.0, -6.0, rush)
	_wind.pitch_scale = lerpf(0.8, 1.3, rush)


func _enemy_nearby() -> bool:
	if not player.is_alive():
		return false
	for node in get_tree().get_nodes_in_group("aircraft"):
		var other := node as Aircraft
		if other.is_alive() and player.is_hostile_to(other) \
				and other.global_position.distance_to(player.global_position) < COMBAT_MUSIC_RANGE:
			return true
	return false


func restart() -> void:
	SceneLoader.reload()


func _on_hit_landed(shooter: Aircraft, _target: Node3D, _position: Vector3) -> void:
	if shooter == player:
		player_hits += 1
		hud.show_hit_marker()


func _on_player_damaged(amount: float, _attacker: Aircraft) -> void:
	camera.add_shake(minf(amount / 20.0, 0.5))


## Override to decide what happens when the player goes down.
func _on_player_destroyed(_attacker: Aircraft) -> void:
	pass


func _on_player_crashed() -> void:
	camera.add_shake(1.0)
