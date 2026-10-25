class_name MissionInfo
extends Resource
## One mission's entry in the campaign.

## Stable name used in the save file. Don't change it once players have saves.
@export var id := ""
@export var title := ""
@export_multiline var summary := ""
@export_file("*.tscn") var scene := ""
