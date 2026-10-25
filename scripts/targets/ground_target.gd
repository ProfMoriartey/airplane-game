class_name GroundTarget
extends StaticBody3D
## Something on the ground that can be destroyed: vehicles, guns, buildings, balloons.
##
## Placed on the terrain automatically when the level starts. When destroyed it
## explodes, turns into a dark smouldering wreck, and reports who destroyed it.

signal destroyed(attacker: Aircraft)

const EXPLOSION_SCENE := preload("res://scenes/effects/explosion.tscn")
const WRECK_SMOKE_SCENE := preload("res://scenes/effects/wreck_smoke.tscn")
const WRECK_COLOR := Color(0.1, 0.09, 0.08)

@export var display_name := "Target"
@export var team := Aircraft.Team.CENTRAL
@export var max_health := 40.0
## Bullets only do this fraction of their damage: low for armour and buildings,
## which really need bombs.
@export_range(0.0, 1.0) var bullet_damage_scale := 1.0
@export var score_value := 100
## Height above the ground. The target is moved onto the terrain when the level starts.
@export var ground_offset := 0.0
@export var snap_to_ground := true
@export var smoke_when_destroyed := true
## Buildings slump into a pile of rubble when destroyed.
@export var collapse_on_destroy := false

var health := 0.0
var is_destroyed := false


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("ground_targets")
	health = max_health
	if snap_to_ground:
		place_on_ground()


func is_alive() -> bool:
	return not is_destroyed


func place_on_ground() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if terrain:
		global_position.y = terrain.get_surface_height(global_position.x, global_position.z) + ground_offset


func take_damage(
	amount: float,
	_hit_position: Vector3,
	attacker: Aircraft,
	kind := Damage.Kind.BULLET,
) -> void:
	if is_destroyed:
		return
	if kind == Damage.Kind.BULLET:
		amount *= bullet_damage_scale
	health -= amount
	if health <= 0.0:
		_destroy(attacker)


func _destroy(attacker: Aircraft) -> void:
	is_destroyed = true
	health = 0.0

	var explosion := EXPLOSION_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position + Vector3.UP * 2.0

	var wreck := StandardMaterial3D.new()
	wreck.albedo_color = WRECK_COLOR
	wreck.roughness = 1.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D"):
		mesh.material_override = wreck

	if smoke_when_destroyed:
		add_child(WRECK_SMOKE_SCENE.instantiate())
	if collapse_on_destroy and has_node("Model"):
		var tween := create_tween()
		tween.tween_property($Model, "scale", Vector3(1.08, 0.3, 1.08), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	destroyed.emit(attacker)
	Events.ground_target_destroyed.emit(self, attacker)
