extends SceneTree
## Balance testing: what each campaign mission throws at the player, how many
## points it can give, and when the player reaches each rank and new aircraft.
##
##   godot --headless --path . -s res://tools/balance/campaign_report.gd
##
## "Threat" weighs enemy fighters by pilot skill (rookie 1, veteran 2, ace 4)
## and adds 1 per anti-aircraft gun. "Typical" assumes a player who completes the
## main objectives, half the bonus objectives and two thirds of the targets.

const SKILL_WEIGHT := [1.0, 2.0, 4.0]
const SKILL_NAMES := ["rookie", "veteran", "ace"]
const AIRCRAFT_SCORE := 100

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_report()
	return false


func _report() -> void:
	var campaign = load("res://data/campaign/campaign.tres")
	var ranks: Array = load("res://scripts/campaign/ranks.gd").RANKS
	var player_aircraft: Array = root.get_node("Profile").PLAYER_AIRCRAFT
	print("")
	print("%-3s %-24s %-26s %3s %6s %4s %5s %6s %7s" % ["#", "mission", "enemy fighters", "AA", "threat", "obj", "bonus", "max", "typical"])
	var number := 0
	var typical_total := 0
	var max_total := 0
	var career: Array = []
	for mission_info in campaign.all_missions():
		number += 1
		var scene: Node = load(mission_info.scene).instantiate()
		var fighters := {}
		var threat := 0.0
		var aa := 0
		var target_score := 0
		var air_score := 0
		for node in scene.find_children("*", "", true, false):
			if _uses(node, "enemy_squadron.gd"):
				var first_wingman := 1 if node.leader_name != "" else 0
				for index in node.count:
					var skill: int = node.skill
					if index == 0 and node.leader_name != "":
						skill = node.leader_skill
					elif index >= first_wingman and index < first_wingman + node.veterans:
						skill = mini(node.skill + 1, 2)
					var label: String = "%s %s" % [SKILL_NAMES[skill], "(%s)" % node.leader_name if index == 0 and node.leader_name != "" else ""]
					fighters[label.strip_edges()] = fighters.get(label.strip_edges(), 0) + 1
					threat += SKILL_WEIGHT[skill]
					air_score += AIRCRAFT_SCORE
			elif _uses(node, "aa_gun.gd"):
				aa += 1
				threat += 1.0
			if _uses(node, "ground_target.gd"):
				target_score += node.score_value
		var main_score := 0
		var bonus_score := 0
		var main := 0
		var bonus := 0
		for objective in scene.find_children("*", "", true, false).filter(func(node: Node) -> bool: return _uses(node, "objective.gd") and not _uses(node, "mission.gd")):
			if objective.optional:
				bonus += 1
				bonus_score += objective.score_bonus
			else:
				main += 1
				main_score += objective.score_bonus
		var best := main_score + bonus_score + target_score + air_score
		var typical := main_score + bonus_score / 2 + (target_score + air_score) * 2 / 3
		max_total += best
		typical_total += typical
		career.append([mission_info.title, typical_total, max_total])
		var fighter_text := ", ".join(fighters.keys().map(func(key: String) -> String: return "%d %s" % [fighters[key], key]))
		print("%-3d %-24s %-26s %3d %6.0f %4d %5d %6d %7d" % [number, mission_info.title, fighter_text, aa, threat, main, bonus, best, typical])
		scene.free()

	print("")
	print("Career points after each mission (typical / best), and the ranks reached:")
	for row in career:
		print("  %-24s %6d  %-18s %6d  %s" % [row[0], row[1], _rank_at(ranks, row[1]), row[2], _rank_at(ranks, row[2])])
	print("")
	print("Aircraft unlocks:")
	for aircraft in player_aircraft:
		var needed: int = ranks[aircraft.unlock_rank].points
		var after := "never (typical)"
		for row in career:
			if row[1] >= needed:
				after = "after %s" % row[0]
				break
		print("  %-8s %-18s %6d points  -> %s" % [aircraft.display_name, ranks[aircraft.unlock_rank].name, needed, after])
	print("(Medals add %d points each on top.)" % load("res://scripts/campaign/medals.gd").MEDAL_POINTS)


## Whether a node's script is (or extends) the script with this file name.
## Checked by file so this tool compiles before the game's classes are loaded.
func _uses(node: Node, file: String) -> bool:
	var script: Script = node.get_script()
	while script:
		if script.resource_path.get_file() == file:
			return true
		script = script.get_base_script()
	return false


func _rank_at(ranks: Array, points: int) -> String:
	var name := ""
	for rank in ranks:
		if points >= rank.points:
			name = rank.name
	return name
