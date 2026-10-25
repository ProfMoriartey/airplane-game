extends Control
## Set up a split-screen game: each player picks their device, aircraft and
## paint, then the mode, layout and where to fly.

const SPLIT_SCENE := "res://scenes/levels/split_screen.tscn"
## Gap between the panel and the window edge.
const MARGIN := 20.0
const PREVIEW_SIZE := Vector2(0, 140)
const TURN_SPEED := 0.35
const PLAYER_COLORS := [Color(0.95, 0.8, 0.45), Color(0.55, 0.8, 1.0)]

var _device_ids: Array[int] = []
var _device_pickers: Array[OptionButton] = []
var _aircraft: Array[AircraftStats] = []
var _models: Array[BiplaneModel] = []
var _turntables: Array[Node3D] = []
var _descriptions: Array[Label] = []


func _ready() -> void:
	_aircraft = Profile.unlocked_aircraft()
	# Player 1 starts with whatever they fly in the hangar.
	if not _is_unlocked(TwoPlayer.aircraft[0]):
		TwoPlayer.aircraft[0] = Profile.selected_aircraft().id
		TwoPlayer.liveries[0] = Profile.livery_of(TwoPlayer.aircraft[0])
	if not _is_unlocked(TwoPlayer.aircraft[1]):
		TwoPlayer.aircraft[1] = _aircraft[0].id

	$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	$Panel/Box.add_child(cards)
	$Panel/Box.move_child(cards, %Options.get_index())
	for player in 2:
		cards.add_child(_player_card(player))

	%Options.columns = 6
	_option(%Options, "Mode", ["Co-op (enemy waves)", "Versus (first to 5)"], TwoPlayer.mode, func(index: int) -> void:
		TwoPlayer.mode = index
		_show_plane(1))
	_option(%Options, "Screen", ["Side by side", "Top and bottom"], TwoPlayer.layout, func(index: int) -> void: TwoPlayer.layout = index)
	var maps := TheaterPresets.THEATERS.map(func(theater: Dictionary) -> String: return theater.name)
	_option(%Options, "Landscape", maps, TwoPlayer.theater, func(index: int) -> void: TwoPlayer.theater = index)
	_option(%Options, "Time of day", ["Dawn", "Noon", "Dusk"], TwoPlayer.time_of_day, func(index: int) -> void: TwoPlayer.time_of_day = index)
	_option(%Options, "Weather", ["Clear", "Overcast", "Rain", "Fog"], TwoPlayer.weather, func(index: int) -> void: TwoPlayer.weather = index)

	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%StartButton.pressed.connect(SceneLoader.change_scene.bind(SPLIT_SCENE))
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _fill_devices())
	_fill_devices()
	for player in 2:
		_show_plane(player)
	%StartButton.grab_focus()


func _process(delta: float) -> void:
	for turntable in _turntables:
		turntable.rotate_y(TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()


## One player's column: their plane turning on a stand, and their choices.
func _player_card(player: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var title := Label.new()
	title.text = tr("PLAYER %d") % (player + 1)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PLAYER_COLORS[player])
	box.add_child(title)
	box.add_child(_preview(player))
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	box.add_child(description)
	_descriptions.append(description)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	_device_pickers.append(_option(grid, "Uses", [], 0, func(index: int) -> void:
		TwoPlayer.devices[player] = _device_ids[index]
		_validate()))
	var names := _aircraft.map(func(aircraft: AircraftStats) -> String: return aircraft.display_name)
	var ids := _aircraft.map(func(aircraft: AircraftStats) -> String: return aircraft.id)
	_option(grid, "Flies", names, maxi(ids.find(TwoPlayer.aircraft[player]), 0), func(index: int) -> void:
		TwoPlayer.aircraft[player] = _aircraft[index].id
		_show_plane(player))
	var paints := Liveries.LIVERIES.map(func(livery: Dictionary) -> String: return livery.name)
	_option(grid, "Paint", paints, TwoPlayer.liveries[player], func(index: int) -> void:
		TwoPlayer.liveries[player] = index
		_show_plane(player))
	return card


## A small 3D stand with its own world, light and camera, like the hangar's.
func _preview(player: int) -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = PREVIEW_SIZE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.transparent_bg = false
	container.add_child(view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.14, 0.11)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.55, 0.48)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var light := DirectionalLight3D.new()
	light.light_color = Color(1, 0.92, 0.8)
	view.add_child(light)
	light.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var turntable := Node3D.new()
	turntable.rotation.y = player * PI
	view.add_child(turntable)
	var model := BiplaneModel.new()
	turntable.add_child(model)
	var camera := Camera3D.new()
	camera.fov = 45.0
	view.add_child(camera)
	camera.look_at_from_position(Vector3(6.5, 2.4, 6.5), Vector3(0, 0.3, 0))
	_turntables.append(turntable)
	_models.append(model)
	return container


func _show_plane(player: int) -> void:
	if _models.size() <= player:
		return
	var aircraft := _find_aircraft(TwoPlayer.aircraft[player])
	# In versus, player 2 flies for the other side.
	var side := Aircraft.Team.CENTRAL if player == 1 and TwoPlayer.mode == TwoPlayer.Mode.VERSUS else Aircraft.Team.ALLIES
	_models[player].build(aircraft, side, TwoPlayer.liveries[player])
	_descriptions[player].text = aircraft.description


func _find_aircraft(id: String) -> AircraftStats:
	for aircraft in _aircraft:
		if aircraft.id == id:
			return aircraft
	return _aircraft[0]


func _is_unlocked(id: String) -> bool:
	return _aircraft.any(func(aircraft: AircraftStats) -> bool: return aircraft.id == id)


## Lists the keyboard and every connected controller for both players.
func _fill_devices() -> void:
	_device_ids = [TwoPlayer.KEYBOARD]
	var names: Array[String] = ["Keyboard and mouse"]
	for device in Input.get_connected_joypads():
		_device_ids.append(device)
		names.append(tr("Controller %d (%s)") % [device + 1, Input.get_joy_name(device)])
	for player in 2:
		var picker := _device_pickers[player]
		picker.clear()
		for label in names:
			picker.add_item(label)
		var index := _device_ids.find(TwoPlayer.devices[player])
		if index < 0:
			# Pick a sensible default: keyboard for player 1, the first controller for player 2.
			index = 0 if player == 0 else mini(1, _device_ids.size() - 1)
			TwoPlayer.devices[player] = _device_ids[index]
		picker.select(index)
	_validate()


func _validate() -> void:
	var problem := ""
	if Input.get_connected_joypads().is_empty():
		problem = "Connect a controller or flight stick - two players can't share one keyboard."
	elif TwoPlayer.devices[0] == TwoPlayer.devices[1]:
		problem = "Each player needs their own device."
	%Status.text = problem
	%StartButton.disabled = problem != ""


func _option(grid: GridContainer, label_text: String, choices: Array, selected: int, on_change: Callable) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.clip_text = true
	picker.custom_minimum_size = Vector2(160, 0)
	for choice: String in choices:
		picker.add_item(choice)
	if not choices.is_empty():
		picker.select(selected)
	picker.item_selected.connect(on_change)
	grid.add_child(picker)
	return picker
