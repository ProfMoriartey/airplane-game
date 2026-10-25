extends Control
## Draws the gun sight, bomb sight, hit marker, enemy and objective markers,
## lead indicators, and arrows pointing to anything that's off screen.

## How far ahead of the nose the gun sight is projected.
const SIGHT_DISTANCE := 300.0
const SIGHT_RADIUS := 14.0
const HIT_MARKER_TIME := 0.15
## Show where to aim for enemies closer than this.
const LEAD_RANGE := 700.0
const EDGE_MARGIN := 48.0
const SIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const HIT_COLOR := Color(1.0, 0.3, 0.2)
const BOMB_SIGHT_COLOR := Color(1.0, 0.6, 0.2, 0.9)
## Only show the bomb sight when this low over the ground.
const BOMB_SIGHT_MAX_HEIGHT := 1200.0

var plane: Aircraft
var objective_markers: Array[Vector3] = []

var _hit_timer := 0.0
var _font := ThemeDB.fallback_font
var _terrain: Terrain


func show_hit_marker() -> void:
	_hit_timer = HIT_MARKER_TIME


func _process(delta: float) -> void:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if plane == null or not plane.is_alive() or camera == null:
		return
	_draw_sight(camera)
	if Settings.show_bomb_sight:
		_draw_bomb_sight(camera)
	if not Settings.show_markers:
		return
	for marker in objective_markers:
		_draw_objective(camera, marker)
	for node in get_tree().get_nodes_in_group("aircraft"):
		var other := node as Aircraft
		if other.is_alive() and plane.is_hostile_to(other):
			_draw_enemy(camera, other)


func _draw_sight(camera: Camera3D) -> void:
	var point := plane.global_position - plane.global_basis.z * SIGHT_DISTANCE
	if camera.is_position_behind(point):
		return
	var center := camera.unproject_position(point)
	draw_arc(center, SIGHT_RADIUS, 0.0, TAU, 32, SIGHT_COLOR, 2.0)
	draw_circle(center, 2.0, SIGHT_COLOR)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * (SIGHT_RADIUS + 4.0), center + direction * (SIGHT_RADIUS + 12.0), SIGHT_COLOR, 2.0)

	if _hit_timer > 0.0:
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + corner * 8.0, center + corner * 18.0, HIT_COLOR, 3.0)


func _draw_bomb_sight(camera: Camera3D) -> void:
	if plane.bombs.count == 0:
		return
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	var here := plane.global_position
	if here.y - _terrain.get_height(here.x, here.z) > BOMB_SIGHT_MAX_HEIGHT:
		return
	var impact: Variant = plane.bombs.predict_impact(_terrain)
	if impact == null or camera.is_position_behind(impact):
		return
	var center := camera.unproject_position(impact)
	draw_arc(center, 10.0, 0.0, TAU, 24, BOMB_SIGHT_COLOR, 2.0)
	draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), BOMB_SIGHT_COLOR, 1.5)
	draw_line(center + Vector2(0, -18), center + Vector2(0, 18), BOMB_SIGHT_COLOR, 1.5)


func _draw_objective(camera: Camera3D, marker: Vector3) -> void:
	var distance := plane.global_position.distance_to(marker)
	var label := "%d m" % roundi(distance)
	var screen := get_viewport_rect().size
	var on_screen_area := Rect2(Vector2.ONE * EDGE_MARGIN, screen - Vector2.ONE * EDGE_MARGIN * 2.0)
	var behind := camera.is_position_behind(marker)
	var projected := camera.unproject_position(marker)
	if behind or not on_screen_area.has_point(projected):
		_draw_offscreen_arrow(projected, behind, label, screen, Settings.color("objective"))
		return
	var radius := 9.0
	var diamond := PackedVector2Array([
		projected + Vector2(0, -radius), projected + Vector2(radius, 0),
		projected + Vector2(0, radius), projected + Vector2(-radius, 0), projected + Vector2(0, -radius),
	])
	draw_polyline(diamond, Settings.color("objective"), 2.0)
	draw_string(_font, projected + Vector2(-20.0, radius + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Settings.color("objective"))


func _draw_enemy(camera: Camera3D, enemy: Aircraft) -> void:
	var distance := plane.global_position.distance_to(enemy.global_position)
	var label := "%d m" % roundi(distance)
	if enemy.pilot_name != "":
		label = "%s  %s" % [tr(enemy.pilot_name), label]
	var screen := get_viewport_rect().size
	var on_screen_area := Rect2(Vector2.ONE * EDGE_MARGIN, screen - Vector2.ONE * EDGE_MARGIN * 2.0)

	var behind := camera.is_position_behind(enemy.global_position)
	var projected := camera.unproject_position(enemy.global_position)
	if behind or not on_screen_area.has_point(projected):
		_draw_offscreen_arrow(projected, behind, label, screen, Settings.color("enemy"))
		return

	# Corner brackets that shrink with distance.
	var half := clampf(3000.0 / distance, 10.0, 40.0)
	var arm := half * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip := projected + corner * half
		draw_line(tip, tip - Vector2(corner.x * arm, 0.0), Settings.color("enemy"), 2.0)
		draw_line(tip, tip - Vector2(0.0, corner.y * arm), Settings.color("enemy"), 2.0)
	draw_string(_font, projected + Vector2(-20.0, half + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Settings.color("enemy"))

	# Lead indicator: put the gun sight on this to hit a moving target.
	if distance < LEAD_RANGE and Settings.show_lead_indicator:
		var flight_time := distance / plane.guns.muzzle_speed
		var lead := enemy.global_position + (enemy.velocity - plane.velocity) * flight_time
		if not camera.is_position_behind(lead):
			var lead_screen := camera.unproject_position(lead)
			draw_arc(lead_screen, 6.0, 0.0, TAU, 16, Settings.color("enemy"), 2.0)
			draw_line(projected, lead_screen, Color(Settings.color("enemy"), 0.35), 1.0)


func _draw_offscreen_arrow(projected: Vector2, behind: bool, label: String, screen: Vector2, color: Color) -> void:
	var center := screen * 0.5
	var direction := projected - center
	# Points behind the camera project mirrored, so flip them.
	if behind:
		direction = -direction
	if direction.length_squared() < 1.0:
		direction = Vector2.DOWN
	direction = direction.normalized()

	var half := center - Vector2.ONE * EDGE_MARGIN
	var reach := minf(
		half.x / maxf(absf(direction.x), 0.001),
		half.y / maxf(absf(direction.y), 0.001),
	)
	var tip := center + direction * reach
	var side := direction.orthogonal() * 10.0
	draw_colored_polygon(PackedVector2Array([tip, tip - direction * 22.0 + side, tip - direction * 22.0 - side]), color)
	draw_string(_font, tip - direction * 42.0 + Vector2(-20.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
