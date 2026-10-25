class_name Terrain
extends StaticBody3D
## Procedurally generated rolling countryside with a patchwork of fields and forests.
##
## The same noise drives the visible mesh, the collision and get_height(), so
## anything placed with get_height() sits exactly on the ground.

@export var size := 6000.0
@export var resolution := 300 ## Grid cells per side.
@export var height_scale := 180.0
@export var terrain_seed := 1914
@export var tree_count := 9000
## How much of the land is forest: 0 none, 1 all of it.
@export_range(0.0, 1.0) var forest_cover := 0.45

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
@export var tree_color := Color(0.16, 0.27, 0.12)
## Ground above this height is snow-covered. 0 means no snow.
@export var snow_height := 0.0

var _height_noise := FastNoiseLite.new()
var _field_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _noise_ready := false


func _ready() -> void:
	var mesh := _build_mesh()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	add_child(collision)

	_scatter_trees()


## Ground height in metres at a world position.
func get_height(x: float, z: float) -> float:
	# Other nodes may ask for heights before our _ready() has run.
	if not _noise_ready:
		_setup_noise()
	var n := _height_noise.get_noise_2d(x, z) * 0.5 + 0.5
	# Raising to a power flattens the valleys and keeps the hills rounded.
	return pow(n, 1.8) * height_scale


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
			var normal := Vector3(
				get_height(x - step, z) - get_height(x + step, z),
				2.0 * step,
				get_height(x, z - step) - get_height(x, z + step),
			).normalized()
			var shade := lerpf(0.65, 1.15, clampf(normal.dot(light), 0.0, 1.0))
			var color := _ground_color(x, z, get_height(x, z), normal) * shade
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
			# Normal from the slope between neighbouring points.
			var normal := Vector3(
				get_height(x - cell, z) - get_height(x + cell, z),
				2.0 * cell,
				get_height(x, z - cell) - get_height(x, z + cell),
			).normalized()
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

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _ground_color(x: float, z: float, height: float, normal: Vector3) -> Color:
	var field := _field_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var color := field_colors[int(field * field_colors.size()) % field_colors.size()]
	# Steep slopes show bare rock and earth instead of fields.
	var steepness := clampf(inverse_lerp(0.9, 0.75, normal.y), 0.0, 1.0)
	color = color.lerp(rock_color, steepness)
	if snow_height > 0.0:
		var snow := clampf((height - snow_height) / 40.0, 0.0, 1.0) * (1.0 - steepness * 0.6)
		color = color.lerp(Color(0.92, 0.93, 0.95), snow)
	return color


## Trees grow in clumps where the forest noise is high.
func _is_forest(x: float, z: float) -> bool:
	return _forest_noise.get_noise_2d(x, z) > lerpf(0.7, -0.3, forest_cover)


func _scatter_trees() -> void:
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.0
	tree_mesh.bottom_radius = 4.0
	tree_mesh.height = 14.0
	tree_mesh.radial_segments = 6
	tree_mesh.rings = 1
	var tree_material := StandardMaterial3D.new()
	tree_material.albedo_color = tree_color
	tree_material.roughness = 1.0
	tree_mesh.material = tree_material

	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var transforms: Array[Transform3D] = []
	var half := size * 0.5
	var attempts := tree_count * 8

	while transforms.size() < tree_count and attempts > 0:
		attempts -= 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if not _is_forest(x, z):
			continue
		var tree_scale := rng.randf_range(0.7, 1.4)
		var origin := Vector3(x, get_height(x, z) + tree_mesh.height * 0.5 * tree_scale, z)
		var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale)
		transforms.append(Transform3D(tree_basis, origin))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tree_mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])

	var trees := MultiMeshInstance3D.new()
	trees.multimesh = multimesh
	add_child(trees)
