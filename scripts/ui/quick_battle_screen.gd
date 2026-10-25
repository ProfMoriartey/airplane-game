extends Control
## Set up a Quick Battle: landscape, time of day, weather and enemy skill.

const BATTLE_SCENE := "res://scenes/levels/free_flight.tscn"


func _ready() -> void:
	var maps: Array[String] = []
	for theater in TheaterPresets.THEATERS:
		maps.append(theater.name)
	_option("Landscape", maps, QuickBattle.theater, func(index: int) -> void: QuickBattle.theater = index)
	_option("Time of day", ["Dawn", "Noon", "Dusk"], QuickBattle.time_of_day, func(index: int) -> void: QuickBattle.time_of_day = index)
	_option("Weather", ["Clear", "Overcast", "Rain", "Fog"], QuickBattle.weather, func(index: int) -> void: QuickBattle.weather = index)
	_option("Enemy pilots", ["Getting better each wave", "Rookies", "Veterans", "Aces"], QuickBattle.enemy_skill + 1, func(index: int) -> void: QuickBattle.enemy_skill = index - 1)
	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%StartButton.pressed.connect(SceneLoader.change_scene.bind(BATTLE_SCENE))
	%StartButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()


func _option(label_text: String, choices: Array, selected: int, on_change: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Options.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(300, 0)
	for choice: String in choices:
		picker.add_item(choice)
	picker.select(selected)
	picker.item_selected.connect(on_change)
	%Options.add_child(picker)
