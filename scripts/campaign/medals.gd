class_name Medals
## Medals the pilot can earn, and the rules for earning them.

## Career points awarded with each medal.
const MEDAL_POINTS := 300

const MEDALS := [
	{id = "first_victory", name = "Flying Cross", description = "Shoot down your first enemy aircraft."},
	{id = "ace", name = "Ace Badge", description = "Shoot down 5 enemy aircraft in total."},
	{id = "double_ace", name = "Golden Wings", description = "Shoot down 15 enemy aircraft in total."},
	{id = "balloon_buster", name = "Balloon Buster", description = "Destroy 5 observation balloons in total."},
	{id = "ground_attack", name = "Ground Attack Clasp", description = "Destroy 25 ground targets in total."},
	{id = "untouchable", name = "Untouchable", description = "Complete a mission without taking any damage."},
	{id = "thorough", name = "Mention in Dispatches", description = "Complete every bonus objective in a mission."},
	{id = "sharpshooter", name = "Marksman Medal", description = "Complete a mission with at least 35% gun accuracy (50+ shots)."},
	{id = "theater_1", name = "Quiet Sector Ribbon", description = "Complete every mission in The Quiet Sector."},
	{id = "theater_2", name = "Mud and Wire Ribbon", description = "Complete every mission in Mud and Wire."},
	{id = "theater_3", name = "High Passes Ribbon", description = "Complete every mission in The High Passes."},
	{id = "nemesis", name = "Order of the Crow", description = "Shoot down the Crimson Crow."},
]


static func find(id: String) -> Dictionary:
	for medal in MEDALS:
		if medal.id == id:
			return medal
	return {}


## Which medal ids this mission result earns, given the career totals
## (which already include this mission). Medals already owned are left out.
static func evaluate(totals: Dictionary, result: Dictionary, theaters_complete: Array, owned: Array) -> Array[String]:
	var earned: Array[String] = []
	var checks := {
		first_victory = totals.air_kills >= 1,
		ace = totals.air_kills >= 5,
		double_ace = totals.air_kills >= 15,
		balloon_buster = totals.balloons >= 5,
		ground_attack = totals.ground_kills >= 25,
		untouchable = result.success and result.damage_taken == 0.0,
		thorough = result.success and result.bonus_total > 0 and result.bonus_done == result.bonus_total,
		sharpshooter = result.success and result.shots >= 50 and float(result.hits) / result.shots >= 0.35,
		theater_1 = theaters_complete.has(0),
		theater_2 = theaters_complete.has(1),
		theater_3 = theaters_complete.has(2),
		nemesis = result.get("aces_downed", []).has("Crimson Crow"),
	}
	for id: String in checks:
		if checks[id] and not owned.has(id):
			earned.append(id)
	return earned
