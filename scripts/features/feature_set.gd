class_name FeatureSet
extends Node3D
## Lädt den Bauteile-Katalog (setups/parts.json) und die Feature-Setups der Terminals
## (setups/terminal1.json, terminal2.json) und stellt die Teile entlang der Seile auf.
## Bietet der Fahrerphysik eine Abfrage der Hindernis-Oberkante an jedem Punkt.

const PARTS_FILE := "res://setups/parts.json"

var parts: Array[FeaturePart] = []
var _catalog: Dictionary = {}


## terminals: z. B. {"T1": cable_t1, "T2": cable}
func load_setups(files: Array[String], terminals: Dictionary) -> void:
	_catalog = _read_json(PARTS_FILE)
	for file in files:
		var setup := _read_json(file)
		var cable: CableSystem = terminals.get(setup.get("terminal", ""))
		if cable == null:
			push_warning("Setup %s: unbekanntes Terminal" % file)
			continue
		for row: Dictionary in setup.get("parts", []):
			_place(row, cable, file)


func _place(row: Dictionary, cable: CableSystem, file: String, parent := Transform3D.IDENTITY) -> void:
	var id: String = row.get("part", "")
	if not _catalog.has(id):
		push_warning("Setup %s: Bauteil '%s' fehlt im Katalog" % [file, id])
		return
	var s: float = row.get("s", 0.0)
	var x: float = row.get("x", 0.0)
	var yaw := deg_to_rad(float(row.get("yaw", 0.0)))
	if row.get("dir", "out") == "in":
		yaw += PI
	# Position relativ zum Elternteil (Gruppe) bzw. zum Startmast, Seil entlang -z
	var local := parent * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, -s))
	var entry: Dictionary = _catalog[id]
	if entry.get("type", "") == "group":
		# Gruppe: mehrere Teile, die zusammen ein Feature bilden (z. B. Pyramid Series)
		for child: Dictionary in entry.get("parts", []):
			_place(child, cable, file, local)
		return
	# Katalogwerte, einzelne Werte dürfen im Setup überschrieben werden
	var p: Dictionary = entry.duplicate()
	for key: String in ["length", "width", "height", "height_end", "ramp_in", "ramp_out", "ramp_curve", "curve", "radius", "center_y", "color", "name"]:
		if row.has(key):
			p[key] = row[key]
	var part := FeaturePart.new()
	part.setup(id, p)
	part.cable = cable
	var world := cable.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, cable.mast_a_z)) * local
	part.transform = world
	var on_cable := cable.transform.affine_inverse() * world.origin
	part.s_center = cable.mast_a_z - on_cable.z
	part.x_center = on_cable.x
	add_child(part)
	parts.append(part)


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
