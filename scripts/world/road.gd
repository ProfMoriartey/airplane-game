class_name Road
extends Path3D
## A Path3D that's also drawn as a dirt road on the ground, e.g. for a convoy.

@export var width := 7.0


func _ready() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if terrain == null:
		return
	var points := PackedVector3Array()
	for point in curve.get_baked_points():
		points.append(to_global(point))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	RoadMesh.add_road(tool, terrain, points, width)
	tool.set_material(RoadMesh.make_material())
	var road := MeshInstance3D.new()
	road.mesh = tool.commit()
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The road is built in world space.
	road.top_level = true
	add_child(road)
