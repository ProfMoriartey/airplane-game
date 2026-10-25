class_name VehicleModel
extends Node3D
## Builds low-poly WWI ground vehicles in code. Vehicles face -Z.

enum Kind { TANK, TRUCK }

@export var kind := Kind.TRUCK

static var _cache := {}


func _ready() -> void:
	if not _cache.has(kind):
		_cache[kind] = _make_tank() if kind == Kind.TANK else _make_truck()
	var instance := MeshInstance3D.new()
	instance.mesh = _cache[kind]
	add_child(instance)


## A rhomboid "landship": tracks running right round tall sides, gun sponsons, a small cab.
static func _make_tank() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("hull", Color(0.36, 0.34, 0.26), 0.85, 0.2)
	kit.add_material("track", Color(0.15, 0.14, 0.12), 0.9)
	kit.add_material("gun", Color(0.12, 0.12, 0.12), 0.5, 0.6)
	var side_outline := PackedVector2Array([
		Vector2(4.1, 1.0), Vector2(3.3, 2.5), Vector2(-2.9, 2.5), Vector2(-3.9, 1.3), Vector2(-3.1, 0.0), Vector2(3.0, 0.0),
	])
	# Outline x runs along the vehicle: turning it a quarter-turn points the tall horn forward (-Z).
	var turn := Basis(Vector3.UP, PI * 0.5)
	for x: float in [-1.45, 1.45]:
		kit.extrude("track", Transform3D(turn, Vector3(x, 0, 0)), side_outline, 0.75)
		kit.extrude("hull", Transform3D(turn, Vector3(x * 1.27, 0, 0)), PackedVector2Array([
			Vector2(3.6, 1.1), Vector2(3.0, 2.2), Vector2(-2.6, 2.2), Vector2(-3.4, 1.3), Vector2(-2.8, 0.25), Vector2(2.7, 0.25),
		]), 0.05)
		# Gun sponsons bulge out of each side.
		kit.box("hull", Transform3D(Basis.IDENTITY, Vector3(x * 1.55, 1.35, -0.3)), Vector3(0.7, 0.9, 1.5))
		kit.cylinder("gun", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x * 1.75, 1.4, -1.3)), 0.08, 0.1, 1.2, 6)
	kit.box("hull", Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)), Vector3(2.2, 1.9, 5.6))
	kit.box("hull", Transform3D(Basis.IDENTITY, Vector3(0, 2.5, -1.4)), Vector3(1.3, 0.6, 1.6))
	kit.box("track", Transform3D(Basis.IDENTITY, Vector3(0, 2.62, -2.15)), Vector3(0.9, 0.15, 0.08))
	return kit.commit()


## A lorry with a bonneted cab and a canvas-covered load bed.
static func _make_truck() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_material("body", Color(0.3, 0.32, 0.2), 0.85)
	kit.add_material("canvas", Color(0.6, 0.55, 0.4), 0.95)
	kit.add_material("dark", Color(0.08, 0.08, 0.08), 0.7)
	kit.add_material("glass", Color(0.18, 0.22, 0.25), 0.2, 0.3)
	kit.box("dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), Vector3(1.6, 0.25, 5.8))
	# Bonnet, radiator and cab.
	kit.box("body", Transform3D(Basis.IDENTITY, Vector3(0, 1.25, -2.3)), Vector3(1.2, 0.8, 1.3))
	kit.box("dark", Transform3D(Basis.IDENTITY, Vector3(0, 1.25, -2.97)), Vector3(1.0, 0.7, 0.05))
	kit.box("body", Transform3D(Basis.IDENTITY, Vector3(0, 1.75, -1.15)), Vector3(2.0, 1.7, 1.1))
	kit.box("glass", Transform3D(Basis.IDENTITY, Vector3(0, 2.15, -1.71)), Vector3(1.6, 0.55, 0.02))
	for x: float in [-1.01, 1.01]:
		kit.box("glass", Transform3D(Basis.IDENTITY, Vector3(x, 2.15, -1.15)), Vector3(0.02, 0.5, 0.7))
		# Mudguards over the front wheels.
		kit.box("body", Transform3D(Basis.IDENTITY, Vector3(x * 0.9, 1.15, -2.0)), Vector3(0.4, 0.06, 1.2))
	# Load bed with sides, and a canvas tilt arched over it.
	kit.box("body", Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 1.0)), Vector3(2.2, 0.5, 3.6))
	kit.cylinder("canvas", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.4, 1.0)), 1.1, 1.1, 3.6, 12)
	for z: float in [-2.0, 0.0, 1.9]:
		for x: float in [-0.95, 0.95]:
			kit.cylinder("dark", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.55, z)), 0.5, 0.5, 0.3, 10)
	return kit.commit()
