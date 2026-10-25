extends Node3D
## Simulates and draws every bullet in flight.
##
## Bullets are plain data rather than nodes: each physics tick they move forward
## and a ray between their old and new position checks for hits. All tracers are
## drawn with a single MultiMesh, so hundreds of bullets stay cheap.

signal hit_landed(shooter: Aircraft, target: Aircraft, position: Vector3)

const MAX_BULLETS := 1024
const LIFETIME := 1.3
const BULLET_DROP := 4.0 ## A little gravity, in m/s².
const TRACER_LENGTH := 6.0
const HIT_MASK := 1 | 2 | 4 ## World, player and enemy layers.
const SPARKS_SCENE := preload("res://scenes/effects/hit_sparks.tscn")
const DUST_SCENE := preload("res://scenes/effects/ground_dust.tscn")


class Bullet:
	var position: Vector3
	var velocity: Vector3
	var life: float
	var damage: float
	var shooter: Aircraft


var _bullets: Array[Bullet] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _tracers := MultiMesh.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ray.collision_mask = HIT_MASK

	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.12, 0.12, 1.0)
	var tracer_material := StandardMaterial3D.new()
	tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_material.albedo_color = Color(1.0, 0.85, 0.4)
	tracer_mesh.material = tracer_material

	_tracers.transform_format = MultiMesh.TRANSFORM_3D
	_tracers.mesh = tracer_mesh
	_tracers.instance_count = MAX_BULLETS
	_tracers.visible_instance_count = 0
	var tracer_instance := MultiMeshInstance3D.new()
	tracer_instance.multimesh = _tracers
	tracer_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer_instance)


func spawn(from: Vector3, initial_velocity: Vector3, damage: float, shooter: Aircraft) -> void:
	if _bullets.size() >= MAX_BULLETS:
		return
	var bullet := Bullet.new()
	bullet.position = from
	bullet.velocity = initial_velocity
	bullet.life = LIFETIME
	bullet.damage = damage
	bullet.shooter = shooter
	_bullets.append(bullet)


## Removes every bullet, e.g. when a level restarts.
func clear() -> void:
	_bullets.clear()
	_tracers.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var index := 0
	while index < _bullets.size():
		var bullet := _bullets[index]
		if _step(bullet, space, delta):
			index += 1
		else:
			# Swap-remove: order doesn't matter and it avoids shifting the array.
			_bullets[index] = _bullets[-1]
			_bullets.pop_back()
	_draw_tracers()


## Moves one bullet. Returns false when it should be removed.
func _step(bullet: Bullet, space: PhysicsDirectSpaceState3D, delta: float) -> bool:
	bullet.life -= delta
	if bullet.life <= 0.0:
		return false

	bullet.velocity.y -= BULLET_DROP * delta
	var next_position := bullet.position + bullet.velocity * delta
	_ray.from = bullet.position
	_ray.to = next_position
	_ray.exclude = [bullet.shooter.get_rid()] if is_instance_valid(bullet.shooter) else []
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		bullet.position = next_position
		return true

	var target := hit.collider as Aircraft
	if target:
		var shooter := bullet.shooter if is_instance_valid(bullet.shooter) else null
		# Planes on the same side don't hurt each other.
		if shooter == null or target.is_hostile_to(shooter):
			target.take_damage(bullet.damage, hit.position, shooter)
			hit_landed.emit(shooter, target, hit.position)
		_spawn_effect(SPARKS_SCENE, hit.position)
	else:
		_spawn_effect(DUST_SCENE, hit.position)
	return false


func _spawn_effect(scene: PackedScene, at: Vector3) -> void:
	var effect := scene.instantiate() as Node3D
	get_tree().current_scene.add_child(effect)
	effect.global_position = at


func _draw_tracers() -> void:
	_tracers.visible_instance_count = _bullets.size()
	for index in _bullets.size():
		var bullet := _bullets[index]
		var direction := bullet.velocity.normalized()
		var up := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
		var tracer_basis := Basis.looking_at(direction, up).scaled(Vector3(1.0, 1.0, TRACER_LENGTH))
		# Draw the tracer trailing behind the bullet's position.
		var center := bullet.position - direction * TRACER_LENGTH * 0.5
		_tracers.set_instance_transform(index, Transform3D(tracer_basis, center))
