class_name TurnBuoys
extends Node3D
## Wendebojen an jedem Wendepunkt einer Anlage:
##  * rote Boje mittig unter dem Seil = optimale Stelle zum Rauskanten für die Kurve
##  * zwei weiße Bojen links und rechts = um diese fährt man die ideale Kurve herum
## Die Positionen ergeben sich aus den Wendepunkten des Carriers (CableSystem.turn_*_z).

const RED_BEFORE := 20.0       # rote Boje so weit vor dem Wendepunkt des Carriers
const WHITE_BEFORE := 4.0      # weiße Bojen kurz vor dem Wendepunkt ...
const WHITE_SIDE := 7.0        # ... so weit links/rechts vom Seil

var water: Water

## Pro Wendepunkt: {"cable", "end" (+1 = Endmast, -1 = Ufer), "red": Vector3, "whites": [Vector3, Vector3]}
var turns: Array[Dictionary] = []
var _floats: Array[Node3D] = []


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
	Util.sphere(buoy, r, Vector3(0, 0.05, 0), mat)
	Util.beam(buoy, Vector3(0, r, 0), Vector3(0, r + 0.25, 0), 0.03, mat)   # kleiner Stab obendrauf
	_floats.append(buoy)
	return p


func _process(_delta: float) -> void:
	if water == null:
		return
	for b in _floats:
		b.position.y = water.height_at(b.position.x, b.position.z)
