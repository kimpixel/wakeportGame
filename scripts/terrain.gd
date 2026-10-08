class_name Terrain
extends Node3D
## Gelände aus dem echten Höhenmodell (DGM1) mit Luftbild-Textur und Wald aus dem
## Oberflächenmodell (DOM1 - DGM1 = Baumhöhe). Nahe der Anlage fein (1 m), weiter weg gröber.

const CHUNK := 40.0
const TREE_SPACING := 4.2
const TREE_CHUNK := 80.0

var _material: ShaderMaterial
var _dop_image: Image


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

func _dop_color(x: float, z: float) -> Color:
	if _dop_image == null:
		return Color(0.25, 0.4, 0.2)
	var r := Geo.game_to_rel(x, z)
	var px := int((r.x - Geo.area.position.x) / Geo.area.size.x * _dop_image.get_width())
	var py := int((Geo.area.end.y - r.y) / Geo.area.size.y * _dop_image.get_height())
	return _dop_image.get_pixel(clampi(px, 0, _dop_image.get_width() - 1), clampi(py, 0, _dop_image.get_height() - 1))


## Krone aus mehreren gestauchten Kugeln (Einheitsgröße ca. 2 x 1 x 2).
func _blob_mesh(blobs: Array, segments: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segments
	sphere.rings = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Array in blobs:
		var pos: Vector3 = b[0]
		var size: Vector3 = b[1]
		st.append_from(sphere, 0, Transform3D(Basis.from_scale(size), pos))
	return st.commit()


func _tree_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	return m


func _build_trees() -> void:
	var mat := _tree_material()
	# Waldkiefer: schirmartige, lockere Krone aus mehreren Büscheln
	var pine := _blob_mesh([
		[Vector3(0.0, 0.15, 0.0), Vector3(0.7, 0.42, 0.7)],
		[Vector3(0.5, -0.1, 0.2), Vector3(0.45, 0.32, 0.45)],
		[Vector3(-0.4, -0.05, -0.35), Vector3(0.5, 0.33, 0.5)],
		[Vector3(0.05, 0.3, -0.35), Vector3(0.42, 0.28, 0.42)],
		[Vector3(-0.35, 0.1, 0.42), Vector3(0.4, 0.3, 0.4)],
	], 6)
	# Laubbaum: runde, dichte Krone
	var leafy := _blob_mesh([
		[Vector3(0.0, 0.0, 0.0), Vector3(0.8, 0.6, 0.8)],
		[Vector3(0.45, 0.15, 0.1), Vector3(0.55, 0.45, 0.55)],
		[Vector3(-0.4, 0.1, 0.25), Vector3(0.55, 0.45, 0.55)],
		[Vector3(0.1, 0.3, -0.35), Vector3(0.5, 0.4, 0.5)],
		[Vector3(-0.1, -0.2, -0.4), Vector3(0.5, 0.4, 0.5)],
	], 7)
	# Fichte: gestufter Kegel
	var spruce_st := SurfaceTool.new()
	spruce_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Array in [[-0.2, 0.6, 1.0], [0.12, 0.5, 0.72], [0.38, 0.3, 0.42]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = c[2]
		cone.height = c[1]
		cone.radial_segments = 7
		cone.rings = 1
		spruce_st.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, c[0], 0.0)))
	var spruce := spruce_st.commit()
	for m: ArrayMesh in [pine, leafy, spruce]:
		m.surface_set_material(0, mat)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 5
	trunk.rings = 1
	trunk.material = mat

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := Geo.game_bounds()
	var meshes := [pine, leafy, spruce]
	var chunks := {}   # Vector3i(cx, cz, art) -> [Transforms, Farben];  art 3 = Stämme
	var x := b.position.x
	while x < b.end.x:
		var z := b.position.y
		while z < b.end.y:
			var tx := x + rng.randf_range(-1.5, 1.5)
			var tz := z + rng.randf_range(-1.5, 1.5)
			z += TREE_SPACING
			if not Geo.in_area(tx, tz):
				continue
			var tree_h := Geo.canopy(tx, tz)
			if tree_h < 3.5:
				continue
			var ground := Geo.height(tx, tz)
			if ground < 0.2:
				continue
			# Gebäude haben auch Höhe – Bäume nur dort, wo das Luftbild grün ist
			var col := _dop_color(tx, tz)
			if not (col.g > col.r * 1.02 and col.g >= col.b * 0.95 and col.get_luminance() < 0.55):
				continue
			tree_h = minf(tree_h, 30.0) * rng.randf_range(0.92, 1.05)

			# Baumart: überwiegend Kiefern, hellgrüne Stellen und Strandnähe eher Laubbäume
			var leafy_chance := clampf((col.get_luminance() - 0.2) * 3.0, 0.08, 0.6)
			if Vector2(tx, tz).length() < 90.0:
				leafy_chance = maxf(leafy_chance, 0.55)
			var roll := rng.randf()
			var art := 1 if roll < leafy_chance else (2 if roll < leafy_chance + 0.1 else 0)

			var crown_h: float
			var crown_r: float
			var tint: Color
			var bark: Color
			match art:
				0:   # Kiefer: langer Stamm, Krone im oberen Drittel
					crown_h = tree_h * rng.randf_range(0.28, 0.38)
					crown_r = clampf(tree_h * 0.17, 1.3, 3.8) * rng.randf_range(0.8, 1.2)
					tint = Color(0.11, 0.21, 0.1).lerp(col, 0.25) * rng.randf_range(0.85, 1.15)
					bark = Color(0.27, 0.2, 0.16) * rng.randf_range(0.85, 1.1)
				1:   # Laubbaum: Krone über gut die Hälfte der Höhe
					crown_h = tree_h * rng.randf_range(0.5, 0.62)
					crown_r = clampf(tree_h * 0.26, 1.6, 5.0) * rng.randf_range(0.85, 1.15)
					tint = Color(0.24, 0.38, 0.13).lerp(col * 1.2, 0.35) * rng.randf_range(0.85, 1.15)
					bark = Color(0.4, 0.37, 0.33)
				_:   # Fichte: Kegel fast bis zum Boden
					crown_h = tree_h * 0.78
					crown_r = clampf(tree_h * 0.17, 1.2, 3.2)
					tint = Color(0.08, 0.18, 0.11) * rng.randf_range(0.85, 1.15)
					bark = Color(0.35, 0.27, 0.2)
			var crown_y := ground + tree_h - crown_h * 0.5
			var trunk_top := crown_y if art != 0 else crown_y + crown_h * 0.2
			var trunk_r := 0.12 + tree_h * 0.009
			var basis := Basis.from_scale(Vector3(crown_r, crown_h, crown_r)).rotated(Vector3.UP, rng.randf() * TAU)
			_chunk_add(chunks, tx, tz, art, Transform3D(basis, Vector3(tx, crown_y, tz)), tint)
			var trunk_h := maxf(trunk_top - ground, 0.5)
			_chunk_add(chunks, tx, tz, 3, Transform3D(Basis.from_scale(Vector3(trunk_r, trunk_h, trunk_r)), Vector3(tx, ground + trunk_h * 0.5, tz)), bark)
		x += TREE_SPACING

	for key: Vector3i in chunks:
		var entry: Array = chunks[key]
		_add_multimesh(trunk if key.z == 3 else meshes[key.z], entry[0], entry[1])


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
func _add_multimesh(mesh: Mesh, transforms: Array, colors: Array) -> void:
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
	add_child(mmi)
