class_name Guns
extends Node3D
## A plane's synchronised machine guns.
##
## Firing builds up heat. At full heat the guns overheat and stop until they cool
## down, and firing them hot can jam them for a moment.

@export var fire_rate := 12.0 ## Rounds per second, all guns together.
@export var muzzle_speed := 600.0 ## Metres per second.
@export var damage := 6.0 ## Per bullet.
@export var spread_degrees := 0.6
@export var max_ammo := 800
## Heat gained per second of firing, the same for every gun type: holding the
## trigger overheats the guns after about 6 seconds (cooling included).
@export var heat_per_second := 0.52
@export var cooling_rate := 0.35 ## Heat lost per second.
## After overheating, the guns can fire again once heat drops below this.
@export var overheat_recovery := 0.4
@export var jam_duration := 2.0

var trigger := false
var ammo := 0
var heat := 0.0
var is_overheated := false
var is_jammed := false
var shots_fired := 0

var _cooldown := 0.0
var _jam_timer := 0.0
var _next_muzzle := 0

const FLASH_TIME := 0.05
const SHOT_SOUND := preload("res://assets/audio/sfx/gunshot.wav")

var _flash_timers: Array[float] = []
var _flashes: Array[Node3D] = []
var _shot_sound: AudioStreamPlayer3D

@onready var _owner_aircraft := get_parent() as Aircraft
@onready var _muzzles: Array[Node] = get_children()


func _ready() -> void:
	ammo = max_ammo
	_shot_sound = AudioStreamPlayer3D.new()
	_shot_sound.stream = SHOT_SOUND
	_shot_sound.bus = &"SFX"
	_shot_sound.unit_size = 12.0
	_shot_sound.volume_db = 3.0
	_shot_sound.max_polyphony = 6
	_shot_sound.position = Vector3(0, 0.6, -2.0)
	add_child(_shot_sound)
	for muzzle: Node3D in _muzzles:
		var flash := _make_flash()
		muzzle.add_child(flash)
		_flashes.append(flash)
		_flash_timers.append(0.0)


func _process(delta: float) -> void:
	for index in _flashes.size():
		_flash_timers[index] -= delta
		_flashes[index].visible = _flash_timers[index] > 0.0


func _physics_process(delta: float) -> void:
	heat = maxf(heat - cooling_rate * delta, 0.0)
	if is_overheated and heat < overheat_recovery:
		is_overheated = false
	if is_jammed:
		_jam_timer -= delta
		is_jammed = _jam_timer > 0.0

	_cooldown -= delta
	if not trigger or not can_fire():
		_cooldown = maxf(_cooldown, 0.0)
		return
	while _cooldown <= 0.0 and can_fire():
		_fire_round()
		_cooldown += 1.0 / fire_rate


func reload() -> void:
	ammo = max_ammo
	heat = 0.0
	is_overheated = false
	is_jammed = false


func can_fire() -> bool:
	return ammo > 0 and not is_overheated and not is_jammed


func _fire_round() -> void:
	ammo -= 1
	shots_fired += 1
	heat += heat_per_second / fire_rate
	if heat >= 1.0:
		heat = 1.0
		is_overheated = true
	# Firing hot guns risks a jam.
	elif randf() < maxf(heat - 0.7, 0.0) * 0.02:
		is_jammed = true
		_jam_timer = jam_duration

	_shot_sound.pitch_scale = randf_range(0.92, 1.08)
	_shot_sound.play()
	var muzzle := _muzzles[_next_muzzle] as Node3D
	_flash_timers[_next_muzzle] = FLASH_TIME
	_flashes[_next_muzzle].rotation.z = randf() * TAU
	_next_muzzle = (_next_muzzle + 1) % _muzzles.size()

	var spread := deg_to_rad(spread_degrees)
	var direction := -muzzle.global_basis.z
	direction = direction.rotated(muzzle.global_basis.x, randf_range(-spread, spread))
	direction = direction.rotated(muzzle.global_basis.y, randf_range(-spread, spread))

	Projectiles.spawn(
		muzzle.global_position,
		_owner_aircraft.velocity + direction * muzzle_speed,
		damage,
		_owner_aircraft,
	)


## A star-shaped burst of flame and a flicker of light at a gun's muzzle.
func _make_flash() -> Node3D:
	var flash := Node3D.new()
	flash.visible = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.75, 0.3, 0.9)
	material.albedo_texture = preload("res://assets/textures/soft_puff.tres")
	for angle: float in [0.0, PI * 0.5]:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.35, 0.9)
		mesh.material = material
		quad.mesh = mesh
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Long axis pointing forward out of the barrel.
		quad.rotation = Vector3(-PI * 0.5, 0.0, angle)
		quad.position = Vector3(0, 0, -0.4)
		flash.add_child(quad)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.0
	light.omni_range = 6.0
	flash.add_child(light)
	return flash
