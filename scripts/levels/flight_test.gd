extends Node3D
## Sandbox level for trying out and tuning the flight model.

## Distance from the map centre where the "turn back" warning appears.
@export var play_radius := 2200.0

@onready var _plane: Aircraft = $PlayerPlane
@onready var _camera: ChaseCamera = $ChaseCamera
@onready var _hud := $HUD


func _ready() -> void:
	_hud.setup(_plane)
	_plane.crashed.connect(_on_plane_crashed)


func _physics_process(_delta: float) -> void:
	var distance := Vector2(_plane.global_position.x, _plane.global_position.z).length()
	_hud.set_boundary_warning(distance > play_radius)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_plane_crashed() -> void:
	_camera.add_shake(1.0)
	_hud.show_message("CRASHED\nPress R to restart")
