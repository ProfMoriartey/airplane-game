class_name Scenery
extends Node3D
## Decorates the countryside with villages (houses, barns, churches, windmills)
## joined by dirt roads. Purely scenery: it can be crashed into, not destroyed.
##
## Villages keep clear of water, steep ground, the player's start and any
## mission targets, so they never get in the way of a mission.

const WINDMILL_SCENE := preload("res://scenes/world/windmill.tscn")
## How far villages stay from the map centre, so they're inside the play area.
const MAX_RADIUS := 2150.0
const MIN_VILLAGE_SPACING := 550.0
## Keep this far from mission targets and the player's start.
const CLEARANCE := 220.0
const MAX_SLOPE := 0.12

@export var village_count := 10
@export var scenery_seed := 7
@export_range(0.0, 1.0) var church_chance := 0.5
@export_range(0.0, 1.0) var windmill_chance := 0.4
@export var wall_colors: Array[Color] = [
	Color(0.85, 0.82, 0.74), Color(0.78, 0.72, 0.62), Color(0.7, 0.66, 0.6), Color(0.62, 0.5, 0.4),
]
@export var roof_colors: Array[Color] = [
	Color(0.55, 0.25, 0.18), Color(0.45, 0.22, 0.16), Color(0.3, 0.3, 0.33), Color(0.38, 0.28, 0.2),
]

## Where the villages ended up, once built.
var village_sites: Array[Vector3] = []

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
## Building parts: { mesh: Mesh, transforms: [], colors: [] } per part kind.
var _parts := {}
var _collision: StaticBody3D


func _ready() -> void:
	# Wait until every node is ready, so mission targets are in their groups.
	_build.call_deferred()


func _build() -> void:
	_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	if _terrain == null:
		return
	_rng.seed = scenery_seed
	_setup_parts()
	_collision = StaticBody3D.new()
	_collision.collision_mask = 0
	add_child(_collision)

	village_sites = _choose_village_sites()
	for center in village_sites:
		_build_village(center)
	_build_roads(village_sites)
	_commit_parts()


func _choose_village_sites() -> Array[Vector3]:
	var avoid: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("ground_targets"):
		avoid.append((node as Node3D).global_position)
	for node in get_tree().get_nodes_in_group("player"):
		avoid.append((node as Node3D).global_position)

	var sites: Array[Vector3] = []
	var attempts := village_count * 60
	while sites.size() < village_count and attempts > 0:
		attempts -= 1
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf()) * MAX_RADIUS
		var point := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if not _is_buildable(point, 70.0):
			continue
		if _too_close(point, sites, MIN_VILLAGE_SPACING) or _too_close(point, avoid, CLEARANCE):
			continue
		point.y = _terrain.get_mesh_height(point.x, point.z)
		sites.append(point)
	return sites


func _too_close(point: Vector3, others: Array[Vector3], distance: float) -> bool:
	for other in others:
		if Vector2(point.x - other.x, point.z - other.z).length() < distance:
			return true
	return false


## Dry, fairly flat ground around a point.
func _is_buildable(point: Vector3, radius: float) -> bool:
	var center := _terrain.get_height(point.x, point.z)
	if _terrain.has_water and center < _terrain.water_level + 3.0:
		return false
	if _terrain.snow_height > 0.0 and center > _terrain.snow_height:
		return false
	for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if absf(_terrain.get_height(point.x + offset.x, point.z + offset.y) - center) > radius * MAX_SLOPE:
			return false
	return true


func _build_village(center: Vector3) -> void:
	var placed: Array[Vector3] = []
	if _rng.randf() < church_chance:
		_add_church(center, _rng.randf() * TAU)
		placed.append(center)

	var count := _rng.randi_range(5, 10)
	var attempts := count * 10
	while placed.size() < count and attempts > 0:
		attempts -= 1
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(25.0, 90.0)
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if _too_close(spot, placed, 20.0) or not _is_buildable(spot, 8.0):
			continue
		# Buildings face roughly towards the village centre.
		var facing := angle + PI * 0.5 + _rng.randf_range(-0.2, 0.2)
		if _rng.randf() < 0.25:
			_add_building(spot, facing, Vector3(10, 6, 14), 3.5, false)
		else:
			_add_building(spot, facing, Vector3(_rng.randf_range(6, 8), _rng.randf_range(4, 5.5), _rng.randf_range(7, 10)), 3.0, true)
		placed.append(spot)

	if _rng.randf() < windmill_chance:
		var angle := _rng.randf() * TAU
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * 130.0
		if _is_buildable(spot, 10.0):
			var windmill := WINDMILL_SCENE.instantiate() as Node3D
			add_child(windmill)
			windmill.global_position = Vector3(spot.x, _terrain.get_mesh_height(spot.x, spot.z) - 0.5, spot.z)
			windmill.rotation.y = _rng.randf() * TAU


func _add_building(spot: Vector3, facing: float, walls: Vector3, roof_height: float, painted: bool) -> void:
	var ground := _lowest_corner(spot, walls)
	var turn := Basis(Vector3.UP, facing)
	# Walls reach a little below ground so they never float on a slope.
	var sunk := 2.0
	var wall_center := Vector3(spot.x, ground + (walls.y - sunk) * 0.5, spot.z)
	var wall_color: Color = wall_colors[_rng.randi() % wall_colors.size()] if painted else Color(0.42, 0.32, 0.24)
	_add_part("box", Transform3D(turn.scaled(Vector3(walls.x, walls.y + sunk, walls.z)), wall_center), wall_color)
	var roof_base := ground + walls.y - sunk * 0.5 + roof_height * 0.5
	var roof_color: Color = roof_colors[_rng.randi() % roof_colors.size()]
	_add_part("roof", Transform3D(turn.scaled(Vector3(walls.x + 0.8, roof_height, walls.z + 0.8)), Vector3(spot.x, roof_base, spot.z)), roof_color)
	_add_collision(Transform3D(turn, wall_center + Vector3.UP * roof_height * 0.5), Vector3(walls.x, walls.y + roof_height, walls.z))


func _add_church(spot: Vector3, facing: float) -> void:
	var turn := Basis(Vector3.UP, facing)
	var nave := Vector3(9, 8, 18)
	_add_building(spot, facing, nave, 4.5, true)
	var ground := _lowest_corner(spot, nave)
	var tower_spot := spot + turn * Vector3(0, 0, -nave.z * 0.5 - 2.5)
	var stone := Color(0.72, 0.7, 0.66)
	_add_part("box", Transform3D(turn.scaled(Vector3(5, 20, 5)), Vector3(tower_spot.x, ground + 8.0, tower_spot.z)), stone)
	_add_part("spire", Transform3D(turn.scaled(Vector3(1, 1, 1)), Vector3(tower_spot.x, ground + 22.0, tower_spot.z)), Color(0.3, 0.32, 0.33))
	_add_collision(Transform3D(turn, Vector3(tower_spot.x, ground + 12.0, tower_spot.z)), Vector3(5, 26, 5))


func _lowest_corner(spot: Vector3, walls: Vector3) -> float:
	var reach := maxf(walls.x, walls.z) * 0.5
	var lowest := INF
	for offset: Vector2 in [Vector2(reach, reach), Vector2(-reach, reach), Vector2(reach, -reach), Vector2(-reach, -reach)]:
		lowest = minf(lowest, _terrain.get_mesh_height(spot.x + offset.x, spot.z + offset.y))
	return lowest


func _build_roads(villages: Array[Vector3]) -> void:
	if villages.size() < 2:
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Join each village to its nearest already-connected neighbour.
	var connected: Array[Vector3] = [villages[0]]
	for village in villages.slice(1):
		var nearest := connected[0]
		for other in connected:
			if village.distance_to(other) < village.distance_to(nearest):
				nearest = other
		RoadMesh.add_road(tool, _terrain, _wandering_line(nearest, village), 6.0)
		connected.append(village)
	tool.set_material(RoadMesh.make_material())
	var roads := MeshInstance3D.new()
	roads.mesh = tool.commit()
	roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roads)


## A line between two points with a gentle sideways wander, so roads aren't ruler-straight.
func _wandering_line(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var side := Vector3(-(to.z - from.z), 0.0, to.x - from.x).normalized()
	var wander := _rng.randf_range(-0.12, 0.12) * length
	var steps := maxi(ceili(length / 40.0), 2)
	for step in steps + 1:
		var t := float(step) / steps
		points.append(from.lerp(to, t) + side * sin(t * PI) * wander)
	return points


## --- Batched building parts ---

func _setup_parts() -> void:
	var box := BoxMesh.new()
	var roof := PrismMesh.new()
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 3.0
	spire.height = 8.0
	spire.radial_segments = 4
	spire.rings = 1
	for kind: String in ["box", "roof", "spire"]:
		var mesh: PrimitiveMesh = {box = box, roof = roof, spire = spire}[kind]
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.95
		mesh.material = material
		_parts[kind] = {mesh = mesh, transforms = [], colors = []}


func _add_part(kind: String, part_transform: Transform3D, color: Color) -> void:
	_parts[kind].transforms.append(part_transform)
	_parts[kind].colors.append(color)


func _add_collision(shape_transform: Transform3D, box_size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = shape_transform
	_collision.add_child(collision)


func _commit_parts() -> void:
	for kind: String in _parts:
		var part: Dictionary = _parts[kind]
		if part.transforms.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = part.mesh
		multimesh.instance_count = part.transforms.size()
		for index in part.transforms.size():
			multimesh.set_instance_transform(index, part.transforms[index])
			multimesh.set_instance_color(index, part.colors[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		add_child(instance)
