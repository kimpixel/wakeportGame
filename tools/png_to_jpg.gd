extends SceneTree
## PNG -> JPG (Luftbilder aus tools/park_geo.mjs), PNG danach gelöscht.
##   Godot --headless --path . -s tools/png_to_jpg.gd -- parks/<id>/geo


func _init() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".png"):
			continue
		var img := Image.load_from_file(dir.path_join(f))
		var out := dir.path_join(f.get_basename() + ".jpg")
		img.save_jpg(out, 0.88)
		DirAccess.remove_absolute(dir.path_join(f))
		print("JPG: ", out, " ", img.get_size())
	quit()
