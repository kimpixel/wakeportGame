class_name Spray
extends RefCounted
## "Tropfen": Optik aller Spritz-Partikel (Kante, Landung, Drift-Press, Hecht, Boot). Jeder Tropfen ist ein
## weiches Wolken-Sprite (zeigt zur Kamera, durch Rauschen ausgefranst, zufällig gedreht), weich ausgeblendet
## an der Wasseroberfläche (Proximity Fade), mit Verlauf über die Lebenszeit (wächst, wird durchsichtig und
## graublau). Die Textur erzeugt das Spiel selbst. Der zusammenhängende Gischt-Vorhang ist SpraySheet.

static var _mat: StandardMaterial3D


## Emitter auf die Tropfen-Optik umstellen. Die Größe kommt vom Kugel-Mesh, das der Emitter mitbringt.
static func register(p: CPUParticles3D) -> void:
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
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat.roughness = 0.6
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# weiches Ausblenden, wo das Sprite die Wasseroberfläche oder ein Feature schneidet
	_mat.proximity_fade_enabled = true
	_mat.proximity_fade_distance = 0.3
	_mat.emission_enabled = true
	_mat.emission = Color(0.25, 0.28, 0.3)     # etwas Eigenhelligkeit: Gischt leuchtet im Licht leicht
	_mat.emission_energy_multiplier = 0.4
	return _mat


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
