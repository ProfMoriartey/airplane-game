extends CanvasLayer
## A short feedback form for playtests: how hard it felt, how much fun it was,
## and any comments. Saved with the last flight's results (see session.gd),
## so testers can send the playtest folder afterwards.

signal closed

## What the feedback is about, if not the last finished flight (e.g. one still in progress).
var about := ""

const DIFFICULTY_CHOICES := ["Far too easy", "A bit easy", "About right", "A bit hard", "Far too hard"]
const FUN_CHOICES := ["1 - Not fun", "2", "3 - OK", "4", "5 - Great fun"]

var _difficulty: OptionButton
var _fun: OptionButton
var _comment: TextEdit
var _status: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "FEEDBACK"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var last: Dictionary = SceneLoader.session.last_flight
	if about == "":
		about = _describe(last) if not last.is_empty() else tr("the game in general")
	box.add_child(_note(tr("About: %s") % about))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	_difficulty = _choice(grid, "How hard was it?", DIFFICULTY_CHOICES, 2)
	_fun = _choice(grid, "How much fun was it?", FUN_CHOICES, 2)
	var comment_label := Label.new()
	comment_label.text = "Anything else? (optional)"
	box.add_child(comment_label)
	_comment = TextEdit.new()
	_comment.custom_minimum_size = Vector2(0, 110)
	_comment.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_comment.placeholder_text = "What was confusing, too hard, or the best part?"
	box.add_child(_comment)
	_status = _note("")
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(140, 40)
	cancel.pressed.connect(close)
	buttons.add_child(cancel)
	var save := Button.new()
	save.text = "Save feedback"
	save.custom_minimum_size = Vector2(180, 40)
	save.pressed.connect(_save)
	buttons.add_child(save)
	_difficulty.grab_focus()


func _input(event: InputEvent) -> void:
	# Typing in the comment box shouldn't fly the plane or close the form.
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) and not _comment.has_focus():
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _save() -> void:
	SceneLoader.session.record_feedback(about, DIFFICULTY_CHOICES[_difficulty.selected], FUN_CHOICES[_fun.selected], _comment.text)
	_status.text = tr("Thanks! Saved to the playtest folder (Settings > Gameplay).")
	get_tree().create_timer(1.2, true, false, true).timeout.connect(close)


func _describe(flight: Dictionary) -> String:
	return "%s %s - %s" % [str(flight.get("mode", "")).replace("_", " "), flight.get("name", ""), flight.get("result", "")]


func _choice(grid: GridContainer, label_text: String, choices: Array, selected: int) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(220, 0)
	for choice: String in choices:
		picker.add_item(choice)
	picker.select(selected)
	grid.add_child(picker)
	return picker


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	return label
