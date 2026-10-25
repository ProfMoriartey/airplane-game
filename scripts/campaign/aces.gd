class_name Aces
## The enemy aces you can challenge in Ace Duels.

const ACES := [
	{
		id = "hussar", name = "Blue Hussar", stats = preload("res://data/aircraft/ace_hussar.tres"),
		description = "A former cavalry officer who flies like he rides: all dash and daring. His blue-and-gold machine turns tighter than anything in the sky, but it can't take much punishment.",
		taunt = "Blue Hussar: En garde, little bird!", theater = 0, time_of_day = Weather.TimeOfDay.NOON,
	},
	{
		id = "black", name = "Black Knight", stats = preload("res://data/aircraft/ace_black.tres"),
		description = "Flies a fast, all-black fighter and fights at dusk. He dives in from out of the sun, fires once, and climbs away. Never follow him into a long chase.",
		taunt = "Black Knight: You will not even see me coming.", theater = 1, time_of_day = Weather.TimeOfDay.DUSK,
	},
	{
		id = "iron", name = "Iron Baron", stats = preload("res://data/aircraft/ace_iron.tres"),
		description = "A patient, methodical veteran in an armoured grey triplane. Slow to kill and slow to anger. You will need every bullet.",
		taunt = "Iron Baron: Let us see what they teach young pilots these days.", theater = 2, time_of_day = Weather.TimeOfDay.NOON,
	},
	{
		id = "crow", name = "Crimson Crow", stats = preload("res://data/aircraft/enemy_ace.tres"),
		description = "The greatest ace of the war, in his red triplane. A rematch, one on one, with no wingmen to hide behind.",
		taunt = "Crimson Crow: So. Again. This time there will be no luck.", theater = 2, time_of_day = Weather.TimeOfDay.DAWN,
		unlocked_by = "m09",
	},
]


static func is_unlocked(ace: Dictionary) -> bool:
	return not ace.has("unlocked_by") or Profile.is_completed(ace.unlocked_by)
