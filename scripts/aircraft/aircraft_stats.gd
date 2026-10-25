class_name AircraftStats
extends Resource
## Everything that defines one aircraft type: how it flies, how it looks,
## what it carries and when the player unlocks it.
##
## Each plane in the game gets its own .tres file in data/aircraft/, so a new
## aircraft can be added or rebalanced without touching any code.

@export var id := ""
@export var display_name := "Aircraft"
@export_multiline var description := ""
## The rank (index into Ranks.RANKS) the player needs to fly this plane.
@export var unlock_rank := 0

@export_group("Speed")
## Top speed in level flight at full throttle, in metres per second.
@export var max_speed := 55.0
## Acceleration from the engine at full throttle, in m/s².
@export var thrust := 14.0
## Below this speed the wings stop lifting and the plane stalls.
@export var stall_speed := 22.0
## Speed the plane has when a mission starts in the air.
@export var start_speed := 42.0

@export_group("Handling")
## Maximum turn rates in radians per second.
@export var pitch_rate := 1.5
@export var roll_rate := 2.6
@export var yaw_rate := 0.5
## How strongly banking the wings turns the nose.
@export var bank_turn_rate := 0.8
## How quickly the plane reacts to stick input. Higher feels snappier.
@export var control_response := 5.0
## How fast the nose falls during a stall.
@export var stall_nose_drop := 1.2

@export_group("Durability")
@export var max_health := 100.0

@export_group("Weapons")
@export var gun_fire_rate := 12.0
@export var gun_damage := 6.0
@export var bomb_capacity := 6

@export_group("Look")
@export var paint_color := Color(0.36, 0.4, 0.24)
@export var wing_color := Color(0.78, 0.71, 0.54)
## Wingspan relative to the standard biplane.
@export var wing_span := 1.0
## Overall size, e.g. bigger for bombers.
@export var model_scale := 1.0
## Adds a third wing.
@export var triplane := false
