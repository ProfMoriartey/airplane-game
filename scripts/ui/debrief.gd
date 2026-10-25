extends CanvasLayer
## The results screen shown when a mission ends, with the career changes it caused.

signal retry_pressed

const CAMPAIGN_SCREEN := "res://scenes/ui/campaign_screen.tscn"
const SUCCESS_COLOR := Color(0.55, 0.9, 0.5)
const FAILURE_COLOR := Color(1.0, 0.45, 0.35)


func _ready() -> void:
	%RetryButton.pressed.connect(func() -> void: retry_pressed.emit())
	%CampaignButton.pressed.connect(SceneLoader.change_scene.bind(CAMPAIGN_SCREEN))


## stats is a list of [label, value] pairs. career is what Profile.record_mission()
## returned (empty outside the campaign). next_mission is offered as the next step.
func setup(success: bool, reason: String, stats: Array, career: Dictionary, next_mission: MissionInfo) -> void:
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

	%Career.visible = not career.is_empty()
	if not career.is_empty():
		%CareerText.text = _describe_career(success, career)

	%NextButton.visible = next_mission != null
	if next_mission:
		%NextButton.pressed.connect(SceneLoader.change_scene.bind(next_mission.scene))
		%NextButton.grab_focus()
	else:
		%RetryButton.grab_focus()
	%RetryButton.text = "Fly again" if success else "Retry"


func _describe_career(success: bool, career: Dictionary) -> String:
	var lines: PackedStringArray = []
	var gained: int = career.points_after - career.points_before
	if gained > 0:
		lines.append("+%d career points  (%d total)" % [gained, career.points_after])
	elif success:
		lines.append("No new points - beat your best score to earn more.")
	else:
		lines.append("Complete the mission to earn career points.")

	if career.rank_after > career.rank_before:
		lines.append("")
		lines.append("PROMOTED to %s!" % Ranks.name_of(career.rank_after))
	else:
		lines.append("Rank: %s" % Ranks.name_of(career.rank_after))
		var next := Ranks.next_threshold(career.rank_after)
		if next > 0:
			lines.append("%d points to %s" % [next - career.points_after, Ranks.name_of(career.rank_after + 1)])

	for id: String in career.new_medals:
		lines.append("")
		lines.append("MEDAL: %s" % Medals.find(id).name)
		lines.append(Medals.find(id).description)

	for aircraft: AircraftStats in career.new_aircraft:
		lines.append("")
		lines.append("NEW AIRCRAFT: %s" % aircraft.display_name)
	return "\n".join(lines)
