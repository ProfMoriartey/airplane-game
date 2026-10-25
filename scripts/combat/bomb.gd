class_name Bomb
extends Node3D
## A falling bomb. Explodes on whatever it hits, damaging everything nearby.

const GRAVITY := 9.8
const BLAST_RADIUS := 25.0
const BLAST_DAMAGE := 200.0
const HIT_MASK := 1 | 16 ## World and ground targets.
const MAX_LIFETIME := 30.0
const EXPLOSION_SCENE := preload("res://scenes/effects/explosion.tscn")

var velocity := Vector3.ZERO
var dropped_by: Aircraft

var _ray := PhysicsRayQueryParameters3D.new()
var _terrain: Terrain
var _age := 0.0


## Where a bomb released at `from` with `initial_velocity` will hit the ground,
## or null if it won't land within a reasonable time. Used for the bomb sight.
static func predict_impact(from: Vector3, initial_velocity: Vector3, terrain: Terrain) -> Variant:
	var point := from
	var bomb_velocity := initial_velocity
	var step := 0.05
	var time := 0.0
	while time < 20.0:
		bomb_velocity.y -= GRAVITY * step
		point += bomb_velocity * step
		time += step
		var ground := terrain.get_height(point.x, point.z)
		if point.y <= ground:
			return Vector3(point.x, ground, point.z)
	return null


func _ready() -> void:
	_ray.collision_mask = HIT_MASK
	_terrain = get_tree().get_first_node_in_group("terrain") as Terrain


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	var next_position := global_position + velocity * delta

	_ray.from = global_position
	_ray.to = next_position
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		_detonate(hit.position)
		return
	if _terrain and next_position.y < _terrain.get_height(next_position.x, next_position.z):
		_detonate(next_position)
		return
	if _age > MAX_LIFETIME:
		queue_free()
		return

	global_position = next_position
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)


func _detonate(at: Vector3) -> void:
	var attacker := dropped_by if is_instance_valid(dropped_by) else null
	var team := attacker.team if attacker else Damage.NO_TEAM
	Damage.explode(get_tree(), at, BLAST_RADIUS, BLAST_DAMAGE, attacker, team)

	var explosion := EXPLOSION_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = at
	queue_free()
