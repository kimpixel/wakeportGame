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

func _build_t2_start() -> void:
	# Starthütte direkt am Wasser: Holzdeck, offene Front zum See, graues Pultdach
	var y := maxf(_ground(3.9, -2.0, 5.6, 7.0), 0.6)
	var hut := _node(3.9, -2.0, y)
	_b(hut, Vector3(6.4, 0.25, 7.6), Vector3(0.3, -0.12, 0), _wood_dark)          # Deck
	for p: Vector2 in [Vector2(-2.8, -3.6), Vector2(3.3, -3.6), Vector2(-2.8, 3.6), Vector2(3.3, 3.6), Vector2(0.3, 0.0)]:
		_post(hut, p.x, p.y, -y - 1.0, -0.2, _wood_grey, 0.12)                     # Pfähle unter dem Deck
	for p: Vector2 in [Vector2(-2.6, -3.3), Vector2(2.6, -3.3), Vector2(-2.6, 3.3), Vector2(2.6, 3.3)]:
		_post(hut, p.x, p.y, 0.0, 2.9 if p.x < 0 else 2.5, _wood, 0.1)
	_b(hut, Vector3(0.12, 2.8, 6.8), Vector3(-2.65, 1.4, 0), _wood)                 # Rückwand (Land)
	_b(hut, Vector3(5.3, 1.1, 0.1), Vector3(0, 0.55, -3.35), _wood)                 # Brüstung Nord
	_b(hut, Vector3(5.3, 1.1, 0.1), Vector3(0, 0.55, 3.35), _wood)                  # Brüstung Süd
	var roof := Node3D.new()
	roof.rotation.y = PI * 0.5
	roof.position = Vector3(0, 0, 0)
	hut.add_child(roof)
	_shed_roof(roof, 8.0, 6.6, 2.55, 3.0, _roof)
	roof.position.y = 0.05
	_b(hut, Vector3(1.6, 0.45, 3.0), Vector3(-1.8, 0.23, 0.5), _wood)                # Bank
	_b(hut, Vector3(0.9, 1.6, 1.2), Vector3(2.0, 0.8, 2.5), _wood_grey)              # Spind
	# Steuermann ("Hebler") vorne an der Kante, schaut aufs Wasser, mit gelber Fernsteuerung
	# (ca. 30 cm lang, 10 cm dick) in beiden Händen vor dem Bauch
	var remote_at := Vector3(1.85, 1.08, -1.5)
	if not _human_figure(hut, "res://assets/characters/operator.glb", Vector3(1.55, 0.0, -1.5), false, remote_at):
		_person(hut, Vector3(1.55, 0.0, -1.5), Color(0.1, 0.1, 0.12), false, remote_at)
	_b(hut, Vector3(0.1, 0.3, 0.12), remote_at, Util.mat(Color(1.0, 0.82, 0.05), 0.5))
	_b(hut, Vector3(0.02, 0.06, 0.06), remote_at + Vector3(0.06, 0.08, 0.0), Util.mat(Color(0.85, 0.1, 0.1)))   # Not-Aus
	_b(hut, Vector3(0.02, 0.04, 0.04), remote_at + Vector3(0.06, -0.03, -0.03), _black)                      # Taster
	_b(hut, Vector3(0.02, 0.04, 0.04), remote_at + Vector3(0.06, -0.03, 0.03), _black)
	people.append({"pos": hut.global_transform * Vector3(1.55, 1.6, -1.5), "pitch": 0.92})
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

	# Schwimmende Startstege (entspricht Lake.DOCK_*, darauf startet der Fahrer)
	var dmin := Lake.DOCK_MIN
	var dmax := Lake.DOCK_MAX
	var dock := Node3D.new()
	add_child(dock)
	var c := Vector3((dmin.x + dmax.x) * 0.5, Lake.DOCK_Y - 0.15, (dmin.y + dmax.y) * 0.5)
	_b(dock, Vector3(dmax.x - dmin.x, 0.3, dmax.y - dmin.y), c, _wood)
	_b(dock, Vector3(dmax.x - dmin.x + 0.2, 0.32, 0.25), c + Vector3(0, -0.02, (dmax.y - dmin.y) * 0.5), _blue)
	_b(dock, Vector3(dmax.x - dmin.x + 0.2, 0.32, 0.25), c + Vector3(0, -0.02, -(dmax.y - dmin.y) * 0.5), _blue)
	# Steg zwischen Hütte und Startsteg
	var link := Geo.rel_to_game(7.2, -2.0)
	_b(dock, Vector3(1.6, 0.25, 1.8), Vector3(link.x, Lake.DOCK_Y - 0.12, link.y), _wood_dark)
	# Wakeboards am Steg
	for i in 3:
		var bp := c + Vector3(-2.0 + i * 0.5, 0.22, 1.8)
		var bd := _b(dock, Vector3(0.42, 0.04, 1.35), bp, _black)
		bd.rotation.y = 0.2 * i


## Realistische Figur (MakeHuman), schaut in lokale +X-Richtung (aufs Wasser).
## sitting: sitzt auf Höhe base.y (Bank), Hände auf den Oberschenkeln;
## sonst stehend, Hände bei hands_at (z. B. an der Fernsteuerung).
func _human_figure(parent: Node3D, path: String, base: Vector3, sitting: bool, hands_at := Vector3.INF) -> bool:
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
				var dz := -0.06 if side == "l" else 0.06
				var hand := hands_at + Vector3(-0.04, -0.06, dz)
				rig.arm(side, w.call(hand), w.call(base + Vector3(-0.1, 0.9, dz * 8.0)))
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
	var dock := _node(21.9, -29.5, 0.18)
	_b(dock, Vector3(4.4, 0.3, 7.0), Vector3.ZERO, _wood)
	_b(dock, Vector3(4.6, 0.32, 0.25), Vector3(0, -0.02, 3.5), _blue)
	_b(dock, Vector3(0.25, 0.32, 7.0), Vector3(2.2, -0.02, 0), _blue)
	var jet := Node3D.new()
	jet.position = Vector3(0.4, 0.35, -1.5)
	dock.add_child(jet)
	_b(jet, Vector3(1.1, 0.5, 2.9), Vector3.ZERO, _white)
	_b(jet, Vector3(0.9, 0.3, 1.0), Vector3(0, 0.35, 0.2), Util.mat(Color(0.1, 0.2, 0.35)))


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
	# Rotes Rettungsboot neben der T2-Hütte
	var boat := _node(7.5, 5.0, 0.1, 30.0)
	_b(boat, Vector3(1.5, 0.45, 3.4), Vector3.ZERO, Util.mat(Color(0.85, 0.15, 0.2), 0.5))
	_b(boat, Vector3(0.3, 0.5, 0.4), Vector3(0, 0.35, 1.6), _black)
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
