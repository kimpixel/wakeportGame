class_name Terrain
extends Node3D
## Gelände aus dem echten Höhenmodell (DGM1) mit Luftbild-Textur und Wald aus dem
## Oberflächenmodell (DOM1 - DGM1 = Baumhöhe). Nahe der Anlage fein (1 m), weiter weg gröber.

const CHUNK := 40.0
const TREE_SPACING := 4.2
const TREE_CHUNK := 160.0   # groß = wenige Draw Calls
const FAR_RANGE := 160.0    # ab hier (Kachel-Mitte) Kronen ohne Blattkarten
const GRASS_SPACING := 0.9   # Rasterabstand der Grasbüschel in m
const GRASS_CHUNK := 32.0
const GRASS_RANGE := 110.0   # Sichtweite der Gras-Kacheln (Shader lässt es vorher wegschrumpfen)
const VARIANTS := 3      # Kronen-Varianten je Baumart
const TRUNKS := 100      # Stämme: Schlüssel TRUNKS + Kronenart (gleiche Reihenfolge, Baumdichte passt)

var _material: ShaderMaterial
var _dop_image: Image
var _dop_core: Image   # feines Luftbild um die Anlagen (für das Gras)


func _ready() -> void:
	Geo.ensure_loaded()
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/terrain.gdshader")
	var wide: Texture2D = load(Geo.DIR + "dop_wide.jpg")
	_material.set_shader_parameter("dop_wide", wide)
	_material.set_shader_parameter("dop_core", load(Geo.DIR + "dop_core.jpg"))
	_material.set_shader_parameter("area_rect", Vector4(Geo.area.position.x, Geo.area.position.y, Geo.area.end.x, Geo.area.end.y))
	_material.set_shader_parameter("core_rect", Vector4(Geo.core.position.x, Geo.core.position.y, Geo.core.end.x, Geo.core.end.y))
	_material.set_shader_parameter("dir_u", Geo.dir_u)
	_material.set_shader_parameter("brightness", 0.75 if compat else 1.0)

	_dop_image = wide.get_image()
	if _dop_image and _dop_image.is_compressed():
		_dop_image.decompress()

	var t0 := Time.get_ticks_msec()
	_build_terrain()
	_build_far_ground(compat)
	_build_trees()
	_dop_core = (load(Geo.DIR + "dop_core.jpg") as Texture2D).get_image()
	if _dop_core and _dop_core.is_compressed():
		_dop_core.decompress()
	_build_grass()
	_dop_core = null
	_water_cache.clear()
	if "--autotest" in OS.get_cmdline_user_args():
		var n := 0
		for c in get_children():
			if c is MultiMeshInstance3D:
				n += (c as MultiMeshInstance3D).multimesh.instance_count
		print("Terrain gebaut in %d ms, %d Baum-Instanzen" % [Time.get_ticks_msec() - t0, n])


# ---------------------------------------------------------------- Gelände

func _build_terrain() -> void:
	var b := Geo.game_bounds()
	var cx := int(ceil(b.size.x / CHUNK))
	var cz := int(ceil(b.size.y / CHUNK))
	for i in cx:
		for j in cz:
			var x0 := b.position.x + i * CHUNK
			var z0 := b.position.y + j * CHUNK
			var center := Vector2(x0 + CHUNK * 0.5, z0 + CHUNK * 0.5)
			# Chunks, die komplett außerhalb des Datengebiets liegen, weglassen
			var any_inside := false
			for c: Vector2 in [Vector2(x0, z0), Vector2(x0 + CHUNK, z0), Vector2(x0, z0 + CHUNK), Vector2(x0 + CHUNK, z0 + CHUNK), center]:
				if Geo.in_area(c.x, c.y):
					any_inside = true
			if not any_inside:
				continue
			var d := center.length()
			var step := 1.0 if d < 130.0 else (2.0 if d < 320.0 else 4.0)
			if Geo.height(center.x, center.y) < -3.0 and d > 60.0:
				step = maxf(step, 4.0)   # tiefer Seegrund ist ohnehin verdeckt
			_build_chunk(x0, z0, step)


func _build_chunk(x0: float, z0: float, step: float) -> void:
	var n := int(CHUNK / step)
	var g := n + 3   # Höhen inkl. Rand für Normalen
	var hs := PackedFloat32Array()
	hs.resize(g * g)
	for j in g:
		for i in g:
			hs[j * g + i] = Geo.height(x0 + (i - 1) * step, z0 + (j - 1) * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	normals.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var k := (j + 1) * g + (i + 1)
			var h := hs[k]
			verts[j * (n + 1) + i] = Vector3(x0 + i * step, h, z0 + j * step)
			normals[j * (n + 1) + i] = Vector3(hs[k - 1] - hs[k + 1], 2.0 * step, hs[k - g] - hs[k + g]).normalized()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])

	# Schürzen an den Rändern verdecken Lücken zwischen unterschiedlich feinen Chunks
	var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for t in n + 1:
		edges[0].append(t)
		edges[1].append(n * (n + 1) + t)
		edges[2].append(t * (n + 1))
		edges[3].append(t * (n + 1) + n)
	for e in edges:
		var base := verts.size()
		for idx in e:
			verts.append(verts[idx] - Vector3(0.0, step * 1.5, 0.0))
			normals.append(normals[idx])
		for t in e.size() - 1:
			indices.append_array([e[t], e[t + 1], base + t + 1, e[t], base + t + 1, base + t])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


## Flache Waldebene rund um das Datengebiet, damit der Horizont nicht leer ist.
## Sie liegt unter dem Rand des echten Geländes (dort ist überall Wald, > 2 m über dem See).
func _build_far_ground(compat: bool) -> void:
	var inner := Geo.game_bounds().grow(-80.0)
	var outer := inner.grow(2500.0)
	var mat := Util.mat(Color(0.12, 0.22, 0.1) if compat else Color(0.16, 0.3, 0.13))
	var pieces := [
		Rect2(outer.position.x, outer.position.y, outer.size.x, inner.position.y - outer.position.y),
		Rect2(outer.position.x, inner.end.y, outer.size.x, outer.end.y - inner.end.y),
		Rect2(outer.position.x, inner.position.y, inner.position.x - outer.position.x, inner.size.y),
		Rect2(inner.end.x, inner.position.y, outer.end.x - inner.end.x, inner.size.y),
	]
	for r: Rect2 in pieces:
		var pm := PlaneMesh.new()
		pm.size = r.size
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.position = Vector3(r.get_center().x, 2.0, r.get_center().y)
		add_child(mi)

	# Kronendach außerhalb des Datengebiets, damit der Wald bis zum Horizont reicht
	var canopy_mat := ShaderMaterial.new()
	canopy_mat.shader = preload("res://shaders/canopy.gdshader")
	canopy_mat.set_shader_parameter("brightness", 0.8 if compat else 1.0)
	var data := Geo.game_bounds().grow(-10.0)
	var far := data.grow(2500.0)
	for r: Rect2 in [
		Rect2(far.position.x, far.position.y, far.size.x, data.position.y - far.position.y),
		Rect2(far.position.x, data.end.y, far.size.x, far.end.y - data.end.y),
		Rect2(far.position.x, data.position.y, data.position.x - far.position.x, data.size.y),
		Rect2(data.end.x, data.position.y, far.end.x - data.end.x, data.size.y),
	]:
		var pm := PlaneMesh.new()
		pm.size = r.size
		pm.subdivide_width = int(r.size.x / 25.0)
		pm.subdivide_depth = int(r.size.y / 25.0)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = canopy_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 12.0
		mi.position = Vector3(r.get_center().x, 13.0, r.get_center().y)
		add_child(mi)


# ---------------------------------------------------------------- Wald

## Farbe aus dem feinen Luftbild, außerhalb davon aus dem groben.
func _dop_color_fine(x: float, z: float) -> Color:
	var r := Geo.game_to_rel(x, z)
	if _dop_core == null or not Geo.core.has_point(r):
		return _dop_color(x, z)
	var px := int((r.x - Geo.core.position.x) / Geo.core.size.x * _dop_core.get_width())
	var py := int((Geo.core.end.y - r.y) / Geo.core.size.y * _dop_core.get_height())
	return _dop_core.get_pixel(clampi(px, 0, _dop_core.get_width() - 1), clampi(py, 0, _dop_core.get_height() - 1))


func _dop_color(x: float, z: float) -> Color:
	if _dop_image == null:
		return Color(0.25, 0.4, 0.2)
	var r := Geo.game_to_rel(x, z)
	var px := int((r.x - Geo.area.position.x) / Geo.area.size.x * _dop_image.get_width())
	var py := int((Geo.area.end.y - r.y) / Geo.area.size.y * _dop_image.get_height())
	return _dop_image.get_pixel(clampi(px, 0, _dop_image.get_width() - 1), clampi(py, 0, _dop_image.get_height() - 1))


## Blatt- bzw. Nadeltextur (zur Laufzeit gemalt, keine Datei): 2 x 2 Kacheln mit je einem
## Büschel, hell/grau (die Baumfarbe kommt aus der Instanzfarbe), Alpha = Blatt.
func _foliage_texture(needles: bool, rng: RandomNumberGenerator) -> ImageTexture:
	const W := 256
	const T := 128
	var data := PackedByteArray()
	data.resize(W * W * 4)
	for i in W * W:
		data[i * 4] = 170
		data[i * 4 + 1] = 180
		data[i * 4 + 2] = 160
		data[i * 4 + 3] = 0
	for tile in 4:
		var ox := (tile % 2) * T + T / 2
		var oy := (tile / 2) * T + T / 2
		var count := 26 if needles else 85
		for k in count:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * (T * 0.3)
			var cx := ox + cos(a) * r
			var cy := oy + sin(a) * r
			var bright := rng.randf_range(0.55, 1.0)
			if needles:
				# Nadelbüschel: Strahlen um den Zweig
				var dir0 := rng.randf() * TAU
				for nd in 16:
					var da := dir0 + nd * TAU / 16.0 + rng.randf_range(-0.15, 0.15)
					var ln := rng.randf_range(9.0, 17.0)
					var steps := int(ln * 1.5)
					for st in steps:
						var f := float(st) / steps
						var px := int(cx + cos(da) * ln * f)
						var py := int(cy + sin(da) * ln * f * 0.8)
						var sh := bright * (0.75 + 0.25 * f)
						for dx in 2:
							_paint(data, W, px + dx, py, sh)
			else:
				# Blatt: spitze Ellipse, zeigt vom Büschel weg, Mittelrippe etwas dunkler
				var ang := a + rng.randf_range(-0.6, 0.6)
				var ln := rng.randf_range(6.0, 10.0)
				var wd := ln * rng.randf_range(0.38, 0.5)
				var ca := cos(ang)
				var sa := sin(ang)
				var ext := int(ln) + 1
				for py in range(int(cy) - ext, int(cy) + ext + 1):
					for px in range(int(cx) - ext, int(cx) + ext + 1):
						var u := ((px - cx) * ca + (py - cy) * sa) / ln
						var v := (-(px - cx) * sa + (py - cy) * ca) / wd
						var lim := 1.0 - u * u
						if lim <= 0.0 or v * v > lim * lim:
							continue
						var sh := bright * (0.82 + 0.18 * u) * (0.8 if absf(v) < 0.12 else 1.0) * (1.0 - 0.25 * absf(v))
						_paint(data, W, px, py, sh)
	var img := Image.create_from_data(W, W, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _paint(data: PackedByteArray, w: int, x: int, y: int, shade: float) -> void:
	if x < 0 or y < 0 or x >= w or y >= w:
		return
	var i := (y * w + x) * 4
	var v := int(clampf(shade, 0.0, 1.0) * 255.0)
	data[i] = v
	data[i + 1] = v
	data[i + 2] = int(v * 0.9)
	data[i + 3] = 255


## Krone (Einheitsgröße ca. 2 x 1 x 2): Fläche 0 = dunkle, geschlossene Hülle aus Kugeln/Kegeln
## (damit man nicht durch die Krone sieht), Fläche 1 = Blattkarten mit Blatt-/Nadeltextur.
## hull = [[Mesh, Transform3D], …], cards = [[Mitte, Richtung, Größe], …] (Einheitsraum).
## Normalen zeigen vom Kronenmittelpunkt weg (weiches Licht wie bei echtem Laub);
## UV2.x = Verschattung (innen und unten dunkel). stretch: Einheitsraum -> ungefähr echte Proportionen, hull_dark: Helligkeit der Hülle.
## Ergebnis [nah, fern, Schatten]: fern = grobe Hülle mit jeder zweiten (größeren) Blattkarte (ab FAR_RANGE),
## Schatten = nur die grobe Hülle (wirft den Schatten für alle Stufen).
func _crown_mesh(hull: Array, cards: Array, center: Vector3, rng: RandomNumberGenerator, stretch := Vector3(1.0, 2.2, 1.0), hull_dark := 0.45) -> Array:
	var extent := 0.01
	for c: Array in cards:
		extent = maxf(extent, (((c[0] as Vector3) - center) * stretch).length())
	var mesh := ArrayMesh.new()
	var far := ArrayMesh.new()
	var shadow := ArrayMesh.new()
	for surface in 4:   # 0 = Hülle, 1 = Blattkarten, 2 = grobe Hülle (Ferne, Schatten), 3 = halbe Blattkarten (Ferne)
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		if surface == 0 or surface == 2:
			for part: Array in hull:
				var src: Array = (part[0] if surface == 0 else _lowres(part[0])).surface_get_arrays(0)
				var xf: Transform3D = part[1]
				var base := verts.size()
				for lv: Vector3 in src[Mesh.ARRAY_VERTEX]:
					var p := xf * lv
					verts.append(p)
					normals.append(((p - center) * stretch * stretch).normalized())
					uvs.append(Vector2.ZERO)
				for idx: int in src[Mesh.ARRAY_INDEX]:
					indices.append(base + idx)
		else:
			for ci in cards.size():
				if surface == 3 and ci % 2 == 1:
					continue
				var c: Array = cards[ci]
				var pos: Vector3 = c[0]
				var n: Vector3 = (c[1] as Vector3).normalized()
				var size: float = c[2] * (1.3 if surface == 3 else 1.0)
				var side := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
				var up := side.cross(n)
				var roll := rng.randf() * TAU
				var t := (side * cos(roll) + up * sin(roll)) * size
				var bt := (up * cos(roll) - side * sin(roll)) * size
				var q := pos * stretch
				var tile := Vector2(rng.randi_range(0, 1), rng.randi_range(0, 1)) * 0.5
				var base := verts.size()
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var p := (q + t * corner.x + bt * corner.y) / stretch
					verts.append(p)
					normals.append(((p - center) * stretch * stretch).normalized().lerp(n * stretch, 0.25).normalized())
					uvs.append(tile + (corner * 0.5 + Vector2(0.5, 0.5)) * 0.5)
				indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		var ao := PackedVector2Array()
		for p: Vector3 in verts:
			var r := ((p - center) * stretch).length() / extent
			var h := clampf((p.y - center.y) * 1.2 + 0.5, 0.0, 1.0)
			var a := clampf(pow(r, 1.3) * 0.8 + h * 0.35, 0.1, 1.0)
			ao.append(Vector2(a * [hull_dark, 1.0, hull_dark, 1.0][surface], 0.0))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = ao
		arrays[Mesh.ARRAY_INDEX] = indices
		([mesh, mesh, far, far][surface] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if surface == 2:
			shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [mesh, far, shadow]


var _lowres_cache := {}

## Grobe Fassung eines Hüllen-Teils für die Fern-Krone (wenige Dreiecke).
func _lowres(mesh: Mesh) -> Mesh:
	if _lowres_cache.has(mesh):
		return _lowres_cache[mesh]
	var lo: PrimitiveMesh
	if mesh is CylinderMesh:
		var c := (mesh as CylinderMesh).duplicate() as CylinderMesh
		c.radial_segments = 5
		lo = c
	else:
		var sph := SphereMesh.new()
		sph.radius = 1.0
		sph.height = 2.0
		sph.radial_segments = 5
		sph.rings = 1
		lo = sph
	_lowres_cache[mesh] = lo
	return lo


## Zufällige Richtung auf der Kugel, nach oben/außen bevorzugt.
func _rand_dir(rng: RandomNumberGenerator, min_y: float) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(min_y, 1.0), rng.randf_range(-1.0, 1.0)).normalized()


## Laubbaum: runde Wolke aus Blattbüscheln.
func _leafy_mesh(rng: RandomNumberGenerator, ball: Mesh) -> Array:
	var hull := []
	var cards := []
	for i in 9:
		var dir := _rand_dir(rng, -0.5)
		var rad := sqrt(rng.randf_range(0.2, 1.0))
		var s := rng.randf_range(0.38, 0.5) * (1.2 - rad * 0.3)
		var pos := dir * rad * Vector3(0.55, 0.26, 0.55)
		hull.append([ball, Transform3D(Basis.from_scale(Vector3(s, s * 0.45, s) * 0.72), pos)])
		for k in 9:
			var d := _rand_dir(rng, -0.6)
			cards.append([pos + d * Vector3(s, s * 0.45, s) * rng.randf_range(0.6, 0.95), d + dir * 0.6, rng.randf_range(0.3, 0.42)])
	return _crown_mesh(hull, cards, Vector3(0.0, -0.05, 0.0), rng)


## Waldkiefer: schirmartige, lockere Krone aus flachen Nadelbüscheln an Astenden, oben dichter.
func _pine_mesh(rng: RandomNumberGenerator, ball: Mesh) -> Array:
	var hull := []
	var cards := []
	var n := rng.randi_range(12, 15)
	for i in n:
		var y := rng.randf_range(-0.4, 0.32)
		var spread := 0.75 - (y + 0.4) * 0.45
		var a := float(i) / n * TAU + rng.randf_range(-0.4, 0.4)
		var r := spread * rng.randf_range(0.45, 1.0)
		var s := rng.randf_range(0.32, 0.46)
		var pos := Vector3(cos(a) * r, y, sin(a) * r)
		hull.append([ball, Transform3D(Basis.from_scale(Vector3(s, s * 0.4, s) * 0.8), pos)])
		for k in 5:
			var d := _rand_dir(rng, -0.2) + Vector3(cos(a), 0.0, sin(a)) * 0.3
			cards.append([pos + Vector3(d.x * s * 0.7, d.y * s * 0.25, d.z * s * 0.7), d + Vector3.UP * 0.8, rng.randf_range(0.3, 0.42)])
	hull.append([ball, Transform3D(Basis.from_scale(Vector3(0.36, 0.14, 0.36)), Vector3(0.0, 0.3, 0.0))])
	for k in 4:
		var d := _rand_dir(rng, 0.2)
		cards.append([Vector3(0.0, 0.33, 0.0) + d * Vector3(0.3, 0.1, 0.3), d + Vector3.UP, 0.4])
	return _crown_mesh(hull, cards, Vector3(0.0, -0.1, 0.0), rng)


## Fichte: Etagen aus Kegeln, am Rand leicht hängende Nadelkarten.
func _spruce_mesh(rng: RandomNumberGenerator) -> Array:
	var hull := []
	var cards := []
	var tiers := 6
	for t in tiers:
		var f := float(t) / (tiers - 1)
		var radius := lerpf(0.95, 0.4, f) * rng.randf_range(0.9, 1.05)
		var height := lerpf(0.4, 0.26, f)
		var y := lerpf(-0.32, 0.44, f)
		# Hülle kleiner als die Etage: die Nadelkarten bilden den Rand
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = radius * 0.7
		cone.height = height * 0.9
		cone.radial_segments = 7
		cone.rings = 1
		hull.append([cone, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0))])
		# Nadelkarten über die ganze Schräge der Etage, außen mehr
		var m := int(lerpf(20.0, 8.0, f))
		for k in m:
			var ang := (k + rng.randf()) / m * TAU
			var out := Vector3(cos(ang), 0.0, sin(ang))
			var g := sqrt(rng.randf_range(0.1, 1.0))
			var pos := out * radius * g + Vector3(0.0, y + height * 0.5 - g * height * 1.05, 0.0)
			cards.append([pos, out + Vector3.UP * lerpf(0.9, 0.3, g) + _rand_dir(rng, -1.0) * 0.35, lerpf(0.38, 0.22, f) * rng.randf_range(0.85, 1.15)])
	return _crown_mesh(hull, cards, Vector3(0.0, -0.6, 0.0), rng, Vector3(1.0, 4.5, 1.0), 0.55)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shader := preload("res://shaders/foliage.gdshader")
	var hull_mat := ShaderMaterial.new()
	hull_mat.shader = shader
	var leaf_mats: Array[ShaderMaterial] = []
	for needles in [true, false]:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("cards", true)
		m.set_shader_parameter("leaf_tex", _foliage_texture(needles, rng))
		leaf_mats.append(m)
	var bark_mat := ShaderMaterial.new()
	bark_mat.shader = preload("res://shaders/bark.gdshader")
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 5
	ball.rings = 2
	# je Baumart VARIANTS verschiedene Kronen, damit sich der Wald nicht sichtbar wiederholt
	var meshes := []   # Index art * VARIANTS + Variante: [nah, fern, Schatten]
	for art in 3:
		for v in VARIANTS:
			var pair: Array
			match art:
				0: pair = _pine_mesh(rng, ball)
				1: pair = _leafy_mesh(rng, ball)
				_: pair = _spruce_mesh(rng)
			(pair[0] as ArrayMesh).surface_set_material(0, hull_mat)
			(pair[0] as ArrayMesh).surface_set_material(1, leaf_mats[1] if art == 1 else leaf_mats[0])
			(pair[1] as ArrayMesh).surface_set_material(0, hull_mat)
			(pair[1] as ArrayMesh).surface_set_material(1, leaf_mats[1] if art == 1 else leaf_mats[0])
			(pair[2] as ArrayMesh).surface_set_material(0, hull_mat)
			meshes.append(pair)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.material = bark_mat

	var b := Geo.game_bounds()
	rng.seed = 7   # Standorte unabhängig von den Kronen-Meshes
	var chunks := {}   # Vector3i(cx, cz, Kronenart bzw. TRUNKS + Kronenart) -> [Transforms, Farben]
	var x := b.position.x
	while x < b.end.x:
		var z := b.position.y
		while z < b.end.y:
			var tx := x + rng.randf_range(-1.5, 1.5)
			var tz := z + rng.randf_range(-1.5, 1.5)
			z += TREE_SPACING
			if not Geo.in_area(tx, tz):
				continue
			var ground := Geo.height(tx, tz)
			if ground < 0.2:
				continue
			var tree_h := Geo.canopy(tx, tz)
			var col := _dop_color(tx, tz)
			var shore := _near_water(tx, tz, 14.0) and not _at_beach(tx, tz)
			if tree_h < 3.5:
				# Das Oberflächenmodell ist am Ufer zu grob: der Waldrand reicht bis ans Wasser (Büsche, junge Bäume)
				if shore and _is_green(col) and _forest_near(tx, tz):
					_add_tree(chunks, rng, tx, tz, ground, rng.randf_range(4.0, 8.0), col, 1, true)
				continue
			# Gebäude haben auch Höhe – Bäume nur dort, wo das Luftbild grün ist
			if not _is_green(col):
				continue
			tree_h = minf(tree_h, 30.0) * rng.randf_range(0.92, 1.05)
			# Baumart: dichter Mischwald, überwiegend Laubbäume und Kiefern, nur selten eine Fichte
			var leafy_chance := clampf((col.get_luminance() - 0.15) * 3.0, 0.55, 0.8)
			var roll := rng.randf()
			var art := 1 if roll < leafy_chance else (2 if roll < leafy_chance + 0.02 else 0)
			_add_tree(chunks, rng, tx, tz, ground, tree_h, col, art, shore)
			if shore:
				# Waldmantel: zwischen den Uferbäumen Büsche, damit vom See eine geschlossene grüne Wand steht
				for k in 1:
					var bx := tx + rng.randf_range(-2.2, 2.2)
					var bz := tz + rng.randf_range(-2.2, 2.2)
					var bg := Geo.height(bx, bz)
					if bg > 0.2:
						_add_tree(chunks, rng, bx, bz, bg, rng.randf_range(3.0, 7.0), col, 1, true)
		x += TREE_SPACING

	# Kronen: nah mit Blattkarten, ab FAR_RANGE nur die Hülle (Kachel-Mitte zählt, daher Rand)
	for key: Vector3i in chunks:
		var entry: Array = chunks[key]
		if key.z >= TRUNKS:
			_add_multimesh(trunk, entry[0], entry[1])
		else:
			# Schatten wirft nur die grobe Hülle (eigenes MultiMesh): die Blattkarten in allen
			# Schattenstufen mitzuzeichnen kostet viel, sieht man im Schatten aber kaum
			var near := _add_multimesh(meshes[key.z][0], entry[0], entry[1], 0.0, FAR_RANGE)
			near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var far := _add_multimesh(meshes[key.z][1], entry[0], entry[1], FAR_RANGE, 0.0)
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var shadow := _add_multimesh(meshes[key.z][2], entry[0], entry[1])
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Ein Baum: Krone (Art 0 Kiefer, 1 Laubbaum, 2 Fichte) und Stamm. edge = Waldrand am Wasser:
## Krone reicht fast bis zum Boden und ist breiter (wie ein Waldmantel, keine kahlen Stämme zum See).
func _add_tree(chunks: Dictionary, rng: RandomNumberGenerator, tx: float, tz: float, ground: float, tree_h: float,
		col: Color, art: int, edge: bool) -> void:
	var crown_h: float
	var crown_r: float
	var tint: Color
	var bark: Color
	match art:
		0:   # Kiefer: Krone über gut die Hälfte der Höhe (buschig wie im hiesigen Wald)
			crown_h = tree_h * (rng.randf_range(0.7, 0.8) if edge else rng.randf_range(0.48, 0.6))
			crown_r = clampf(tree_h * 0.25, 1.8, 5.2) * rng.randf_range(0.85, 1.2)
			tint = Color(0.11, 0.21, 0.1).lerp(col, 0.25) * rng.randf_range(0.85, 1.15)
			bark = Color(0.2, 0.17, 0.15) * rng.randf_range(0.85, 1.1)
		1:   # Laubbaum: Krone über drei Viertel der Höhe, breit
			crown_h = tree_h * (rng.randf_range(0.85, 0.92) if edge else rng.randf_range(0.68, 0.8))
			crown_r = clampf(tree_h * 0.36, 1.6, 7.0) * rng.randf_range(0.85, 1.15)
			tint = Color(0.24, 0.38, 0.13).lerp(col * 1.2, 0.35) * rng.randf_range(0.85, 1.15)
			bark = Color(0.33, 0.31, 0.28)
		_:   # Fichte: Kegel fast bis zum Boden
			crown_h = tree_h * 0.88
			crown_r = clampf(tree_h * 0.21, 1.6, 4.0)
			tint = Color(0.1, 0.2, 0.12) * rng.randf_range(0.85, 1.15)
			bark = Color(0.35, 0.27, 0.2)
	if edge:
		crown_r *= 1.15
	var crown_y := ground + tree_h - crown_h * 0.5
	var trunk_top := crown_y if art != 0 else crown_y + crown_h * 0.2
	var trunk_r := 0.12 + tree_h * 0.009
	# Kiefern stehen oft etwas schief, Krone leicht versetzt
	var lean := Vector3.ZERO
	if art == 0:
		lean = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * crown_r * 0.18
	var basis := Basis.from_scale(Vector3(crown_r, crown_h, crown_r)).rotated(Vector3.UP, rng.randf() * TAU)
	var kind := art * VARIANTS + rng.randi_range(0, VARIANTS - 1)
	_chunk_add(chunks, tx, tz, kind, Transform3D(basis, Vector3(tx, crown_y, tz) + lean), tint)
	var up := Vector3(lean.x, maxf(trunk_top - ground, 0.5), lean.z)
	var tilt := Basis(Quaternion(Vector3.UP, up.normalized()))
	bark.a = 0.5 if art == 0 else 1.0   # Alpha < 1 = Kiefer (orange Rinde oben)
	_chunk_add(chunks, tx, tz, TRUNKS + kind, Transform3D(tilt * Basis.from_scale(Vector3(trunk_r, up.length(), trunk_r)), Vector3(tx, ground, tz) + up * 0.5), bark)


## Luftbild grün (Wald, Wiese) – auch Kronenschatten (bläulich dunkel); nicht grau (Dächer, Wege) oder Sand.
func _is_green(col: Color) -> bool:
	return col.g > col.r * 0.98 and col.g >= col.b * 0.8 and col.get_luminance() < 0.5


var _water_cache := {}   # 3-m-Rasterpunkt -> Wasser? (Nachbarbäume fragen dieselben Punkte ab)

## Liegt Wasser höchstens d Meter entfernt (8 Richtungen, zwei Abstände)?
func _near_water(x: float, z: float, d: float) -> bool:
	for f: float in [1.0, 0.5]:
		for i in 8:
			var p := Vector2(x, z) + Vector2.from_angle(i * TAU / 8.0) * d * f
			var cell := Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))
			var wet: Variant = _water_cache.get(cell)
			if wet == null:
				var c := Vector2(cell) * 3.0
				wet = Geo.in_area(c.x, c.y) and Geo.height(c.x, c.y) < 0.2
				_water_cache[cell] = wet
			if wet:
				return true
	return false


## Steht landeinwärts (bis 8 m) hoher Wald?
func _forest_near(x: float, z: float) -> bool:
	for i in 8:
		var p := Vector2(x, z) + Vector2.from_angle(i * TAU / 8.0) * 8.0
		if Geo.in_area(p.x, p.y) and Geo.canopy(p.x, p.y) > 6.0:
			return true
	return false


## Nachgebauter Strand an den Startmasten (Sand, Hütten, Stege): kein Waldmantel, kein Gras.
func _at_beach(x: float, z: float) -> bool:
	var p := Vector3(x, 0.0, z)
	return p.distance_to(Geo.masts["t1_start"]) < 18.0 or p.distance_to(Geo.masts["t2_start"]) < 18.0


func _chunk_add(chunks: Dictionary, x: float, z: float, art: int, t: Transform3D, c: Color) -> void:
	var key := Vector3i(floori(x / TREE_CHUNK), floori(z / TREE_CHUNK), art)
	if not chunks.has(key):
		chunks[key] = [[], []]
	chunks[key][0].append(t)
	chunks[key][1].append(c)


## Baumdichte (Grafikqualität): nur ein Teil der Bäume wird gezeichnet (0..1).
func set_tree_density(f: float) -> void:
	for c in get_children():
		if c is MultiMeshInstance3D:
			var mm := (c as MultiMeshInstance3D).multimesh
			mm.visible_instance_count = -1 if f >= 0.999 else int(mm.instance_count * f)


## Ein MultiMesh pro Kachel und Baumart (kachelweise Sichtbarkeitsprüfung der Kamera).
## Sichtweite von/bis (0 = unbegrenzt), mit Rand gegen Flackern an der Grenze.
func _add_multimesh(mesh: Mesh, transforms: Array, colors: Array, vis_begin := 0.0, vis_end := 0.0) -> MultiMeshInstance3D:
	var center := Vector3.ZERO
	for t: Transform3D in transforms:
		center += t.origin
	center /= transforms.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		t.origin -= center
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = center
	mmi.visibility_range_begin = vis_begin
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_begin_margin = 10.0 if vis_begin > 0.0 else 0.0
	mmi.visibility_range_end_margin = 10.0 if vis_end > 0.0 else 0.0
	add_child(mmi)
	return mmi


# ---------------------------------------------------------------- Gras

## Grasbüschel (aus SimpleGrassTextured, siehe assets/grass/README.md) am Ufer beider Anlagen: nur auf Land,
## das im Luftbild grün ist (kein Sand, keine Wege/Dächer), niedrig über dem See; im Wald lichter.
func _build_grass() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grass.gdshader")
	mat.set_shader_parameter("texture_albedo", preload("res://assets/grass/grassbushcc008.png"))
	mat.set_shader_parameter("fade_end", GRASS_RANGE - 25.0)
	mat.set_shader_parameter("fade_begin", GRASS_RANGE - 55.0)
	var mesh := _grass_mesh()
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var chunks := {}
	var done := {}   # Rasterpunkte, die schon geprüft sind (Bereiche beider Anlagen überlappen)
	for t: String in ["t1", "t2"]:
		var a: Vector3 = Geo.masts[t + "_start"]
		var e: Vector3 = Geo.masts[t + "_end"]
		var along := (e - a).normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		var length := a.distance_to(e)
		var s := -60.0
		while s < length + 40.0:
			var q := -90.0
			while q < 90.0:
				var p := a + along * s + side * q
				q += GRASS_SPACING
				var cell := Vector2i(roundi(p.x / GRASS_SPACING), roundi(p.z / GRASS_SPACING))
				if done.has(cell):
					continue
				done[cell] = true
				var gx := cell.x * GRASS_SPACING + rng.randf_range(-0.45, 0.45)
				var gz := cell.y * GRASS_SPACING + rng.randf_range(-0.45, 0.45)
				if not Geo.in_area(gx, gz):
					continue
				if _at_beach(gx, gz):
					continue
				var ground := Geo.height(gx, gz)
				if ground < 0.25 or ground > 9.0:
					continue
				var col := _dop_color_fine(gx, gz)
				if Geo.canopy(gx, gz) > 3.5:
					# Wald: das Luftbild zeigt nur Kronen und Schatten, der Boden ist lichter bewachsen
					# (helle Stellen = Sand, Dächer; Gebäude haben im Oberflächenmodell auch Höhe)
					if rng.randf() > 0.45 or col.get_luminance() > 0.42 or col.r > col.g * 1.05:
						continue
					col = Color(0.3, 0.42, 0.2)
				elif not (col.g > col.r * 0.95 and col.g >= col.b * 0.85 and col.get_luminance() < 0.6):
					continue
				elif minf(col.g, col.b) / maxf(col.r, 0.02) > 1.15 and col.b > 0.25:
					continue   # türkis = Ufersand/Wasser im Luftbild (wie im Gelände-Shader)
				var w := rng.randf_range(0.8, 1.3)
				var h := rng.randf_range(0.45, 0.8)
				var basis := Basis.from_scale(Vector3(w, h, w)).rotated(Vector3.UP, rng.randf() * TAU)
				var tint := Color(1, 1, 1).lerp(Color(col.r, col.g, col.b) * 2.2, 0.35) * rng.randf_range(0.6, 0.85)
				var key := Vector3i(floori(gx / GRASS_CHUNK), floori(gz / GRASS_CHUNK), 0)
				if not chunks.has(key):
					chunks[key] = [[], []]
				chunks[key][0].append(Transform3D(basis, Vector3(gx, ground - 0.05, gz)))
				chunks[key][1].append(tint)
			s += GRASS_SPACING
	for key: Vector3i in chunks:
		var mmi := _add_multimesh(mesh, chunks[key][0], chunks[key][1], 0.0, GRASS_RANGE)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end_margin = 5.0


## Zwei gekreuzte Flächen, 1 m breit und hoch, Fuß bei y = 0 (wie das Standard-Mesh von SimpleGrassTextured).
func _grass_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-0.5, 1, 0), Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0.5, 1, 0),
		Vector3(0, 1, -0.5), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5), Vector3(0, 1, 0.5)])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), Vector2(1, 0),
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), Vector2(1, 0)])
	var normals := PackedVector3Array()
	for i in 8:
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 1, 0, 4, 5, 6, 7, 5, 4])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
