extends Node3D
## Keeps this node centred on the active camera's position (but not its rotation),
## e.g. so rain always falls around the player.


func _ready() -> void:
	top_level = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
