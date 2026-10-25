extends CanvasLayer
## The old-film vignette and grain, shown only if the player has it switched on.


func _ready() -> void:
	Settings.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = Settings.film_grain
