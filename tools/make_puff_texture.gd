extends SceneTree
## Builds assets/textures/soft_puff.tres: the soft round blob used by clouds,
## smoke, dust, splashes, explosions and muzzle flashes.
##
##   godot --headless --path . -s res://tools/make_puff_texture.gd
##
## It must include mipmaps (smaller copies for things far away). Without them,
## some Windows graphics drivers read garbage for distant clouds and smoke,
## which shows up as flickering coloured dots blown up into white blobs.

const PATH := "res://assets/textures/soft_puff.tres"
## Kept the same so the editor still knows it as the file scenes already use.
const UID := "uid://crroybalfcnde"
const SIZE := 128
## Opacity from the centre (0) to the edge (1) of the blob.
const FALLOFF := [[0.0, 1.0], [0.5, 0.6], [1.0, 0.0]]


func _init() -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var distance := (Vector2(x + 0.5, y + 0.5) - center).length() / (SIZE * 0.5)
			image.set_pixel(x, y, Color(1, 1, 1, _opacity(distance)))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var error := ResourceSaver.save(texture, PATH)
	ResourceSaver.set_uid(PATH, ResourceUID.text_to_id(UID))
	print("Saved %s with %d mipmap levels (error %d)" % [PATH, image.get_mipmap_count(), error])
	quit()


func _opacity(distance: float) -> float:
	for index in range(1, FALLOFF.size()):
		var from: Array = FALLOFF[index - 1]
		var to: Array = FALLOFF[index]
		if distance <= to[0]:
			return lerpf(from[1], to[1], inverse_lerp(from[0], to[0], distance))
	return 0.0
