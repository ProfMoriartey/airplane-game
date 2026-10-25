class_name Minimap
extends Control
## A round, heading-up minimap: the player's plane in the middle pointing up,
## the ground turning beneath it, and enemies, friends and objectives around it.
## Things out of range sit on the rim. "N" on the rim shows which way north is.

const MAP_SHADER := preload("res://shaders/minimap.gdshader")
const MAP_PIXELS := 256
const MAP_EXTENT := 3000.0
## Radius of the area shown, in metres; the zoom key cycles through these.
const RANGES := [1000.0, 2000.0, 4000.0]
const PLAYER_COLOR := Color(1.0, 0.95, 0.8)
const RIM_COLOR := Color(0.75, 0.62, 0.35, 0.9)

var plane: Aircraft:
	set(value):
		plane = value
		controls = value.controls if value else ""
var objective_markers: Array[Vector3] = []

## Prefix of the player's input actions, for the zoom control.
var controls := ""
var _range_index := 1
var _map: ColorRect
var _icons: Control
var _material := ShaderMaterial.new()
var _font := ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = MAP_SHADER
	_map = ColorRect.new()
	_map.material = _material
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_icons = Control.new()
	_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_icons)
	add_child(_icons)


func set_terrain(terrain: Terrain) -> void:
	_material.set_shader_parameter("map_texture", terrain.get_map_texture(MAP_PIXELS, MAP_EXTENT))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(controls + "map_zoom"):
		_range_index = (_range_index + 1) % RANGES.size()


func _process(_delta: float) -> void:
	visible = Settings.show_minimap and plane != null and plane.is_alive()
	if not visible:
		return
	var here := plane.global_position
	_material.set_shader_parameter("center_uv", Vector2(here.x, here.z) / (MAP_EXTENT * 2.0) + Vector2(0.5, 0.5))
	_material.set_shader_parameter("heading", _heading())
	_material.set_shader_parameter("zoom", RANGES[_range_index] / (MAP_EXTENT * 2.0))
	_icons.queue_redraw()


## Which way the plane faces, in radians clockwise from north (-Z).
func _heading() -> float:
	var forward := -plane.global_basis.z
	return atan2(forward.x, -forward.z)


## Turns a world position into a point on the minimap. clamped is set when it
## had to be pulled in to the rim.
func _to_map(world: Vector3) -> Dictionary:
	var radius := size.x * 0.5
	var heading := _heading()
	var offset := Vector2(world.x - plane.global_position.x, world.z - plane.global_position.z)
	var c := cos(heading)
	var s := sin(heading)
	var range_metres: float = RANGES[_range_index]
	var turned := Vector2(c * offset.x + s * offset.y, -s * offset.x + c * offset.y) / range_metres * radius
	var clamped := turned.length() > radius - 6.0
	if clamped:
		turned = turned.normalized() * (radius - 6.0)
	return {point = size * 0.5 + turned, clamped = clamped}


func _draw_icons() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5
	_icons.draw_arc(center, radius - 1.0, 0.0, TAU, 48, RIM_COLOR, 2.0)

	# North, wherever it is now that the map has turned.
	var heading := _heading()
	var north := Vector2(-sin(heading), -cos(heading))
	var north_point := center + north * (radius - 12.0)
	_icons.draw_circle(north_point, 9.0, Color(0, 0, 0, 0.6))
	_icons.draw_string(_font, north_point + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Settings.color("objective"))

	for marker in objective_markers:
		var spot := _to_map(marker)
		_diamond(spot.point, 5.0 if spot.clamped else 6.0)

	for node in get_tree().get_nodes_in_group("aircraft"):
		var other := node as Aircraft
		if other == plane or not other.is_alive():
			continue
		var spot := _to_map(other.global_position)
		var color := Settings.color("enemy") if plane.is_hostile_to(other) else Settings.color("friend")
		var other_forward := -other.global_basis.z
		var direction := atan2(other_forward.x, -other_forward.z) - heading
		_arrow(spot.point, direction, 4.5 if spot.clamped else 6.0, color)

	# The player, always in the middle, always pointing up.
	_arrow(center, 0.0, 8.0, PLAYER_COLOR)
	_icons.draw_string(_font, Vector2(6, size.y - 6), tr("%d km") % roundi(RANGES[_range_index] / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RIM_COLOR)


## A small plane-shaped arrow; angle 0 points up the minimap.
func _arrow(at: Vector2, angle: float, length: float, color: Color) -> void:
	var forward := Vector2(sin(angle), -cos(angle))
	var side := forward.orthogonal()
	var points := PackedVector2Array([
		at + forward * length,
		at - forward * length * 0.6 + side * length * 0.7,
		at - forward * length * 0.25,
		at - forward * length * 0.6 - side * length * 0.7,
	])
	_icons.draw_colored_polygon(points, color)
	_icons.draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.7), 1.0)


func _diamond(at: Vector2, radius: float) -> void:
	var points := PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)])
	_icons.draw_colored_polygon(points, Settings.color("objective"))
