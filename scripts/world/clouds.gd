class_name Clouds
extends Node3D
## Fluffy clouds made of soft camera-facing puffs. Flying into one fills the
## screen with white mist.

const CLOUD_SHADER := preload("res://shaders/cloud.gdshader")
const PUFF_TEXTURE := preload("res://assets/textures/soft_puff.tres")
const AREA := 3000.0
## The most clouds there will ever be, at amount 1.
const MAX_CLOUDS := 70

## 0 = clear sky, 1 = heavy cloud cover.
@export_range(0.0, 1.0) var amount := 0.4
@export var altitude := 650.0
@export var top_color := Color(1, 1, 1)
@export var bottom_color := Color(0.72, 0.75, 0.8)
@export var cloud_seed := 3

## Each cloud: { center: Vector3, radius: Vector3 } for the fly-through check.
var _clouds: Array[Dictionary] = []
var _mist: ColorRect


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = cloud_seed
	var transforms: Array[Transform3D] = []
	var shades: Array[Color] = []
	for index in roundi(MAX_CLOUDS * amount):
		var center := Vector3(rng.randf_range(-AREA, AREA), altitude + rng.randf_range(-60, 80), rng.randf_range(-AREA, AREA))
		var radius := Vector3(rng.randf_range(90, 220), rng.randf_range(30, 60), rng.randf_range(90, 220))
		_clouds.append({center = center, radius = radius})
		for puff in rng.randi_range(8, 16):
			var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)) * radius
			var puff_size := rng.randf_range(70, 150)
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * puff_size), center + offset))
			var shade := rng.randf_range(0.9, 1.0)
			shades.append(Color(shade, shade, shade))
	if transforms.is_empty():
		return

	var material := ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.set_shader_parameter("puff", PUFF_TEXTURE)
	material.set_shader_parameter("top_color", top_color)
	material.set_shader_parameter("bottom_color", bottom_color)
	var quad := QuadMesh.new()
	quad.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, shades[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Puffs face the camera in the shader, so make sure they're never culled early.
	instance.custom_aabb = AABB(Vector3(-AREA - 300, altitude - 400, -AREA - 300), Vector3(AREA * 2 + 600, 800, AREA * 2 + 600))
	add_child(instance)

	var layer := CanvasLayer.new()
	layer.layer = -1
	_mist = ColorRect.new()
	_mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.color = Color(top_color, 0.0)
	layer.add_child(_mist)
	add_child(layer)


func _process(_delta: float) -> void:
	if _mist == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# How deep inside the nearest cloud the camera is: 0 outside, 1 at its heart.
	var depth := 0.0
	for cloud in _clouds:
		var offset: Vector3 = (camera.global_position - cloud.center) / cloud.radius
		depth = maxf(depth, 1.0 - offset.length())
	_mist.color.a = clampf(depth * 1.6, 0.0, 0.85)
