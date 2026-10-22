class_name Plants
## Bepflanzung: Automatik am Ufer (Schilf, Ufergras, Sträucher) und von Hand gemalte Pflanzen
## (Setup-Editor, Reiter „Pflanzen“). Gebaut werden sie in Terrain (MultiMeshes).
##
## Automatik und Malen arbeiten zusammen: wo gemalt, radiert oder „Automatik“ zurückgeholt wird,
## gilt die Stelle (Raster CELL) als **von Hand gepflegt** – getrennt für Bodenpflanzen (Gräser,
## Schilf) und Gehölze (Sträucher, Bäume). Dort setzt die Automatik nichts mehr, auch keine Bäume
## aus dem Oberflächenmodell bzw. kein Wiesengras; es stehen nur die gemalten Pflanzen.
##
## Datei setups/plants.json (Spielkoordinaten): {"plants": [[art, x, z, höhe, yaw], …],
## "boden": [[cx, cz], …], "gehoelz": [[cx, cz], …]}. Lokal (aus dem Projekt gestartet) speichert der
## Editor direkt dorthin (dann committen), in exportierten Versionen nach user://plants.json.

const FILE := "res://setups/plants.json"
const USER_FILE := "user://plants.json"
const CELL := 2.0            # m Raster der von Hand gepflegten Stellen
const LAYERS := ["boden", "gehoelz"]
const LAYER_NAMES := {"boden": "Bodenpflanzen (Gräser, Schilf)", "gehoelz": "Gehölze (Sträucher, Bäume)"}  # i18n

## Arten in Reihenfolge des Editors. spacing = Abstand beim Malen (m), h = Höhe von/bis (m),
## ground = erlaubte Geländehöhe über dem See von/bis (Schilf steht im flachen Wasser),
## r = Radius in der Draufsicht (Anteil der Höhe), color = Punkt im Editor.
const SPECIES := [
	{"id": "schilf", "name": "Schilf", "layer": "boden", "spacing": 0.5, "h": [1.2, 2.4],  # i18n
		"ground": [-1.1, 0.25], "r": 0.12, "color": Color(0.75, 0.68, 0.35)},
	{"id": "ufergras", "name": "Ufergras", "layer": "boden", "spacing": 0.7, "h": [0.7, 1.15],  # i18n
		"ground": [0.0, 6.0], "r": 0.4, "color": Color(0.6, 0.8, 0.3)},
	{"id": "gras", "name": "Wiesengras", "layer": "boden", "spacing": 0.9, "h": [0.45, 0.8],  # i18n
		"ground": [0.1, 9.0], "r": 0.45, "color": Color(0.35, 0.75, 0.25)},
	{"id": "strauch", "name": "Strauch", "layer": "gehoelz", "spacing": 2.2, "h": [1.2, 2.8],  # i18n
		"ground": [0.05, 20.0], "r": 0.45, "color": Color(0.2, 0.55, 0.2)},
	{"id": "laubbaum", "name": "Laubbaum", "layer": "gehoelz", "spacing": 5.0, "h": [6.0, 14.0],  # i18n
		"ground": [0.2, 30.0], "r": 0.3, "color": Color(0.45, 0.65, 0.15)},
	{"id": "kiefer", "name": "Kiefer", "layer": "gehoelz", "spacing": 5.0, "h": [8.0, 18.0],  # i18n
		"ground": [0.2, 30.0], "r": 0.22, "color": Color(0.12, 0.38, 0.2)},
]

# Automatik am Ufer
const AUTO_RANGE := 230.0      # m um die Bahnen (weiter weg verdeckt der Waldmantel alles)
const AUTO_GRID := 3.0         # m Grobraster (Höhen, Abstand zum Ufer)
const LANE_FREE := 26.0        # m um die Seile: kein Schilf (Fahrbereich, Wenden)
const DOCK_FREE := 30.0        # m um die Startmasten: nichts (Strand, Stege)

static var hand := {}          # Vector2i (Zelle) -> Array von [art, x, z, höhe, yaw]
static var managed := {"boden": {}, "gehoelz": {}}   # Ebene -> {Vector2i: true}
static var _loaded := false
static var _auto: Array = []   # [art, x, z, höhe, yaw, helligkeit]
static var _auto_done := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FILE
	if OS.has_feature("template") and FileAccess.file_exists(USER_FILE):
		file = USER_FILE
	var d: Variant = null
	if FileAccess.file_exists(file):
		d = JSON.parse_string(FileAccess.get_file_as_string(file))
	from_data(d if d is Dictionary else {})


static func species(id: String) -> Dictionary:
	for s: Dictionary in SPECIES:
		if s["id"] == id:
			return s
	return {}


static func layer_of(id: String) -> String:
	return str(species(id).get("layer", "boden"))


static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


static func is_managed(layer: String, x: float, z: float) -> bool:
	return (managed[layer] as Dictionary).has(cell_of(x, z))


## Darf die Art hier stehen (Geländehöhe)?
static func allowed(id: String, x: float, z: float) -> bool:
	if not Geo.in_area(x, z):
		return false
	var g: Array = species(id).get("ground", [0.0, 99.0])
	var h := Geo.height(x, z)
	return h >= float(g[0]) and h <= float(g[1])


## Alle von Hand gesetzten Pflanzen als Liste.
static func hand_list() -> Array:
	var out := []
	for cell: Vector2i in hand:
		out.append_array(hand[cell])
	return out


static func add_hand(e: Array) -> void:
	var c := cell_of(e[1], e[2])
	if not hand.has(c):
		hand[c] = []
	(hand[c] as Array).append(e)


## Von Hand gesetzte Pflanzen der Ebene im Umkreis r (für Abstände und Radieren).
static func hand_near(x: float, z: float, r: float, layer := "") -> Array:
	var out := []
	var c0 := cell_of(x - r, z - r)
	var c1 := cell_of(x + r, z + r)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for e: Array in hand.get(Vector2i(cx, cz), []):
				if (layer == "" or layer_of(e[0]) == layer) and Vector2(e[1] - x, e[2] - z).length() <= r:
					out.append(e)
	return out


static func remove_hand(e: Array) -> void:
	var c := cell_of(e[1], e[2])
	var arr: Array = hand.get(c, [])
	arr.erase(e)
	if arr.is_empty():
		hand.erase(c)


static func to_data() -> Dictionary:
	var plants := []
	for e: Array in hand_list():
		plants.append([e[0], snappedf(e[1], 0.01), snappedf(e[2], 0.01), snappedf(e[3], 0.01), snappedf(e[4], 0.01)])
	plants.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))
	var out := {"info": "Bepflanzung (Spielkoordinaten), siehe scripts/plants.gd", "plants": plants}
	for layer: String in LAYERS:
		var cells := []
		for c: Vector2i in managed[layer]:
			cells.append([c.x, c.y])
		cells.sort()
		out[layer] = cells
	return out


static func from_data(d: Dictionary) -> void:
	hand.clear()
	managed = {"boden": {}, "gehoelz": {}}
	for e: Variant in d.get("plants", []):
		if e is Array and (e as Array).size() >= 5 and not species(str(e[0])).is_empty():
			add_hand([str(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4])])
	for layer: String in LAYERS:
		for c: Variant in d.get(layer, []):
			if c is Array and (c as Array).size() >= 2:
				(managed[layer] as Dictionary)[Vector2i(int(c[0]), int(c[1]))] = true


## Speichern: aus dem Projekt gestartet direkt in setups/plants.json (zum Committen),
## sonst nach user://. Ergebnis: Pfad oder "" bei Fehler.
static func save() -> String:
	var file := USER_FILE if OS.has_feature("template") else FILE
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		push_warning("Konnte %s nicht schreiben" % file)
		return ""
	f.store_string(to_json())
	f.close()
	return file


static func to_json() -> String:
	# eine Pflanze bzw. Zelle je Zeile (kleine Diffs in Git)
	var d := to_data()
	var lines: Array[String] = ["{", '  "info": %s,' % JSON.stringify(d["info"])]
	for key: String in ["plants", "boden", "gehoelz"]:
		var rows: Array = d[key]
		var parts: Array[String] = []
		for r: Array in rows:
			parts.append("    " + JSON.stringify(r))
		var tail := "," if key != "gehoelz" else ""
		if parts.is_empty():
			lines.append('  "%s": []%s' % [key, tail])
		else:
			lines.append('  "%s": [\n%s\n  ]%s' % [key, ",\n".join(parts), tail])
	lines.append("}")
	return "\n".join(lines) + "\n"


## Eigene Datei (exportierte Version) löschen: wieder die Bepflanzung aus dem Spiel.
static func reset_user() -> void:
	if FileAccess.file_exists(USER_FILE):
		DirAccess.remove_absolute(USER_FILE)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	from_data(d if d is Dictionary else {})


static func can_reset_user() -> bool:
	return OS.has_feature("template") and FileAccess.file_exists(USER_FILE)


# ---------------------------------------------------------------- Automatik am Ufer

## Gut gemischte Zahl aus drei ganzen Zahlen (splitmix64), z. B. als Startwert eines Zufallsgenerators
## je Rasterpunkt. Nicht hash(): ähnliche Startwerte geben in Godot ähnliche Zufallsfolgen (ganze
## Waldstücke hatten sonst dieselben Kronen bzw. keine).
static func mix(a: int, b: int, c: int) -> int:
	var z := a * 0x6A09E667F3BCC909 + b * 0x3C6EF372FE94F82B + c * 0x510E527FADE682D1
	z = (z ^ (z >> 30)) * 0x3F58476D1CE4E5B9
	z = (z ^ (z >> 27)) * 0x14D049BB133111EB
	return z ^ (z >> 31)


## Zufallswert 0..1 je Rasterpunkt (immer gleich, unabhängig von der Reihenfolge).
static func rand01(ix: int, iz: int, salt: int) -> float:
	return float((mix(ix, iz, salt) >> 20) & 0xffff) / 65536.0


## Automatisch gesetzte Uferpflanzen (einmal gerechnet, danach aus dem Zwischenspeicher).
## color_at(x, z) -> Color: Luftbild (für Sand, Wege, Dächer). Von Hand gepflegte Stellen
## sind hier noch enthalten (filtert Terrain beim Bauen).
static func auto_shore(color_at: Callable) -> Array:
	if _auto_done:
		return _auto
	_auto_done = true
	var t0 := Time.get_ticks_msec()
	var lanes := []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for t: String in ["t1", "t2"]:
		var a: Vector3 = Geo.masts[t + "_start"]
		var e: Vector3 = Geo.masts[t + "_end"]
		lanes.append([Vector2(a.x, a.z), Vector2(e.x, e.z)])
		for p: Vector3 in [a, e]:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	var docks := [Vector2(Geo.masts["t1_start"].x, Geo.masts["t1_start"].z), Vector2(Geo.masts["t2_start"].x, Geo.masts["t2_start"].z)]
	var gb := Geo.game_bounds()
	lo = (lo - Vector2.ONE * AUTO_RANGE).max(gb.position)
	hi = (hi + Vector2.ONE * AUTO_RANGE).min(gb.end)
	var g := AUTO_GRID
	var nx := int((hi.x - lo.x) / g) + 2
	var nz := int((hi.y - lo.y) / g) + 2
	# Grobraster: Höhe und vorzeichenbehafteter Abstand zur Uferlinie (Land +, Wasser −)
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	var dist := PackedFloat32Array()
	dist.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := lo.x + i * g
			var z := lo.y + j * g
			var h := Geo.height(x, z) if Geo.in_area(x, z) else 5.0
			hs[j * nx + i] = h
	for wet_pass: bool in [false, true]:
		# Chamfer-Abstand (3-4) zu den Rasterpunkten der anderen Seite, gedeckelt
		var d := PackedFloat32Array()
		d.resize(nx * nz)
		for k in nx * nz:
			var wet := hs[k] < 0.0
			d[k] = 0.0 if wet != wet_pass else 99.0
		for j in nz:
			for i in nx:
				var k := j * nx + i
				if i > 0: d[k] = minf(d[k], d[k - 1] + g)
				if j > 0: d[k] = minf(d[k], d[k - nx] + g)
				if i > 0 and j > 0: d[k] = minf(d[k], d[k - nx - 1] + g * 1.414)
				if i < nx - 1 and j > 0: d[k] = minf(d[k], d[k - nx + 1] + g * 1.414)
		for j in range(nz - 1, -1, -1):
			for i in range(nx - 1, -1, -1):
				var k := j * nx + i
				if i < nx - 1: d[k] = minf(d[k], d[k + 1] + g)
				if j < nz - 1: d[k] = minf(d[k], d[k + nx] + g)
				if i < nx - 1 and j < nz - 1: d[k] = minf(d[k], d[k + nx + 1] + g * 1.414)
				if i > 0 and j < nz - 1: d[k] = minf(d[k], d[k + nx - 1] + g * 1.414)
		for k in nx * nz:
			var wet := hs[k] < 0.0
			if wet == wet_pass:
				# Uferlinie liegt etwa mittig zwischen den Rasterpunkten
				dist[k] = (d[k] - g * 0.5) * (-1.0 if wet else 1.0)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.035
	var out := []
	for j in nz - 1:
		for i in nx - 1:
			var k := j * nx + i
			var dmin := minf(minf(dist[k], dist[k + 1]), minf(dist[k + nx], dist[k + nx + 1]))
			var dmax := maxf(maxf(dist[k], dist[k + 1]), maxf(dist[k + nx], dist[k + nx + 1]))
			if dmin > 10.0 or dmax < -5.0:
				continue   # weit im Wald bzw. im See
			var x0 := lo.x + i * g
			var z0 := lo.y + j * g
			var mid := Vector2(x0 + g * 0.5, z0 + g * 0.5)
			var lane_d := INF
			for ln: Array in lanes:
				lane_d = minf(lane_d, _seg_dist(mid, ln[0], ln[1]))
			if lane_d > AUTO_RANGE:
				continue
			if mid.distance_to(docks[0]) < DOCK_FREE or mid.distance_to(docks[1]) < DOCK_FREE:
				continue
			for si in 3:
				var sp: Dictionary = SPECIES[[0, 1, 3][si]]
				var id: String = sp["id"]
				match id:
					"schilf":
						if dmin > 0.5 or dmax < -6.0 or lane_d < LANE_FREE:
							continue
					"ufergras":
						if dmax < 0.0 or dmin > 5.0:
							continue
					"strauch":
						if dmax < 0.8 or dmin > 7.0:
							continue
				var step: float = sp["spacing"] * (1.4 if id == "schilf" else 1.0)
				# Büschel/Gruppen statt gleichmäßigem Saum
				var clump := noise.get_noise_2d(mid.x + si * 500.0, mid.y)
				var thr := {"schilf": 0.0, "ufergras": -0.25, "strauch": -0.2}[id] as float
				if clump < thr - 0.15:
					continue
				for gx in range(ceili(x0 / step), ceili((x0 + g) / step)):
					for gz in range(ceili(z0 / step), ceili((z0 + g) / step)):
						var salt := 100 + si * 10
						var px := (gx + rand01(gx, gz, salt) * 0.9 - 0.45) * step
						var pz := (gz + rand01(gx, gz, salt + 1) * 0.9 - 0.45) * step
						if noise.get_noise_2d(px + si * 500.0, pz) < thr:
							continue
						var fx := clampf((px - lo.x) / g, 0.0, nx - 1.001)
						var fz := clampf((pz - lo.y) / g, 0.0, nz - 1.001)
						var ci := int(fx)
						var cj := int(fz)
						var tx := fx - ci
						var tz := fz - cj
						var kk := cj * nx + ci
						var sd := lerpf(lerpf(dist[kk], dist[kk + 1], tx), lerpf(dist[kk + nx], dist[kk + nx + 1], tx), tz)
						var h := Geo.height(px, pz)
						var ok := false
						match id:
							"schilf": ok = sd > -5.0 and sd < 0.3 and h > -1.1 and h < 0.15
							"ufergras": ok = sd > -0.2 and sd < 4.5 and h > 0.02 and h < 2.5
							"strauch": ok = sd > 1.0 and sd < 6.5 and h > 0.1
						if not ok:
							continue
						var col: Color = color_at.call(px, pz)
						var lum := col.get_luminance()
						if id == "schilf":
							if lum > 0.38:
								continue   # hell = Sand unter flachem Wasser (Badebereich)
						elif lum > 0.42 or (col.r > col.g * 1.05 and lum > 0.22):
							continue   # Sand, Wege, Dächer
						var r := rand01(gx, gz, salt + 2)
						var hr: Array = sp["h"]
						out.append([id, px, pz, lerpf(hr[0], hr[1], r), rand01(gx, gz, salt + 3) * TAU, 0.8 + 0.3 * rand01(gx, gz, salt + 4)])
	_auto = out
	if "--autotest" in OS.get_cmdline_user_args():
		var n := {}
		for e: Array in out:
			n[e[0]] = n.get(e[0], 0) + 1
		print("Uferpflanzen in %d ms: %s" % [Time.get_ticks_msec() - t0, n])
	return _auto


## Zuletzt gerechnete Automatik (Setup-Editor; gerechnet beim Aufbau des Geländes).
static func auto_cache() -> Array:
	return _auto


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var f := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * f)
