extends Control
## The title card shown when the game starts. Any key skips it.

const MENU := "res://scenes/ui/menu.tscn"
const FADE_TIME := 0.8
const HOLD_TIME := 1.6

var _leaving := false


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(%Box, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(%Box, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_leave)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	SceneLoader.change_scene(MENU)
