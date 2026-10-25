class_name PadMenus
extends Node
## Makes every menu work with a controller: scroll areas follow the highlighted
## button, and the right stick (or Page Up / Down) scrolls long text.

## Pixels per second at full stick.
const SCROLL_SPEED := 900.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is ScrollContainer:
		# Moving the highlight off-screen scrolls it back into view.
		node.follow_focus = true


func _process(delta: float) -> void:
	var amount := Input.get_axis("ui_scroll_up", "ui_scroll_down")
	# No highlighted button means no menu is open (in flight the right stick looks around).
	var focus := get_viewport().gui_get_focus_owner()
	if amount == 0.0 or not focus:
		return
	var scroll := _scroll_target(focus)
	if scroll:
		scroll.scroll_vertical += int(amount * SCROLL_SPEED * delta)


## The scroll area to move: the one holding the highlighted button, or else
## the visible one closest to it (like the credits, whose Back button sits below).
func _scroll_target(focus: Control) -> ScrollContainer:
	var best: ScrollContainer
	var best_depth := -1
	for node in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if not scroll.is_visible_in_tree() or scroll.get_v_scroll_bar().max_value <= scroll.size.y:
			continue
		if scroll.is_ancestor_of(focus):
			return scroll
		var depth := _shared_depth(scroll, focus)
		if depth > best_depth:
			best = scroll
			best_depth = depth
	return best


## How deep in the tree two nodes' closest shared parent is.
func _shared_depth(a: Node, b: Node) -> int:
	var parent := a
	while parent and not parent.is_ancestor_of(b):
		parent = parent.get_parent()
	var depth := 0
	while parent:
		depth += 1
		parent = parent.get_parent()
	return depth
