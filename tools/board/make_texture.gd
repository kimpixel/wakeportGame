extends SceneTree
## Schneidet aus einem Produktfoto (drei Ansichten nebeneinander: oben, unten, Seite)
## die Brett-Unterseite aus und speichert sie als Textur:
##   godot --headless --path . --script tools/board/make_texture.gd -- <foto.png> <ansicht 0|1|2> <ausgabe.png>
## Hintergrund (fast weiß) wird transparent; das Brett wird auf seine Umrisse zugeschnitten.
## Ausgabe nach assets/board/top.png bzw. bottom.png (Ansicht 0 = oben, 1 = unten).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var view := args[1].to_int()
	var w := img.get_width()
	var h := img.get_height()
	# Spalten mit Brett-Pixeln finden und in zusammenhängende Bereiche (Ansichten) teilen
	var cols: Array[bool] = []
	for x in w:
		var n := 0
		for y in range(0, h, 2):
			if not _is_bg(img.get_pixel(x, y)):
				n += 1
		cols.append(n > h / 20)
	var spans: Array[Vector2i] = []
	var start := -1
	for x in w + 1:
		var on := x < w and cols[x]
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			if x - start > 8:
				spans.append(Vector2i(start, x - 1))
			start = -1
	print("Ansichten (Spalten): ", spans)
	var sx := spans[view]
	# Zeilen innerhalb der Ansicht
	var y0 := h
	var y1 := 0
	for y in h:
		for x in range(sx.x, sx.y + 1, 2):
			if not _is_bg(img.get_pixel(x, y)):
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
				break
	var crop := img.get_region(Rect2i(sx.x, y0, sx.y - sx.x + 1, y1 - y0 + 1))
	print("Ausschnitt: x ", sx, " y ", Vector2i(y0, y1), " -> ", crop.get_size())
	for y in crop.get_height():
		for x in crop.get_width():
			var c := crop.get_pixel(x, y)
			if _is_bg(c):
				crop.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	crop.resize(256, 1024, Image.INTERPOLATE_LANCZOS)
	crop.save_png(args[2])
	print("gespeichert: ", args[2])
	quit()


func _is_bg(c: Color) -> bool:
	return c.r > 0.96 and c.g > 0.96 and c.b > 0.96
