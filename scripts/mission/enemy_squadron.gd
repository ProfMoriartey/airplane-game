class_name EnemySquadron
extends Node3D
## A group of enemy fighters that appear here, flying the way this node faces,
## when a DestroyObjective that targets this squadron starts.

const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")

@export var count := 2
@export var skill := AircraftAI.Skill.ROOKIE
## Distance between planes, side by side.
@export var spacing := 60.0


func spawn() -> void:
	for index in count:
		var side := (index - (count - 1) * 0.5) * spacing
		var enemy := ENEMY_SCENE.instantiate() as Aircraft
		var ai := enemy.get_node("AI") as AircraftAI
		ai.skill = skill
		ai.patrol_center = global_position
		# top_level lets the planes fly freely instead of moving with this node.
		enemy.top_level = true
		enemy.transform = Transform3D(global_basis, global_position + global_basis.x * side)
		add_child(enemy)
