class_name Balloon
extends GroundTarget
## An observation balloon on a long tether. When shot down it burns and falls.

@export var fall_time := 6.0

@onready var _tether: MeshInstance3D = $Tether


func _ready() -> void:
	super()
	# Stretch the tether (a 1 m tall cylinder) from the basket down to the ground.
	_tether.scale.y = ground_offset
	_tether.position.y = -ground_offset * 0.5


func _destroy(attacker: Aircraft) -> void:
	super(attacker)
	_tether.visible = false
	var ground := global_position.y - ground_offset
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position:y", ground, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
