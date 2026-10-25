extends Node3D
## Turns slowly around its own forward axis, like windmill sails.

@export var speed := 0.6 ## Radians per second.


func _process(delta: float) -> void:
	rotate_object_local(Vector3.BACK, speed * delta)
