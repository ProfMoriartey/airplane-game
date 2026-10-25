class_name MeshKit
extends RefCounted
## A small toolkit for building low-poly models in code.
##
## Add shapes with a named material; commit() merges everything into one mesh
## with one surface per material, so a whole model draws in a few calls.
## Triangles are automatically wound to face along their normals.

var _materials := {}
var _tools := {}


func add_material(material_name: String, color: Color, roughness := 0.85, metallic := 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[material_name] = material


func set_material(material_name: String, material: Material) -> void:
	_materials[material_name] = material


func get_material(material_name: String) -> Material:
	return _materials[material_name]


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material_name: String in _tools:
		var tool: SurfaceTool = _tools[material_name]
		tool.set_material(_materials[material_name])
		tool.commit(mesh)
	return mesh


## --- Shapes ---

## A box centred on the transform's origin.
func box(material_name: String, at: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3.DOWN, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3.BACK, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
	]
	for face: Array in faces:
		var normal: Vector3 = at.basis * face[0]
		var corners: Array = face[1].map(func(corner: Vector3) -> Vector3: return at * corner)
		_quad(material_name, corners[0], corners[1], corners[2], corners[3], normal)


## A cylinder (or cone, with a 0 radius) along the transform's Y axis, centred on its origin.
func cylinder(material_name: String, at: Transform3D, top_radius: float, bottom_radius: float, height: float, segments := 8, caps := true) -> void:
	var rings: Array[PackedVector3Array] = []
	for y: float in [-height * 0.5, height * 0.5]:
		var radius := bottom_radius if y < 0.0 else top_radius
		var ring := PackedVector3Array()
		for k in segments:
			var angle := TAU * k / segments
			ring.append(at * Vector3(cos(angle) * radius, y, sin(angle) * radius))
		rings.append(ring)
	strip(material_name, rings, true)
	if caps:
		cap(material_name, rings[0], at * Vector3(0, -height * 0.5, 0), at.basis * Vector3.DOWN)
		cap(material_name, rings[1], at * Vector3(0, height * 0.5, 0), at.basis * Vector3.UP)


func sphere(material_name: String, at: Transform3D, radius: float, segments := 8, rings := 5) -> void:
	var loops: Array[PackedVector3Array] = []
	for r in range(1, rings):
		var phi := PI * r / rings
		var ring := PackedVector3Array()
		for k in segments:
			var theta := TAU * k / segments
			ring.append(at * (Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius))
		loops.append(ring)
	strip(material_name, loops, true)
	cap(material_name, loops[0], at * Vector3(0, radius, 0), at.basis * Vector3.UP)
	cap(material_name, loops[-1], at * Vector3(0, -radius, 0), at.basis * Vector3.DOWN)


## A flat disc facing the transform's +Y axis (for markings).
func disc(material_name: String, at: Transform3D, radius: float, segments := 16) -> void:
	var ring := PackedVector3Array()
	for k in segments:
		var angle := TAU * k / segments
		ring.append(at * Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	cap(material_name, ring, at.origin, at.basis * Vector3.UP)


## A 2D outline (x, y) pushed out along Z by `depth`, centred on the transform's origin.
func extrude(material_name: String, at: Transform3D, outline: PackedVector2Array, depth: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for z: float in [-depth * 0.5, depth * 0.5]:
		var ring := PackedVector3Array()
		for point in outline:
			ring.append(at * Vector3(point.x, point.y, z))
		rings.append(ring)
	# Flat-shaded sides, one quad per outline edge.
	for k in outline.size():
		var next := (k + 1) % outline.size()
		var edge := outline[next] - outline[k]
		var normal := at.basis * Vector3(edge.y, -edge.x, 0.0).normalized()
		var center := (outline[k] + outline[next]) * 0.5
		if Vector2(normal.x, normal.y).dot(center - _centroid(outline)) < 0.0:
			normal = -normal
		_quad(material_name, rings[0][k], rings[0][next], rings[1][next], rings[1][k], normal)
	cap(material_name, rings[0], at * Vector3(_centroid(outline).x, _centroid(outline).y, -depth * 0.5), at.basis * Vector3.FORWARD)
	cap(material_name, rings[1], at * Vector3(_centroid(outline).x, _centroid(outline).y, depth * 0.5), at.basis * Vector3.BACK)


## A smooth tube through a list of rings (all with the same number of points).
func strip(material_name: String, rings: Array[PackedVector3Array], closed: bool) -> void:
	var count := rings[0].size()
	var normals: Array[PackedVector3Array] = []
	for i in rings.size():
		var ring_normals := PackedVector3Array()
		var center := Vector3.ZERO
		for point in rings[i]:
			center += point
		center /= count
		for k in count:
			var along := rings[mini(i + 1, rings.size() - 1)][k] - rings[maxi(i - 1, 0)][k]
			var around := rings[i][(k + 1) % count] - rings[i][(k - 1 + count) % count]
			var normal := along.cross(around).normalized()
			if normal.dot(rings[i][k] - center) < 0.0:
				normal = -normal
			ring_normals.append(normal)
		normals.append(ring_normals)
	var segments := count if closed else count - 1
	for i in rings.size() - 1:
		for k in segments:
			var k2 := (k + 1) % count
			_tri(material_name, rings[i][k], rings[i + 1][k], rings[i + 1][k2], normals[i][k], normals[i + 1][k], normals[i + 1][k2])
			_tri(material_name, rings[i][k], rings[i + 1][k2], rings[i][k2], normals[i][k], normals[i + 1][k2], normals[i][k2])


## Closes a ring with a flat fan around `center`, facing `normal`.
func cap(material_name: String, ring: PackedVector3Array, center: Vector3, normal: Vector3) -> void:
	for k in ring.size():
		_tri(material_name, center, ring[k], ring[(k + 1) % ring.size()], normal, normal, normal)


## --- Internals ---

func _quad(material_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(material_name, a, b, c, normal, normal, normal)
	_tri(material_name, a, c, d, normal, normal, normal)


func _tri(material_name: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var tool := _tool(material_name)
	# Godot draws triangles whose corners run clockwise (seen from the front) as front faces.
	if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
		var swap_point := b
		b = c
		c = swap_point
		var swap_normal := nb
		nb = nc
		nc = swap_normal
	for vertex: Array in [[a, na], [b, nb], [c, nc]]:
		tool.set_normal(vertex[1])
		tool.set_uv(Vector2.ZERO)
		tool.add_vertex(vertex[0])


func _tool(material_name: String) -> SurfaceTool:
	if not _tools.has(material_name):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material_name] = tool
	return _tools[material_name]


func _centroid(outline: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in outline:
		sum += point
	return sum / outline.size()
