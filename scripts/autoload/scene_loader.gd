extends CanvasLayer
## Switches between scenes (menu, levels) behind a loading screen.
## The next scene loads in the background so the game doesn't freeze.

const MAIN_MENU := "res://scenes/ui/menu.tscn"

var _loading_path := ""
var _progress: ProgressBar


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_screen()


func change_scene(path: String) -> void:
	if _loading_path != "":
		return
	get_tree().paused = false
	_loading_path = path
	_progress.value = 0.0
	visible = true
	ResourceLoader.load_threaded_request(path)


func reload() -> void:
	change_scene(get_tree().current_scene.scene_file_path)


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU)


func _process(_delta: float) -> void:
	if _loading_path == "":
		return
	var progress := []
	match ResourceLoader.load_threaded_get_status(_loading_path, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_progress.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
			_loading_path = ""
			get_tree().change_scene_to_packed(scene)
			visible = false
		_:
			push_error("Could not load scene: %s" % _loading_path)
			_loading_path = ""
			visible = false


func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(400, 0)
	box.position = Vector2(-200, -30)
	box.add_theme_constant_override("separation", 12)
	background.add_child(box)

	var label := Label.new()
	label.text = "LOADING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	box.add_child(label)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(400, 16)
	_progress.show_percentage = false
	box.add_child(_progress)
