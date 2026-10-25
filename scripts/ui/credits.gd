extends Control
## Credits, followed by the licence notices for the Godot Engine and the
## third-party code built into it, which must ship with the game.

const SCROLL_SPEED := 30.0

var _scroll_position := 0.0


func _ready() -> void:
	%BackButton.pressed.connect(SceneLoader.go_to_main_menu)
	%BackButton.grab_focus()
	var lines: PackedStringArray = [
		"[center][b]%s[/b][/center]" % ProjectSettings.get_setting("application/config/name").to_upper(),
		"",
		"[center][b]Design, programming and art[/b]\nChrollo[/center]",
		"",
		"[center][b]Sound effects and music[/b]\nSynthesised in-house - no recorded samples[/center]",
		"",
		"[center][b]Aircraft, vehicles and landscapes[/b]\nBuilt procedurally in code[/center]",
		"",
		"[center][b]Made with the Godot Engine[/b]\ngodotengine.org[/center]",
		"",
		"",
		"[b]Godot Engine licence[/b]",
		Engine.get_license_text(),
		"",
		"[b]Third-party components in the Godot Engine[/b]",
	]
	for component in Engine.get_copyright_info():
		for part: Dictionary in component.parts:
			lines.append("%s - %s" % [component.name, part.license])
			for holder: String in part.copyright:
				lines.append("    (c) %s" % holder)
	%Text.text = "\n".join(lines)


func _process(delta: float) -> void:
	# Roll the credits slowly, like a film.
	_scroll_position += SCROLL_SPEED * delta
	%Scroll.scroll_vertical = int(_scroll_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.go_to_main_menu()
