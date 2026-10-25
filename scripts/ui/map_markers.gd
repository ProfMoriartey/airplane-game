extends Control
## Draws objective numbers and the player's start position on top of the briefing map.

const OBJECTIVE_COLOR := Color(1.0, 0.85, 0.3)
const OPTIONAL_COLOR := Color(0.7, 0.85, 1.0)
const PLAYER_COLOR := Color(0.4, 1.0, 0.5)

var extent := 2400.0
var markers: Array[Dictionary] = []
var player_position := Vector3.ZERO
var player_heading := Vector3.FORWARD

var _font := ThemeDB.fallback_font


func _draw() -> void:
	for marker in markers:
		var point := _to_map(marker.position)
		var color := OPTIONAL_COLOR if marker.optional else OBJECTIVE_COLOR
		draw_circle(point, 13.0, Color(0, 0, 0, 0.6))
		draw_arc(point, 13.0, 0.0, TAU, 24, color, 2.0)
		draw_string(_font, point + Vector2(-5, 6), marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

	# The player's start, as an arrow pointing the way the plane faces.
	var start := _to_map(player_position)
	var heading := Vector2(player_heading.x, player_heading.z).normalized()
	var side := heading.orthogonal() * 8.0
	draw_colored_polygon(PackedVector2Array([start + heading * 14.0, start - heading * 8.0 + side, start - heading * 8.0 - side]), PLAYER_COLOR)


func _to_map(world: Vector3) -> Vector2:
	return Vector2(
		(world.x / extent * 0.5 + 0.5) * size.x,
		(world.z / extent * 0.5 + 0.5) * size.y,
	)
