class_name AircraftStats
extends Resource
## Tunable numbers that define how one aircraft type flies.
##
## Each plane in the game gets its own .tres file in data/aircraft/, so a new
## aircraft can be added or rebalanced without touching any code.

@export var display_name := "Aircraft"

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
