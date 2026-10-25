extends RigidBody3D
## A piece of a wrecked plane that tumbles to the ground, then disappears.

@export var lifetime := 10.0


func _ready() -> void:
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)
