class_name Lake
extends RefCounted
## Abmessungen der Anlage T2 am Raunheimer Waldsee (Spielkoordinaten, siehe Geo).
## Mastpositionen stammen aus den echten Koordinaten (assets/geo/geo.json).

const CABLE_Y := 10.0          # Höhe des Stahlseils über dem Wasser
const MAST_A_Z := 0.0          # T2-Startmast am Strand
const MAST_B_Z := -197.57      # T2-Endmast im See (Seillänge ca. 198 m)
const PULLEY_RADIUS := 0.15    # Rolle ca. 30 cm Durchmesser
const MAST_B_RADIUS := 3.0     # Kollisionsradius des Endmasts samt Plattform

## Schwimmender Startsteg vor der T2-Hütte (x, z)
const DOCK_MIN := Vector2(-1.2, -12.5)
const DOCK_MAX := Vector2(4.6, -7.4)
const DOCK_Y := 0.28

## Kicker: dir = Richtung (entlang z), in die die Rampe ansteigt.
const KICKERS := [
	{"x": 7.0, "z": -110.0, "dir": -1.0, "len": 6.0, "width": 3.0, "height": 1.3},
	{"x": -7.0, "z": -88.0, "dir": 1.0, "len": 6.0, "width": 3.0, "height": 1.3},
]


static func in_dock(x: float, z: float) -> bool:
	return x > DOCK_MIN.x and x < DOCK_MAX.x and z > DOCK_MIN.y and z < DOCK_MAX.y


## Ist an dieser Stelle (fahrbares) Wasser? Ufer und Land kommen aus dem echten Geländemodell.
static func in_lake(x: float, z: float, margin := 0.0) -> bool:
	return Geo.height(x, z) < -0.1 - margin * 0.3


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
