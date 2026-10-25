extends SceneTree
## Builds the app icons from icon.svg: a Windows .ico (several sizes in one
## file) and a 1024 px PNG that the Mac export turns into its icon.
##
##   godot --headless --path . -s res://tools/make_icons.gd

const SOURCE := "res://icon.svg"
const ICO_PATH := "res://assets/icons/icon.ico"
const MAC_PATH := "res://assets/icons/icon_1024.png"
const ICO_SIZES := [16, 24, 32, 48, 64, 128, 256]
## The size icon.svg is drawn at.
const SVG_SIZE := 256.0


func _init() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	_render(svg, 1024).save_png(MAC_PATH)
	var images: Array[PackedByteArray] = []
	for size in ICO_SIZES:
		images.append(_render(svg, size).save_png_to_buffer())
	_write_ico(images)
	print("Wrote %s and %s" % [ICO_PATH, MAC_PATH])
	quit()


func _render(svg: String, size: int) -> Image:
	var image := Image.new()
	image.load_svg_from_string(svg, size / SVG_SIZE)
	return image


## An .ico file is a small directory of images; modern ones can hold PNGs.
func _write_ico(images: Array[PackedByteArray]) -> void:
	var file := FileAccess.open(ICO_PATH, FileAccess.WRITE)
	file.store_16(0)  # Reserved.
	file.store_16(1)  # 1 = icon.
	file.store_16(images.size())
	var offset := 6 + 16 * images.size()
	for index in images.size():
		var size: int = ICO_SIZES[index]
		file.store_8(size % 256)  # Width and height; 0 means 256.
		file.store_8(size % 256)
		file.store_8(0)  # No palette.
		file.store_8(0)  # Reserved.
		file.store_16(1)  # Colour planes.
		file.store_16(32)  # Bits per pixel.
		file.store_32(images[index].size())
		file.store_32(offset)
		offset += images[index].size()
	for data in images:
		file.store_buffer(data)
