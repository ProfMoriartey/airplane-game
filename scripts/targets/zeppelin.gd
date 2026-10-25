class_name Zeppelin
extends GroundTarget
## A huge, slow airship. When it's shot down it catches fire along its length
## and sinks to the ground.

@export var fall_time := 12.0


func _destroy(attacker: Aircraft) -> void:
	super(attacker)
	for flames in find_children("Fire*", "CPUParticles3D"):
		flames.emitting = true
	var mover := get_node_or_null("PathMover")
	if mover:
		mover.process_mode = Node.PROCESS_MODE_DISABLED
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var ground := terrain.get_surface_height(global_position.x, global_position.z) if terrain else 0.0
	var tween := create_tween().set_parallel()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position:y", ground, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The nose drops as the hull burns through.
	tween.tween_property(self, "rotation:x", -0.35, fall_time)
