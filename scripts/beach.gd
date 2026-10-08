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

## T2-Startblock nach dem Umbau (Fotos Herbst 2026): Holzplattform am Ufer, an der Seeseite mit
## grauen Dielen verkleidet und auf Stahlpfosten; davor eine Mauer aus Beton-Pflanzringen mit
## Sandsäcken. Darauf hinten (Land) ein Raum mit Holzbrüstung und Folienfenstern unter einem
## flachen Satteldach (dunkle Blechkante, Holzuntersicht, Markise zum See), vorne eine offene
## Terrasse mit Geländer und Bank. Eine Stahltreppe führt an der Südostecke hinunter auf einen
## Holzsteg neben dem schwimmenden Startsteg; am Startsteg steht der schwarze Brettständer.
const HUT_DECK_Y := 1.35         # Deck der Plattform über dem Wasserspiegel
const HUT_BACK := -2.9           # Hütten-Raum (lokal x = Ost): Rückseite (Land) ...
const HUT_FRONT := 2.7           # ... Vorderkante über dem Wasser
const HUT_HALF_Z := 3.3          # halbe Länge Nord-Süd (lokal z = Süd)
const CAB_FRONT := 0.4           # Raum: Seeseite (x); Rückseite = HUT_BACK
const CAB_N := -1.0              # Raum: Nordwand (z); Südwand = HUT_HALF_Z, nördlich davon Terrasse
const ROOF_W := -3.3             # Dach: Westtraufe ...
const ROOF_E := 1.5              # ... Osttraufe (weit über die Terrasse)
const ROOF_N := -1.8             # Giebelseiten Nord/Süd
const ROOF_S := 3.9
const EAVE_Y := 2.45             # Traufhöhe über dem Deck
const RIDGE_Y := 3.0             # Firsthöhe (First läuft Nord-Süd)
const STAIR_X0 := 1.5            # Treppe an der Südkante zwischen x0 und x1
const STAIR_X1 := 2.55
const JETTY_Y := 0.42            # Holzsteg unter der Treppe (Oberkante)

func _build_t2_start() -> void:
	var y := HUT_DECK_Y
	var hut := _node(3.9, -2.0, y)
	var grey := Util.mat(Color(0.56, 0.53, 0.49))        # verwitterte Dielen (Deck, Verkleidung, Geländer)
	var grey_dark := Util.mat(Color(0.4, 0.38, 0.35))
	var cab := Util.mat(Color(0.63, 0.48, 0.34))         # Raum: wärmeres, frischeres Holz
	var cab_dark := Util.mat(Color(0.5, 0.37, 0.26))
	var steel := Util.mat(Color(0.66, 0.68, 0.7), 0.45)  # verzinkt
	steel.metallic = 0.5
	var iron := Util.mat(Color(0.2, 0.21, 0.22), 0.6)
	var depth := HUT_FRONT - HUT_BACK
	# Deck aus Dielen (laufen Ost-West), darunter Unterbau
	var n_planks := int(HUT_HALF_Z * 2.0 / 0.15)
	for i in n_planks:
		var z := -HUT_HALF_Z + (i + 0.5) * HUT_HALF_Z * 2.0 / n_planks
		_b(hut, Vector3(depth + 0.06, 0.05, 0.135), Vector3((HUT_BACK + HUT_FRONT) * 0.5, -0.025, z), grey)
	_b(hut, Vector3(depth - 0.1, 0.2, HUT_HALF_Z * 2.0 - 0.1), Vector3((HUT_BACK + HUT_FRONT) * 0.5, -0.15, 0), grey_dark)
	# Stahlpfosten unter dem Deck bis in den Boden
	var px := HUT_BACK + 0.4
	while px < HUT_FRONT:
		for z: float in [-HUT_HALF_Z + 0.3, 0.0, HUT_HALF_Z - 0.3]:
			Util.beam(hut, Vector3(px, -y - 0.8, z), Vector3(px, -0.25, z), 0.05, steel)
		px += 1.6
	# Verkleidung aus waagerechten Dielen: Seeseite und Südost-Ecke bis knapp über die Ringe,
	# Nordseite bis in den Hang und darüber als brusthohe Wand
	_cladding(hut, Vector3(HUT_FRONT + 0.02, 0, -HUT_HALF_Z), Vector3(HUT_FRONT + 0.02, 0, HUT_HALF_Z), -0.95, 0.0, grey)
	_cladding(hut, Vector3(CAB_FRONT, 0, HUT_HALF_Z + 0.02), Vector3(HUT_FRONT, 0, HUT_HALF_Z + 0.02), -1.0, 0.0, grey)
	_cladding(hut, Vector3(HUT_BACK, 0, -HUT_HALF_Z - 0.02), Vector3(HUT_FRONT + 0.04, 0, -HUT_HALF_Z - 0.02), -y - 0.2, 1.05, grey)
	_b(hut, Vector3(depth + 0.1, 0.05, 0.16), Vector3((HUT_BACK + HUT_FRONT) * 0.5 + 0.02, 1.08, -HUT_HALF_Z), grey)  # Abdeckbrett
	_cab_room(hut, cab, cab_dark, iron)
	_cab_roof(hut, cab, iron)
	# Terrasse: Geländer zum See und an der Südkante bis zur Treppe (Pfosten, breiter Handlauf, Seil)
	_deck_rail(hut, Vector3(HUT_FRONT - 0.06, 0, -HUT_HALF_Z + 0.1), Vector3(HUT_FRONT - 0.06, 0, HUT_HALF_Z - 0.06), grey, steel)
	_deck_rail(hut, Vector3(CAB_FRONT + 0.05, 0, HUT_HALF_Z - 0.06), Vector3(STAIR_X0 - 0.08, 0, HUT_HALF_Z - 0.06), grey, steel)
	# hohe Lehne am Nordende der Terrasse (Windschutz)
	for z: float in [-HUT_HALF_Z + 0.1, -1.6]:
		_post(hut, HUT_FRONT - 0.3, z, 0.0, 1.75, grey, 0.045)
	_b(hut, Vector3(0.05, 0.3, 1.8), Vector3(HUT_FRONT - 0.3, 1.6, (-HUT_HALF_Z - 1.5) * 0.5), grey)
	# Bank vor dem Raum, Blick auf den See (Rücken an der Brüstung)
	_b(hut, Vector3(0.42, 0.05, 3.2), Vector3(CAB_FRONT + 0.25, 0.45, 1.6), cab)
	for z: float in [0.1, 1.6, 3.1]:
		_b(hut, Vector3(0.36, 0.42, 0.05), Vector3(CAB_FRONT + 0.25, 0.21, z), cab_dark)
	# Kleinkram: graue Kiste an der Kante, Feuerlöscher am Pfosten, Liegestuhl zusammengeklappt an der Treppe
	_b(hut, Vector3(0.4, 0.24, 0.3), Vector3(HUT_FRONT - 0.35, 0.12, 0.6), Util.mat(Color(0.6, 0.62, 0.64), 0.6))
	var ext := CylinderMesh.new()
	ext.top_radius = 0.08
	ext.bottom_radius = 0.08
	ext.height = 0.5
	var ext_mi := MeshInstance3D.new()
	ext_mi.mesh = ext
	ext_mi.material_override = Util.mat(Color(0.85, 0.08, 0.06), 0.4)
	ext_mi.position = Vector3(CAB_FRONT + 0.12, 0.3, CAB_N - 0.15)
	hut.add_child(ext_mi)
	_b(hut, Vector3(0.05, 0.08, 0.05), ext_mi.position + Vector3(0, 0.29, 0), _black)
	_folded_chair(hut, Vector3(STAIR_X0 - 0.45, 0.0, HUT_HALF_Z - 0.2))
	_shore_wall(hut, y)
	_tire_row(hut, y)
	_t2_stairs(hut, iron, steel)

	# Steuermann: läuft zwischen Raum, Terrasse, Treppe, Holzsteg und Startsteg, Blick immer auf dem Fahrer
	var hw := func(l: Vector3) -> Vector3: return hut.global_transform * l
	var dock_w := func(de: float, dn: float, h: float) -> Vector3:
		var g := Geo.rel_to_game(de, dn)
		return Vector3(g.x, h, g.y)
	var sx := (STAIR_X0 + STAIR_X1) * 0.5
	_operator("T2", [hw.call(Vector3(CAB_FRONT + 0.4, 0.0, CAB_N + 0.4)), hw.call(Vector3(1.9, 0.0, -1.6)),
		hw.call(Vector3(sx, 0.0, 1.4)), hw.call(Vector3(sx, 0.0, HUT_HALF_Z - 0.2)),
		hw.call(Vector3(sx, JETTY_Y - HUT_DECK_Y, HUT_HALF_Z + 1.6)), dock_w.call(7.8, -5.6, JETTY_Y),
		dock_w.call(8.6, -3.3, Lake.DOCK_Y), dock_w.call(8.6, -0.6, Lake.DOCK_Y), dock_w.call(9.0, 1.4, Lake.DOCK_Y)], people)
	# Gäste auf der Bank vor dem Raum – je nach Session 0 bis 3
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shirts := [Color(0.9, 0.3, 0.2), Color(0.2, 0.5, 0.85), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 0.4)]
	var guests := rng.randi_range(0, 3)
	for gi in guests:
		var gz := 0.6 + gi * 0.8
		var at := Vector3(CAB_FRONT + 0.2, 0.47, gz)
		var model := "res://assets/characters/guest_f.glb" if gi % 2 == 0 else "res://assets/characters/guest_m.glb"
		if not _human_figure(hut, model, at, true):
			_person(hut, at, shirts[gi], true)
		people.append({"pos": hut.global_transform * Vector3(CAB_FRONT + 0.35, 1.15, gz), "pitch": rng.randf_range(1.0, 1.35)})

	# Schwimmender Startsteg (entspricht Lake.DOCK_*, darauf startet der Fahrer):
	# sandfarbene Fläche, rundherum blau eingefasst (Schwimmkörper)
	var dmin := Lake.DOCK_MIN
	var dmax := Lake.DOCK_MAX
	var dock := Node3D.new()
	add_child(dock)
	var c := Vector3((dmin.x + dmax.x) * 0.5, Lake.DOCK_Y, (dmin.y + dmax.y) * 0.5)
	var dsx := dmax.x - dmin.x
	var dsz := dmax.y - dmin.y
	var float_blue := Util.mat(Color(0.25, 0.62, 0.88), 0.5)
	_b(dock, Vector3(dsx, 0.42, dsz), c + Vector3(0, -0.23, 0), float_blue)               # Schwimmkörper
	_b(dock, Vector3(dsx - 0.3, 0.05, dsz - 0.3), c + Vector3(0, -0.02, 0), Util.mat(Color(0.86, 0.76, 0.52), 0.8))  # Deckfläche
	_t2_jetty()
	_board_rack()
	_build_white_dock()
	var east2 := Vector3(Geo.rel_to_game(1, 0).x - Geo.rel_to_game(0, 0).x, 0.0, Geo.rel_to_game(1, 0).y - Geo.rel_to_game(0, 0).y).normalized()
	var st := Geo.rel_to_game(11.6, 1.6)
	waiting_spots.append({"pos": Vector3(st.x, Lake.DOCK_Y, st.y), "face": east2, "kind": "wait_stand"})
	# sitzende Fahrerin an der Ostkante des Südost-Arms (weißer Steg), Beine zum See
	var arm_n := Vector2(0.937, 0.35)                    # Normale des Arms (9.2,-3.3)->(13.2,-14.0) nach Osten
	var si := Geo.rel_to_game(10.4 + arm_n.x * 0.78, -6.51 + arm_n.y * 0.78)
	var sf := Geo.rel_to_game(arm_n.x, arm_n.y)
	waiting_spots.append({"pos": Vector3(si.x, 0.18, si.y), "face": Vector3(sf.x, 0.0, sf.y).normalized(), "kind": "wait_sit"})


## Wand aus waagerechten Dielen von a nach b (lokal, a.y/b.y ignoriert) zwischen Höhe y0 und y1.
func _cladding(parent: Node3D, a: Vector3, b: Vector3, y0: float, y1: float, mat: Material) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	var n := Node3D.new()
	n.position = Vector3((a.x + b.x) * 0.5, 0, (a.z + b.z) * 0.5)
	n.rotation.y = atan2(-d.z, d.x)
	parent.add_child(n)
	var rows := maxi(int(round((y1 - y0) / 0.15)), 1)
	var h := (y1 - y0) / rows
	for i in rows:
		_b(n, Vector3(length, h - 0.015, 0.03), Vector3(0, y0 + (i + 0.5) * h, 0), mat)


## Terrassengeländer: Vierkantpfosten, breiter Handlauf, gespanntes Stahlseil.
func _deck_rail(parent: Node3D, a: Vector3, b: Vector3, mat: Material, wire: Material) -> void:
	var n := maxi(int(ceil(a.distance_to(b) / 1.3)), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_post(parent, p.x, p.z, 0.0, 1.0, mat, 0.045)
	var d := b - a
	var rail := _b(parent, Vector3(d.length() + 0.1, 0.04, 0.14), (a + b) * 0.5 + Vector3(0, 1.02, 0), mat)
	rail.rotation.y = atan2(-d.z, d.x)
	Util.beam(parent, a + Vector3(0, 0.55, 0), b + Vector3(0, 0.55, 0), 0.006, wire)


## Raum hinten auf der Plattform: Brüstung aus Brettern, darüber Folienfenster in Holzrahmen,
## oben ein Brettband; Tür zur Terrasse an der Nordostecke (offen). Drinnen Bank, Westen, Schaltkasten.
func _cab_room(hut: Node3D, wood: Material, wood_dark: Material, iron: Material) -> void:
	var pvc := Util.mat(Color(0.86, 0.9, 0.93, 0.16), 0.08)
	pvc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pvc.metallic = 0.3
	pvc.cull_mode = BaseMaterial3D.CULL_DISABLED
	var x0 := HUT_BACK + 0.04
	var x1 := CAB_FRONT
	var z0 := CAB_N
	var z1 := HUT_HALF_Z - 0.04
	var door := z0 + 0.85                     # Türöffnung an der Ostseite zwischen z0 und door
	var walls: Array = [                      # [a, b] je Wand
		[Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)],
		[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x1, 0, door), Vector3(x1, 0, z1)]]
	for w: Array in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		_cladding(hut, a, b, 0.0, 0.9, wood)                     # Brüstung
		_cladding(hut, a, b, 2.02, 2.42, wood)                   # Brettband unterm Dach
		var d := b - a
		var sheet := _b(hut, Vector3(d.length(), 1.1, 0.01), (a + b) * 0.5 + Vector3(0, 1.46, 0), pvc)
		sheet.rotation.y = atan2(-d.z, d.x)
		var rail := _b(hut, Vector3(d.length(), 0.05, 0.1), (a + b) * 0.5 + Vector3(0, 0.92, 0), wood_dark)
		rail.rotation.y = atan2(-d.z, d.x)                       # Brüstungsabdeckung
		var n := maxi(int(ceil(d.length() / 1.7)), 1)
		for i in n + 1:                                          # Pfosten
			var p := a.lerp(b, float(i) / n)
			_post(hut, p.x, p.z, 0.0, 2.45, wood_dark, 0.05)
	_post(hut, x1, z0, 0.0, 2.45, wood_dark, 0.05)
	_cladding(hut, Vector3(x1, 0, z0), Vector3(x1, 0, door), 2.02, 2.42, wood)   # Sturz über der Tür
	# offene Falttür aus Folie im Holzrahmen, nach außen aufgeschwenkt
	var dn := Node3D.new()
	dn.position = Vector3(x1 + 0.03, 0, z0 + 0.02)
	dn.rotation.y = deg_to_rad(-65.0)
	hut.add_child(dn)
	for zz: float in [0.03, 0.8]:
		_b(dn, Vector3(0.05, 2.0, 0.05), Vector3(0, 1.0, zz), wood_dark)
	for yy: float in [0.02, 0.95, 1.98]:
		_b(dn, Vector3(0.05, 0.05, 0.82), Vector3(0, yy, 0.415), wood_dark)
	_b(dn, Vector3(0.01, 1.9, 0.75), Vector3(0, 1.0, 0.415), pvc)
	# Giebeldreiecke Nord/Süd über dem Brettband bis unters Dach (senkrechte Bretter)
	var ridge_x := (ROOF_W + ROOF_E) * 0.5
	for z: float in [z0, z1]:
		var x := x0
		while x < x1 - 0.05:
			var top := _roof_y(x + 0.07) - 0.16
			if top > 2.45:
				_b(hut, Vector3(0.14, top - 2.42, 0.03), Vector3(x + 0.07, (top + 2.42) * 0.5, z), wood)
			x += 0.155
	Util.beam(hut, Vector3(ridge_x, RIDGE_Y - 0.2, z0), Vector3(ridge_x, RIDGE_Y - 0.2, z1), 0.07, wood_dark)  # Firstpfette
	# Drinnen: Bank an der Westwand, Schwimmwesten an der Südwand, Schaltkasten, Heizstrahler, Lautsprecher
	_b(hut, Vector3(0.45, 0.05, 3.6), Vector3(x0 + 0.3, 0.45, 1.2), wood)
	_b(hut, Vector3(0.4, 0.42, 3.6), Vector3(x0 + 0.3, 0.21, 1.2), wood_dark)
	var vests := [Color(0.9, 0.25, 0.2), Color(0.95, 0.5, 0.15), Color(0.85, 0.35, 0.55), Color(0.2, 0.35, 0.75),
		Color(0.95, 0.75, 0.15), Color(0.75, 0.2, 0.35), Color(0.3, 0.3, 0.35)]
	for i in vests.size():
		_b(hut, Vector3(0.32, 0.5, 0.09), Vector3(x0 + 0.5 + i * 0.36, 1.4, z1 - 0.12), Util.mat(vests[i], 0.8))
	Util.beam(hut, Vector3(x0 + 0.3, 1.68, z1 - 0.1), Vector3(x0 + 3.0, 1.68, z1 - 0.1), 0.012, iron)  # Kleiderstange
	_b(hut, Vector3(0.12, 0.45, 0.35), Vector3(x0 + 0.08, 1.5, z0 + 0.6), _wood_grey)            # Schaltkasten
	_b(hut, Vector3(0.14, 0.06, 0.9), Vector3(x1 + 0.35, 2.36, 1.0), iron)                         # Heizstrahler
	_b(hut, Vector3(0.02, 0.03, 0.8), Vector3(x1 + 0.35, 2.32, 1.0), Util.mat(Color(0.9, 0.35, 0.1), 0.5))
	_b(hut, Vector3(0.2, 0.3, 0.2), Vector3(x1 + 0.14, 2.15, z0 + 1.5), _black)                     # Lautsprecher
	# T2-Schild an der Südwestecke
	var sign_mi := _b(hut, Vector3(0.45, 0.8, 0.03), Vector3(x0 + 0.3, 1.55, z1 + 0.06), _black)
	var lbl := Label3D.new()
	lbl.text = "T2"
	lbl.font_size = 96
	lbl.pixel_size = 0.004
	lbl.outline_size = 0
	lbl.modulate = Color(0.95, 0.95, 0.95)
	lbl.position = sign_mi.position + Vector3(0, 0.18, 0.02)
	hut.add_child(lbl)


## Höhe der Dachunterkante über dem Deck an der Stelle x (lokal).
func _roof_y(x: float) -> float:
	var ridge_x := (ROOF_W + ROOF_E) * 0.5
	var half := (ROOF_E - ROOF_W) * 0.5
	return lerpf(RIDGE_Y, EAVE_Y, clampf(absf(x - ridge_x) / half, 0.0, 1.0))


## Flaches Satteldach, First Nord-Süd: dunkle Blechdeckung und -kanten, Holzuntersicht mit
## Sparren, großer Überstand über die Terrasse; Markisenkasten an der Osttraufe.
func _cab_roof(hut: Node3D, wood: Material, iron: Material) -> void:
	var top := Util.mat(Color(0.24, 0.25, 0.26), 0.55)
	top.metallic = 0.3
	var under := Util.mat(Color(0.7, 0.57, 0.42))
	var ridge_x := (ROOF_W + ROOF_E) * 0.5
	var half := (ROOF_E - ROOF_W) * 0.5
	var rise := RIDGE_Y - EAVE_Y
	var slope := sqrt(half * half + rise * rise)
	var w := ROOF_S - ROOF_N
	var zc := (ROOF_N + ROOF_S) * 0.5
	for side: float in [-1.0, 1.0]:                  # -1 = Westhälfte, +1 = Osthälfte
		var n := Node3D.new()
		n.position = Vector3(ridge_x + side * half * 0.5, (RIDGE_Y + EAVE_Y) * 0.5 + 0.08, zc)
		n.rotation.z = -side * atan2(rise, half)
		hut.add_child(n)
		_b(n, Vector3(slope + 0.04, 0.05, w), Vector3(0, 0.05, 0), top)
		_b(n, Vector3(slope, 0.04, w - 0.04), Vector3(0, 0.0, 0), under)
		for z: float in [-w * 0.5, w * 0.5]:          # Ortgangblech
			_b(n, Vector3(slope + 0.04, 0.2, 0.03), Vector3(0, 0.0, z), iron)
		_b(n, Vector3(0.03, 0.2, w + 0.03), Vector3(side * (slope * 0.5 + 0.02), 0.0, 0), iron)   # Traufblech
		var k := int(w / 0.62)
		for i in k + 1:                               # Sparren
			_b(n, Vector3(slope, 0.12, 0.06), Vector3(0, -0.08, -w * 0.5 + 0.1 + i * (w - 0.2) / k), wood)
	# Markise (eingefahren) unter der Osttraufe
	var cas := Util.mat(Color(0.5, 0.51, 0.52), 0.5)
	_b(hut, Vector3(0.16, 0.14, 4.8), Vector3(ROOF_E - 0.15, EAVE_Y - 0.08, 1.2), cas)
	_b(hut, Vector3(0.02, 0.12, 4.7), Vector3(ROOF_E - 0.06, EAVE_Y - 0.2, 1.2), Util.mat(Color(0.62, 0.62, 0.6), 0.9))


## Zusammengeklappter Liegestuhl (rosa Stoff mit gelber Raute), ans Geländer gelehnt.
func _folded_chair(parent: Node3D, at: Vector3) -> void:
	var ch := Node3D.new()
	ch.position = at
	ch.rotation.x = -0.12
	parent.add_child(ch)
	var frame := Util.mat(Color(0.45, 0.28, 0.2))
	for x: float in [-0.27, 0.27]:
		_b(ch, Vector3(0.04, 1.15, 0.03), Vector3(x, 0.57, 0), frame)
	_b(ch, Vector3(0.5, 1.0, 0.01), Vector3(0, 0.6, 0.02), Util.mat(Color(0.94, 0.82, 0.8), 0.9))
	var dia := _b(ch, Vector3(0.18, 0.18, 0.01), Vector3(0, 0.85, 0.03), Util.mat(Color(0.97, 0.85, 0.2), 0.8))
	dia.rotation.z = PI * 0.25


## Stahltreppe von der Südostecke hinunter auf den Holzsteg: Wangen aus Flachstahl, schwarze Stufen.
func _t2_stairs(hut: Node3D, iron: Material, steel: Material) -> void:
	var drop := HUT_DECK_Y - JETTY_Y
	var steps := 6
	var rise := drop / steps
	var run := 0.24
	var tread := Util.mat(Color(0.1, 0.1, 0.11), 0.9)
	var w := STAIR_X1 - STAIR_X0
	var xc := (STAIR_X0 + STAIR_X1) * 0.5
	for i in range(1, steps):
		var h := -i * rise
		var z := HUT_HALF_Z + i * run
		_b(hut, Vector3(w - 0.06, 0.04, run + 0.04), Vector3(xc, h - 0.02, z), tread)
		_b(hut, Vector3(w - 0.06, 0.03, 0.03), Vector3(xc, h - 0.02, z + run * 0.5 + 0.01), steel)   # Kante
	var length := sqrt(drop * drop + (steps * run) * (steps * run))
	for x: float in [STAIR_X0, STAIR_X1]:
		var s := _b(hut, Vector3(0.03, 0.24, length), Vector3(x, -drop * 0.5 - 0.06, HUT_HALF_Z + steps * run * 0.5), iron)
		s.rotation.x = atan2(drop, steps * run)


## Holzsteg unter der Treppe zwischen Ufer und Startsteg: graue Dielen, schwarze Gummimatten.
## Vorne an der Treppe breit, dann schmaler am Ufer entlang nach Süden (insgesamt ca. 9 m).
func _t2_jetty() -> void:
	var j := _node(7.15, -5.65, JETTY_Y)          # lokal: x = Ost, z = Süd
	var parts: Array[Rect2] = [Rect2(-1.8, -1.5, 3.6, 3.0), Rect2(-0.2, 1.5, 2.0, 6.0)]
	var plank := Util.mat(Color(0.55, 0.52, 0.48))
	for r: Rect2 in parts:
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		_b(j, Vector3(r.size.x - 0.1, 0.3, r.size.y - 0.1), c + Vector3(0, -0.19, 0), _wood_dark)
		var n := int(r.size.x / 0.15)
		for i in n:
			_b(j, Vector3(0.135, 0.04, r.size.y), Vector3(r.position.x + (i + 0.5) * r.size.x / n, -0.02, c.z), plank)
		# Hindernis entlang der längeren Seite
		var a := j.global_transform * (c - (Vector3(r.size.x * 0.5, 0, 0) if r.size.x > r.size.y else Vector3(0, 0, r.size.y * 0.5)))
		var b := j.global_transform * (c + (Vector3(r.size.x * 0.5, 0, 0) if r.size.x > r.size.y else Vector3(0, 0, r.size.y * 0.5)))
		obstacles.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "half_w": minf(r.size.x, r.size.y) * 0.5, "top": JETTY_Y})
	_b(j, Vector3(0.12, 0.1, 6.0), Vector3(-0.2, -0.04, 4.5), _wood_dark)            # Randbalken zum Ufer
	_b(j, Vector3(2.0, 0.1, 0.12), Vector3(0.8, -0.04, 7.5), _wood_dark)             # Randbalken Süd
	var mat := Util.mat(Color(0.07, 0.07, 0.08), 0.95)
	_b(j, Vector3(0.85, 0.015, 1.7), Vector3(-1.0, 0.007, -0.3), mat)
	_b(j, Vector3(1.4, 0.015, 0.9), Vector3(0.9, 0.007, -0.9), mat)
	_b(j, Vector3(1.2, 0.015, 2.2), Vector3(0.7, 0.007, 4.2), mat)
	var bd := BoardLibrary.make(2)                                                       # abgelegtes Brett
	bd.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.2, 0.06, 0.5))
	j.add_child(bd)


## Brettständer am Nordende des Startstegs an der Hütte: schwarzer Kasten, Leihbretter in drei Reihen zu je
## zwei, schräg eingehängt, Bindungen zum See.
func _board_rack() -> void:
	var rack := _node(7.6, 0.1, Lake.DOCK_Y)
	var bl := Wakeboard.LENGTH
	var w := bl * 2.0 + 0.12
	var hgt := 1.5
	_b(rack, Vector3(0.04, hgt, w), Vector3(0.02, hgt * 0.5, 0), _black)
	for z: float in [-w * 0.5, 0.0, w * 0.5]:
		_b(rack, Vector3(0.38, hgt, 0.03), Vector3(0.19, hgt * 0.5, z), _black)
	var tilt := Basis(Vector3.BACK, -deg_to_rad(68.0))                   # Bindungen (+y) zeigen nach Osten, leicht nach oben
	var k := 0
	for row in 3:
		for col in 2:
			var bd := BoardLibrary.make(1 + k % maxi(BoardLibrary.count() - 1, 1))
			bd.transform = Transform3D(tilt, Vector3(0.2, 0.3 + row * 0.45, (col - 0.5) * (bl + 0.04)))
			rack.add_child(bd)
			k += 1

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
## am Startsteg vorbei, ein langer Arm schräg nach Südosten.
func _build_white_dock() -> void:
	var white := Util.mat(Color(0.93, 0.94, 0.93), 0.55)
	var seam := Util.mat(Color(0.55, 0.57, 0.58), 0.6)
	_strip(Vector2(9.7, 8.2), Vector2(9.7, 2.3), 1.6, 0.18, white, seam)
	_strip(Vector2(9.2, -3.3), Vector2(13.2, -14.0), 1.6, 0.18, white, seam)


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


## Ufermauer vor der Plattform: Beton-Pflanzringe in zwei Lagen (mit Erde und Kraut), davor
## Sandsäcke an der Wasserlinie. Läuft vor der Seeseite entlang und am Ufer weiter nach Norden.
func _shore_wall(hut: Node3D, deck_y: float) -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 0.28
	ring.bottom_radius = 0.28
	ring.height = 0.3
	ring.radial_segments = 14
	ring.rings = 1
	var soil := CylinderMesh.new()
	soil.top_radius = 0.22
	soil.bottom_radius = 0.22
	soil.height = 0.02
	soil.radial_segments = 10
	var bag := BoxMesh.new()
	bag.size = Vector3(0.45, 0.16, 0.6)
	var ring_xf: Array[Transform3D] = []
	var soil_xf: Array[Transform3D] = []
	var bag_xf: Array[Transform3D] = []
	var plants: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2602
	var base := -deck_y - 0.12                     # Unterkante knapp unter dem Wasserspiegel
	var line: Array[Vector3] = [Vector3(HUT_FRONT + 0.3, 0, HUT_HALF_Z + 0.2), Vector3(HUT_FRONT + 0.3, 0, -HUT_HALF_Z - 0.4),
		Vector3(HUT_FRONT + 0.15, 0, -HUT_HALF_Z - 3.5), Vector3(HUT_FRONT - 0.4, 0, -HUT_HALF_Z - 6.0)]
	for s in line.size() - 1:
		var a := line[s]
		var b := line[s + 1]
		var n := maxi(int(a.distance_to(b) / 0.56), 1)
		var side := (b - a).normalized().cross(Vector3.UP)   # zeigt vom Ufer weg (Osten)
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			var lay := 2 if s == 0 else (2 if i % 3 != 0 else 1)
			for l in lay:
				var q := p + Vector3(rng.randf_range(-0.04, 0.04), base + 0.15 + l * 0.3, 0) - side * l * 0.1
				ring_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
				if l == lay - 1:
					soil_xf.append(Transform3D(Basis.IDENTITY, q + Vector3(0, 0.14, 0)))
					if rng.randf() < 0.45:
						plants.append(q + Vector3(0, 0.14, 0))
			var bq := p + side * 0.42 + Vector3(0, base + 0.08, 0)
			bag_xf.append(Transform3D(Basis(Vector3.UP, atan2(-side.z, side.x) + rng.randf_range(-0.3, 0.3)) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), bq))
	_multi(hut, ring, ring_xf, Util.mat(Color(0.64, 0.63, 0.59), 0.95))
	_multi(hut, soil, soil_xf, Util.mat(Color(0.25, 0.2, 0.15), 1.0))
	_multi(hut, bag, bag_xf, Util.mat(Color(0.2, 0.24, 0.2), 0.95))
	# Kraut, Gras und kleine Weiden in den Ringen: Büschel aus schmalen, gefächerten Halmen
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 1.0, 0.012)
	var green_xf: Array[Transform3D] = []
	var straw_xf: Array[Transform3D] = []
	for p: Vector3 in plants:
		var h := rng.randf_range(0.35, 1.0)
		var dry := rng.randf() < 0.3
		for k in rng.randi_range(7, 12):
			var bs := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.05, 0.45))
			bs = bs * Basis.from_scale(Vector3(1.0, h * rng.randf_range(0.6, 1.1), 1.0))
			var off := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
			var xf := Transform3D(bs, p + off + bs * Vector3(0, 0.5, 0))
			if dry or rng.randf() < 0.15:
				straw_xf.append(xf)
			else:
				green_xf.append(xf)
	var green := Util.mat(Color(0.3, 0.42, 0.2), 0.9)
	green.cull_mode = BaseMaterial3D.CULL_DISABLED
	var straw := Util.mat(Color(0.58, 0.54, 0.32), 0.9)
	straw.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multi(hut, blade, green_xf, green)
	_multi(hut, blade, straw_xf, straw)


## Eine Reihe hochkant stehender Altreifen hinter den Ringen unter dem Deck.
func _tire_row(hut: Node3D, deck_y: float) -> void:
	var tire := TorusMesh.new()
	tire.inner_radius = 0.17
	tire.outer_radius = 0.32
	tire.rings = 16
	tire.ring_segments = 8
	var xf: Array[Transform3D] = []
	var z := -HUT_HALF_Z + 0.3
	while z < HUT_HALF_Z - 0.2:
		xf.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.35, 1.0)), Vector3(HUT_FRONT - 0.15, -deck_y + 0.2, z)))
		z += 0.5
	_multi(hut, tire, xf, Util.mat(Color(0.06, 0.06, 0.065), 0.85))


func _multi(parent: Node3D, mesh: Mesh, xf: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	parent.add_child(mi)


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
