extends Control
## Pilots (save slots): each has their own campaign, medals and aircraft.
## Choose who to fly as, create a new pilot, rename or delete one.

const MARGIN := 40
const HEADER_COLOR := Color(0.85, 0.7, 0.45)
const NOTE_COLOR := Color(0.7, 0.66, 0.58)
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _cards: HBoxContainer
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _delete_dialog: ConfirmationDialog
## The slot the open dialog is about.
var _dialog_slot := 0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "PILOTS"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	box.add_child(_note("Each pilot has their own campaign progress, medals, aircraft and duels. Settings are shared."))
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_cards)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(SceneLoader.go_to_main_menu)
	box.add_child(back)
	_build_dialogs()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _name_dialog.visible and not _delete_dialog.visible:
		SceneLoader.go_to_main_menu()


func _refresh(focus_slot := Profile.current_slot) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for slot in Profile.SLOT_COUNT:
		_cards.add_child(_card(slot))
	var first := _cards.get_child(focus_slot).find_child("Main", true, false) as Button
	first.grab_focus.call_deferred()


func _card(slot: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var summary := Profile.slot_summary(slot) if Profile.slot_exists(slot) else {}
	var current := slot == Profile.current_slot

	var heading := Label.new()
	heading.text = tr("SLOT %d") % (slot + 1)
	if current:
		heading.text += "  -  " + tr("FLYING NOW")
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", HEADER_COLOR)
	box.add_child(heading)
	var name_label := Label.new()
	name_label.text = summary.name if not summary.is_empty() else "Empty"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	if summary.is_empty():
		box.add_child(_note("No pilot yet."))
	else:
		var lines: PackedStringArray = [
			Ranks.name_of(summary.rank),
			tr("%d career points") % summary.points,
			tr("Campaign: %d / %d missions") % [summary.missions_completed, summary.missions_total],
			tr("Medals: %d / %d") % [summary.medals, Medals.MEDALS.size()],
			tr("Last flown: %s") % _date(summary.last_played),
		]
		box.add_child(_note("\n".join(lines)))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var main := Button.new()
	main.name = "Main"
	main.custom_minimum_size = Vector2(0, 42)
	if summary.is_empty():
		main.text = "Create pilot"
		main.pressed.connect(_ask_name.bind(slot, true))
	elif current:
		main.text = "Flying as this pilot"
		main.pressed.connect(SceneLoader.go_to_main_menu)
	else:
		main.text = "Fly as this pilot"
		main.pressed.connect(func() -> void:
			Profile.use_slot(slot)
			_refresh(slot))
	box.add_child(main)
	if not summary.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var rename := Button.new()
		rename.text = "Rename"
		rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename.pressed.connect(_ask_name.bind(slot, false))
		row.add_child(rename)
		var delete := Button.new()
		delete.text = "Delete"
		delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delete.pressed.connect(_ask_delete.bind(slot))
		row.add_child(delete)
	return card


## --- Dialogs ---

func _build_dialogs() -> void:
	_name_dialog = ConfirmationDialog.new()
	_name_dialog.title = "Pilot name"
	_name_edit = LineEdit.new()
	_name_edit.max_length = Profile.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size = Vector2(320, 0)
	_name_edit.text_submitted.connect(func(_text: String) -> void:
		_name_dialog.hide()
		_on_name_confirmed())
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(_name_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete pilot"
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.confirmed.connect(func() -> void:
		Profile.delete_slot(_dialog_slot)
		_refresh())
	add_child(_delete_dialog)


func _ask_name(slot: int, creating: bool) -> void:
	_dialog_slot = slot
	_name_dialog.set_meta("creating", creating)
	_name_dialog.ok_button_text = "Create" if creating else "Rename"
	_name_edit.text = Profile.default_name(slot) if creating else Profile.slot_summary(slot).name
	_name_dialog.popup_centered()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_confirmed() -> void:
	var slot := _dialog_slot
	var typed := Profile.clean_name(_name_edit.text, slot)
	if _name_dialog.get_meta("creating"):
		Profile.use_slot(slot, typed)
	else:
		Profile.rename_slot(slot, typed)
	_refresh(slot)


func _ask_delete(slot: int) -> void:
	_dialog_slot = slot
	var summary := Profile.slot_summary(slot)
	_delete_dialog.dialog_text = tr("Delete %s and all their progress?\nThis can't be undone.") % summary.name
	_delete_dialog.popup_centered()
	_delete_dialog.get_cancel_button().grab_focus()


## --- Helpers ---

func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", NOTE_COLOR)
	return label


func _date(unix_time: int) -> String:
	if unix_time <= 0:
		return "never"
	var date := Time.get_date_dict_from_unix_time(unix_time + _utc_offset())
	return "%d %s %d" % [date.day, tr(MONTHS[date.month - 1]), date.year]


func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60
