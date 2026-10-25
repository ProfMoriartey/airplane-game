class_name CampaignData
extends Resource
## The whole campaign: theaters in order, each with missions in order.
## Missions unlock one after another, straight through all theaters.

@export var theaters: Array[TheaterInfo] = []


func all_missions() -> Array[MissionInfo]:
	var missions: Array[MissionInfo] = []
	for theater in theaters:
		missions.append_array(theater.missions)
	return missions


func find(id: String) -> MissionInfo:
	for mission in all_missions():
		if mission.id == id:
			return mission
	return null


## The mission after this one, or null for the last mission.
func next_after(id: String) -> MissionInfo:
	var missions := all_missions()
	for index in missions.size() - 1:
		if missions[index].id == id:
			return missions[index + 1]
	return null


## The mission before this one, or null for the first mission.
func previous_of(id: String) -> MissionInfo:
	var missions := all_missions()
	for index in range(1, missions.size()):
		if missions[index].id == id:
			return missions[index - 1]
	return null


func theater_index_of(id: String) -> int:
	for index in theaters.size():
		for mission in theaters[index].missions:
			if mission.id == id:
				return index
	return -1
