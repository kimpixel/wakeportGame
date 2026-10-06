class_name Lake
extends RefCounted
## Gemeinsame Abmessungen der Anlage (in Metern). Die Wasseroberfläche liegt bei y = 0.
## Der See erstreckt sich vom Startufer (z = 0) in Richtung -z.

const MIN_X := -90.0
const MAX_X := 90.0
const MIN_Z := -350.0
const MAX_Z := 0.0
const SHORE_Y := 0.5

const CABLE_Y := 10.0          # Höhe des Stahlseils
const MAST_A_Z := 6.0          # Mast 1 steht am Ufer
const MAST_B_Z := -175.0       # Mast 2 steht in der Mitte des Sees
const PULLEY_RADIUS := 0.15    # Rolle ca. 30 cm Durchmesser
const MAST_B_RADIUS := 3.4     # Kollisionsradius Mast 2 inkl. Dreibein

const DOCK_MIN := Vector2(-2.5, -5.0)   # (x, z)
const DOCK_MAX := Vector2(2.5, 1.5)
const DOCK_Y := 0.35

## Kicker: dir = Richtung (entlang z), in die die Rampe ansteigt.
const KICKERS := [
	{"x": 7.0, "z": -95.0, "dir": -1.0, "len": 6.0, "width": 3.0, "height": 1.3},
	{"x": -7.0, "z": -70.0, "dir": 1.0, "len": 6.0, "width": 3.0, "height": 1.3},
]


static func in_dock(x: float, z: float) -> bool:
	return x > DOCK_MIN.x and x < DOCK_MAX.x and z > DOCK_MIN.y and z < DOCK_MAX.y


static func in_lake(x: float, z: float, margin := 0.0) -> bool:
	return x > MIN_X + margin and x < MAX_X - margin and z > MIN_Z + margin and z < MAX_Z - margin


static func kicker_profile(u: float, height: float) -> float:
	return -0.15 + (height + 0.15) * pow(u, 1.6)


## Höhe der Kicker-Oberfläche an (x, z) oder -100, wenn dort kein Kicker ist.
static func kicker_height(x: float, z: float) -> float:
	var best := -100.0
	for k: Dictionary in KICKERS:
		var kx: float = k["x"]
		var kz: float = k["z"]
		var kdir: float = k["dir"]
		var klen: float = k["len"]
		var kw: float = k["width"]
		var kh: float = k["height"]
		if absf(x - kx) > kw * 0.5:
			continue
		var u := ((z - kz) * kdir + klen * 0.5) / klen
		if u < 0.0 or u > 1.0:
			continue
		best = maxf(best, kicker_profile(u, kh))
	return best
