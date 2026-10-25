class_name Ranks
## The pilot's ranks and the career points needed for each.

const RANKS := [
	{name = "Corporal", points = 0},
	{name = "Sergeant", points = 1500},
	{name = "Second Lieutenant", points = 3500},
	{name = "Lieutenant", points = 6000},
	{name = "Captain", points = 9000},
	{name = "Major", points = 12000},
	{name = "Lieutenant Colonel", points = 15000},
	{name = "Colonel", points = 18000},
]


static func rank_for(points: int) -> int:
	var rank := 0
	for index in RANKS.size():
		if points >= RANKS[index].points:
			rank = index
	return rank


static func name_of(rank: int) -> String:
	return RANKS[rank].name


## Points needed for the next rank, or -1 at the top rank.
static func next_threshold(rank: int) -> int:
	return RANKS[rank + 1].points if rank + 1 < RANKS.size() else -1
