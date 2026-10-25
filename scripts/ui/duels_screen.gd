extends Control
## Choose an enemy ace to fight one on one.

const DUEL_SCENE := "res://scenes/levels/duel.tscn"

var _selected := 0


func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%FightButton.pressed.connect(_fight)
	for index in Aces.ACES.size():
		var ace: Dictionary = Aces.ACES[index]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		if not Aces.is_unlocked(ace):
			button.text = tr("%s   (locked)") % tr(ace.name)
		elif Profile.has_won_duel(ace.id):
			button.text = tr("%s   - defeated") % tr(ace.name)
		else:
			button.text = ace.name
		button.pressed.connect(_select.bind(index))
		%AceList.add_child(button)
	_select(DuelLevel.ace_index)
	%FightButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()


func _select(index: int) -> void:
	_selected = index
	var ace: Dictionary = Aces.ACES[index]
	%AceName.text = ace.name
	%AceDescription.text = ace.description
	var unlocked := Aces.is_unlocked(ace)
	if not unlocked:
		%AceRecord.text = "Defeat him in the campaign first."
	elif Profile.has_won_duel(ace.id):
		%AceRecord.text = "You have beaten him. Fancy another go?"
	else:
		%AceRecord.text = "Undefeated."
	%FightButton.disabled = not unlocked


func _fight() -> void:
	DuelLevel.ace_index = _selected
	SceneLoader.change_scene(DUEL_SCENE)
