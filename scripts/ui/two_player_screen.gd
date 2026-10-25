extends Control
## Set up a split-screen game: mode, layout, who uses which device, and where.

const SPLIT_SCENE := "res://scenes/levels/split_screen.tscn"

var _device_ids: Array[int] = []
var _device_pickers: Array[OptionButton] = []
var _aircraft: Array[AircraftStats] = []


func _ready() -> void:
	_option("Mode", ["Co-op: fight the waves together", "Versus: first to 5 kills"], TwoPlayer.mode, func(index: int) -> void: TwoPlayer.mode = index)
	_option("Screen", ["Side by side", "Top and bottom"], TwoPlayer.layout, func(index: int) -> void: TwoPlayer.layout = index)
	for player in 2:
		var picker := _option("Player %d uses" % (player + 1), [], 0, func(index: int) -> void:
			TwoPlayer.devices[player] = _device_ids[index]
			_validate())
		_device_pickers.append(picker)
	_aircraft = Profile.unlocked_aircraft()
	var names := _aircraft.map(func(aircraft: AircraftStats) -> String: return aircraft.display_name)
	var current := maxi(_aircraft.map(func(aircraft: AircraftStats) -> String: return aircraft.id).find(TwoPlayer.second_aircraft), 0)
	_option("Player 2 flies", names, current, func(index: int) -> void: TwoPlayer.second_aircraft = _aircraft[index].id)
	var maps := TheaterPresets.THEATERS.map(func(theater: Dictionary) -> String: return theater.name)
	_option("Landscape", maps, TwoPlayer.theater, func(index: int) -> void: TwoPlayer.theater = index)
	_option("Time of day", ["Dawn", "Noon", "Dusk"], TwoPlayer.time_of_day, func(index: int) -> void: TwoPlayer.time_of_day = index)
	_option("Weather", ["Clear", "Overcast", "Rain", "Fog"], TwoPlayer.weather, func(index: int) -> void: TwoPlayer.weather = index)

	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%StartButton.pressed.connect(SceneLoader.change_scene.bind(SPLIT_SCENE))
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _fill_devices())
	_fill_devices()
	%StartButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()


## Lists the keyboard and every connected controller for both players.
func _fill_devices() -> void:
	_device_ids = [TwoPlayer.KEYBOARD]
	var names: Array[String] = ["Keyboard and mouse"]
	for device in Input.get_connected_joypads():
		_device_ids.append(device)
		names.append("Controller %d (%s)" % [device + 1, Input.get_joy_name(device)])
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


func _option(label_text: String, choices: Array, selected: int, on_change: Callable) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Options.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(360, 0)
	for choice: String in choices:
		picker.add_item(choice)
	if not choices.is_empty():
		picker.select(selected)
	picker.item_selected.connect(on_change)
	%Options.add_child(picker)
	return picker
