class_name Level
extends Node3D
## Shared setup for every playable level: the player's plane, camera, HUD,
## pause menu and the edge-of-map warning. Free flight and missions build on this.

## Distance from the map centre where the "turn back" warning appears.
@export var play_radius := 2200.0

## Bullets the player has landed on enemies, for accuracy stats.
var player_hits := 0

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


func _physics_process(_delta: float) -> void:
	var distance := Vector2(player.global_position.x, player.global_position.z).length()
	hud.set_boundary_warning(distance > play_radius)


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
