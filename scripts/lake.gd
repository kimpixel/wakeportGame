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

static func in_dock(x: float, z: float) -> bool:
	return x > DOCK_MIN.x and x < DOCK_MAX.x and z > DOCK_MIN.y and z < DOCK_MAX.y


## Ist an dieser Stelle (fahrbares) Wasser? Ufer und Land kommen aus dem echten Geländemodell.
static func in_lake(x: float, z: float, margin := 0.0) -> bool:
	return Geo.height(x, z) < -0.1 - margin * 0.3

