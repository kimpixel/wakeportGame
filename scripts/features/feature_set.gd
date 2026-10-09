class_name FeatureSet
extends Node3D
## Lädt den Bauteile-Katalog (setups/parts.json) und ein Feature-Setup (setups/setup_*.json,
## Liste in setups/index.json) und stellt die Teile entlang der Seile auf.
## Bietet der Fahrerphysik eine Abfrage der Hindernis-Oberkante an jedem Punkt.

const PARTS_FILE := "res://setups/parts.json"
const INDEX_FILE := "res://setups/index.json"
const USER_DIR := "user://setups"                  # eigene Setups aus dem Setup-Editor
const USER_INDEX := "user://setups/index.json"
const OVERRIDES := ["length", "width", "height", "height_end", "ramp_in", "ramp_out", "ramp_curve", "side_ramp", "curve", "radius", "center_y", "color", "name", "body", "inner_v", "article", "body_curve", "profile", "side_curve", "lip"]

var parts: Array[FeaturePart] = []
var setup_name := ""
var colliders := true          # Kollisionskörper für die Ragdoll (Katalog der Startseite: aus)
var _catalog: Dictionary = {}


## Alle Setups aus setups/index.json: [{"id", "name", "date", "file"}, …] (neuestes zuerst),
## danach die eigenen aus dem Setup-Editor (mit "user": true).
static func list_setups() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_FILE))
	var out: Array = data.get("setups", []) if data is Dictionary else []
	for e: Dictionary in user_setups():
		var u := e.duplicate()
		u["user"] = true
		out.append(u)
	return out


## Eigene Setups (user://setups/index.json).
static func user_setups() -> Array:
	if not FileAccess.file_exists(USER_INDEX):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(USER_INDEX))
	return data.get("setups", []) if data is Dictionary else []


## Eigenes Setup speichern (neu oder überschreiben). Gibt die Datei zurück ("" bei Fehler).
static func save_user_setup(id: String, setup: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var file := "%s/%s.json" % [USER_DIR, id]
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		push_warning("Konnte %s nicht schreiben" % file)
		return ""
	f.store_string(JSON.stringify(setup, "  ", false))
	f.close()
	var list := user_setups()
	var entry := {"id": id, "name": setup.get("name", id), "file": file}
	var found := false
	for i in list.size():
		if list[i].get("id", "") == id:
			list[i] = entry
			found = true
	if not found:
		list.append(entry)
	_write_user_index(list)
	return file


## Eigenes Setup löschen.
static func delete_user_setup(id: String) -> void:
	var list := user_setups()
	for i in range(list.size() - 1, -1, -1):
		if list[i].get("id", "") == id:
			DirAccess.remove_absolute(list[i].get("file", ""))
			list.remove_at(i)
	_write_user_index(list)


static func _write_user_index(list: Array) -> void:
	var f := FileAccess.open(USER_INDEX, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"setups": list}, "  ", false))
		f.close()


## Setup-Datei als Dictionary ({"name", "T1": [...], "T2": [...]}).
static func read_setup(file: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	return data if data is Dictionary else {}


## Bauteile-Katalog (parts.json).
static func read_catalog() -> Dictionary:
	return read_setup(PARTS_FILE)


## Entfernt das aktuelle Setup und baut das Setup aus file auf.
## terminals: z. B. {"T1": cable_t1, "T2": cable}
## s_offset: pro Terminal zusätzlicher Abstand (m) – die Setups sind vom T2-Startsteg aus
## gemessen; liegt der Startsteg einer Anlage weiter draußen, rücken ihre Teile mit.
func load_setup(file: String, terminals: Dictionary, s_offset := {}) -> void:
	load_data(_read_json(file), terminals, s_offset, file)


## Wie load_setup, aber aus einem schon gelesenen Setup (Setup-Editor).
## Jedes Teil merkt sich die Nummer seiner Setup-Zeile (FeaturePart.row_index).
func load_data(setup: Dictionary, terminals: Dictionary, s_offset := {}, label := "") -> void:
	for part in parts:
		part.queue_free()
	parts.clear()
	if _catalog.is_empty():
		_catalog = _read_json(PARTS_FILE)
	setup_name = setup.get("name", label)
	for terminal: String in terminals:
		var off: float = s_offset.get(terminal, 0.0)
		var rows: Array = setup.get(terminal, [])
		for i in rows.size():
			var r: Dictionary = (rows[i] as Dictionary).duplicate()
			r["s"] = float(r.get("s", 0.0)) + off
			r["_row"] = i
			_place(r, terminals[terminal], label)


func _place(row: Dictionary, cable: CableSystem, file: String, parent := Transform3D.IDENTITY) -> void:
	var id: String = row.get("part", "")
	if not _catalog.has(id):
		push_warning("Setup %s: Bauteil '%s' fehlt im Katalog" % [file, id])
		return
	var s: float = row.get("s", 0.0)
	var x: float = row.get("x", 0.0)
	var yaw := deg_to_rad(float(row.get("yaw", 0.0)))
	var flipped: bool = row.get("dir", "out") == "in"
	if flipped:
		yaw += PI
	# Position relativ zum Elternteil (Gruppe) bzw. zum Startmast, Seil entlang -z
	var local := parent * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, -s))
	var entry: Dictionary = _catalog[id]
	if entry.get("type", "") == "group":
		# Gruppe: mehrere Teile, die zusammen ein Feature bilden (z. B. Pyramid Series).
		# "mirror": negative x der Teile zeigen immer vom Seil weg (z. B. A-Frame Rail außen).
		# ramp_in/ramp_out der Setup-Zeile gelten für die Teile am Anfang ("edge": "in") bzw. Ende.
		var mirror := 1.0
		if entry.get("mirror", false):
			mirror = -signf(x if x != 0.0 else -1.0) * (-1.0 if flipped else 1.0)
		for child: Dictionary in entry.get("parts", []):
			var c := child.duplicate()
			c["group"] = entry.get("name", id)
			c["_row"] = row.get("_row", -1)
			c["x"] = float(c.get("x", 0.0)) * mirror
			if row.has("ramp_in") and c.get("edge", "") == "in":
				c["ramp_in"] = row["ramp_in"]
			if row.has("ramp_out") and c.get("edge", "") == "out":
				c["ramp_out"] = row["ramp_out"]
			_place(c, cable, file, local)
		return
	# Katalogwerte, einzelne Werte dürfen im Setup überschrieben werden
	var p: Dictionary = entry.duplicate()
	for key: String in OVERRIDES:
		if row.has(key):
			p[key] = row[key]
	# Pipe-Module: "body" = Rohrlänge; Auffahrten werden vorne/hinten angesteckt,
	# s bezeichnet weiter die Mitte des Rohrs (so passen geteilte Pipes genau aneinander)
	if p.get("type", "") == "pipe" and p.has("body"):
		var ri: float = p.get("ramp_in", 0.0)
		var ro: float = p.get("ramp_out", 0.0)
		p["length"] = float(p["body"]) + ri + ro
		local = local * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -(ro - ri) * 0.5))
	var part := FeaturePart.new()
	part.setup(id, p)
	part.group_name = row.get("group", "")
	part.row_index = row.get("_row", -1)
	part.cable = cable
	part.collide = colliders
	var world := cable.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, cable.mast_a_z)) * local
	part.transform = world
	var on_cable := cable.transform.affine_inverse() * world.origin
	part.s_center = cable.mast_a_z - on_cable.z
	part.x_center = on_cable.x
	# Auf welcher Seite (lokal v) liegt das Seil? Dort sind Transitions / seitliche Auffahrten.
	var side_pt := cable.transform.affine_inverse() * (world * Vector3(1.0, 0.0, 0.0))
	part.inner_v = 1.0 if absf(side_pt.x) < absf(on_cable.x) else -1.0
	if p.has("inner_v"):
		part.inner_v = signf(float(p["inner_v"]))      # z. B. gespiegelte 1/2 Transition Rails
	add_child(part)
	parts.append(part)
	if show_hitboxes:
		part.show_catch_zone(true)


func _read_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return data
	push_warning("Konnte %s nicht lesen" % path)
	return {}


## Alle Teile einer Anlage.
func parts_of(cable: CableSystem) -> Array[FeaturePart]:
	var out: Array[FeaturePart] = []
	for part in parts:
		if part.cable == cable:
			out.append(part)
	return out


## Liegt direkt vor dem Einstieg eines Teils schon ein anderes (Combo wie Wedge -> Pipe)?
## Dann wird das hintere Teil nicht eigens angefahren, man kommt über das vordere drauf.
func height_at_entry_free(part: FeaturePart, travel: Vector3) -> bool:
	var d := 1.0 if part.forward_world().dot(travel) >= 0.0 else -1.0
	var entry := part.global_position - part.forward_world() * d * (part.length * 0.5 + 0.6)
	for other in parts:
		if other != part and other.height_at(entry.x, entry.z) > 0.3:
			return false
	return true


## Ist neben dem Teil auf der Seilseite ein höheres Teil? Dann zieht einen das Seil
## beim Rutschen dagegen – solche Teile fährt der Autopilot nicht an.
func inner_side_clear(part: FeaturePart) -> bool:
	var side := -signf(part.x_center)               # Richtung Seillinie (lokales x)
	var top := part.height_local(0.0, 0.0)
	for k in 5:
		var u := lerpf(-part.length * 0.4, part.length * 0.4, k / 4.0)
		var v := side * (part.width * 0.5 + 0.5) * (1.0 if part.forward_world().dot(part.cable.transform.basis * Vector3.FORWARD) >= 0.0 else -1.0)
		var p := part.global_transform * Vector3(v, 0.0, -u)
		for other in parts:
			if other != part and other.height_at(p.x, p.z) > top + 0.1:
				return false
	return true


## Höchste Hindernis-Oberkante an (x, z) oder FeaturePart.NONE.
func height_at(x: float, z: float, collision := false) -> float:
	var best := FeaturePart.NONE
	for part in parts:
		best = maxf(best, part.height_at(x, z, collision))
	return best


## Fangzone eines Sliders an world (nächster Zielpunkt) oder null. Gibt [Teil, Zielpunkt] zurück.
func catch_at(world: Vector3) -> Array:
	var best: Array = []
	var best_d := INF
	for part in parts:
		var t := part.catch_target(world)
		if t != Vector3.INF:
			var d := Vector2(t.x - world.x, t.z - world.z).length() + absf(t.y - world.y) * 0.5
			if d < best_d:
				best_d = d
				best = [part, t]
	return best


## Fliegt man gerade auf einen Slider zu (Weg ab world entlang dir, bis dist m)? Höhe egal.
func slider_ahead(world: Vector3, dir: Vector3, dist: float) -> bool:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	for part in parts:
		var k := 0.0
		while k <= dist:
			if part.over_slider(world + d * k, 0.3):
				return true
			k += 1.0
	return false


## Debug: Fangzonen aller Slider ein-/ausblenden.
var show_hitboxes := false:
	set(on):
		show_hitboxes = on
		for part in parts:
			part.show_catch_zone(on)


## Das Teil mit der höchsten Oberkante an (x, z) oder null.
func part_at(x: float, z: float) -> FeaturePart:
	var best := FeaturePart.NONE
	var found: FeaturePart = null
	for part in parts:
		var h := part.height_at(x, z)
		if h > best:
			best = h
			found = part
	return found


# ---------------------------------------------------------------- Schwimmen um Features

## Grundriss eines Teils als gedrehtes Rechteck in der Ebene (x, z), um margin vergrößert.
func _rect(part: FeaturePart, margin: float) -> Dictionary:
	var ax := part.lock_axis()
	var a2 := Vector2(ax.x, ax.z).normalized()
	var gp := part.global_position
	return {"c": Vector2(gp.x, gp.z), "a": a2, "s": Vector2(-a2.y, a2.x),
		"hx": part.length * 0.5 + margin, "hy": part.width * 0.5 + margin}


static func _local(r: Dictionary, p: Vector2) -> Vector2:
	var d: Vector2 = p - r["c"]
	return Vector2(d.dot(r["a"]), d.dot(r["s"]))


static func _inside(r: Dictionary, p: Vector2, shrink := 0.0) -> bool:
	var l := _local(r, p)
	return absf(l.x) < float(r["hx"]) - shrink and absf(l.y) < float(r["hy"]) - shrink


## Schneidet die Strecke a–b das Innere des Rechtecks? (Liang-Barsky im Rechteck-Raum)
static func _seg_hits(r: Dictionary, a: Vector2, b: Vector2) -> bool:
	var p := _local(r, a)
	var q := _local(r, b)
	var d := q - p
	var hx: float = float(r["hx"]) - 0.02
	var hy: float = float(r["hy"]) - 0.02
	var t0 := 0.0
	var t1 := 1.0
	for k in 4:
		var pk: float = [-d.x, d.x, -d.y, d.y][k]
		var qk: float = [p.x + hx, hx - p.x, p.y + hy, hy - p.y][k]
		if absf(pk) < 1e-9:
			if qk < 0.0:
				return false
		else:
			var t := qk / pk
			if pk < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
	return true


## Weg zum Schwimmen von from nach to (Welt), großzügig um alle Features herum.
## Liefert die Wegpunkte (x, z) ohne den Startpunkt; der letzte ist to.
func swim_path(from: Vector3, to: Vector3, margin: float) -> Array[Vector2]:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var out: Array[Vector2] = []
	# nur Teile in der Nähe der Strecke betrachten
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * 30.0
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * 30.0
	var rects: Array[Dictionary] = []
	for part in parts:
		var gp := part.global_position
		if gp.x < lo.x or gp.x > hi.x or gp.z < lo.y or gp.z > hi.y:
			continue
		var r := _rect(part, margin)
		if not _inside(r, b):              # Ziel (Handle) liegt nie in einem Hindernis
			rects.append(r)
	# Start im Sicherheitsabstand (z. B. hinter einem Feature oder mitten in einem Hack):
	# rundum den kürzesten Ausweg suchen, der durch kein Feature selbst führt
	var start_in := false
	for r in rects:
		if _inside(r, a):
			start_in = true
			break
	if start_in:
		var solid: Array[Dictionary] = []
		for part in parts:
			solid.append(_rect(part, 0.3))
		var best := Vector2.INF
		var best_d := INF
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			var dd := 0.5
			while dd < 25.0:
				var p := a + dir * dd
				var free := true
				for r in rects:
					if _inside(r, p):
						free = false
						break
				if free:
					var ok := true
					for r in solid:
						if _seg_hits(r, a, p) and not _inside(r, a):
							ok = false
							break
					if ok and dd < best_d:
						best_d = dd
						best = p
					break
				dd += 0.5
		if best != Vector2.INF:
			a = best
			out.append(a)
	var blocked := func(p: Vector2, q: Vector2) -> bool:
		for r in rects:
			if _seg_hits(r, p, q):
				return true
		return false
	if not blocked.call(a, b):
		out.append(b)
		return out
	# Sichtgraph über die Ecken der vergrößerten Rechtecke, kürzester Weg (Dijkstra)
	var nodes: Array[Vector2] = [a, b]
	for r in rects:
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var c: Vector2 = r["c"] + r["a"] * sx * (float(r["hx"]) + 0.05) + r["s"] * sy * (float(r["hy"]) + 0.05)
				var free := true
				for r2 in rects:
					if _inside(r2, c):
						free = false
						break
				if free:
					nodes.append(c)
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	for _iter in n:
		var u := -1
		for i in n:
			if not done[i] and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0 or dist[u] == INF or u == 1:
			break
		done[u] = true
		for v in n:
			if done[v] or v == u:
				continue
			var w := nodes[u].distance_to(nodes[v])
			if dist[u] + w < dist[v] and not blocked.call(nodes[u], nodes[v]):
				dist[v] = dist[u] + w
				prev[v] = u
	if prev[1] < 0:
		out.append(b)                      # kein Weg gefunden: direkt (Notfall)
		return out
	var rev: Array[Vector2] = []
	var k := 1
	while k > 0:
		rev.append(nodes[k])
		k = prev[k]
	rev.reverse()
	out.append_array(rev)
	return out


## Harte Grenze beim Schwimmen: aus dem Grundriss (plus margin) eines Features herausschieben.
func push_out(p: Vector3, margin: float) -> Vector3:
	var q := Vector2(p.x, p.z)
	for part in parts:
		var gp := part.global_position
		if absf(gp.x - q.x) > 40.0 or absf(gp.z - q.y) > 40.0:
			continue
		var r := _rect(part, margin)
		if _inside(r, q):
			var l := _local(r, q)
			var ex := float(r["hx"]) - absf(l.x)
			var ey := float(r["hy"]) - absf(l.y)
			q += r["a"] * signf(l.x) * ex if ex < ey else r["s"] * signf(l.y) * ey
	return Vector3(q.x, p.y, q.y)
