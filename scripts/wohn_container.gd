class_name WohnContainer
extends RefCounted
## Wohncontainer (umgebauter Container zum Übernachten), Modell aus tools/container/build_container.py.
## Die Hausnummer neben der Schiebetür ist je Container verschieden und wird hier als Text eingesetzt
## (Marke "Hausnummer" im Modell = Mitte der Zahl, mittig über der Leuchte).
## Lage: Ursprung = Mitte der Grundfläche am Boden, 12 × 3 m; Vorderseite (Glas, Schiebetür) zeigt nach −X.

const MODEL := preload("res://assets/buildings/wohncontainer.glb")
const NUMBER_SIZE := 0.0075   # Meter je Schriftpixel (font_size 42 → Ziffern ca. 0,21 m hoch)

static var _number_mat: StandardMaterial3D


static func make(number: int) -> Node3D:
	var root: Node3D = MODEL.instantiate()
	var mark := root.find_child("Hausnummer", true, false) as Node3D
	if mark == null:
		push_warning("WohnContainer: Marke Hausnummer fehlt")
		return root
	var text := TextMesh.new()
	text.text = str(number)
	text.font_size = 42
	text.pixel_size = NUMBER_SIZE
	text.depth = 0.004
	if _number_mat == null:
		_number_mat = StandardMaterial3D.new()
		_number_mat.albedo_color = Color(0.08, 0.08, 0.085)
		_number_mat.roughness = 0.5
	var mi := MeshInstance3D.new()
	mi.name = "Nummer"
	mi.mesh = text
	mi.material_override = _number_mat
	# Text schaut nach +Z, die Wand nach −X: um −90° um die Hochachse drehen
	mi.basis = Basis(Vector3.UP, -PI / 2.0)
	mi.position.x = -text.depth / 2.0
	mark.add_child(mi)
	return root
