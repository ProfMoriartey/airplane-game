extends CanvasLayer
## The screen shown before a mission: story, objectives, a map and plane selection.

signal start_pressed
signal aircraft_selected(aircraft: AircraftStats)

const MAP_PIXELS := 256
## The map shows this many metres in every direction from the centre.
const MAP_EXTENT := 2400.0
## On wide screens the briefing stays this wide, centred, instead of stretching.
const MAX_WIDTH := 1280.0
const SIDE_MARGIN := 40
const CAMPAIGN_SCREEN := "res://scenes/ui/campaign_screen.tscn"

var _aircraft: Array[AircraftStats] = []
## Where Back goes: the campaign screen, or the main menu for training and other missions.
var _back_scene := SceneLoader.MAIN_MENU


func _ready() -> void:
	_add_scrolling_and_buttons()
	%StartButton.pressed.connect(func() -> void: start_pressed.emit())
	%StartButton.grab_focus()
	%AircraftPicker.item_selected.connect(_on_aircraft_picked)
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


## Long briefings scroll, while Back and Take off always stay in view below.
func _add_scrolling_and_buttons() -> void:
	var column := $Margin/Columns/Text as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", column.get_theme_constant("separation"))
	scroll.add_child(content)
	for child in column.get_children():
		if child == %StartButton:
			continue
		if child.name == "Spacer":
			child.queue_free()
			continue
		child.reparent(content)
	column.add_child(scroll)
	column.move_child(scroll, 0)
	# Moving nodes drops their owner, which %Name lookups rely on.
	for child in content.get_children():
		child.owner = self

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, %StartButton.custom_minimum_size.y)
	back.pressed.connect(_go_back)
	buttons.add_child(back)
	%StartButton.reparent(buttons)
	%StartButton.owner = self


func _go_back() -> void:
	SceneLoader.change_scene(_back_scene)


func _fit_width() -> void:
	var extra := maxf(get_viewport().get_visible_rect().size.x - MAX_WIDTH, 0.0) / 2.0
	for side in ["margin_left", "margin_right"]:
		$Margin.add_theme_constant_override(side, SIDE_MARGIN + int(extra))


func setup(mission: Mission, terrain: Terrain, player: Aircraft) -> void:
	%Title.text = tr(mission.title).to_upper()
	if Profile.CAMPAIGN.all_missions().any(func(info: MissionInfo) -> bool: return info.id == mission.mission_id):
		_back_scene = CAMPAIGN_SCREEN
	%Story.text = mission.briefing

	var lines: PackedStringArray = []
	var markers: Array[Dictionary] = []
	var number := 0
	for objective in mission.objectives:
		if objective.optional:
			lines.append(tr("Bonus: %s") % Settings.fill_keys(objective.description))
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
	var text := tr("%s\nTop speed %d km/h   Armour %d   Guns %d   Bombs %d") % [
		tr(aircraft.description),
		roundi(aircraft.max_speed * 3.6),
		roundi(aircraft.max_health),
		roundi(aircraft.gun_damage * aircraft.gun_fire_rate),
		aircraft.bomb_capacity,
	]
	if _aircraft.size() < Profile.PLAYER_AIRCRAFT.size():
		text += "\n" + tr("More aircraft unlock as you are promoted.")
	%AircraftInfo.text = text
