class_name Beach
extends Node3D
## Strandbereich des Wakeports, nachgebaut nach Fotos und Luftbild (DOP20).
## Positionen in Metern relativ zum T2-Startmast: dE = nach Osten, dN = nach Norden.
## Alles steht auf dem echten Gelände (Geo.height).

var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _wood_grey: StandardMaterial3D
var _roof: StandardMaterial3D
var _white: StandardMaterial3D
var _black: StandardMaterial3D
var _blue: StandardMaterial3D
var _north_yaw := 0.0

## Leute im T2-Startblock (Steuermann/"Hebler" + Gäste). Von dort kommt der Jubel.
## Jeder Eintrag: {"pos": Vector3 (Kopfhöhe, Welt), "pitch": Stimmlage}
var people: Array[Dictionary] = []
## Wie people, für den T1-Startsteg (dort steht nur der Steuermann).
var people_t1: Array[Dictionary] = []

## Laufwege der Steuermänner (Welt, als Kette begehbar) – die Figuren baut Ambient.
var operator_paths := {}            # "T1"/"T2" -> Array[Vector3]
## Plätze für wartende Fahrer: {"pos": Vector3 (Welt), "face": Vector3 (Blickrichtung), "kind": "wait_stand"/"wait_sit"}
var waiting_spots: Array[Dictionary] = []

## Feste Hindernisse auf dem Wasser (weißer Steg, Holzsteg): wer dagegen fährt, stürzt.
## Jeder Eintrag: {"a": Vector2, "b": Vector2 (Mittellinie, Spiel-x/z), "half_w": float, "top": float}
var obstacles: Array[Dictionary] = []


func _ready() -> void:
	Geo.ensure_loaded()
	_north_yaw = Geo.north_yaw()
	_wood = Util.mat(Color(0.66, 0.56, 0.44))
	_wood_dark = Util.mat(Color(0.42, 0.34, 0.27))
	_wood_grey = Util.mat(Color(0.55, 0.53, 0.5))
	_roof = Util.mat(Color(0.8, 0.8, 0.78), 0.7)
	_white = Util.mat(Color(0.93, 0.93, 0.92), 0.7)
	_black = Util.mat(Color(0.08, 0.08, 0.09), 0.6)
	_blue = Util.mat(Color(0.15, 0.45, 0.8), 0.5)

	_build_t2_start()
	_build_t1_start()
	_build_main_building()
	_build_beach_items()
	_build_water_items()


# ---------------------------------------------------------------- Helfer

## Spielposition zu (dE, dN); y = Geländehöhe (mind. Wasserniveau).
func _at(de: float, dn: float, y_offset := 0.0) -> Vector3:
	var g := Geo.rel_to_game(de, dn)
	return Vector3(g.x, maxf(Geo.height(g.x, g.y), 0.0) + y_offset, g.y)


## Höchster Geländepunkt unter einer Grundfläche (damit nichts im Hang versinkt).
func _ground(de: float, dn: float, se: float, sn: float) -> float:
	var h := -INF
	for ox: float in [-0.5, 0.0, 0.5]:
		for oy: float in [-0.5, 0.0, 0.5]:
			var g := Geo.rel_to_game(de + ox * se, dn + oy * sn)
			h = maxf(h, Geo.height(g.x, g.y))
	return maxf(h, 0.0)


## Nach Norden ausgerichteter Knoten (lokal: +X = Osten, -Z = Norden).
func _node(de: float, dn: float, y: float, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	var g := Geo.rel_to_game(de, dn)
	n.position = Vector3(g.x, y, g.y)
	n.rotation.y = _north_yaw + deg_to_rad(yaw_deg)
	add_child(n)
	return n


## Box in lokalen Koordinaten (x = Ost, y = hoch, z = Süd).
func _b(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
	return Util.box(parent, size, center, mat)


func _post(parent: Node3D, x: float, z: float, y0: float, y1: float, mat: Material, r := 0.07) -> void:
	_b(parent, Vector3(r * 2, y1 - y0, r * 2), Vector3(x, (y0 + y1) * 0.5, z), mat)


## Satteldach (Prisma), First entlang lokal x.
func _gable(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size.z, size.y, size.x)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.rotation.y = PI * 0.5
	parent.add_child(mi)


## Pultdach als schräge Platte.
func _shed_roof(parent: Node3D, sx: float, sz: float, y_low: float, y_high: float, mat: Material) -> void:
	var mi := _b(parent, Vector3(sx, 0.08, sqrt(sz * sz + (y_high - y_low) * (y_high - y_low))), Vector3(0, (y_low + y_high) * 0.5, 0), mat)
	mi.rotation.x = -atan2(y_high - y_low, sz)


func _railing(parent: Node3D, a: Vector3, b: Vector3, mat: Material) -> void:
	var n := maxi(int(a.distance_to(b) / 1.2), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_post(parent, p.x, p.z, p.y, p.y + 1.0, mat, 0.04)
	Util.beam(parent, a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), 0.035, mat)


# ---------------------------------------------------------------- T2-Start

## T2-Startblock: Hütte nach den Drohnenfotos – niedrige Holzhütte direkt am Ufer auf einer
## Reifenmauer, helles Wellblech-Pultdach, Seitenwände aus senkrechten Brettern, offen zum See.
## Davor (nach dem aktuellen Luftbild DOP20 und Fotos): Treppe zum schwimmenden Startsteg (blau
## eingefasst), weißer Schwimmsteg nach Norden und schräg nach Südosten, Holzsteg mit Liegestühlen.
const HUT_DECK_Y := 1.35         # Deck der Hütte über dem Wasserspiegel
const HUT_BACK := -2.9           # Hütten-Raum (lokal x = Ost): Rückwand (Land) ...
const HUT_FRONT := 2.7           # ... Vorderkante über dem Wasser
const HUT_HALF_Z := 3.3          # halbe Länge Nord-Süd

func _build_t2_start() -> void:
	var y := HUT_DECK_Y
	var hut := _node(3.9, -2.0, y)
	var plank := Util.mat(Color(0.58, 0.5, 0.41))        # verwittertes Holz (Deck, Stege)
	var board := Util.mat(Color(0.67, 0.62, 0.55))       # helle, graue Bretter (Wände)
	var post := Util.mat(Color(0.5, 0.44, 0.37))
	var depth := HUT_FRONT - HUT_BACK
	# Deck aus Dielen, darunter Unterbau bis ins Wasser
	var n_planks := int(HUT_HALF_Z * 2.0 / 0.16)
	for i in n_planks:
		var z := -HUT_HALF_Z + (i + 0.5) * HUT_HALF_Z * 2.0 / n_planks
		_b(hut, Vector3(depth + 0.1, 0.06, 0.145), Vector3((HUT_BACK + HUT_FRONT) * 0.5, -0.03, z), plank)
	_b(hut, Vector3(depth, 0.22, HUT_HALF_Z * 2.0), Vector3((HUT_BACK + HUT_FRONT) * 0.5, -0.17, 0), _wood_dark)
	# Pfosten unter dem Deck bis in den Boden (Hang fällt zum Wasser ab)
	var px := HUT_BACK + 0.1
	while px < HUT_FRONT:
		for z: float in [-HUT_HALF_Z + 0.1, HUT_HALF_Z - 0.1]:
			_post(hut, px, z, -y - 0.6, -0.2, post, 0.08)
		px += 1.1
	# Eckpfosten: hinten höher (Pultdach fällt zum Wasser hin ab)
	var roof_back := 2.75
	var roof_front := 2.35
	for x: float in [HUT_BACK + 0.08, HUT_FRONT - 0.15]:
		for z: float in [-HUT_HALF_Z + 0.08, HUT_HALF_Z - 0.08]:
			_post(hut, x, z, 0.0, roof_back if x < 0.0 else roof_front, post, 0.07)
	_post(hut, HUT_FRONT - 0.15, 0.0, 0.0, roof_front, post, 0.06)
	# Rückwand zum Land: waagerechte Bretter bis unters Dach
	for i in int(roof_back / 0.2):
		_b(hut, Vector3(0.05, 0.18, HUT_HALF_Z * 2.0), Vector3(HUT_BACK + 0.02, 0.1 + i * 0.2, 0), board)
	# Seitenwände: senkrechte Bretter mit Fugen, hinten hoch, vorne brusthoch (offen zum See)
	for side: float in [-1.0, 1.0]:
		var z := side * (HUT_HALF_Z - 0.03)
		var x := HUT_BACK + 0.1
		while x < HUT_FRONT - 0.25:
			var h := lerpf(roof_back - 0.1, 1.05, clampf((x - HUT_BACK) / 2.5, 0.0, 1.0))
			_b(hut, Vector3(0.13, h, 0.04), Vector3(x + 0.065, h * 0.5, z), board)
			x += 0.155
		_b(hut, Vector3(depth - 0.2, 0.07, 0.09), Vector3((HUT_BACK + HUT_FRONT) * 0.5 - 0.1, 1.08, z), post)  # Handlauf
	# Pultdach aus hellem Wellblech mit Überstand; Rippen laufen zum Wasser hin
	var roof := Node3D.new()
	hut.add_child(roof)
	var over := 0.35
	var run := depth + over * 2.0
	roof.position = Vector3((HUT_BACK + HUT_FRONT) * 0.5, (roof_back + roof_front) * 0.5 + 0.06, 0)
	roof.rotation.z = -atan2(roof_back - roof_front, depth)
	var tin := Util.mat(Color(0.82, 0.83, 0.82), 0.45)
	tin.metallic = 0.35
	var tin_dark := Util.mat(Color(0.68, 0.69, 0.69), 0.5)
	tin_dark.metallic = 0.35
	var roof_w := HUT_HALF_Z * 2.0 + over * 2.0
	_b(roof, Vector3(run, 0.02, roof_w), Vector3.ZERO, tin)
	var nz := int(roof_w / 0.2)
	for i in nz + 1:
		_b(roof, Vector3(run, 0.035, 0.05), Vector3(0, 0.02, -roof_w * 0.5 + i * roof_w / nz), tin_dark)
	_b(roof, Vector3(0.06, 0.12, roof_w), Vector3(run * 0.5, -0.04, 0), tin_dark)      # Traufblech vorne
	# Einrichtung: Bank an der Rückwand, Holztruhe vorne rechts, Feuerlöscher, Schaltkasten
	_b(hut, Vector3(0.5, 0.06, 4.4), Vector3(-1.75, 0.45, 0.4), plank)
	_b(hut, Vector3(0.45, 0.42, 4.4), Vector3(-1.78, 0.21, 0.4), _wood_dark)
	_b(hut, Vector3(0.08, 0.5, 4.4), Vector3(-2.75, 0.75, 0.4), plank)                 # Lehne
	_b(hut, Vector3(0.75, 0.6, 1.1), Vector3(2.2, 0.3, 2.6), Util.mat(Color(0.78, 0.68, 0.52)))   # Truhe
	_b(hut, Vector3(0.8, 0.06, 1.15), Vector3(2.2, 0.63, 2.6), plank)                  # Deckel
	var ext := CylinderMesh.new()
	ext.top_radius = 0.08
	ext.bottom_radius = 0.08
	ext.height = 0.5
	var ext_mi := MeshInstance3D.new()
	ext_mi.mesh = ext
	ext_mi.material_override = Util.mat(Color(0.85, 0.08, 0.06), 0.4)
	ext_mi.position = Vector3(HUT_FRONT - 0.15, 0.55, -HUT_HALF_Z + 0.25)
	hut.add_child(ext_mi)                                                              # Feuerlöscher
	_b(hut, Vector3(0.05, 0.08, 0.05), ext_mi.position + Vector3(0, 0.29, 0), _black)
	_b(hut, Vector3(0.12, 0.45, 0.35), Vector3(HUT_BACK + 0.12, 1.5, -2.4), _wood_grey)   # Schaltkasten
	_tire_wall(hut, y)
	# Steuermann ("Hebler") vorne an der Kante, schaut aufs Wasser
	# Steuermann: läuft zwischen Hütte, Treppe und Startsteg, Blick immer auf dem Fahrer
	var hw := func(l: Vector3) -> Vector3: return hut.global_transform * l
	var dock_w := func(de: float, dn: float) -> Vector3:
		var g := Geo.rel_to_game(de, dn)
		return Vector3(g.x, Lake.DOCK_Y, g.y)
	_operator("T2", [hw.call(Vector3(0.2, 0.0, -1.2)), hw.call(Vector3(1.55, 0.0, -1.5)), hw.call(Vector3(2.2, 0.0, -0.3)),
		hw.call(Vector3(2.75, 0.0, 0.0)), hw.call(Vector3(3.95, Lake.DOCK_Y - HUT_DECK_Y, 0.0)),
		dock_w.call(8.6, -0.6), dock_w.call(9.0, 1.4)], people)
	# Gäste auf der Bank – je nach Session 0 bis 3
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shirts := [Color(0.9, 0.3, 0.2), Color(0.2, 0.5, 0.85), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.4)]
	var guests := rng.randi_range(0, 3)
	for gi in guests:
		var gz := -0.6 + gi * 0.75
		var model := "res://assets/characters/guest_f.glb" if gi % 2 == 0 else "res://assets/characters/guest_m.glb"
		if not _human_figure(hut, model, Vector3(-1.75, 0.45, gz), true):
			_person(hut, Vector3(-1.75, 0.45, gz), shirts[gi], true)
		people.append({"pos": hut.global_transform * Vector3(-1.6, 1.15, gz), "pitch": rng.randf_range(1.0, 1.35)})
	_b(hut, Vector3(0.6, 1.0, 0.1), Vector3(-2.55, 1.6, -1.5), Util.mat(Color(0.8, 0.15, 0.12)))  # Rettungsring-Tafel

	# Schwimmender Startsteg (entspricht Lake.DOCK_*, darauf startet der Fahrer):
	# helle Holzfläche, rundherum blau eingefasst (Schwimmkörper)
	var dmin := Lake.DOCK_MIN
	var dmax := Lake.DOCK_MAX
	var dock := Node3D.new()
	add_child(dock)
	var c := Vector3((dmin.x + dmax.x) * 0.5, Lake.DOCK_Y, (dmin.y + dmax.y) * 0.5)
	var sx := dmax.x - dmin.x
	var sz := dmax.y - dmin.y
	var float_blue := Util.mat(Color(0.25, 0.62, 0.88), 0.5)
	_b(dock, Vector3(sx, 0.42, sz), c + Vector3(0, -0.23, 0), float_blue)               # Schwimmkörper
	_b(dock, Vector3(sx - 0.3, 0.05, sz - 0.3), c + Vector3(0, -0.02, 0), Util.mat(Color(0.86, 0.8, 0.66), 0.8))  # Deckfläche
	# Treppe von der Hütte hinunter zum Startsteg
	var stairs := _node(7.15, -2.0, 0.0)
	var steps := 4
	for i in steps:
		var h := lerpf(HUT_DECK_Y, Lake.DOCK_Y, float(i + 1) / (steps + 1))
		_b(stairs, Vector3(0.32, 0.06, 1.3), Vector3(-0.45 + i * 0.3, h - 0.03, 0), plank)
	for side: float in [-1.0, 1.0]:
		Util.beam(stairs, Vector3(-0.65, HUT_DECK_Y - 0.05, side * 0.68), Vector3(0.75, Lake.DOCK_Y - 0.05, side * 0.68), 0.05, _wood_dark)
	# Brettständer am Landende des Startstegs: Leihbretter aus der Brett-Bibliothek stehen hochkant
	var rack := _node(8.2, -3.2, Lake.DOCK_Y)
	for z: float in [-0.9, 0.9]:
		_post(rack, 0.0, z, 0.0, 1.0, _black, 0.04)
	Util.beam(rack, Vector3(0, 0.95, -0.9), Vector3(0, 0.95, 0.9), 0.03, _black)
	for i in 3:
		var bd := BoardLibrary.make(i + 1)
		# Länge senkrecht, Bindungen zeigen zum See (Ost), leicht an die Stange gelehnt
		# (Brettlänge lokal z -> senkrecht, Bindungen lokal +y -> Osten, oben leicht zur Stange geneigt)
		var stand := Basis(Vector3.BACK, 0.12) * Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
		bd.transform = Transform3D(stand, Vector3(0.2, Wakeboard.LENGTH * 0.5 + 0.03, -0.55 + i * 0.55))
		rack.add_child(bd)
	_build_white_dock()
	var east2 := Vector3(Geo.rel_to_game(1, 0).x - Geo.rel_to_game(0, 0).x, 0.0, Geo.rel_to_game(1, 0).y - Geo.rel_to_game(0, 0).y).normalized()
	var st := Geo.rel_to_game(11.6, 1.6)
	waiting_spots.append({"pos": Vector3(st.x, Lake.DOCK_Y, st.y), "face": east2, "kind": "wait_stand"})
	var si := Geo.rel_to_game(10.5, 5.6)
	waiting_spots.append({"pos": Vector3(si.x, 0.18, si.y), "face": east2, "kind": "wait_sit"})


## Hindernis-Abfrage: trifft ein Fahrer (Brett-Radius r) an p einen Steg? Darüber springen geht.
func obstacle_hit(p: Vector3, r: float) -> bool:
	for o: Dictionary in obstacles:
		if p.y > o["top"] + 0.45:
			continue
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), o["a"], o["b"])
		if q.distance_to(Vector2(p.x, p.z)) < o["half_w"] + r:
			return true
	return false


## Weißer Schwimmsteg (Kunststoffmodule, ca. 1,6 m breit) nach dem Luftbild: ein Arm nach Norden
## am Startsteg vorbei, ein langer Arm schräg nach Südosten; daran ein Holzsteg mit zwei Liegestühlen.
func _build_white_dock() -> void:
	var white := Util.mat(Color(0.93, 0.94, 0.93), 0.55)
	var seam := Util.mat(Color(0.55, 0.57, 0.58), 0.6)
	_strip(Vector2(9.7, 8.2), Vector2(9.7, 2.3), 1.6, 0.18, white, seam)
	_strip(Vector2(9.2, -3.3), Vector2(13.2, -14.0), 1.6, 0.18, white, seam)
	# Holzsteg mit Liegestühlen, landseitig am Südost-Arm
	var deck := _node(9.3, -9.6, 0.16, -20.5)
	var dc := Geo.rel_to_game(9.3, -9.6)
	var dx := deck.global_basis.x if deck.is_inside_tree() else deck.basis.x
	obstacles.append({"a": Vector2(dc.x - dx.x * 1.5, dc.y - dx.z * 1.5), "b": Vector2(dc.x + dx.x * 1.5, dc.y + dx.z * 1.5), "half_w": 1.4, "top": 0.2})
	var plank := Util.mat(Color(0.5, 0.43, 0.35))
	_b(deck, Vector3(3.0, 0.3, 2.8), Vector3(0, -0.15, 0), _wood_dark)
	for i in 14:
		_b(deck, Vector3(0.19, 0.04, 2.8), Vector3(-1.4 + i * 0.215, 0.02, 0), plank)
	for z: float in [-0.6, 0.6]:
		_deck_chair(deck, Vector3(0.2, 0.04, z), plank)


## Liegestuhl aus Holz (Adirondack-Stil), Lehne zum Land (lokal -x), Blick zum See.
func _deck_chair(parent: Node3D, at: Vector3, mat: Material) -> void:
	var ch := Node3D.new()
	ch.position = at
	parent.add_child(ch)
	var seat := _b(ch, Vector3(0.6, 0.05, 0.6), Vector3(0.1, 0.3, 0), mat)
	seat.rotation.z = 0.12
	var back := _b(ch, Vector3(0.06, 0.8, 0.6), Vector3(-0.28, 0.62, 0), mat)
	back.rotation.z = -0.45
	for z: float in [-0.32, 0.32]:
		_b(ch, Vector3(0.7, 0.05, 0.1), Vector3(0.05, 0.52, z), mat)          # Armlehnen
		_post(ch, 0.35, z, 0.0, 0.5, mat, 0.03)
		_post(ch, -0.15, z, 0.0, 0.3, mat, 0.03)


## Schwimmender Steg zwischen zwei Punkten (dE, dN): Module à ~2 m mit dunklen Fugen.
## Wird als Hindernis in obstacles eingetragen.
func _strip(a: Vector2, b: Vector2, width: float, top: float, mat: Material, seam_mat: Material) -> void:
	var p0 := Geo.rel_to_game(a.x, a.y)
	var p1 := Geo.rel_to_game(b.x, b.y)
	var d := p1 - p0
	var length := d.length()
	var n := Node3D.new()
	n.position = Vector3((p0.x + p1.x) * 0.5, top, (p0.y + p1.y) * 0.5)
	n.rotation.y = atan2(-d.y, d.x)
	add_child(n)
	obstacles.append({"a": p0, "b": p1, "half_w": width * 0.5, "top": top})
	var modules := maxi(int(round(length / 2.0)), 1)
	var ml := length / modules
	for i in modules:
		var x := -length * 0.5 + (i + 0.5) * ml
		_b(n, Vector3(ml - 0.04, 0.4, width), Vector3(x, -0.2, 0), mat)
		_b(n, Vector3(0.05, 0.38, width + 0.01), Vector3(x + ml * 0.5, -0.2, 0), seam_mat)


## Reifenmauer unter der Vorderkante der Hütte (liegende Autoreifen, gestapelt, zwei Reihen).
func _tire_wall(hut: Node3D, deck_y: float) -> void:
	var tire := TorusMesh.new()
	tire.inner_radius = 0.17
	tire.outer_radius = 0.32
	tire.rings = 16
	tire.ring_segments = 8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tire
	var xf: Array[Transform3D] = []
	for row in 2:
		var x := HUT_FRONT - 0.35 - row * 0.55
		var z := -HUT_HALF_Z - 0.3 + row * 0.3
		while z < HUT_HALF_Z + 0.3:
			var yy := -deck_y - 0.3
			while yy < -0.3:
				xf.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.35, 1.0)), Vector3(x, yy, z)))
				yy += 0.2
			z += 0.62
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Util.mat(Color(0.06, 0.06, 0.065), 0.85)
	hut.add_child(mi)


## Steuermann ("Hebler") an base (lokal, schaut nach +X aufs Wasser) mit der gelben
## Fernsteuerung (ca. 30 cm lang, 10 cm dick): quer vor dem Bauch, an beiden Enden gehalten,
## Not-Aus und Taster oben. Seine Stimme kommt in die Liste crowd (Jubel bei Punkten).
func _operator(terminal: String, path: Array[Vector3], crowd: Array[Dictionary]) -> void:
	operator_paths[terminal] = path
	crowd.append({"pos": path[1] + Vector3(0, 1.6, 0), "pitch": 0.92})


## Realistische Figur (MakeHuman), schaut in lokale +X-Richtung (aufs Wasser).
## sitting: sitzt auf Höhe base.y (Bank), Hände auf den Oberschenkeln;
## sonst stehend, Hände bei hands_at (z. B. an der Fernsteuerung).
func _human_figure(parent: Node3D, path: String, base: Vector3, sitting: bool, hands_at := Vector3.INF, hand_spread := 0.06) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var fig: Node3D = (load(path) as PackedScene).instantiate()
	fig.rotation.y = PI * 0.5                       # Modell schaut nach +Z -> lokal +X
	fig.position = Vector3(base.x, 0.0, base.z) if sitting else base
	parent.add_child(fig)
	var skel := HumanRig.find_skeleton(fig)
	if skel == null:
		return false
	var rig := HumanRig.new(skel)
	var w := func(local: Vector3) -> Vector3: return rig.to_skel(parent.global_transform * local)
	var fwd := Vector3(1, 0, 0)                     # Blickrichtung im Hütten-Raum
	if sitting:
		var pelvis := Vector3(base.x + 0.05, base.y + 0.12, base.z)
		rig.set_pelvis(w.call(pelvis), Basis.IDENTITY)
		rig.bend_spine(Quaternion(Vector3(0, 0, 1), 0.0))
		for side: String in ["l", "r"]:
			var dz := -0.12 if side == "l" else 0.12
			var foot := Vector3(base.x + 0.5, 0.09, base.z + dz * 1.4)
			rig.leg(side, w.call(foot), w.call(pelvis + fwd * 1.2 + Vector3(0, 0.6, dz)))
			var hand := pelvis + fwd * 0.32 + Vector3(0, 0.12, dz * 1.3)
			rig.arm(side, w.call(hand), w.call(pelvis + Vector3(-0.2, 0.2, dz * 4.0)))
	else:
		var rest_pelvis := rig.rest_global("pelvis").origin
		rig.set_pelvis(rest_pelvis, Basis.IDENTITY)
		if hands_at != Vector3.INF:
			for side: String in ["l", "r"]:
				# beide Hände umgreifen die Enden (Faust wie am Griff), Daumen zur Mitte
				var dz := -hand_spread if side == "l" else hand_spread
				var grip_at := hands_at + Vector3(0.0, 0.0, dz)
				var to_center: Vector3 = rig.skeleton.global_transform.basis.inverse() * (parent.global_basis * Vector3(0, 0, -signf(dz)))
				rig.grip(side, w.call(grip_at), to_center, w.call(base + Vector3(-0.1, 0.9, dz * 6.0)))
	rig.look_at(w.call(base + fwd * 20.0 + Vector3(0, 1.5, 0)), 0.6)
	return true


## Einfache Figur, schaut in lokale +X-Richtung (aufs Wasser). sitting: sitzt auf Höhe base.y.
## hands_at: optionaler Punkt, an dem beide Hände etwas halten (lokal).
func _person(parent: Node3D, base: Vector3, shirt: Color, sitting: bool, hands_at := Vector3.INF) -> void:
	var skin := Util.mat(Color(0.88, 0.68, 0.52))
	var pants := Util.mat(Color(0.2, 0.22, 0.3))
	var hip := base + Vector3(0, 0.0 if sitting else 0.85, 0)
	for side: float in [-0.12, 0.12]:
		if sitting:
			Util.beam(parent, hip + Vector3(0.05, 0.05, side), hip + Vector3(0.45, 0.05, side), 0.07, pants)
			Util.beam(parent, hip + Vector3(0.45, 0.05, side), Vector3(base.x + 0.5, base.y - 0.45, base.z + side), 0.06, pants)
		else:
			Util.beam(parent, Vector3(base.x, base.y, base.z + side), hip + Vector3(0, 0, side), 0.07, pants)
	_b(parent, Vector3(0.24, 0.6, 0.4), hip + Vector3(0, 0.33, 0), Util.mat(shirt))
	Util.sphere(parent, 0.12, hip + Vector3(0, 0.78, 0), skin)
	for side: float in [-0.24, 0.24]:
		var hand := hip + Vector3(0.25 if not sitting else 0.2, 0.2, side * 1.1)
		if hands_at != Vector3.INF:
			hand = hands_at + Vector3(-0.03, -0.05, signf(side) * 0.07)
		Util.beam(parent, hip + Vector3(0, 0.6, side), hand, 0.045, skin)


# ---------------------------------------------------------------- T1-Start

func _build_t1_start() -> void:
	# Überdachte Lounge auf dem Plateau
	var y := _ground(8.8, -32.0, 7.0, 6.0)
	var pav := _node(8.8, -32.0, y)
	_b(pav, Vector3(7.2, 0.3, 6.2), Vector3(0, 0.15, 0), _wood_dark)
	for px: float in [-3.3, 0.0, 3.3]:
		for pz: float in [-2.8, 2.8]:
			_post(pav, px, pz, 0.3, 2.9, _wood, 0.09)
	_gable(pav, Vector3(7.8, 0.9, 6.8), Vector3(0, 3.35, 0), _roof)
	_b(pav, Vector3(7.0, 0.9, 0.1), Vector3(0, 0.75, 2.8), _wood)
	for i in 3:
		_b(pav, Vector3(1.8, 0.45, 0.7), Vector3(-2.2 + i * 2.2, 0.53, -1.6), _wood_grey)
		_b(pav, Vector3(1.2, 0.75, 0.8), Vector3(-2.2 + i * 2.2, 0.68, 0.2), _wood)

	# Treppe hinunter zum Steg
	var top := _at(14.0, -32.5)
	var bottom := Vector3(Geo.rel_to_game(19.4, -32.5).x, 0.35, Geo.rel_to_game(19.4, -32.5).y)
	var steps := 10
	for i in steps:
		var t := (i + 0.5) / steps
		var p := top.lerp(bottom, t)
		var s := _b(self, Vector3(1.4, 0.08, 0.6), p, _wood)
		s.rotation.y = _north_yaw
	_railing(self, top + Vector3(0, 0, 0.75), bottom + Vector3(0, 0, 0.75), _wood)

	# Schwimmsteg mit Jetski
	var dock := _node(21.9, -29.5, Lake.DOCK_T1_Y - 0.15)
	_b(dock, Vector3(4.4, 0.3, 7.0), Vector3.ZERO, _wood)
	_b(dock, Vector3(4.6, 0.32, 0.25), Vector3(0, -0.02, 3.5), _blue)
	_b(dock, Vector3(0.25, 0.32, 7.0), Vector3(2.2, -0.02, 0), _blue)
	var jet := Node3D.new()
	jet.position = Vector3(0.4, 0.35, -1.5)
	dock.add_child(jet)
	_b(jet, Vector3(1.1, 0.5, 2.9), Vector3.ZERO, _white)
	_b(jet, Vector3(0.9, 0.3, 1.0), Vector3(0, 0.35, 0.2), Util.mat(Color(0.1, 0.2, 0.35)))
	# Steuermann für T1 am landseitigen Ende des Stegs
	var dw := func(l: Vector3) -> Vector3: return dock.global_transform * l
	_operator("T1", [dw.call(Vector3(-1.5, 0.15, -2.6)), dw.call(Vector3(-1.6, 0.15, 0.5)),
		dw.call(Vector3(-0.6, 0.15, 2.6)), dw.call(Vector3(1.2, 0.15, 2.7))], people_t1)
	# wartender Fahrer am T1-Steg: sitzt an der Seekante, links am Rand (nicht im Weg des Startenden)
	var east := dock.global_basis.x
	waiting_spots.append({"pos": dw.call(Vector3(2.2, 0.15, -1.0)), "face": east, "kind": "wait_sit"})


# ---------------------------------------------------------------- Hauptgebäude

func _build_main_building() -> void:
	# Zweistöckiges Hauptgebäude mit dunkler Plakatfront
	var y := _ground(-21.3, -32.2, 7.0, 6.3)
	var hb := _node(-21.3, -32.2, y)
	_b(hb, Vector3(7.0, 3.0, 6.3), Vector3(0, 1.5, 0), _wood_grey)
	_b(hb, Vector3(6.2, 2.8, 5.4), Vector3(0, 4.4, 0.3), _wood)
	_b(hb, Vector3(6.6, 0.2, 5.9), Vector3(0, 5.9, 0.3), _roof)
	var poster := Util.mat(Color(0.12, 0.13, 0.15), 0.4)
	_b(hb, Vector3(5.8, 2.3, 0.08), Vector3(0, 4.4, -2.42), poster)
	_b(hb, Vector3(1.6, 1.8, 0.09), Vector3(-1.3, 4.4, -2.45), Util.mat(Color(0.85, 0.87, 0.9)))
	_b(hb, Vector3(1.4, 1.8, 0.09), Vector3(1.4, 4.4, -2.45), Util.mat(Color(0.6, 0.65, 0.72)))
	_b(hb, Vector3(3.0, 1.0, 0.08), Vector3(-1.5, 1.8, -3.17), Util.mat(Color(0.3, 0.32, 0.3)))   # Theke
	var dish := Util.sphere(hb, 0.35, Vector3(2.4, 6.6, 1.5), _white)
	dish.scale = Vector3(1, 1, 0.35)
	_post(hb, 2.4, 1.5, 5.9, 6.4, _black, 0.03)

	# Holzpalisade entlang der Rückseite des Strandes (Richtung T1-Mast)
	var a := _at(-17.5, -29.4)
	var b := _at(-2.5, -28.8)
	var n := 16
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var plank := _b(self, Vector3(0.95, 2.4, 0.15), Vector3(p.x, p.y + 1.2, p.z), _wood_grey)
		plank.rotation.y = atan2(-(b - a).x, -(b - a).z) + PI * 0.5
	# Bambus-Sichtschutz davor
	for i in 4:
		var p := _at(-13.0 + i * 1.6, -27.6)
		var sc := _b(self, Vector3(1.5, 1.9, 0.08), p + Vector3(0, 0.95, 0), Util.mat(Color(0.78, 0.66, 0.42)))
		sc.rotation.y = _north_yaw
	# Bar-Anbau westlich mit Markise
	var bar := _node(-28.5, -30.5, _ground(-28.5, -30.5, 6.0, 4.0))
	_b(bar, Vector3(6.0, 2.6, 4.0), Vector3(0, 1.3, 0), _wood_dark)
	_b(bar, Vector3(6.4, 0.12, 2.0), Vector3(0, 2.4, -2.6), Util.mat(Color(0.25, 0.27, 0.28)))
	_b(bar, Vector3(4.0, 1.1, 0.5), Vector3(0, 0.55, -2.3), _wood)

	# Weißes Partyzelt
	var tent := _node(-40.2, -37.4, _ground(-40.2, -37.4, 11.0, 7.0))
	_b(tent, Vector3(11.0, 2.3, 7.0), Vector3(0, 1.15, 0), _white)
	_gable(tent, Vector3(11.2, 1.3, 7.2), Vector3(0, 2.95, 0), _white)

	# Pickup
	var car := _node(-33.5, -29.5, _ground(-33.5, -29.5, 2.0, 5.0), 75.0)
	_b(car, Vector3(1.9, 0.9, 5.2), Vector3(0, 0.75, 0), _black)
	_b(car, Vector3(1.8, 0.7, 2.2), Vector3(0, 1.5, -0.6), _black)
	for wx: float in [-0.9, 0.9]:
		for wz: float in [-1.7, 1.7]:
			_b(car, Vector3(0.3, 0.7, 0.7), Vector3(wx, 0.35, wz), Util.mat(Color(0.03, 0.03, 0.03)))

	# Holzschuppen am Strand
	var shed := _node(-19.3, -2.4, _ground(-19.3, -2.4, 4.5, 4.2))
	_b(shed, Vector3(4.5, 2.4, 4.2), Vector3(0, 1.2, 0), _wood)
	_shed_roof(shed, 4.9, 4.6, 2.4, 2.8, _roof)


# ---------------------------------------------------------------- Strand

func _build_beach_items() -> void:
	# Palmen
	for p: Vector2 in [Vector2(-19.9, -14.2), Vector2(-17.0, -13.8), Vector2(-21.3, -18.7), Vector2(-12.9, -19.2),
			Vector2(-9.5, -12.6), Vector2(-6.2, -20.1), Vector2(-1.4, -8.8), Vector2(-1.0, -16.9), Vector2(-6.5, -4.5)]:
		_palm(_at(p.x, p.y), absf(p.x * 7.3 + p.y))
	# Schwarze Pagodenzelte bei der Bar
	for p: Vector2 in [Vector2(-13.4, -22.5), Vector2(-9.4, -23.6)]:
		var t := _node(p.x, p.y, _ground(p.x, p.y, 3.0, 3.0), 45.0)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 2.3
		cm.height = 1.1
		cm.radial_segments = 4
		cone.mesh = cm
		cone.material_override = _black
		cone.position = Vector3(0, 2.75, 0)
		t.add_child(cone)
		for px: float in [-1.1, 1.1]:
			for pz: float in [-1.1, 1.1]:
				_post(t, px, pz, 0.0, 2.2, Util.mat(Color(0.7, 0.7, 0.7)), 0.03)
		_b(t, Vector3(1.4, 0.75, 0.8), Vector3(0, 0.37, 0), _wood)
	# Liegestühle und Sitzsäcke
	var lounger := Util.mat(Color(0.85, 0.82, 0.75))
	for p: Vector2 in [Vector2(-15.5, -7.5), Vector2(-13.8, -7.0), Vector2(-4.5, -12.5), Vector2(-3.0, -12.0),
			Vector2(-24.0, -10.0), Vector2(-25.5, -10.5)]:
		var l := _node(p.x, p.y, _ground(p.x, p.y, 1.0, 2.0), 20.0)
		_b(l, Vector3(0.7, 0.3, 1.9), Vector3(0, 0.25, 0), lounger)
		var back := _b(l, Vector3(0.7, 0.8, 0.08), Vector3(0, 0.6, 0.85), lounger)
		back.rotation.x = 0.5
	# Beachflags (Liquid Force / Slingshot)
	var flag_cols := [Color(0.08, 0.08, 0.1), Color(0.85, 0.2, 0.12), Color(0.95, 0.45, 0.12)]
	var i := 0
	for p: Vector2 in [Vector2(-5.5, -6.0), Vector2(-9.0, -9.5), Vector2(-14.0, -9.0), Vector2(-3.0, -22.5), Vector2(0.5, -13.0)]:
		var base := _at(p.x, p.y)
		Util.beam(self, base, base + Vector3(0, 3.6, 0), 0.03, _black)
		var fl := Util.box(self, Vector3(0.6, 2.6, 0.03), base + Vector3(0.3, 2.2, 0), Util.mat(flag_cols[i % 3], 0.8))
		fl.rotation.y = _north_yaw + 0.6 * i
		i += 1
	# Australien-Fahne am Fahnenmast (wie auf dem Foto)
	var fp := _at(-3.0, 2.0)
	Util.beam(self, fp, fp + Vector3(0, 6.0, 0), 0.04, _white)
	Util.box(self, Vector3(1.5, 0.9, 0.03), fp + Vector3(0.75, 5.5, 0), Util.mat(Color(0.1, 0.2, 0.55)))
	# Seil-Absperrung entlang der Uferkante
	var rope_mat := Util.mat(Color(0.75, 0.7, 0.6))
	var prev := Vector3.ZERO
	for k in 9:
		var p := _at(-1.0 - k * 2.0, -6.0 - k * 2.2)
		_post(self, p.x, p.z, p.y, p.y + 0.9, _wood, 0.05)
		if k > 0:
			Util.beam(self, prev + Vector3(0, 0.8, 0), p + Vector3(0, 0.8, 0), 0.015, rope_mat)
		prev = p


func _palm(base: Vector3, seed_value: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value * 1000.0)
	var trunk_mat := Util.mat(Color(0.5, 0.4, 0.3))
	var leaf_mat := Util.mat(Color(0.25, 0.45, 0.18))
	var h := rng.randf_range(2.2, 3.4)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var mid := base + Vector3(0, h * 0.5, 0) + lean * 0.3
	var top := base + Vector3(0, h, 0) + lean
	Util.beam(self, base, mid, 0.13, trunk_mat)
	Util.beam(self, mid, top, 0.11, trunk_mat)
	for k in 8:
		var ang := TAU * k / 8.0 + rng.randf() * 0.3
		var leaf := Util.box(self, Vector3(0.35, 0.03, 1.5), top, leaf_mat)
		leaf.rotation = Vector3(0.55, ang, 0)
		leaf.position = top + Vector3(sin(ang), -0.35, cos(ang)) * 0.65


# ---------------------------------------------------------------- Wasser

func _build_water_items() -> void:
	# Rotes Schlauchboot (Rettungsboot) am weißen Steg, Bug nach Norden, Außenborder hinten
	var boat := _node(11.4, 5.4, 0.12, 4.0)
	var rubber := Util.mat(Color(0.82, 0.16, 0.2), 0.55)
	for side: float in [-1.0, 1.0]:
		var tube := CapsuleMesh.new()
		tube.radius = 0.22
		tube.height = 3.0
		var t := MeshInstance3D.new()
		t.mesh = tube
		t.material_override = rubber
		t.rotation.x = PI * 0.5
		t.position = Vector3(side * 0.55, 0.0, 0.1)
		boat.add_child(t)
	Util.beam(boat, Vector3(-0.55, 0.0, -1.35), Vector3(0.55, 0.0, -1.35), 0.22, rubber)   # Bug
	_b(boat, Vector3(1.1, 0.06, 2.8), Vector3(0, -0.15, 0.1), Util.mat(Color(0.35, 0.35, 0.37), 0.7))  # Boden
	_b(boat, Vector3(1.0, 0.35, 0.06), Vector3(0, 0.0, 1.55), _wood_dark)                    # Spiegel
	_b(boat, Vector3(0.28, 0.4, 0.35), Vector3(0, 0.35, 1.75), _black)                       # Außenborder
	_b(boat, Vector3(0.08, 0.5, 0.1), Vector3(0, -0.05, 1.82), _black)
	_b(boat, Vector3(1.0, 0.05, 0.3), Vector3(0, 0.1, -0.1), _wood_grey)                     # Sitzbank
	# Gelbe Bojenleine (Abgrenzung zum Badebereich im Norden): ca. 2 m lange gelbe
	# Schwimmzylinder, aneinandergekettet
	var tube := CylinderMesh.new()
	tube.top_radius = 0.13
	tube.bottom_radius = 0.13
	tube.height = 1.9
	tube.radial_segments = 10
	tube.rings = 1
	var yellow := Util.mat(Color(1.0, 0.82, 0.1), 0.45)
	var link_mat := Util.mat(Color(0.15, 0.15, 0.15), 0.6)
	var pts := [Vector2(4.0, 11.0), Vector2(22.0, 26.0), Vector2(60.0, 55.0), Vector2(110.0, 92.0)]
	for s in pts.size() - 1:
		var a: Vector2 = pts[s]
		var b: Vector2 = pts[s + 1]
		var n := int(a.distance_to(b) / 2.0)
		for k in n:
			var p0 := Geo.rel_to_game(a.lerp(b, float(k) / n).x, a.lerp(b, float(k) / n).y)
			var p1 := Geo.rel_to_game(a.lerp(b, float(k + 1) / n).x, a.lerp(b, float(k + 1) / n).y)
			if Geo.height(p0.x, p0.y) > -0.1 or Geo.height(p1.x, p1.y) > -0.1:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = tube
			mi.material_override = yellow
			var t := Util.beam_transform(Vector3(p0.x, 0.03, p0.y), Vector3(p1.x, 0.03, p1.y), 1.0)
			t.basis = t.basis.orthonormalized()          # Zylinderlänge bleibt 1,9 m, nur ausrichten
			mi.transform = t
			add_child(mi)
			Util.sphere(self, 0.07, Vector3(p1.x, 0.03, p1.y), link_mat)    # Kettenglied
