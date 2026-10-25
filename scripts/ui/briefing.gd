extends CanvasLayer
## The screen shown before a mission: story, objectives and a map.

signal start_pressed

const MAP_PIXELS := 256
## The map shows this many metres in every direction from the centre.
const MAP_EXTENT := 2400.0


func _ready() -> void:
	%StartButton.pressed.connect(func() -> void: start_pressed.emit())
	%StartButton.grab_focus()


func setup(mission: Mission, terrain: Terrain, player: Aircraft) -> void:
	%Title.text = mission.title.to_upper()
	%Story.text = mission.briefing

	var lines: PackedStringArray = []
	var markers: Array[Dictionary] = []
	var number := 0
	for objective in mission.objectives:
		if objective.optional:
			lines.append("Bonus: %s" % objective.description)
			markers.append({position = objective.get_map_position(), label = "+", optional = true})
		else:
			number += 1
			lines.append("%d. %s" % [number, objective.description])
			markers.append({position = objective.get_map_position(), label = str(number), optional = false})
	%Objectives.text = "\n".join(lines)

	var map := %Map as TextureRect
	map.texture = ImageTexture.create_from_image(terrain.create_map_image(MAP_PIXELS, MAP_EXTENT))
	var overlay := %MapMarkers
	overlay.extent = MAP_EXTENT
	overlay.markers = markers
	overlay.player_position = player.global_position
	overlay.player_heading = -player.global_basis.z
	overlay.queue_redraw()
