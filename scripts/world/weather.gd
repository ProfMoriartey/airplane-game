class_name Weather
extends Node
## Sets up the sky, sun, fog, clouds and rain for a level from two simple choices:
## the time of day and the weather.

enum TimeOfDay { DAWN, NOON, DUSK }
enum Kind { CLEAR, OVERCAST, RAIN, FOG }

const RAIN_SCENE := preload("res://scenes/world/rain.tscn")

## Sun height and direction (degrees), light colour, and sky colours for each time of day.
const TIMES := {
	TimeOfDay.DAWN: {
		elevation = 9.0, azimuth = 70.0, sun = Color(1.0, 0.72, 0.5), energy = 0.95,
		sky_top = Color(0.33, 0.42, 0.62), horizon = Color(0.95, 0.72, 0.55), ambient = 0.7,
	},
	TimeOfDay.NOON: {
		elevation = 55.0, azimuth = 150.0, sun = Color(1.0, 0.97, 0.92), energy = 1.15,
		sky_top = Color(0.3, 0.48, 0.74), horizon = Color(0.7, 0.76, 0.8), ambient = 1.0,
	},
	TimeOfDay.DUSK: {
		elevation = 7.0, azimuth = 250.0, sun = Color(1.0, 0.55, 0.32), energy = 0.85,
		sky_top = Color(0.22, 0.25, 0.45), horizon = Color(0.95, 0.55, 0.38), ambient = 0.6,
	},
}
## How each kind of weather changes things: how grey the sky goes, sun strength,
## fog thickness and cloud cover.
const KINDS := {
	Kind.CLEAR: {grey = 0.0, sun = 1.0, fog = 1.0, clouds = 0.35, cloud_shade = 1.0},
	Kind.OVERCAST: {grey = 0.65, sun = 0.45, fog = 1.6, clouds = 0.85, cloud_shade = 0.75},
	Kind.RAIN: {grey = 0.8, sun = 0.3, fog = 2.4, clouds = 1.0, cloud_shade = 0.55},
	Kind.FOG: {grey = 0.6, sun = 0.5, fog = 4.0, clouds = 0.15, cloud_shade = 0.85},
}
const BASE_FOG_DENSITY := 0.0005

@export var time_of_day := TimeOfDay.NOON
@export var kind := Kind.CLEAR
## Overrides the weather's usual cloud cover when 0 or more.
@export_range(-1.0, 1.0) var cloud_amount := -1.0
@export var cloud_altitude := 650.0
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D


func _ready() -> void:
	var time: Dictionary = TIMES[time_of_day]
	var weather: Dictionary = KINDS[kind]
	var grey := Color(0.62, 0.64, 0.66)

	var sky_top: Color = time.sky_top.lerp(grey * 0.9, weather.grey)
	var horizon: Color = time.horizon.lerp(grey, weather.grey)

	sun.rotation_degrees = Vector3(-time.elevation, time.azimuth, 0.0)
	sun.light_color = time.sun
	sun.light_energy = time.energy * weather.sun
	sun.shadow_enabled = weather.sun > 0.4 and Settings.quality_value("shadows")

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = horizon
	# Hide the sun disc when it's behind cloud.
	sky_material.sun_angle_max = 30.0 if weather.sun > 0.4 else 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = time.ambient
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = horizon
	environment.fog_density = BASE_FOG_DENSITY * weather.fog
	environment.fog_aerial_perspective = 0.3
	environment.fog_sky_affect = 0.0
	# A soft glow around bright light (sun on the clouds, fire, muzzle flashes)...
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	# ...and a little extra contrast, with colours slightly muted in bad weather.
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = lerpf(1.08, 0.85, weather.grey)
	world_environment.environment = environment

	var clouds := Clouds.new()
	clouds.amount = cloud_amount if cloud_amount >= 0.0 else weather.clouds
	clouds.altitude = cloud_altitude
	clouds.top_color = Color.WHITE.lerp(time.sun, 0.35) * weather.cloud_shade
	clouds.bottom_color = horizon.darkened(0.25) * weather.cloud_shade
	clouds.bottom_color.a = 1.0
	clouds.top_color.a = 1.0
	add_child(clouds)

	if kind == Kind.RAIN:
		add_child(RAIN_SCENE.instantiate())
