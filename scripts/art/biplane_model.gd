class_name BiplaneModel
extends Node3D
## Builds a detailed low-poly WWI biplane (or triplane) from an aircraft's stats:
## tapered fuselage, rounded wings with struts and bracing wires, guns, landing
## gear, national markings, a pilot, a cockpit with gauges, and moving propeller
## and control surfaces.
##
## The plane faces -Z. Models are cached, so planes of the same type share meshes.

const TEAM_ALLIES := 0

## For standalone use (e.g. a parked plane); aircraft call build() themselves.
@export var stats: AircraftStats
@export var team := 0
@export var build_on_ready := false

var propeller: Node3D

var _blades: Node3D
var _blur: MeshInstance3D
var _aileron_left: Node3D
var _aileron_right: Node3D
var _elevator: Node3D
var _rudder: Node3D
var _head: Node3D
var _cockpit: Node3D
var _needles: Array[Node3D] = []

static var _cache := {}


func _ready() -> void:
	if build_on_ready and stats:
		build(stats, team)


func build(aircraft: AircraftStats, side: int) -> void:
	for child in get_children():
		child.queue_free()
	_needles.clear()
	var key := "%s/%d" % [aircraft.id, side]
	if not _cache.has(key):
		_cache[key] = _make_meshes(aircraft, side)
	var meshes: Dictionary = _cache[key]
	var span := aircraft.wing_span
	scale = Vector3.ONE * aircraft.model_scale

	_add_mesh(self, meshes.body, Transform3D.IDENTITY)

	propeller = _add_pivot(self, Vector3(0, 0, -3.1))
	_blades = _add_pivot(propeller, Vector3.ZERO)
	_add_mesh(_blades, meshes.blades, Transform3D.IDENTITY)
	_blur = _add_mesh(propeller, meshes.blur, Transform3D.IDENTITY)

	var aileron_x := 4.5 * span - 1.3
	# Ailerons sit on the upper wing, which rises slightly towards the tips.
	var aileron_y := 1.2 + aileron_x * 0.035
	_aileron_left = _add_pivot(self, Vector3(-aileron_x, aileron_y, -0.5))
	_add_mesh(_aileron_left, meshes.aileron, Transform3D.IDENTITY)
	_aileron_right = _add_pivot(self, Vector3(aileron_x, aileron_y, -0.5))
	_add_mesh(_aileron_right, meshes.aileron, Transform3D.IDENTITY)
	_elevator = _add_pivot(self, Vector3(0, 0.15, 2.85))
	_add_mesh(_elevator, meshes.elevator, Transform3D.IDENTITY)
	_rudder = _add_pivot(self, Vector3(0, 0.25, 3.0))
	_add_mesh(_rudder, meshes.rudder, Transform3D.IDENTITY)

	_head = _add_pivot(self, Vector3(0, 0.78, 0.15))
	_add_mesh(_head, meshes.head, Transform3D.IDENTITY)

	_cockpit = _add_pivot(self, Vector3(0, 0.6, -0.22))
	_cockpit.scale = Vector3.ONE * 0.55
	_cockpit.visible = false
	_add_mesh(_cockpit, meshes.panel, Transform3D.IDENTITY)
	for x: float in [-0.2, 0.0, 0.2]:
		var needle := _add_pivot(_cockpit, Vector3(x, 0.02, 0.035))
		_add_mesh(needle, meshes.needle, Transform3D.IDENTITY)
		_needles.append(needle)


## Moves the propeller, control surfaces and gauges to match the plane.
func animate(plane: Aircraft, delta: float) -> void:
	if propeller == null:
		return
	var spin := (0.2 + plane.throttle) * 60.0 if not plane.is_crashed else 0.0
	propeller.rotate_object_local(Vector3.BACK, spin * delta)
	# Fast-spinning blades become a faint blur disc, like a real propeller.
	_blur.visible = spin > 30.0
	_blades.visible = spin <= 50.0

	var deflection := deg_to_rad(20.0)
	_aileron_left.rotation.x = -plane.roll_input * deflection
	_aileron_right.rotation.x = plane.roll_input * deflection
	_elevator.rotation.x = plane.pitch_input * deflection
	_rudder.rotation.y = -plane.yaw_input * deflection

	# Gauges: airspeed, altitude, engine revs.
	var max_speed := plane.stats.max_speed * 1.3
	_needles[0].rotation.z = -lerpf(-2.3, 2.3, clampf(plane.speed / max_speed, 0.0, 1.0))
	_needles[1].rotation.z = -fmod(plane.global_position.y / 1000.0, 1.0) * TAU
	_needles[2].rotation.z = -lerpf(-2.3, 2.3, plane.throttle)


## The pilot's head turns with the player's look direction (yaw in radians).
func set_head_turn(yaw: float) -> void:
	if _head:
		_head.rotation.y = clampf(yaw, -1.8, 1.8)


## In cockpit view the pilot's own head is hidden and the instruments shown.
func set_cockpit_view(cockpit: bool) -> void:
	if _head:
		_head.visible = not cockpit
		_cockpit.visible = cockpit


func _add_pivot(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _add_mesh(parent: Node3D, mesh: Mesh, at: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = at
	parent.add_child(instance)
	return instance


## --- Building the meshes ---

static func _make_meshes(aircraft: AircraftStats, side: int) -> Dictionary:
	return {
		body = _make_body(aircraft, side),
		blades = _make_blades(),
		blur = _make_blur(),
		aileron = _make_flap(aircraft, 2.4, 0.38),
		elevator = _make_elevator(aircraft),
		rudder = _make_rudder(aircraft, side),
		head = _make_head(),
		panel = _make_panel(),
		needle = _make_needle(),
	}


static func _kit(aircraft: AircraftStats) -> MeshKit:
	var kit := MeshKit.new()
	kit.add_material("paint", aircraft.paint_color, 0.8)
	kit.add_material("canvas", aircraft.wing_color, 0.9)
	kit.add_material("metal", Color(0.3, 0.3, 0.3), 0.45, 0.6)
	kit.add_material("dark", Color(0.08, 0.08, 0.08), 0.7)
	kit.add_material("wood", Color(0.42, 0.28, 0.16), 0.7)
	kit.add_material("leather", Color(0.3, 0.2, 0.12), 0.8)
	kit.add_material("blue", Color(0.12, 0.2, 0.5), 0.8)
	kit.add_material("white", Color(0.92, 0.92, 0.9), 0.8)
	kit.add_material("red", Color(0.7, 0.1, 0.08), 0.8)
	return kit


static func _make_body(aircraft: AircraftStats, side: int) -> ArrayMesh:
	var kit := _kit(aircraft)
	var span := aircraft.wing_span

	_fuselage(kit)

	# Engine cowling and the gun pair on top of it.
	kit.cylinder("metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -2.75)), 0.56, 0.6, 0.55, 14)
	kit.cylinder("dark", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -3.03)), 0.44, 0.44, 0.02, 14)
	kit.cylinder("metal", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -3.15)), 0.0, 0.14, 0.25, 8)
	for x: float in [-0.3, 0.3]:
		kit.cylinder("dark", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.6, -1.95)), 0.07, 0.07, 0.9, 6)
		kit.cylinder("dark", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.6, -2.5)), 0.025, 0.025, 0.3, 5)
	# Exhaust stub on the right.
	kit.cylinder("dark", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.5, -0.15, -2.1)), 0.06, 0.06, 0.6, 6)

	# Wings.
	_wing(kit, Vector3(0, 1.2, -1.2), 9.0 * span, 1.4, 0.12, 2.0)
	_wing(kit, Vector3(0, -0.35, -1.2), 8.0 * span, 1.3, 0.11, 1.0)
	if aircraft.triplane:
		_wing(kit, Vector3(0, 0.45, -1.2), 8.5 * span, 1.2, 0.11, 0.0)

	# Struts between the wings, and the cabane struts holding the top wing over the fuselage.
	var strut_x := 3.0 * span
	for x: float in [-strut_x, strut_x]:
		for z: float in [-1.65, -0.8]:
			_rod(kit, "wood", Vector3(x, -0.3, z), Vector3(x, 1.15, z), 0.05)
		# Crossed bracing wires in each wing bay.
		var inner := 0.5 * signf(x)
		_rod(kit, "dark", Vector3(inner, -0.3, -1.2), Vector3(x, 1.15, -1.2), 0.012)
		_rod(kit, "dark", Vector3(inner, 1.15, -1.2), Vector3(x, -0.3, -1.2), 0.012)
	for x: float in [-0.35, 0.35]:
		_rod(kit, "wood", Vector3(x, 0.45, -1.6), Vector3(x * 1.3, 1.15, -1.5), 0.04)
		_rod(kit, "wood", Vector3(x, 0.45, -0.8), Vector3(x * 1.3, 1.15, -0.9), 0.04)

	# Tailplane and fin (the moving elevator and rudder are separate).
	_wing(kit, Vector3(0, 0.15, 2.5), 3.2, 0.7, 0.06, 0.0)
	kit.extrude("paint", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.25, 0)),
		PackedVector2Array([Vector2(-2.4, 0.1), Vector2(-3.0, 0.1), Vector2(-3.0, 1.0), Vector2(-2.75, 1.05)]), 0.06)

	# Landing gear: V-struts, axle and wheels, plus a tail skid.
	for x: float in [-0.6, 0.6]:
		_rod(kit, "wood", Vector3(x * 0.5, -0.4, -2.0), Vector3(x, -1.1, -1.5), 0.04)
		_rod(kit, "wood", Vector3(x * 0.5, -0.4, -1.0), Vector3(x, -1.1, -1.5), 0.04)
		kit.cylinder("dark", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x * 1.15, -1.1, -1.5)), 0.36, 0.36, 0.14, 12)
		kit.cylinder("metal", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x * 1.15, -1.1, -1.5)), 0.12, 0.12, 0.17, 8)
	_rod(kit, "metal", Vector3(-0.7, -1.1, -1.5), Vector3(0.7, -1.1, -1.5), 0.03)
	_rod(kit, "wood", Vector3(0, -0.05, 2.6), Vector3(0, -0.35, 2.95), 0.04)

	# Cockpit rim and a small windscreen.
	kit.cylinder("leather", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.15)), 0.33, 0.36, 0.06, 12, false)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.8, 0.85, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.set_material("glass", glass)
	kit.box("glass", Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.64, -0.45)), Vector3(0.4, 0.2, 0.01))

	_markings(kit, side, span)
	return kit.commit()


## The fuselage: rounded cross-sections tapering from engine to tail.
static func _fuselage(kit: MeshKit) -> void:
	# [z, half width, half height, centre height]
	var sections := [
		[-2.5, 0.52, 0.55, 0.0],
		[-1.8, 0.5, 0.56, 0.02],
		[-0.6, 0.46, 0.52, 0.03],
		[0.6, 0.38, 0.44, 0.06],
		[1.8, 0.24, 0.3, 0.12],
		[2.8, 0.1, 0.16, 0.18],
		[3.05, 0.03, 0.06, 0.2],
	]
	var rings: Array[PackedVector3Array] = []
	for section: Array in sections:
		var ring := PackedVector3Array()
		for k in 12:
			var angle := TAU * k / 12.0
			# A squarish ellipse, like a fabric-covered box frame.
			var c := cos(angle)
			var s := sin(angle)
			var x: float = signf(c) * pow(absf(c), 0.6) * section[1]
			var y: float = signf(s) * pow(absf(s), 0.6) * section[2] + section[3]
			ring.append(Vector3(x, y, section[0]))
		rings.append(ring)
	kit.strip("paint", rings, true)
	kit.cap("paint", rings[-1], Vector3(0, 0.2, 3.05), Vector3.BACK)


## A wing with an aerofoil profile, rounded tips and a little dihedral.
static func _wing(kit: MeshKit, center: Vector3, span: float, chord: float, thickness: float, dihedral_degrees: float) -> void:
	var profile := [
		Vector2(-0.5, 0.0), Vector2(-0.44, 0.55), Vector2(-0.28, 0.95), Vector2(0.0, 0.85),
		Vector2(0.3, 0.45), Vector2(0.5, 0.0), Vector2(0.3, -0.2), Vector2(0.0, -0.3),
		Vector2(-0.3, -0.35), Vector2(-0.44, -0.25),
	]
	var stations := [-1.0, -0.98, -0.93, -0.84, -0.6, -0.2, 0.2, 0.6, 0.84, 0.93, 0.98, 1.0]
	var rings: Array[PackedVector3Array] = []
	var half := span * 0.5
	var dihedral := tan(deg_to_rad(dihedral_degrees))
	for t: float in stations:
		# Round the tips by shrinking the chord over the last fifth of the span.
		var tip := clampf((absf(t) - 0.8) / 0.2, 0.0, 1.0)
		var chord_here := chord * maxf(sqrt(1.0 - tip * tip), 0.12)
		var ring := PackedVector3Array()
		for point: Vector2 in profile:
			ring.append(center + Vector3(
				t * half,
				point.y * thickness + absf(t) * half * dihedral,
				point.x * chord_here + (chord - chord_here) * 0.5,
			))
		rings.append(ring)
	kit.strip("canvas", rings, true)


static func _rod(kit: MeshKit, material_name: String, from: Vector3, to: Vector3, radius: float) -> void:
	var direction := to - from
	var length := direction.length()
	var up := direction / length
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var rod_basis := Basis(side, up, side.cross(up))
	kit.cylinder(material_name, Transform3D(rod_basis, (from + to) * 0.5), radius, radius, length, 5, false)


## Roundels for our side, crosses for the enemy, on the wings and fuselage.
static func _markings(kit: MeshKit, side: int, span: float) -> void:
	var tip_x := 4.5 * span - 1.2
	var low_x := tip_x - 0.4
	# Tilted to match the wings' dihedral, and lifted just clear of the fabric.
	var upper_tilt := deg_to_rad(2.0)
	var lower_tilt := deg_to_rad(1.0)
	var spots := [
		Transform3D(Basis(Vector3.BACK, -upper_tilt), Vector3(-tip_x, 1.33 + tip_x * tan(upper_tilt), -1.25)),
		Transform3D(Basis(Vector3.BACK, upper_tilt), Vector3(tip_x, 1.33 + tip_x * tan(upper_tilt), -1.25)),
		Transform3D(Basis(Vector3.BACK, PI - lower_tilt), Vector3(-low_x, -0.41 + low_x * tan(lower_tilt), -1.2)),
		Transform3D(Basis(Vector3.BACK, PI + lower_tilt), Vector3(low_x, -0.41 + low_x * tan(lower_tilt), -1.2)),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.345, 0.07, 1.0)),
		Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.345, 0.07, 1.0)),
	]
	for spot: Transform3D in spots:
		var small := spot.origin.z > 0.0
		var size := 0.32 if small else 0.55
		if side == TEAM_ALLIES:
			kit.disc("blue", spot, size)
			kit.disc("white", spot.translated_local(Vector3(0, 0.006, 0)), size * 0.68)
			kit.disc("red", spot.translated_local(Vector3(0, 0.012, 0)), size * 0.34)
		else:
			kit.box("white", spot, Vector3(size * 2.0, 0.004, size * 2.0))
			kit.box("dark", spot.translated_local(Vector3(0, 0.006, 0)), Vector3(size * 1.6, 0.004, size * 0.45))
			kit.box("dark", spot.translated_local(Vector3(0, 0.006, 0)), Vector3(size * 0.45, 0.004, size * 1.6))


## --- Moving parts ---

static func _make_blades() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("wood", Color(0.45, 0.3, 0.17), 0.6)
	for direction: float in [1.0, -1.0]:
		kit.extrude("wood", Transform3D(Basis(Vector3.UP, 0.25 * direction), Vector3.ZERO),
			PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.1, 0.9 * direction), Vector2(0.05, 1.2 * direction), Vector2(-0.05, 1.2 * direction), Vector2(-0.09, 0.9 * direction)]), 0.04)
	return kit.commit()


static func _make_blur() -> ArrayMesh:
	var kit := MeshKit.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.2, 0.15, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kit.set_material("blur", material)
	kit.disc("blur", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 1.2, 24)
	return kit.commit()


## A control surface hanging behind its hinge (the pivot), spanning X.
static func _make_flap(aircraft: AircraftStats, span: float, chord: float) -> ArrayMesh:
	var kit := _kit(aircraft)
	kit.box("canvas", Transform3D(Basis.IDENTITY, Vector3(0, 0, chord * 0.5)), Vector3(span, 0.05, chord))
	return kit.commit()


static func _make_elevator(aircraft: AircraftStats) -> ArrayMesh:
	var kit := _kit(aircraft)
	kit.box("canvas", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)), Vector3(3.0, 0.04, 0.4))
	return kit.commit()


## The rudder: tricolour stripes for our side, a white panel with a cross for the enemy.
static func _make_rudder(aircraft: AircraftStats, side: int) -> ArrayMesh:
	var kit := _kit(aircraft)
	if side == TEAM_ALLIES:
		var stripes := ["blue", "white", "red"]
		for index in 3:
			kit.box(stripes[index], Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.08 + index * 0.16)), Vector3(0.05, 1.0, 0.16))
	else:
		kit.box("white", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.24)), Vector3(0.05, 1.0, 0.48))
		kit.box("dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.24)), Vector3(0.06, 0.6, 0.12))
		kit.box("dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.24)), Vector3(0.06, 0.12, 0.4))
	return kit.commit()


## The pilot: leather helmet, goggles, scarf.
static func _make_head() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("leather", Color(0.32, 0.21, 0.13), 0.8)
	kit.add_material("glass", Color(0.15, 0.15, 0.15), 0.2, 0.3)
	kit.add_material("scarf", Color(0.9, 0.88, 0.82), 0.9)
	kit.sphere("leather", Transform3D(Basis.IDENTITY, Vector3.ZERO), 0.17, 10, 6)
	for x: float in [-0.065, 0.065]:
		kit.cylinder("glass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.02, -0.15)), 0.045, 0.045, 0.04, 8)
	kit.cylinder("scarf", Transform3D(Basis.IDENTITY, Vector3(0, -0.18, 0)), 0.13, 0.15, 0.08, 10)
	return kit.commit()


## The instrument panel: wooden board with three gauges, facing the pilot (+Z).
static func _make_panel() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("wood", Color(0.35, 0.22, 0.12), 0.6)
	kit.add_material("face", Color(0.1, 0.1, 0.09), 0.5)
	kit.add_material("rim", Color(0.75, 0.65, 0.4), 0.3, 0.8)
	kit.box("wood", Transform3D.IDENTITY, Vector3(0.72, 0.26, 0.05))
	for x: float in [-0.2, 0.0, 0.2]:
		var face := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.02, 0.028))
		kit.cylinder("rim", face, 0.075, 0.075, 0.012, 16)
		kit.disc("face", face.translated_local(Vector3(0, 0.007, 0)), 0.065, 16)
	return kit.commit()


static func _make_needle() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("needle", Color(0.95, 0.9, 0.75), 0.5)
	kit.box("needle", Transform3D(Basis.IDENTITY, Vector3(0, 0.025, 0)), Vector3(0.006, 0.05, 0.004))
	return kit.commit()
