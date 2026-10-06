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


func _place(row: Dictionary, cable: CableSystem, file: String) -> void:
	var id: String = row.get("part", "")
	if not _catalog.has(id):
		push_warning("Setup %s: Bauteil '%s' fehlt im Katalog" % [file, id])
		return
	# Katalogwerte, einzelne Werte dürfen im Setup überschrieben werden
	var p: Dictionary = (_catalog[id] as Dictionary).duplicate()
	for key: String in ["length", "width", "height", "height_end", "ramp_in", "ramp_out", "curve", "name"]:
		if row.has(key):
			p[key] = row[key]
	var part := FeaturePart.new()
	part.setup(id, p)
	var s: float = row.get("s", 0.0)
	var x: float = row.get("x", 0.0)
	var yaw := deg_to_rad(float(row.get("yaw", 0.0)))
	if row.get("dir", "out") == "in":
		yaw += PI
	# Position im lokalen Raum der Anlage (Seil entlang -z) -> Welt
	part.transform = cable.transform * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, cable.mast_a_z - s))
	add_child(part)
	parts.append(part)


func _read_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return data
	push_warning("Konnte %s nicht lesen" % path)
	return {}


## Höchste Hindernis-Oberkante an (x, z) oder FeaturePart.NONE.
func height_at(x: float, z: float) -> float:
	var best := FeaturePart.NONE
	for part in parts:
		best = maxf(best, part.height_at(x, z))
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
