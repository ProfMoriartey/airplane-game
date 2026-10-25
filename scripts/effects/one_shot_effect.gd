extends Node3D
## Plays every particle emitter in the effect once, fades its lights, then removes it.

@export var duration := 3.0
@export var light_fade_time := 0.4


func _ready() -> void:
	# Start at the end of the frame, after whoever spawned us has moved us into place.
	_play.call_deferred()


func _play() -> void:
	for child in get_children():
		if child is CPUParticles3D:
			child.restart()
		elif child is Light3D:
			create_tween().tween_property(child, "light_energy", 0.0, light_fade_time)
	get_tree().create_timer(duration).timeout.connect(queue_free)
