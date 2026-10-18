class_name Spray
extends RefCounted
## "Tropfen": Optik aller Spritz-Partikel (Kante, Landung, Drift-Press, Hecht, Boot). Jeder Tropfen ist ein
## weiches Wolken-Sprite (zeigt zur Kamera, durch Rauschen ausgefranst, zufällig gedreht), weich ausgeblendet
## an der Wasseroberfläche (Proximity Fade), mit Verlauf über die Lebenszeit (wächst, wird durchsichtig und
## graublau). Die Textur erzeugt das Spiel selbst. Der zusammenhängende Gischt-Vorhang ist SpraySheet.

static var _mat: StandardMaterial3D
## Grafikstufe (Niedrig, Mittel, Hoch): Anteil der Tropfen, gesetzt in main.gd _apply_quality
static var quality := 2
const AMOUNT_Q := [0.35, 0.6, 1.0]
static var _emitters: Array[WeakRef] = []


## Grafikstufe 0..2: weniger Tropfen, einfachere Beleuchtung; weiches Ausblenden am Wasser (Proximity Fade)
## braucht die Szenentiefe – im Browser eine zusätzliche Tiefenkopie je Bild, darum nur auf Hoch.
static func set_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	if _mat:
		_mat_quality()
	var alive: Array[WeakRef] = []
	for w: WeakRef in _emitters:
		var p := w.get_ref() as CPUParticles3D
		if p:
			_set_amount(p)
			alive.append(w)
	_emitters = alive


static func _set_amount(p: CPUParticles3D) -> void:
	var n := maxi(int(round(int(p.get_meta("spray_amount")) * AMOUNT_Q[quality])), 4)
	if p.amount != n:
		p.amount = n


## Emitter auf die Tropfen-Optik umstellen. Die Größe kommt vom Kugel-Mesh, das der Emitter mitbringt.
static func register(p: CPUParticles3D) -> void:
	p.set_meta("spray_amount", p.amount)     # volle Menge (Hoch); einmal je Emitter aufrufen
	_emitters.append(weakref(p))
	_set_amount(p)
	var r := 0.05
	if p.mesh is SphereMesh:
		r = (p.mesh as SphereMesh).radius
	var q := QuadMesh.new()
	q.size = Vector2.ONE * r * 4.0
	q.material = _material()
	p.mesh = q
	p.material_override = null
	p.angle_min = 0.0
	p.angle_max = 360.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 0.55))
	g.set_color(1, Color(0.78, 0.84, 0.9, 0.0))
	g.add_point(0.5, Color(0.93, 0.96, 0.98, 0.3))
	p.color_ramp = g
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0.0, 0.3))     # klein anfangen
	c.add_point(Vector2(1.0, 2.5))     # groß und durchsichtig am Ende
	p.scale_amount_curve = c


static func _material() -> StandardMaterial3D:
	if _mat:
		return _mat
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.billboard_keep_scale = true
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = _texture()
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 10                  # nach dem (transparenten) Wasser zeichnen, sonst deckt es die Tropfen zu
	_mat.roughness = 0.6
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# weiches Ausblenden, wo das Sprite die Wasseroberfläche oder ein Feature schneidet (nur Hoch, set_quality)
	_mat.proximity_fade_distance = 0.3
	_mat.emission_enabled = true
	_mat.emission = Color(0.25, 0.28, 0.3)     # etwas Eigenhelligkeit: Gischt leuchtet im Licht leicht
	_mat.emission_energy_multiplier = 0.4 * Weather.lum
	_mat_quality()
	return _mat


## Eigenhelligkeit mit dem Tageslicht (sonst leuchten die Tropfen nachts), aus Weather.apply.
static func set_light(l: float) -> void:
	if _mat:
		_mat.emission_energy_multiplier = 0.4 * l


static func _mat_quality() -> void:
	_mat.proximity_fade_enabled = quality >= 2
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if quality >= 2 else BaseMaterial3D.SHADING_MODE_PER_VERTEX


## Textur: runder weicher Fleck, durch Rauschen wolkig ausgefranst.
static func _texture() -> ImageTexture:
	var size := 64
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nz.frequency = 0.05
	nz.fractal_octaves = 3
	nz.seed = 19
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			var n := nz.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - smoothstep(0.2, 1.0, d)) * (0.35 + 0.65 * n), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
