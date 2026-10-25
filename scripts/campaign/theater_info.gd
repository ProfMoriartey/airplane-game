class_name TheaterInfo
extends Resource
## A region of the war: a chapter of the campaign with its own missions.

@export var title := ""
@export_multiline var intro := ""
@export var missions: Array[MissionInfo] = []
