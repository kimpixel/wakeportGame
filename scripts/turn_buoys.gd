class_name TurnBuoys
extends Node3D
## Wendebojen an jedem Wendepunkt einer Anlage:
##  * rote Boje mittig unter dem Seil = optimale Stelle zum Rauskanten für die Kurve
##  * zwei weiße Bojen links und rechts = um diese fährt man die ideale Kurve herum
## Die Positionen ergeben sich aus den Wendepunkten des Carriers (CableSystem.turn_*_z).

const RED_BEFORE := 20.0       # rote Boje so weit vor dem Wendepunkt des Carriers
const WHITE_BEFORE := 4.0      # weiße Bojen kurz vor dem Wendepunkt ...
const WHITE_SIDE := 7.0        # ... so weit links/rechts vom Seil
const SIZE := 0.75             # Bojengröße (1 = ursprüngliche Größe)
const HIT_HEIGHT := 0.6        # darüber springt man hinweg (keine Berührung)
const DUNK := 0.45             # so tief drückt das Brett die Boje unter Wasser

var water: Water

## Pro Wendepunkt: {"cable", "end" (+1 = Endmast, -1 = Ufer), "red": Vector3, "whites": [Vector3, Vector3]}
var turns: Array[Dictionary] = []
var _floats: Array[Node3D] = []
var _radius: Array[float] = []
var _dip: Array[float] = []        # wie tief die Boje gerade unter Wasser gedrückt ist
var _dip_v: Array[float] = []      # Geschwindigkeit dieser Auf-/Abbewegung (Feder)
var _touched := {}                 # "fahrer:boje" -> gerade berührt (nur einmal "Ups" je Überfahrt)


func add_cable(cable: CableSystem) -> void:
	var red_mat := Util.mat(Color(0.9, 0.12, 0.1), 0.4)
	var white_mat := Util.mat(Color(0.95, 0.95, 0.93), 0.4)
	for end: float in [1.0, -1.0]:
		var turn_z := cable.turn_b_z if end > 0.0 else cable.turn_a_z
		# Abstand vom Startmast; die Bojen liegen auf der Seite, von der man anfährt
		var s_turn := cable.mast_a_z - turn_z
		var red := _place(cable, s_turn - end * RED_BEFORE, 0.0, red_mat, 0.32)
		var whites: Array[Vector3] = []
		for side: float in [-1.0, 1.0]:
			whites.append(_place(cable, s_turn - end * WHITE_BEFORE, side * WHITE_SIDE, white_mat, 0.3))
		turns.append({"cable": cable, "end": end, "s_turn": s_turn, "red": red, "whites": whites})


func _place(cable: CableSystem, s: float, x: float, mat: Material, r: float) -> Vector3:
	var p := cable.transform * Vector3(x, 0.0, cable.mast_a_z - s)
	var buoy := Node3D.new()
	buoy.position = p
	add_child(buoy)
	r *= SIZE
	Util.sphere(buoy, r, Vector3(0, 0.05 * SIZE, 0), mat)
	Util.beam(buoy, Vector3(0, r, 0), Vector3(0, r + 0.25 * SIZE, 0), 0.03 * SIZE, mat)   # kleiner Stab obendrauf
	_floats.append(buoy)
	_radius.append(r)
	_dip.append(0.0)
	_dip_v.append(0.0)
	return p


## Fährt ein Fahrer (Brett-Radius r) über eine Boje? Dann wird sie unter Wasser gedrückt.
## Gibt true nur beim ersten Kontakt zurück (für das kleine "Ups" des Fahrers).
func run_over(p: Vector3, r: float, who: int) -> bool:
	var first := false
	for i in _floats.size():
		var b := _floats[i].position
		var on := p.y < b.y + _dip[i] + HIT_HEIGHT and Vector2(p.x - b.x, p.z - b.z).length() < _radius[i] + r
		if on:
			_dip_v[i] = minf(_dip_v[i], -3.0)            # nach unten weggedrückt
			if not _touched.get("%d:%d" % [who, i], false):
				first = true
		_touched["%d:%d" % [who, i]] = on
	return first


func _process(delta: float) -> void:
	if water == null:
		return
	for i in _floats.size():
		# gedämpfte Feder: Auftrieb holt die Boje wieder an die Oberfläche (leichtes Nachwippen)
		_dip_v[i] += (-60.0 * _dip[i] - 7.0 * _dip_v[i]) * delta
		_dip[i] = clampf(_dip[i] + _dip_v[i] * delta, -DUNK, 0.15)
		var b := _floats[i]
		b.position.y = water.height_at(b.position.x, b.position.z) + _dip[i]
