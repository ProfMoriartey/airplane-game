class_name EnemySquadron
extends Node3D
## A group of enemy fighters that appear here, flying the way this node faces,
## when an objective that uses this squadron starts.

const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")

@export var count := 2
@export var skill := AircraftAI.Skill.ROOKIE
## Distance between planes, side by side.
@export var spacing := 60.0
## Go after balloons, guns and other ground targets, not just aircraft.
@export var attack_ground_targets := false
## Never shoot: harmless target planes, e.g. for training.
@export var passive := false

@export_group("Leader")
## Optional: the first plane is a named ace flying this aircraft type.
@export var leader_name := ""
@export var leader_stats: AircraftStats
@export var leader_skill := AircraftAI.Skill.ACE


## Launches the squadron and returns its planes.
func spawn() -> Array[Aircraft]:
	var planes: Array[Aircraft] = []
	for index in count:
		var side := (index - (count - 1) * 0.5) * spacing
		var enemy := ENEMY_SCENE.instantiate() as Aircraft
		var ai := enemy.get_node("AI") as AircraftAI
		ai.skill = skill
		ai.patrol_center = global_position
		ai.attack_ground_targets = attack_ground_targets
		ai.passive = passive
		if index == 0 and leader_name != "":
			enemy.pilot_name = leader_name
			ai.skill = leader_skill
			ai.attack_ground_targets = false
			if leader_stats:
				enemy.stats = leader_stats
		# top_level lets the planes fly freely instead of moving with this node.
		enemy.top_level = true
		enemy.transform = Transform3D(global_basis, global_position + global_basis.x * side)
		add_child(enemy)
		planes.append(enemy)
	return planes
