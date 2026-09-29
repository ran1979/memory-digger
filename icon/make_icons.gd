extends SceneTree
# Run: godot --headless --path . -s icon/make_icons.gd
# Rasterize icon/*.svg into the PNGs Android export wants, plus a composited 192px legacy icon.


func _svg(path: String, scale: float) -> Image:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(path), scale)
	return img


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://icon/")
	_svg(dir + "foreground.svg", 1.0).save_png(dir + "foreground_432.png")
	_svg(dir + "background.svg", 1.0).save_png(dir + "background_432.png")
	# Legacy icon: background + foreground zoomed 1.3x (no adaptive mask cropping it).
	var icon := _svg(dir + "background.svg", 192.0 / 432.0)
	var fg := _svg(dir + "foreground.svg", 192.0 * 1.3 / 432.0)
	var off := (fg.get_width() - 192) / 2
	icon.blend_rect(fg, Rect2i(off, off, 192, 192), Vector2i.ZERO)
	icon.save_png(dir + "icon_192.png")
	print("icons ", icon.get_size(), " ", fg.get_size())
	quit()
