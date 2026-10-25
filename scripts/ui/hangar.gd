extends Control
## The hangar: browse the aircraft, compare them, choose one and its paint.

const TURN_SPEED := 0.35
## Ranges used to turn each statistic into a bar from 0 to 100.
const STAT_RANGES := {
	"Top speed": [48.0, 66.0],
	"Agility": [3.5, 5.2],
	"Armour": [70.0, 135.0],
	"Firepower": [60.0, 135.0],
	"Bombs": [0.0, 8.0],
}

var _shown: AircraftStats


func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%SelectButton.pressed.connect(_select)
	%LiveryPicker.item_selected.connect(_on_livery_picked)
	for livery in Liveries.LIVERIES:
		%LiveryPicker.add_item(livery.name)
	for aircraft in Profile.PLAYER_AIRCRAFT:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var unlocked := aircraft.unlock_rank <= Profile.rank()
		button.text = aircraft.display_name if unlocked else tr("%s   (unlocks at %s)") % [tr(aircraft.display_name), Ranks.name_of(aircraft.unlock_rank)]
		button.pressed.connect(_show.bind(aircraft))
		%PlaneList.add_child(button)
	_show(Profile.selected_aircraft())
	%SelectButton.grab_focus()


func _process(delta: float) -> void:
	%Turntable.rotate_y(TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()


func _show(aircraft: AircraftStats) -> void:
	_shown = aircraft
	var livery := Profile.livery_of(aircraft.id)
	%Model.build(aircraft, Aircraft.Team.ALLIES, livery)
	%LiveryPicker.select(livery)
	%Name.text = aircraft.display_name
	%Description.text = aircraft.description
	var unlocked := aircraft.unlock_rank <= Profile.rank()
	%SelectButton.disabled = not unlocked
	%LiveryPicker.disabled = not unlocked
	if not unlocked:
		%SelectButton.text = tr("Unlocks at %s") % Ranks.name_of(aircraft.unlock_rank)
	elif aircraft == Profile.selected_aircraft():
		%SelectButton.text = "Selected"
	else:
		%SelectButton.text = "Fly this aircraft"
	_show_stats(aircraft)


func _show_stats(aircraft: AircraftStats) -> void:
	for child in %Stats.get_children():
		child.queue_free()
	var values := {
		"Top speed": aircraft.max_speed,
		"Agility": aircraft.pitch_rate + aircraft.roll_rate,
		"Armour": aircraft.max_health,
		"Firepower": aircraft.gun_damage * aircraft.gun_fire_rate,
		"Bombs": float(aircraft.bomb_capacity),
	}
	for stat: String in values:
		var label := Label.new()
		label.text = stat
		label.custom_minimum_size = Vector2(100, 0)
		%Stats.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(240, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var limits: Array = STAT_RANGES[stat]
		bar.value = clampf(inverse_lerp(limits[0], limits[1], values[stat]), 0.05, 1.0) * 100.0
		%Stats.add_child(bar)


func _on_livery_picked(index: int) -> void:
	Profile.set_livery(_shown.id, index)
	%Model.build(_shown, Aircraft.Team.ALLIES, index)


func _select() -> void:
	Profile.select_aircraft(_shown.id)
	_show(_shown)
