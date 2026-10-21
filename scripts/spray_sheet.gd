class_name SpraySheet
extends MeshInstance3D
## "Wasserwand": Gischt-Vorhang beim Schneiden (nach Fotos vom Wakeport): kein Partikelhaufen, sondern eine
## zusammenhängende, dünne Wasserwand. Die Kante gibt laufend Wasser ab ("Scheiben"); jede Scheibe
## bleibt, wo sie die Kante verlassen hat, und fliegt ballistisch: flach von der Kante weg, im Bogen
## hoch, weit hinter dem Fahrer zurück ins Wasser. Jedes Bild wird aus allen Scheiben ein Band
## aufgespannt (Zeilen = flache bis steilste Flugbahn), fein gestreift in Flugrichtung, durchscheinend,
## oben und zum Ende ausgefranst. Höhe und Weite kommen vom Kantendruck (strength 0..1).

const LIFE := 1.25              # s, so lange fliegt das Wasser (Länge des Vorhangs)
## je Grafikstufe (Niedrig, Mittel, Hoch): s zwischen zwei Scheiben, Zeilen von der flachsten zur steilsten Flugbahn
const EMIT_Q := [0.05, 0.035, 0.025]
const ROWS_Q := [5, 7, 9]
static var quality := 2         # Grafikstufe, gesetzt in main.gd _apply_quality
## Form (live regelbar im Debug-Overlay F4, Reiter "Wasserwand")
static var WALL_BASE := 1.1        # m: so lang ist der Ansatz an der Kante (Teil des Bretts im Wasser)
static var WALL_SPEED_MIN := 0.0   # m/s Abwurf bei wenig Kantendruck
static var WALL_SPEED_MAX := 12.068   # m/s bei voller Stärke
static var WALL_ANG_LOW := 0.22    # rad: flachste Bahn (weit zur Seite)
static var WALL_ANG_HIGH := 0.716  # rad: steilste Bahn (hoch, kippt über wie eine Tube)
## Stärke der Wasserwand (berechnet in Rider._update_spray, steuert auch die Tropfen), 0..1:
## Summe der Anteile Seilzug + Tempo + Winkel + Sprung-Ladung, je mit Gewicht (auch bei durchhängendem Seil
## spritzt es, wenn man mit Tempo auf der Kante fährt).
static var WALL_ROPE_MIN := 51.0    # N Seilzug, ab dem die Wasserwand wächst
static var WALL_ROPE_FULL := 823.2  # N Seilzug: voller Seilzug-Anteil
static var WALL_TEMPO_FULL := 11.0  # m/s Fahrtempo für vollen Tempo-Anteil (ca. 40 km/h)
static var WALL_W_ROPE := 0.5       # Gewicht Seilzug
static var WALL_W_TEMPO := 0.1      # Gewicht Tempo
static var WALL_W_ANGLE := 0.25     # Gewicht Winkel (Seil quer zur Fahrtrichtung = Kante voll belastet)
static var WALL_W_JUMP := 0.3       # Gewicht Sprung-Ladung (in die Knie = mehr Druck auf die Kante)
const GRAVITY := 9.8

var water: Water
var _slices: Array = []         # [Startpunkt, Seite, Brettachse, Abwurf, Zeit, Stärke, Abschnitt]
var _seg := 0                   # Abschnitt: neu nach Pause oder Kantenwechsel (Wand wird nicht darüber verbunden)
var _was_active := false
var _t := 0.0
var _emit_acc := 0.0
var _mesh := ArrayMesh.new()
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
		# Kantenwechsel (Seite dreht sich um) oder Neubeginn: neuer Abschnitt, sonst würde die Wand quer
		# über das Brett zur alten Seite gespannt (sah kurz aus wie in die falsche Richtung)
		if not _was_active or (not _slices.is_empty() and (_slices[-1][1] as Vector3).dot(side) < 0.5):
			_seg += 1
		_emit_acc += delta
		var dt: float = EMIT_Q[quality]
		while _emit_acc >= dt:
			_emit_acc -= dt
			var speed := lerpf(WALL_SPEED_MIN, WALL_SPEED_MAX, strength)
			_slices.append([at, side, axis, speed, _t, strength, _seg])
	else:
		_emit_acc = 0.0
	_was_active = active
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
	# nur die Grundwellen (billig): die volle Höhe mit allen Heckwellen-Ringen je Punkt und Bild
	# machte das Spiel am Handy sehr langsam
	var wy := Water.ambient(p.x, p.z, water.sim_time) if water else 0.0
	if water:
		var pl := water.pool_level(p.x, p.z)
		if pl > FeaturePart.NONE:
			wy += pl                                          # im Pool: dessen Wasserspiegel
	p.y = maxf(p.y, wy + 0.02)
	return p


func _build() -> void:
	_mesh.clear_surfaces()
	var n := _slices.size()
	if n < 2:
		return
	# jeden Punkt (Scheibe × Zeile) nur einmal rechnen, benachbarte Vierecke teilen ihn
	var rows: int = ROWS_Q[quality]
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n * rows)
	uvs.resize(n * rows)
	cols.resize(n * rows)
	for i in n:
		var s: Array = _slices[i]
		var age := _t - float(s[4])
		for r in rows:
			var f := float(r) / (rows - 1)
			var k := i * rows + r
			pts[k] = _point(s, f, age)
			uvs[k] = Vector2(float(s[4]) * 1.3, f)
			cols[k] = Color(1.0, 1.0, 1.0, _alpha(s, age, f))
	var idx := PackedInt32Array()
	for i in n - 1:
		if int(_slices[i][6]) != int(_slices[i + 1][6]):
			continue                     # nicht über einen Kantenwechsel/eine Pause verbinden
		for r in rows - 1:
			var a := i * rows + r
			var b := a + rows
			idx.append(a)
			idx.append(b)
			idx.append(b + 1)
			idx.append(a)
			idx.append(b + 1)
			idx.append(a + 1)
	if idx.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mesh.surface_set_material(0, _material())


## Grafikstufe 0..2. Weiches Ausblenden am Wasser (Proximity Fade) braucht die Szenentiefe – im Browser
## eine zusätzliche Tiefenkopie je Bild, darum nur auf Hoch.
static func set_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	if _mat:
		_mat.proximity_fade_enabled = quality >= 2


## Helligkeit (unbeleuchtetes Material, sonst leuchtet die Gischt nachts), aus Weather.apply.
static func set_light(l: float) -> void:
	if _mat:
		_mat.albedo_color = Color(l, l, l)


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
	_mat.albedo_color = Color(Weather.lum, Weather.lum, Weather.lum)   # unbeleuchtet: nachts abdunkeln
	_mat.albedo_texture = _texture()
	_mat.texture_repeat = true
	_mat.proximity_fade_distance = 0.3
	_mat.render_priority = 10
	set_quality(quality)
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
