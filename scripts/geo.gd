class_name Geo
extends RefCounted
## Echte Geodaten des Raunheimer Waldsees (siehe tools/fetch_geodata.mjs).
##
## Spielkoordinaten: Ursprung = Startmast T2, -Z zeigt entlang des T2-Seils (fast genau Osten),
## +X zeigt rechts davon (fast genau Süden). y = Höhe über dem Wasserspiegel.

const DIR := "res://assets/geo/"

static var water_level := 0.0
static var origin := Vector2.ZERO        # UTM (E, N) des T2-Startmasts
static var dir_u := Vector2(1, 0)        # Einheitsvektor entlang T2 in UTM (E, N)
static var area := Rect2()               # Datengebiet relativ zum Ursprung (dE, dN), Position = Südwest-Ecke
static var core := Rect2()               # hochaufgelöstes Luftbild relativ zum Ursprung
static var masts := {}                   # Name -> Vector3 in Spielkoordinaten (y = 0)

static var _w := 0
static var _h := 0
static var _terrain := PackedByteArray()
static var _canopy := PackedByteArray()
static var _cw := 0
static var _ch := 0
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "geo.json"))
	water_level = meta["water_level"]
	var m: Dictionary = meta["masts"]
	var a: Array = m["t2_start"]
	var b: Array = m["t2_end"]
	origin = Vector2(a[0], a[1])
	dir_u = (Vector2(b[0], b[1]) - origin).normalized()
	var ar: Dictionary = meta["area"]
	_w = int(ar["w"])
	_h = int(ar["h"])
	area = Rect2(float(ar["e0"]) - origin.x, float(ar["n0"]) - origin.y, _w, _h)
	var co: Dictionary = meta["core"]
	core = Rect2(float(co["e0"]) - origin.x, float(co["n0"]) - origin.y,
		float(co["e1"]) - float(co["e0"]), float(co["n1"]) - float(co["n0"]))
	var cm: Dictionary = meta["canopy"]
	_cw = int(cm["w"])
	_ch = int(cm["h"])
	for key: String in m:
		var p: Array = m[key]
		var g := utm_to_game(float(p[0]), float(p[1]))
		masts[key] = Vector3(g.x, 0.0, g.y)
	# Die Endmasten stehen weiter draußen als in den Daten (Bahnen sind länger, siehe Lake.END_EXTEND)
	for t: String in ["t1", "t2"]:
		var sa: Vector3 = masts[t + "_start"]
		var sb: Vector3 = masts[t + "_end"]
		masts[t + "_end"] = sb + (sb - sa).normalized() * Lake.END_EXTEND
	_terrain = FileAccess.get_file_as_bytes(DIR + "terrain.bin")
	_canopy = FileAccess.get_file_as_bytes(DIR + "canopy.bin")


## UTM (absolut) -> Spiel (x, z)
static func utm_to_game(e: float, n: float) -> Vector2:
	return rel_to_game(e - origin.x, n - origin.y)


## relativ zum Ursprung (dE, dN) -> Spiel (x, z)
static func rel_to_game(de: float, dn: float) -> Vector2:
	return Vector2(de * dir_u.y - dn * dir_u.x, -(de * dir_u.x + dn * dir_u.y))


## Spiel (x, z) -> relativ zum Ursprung (dE, dN)
static func game_to_rel(x: float, z: float) -> Vector2:
	return Vector2(-z * dir_u.x + x * dir_u.y, -z * dir_u.y - x * dir_u.x)


## Spiel-Richtung (Yaw um +Y) einer Himmelsrichtung, z. B. für Gebäude-Ausrichtung im Luftbild.
static func north_yaw() -> float:
	var n := rel_to_game(0.0, 1.0)
	return atan2(-n.x, -n.y)


## Geländehöhe über dem Wasserspiegel (Seeboden ist negativ).
static func height(x: float, z: float) -> float:
	var r := game_to_rel(x, z)
	var fc := r.x - area.position.x - 0.5
	var fr := area.end.y - r.y - 0.5
	return _bilinear_u16(fc, fr)


## Vegetations-/Objekthöhe über dem Gelände (Meter).
static func canopy(x: float, z: float) -> float:
	var r := game_to_rel(x, z)
	var c := clampi(int((r.x - area.position.x) / 2.0), 0, _cw - 1)
	var row := clampi(int((area.end.y - r.y) / 2.0), 0, _ch - 1)
	return _canopy[row * _cw + c] * 0.2


static func _sample(c: int, r: int) -> float:
	c = clampi(c, 0, _w - 1)
	r = clampi(r, 0, _h - 1)
	return _terrain.decode_u16((r * _w + c) * 2) * 0.001 - 20.0


static func _bilinear_u16(fc: float, fr: float) -> float:
	var c0 := floori(fc)
	var r0 := floori(fr)
	var tx := fc - c0
	var ty := fr - r0
	var h00 := _sample(c0, r0)
	var h10 := _sample(c0 + 1, r0)
	var h01 := _sample(c0, r0 + 1)
	var h11 := _sample(c0 + 1, r0 + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


## Spiel-Rechteck (min/max x, z), das das ganze Datengebiet umschließt.
static func game_bounds() -> Rect2:
	var pts := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		var g := rel_to_game(p.x, p.y)
		mn = mn.min(g)
		mx = mx.max(g)
	return Rect2(mn, mx - mn)


static func in_area(x: float, z: float) -> bool:
	return area.has_point(game_to_rel(x, z))
