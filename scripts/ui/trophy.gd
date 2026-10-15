class_name Trophy
extends RefCounted
## Pokal als Bild (Bronze/Silber/Gold, 0 = noch keiner: blasser Umriss). Gezeichnet statt Sonderzeichen –
## die fehlen in der Web-Schrift. Wird einmal je Stufe und Größe gebaut und wiederverwendet.

static var _cache := {}


static func texture(level: int, px := 64) -> ImageTexture:
	var key := Vector2i(level, px)
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c: Color = Training.MEDAL_COLORS[clampi(level, 0, 3)]
	var ss := 4                                    # Unterabtastung je Richtung (glatte Kanten)
	for y in px:
		for x in px:
			var hit := 0
			var light := 0
			for sy in ss:
				for sx in ss:
					var u := (x + (sx + 0.5) / ss) / px
					var v := (y + (sy + 0.5) / ss) / px
					var k := _shape(u, v)
					if k > 0:
						hit += 1
						if k == 2:
							light += 1
			if hit == 0:
				continue
			var a := float(hit) / (ss * ss)
			var col: Color
			if level <= 0:
				col = Color(1, 1, 1, a * 0.3)
			else:
				col = c.lerp(c.lightened(0.45), float(light) / hit)
				col.a = a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 0 = leer, 1 = Pokal, 2 = Pokal mit Glanz (linke Seite der Schale). u, v in 0..1, v nach unten.
static func _shape(u: float, v: float) -> int:
	var dx := u - 0.5
	# Schale: oben breit, unten rund zulaufend
	if v >= 0.08 and v <= 0.56:
		var t := (v - 0.08) / 0.48
		var hw := 0.06 + 0.21 * sqrt(maxf(0.0, 1.0 - t * t))
		if absf(dx) <= hw:
			return 2 if dx < -hw * 0.35 and dx > -hw * 0.75 and t < 0.75 else 1
	# Rand oben
	if v >= 0.05 and v <= 0.11 and absf(dx) <= 0.29:
		return 1
	# Henkel: Ringe links und rechts neben der Schale
	for side: float in [-1.0, 1.0]:
		var d := Vector2(u - (0.5 + side * 0.25), v - 0.27).length()
		if d >= 0.075 and d <= 0.13 and (u - 0.5) * side > 0.2:
			return 1
	# Stiel
	if v >= 0.55 and v <= 0.74 and absf(dx) <= 0.045 + (v - 0.55) * 0.15:
		return 1
	# Sockel
	if v >= 0.74 and v <= 0.81 and absf(dx) <= 0.17:
		return 1
	if v >= 0.81 and v <= 0.93 and absf(dx) <= 0.25:
		return 1
	return 0
