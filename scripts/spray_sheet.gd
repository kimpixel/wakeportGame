class_name SpraySheet
extends MeshInstance3D
## "Wasserwand": Gischt-Vorhang beim Schneiden (nach Fotos vom Wakeport): kein Partikelhaufen, sondern eine
## zusammenhängende, dünne Wasserwand. Die Kante gibt laufend Wasser ab ("Scheiben"); jede Scheibe
## bleibt, wo sie die Kante verlassen hat, und fliegt ballistisch: flach von der Kante weg, im Bogen
## hoch, weit hinter dem Fahrer zurück ins Wasser. Jedes Bild wird aus allen Scheiben ein Band
## aufgespannt (Zeilen = flache bis steilste Flugbahn), fein gestreift in Flugrichtung, durchscheinend,
## oben und zum Ende ausgefranst. Höhe und Weite kommen vom Kantendruck (strength 0..1).

const LIFE := 1.25              # s, so lange fliegt das Wasser (Länge des Vorhangs)
const EMIT_DT := 0.025          # s zwischen zwei Scheiben
const ROWS := 9                 # Zeilen von der flachsten zur steilsten Flugbahn
## Form (live regelbar im Debug-Overlay F4, Reiter "Wasserwand")
static var WALL_BASE := 1.1        # m: so lang ist der Ansatz an der Kante (Teil des Bretts im Wasser)
static var WALL_SPEED_MIN := 2.5   # m/s Abwurf bei wenig Kantendruck
static var WALL_SPEED_MAX := 7.5   # m/s bei vollem Druck (ca. 2,5 m hoch, 2,5 m weit)
static var WALL_ANG_LOW := 0.22    # rad: flachste Bahn (weit zur Seite)
static var WALL_ANG_HIGH := 1.4    # rad: steilste Bahn (hoch, kippt über wie eine Tube)
const GRAVITY := 9.8

var water: Water
var _slices: Array = []         # [Startpunkt, Seite, Steigen, seitlich, Zeit, Stärke]
var _t := 0.0
var _emit_acc := 0.0
var _mesh := ImmediateMesh.new()
static var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 20.0


## Jedes Bild: Kantenmitte (Welt), Seite, zu der das Wasser fliegt, Brettachse (entlang der Kante),
## Stärke 0..1, aktiv?
func feed(at: Vector3, side: Vector3, strength: float, active: bool, delta: float, axis := Vector3.ZERO) -> void:
	_t += delta
	if active:
		_emit_acc += delta
		while _emit_acc >= EMIT_DT:
			_emit_acc -= EMIT_DT
			var speed := lerpf(WALL_SPEED_MIN, WALL_SPEED_MAX, strength)
			_slices.append([at, side, axis, speed, _t, strength])
	else:
		_emit_acc = 0.0
	while not _slices.is_empty() and _t - float(_slices[0][4]) > LIFE:
		_slices.pop_front()
	_build()


func clear() -> void:
	_slices.clear()
	_mesh.clear_surfaces()


func _point(s: Array, f: float, age: float) -> Vector3:
	# Ansatz über die ganze Kante verteilt (unten breit), Abwurf als Fächer von flach-seitlich bis steil:
	# gleich schnell in alle Winkel -> die Wand bildet einen runden Bogen, der überkippt (wie eine Tube)
	var side: Vector3 = s[1]
	var p0: Vector3 = s[0] + (s[2] as Vector3) * (f - 0.5) * WALL_BASE
	var ang := lerpf(WALL_ANG_LOW, WALL_ANG_HIGH, f)
	var v := (side * cos(ang) + Vector3.UP * sin(ang)) * float(s[3])
	var p := p0 + v * age + Vector3.DOWN * 0.5 * GRAVITY * age * age
	var wy := water.height_at(p.x, p.z) if water else 0.0
	p.y = maxf(p.y, wy + 0.02)
	return p


func _build() -> void:
	_mesh.clear_surfaces()
	var n := _slices.size()
	if n < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material())
	for i in n - 1:
		var a: Array = _slices[i]
		var b: Array = _slices[i + 1]
		var age_a := _t - float(a[4])
		var age_b := _t - float(b[4])
		for r in ROWS - 1:
			var f0 := float(r) / (ROWS - 1)
			var f1 := float(r + 1) / (ROWS - 1)
			var quad := [
				[_point(a, f0, age_a), Vector2(float(a[4]) * 1.3, f0), _alpha(a, age_a, f0)],
				[_point(b, f0, age_b), Vector2(float(b[4]) * 1.3, f0), _alpha(b, age_b, f0)],
				[_point(b, f1, age_b), Vector2(float(b[4]) * 1.3, f1), _alpha(b, age_b, f1)],
				[_point(a, f1, age_a), Vector2(float(a[4]) * 1.3, f1), _alpha(a, age_a, f1)],
			]
			for k: int in [0, 1, 2, 0, 2, 3]:
				_mesh.surface_set_color(Color(1.0, 1.0, 1.0, quad[k][2]))
				_mesh.surface_set_uv(quad[k][1])
				_mesh.surface_add_vertex(quad[k][0])
	_mesh.surface_end()


## Deckkraft: an der Kante dicht, zum Ende des Bogens und zur höchsten Bahn hin ausgedünnt.
func _alpha(s: Array, age: float, f: float) -> float:
	var life := age / (LIFE * (0.35 + 0.65 * float(s[5])))   # wenig Druck: kurzer Vorhang
	var start := smoothstep(0.0, 0.08, life)
	var fade := 1.0 - smoothstep(0.62, 1.0, life)    # am dichtesten im Bogen, zum Ende ausdünnen
	var top := 1.0 - smoothstep(0.75, 1.0, f) * 0.8
	return clampf(start * fade * top * (0.12 + 0.8 * float(s[5])), 0.0, 1.0)


static func _material() -> StandardMaterial3D:
	if _mat:
		return _mat
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = Color(1.0, 1.0, 1.0)
	_mat.albedo_texture = _texture()
	_mat.texture_repeat = true
	_mat.proximity_fade_enabled = true
	_mat.proximity_fade_distance = 0.3
	_mat.render_priority = 10
	return _mat


## Textur: feine Streifen in Flugrichtung (u), oben ausgefranst, dazwischen feine Tröpfchen.
static func _texture() -> ImageTexture:
	var w := 256
	var h := 64
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nz.fractal_octaves = 3
	nz.seed = 5
	var sp := FastNoiseLite.new()
	sp.noise_type = FastNoiseLite.TYPE_CELLULAR
	sp.frequency = 0.25
	sp.seed = 9
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / (h - 1)
		for x in w:
			# Streifen: langsam entlang u, schnell quer dazu (nahtlos über u durch Kreis-Abtastung)
			var ang := TAU * x / w
			var streak := nz.get_noise_3d(cos(ang) * 30.0, sin(ang) * 30.0, y * 5.0) * 0.5 + 0.5
			var drops := 1.0 - (sp.get_noise_2d(x, y * 0.6) * 0.5 + 0.5)
			var a := 0.38 + smoothstep(0.38, 0.68, streak) * 0.6   # milchiger Grund + Streifen + smoothstep(0.85, 0.97, drops) * 0.6
			a *= lerpf(1.0, 0.55, v)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
