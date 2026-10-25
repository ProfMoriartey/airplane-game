class_name Terrain
extends StaticBody3D
## Procedurally generated countryside: rolling hills, rivers and lakes, a patchwork
## of fields, forests, and a ring of high hills around the edge of the map.
##
## The same noise drives the visible mesh, the collision and get_height(), so
## anything placed with get_height() sits exactly on the ground.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const SNOW_COLOR := Color(0.92, 0.93, 0.95)
## Trees are split into square chunks this big, so distant chunks can be skipped.
const TREE_CHUNK_SIZE := 500.0
const TREE_DRAW_DISTANCE := 2600.0
## Tree cones end in a flat top this wide rather than a perfect point: a point
## makes triangles with no area, which some graphics drivers shade as garbage.
const CONE_TIP := 0.05
## Beyond this distance trees switch to simpler, shadowless shapes.
const TREE_DETAIL_DISTANCE := 1100.0

@export var size := 6000.0
@export var resolution := 300 ## Grid cells per side.
@export var height_scale := 180.0
@export var terrain_seed := 1914

@export_group("Water")
@export var has_water := true
## Height of lakes and rivers. Low ground below it is flooded.
@export var water_level := 6.0
@export var rivers := true
## How wide rivers are (in noise units; small numbers make narrow rivers).
@export var river_width := 0.045
## Rivers only flow through ground lower than this.
@export var river_max_height := 70.0

@export_group("Map edge")
## The map is ringed by hills starting this far from the centre...
@export var edge_start := 2450.0
## ...rising this high at the very edge.
@export var edge_height := 350.0

@export_group("Trees")
@export var tree_count := 14000
## How much of the land is forest: 0 none, 1 all of it.
@export_range(0.0, 1.0) var forest_cover := 0.45
## Fraction of trees that are pines rather than broadleaf trees.
@export_range(0.0, 1.0) var pine_share := 0.4

@export_group("Colours")
## Fields are coloured at random from this list.
@export var field_colors: Array[Color] = [
	Color(0.36, 0.48, 0.22),
	Color(0.42, 0.52, 0.25),
	Color(0.55, 0.53, 0.30),
	Color(0.30, 0.42, 0.20),
	Color(0.48, 0.42, 0.26),
]
@export var rock_color := Color(0.45, 0.42, 0.36)
@export var shore_color := Color(0.55, 0.5, 0.36)
@export var tree_color := Color(0.16, 0.27, 0.12)
@export var trunk_color := Color(0.3, 0.22, 0.15)
## Ground above this height is snow-covered. 0 means no snow.
@export var snow_height := 0.0

var _height_noise := FastNoiseLite.new()
var _field_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _river_noise := FastNoiseLite.new()
var _noise_ready := false
var _map_textures := {}


func _ready() -> void:
	var mesh := _build_mesh()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	add_child(collision)

	if has_water:
		_build_water()
	_scatter_trees()


## The true ground height in metres at a world position.
func get_height(x: float, z: float) -> float:
	# Other nodes may ask for heights before our _ready() has run.
	if not _noise_ready:
		_setup_noise()
	var n := _height_noise.get_noise_2d(x, z) * 0.5 + 0.5
	# Raising to a power flattens the valleys and keeps the hills rounded.
	var height := pow(n, 1.8) * height_scale

	if has_water and rivers:
		# Rivers follow the lines where a second noise crosses zero.
		var river := absf(_river_noise.get_noise_2d(x, z)) / river_width
		var carve := 1.0 - smoothstep(0.0, 1.0, river)
		var lowland := 1.0 - smoothstep(river_max_height * 0.6, river_max_height, height)
		height = lerpf(height, water_level - 4.0, carve * lowland)

	var distance := Vector2(x, z).length()
	var edge := smoothstep(edge_start, size * 0.5 - 50.0, distance)
	return height + edge * edge * edge_height * (0.6 + 0.4 * n)


## The height of the ground as drawn: the terrain mesh is made of flat triangles,
## so between grid points this differs slightly from get_height(). Use it to set
## things exactly on the visible surface.
func get_mesh_height(x: float, z: float) -> float:
	var cell := size / resolution
	var half := size * 0.5
	var gx := (x + half) / cell
	var gz := (z + half) / cell
	var i := floorf(gx)
	var j := floorf(gz)
	var fx := gx - i
	var fz := gz - j
	var x0 := i * cell - half
	var z0 := j * cell - half
	var h_a := get_height(x0, z0)
	var h_b := get_height(x0 + cell, z0)
	var h_c := get_height(x0, z0 + cell)
	var h_d := get_height(x0 + cell, z0 + cell)
	# Same diagonal split as the mesh: triangles (a, b, c) and (b, d, c).
	if fx + fz <= 1.0:
		return h_a + (h_b - h_a) * fx + (h_c - h_a) * fz
	return h_d + (h_c - h_d) * (1.0 - fx) + (h_b - h_d) * (1.0 - fz)


## Where something resting on the ground sits: the visible ground, or the water
## surface over rivers and lakes.
func get_surface_height(x: float, z: float) -> float:
	var ground := get_mesh_height(x, z)
	return maxf(ground, water_level) if has_water else ground


func is_underwater(x: float, z: float) -> bool:
	return has_water and get_height(x, z) < water_level


## A cached map texture of the ground (see create_map_image).
func get_map_texture(pixels: int, extent: float) -> ImageTexture:
	var key := Vector2(pixels, extent)
	if not _map_textures.has(key):
		_map_textures[key] = ImageTexture.create_from_image(create_map_image(pixels, extent))
	return _map_textures[key]


## A top-down picture of the ground, covering `extent` metres in every direction
## from the centre. Used for the briefing map.
func create_map_image(pixels: int, extent: float) -> Image:
	var image := Image.create(pixels, pixels, false, Image.FORMAT_RGB8)
	var step := extent * 2.0 / pixels
	var light := Vector3(-1.0, 1.5, -1.0).normalized()
	for py in pixels:
		for px in pixels:
			var x := (px + 0.5) * step - extent
			var z := (py + 0.5) * step - extent
			var height := get_height(x, z)
			if has_water and height < water_level:
				image.set_pixel(px, py, Color(0.2, 0.32, 0.38))
				continue
			var normal := _normal_at(x, z, step)
			var shade := lerpf(0.65, 1.15, clampf(normal.dot(light), 0.0, 1.0))
			var color := _ground_color(x, z, height, normal) * shade
			if _is_forest(x, z):
				color = color.lerp(tree_color, 0.6)
			image.set_pixel(px, py, color)
	return image


func _setup_noise() -> void:
	_noise_ready = true
	_height_noise.seed = terrain_seed
	_height_noise.frequency = 0.0005
	_height_noise.fractal_octaves = 5

	_field_noise.seed = terrain_seed + 1
	_field_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_field_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_field_noise.frequency = 0.004

	_forest_noise.seed = terrain_seed + 2
	_forest_noise.frequency = 0.002

	_river_noise.seed = terrain_seed + 3
	_river_noise.frequency = 0.0004
	_river_noise.fractal_octaves = 2


func _normal_at(x: float, z: float, step: float) -> Vector3:
	return Vector3(
		get_height(x - step, z) - get_height(x + step, z),
		2.0 * step,
		get_height(x, z - step) - get_height(x, z + step),
	).normalized()


func _build_mesh() -> ArrayMesh:
	var cell := size / resolution
	var half := size * 0.5
	var row := resolution + 1

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for j in row:
		for i in row:
			var x := i * cell - half
			var z := j * cell - half
			var h := get_height(x, z)
			var normal := _normal_at(x, z, cell)
			vertices.append(Vector3(x, h, z))
			normals.append(normal)
			colors.append(_ground_color(x, z, h, normal))

	# Two triangles per cell, wound clockwise when seen from above.
	for j in resolution:
		for i in resolution:
			var a := j * row + i
			var b := a + 1
			var c := a + row
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("detail_noise", _noise_texture(terrain_seed + 10, 0.05))
	material.set_shader_parameter("macro_noise", _noise_texture(terrain_seed + 11, 0.02))

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var ripples := _noise_texture(terrain_seed + 12, 0.04)
	ripples.as_normal_map = true
	ripples.bump_strength = 4.0
	material.set_shader_parameter("ripples", ripples)
	plane.material = material

	var water := MeshInstance3D.new()
	water.mesh = plane
	water.position.y = water_level
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _noise_texture(noise_seed: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	return texture


func _ground_color(x: float, z: float, height: float, normal: Vector3) -> Color:
	var field := _field_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var color := field_colors[int(field * field_colors.size()) % field_colors.size()]
	# Steep slopes show bare rock and earth instead of fields.
	var steepness := clampf(inverse_lerp(0.9, 0.75, normal.y), 0.0, 1.0)
	color = color.lerp(rock_color, steepness)
	if has_water:
		# Sandy, muddy banks along the water's edge.
		color = color.lerp(shore_color, 1.0 - smoothstep(water_level + 0.5, water_level + 4.0, height))
	if snow_height > 0.0:
		var snow := clampf((height - snow_height) / 40.0, 0.0, 1.0) * (1.0 - steepness * 0.6)
		color = color.lerp(SNOW_COLOR, snow)
	return color


## Trees grow in clumps where the forest noise is high.
func _is_forest(x: float, z: float) -> bool:
	return _forest_noise.get_noise_2d(x, z) > lerpf(0.7, -0.3, forest_cover)


func _scatter_trees() -> void:
	var meshes: Array[Mesh] = [_make_pine(), _make_broadleaf()]
	var far_meshes: Array[Mesh] = [_make_pine_far(), _make_broadleaf_far()]
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var half := size * 0.5
	var chunks_per_side := ceili(size / TREE_CHUNK_SIZE)
	# chunks[kind][chunk index] -> transforms
	var chunks: Array = [[], []]
	for kind in 2:
		for index in chunks_per_side * chunks_per_side:
			chunks[kind].append([])

	var wanted := roundi(tree_count * Settings.quality_value("trees"))
	var placed := 0
	var attempts := wanted * 8
	while placed < wanted and attempts > 0:
		attempts -= 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if not _is_forest(x, z):
			continue
		var ground := get_mesh_height(x, z)
		if has_water and ground < water_level + 1.5:
			continue
		if snow_height > 0.0 and ground > snow_height + 60.0:
			continue
		var kind := 0 if rng.randf() < pine_share else 1
		var tree_scale := rng.randf_range(0.7, 1.35)
		var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale)
		var chunk := floori((x + half) / TREE_CHUNK_SIZE) + floori((z + half) / TREE_CHUNK_SIZE) * chunks_per_side
		chunks[kind][chunk].append(Transform3D(tree_basis, Vector3(x, ground - 0.3, z)))
		placed += 1

	for kind in 2:
		for transforms: Array in chunks[kind]:
			if transforms.is_empty():
				continue
			var near := _tree_instance(meshes[kind], transforms)
			near.visibility_range_end = TREE_DETAIL_DISTANCE
			near.visibility_range_end_margin = 150.0
			var far := _tree_instance(far_meshes[kind], transforms)
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			far.visibility_range_begin = TREE_DETAIL_DISTANCE
			far.visibility_range_begin_margin = 150.0
			far.visibility_range_end = Settings.quality_value("tree_distance")
			far.visibility_range_end_margin = 300.0


func _tree_instance(mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = multimesh
	trees.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(trees)
	return trees


## A conifer: a trunk with two stacked cones. Origin at the foot of the trunk.
func _make_pine() -> Mesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.4
	trunk.height = 4.0
	trunk.radial_segments = 5
	var lower := CylinderMesh.new()
	lower.top_radius = CONE_TIP
	lower.bottom_radius = 3.2
	lower.height = 7.0
	lower.radial_segments = 7
	var upper := CylinderMesh.new()
	upper.top_radius = CONE_TIP
	upper.bottom_radius = 2.3
	upper.height = 5.5
	upper.radial_segments = 7
	return _combine([
		[trunk, Transform3D(Basis.IDENTITY, Vector3(0, 2.0, 0)), trunk_color],
		[lower, Transform3D(Basis.IDENTITY, Vector3(0, 6.5, 0)), tree_color],
		[upper, Transform3D(Basis.IDENTITY, Vector3(0, 10.0, 0)), tree_color.darkened(0.1)],
	])


## A leafy tree: a trunk with a squashed sphere on top.
func _make_broadleaf() -> Mesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.45
	trunk.height = 5.0
	trunk.radial_segments = 5
	var crown := SphereMesh.new()
	crown.radius = 3.6
	crown.height = 6.0
	crown.radial_segments = 8
	crown.rings = 4
	return _combine([
		[trunk, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 0)), trunk_color],
		[crown, Transform3D(Basis.IDENTITY, Vector3(0, 7.0, 0)), tree_color.lightened(0.15)],
	])


## Distant pines: one cone, no trunk.
func _make_pine_far() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = CONE_TIP
	cone.bottom_radius = 3.0
	cone.height = 12.0
	cone.radial_segments = 4
	cone.rings = 1
	return _combine([[cone, Transform3D(Basis.IDENTITY, Vector3(0, 7.0, 0)), tree_color]])


## Distant leafy trees: a rough ball.
func _make_broadleaf_far() -> Mesh:
	var crown := SphereMesh.new()
	crown.radius = 3.6
	crown.height = 7.0
	crown.radial_segments = 5
	crown.rings = 2
	return _combine([[crown, Transform3D(Basis.IDENTITY, Vector3(0, 6.5, 0)), tree_color.lightened(0.15)]])


## Merges primitive meshes into one mesh with a surface (and colour) per part.
func _combine(parts: Array) -> Mesh:
	var mesh := ArrayMesh.new()
	for part: Array in parts:
		var tool := SurfaceTool.new()
		tool.append_from(part[0], 0, part[1])
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		material.roughness = 1.0
		tool.set_material(material)
		tool.commit(mesh)
	return mesh
