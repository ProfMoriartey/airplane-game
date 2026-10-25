extends Node
## Keys for tracking down graphics glitches on other people's computers: each
## one switches a part of the picture off or on, so a tester can say which
## part the glitch belongs to.
##   F5 clouds   F6 trees   F7 water   F8 glow   F9 anti-aliasing

var _hud: HUD
var _states := {}


func setup(hud: HUD) -> void:
	_hud = hud


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F5:
			_toggle("CLOUDS", _nodes_with_script("clouds.gd"))
		KEY_F6:
			_toggle("TREES", get_tree().get_first_node_in_group("terrain").find_children("*", "MultiMeshInstance3D", false, false))
		KEY_F7:
			_toggle("WATER", _water_meshes())
		KEY_F8:
			var environment: Environment = get_viewport().find_world_3d().environment
			if environment == null:
				environment = get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)[0].environment
			environment.glow_enabled = not environment.glow_enabled
			_report("GLOW", environment.glow_enabled)
		KEY_F9:
			var viewport := get_viewport()
			viewport.msaa_3d = Viewport.MSAA_DISABLED if viewport.msaa_3d != Viewport.MSAA_DISABLED else Settings.quality_value("msaa")
			_report("ANTI-ALIASING", viewport.msaa_3d != Viewport.MSAA_DISABLED)


func _toggle(what: String, nodes: Array) -> void:
	var on: bool = not _states.get(what, true)
	_states[what] = on
	for node in nodes:
		node.visible = on
	_report(what, on)


func _report(what: String, on: bool) -> void:
	var text := "TEST: %s %s" % [what, "ON" if on else "OFF"]
	print(text)
	if _hud:
		_hud.flash_banner(text)


func _nodes_with_script(file: String) -> Array:
	return get_tree().current_scene.find_children("*", "", true, false).filter(func(node: Node) -> bool:
		return node.get_script() != null and node.get_script().resource_path.get_file() == file)


func _water_meshes() -> Array:
	return get_tree().get_first_node_in_group("terrain").find_children("*", "MeshInstance3D", false, false).filter(func(mesh: MeshInstance3D) -> bool:
		var material := mesh.material_override if mesh.material_override else mesh.get_active_material(0)
		return material is ShaderMaterial and material.shader.resource_path.get_file() == "water.gdshader")
