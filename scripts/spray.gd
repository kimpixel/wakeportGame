class_name Spray
extends RefCounted
## Gischt-Optik für alle Spritz-Partikel (Kante, Drift-Press, Hecht, Boot). Zwei Stile, umschaltbar
## (Einstellungen -> Wasser -> Gischt): die bisherigen 3D-Kugeln oder weiche Sprites wie in modernen
## Spielen – flache Bilder, die zur Kamera zeigen, mit ausfransendem Rand, weichem Ausblenden an der
## Wasseroberfläche (Proximity Fade) und Verlauf über die Lebenszeit (wachsen, durchsichtig werden,
## vom Weiß ins Graublau). Dazu eine Nebel-Ebene: große, langsame Sprites, die kurz stehen bleiben.
## Die Texturen erzeugt das Spiel selbst (Rauschen × runder Verlauf), es braucht keine Dateien.

enum Kind { DROP, MIST }

static var sprites := true          # false = 3D-Kugeln (bisher)
static var _emitters: Array = []    # [CPUParticles3D, Kind, Kugel-Mesh, material_override]
static var _tex := {}               # Kind -> ImageTexture
static var _mats := {}


## Emitter anmelden: merkt sich die Kugel-Optik und stellt auf den aktuellen Stil.
static func register(p: CPUParticles3D, kind := Kind.DROP) -> void:
	_emitters.append([p, kind, p.mesh, p.material_override])
	_apply(p, kind, p.mesh, p.material_override)


## Stil umschalten (wirkt sofort auf alle Emitter).
static func set_sprites(on: bool) -> void:
	sprites = on
	var keep: Array = []
	for e: Array in _emitters:
		if is_instance_valid(e[0]):
			_apply(e[0], e[1], e[2], e[3])
			keep.append(e)
	_emitters = keep


## Nebel-Emitter (nur im Sprite-Stil sichtbar): große weiche Wolken, die langsam aufsteigen und vergehen.
static func make_mist(parent: Node, amount := 24) -> CPUParticles3D:
	var m := CPUParticles3D.new()
	m.amount = amount
	m.lifetime = 1.6
	m.local_coords = false
	m.top_level = true
	m.emitting = false
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25
	m.direction = Vector3.UP
	m.spread = 60.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.7
	m.gravity = Vector3(0.0, 0.15, 0.0)
	m.damping_min = 0.6
	m.damping_max = 1.2
	m.scale_amount_min = 0.8
	m.scale_amount_max = 1.6
	m.angle_min = 0.0
	m.angle_max = 360.0
	parent.add_child(m)
	register(m, Kind.MIST)
	return m


static func _apply(p: CPUParticles3D, kind: Kind, sphere: Mesh, override: Material) -> void:
	if not sprites:
		p.mesh = sphere
		p.material_override = override
		p.color_ramp = null
		p.scale_amount_curve = null
		p.visible = kind != Kind.MIST
		return
	p.visible = true
	var q := QuadMesh.new()
	var r := 0.05
	if sphere is SphereMesh:
		r = (sphere as SphereMesh).radius
	q.size = Vector2.ONE * (r * 4.5 if kind == Kind.DROP else 0.9)
	q.material = _material(kind)
	p.mesh = q
	p.material_override = null
	p.angle_min = 0.0
	p.angle_max = 360.0
	# Verlauf: Tropfen fast weiß und deckend, dann durchsichtig und graublau; Nebel zart
	var g := Gradient.new()
	if kind == Kind.DROP:
		g.set_color(0, Color(1.0, 1.0, 1.0, 0.95))
		g.set_color(1, Color(0.75, 0.82, 0.88, 0.0))
		g.add_point(0.55, Color(0.92, 0.95, 0.98, 0.7))
	else:
		g.set_color(0, Color(0.95, 0.97, 1.0, 0.0))
		g.set_color(1, Color(0.8, 0.86, 0.92, 0.0))
		g.add_point(0.15, Color(0.95, 0.97, 1.0, 0.32))
		g.add_point(0.6, Color(0.88, 0.92, 0.96, 0.18))
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.55 if kind == Kind.DROP else 0.4))
	c.add_point(Vector2(1.0, 1.0 if kind == Kind.DROP else 1.8))
	c.max_value = 2.0
	p.scale_amount_curve = c


static func _material(kind: Kind) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _texture(kind)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 10                    # nach dem (transparenten) Wasser zeichnen, sonst deckt es die Gischt zu
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 0.6
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.disable_receive_shadows = false
	# weiches Ausblenden, wo das Sprite die Wasseroberfläche oder ein Feature schneidet
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.25 if kind == Kind.DROP else 0.6
	m.emission_enabled = true
	m.emission = Color(0.25, 0.28, 0.3)       # etwas Eigenhelligkeit: Gischt leuchtet im Licht leicht
	m.emission_energy_multiplier = 0.4
	_mats[kind] = m
	return m


## Textur: runder weicher Fleck, durch Rauschen ausgefranst. Tropfen: kleiner Kern mit Spritzern drum
## herum, Nebel: große wolkige Fläche.
static func _texture(kind: Kind) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	var size := 64
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nz.frequency = 0.09 if kind == Kind.DROP else 0.05
	nz.fractal_octaves = 3
	nz.seed = 7 if kind == Kind.DROP else 19
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			var n := nz.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float
			if kind == Kind.DROP:
				# weicher Kern, Rand vom Rauschen ausgefranst (kein Sternchen)
				var edge := 0.45 + 0.35 * n
				a = clampf((1.0 - smoothstep(edge * 0.35, edge, d)) * (0.75 + 0.25 * n), 0.0, 1.0)
			else:
				a = clampf((1.0 - smoothstep(0.2, 1.0, d)) * (0.35 + 0.65 * n), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t
