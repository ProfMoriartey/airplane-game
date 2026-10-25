extends CanvasLayer
## The results screen shown when a mission ends.

signal retry_pressed

const SUCCESS_COLOR := Color(0.55, 0.9, 0.5)
const FAILURE_COLOR := Color(1.0, 0.45, 0.35)


func _ready() -> void:
	%RetryButton.pressed.connect(func() -> void: retry_pressed.emit())
	%MenuButton.pressed.connect(SceneLoader.go_to_main_menu)


## stats is a list of [label, value] pairs.
func setup(success: bool, reason: String, stats: Array) -> void:
	%Result.text = "MISSION COMPLETE" if success else "MISSION FAILED"
	%Result.add_theme_color_override("font_color", SUCCESS_COLOR if success else FAILURE_COLOR)
	%Reason.text = reason
	%Reason.visible = reason != ""

	for row: Array in stats:
		var name_label := Label.new()
		name_label.text = row[0]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.text = str(row[1])
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		%Stats.add_child(name_label)
		%Stats.add_child(value_label)

	%RetryButton.text = "Fly again" if success else "Retry"
	%RetryButton.grab_focus()
