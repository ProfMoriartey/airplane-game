class_name RoadMesh
## Builds dirt-road ribbons that lie on the terrain's surface.

const ROAD_COLOR := Color(0.42, 0.36, 0.26)
## Distance between cross-sections along a road.
const STEP := 6.0
## Lift above the ground, to stop the road flickering into it.
const LIFT := 0.25


static func make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ROAD_COLOR
	material.roughness = 1.0
	return material


## Adds one road along `points` (only x and z matter) to the SurfaceTool.
static func add_road(tool: SurfaceTool, terrain: Terrain, points: PackedVector3Array, width: float) -> void:
	var dense := _resample(points)
	if dense.size() < 2:
		return
	var half := width * 0.5
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	for index in dense.size():
		var here := dense[index]
		var ahead := dense[mini(index + 1, dense.size() - 1)]
		var behind := dense[maxi(index - 1, 0)]
		var direction := Vector3(ahead.x - behind.x, 0.0, ahead.z - behind.z).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * half
		var left := _on_ground(terrain, here - side)
		var right := _on_ground(terrain, here + side)
		if index > 0:
			# Two triangles per segment, wound clockwise seen from above.
			for vertex in [previous_left, left, previous_right, previous_right, left, right]:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(vertex)
		previous_left = left
		previous_right = right


static func _on_ground(terrain: Terrain, point: Vector3) -> Vector3:
	return Vector3(point.x, terrain.get_surface_height(point.x, point.z) + LIFT, point.z)


## Splits the road into evenly spaced points, so it follows the ground closely.
static func _resample(points: PackedVector3Array) -> PackedVector3Array:
	var dense := PackedVector3Array()
	for index in points.size() - 1:
		var from := points[index]
		var to := points[index + 1]
		var steps := maxi(ceili(Vector2(to.x - from.x, to.z - from.z).length() / STEP), 1)
		for step in steps:
			dense.append(from.lerp(to, float(step) / steps))
	if not points.is_empty():
		dense.append(points[-1])
	return dense
