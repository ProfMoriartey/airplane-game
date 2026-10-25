extends Node3D
## The living background behind the main menu: a flight of biplanes circling
## over the countryside, with the camera drifting alongside them.

const ORBIT_RADIUS := 600.0
const ORBIT_SPEED := 0.045 ## Radians per second around the circle.
const ALTITUDE := 320.0
const BANK := 0.35
## Where each plane sits in the formation: (sideways, up, behind).
const SLOTS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(-14, -3, 16), Vector3(16, 2, 20)]

var _angle := 0.0
var _planes: Array[BiplaneModel] = []

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	var types := [Profile.selected_aircraft(), preload("res://data/aircraft/scout.tres"), preload("res://data/aircraft/lark.tres")]
	for index in SLOTS.size():
		var model := BiplaneModel.new()
		add_child(model)
		var aircraft: AircraftStats = types[index]
		model.build(aircraft, Aircraft.Team.ALLIES, Profile.livery_of(aircraft.id) if index == 0 else 0)
		_planes.append(model)


func _process(delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	var leader := _orbit_transform(_angle)
	for index in _planes.size():
		_planes[index].global_transform = leader * Transform3D(Basis.IDENTITY, SLOTS[index])
		_planes[index].propeller.rotate_object_local(Vector3.BACK, 40.0 * delta)
	# The camera hangs off to one side and slightly behind, gently bobbing.
	var bob := sin(_angle * 7.0) * 3.0
	var eye := leader * Vector3(38, 6 + bob, 34)
	var view := Transform3D(Basis.IDENTITY, eye).looking_at(leader * Vector3(-6, 0, -10), Vector3.UP)
	# Turn a little to the left, so the planes fly in the open part of the screen
	# rather than behind the menu panel.
	_camera.global_transform = view.rotated_local(Vector3.UP, 0.32)


## Flying round a big circle, banked into the turn.
func _orbit_transform(angle: float) -> Transform3D:
	var center := Vector3(cos(angle), 0.0, sin(angle)) * ORBIT_RADIUS + Vector3.UP * ALTITUDE
	var forward := Vector3(-sin(angle), 0.0, cos(angle))
	var heading := Basis.looking_at(forward, Vector3.UP).rotated(forward, -BANK)
	return Transform3D(heading, center)
