extends Node3D
## Simulates and draws every bullet in flight.
##
## Bullets are plain data rather than nodes: each physics tick they move forward
## and a ray between their old and new position checks for hits. All tracers are
## drawn with a single MultiMesh, so hundreds of bullets stay cheap.

signal hit_landed(shooter: Aircraft, target: Node3D, position: Vector3)

const MAX_BULLETS := 1024
## Enemy bullets passing this close to the camera make a whizz.
const WHIZZ_DISTANCE := 12.0
const LIFETIME := 1.3
const BULLET_DROP := 4.0 ## A little gravity, in m/s².
const TRACER_LENGTH := 6.0
## Roughly how far a plane's body reaches from its centre, for aim assist.
const ASSIST_BODY_RADIUS := 2.5
const HIT_MASK := 1 | 2 | 4 | 16 ## World, player, enemy and ground target layers.
const SPARKS_SCENE := preload("res://scenes/effects/hit_sparks.tscn")
const DUST_SCENE := preload("res://scenes/effects/ground_dust.tscn")
const SPLASH_SCENE := preload("res://scenes/effects/water_splash.tscn")


class Bullet:
	var position: Vector3
	var velocity: Vector3
	var life: float
	var damage: float
	var shooter: Aircraft
	var whizzed := false


var _bullets: Array[Bullet] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _tracers := MultiMesh.new()
var _terrain: Terrain


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
	_terrain = null
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
	_check_whizz(bullet, next_position)
	_ray.from = bullet.position
	_ray.to = next_position
	_ray.exclude = [bullet.shooter.get_rid()] if is_instance_valid(bullet.shooter) else []
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		var near_miss := _assisted_hit(bullet, next_position)
		if near_miss:
			_hit_aircraft(bullet, near_miss, near_miss.global_position)
			return false
		bullet.position = next_position
		return true

	var target := hit.collider as Node3D
	if _hits_water(bullet.position, hit.position):
		_spawn_effect(SPLASH_SCENE, Vector3(hit.position.x, _terrain.water_level, hit.position.z))
		return false
	if target.has_method("take_damage") and target.is_alive():
		_hit_aircraft(bullet, target, hit.position)
	else:
		_spawn_effect(DUST_SCENE, hit.position)
	return false


func _hit_aircraft(bullet: Bullet, target: Node3D, at: Vector3) -> void:
	var shooter := bullet.shooter if is_instance_valid(bullet.shooter) else null
	# Nobody hurts their own side.
	if shooter == null or target.team != shooter.team:
		target.take_damage(bullet.damage, at, shooter, Damage.Kind.BULLET)
		hit_landed.emit(shooter, target, at)
		Sound.play_at("bullet_hit", at, 0.0, 6.0)
	_spawn_effect(SPARKS_SCENE, at)


## Aim assist: a player's bullet that passes just outside an enemy plane still
## counts. Returns the plane it hit, or null.
func _assisted_hit(bullet: Bullet, next_position: Vector3) -> Node3D:
	var assist: float = Settings.AIM_ASSIST_RADIUS[Settings.aim_assist]
	if assist <= 0.0 or not is_instance_valid(bullet.shooter) or not bullet.shooter.player_controlled:
		return null
	for node in get_tree().get_nodes_in_group("aircraft"):
		var plane := node as Aircraft
		if plane.team == bullet.shooter.team or not plane.is_alive():
			continue
		var closest := Geometry3D.get_closest_point_to_segment(plane.global_position, bullet.position, next_position)
		if closest.distance_to(plane.global_position) < ASSIST_BODY_RADIUS + assist:
			return plane
	return null


## The crack of a bullet passing close by - only for bullets from the player's enemies.
func _check_whizz(bullet: Bullet, next_position: Vector3) -> void:
	if bullet.whizzed or not is_instance_valid(bullet.shooter):
		return
	var player := get_tree().get_first_node_in_group("player") as Aircraft
	if player == null or bullet.shooter.team == player.team:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var closest := Geometry3D.get_closest_point_to_segment(camera.global_position, bullet.position, next_position)
	if closest.distance_to(camera.global_position) < WHIZZ_DISTANCE:
		bullet.whizzed = true
		Sound.play_at("whizz", closest, -4.0, 4.0)


## Whether a bullet travelling between these points goes into a river or lake first.
func _hits_water(from: Vector3, hit_position: Vector3) -> bool:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	if _terrain == null or not _terrain.has_water:
		return false
	return from.y > _terrain.water_level and hit_position.y < _terrain.water_level


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
