class_name FilmCrew
extends Node3D
## Filmteam in den Community Challenges (Einstellung „Challenge: Filmteam“):
##  * "boat"  – das rote Kunststoffboot von T2 fährt seitlich (Seeseite) neben dem Fahrer mit: hinten
##              sitzt einer am Außenborder (Pinne), in der Mitte steht einer mit der Kamera und filmt.
##              Kommt der Fahrer nicht nach (Sturz, Wende), bleibt das Boot stehen bzw. wendet in einem Bogen.
##  * "drone" – eine FPV-Drohne fliegt vorne-seitlich über dem Fahrer und filmt ihn; der Pilot steht mit
##              FPV-Brille und Funke auf dem Startsteg von T2.
## Ohne Challenge liegt das Boot am weißen Steg (Beach), Drohne und Pilot sind weg.
## "patrol" (ohne Challenge): kommt ein SUP aus der Seemitte der T2-Bahn zu nah (zwischen den Bahnen
## verboten), legt das Boot ab (nur der Fahrer an Bord), fährt seeseitig neben ihn, schickt ihn zurück
## (sup_chased) und legt wieder am Liegeplatz an.
## make_boat() baut das Boot (auch für den Liegeplatz): lokal -Z = Bug, +X = rechts, y = 0 Wasserlinie.

const LANE_X := -15.0          # Spur des Boots (lokal T2, Seeseite = -x)
const LANE_END := 15.0         # so weit bleibt das Boot vor den Wendepunkten
const LEAD := 12.0             # Boot fährt vor dem Fahrer (filmt ihn schräg von vorne)
const BOAT_MAX := 11.0         # m/s (ca. 40 km/h)
const BOAT_ACC := 2.2
const BOAT_DEC := 3.5
const BOAT_TURN := 0.85        # rad/s Wendegeschwindigkeit (Bogen statt auf der Stelle)
const DRONE_AHEAD := 5.0       # Drohne: so weit vor dem Fahrer ...
const DRONE_SIDE := 3.5        # ... seitlich (Seeseite) ...
const DRONE_UP := 2.4          # ... und über dem Wasser
const DRONE_MAX := 22.0        # m/s
const PATROL_X := -19.0        # Patrouille: Spur seeseitig außerhalb der Features (lokal T2)
const PATROL_GAP := 4.0        # so weit seeseitig neben dem SUP hält das Boot
const PATROL_STAY := 5.0       # s bleibt es dort, bis der Paddler weg ist
const PATROL_SPEED := 7.0      # m/s

# Bootsmaße
const STERN_Z := 1.9           # Spiegel
const BOW_Z := -2.1            # Bugspitze
const HULL_N := 30             # Spanten
const HULL_M := 9              # Punkte je halbem Spant
const PLASTIC := Color(0.93, 0.24, 0.1)
const FLOOR_Y := 0.0           # Innenboden

var game: Node                 # main.gd
signal sup_chased(person: Node3D)   # Patrouille: Boot ist beim Paddler angekommen

var mode := ""                 # "", "boat", "drone", "patrol"

var boat: Node3D
var _driver: Person
var _filmer: Person
var _spray: CPUParticles3D
var _motor: AudioStreamPlayer3D   # Außenborder-Geräusch (Tonhöhe/Lautstärke nach Tempo)
var _bpos := Vector2.ZERO      # Boot lokal (x, z) im Rahmen von T2
var _bhead := 0.0              # Kurs: Winkel der Fahrtrichtung (lokal, 0 = +z)
var _bv := 0.0
var _bturn := 0.0
var _t := 0.0
var _target: Node3D            # Patrouille: der Paddler
var _pstate := ""              # "out", "stay", "home"
var _route: Array[Vector2] = []
var _moor := Vector2.ZERO      # Liegeplatz (lokal) und Kurs dort
var _moor_head := 0.0
var _stay := 0.0

var drone: Node3D
var _props: Array[Node3D] = []
var _pilot: Person
var _dvel := Vector3.ZERO
var _dfwd := Vector3.FORWARD


func build() -> void:
	boat = make_boat()
	boat.visible = false
	add_child(boat)
	var grip: Node3D = boat.get_node("tiller_grip")
	_driver = _crew(boat, "boat_driver", "res://assets/characters/guest_m.glb", Vector3(-0.38, 0.24, 1.45), 0.35)
	if _driver:
		_driver.hold = grip
	_filmer = _crew(boat, "filmer", "res://assets/characters/guest_f.glb", Vector3(0.05, -0.02, 0.1), PI)
	_spray = CPUParticles3D.new()
	_spray.amount = 40
	_spray.lifetime = 0.7
	_spray.emitting = false
	_spray.local_coords = false
	_spray.direction = Vector3(0, 1, 1)
	_spray.spread = 35.0
	_spray.initial_velocity_min = 1.0
	_spray.initial_velocity_max = 2.5
	_spray.gravity = Vector3(0, -6, 0)
	_spray.scale_amount_min = 0.5
	_spray.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	_spray.mesh = dot
	var foam := Util.mat(Color(0.95, 0.97, 0.98), 0.3)
	_spray.material_override = foam
	_spray.position = Vector3(0, -0.05, STERN_Z + 0.35)
	boat.add_child(_spray)
	if game.sfx:
		_motor = AudioStreamPlayer3D.new()
		_motor.stream = game.sfx.make_outboard_loop()
		_motor.bus = Sfx.BUS_FX
		_motor.unit_size = 9.0
		_motor.max_distance = 250.0
		_motor.position = Vector3(0, 0.5, STERN_Z + 0.25)
		boat.add_child(_motor)

	drone = _make_drone()
	drone.visible = false
	add_child(drone)
	_pilot = Person.new()
	_pilot.kind = "pilot"
	_pilot.visible = false
	add_child(_pilot)
	_pilot.global_position = Vector3(Lake.DOCK_MAX.x - 0.9, Lake.DOCK_Y, Lake.DOCK_MIN.y + 0.8)   # vordere Ecke, neben den Wartenden
	_pilot.rotation.y = PI
	if not _pilot.setup("res://assets/characters/operator.glb"):
		_pilot.queue_free()
		_pilot = null
	else:
		_pilot.watch = drone
		_pilot.watch_offset = Vector3.ZERO
	set_physics_process(false)


func _crew(parent: Node3D, kind: String, model: String, at: Vector3, yaw: float) -> Person:
	var p := Person.new()
	p.kind = kind
	parent.add_child(p)
	p.position = at
	p.rotation.y = yaw
	if not p.setup(model):
		p.queue_free()
		return null
	return p


## Filmteam für eine Challenge einsetzen. choice: 0 Zufall, 1 Boot, 2 Drohne, 3 aus.
func start(choice: int) -> void:
	match choice:
		0:
			mode = "boat" if randi() % 2 == 0 else "drone"
		1:
			mode = "boat"
		2:
			mode = "drone"
		_:
			mode = ""
	var r: Rider = game.rider
	for p: Person in [_driver, _filmer]:
		if p:
			p.watch = r
			p.visible = true
	boat.visible = mode == "boat"
	if _motor:
		if mode == "boat":
			_motor.play(randf())
		else:
			_motor.stop()
	if game.beach.boat:
		game.beach.boat.visible = mode != "boat"
	drone.visible = mode == "drone"
	if _pilot:
		_pilot.visible = mode == "drone"
	set_physics_process(mode != "")
	snap()


func stop() -> void:
	mode = ""
	boat.visible = false
	_spray.emitting = false
	if _motor:
		_motor.stop()
	if game.beach.boat:
		game.beach.boat.visible = true
	drone.visible = false
	if _pilot:
		_pilot.visible = false
	set_physics_process(false)


## Neuer Versuch: Boot bzw. Drohne sofort passend zum (neu platzierten) Fahrer setzen.
func snap() -> void:
	var r: Rider = game.rider
	if mode == "boat":
		var rl := _local(r.pos)
		var dz := _rider_dirz()
		_bpos = Vector2(LANE_X, _clamp_z(rl.z + dz * LEAD))
		_bhead = 0.0 if dz > 0.0 else PI
		_bv = clampf(absf(_local_dir(r.vel).z), 0.0, BOAT_MAX)
		_bturn = 0.0
		_place_boat(0.0)
	elif mode == "drone":
		var h := Vector3(r.vel.x, 0.0, r.vel.z)
		if h.length() > 0.5:
			_dfwd = h.normalized()
		drone.global_position = _drone_target()
		_dvel = Vector3.ZERO
		_orient_drone(0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if mode == "boat":
		_drive_boat(delta)
	elif mode == "drone":
		_fly_drone(delta)
	elif mode == "patrol":
		_patrol(delta)


# ---------------------------------------------------------------- Patrouille

## SUP kommt der T2-Bahn zu nah: Boot legt ab und fährt hin (nur ohne Challenge).
func chase(sup: Node3D) -> void:
	if mode != "" or game.beach.boat == null:
		return
	var moored: Node3D = game.beach.boat
	var m := _local(moored.global_position)
	var bow := _local_dir(-moored.global_basis.z)
	_moor = Vector2(m.x, m.z)
	_moor_head = atan2(bow.x, bow.z)
	_bpos = _moor
	_bhead = _moor_head
	_bv = 0.0
	_bturn = 0.0
	_target = sup
	_pstate = "out"
	_route = [Vector2(PATROL_X, _moor.y - 4.0)]
	mode = "patrol"
	if _filmer:
		_filmer.visible = false
	if _driver:
		_driver.watch = sup
	boat.visible = true
	moored.visible = false
	if _motor:
		_motor.play(randf())
	set_physics_process(true)
	_place_boat(0.0)
	print("BOOT legt ab")


func _patrol(delta: float) -> void:
	match _pstate:
		"out":
			if not is_instance_valid(_target):
				_go_home()
			elif not _route.is_empty():
				if _drive_to(_route[0], PATROL_SPEED, false, delta) < 5.0:
					_route.remove_at(0)
			else:
				var t := _local(_target.global_position)
				if _drive_to(Vector2(t.x - PATROL_GAP, t.z), PATROL_SPEED, true, delta) < 3.0 and _bv < 1.0:
					_pstate = "stay"
					_stay = PATROL_STAY
					sup_chased.emit(_target)
					print("BOOT beim SUP ", _target.global_position)
		"stay":
			_bv = move_toward(_bv, 0.0, BOAT_DEC * delta)
			_bturn = move_toward(_bturn, 0.0, delta)
			_place_boat(delta)
			_stay -= delta
			if _stay <= 0.0:
				_go_home()
		"home":
			if not _route.is_empty():
				if _drive_to(_route[0], PATROL_SPEED, false, delta) < 5.0:
					_route.remove_at(0)
			elif _drive_to(_moor, PATROL_SPEED, true, delta) < 1.5 and _bv < 1.2:
				_dock()


func _go_home() -> void:
	_pstate = "home"
	_route = [Vector2(PATROL_X, _moor.y - 4.0)]
	if _driver:
		_driver.watch = game.rider


## Wieder am Liegeplatz: fahrendes Boot weg, das festgemachte wieder da.
func _dock() -> void:
	mode = ""
	boat.visible = false
	_spray.emitting = false
	if _motor:
		_motor.stop()
	if _filmer:
		_filmer.visible = true
	if game.beach.boat:
		game.beach.boat.visible = true
	set_physics_process(false)
	print("BOOT angelegt")


## Kurs auf ein Ziel (lokal), bremst bei stop rechtzeitig davor. Liefert die Entfernung.
func _drive_to(goal: Vector2, v_max: float, stop: bool, delta: float) -> float:
	var aim := goal - _bpos
	var dist := aim.length()
	var d_ang := wrapf(atan2(aim.x, aim.y) - _bhead, -PI, PI)
	var rate := BOAT_TURN * clampf(0.3 + _bv / 3.0, 0.3, 1.0)
	_bturn = clampf(d_ang * 2.0, -rate, rate)
	_bhead = wrapf(_bhead + _bturn * delta, -PI, PI)
	var v_want := v_max * clampf(cos(d_ang), 0.25, 1.0)
	if stop:
		v_want = minf(v_want, sqrt(2.0 * BOAT_DEC * 0.7 * dist))
	if dist > 3.0:
		v_want = maxf(v_want, 1.2)                     # im Bogen weiter, nicht auf der Stelle drehen
	_bv = move_toward(_bv, v_want, (BOAT_ACC if v_want > _bv else BOAT_DEC) * delta)
	_bpos += Vector2(sin(_bhead), cos(_bhead)) * _bv * delta
	_place_boat(delta)
	return dist


# ---------------------------------------------------------------- Boot

func _cable() -> CableSystem:
	return game.cable


func _local(world: Vector3) -> Vector3:
	return _cable().global_transform.affine_inverse() * world


func _local_dir(world: Vector3) -> Vector3:
	return _cable().global_transform.basis.inverse() * world


func _clamp_z(z: float) -> float:
	var c := _cable()
	return clampf(z, c.turn_b_z + LANE_END, c.turn_a_z - LANE_END)


## Fahrtrichtung des Fahrers entlang des Seils (lokal z: -1 raus, +1 zum Ufer).
func _rider_dirz() -> float:
	var vz := _local_dir(game.rider.vel).z
	if absf(vz) > 0.5:
		return signf(vz)
	return _cable().dir


func _drive_boat(delta: float) -> void:
	var r: Rider = game.rider
	var rl := _local(r.pos)
	var rvz := _local_dir(r.vel).z
	var raw := rl.z + _rider_dirz() * LEAD
	var target := _clamp_z(raw)
	var at_end := not is_equal_approx(raw, target)     # Ziel liegt hinter dem Spurende (Wende)
	var err := target - _bpos.y
	# gewünschte Richtung entlang der Spur: zum Ziel, sonst mit dem Fahrer mit; am Spurende warten
	var dz := 0.0
	if absf(err) > 2.0:
		dz = signf(err)
	elif absf(rvz) > 1.5 and not at_end:
		dz = signf(rvz)
	var v_want := 0.0
	if dz != 0.0:
		var with_rider := absf(rvz) if signf(rvz) == dz and not at_end else 0.0
		v_want = clampf(with_rider + err * dz * 0.6, 0.0, BOAT_MAX)
		# rechtzeitig bremsen: nicht über das Ziel am Spurende bzw. das Spurende hinaus
		var room := _clamp_z(_bpos.y + dz * 1000.0) - _bpos.y
		if at_end:
			room = err
		v_want = minf(v_want, sqrt(2.0 * BOAT_DEC * 0.7 * maxf(absf(room), 0.0)))
		# Zielpunkt 8 m voraus auf der Spur: zieht das Boot zurück auf die Linie
		var aim := Vector2(LANE_X, _bpos.y + dz * 8.0) - _bpos
		var want_head := atan2(aim.x, aim.y)
		var d_ang := wrapf(want_head - _bhead, -PI, PI)
		if absf(d_ang) > 2.0 and absf(cos(_bhead)) > 0.3:
			# Umdrehen immer über die Seeseite (-x), nie Richtung Seil und Fahrer
			d_ang = -signf(cos(_bhead)) * absf(d_ang)
		var rate := BOAT_TURN * clampf(0.3 + _bv / 3.0, 0.3, 1.0)
		_bturn = clampf(d_ang * 2.0, -rate, rate)
		_bhead = wrapf(_bhead + _bturn * delta, -PI, PI)
		v_want *= clampf(cos(d_ang), 0.3, 1.0)           # beim Wenden langsamer
		v_want = maxf(v_want, 1.5 if absf(d_ang) > 0.3 else 0.0)
	else:
		_bturn = move_toward(_bturn, 0.0, delta)
	_bv = move_toward(_bv, v_want, (BOAT_ACC if v_want > _bv else BOAT_DEC) * delta)
	_bpos += Vector2(sin(_bhead), cos(_bhead)) * _bv * delta
	_place_boat(delta)


func _place_boat(_delta: float) -> void:
	var c := _cable()
	var p := c.global_transform * Vector3(_bpos.x, 0.0, _bpos.y)
	var d := c.global_transform.basis * Vector3(sin(_bhead), 0.0, cos(_bhead))
	var yaw := atan2(-d.x, -d.z)
	# Bug hebt sich mit Tempo, legt sich leicht in die Kurve, schaukelt ein wenig
	var pitch := 0.07 * clampf(_bv / 6.0, 0.0, 1.0) + sin(_t * 1.7) * 0.012
	var roll := -_bturn * 0.12 + sin(_t * 1.3 + 0.7) * 0.015
	var h: float = game.water.height_at(p.x, p.z) if game.water else 0.0
	boat.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll), EULER_ORDER_YXZ),
		Vector3(p.x, h + 0.03 + sin(_t * 1.1) * 0.02 - 0.02 * clampf(_bv / 6.0, 0.0, 1.0), p.z))
	_spray.emitting = _bv > 2.0
	if _motor:                                          # Standgas tuckert, mit Tempo höher und lauter
		var thr := clampf(_bv / BOAT_MAX + absf(_bturn) * 0.2, 0.0, 1.0)
		_motor.pitch_scale = lerpf(0.45, 1.25, thr)
		_motor.volume_db = lerpf(-9.0, 0.0, thr)


# ---------------------------------------------------------------- Drohne

func _drone_target() -> Vector3:
	var r: Rider = game.rider
	var sea := _cable().global_transform.basis * Vector3(-1.0, 0.0, 0.0)
	var p := r.pos + _dfwd * DRONE_AHEAD + sea * DRONE_SIDE
	p.y = maxf(r.pos.y, 0.0) + DRONE_UP
	return p


func _fly_drone(delta: float) -> void:
	var r: Rider = game.rider
	var h := Vector3(r.vel.x, 0.0, r.vel.z)
	if h.length() > 1.0:
		_dfwd = _dfwd.slerp(h.normalized(), clampf(delta * 1.5, 0.0, 1.0)).normalized()
	var to := _drone_target() - drone.global_position
	# fliegt mit dem Fahrer mit und gleicht den Abstand zum Zielpunkt weich aus, Tempo begrenzt
	var want := h + to * 1.5
	if want.length() > DRONE_MAX:
		want = want.normalized() * DRONE_MAX
	_dvel = _dvel.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	drone.global_position += _dvel * delta
	_orient_drone(delta)
	for i in _props.size():
		_props[i].rotate_y((1.0 if i % 2 == 0 else -1.0) * 90.0 * delta)


func _orient_drone(_delta: float) -> void:
	var r: Rider = game.rider
	var look := r.pos + Vector3(0, 1.0, 0) - drone.global_position
	var yaw := atan2(-look.x, -look.z)
	var b := Basis(Vector3.UP, yaw)
	# kippt in Flugrichtung wie ein echter Kopter
	var tilt_axis := Vector3.UP.cross(_dvel)
	if tilt_axis.length() > 0.01:
		b = Basis(tilt_axis.normalized(), clampf(_dvel.length() * 0.03, 0.0, 0.45)) * b
	drone.global_basis = b


## FPV-Drohne (5-Zoll-Klasse, ca. 25 cm): Carbon-Rahmen, vier Motoren mit Propellern,
## Action-Kamera oben drauf, LEDs. Lokal -Z = vorne (Kamera).
func _make_drone() -> Node3D:
	var d := Node3D.new()
	var carbon := Util.mat(Color(0.07, 0.07, 0.08), 0.5)
	var grey := Util.mat(Color(0.35, 0.36, 0.38), 0.4)
	Util.box(d, Vector3(0.08, 0.035, 0.16), Vector3.ZERO, carbon)                    # Mittelteil
	Util.box(d, Vector3(0.06, 0.03, 0.08), Vector3(0, 0.03, 0.01), Util.mat(Color(0.9, 0.3, 0.1), 0.6))   # Akku
	Util.box(d, Vector3(0.045, 0.04, 0.06), Vector3(0, 0.065, -0.04), carbon)         # Action-Kamera
	var lens := Util.sphere(d, 0.012, Vector3(0, 0.065, -0.072), Util.mat(Color(0.1, 0.15, 0.25), 0.1))
	lens.scale = Vector3(1, 1, 0.5)
	var prop_mesh := CylinderMesh.new()
	prop_mesh.top_radius = 0.065
	prop_mesh.bottom_radius = 0.065
	prop_mesh.height = 0.004
	var blur := StandardMaterial3D.new()
	blur.albedo_color = Color(0.2, 0.2, 0.22, 0.35)
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.roughness = 0.5
	var blade_mat := Util.mat(Color(0.9, 0.9, 0.92), 0.4)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var tip := Vector3(sin(a), 0.0, cos(a)) * 0.11
		Util.beam(d, Vector3.ZERO, tip, 0.012, carbon)                                 # Arm
		var motor := Util.box(d, Vector3(0.025, 0.022, 0.025), tip + Vector3(0, 0.015, 0), grey)
		motor.name = "motor%d" % k
		var prop := Node3D.new()
		prop.position = tip + Vector3(0, 0.03, 0)
		d.add_child(prop)
		var disc := MeshInstance3D.new()
		disc.mesh = prop_mesh
		disc.material_override = blur
		prop.add_child(disc)
		Util.box(prop, Vector3(0.12, 0.003, 0.012), Vector3.ZERO, blade_mat)          # sichtbares Blatt
		_props.append(prop)
		# LEDs: vorne grün, hinten rot
		var led := Util.mat(Color(0.2, 1.0, 0.3) if tip.z < 0.0 else Color(1.0, 0.15, 0.1), 0.3, true)
		Util.sphere(d, 0.008, tip * 0.6 + Vector3(0, -0.02, 0), led)
	# etwas größer als echt (7-Zoll-Klasse), damit man sie im Bild auch sieht
	var outer := Node3D.new()
	d.scale = Vector3.ONE * 1.5
	outer.add_child(d)
	return outer


# ---------------------------------------------------------------- Bootsmodell

## Rotes Kunststoffboot (Ruderboot-Rumpf aus einem Stück, ca. 4 m): spitzer Bug mit Sprung, gerader
## Spiegel mit Außenborder und Pinne, innen Sitzbänke und Mulden, schwarze Griffe auf der Bordkante.
## Knoten "tiller_grip" = Griff der Pinne (für die Hand des Fahrers).
static func make_boat() -> Node3D:
	var boat := Node3D.new()
	var red := Util.mat(PLASTIC, 0.42)
	var red_dark := Util.mat(PLASTIC.darkened(0.12), 0.5)
	var black := Util.mat(Color(0.06, 0.06, 0.07), 0.6)
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for i in HULL_N + 1:
		var t := float(i) / HULL_N
		outer.append(_section(t, false))
		inner.append(_section(t, true))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, outer, 1.0)
	_grid(st, inner, -1.0)
	# Bordkante (Außen- zu Innenhaut) und Spiegel (Wandstärke + Platte)
	for i in HULL_N:
		for j: int in [0, 2 * HULL_M]:
			_quad(st, outer[i][j], outer[i + 1][j], inner[i + 1][j], inner[i][j], Vector3.UP)
	for j in 2 * HULL_M:
		_quad(st, outer[0][j], outer[0][j + 1], inner[0][j + 1], inner[0][j], Vector3.BACK)
	var top_mid := (inner[0][0] + inner[0][2 * HULL_M]) * 0.5
	for j in 2 * HULL_M:
		_tri(st, top_mid, inner[0][j], inner[0][j + 1], Vector3.BACK)
		_tri(st, top_mid, inner[0][j], inner[0][j + 1], Vector3.FORWARD)
	var hull := MeshInstance3D.new()
	hull.mesh = st.commit()
	hull.material_override = red
	boat.add_child(hull)
	# Scheuerleiste und Rippen außen (waagerechte Kanten im Kunststoff)
	var ribs := SurfaceTool.new()
	ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frac: float in [0.35, 0.62]:
		var j := int(round(HULL_M * (1.0 - frac)))
		for side: int in [j, 2 * HULL_M - j]:
			for i in HULL_N - 2:
				var a := outer[i][side]
				var b := outer[i + 1][side]
				var oa := Vector3(a.x, 0.0, 0.0).normalized() * 0.012
				var ob := Vector3(b.x, 0.0, 0.0).normalized() * 0.012
				var up := Vector3(0, 0.014, 0)
				_quad(ribs, a + oa - up, b + ob - up, b + ob + up, a + oa + up, oa)
	var rib_mesh := MeshInstance3D.new()
	rib_mesh.mesh = ribs.commit()
	rib_mesh.material_override = red_dark
	boat.add_child(rib_mesh)
	# eingeformte Sitzbänke (Heck, Mitte, vorne) und Bugdeck
	for seat: Array in [[1.55, 0.6, 0.22], [0.1, 0.45, 0.2], [-1.05, 0.35, 0.22]]:
		var z: float = seat[0]
		_seat(boat, _half_width(z, true) * 2.0 + 0.02, seat[1], z, seat[2], red, red_dark)
	# schwarze Griffe auf der Bordkante
	for z: float in [1.45, 0.1, -1.2]:
		for sx: float in [-1.0, 1.0]:
			var x := _half_width(z, false) * sx
			var y := _gunwale_y(z) + 0.02
			Util.beam(boat, Vector3(x, y, z - 0.08), Vector3(x, y + 0.03, z - 0.05), 0.012, black)
			Util.beam(boat, Vector3(x, y + 0.03, z - 0.05), Vector3(x, y + 0.03, z + 0.05), 0.012, black)
			Util.beam(boat, Vector3(x, y + 0.03, z + 0.05), Vector3(x, y, z + 0.08), 0.012, black)
	# Ausstattung: weiße Kühlbox vorne, roter Tank mit schwarzem Deckel hinten
	Util.box(boat, Vector3(0.5, 0.32, 0.36), Vector3(0.12, 0.15, -0.5), Util.mat(Color(0.94, 0.94, 0.92), 0.5))
	Util.box(boat, Vector3(0.52, 0.04, 0.38), Vector3(0.12, 0.32, -0.5), Util.mat(Color(0.85, 0.86, 0.84), 0.5))
	Util.box(boat, Vector3(0.3, 0.22, 0.42), Vector3(0.38, 0.34, 1.5), Util.mat(Color(0.8, 0.1, 0.08), 0.5))
	Util.box(boat, Vector3(0.06, 0.04, 0.06), Vector3(0.38, 0.47, 1.38), black)
	_outboard(boat)
	return boat


## Halbspant bei t (0 = Spiegel, 1 = Bugspitze): Punkte von der linken Bordkante über den Kiel
## zur rechten. inner: Innenhaut (Wandstärke, Boden höher).
static func _section(t: float, inner: bool) -> PackedVector3Array:
	var z := lerpf(STERN_Z, BOW_Z, t)
	var w := _width_t(t)
	var g := 0.3 + 0.2 * pow(t, 2.2)                             # Bordkante steigt zum Bug (Sprung)
	var k := -0.17 + 0.62 * pow(maxf(t - 0.55, 0.0) / 0.45, 1.7)  # Kiel läuft zum Steven hoch
	if inner:
		w = maxf(w - 0.05, 0.0)
		k = minf(k + 0.13, g - 0.02)
	var pts := PackedVector3Array()
	for j in range(-HULL_M, HULL_M + 1):
		var th := absf(j) / float(HULL_M) * PI * 0.5
		var side := signf(j)
		var y := k + (g - k) * (1.0 - cos(th))
		if inner:
			y = maxf(y, minf(FLOOR_Y, g - 0.02))                   # innen flacher Boden
		pts.append(Vector3(side * w * pow(sin(th), 0.45), y, z))
	# Reihenfolge: linke Bordkante zuerst
	return pts


static func _width_t(t: float) -> float:
	if t < 0.42:
		return lerpf(0.68, 0.78, smoothstep(0.0, 0.42, t))
	var u := (t - 0.42) / 0.58
	return 0.78 * pow(maxf(1.0 - u * u, 0.0), 0.7)


static func _half_width(z: float, inner: bool) -> float:
	var t := clampf((STERN_Z - z) / (STERN_Z - BOW_Z), 0.0, 1.0)
	return maxf(_width_t(t) - (0.06 if inner else 0.0), 0.0)


static func _gunwale_y(z: float) -> float:
	var t := clampf((STERN_Z - z) / (STERN_Z - BOW_Z), 0.0, 1.0)
	return 0.3 + 0.2 * pow(t, 2.2)


## Fläche aus Spanten; outward = +1 Außenhaut (Normalen nach außen), -1 Innenhaut.
static func _grid(st: SurfaceTool, g: Array[PackedVector3Array], outward: float) -> void:
	var rows := g.size()
	var cols := g[0].size()
	var normals: Array[PackedVector3Array] = []
	for i in rows:
		var row := PackedVector3Array()
		for j in cols:
			var p := g[i][j]
			var du := g[mini(i + 1, rows - 1)][j] - g[maxi(i - 1, 0)][j]
			var dv := g[i][mini(j + 1, cols - 1)] - g[i][maxi(j - 1, 0)]
			var hint := Vector3(p.x, p.y - 0.6, minf(p.z + 1.0, 0.0) * 0.6) * outward
			var n := du.cross(dv)
			if n.length() < 1e-6:
				n = hint
			n = n.normalized()
			if n.dot(hint) < 0.0:
				n = -n
			row.append(n)
		normals.append(row)
	for i in rows - 1:
		for j in cols - 1:
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector2i = q[tri[0]]
				var b: Vector2i = q[tri[1]]
				var c: Vector2i = q[tri[2]]
				var pa := g[a.x][a.y]
				var pb := g[b.x][b.y]
				var pc := g[c.x][c.y]
				if (pb - pa).cross(pc - pa).length() < 1e-7:
					continue
				var na := normals[a.x][a.y]
				var nb := normals[b.x][b.y]
				var nc := normals[c.x][c.y]
				var nsum := na + nb + nc
				if (pb - pa).cross(pc - pa).dot(nsum) > 0.0:     # Godot: Vorderseite im Uhrzeigersinn
					var tp := pb
					pb = pc
					pc = tp
					var tn := nb
					nb = nc
					nc = tn
				for v: Array in [[pa, na], [pb, nb], [pc, nc]]:
					st.set_normal(v[1])
					st.add_vertex(v[0])


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).length() < 1e-7:
		return
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-7:
		n = (c - a).cross(d - a)
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## Eingeformte Sitzbank: Block mit geriffelter Oberseite.
static func _seat(boat: Node3D, w: float, depth: float, z: float, top: float, mat: Material, ribs: Material) -> void:
	Util.box(boat, Vector3(w, 0.05, depth), Vector3(0, top - 0.025, z), mat)          # Sitzfläche
	var h := top - FLOOR_Y
	Util.box(boat, Vector3(w * 0.55, h, depth * 0.85), Vector3(0, FLOOR_Y + h * 0.5, z), mat)   # Sockel
	var n := int(depth / 0.08)
	for k in n:
		var zz := z - depth * 0.5 + (k + 0.5) * depth / n
		Util.box(boat, Vector3(w * 0.8, 0.012, 0.025), Vector3(0, top + 0.004, zz), ribs)


## Außenborder (dunkelgrau) mittig am Spiegel, Pinne nach vorne links.
static func _outboard(boat: Node3D) -> void:
	var m := Node3D.new()
	m.position = Vector3(0, 0.0, STERN_Z + 0.12)
	boat.add_child(m)
	var cowl := Util.mat(Color(0.2, 0.21, 0.23), 0.35)
	var dark := Util.mat(Color(0.08, 0.08, 0.09), 0.6)
	var light := Util.mat(Color(0.55, 0.56, 0.58), 0.4)
	Util.box(m, Vector3(0.1, 0.18, 0.1), Vector3(0, 0.22, -0.06), dark)              # Klemmbock am Spiegel
	var c := Util.box(m, Vector3(0.3, 0.32, 0.42), Vector3(0, 0.52, 0.12), cowl)      # Motorhaube
	c.name = "cowl"
	var top := Util.sphere(m, 0.2, Vector3(0, 0.66, 0.12), cowl)
	top.scale = Vector3(0.75, 0.4, 1.05)
	Util.box(m, Vector3(0.305, 0.035, 0.425), Vector3(0, 0.42, 0.12), light)         # Zierstreifen
	Util.box(m, Vector3(0.12, 0.62, 0.12), Vector3(0, 0.06, 0.12), cowl)              # Schaft
	Util.box(m, Vector3(0.11, 0.12, 0.34), Vector3(0, -0.3, 0.14), cowl)              # Getriebe
	Util.box(m, Vector3(0.02, 0.14, 0.12), Vector3(0, -0.42, 0.2), cowl)              # Skeg
	Util.box(m, Vector3(0.32, 0.015, 0.2), Vector3(0, -0.18, 0.12), cowl)             # Antiventilationsplatte
	for k in 3:
		var bl := Util.box(m, Vector3(0.05, 0.16, 0.012), Vector3(0, -0.3, 0.33), dark)  # Propeller
		bl.rotation.z = k * TAU / 3.0
	# Pinne: von der Haube schräg nach vorne links, Griff am Ende
	var a := Vector3(-0.08, 0.5, -0.1)
	var b := Vector3(-0.3, 0.45, -0.68)
	Util.beam(m, a, b, 0.025, dark)
	var grip := Node3D.new()
	grip.name = "tiller_grip"
	grip.position = m.position + b
	boat.add_child(grip)
