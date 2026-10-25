extends CanvasLayer
## The screen shown before a mission: story, objectives, a map and plane selection.

signal start_pressed
signal aircraft_selected(aircraft: AircraftStats)

const MAP_PIXELS := 256
## The map shows this many metres in every direction from the centre.
const MAP_EXTENT := 2400.0

var _aircraft: Array[AircraftStats] = []


func _ready() -> void:
	%StartButton.pressed.connect(func() -> void: start_pressed.emit())
	%StartButton.grab_focus()
	%AircraftPicker.item_selected.connect(_on_aircraft_picked)


func setup(mission: Mission, terrain: Terrain, player: Aircraft) -> void:
	%Title.text = mission.title.to_upper()
	%Story.text = mission.briefing

	var lines: PackedStringArray = []
	var markers: Array[Dictionary] = []
	var number := 0
	for objective in mission.objectives:
		if objective.optional:
			lines.append("Bonus: %s" % Settings.fill_keys(objective.description))
			markers.append({position = objective.get_map_position(), label = "+", optional = true})
		else:
			number += 1
			lines.append("%d. %s" % [number, Settings.fill_keys(objective.description)])
			markers.append({position = objective.get_map_position(), label = str(number), optional = false})
	%Objectives.text = "\n".join(lines)
	_fill_aircraft(player.stats)

	var map := %Map as TextureRect
	map.texture = terrain.get_map_texture(MAP_PIXELS, MAP_EXTENT)
	var overlay := %MapMarkers
	overlay.extent = MAP_EXTENT
	overlay.markers = markers
	overlay.player_position = player.global_position
	overlay.player_heading = -player.global_basis.z
	overlay.queue_redraw()


func _fill_aircraft(current: AircraftStats) -> void:
	_aircraft = Profile.unlocked_aircraft()
	var picker := %AircraftPicker as OptionButton
	for aircraft in _aircraft:
		picker.add_item(aircraft.display_name)
		if aircraft == current:
			picker.select(picker.item_count - 1)
	_show_aircraft_info(current)


func _on_aircraft_picked(index: int) -> void:
	_show_aircraft_info(_aircraft[index])
	aircraft_selected.emit(_aircraft[index])


func _show_aircraft_info(aircraft: AircraftStats) -> void:
	var text := "%s\nTop speed %d km/h   Armour %d   Guns %d   Bombs %d" % [
		aircraft.description,
		roundi(aircraft.max_speed * 3.6),
		roundi(aircraft.max_health),
		roundi(aircraft.gun_damage * aircraft.gun_fire_rate),
		aircraft.bomb_capacity,
	]
	if _aircraft.size() < Profile.PLAYER_AIRCRAFT.size():
		text += "\nMore aircraft unlock as you are promoted."
	%AircraftInfo.text = text
