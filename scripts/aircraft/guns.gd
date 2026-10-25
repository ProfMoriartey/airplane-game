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
@export var heat_per_shot := 0.012
@export var cooling_rate := 0.35 ## Heat lost per second.
## After overheating, the guns can fire again once heat drops below this.
@export var overheat_recovery := 0.4
@export var jam_duration := 2.0

var trigger := false
var ammo := 0
var heat := 0.0
var is_overheated := false
var is_jammed := false

var _cooldown := 0.0
var _jam_timer := 0.0
var _next_muzzle := 0

@onready var _owner_aircraft := get_parent() as Aircraft
@onready var _muzzles: Array[Node] = get_children()


func _ready() -> void:
	ammo = max_ammo


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
	heat += heat_per_shot
	if heat >= 1.0:
		heat = 1.0
		is_overheated = true
	# Firing hot guns risks a jam.
	elif randf() < maxf(heat - 0.7, 0.0) * 0.02:
		is_jammed = true
		_jam_timer = jam_duration

	var muzzle := _muzzles[_next_muzzle] as Node3D
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
