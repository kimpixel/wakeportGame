class_name Park
extends RefCounted
## Der gewählte Wakepark (parks/<id>/park.json): Lage, Zeitzone, Geodaten, Feature-Setups und seine Anlagen.
##
## Jede Anlage (System) hat eine id (beim Wakeport "T1"/"T2" – so heißen auch die Schlüssel in den Setup-Dateien
## und Ranglisten), einen Anzeigenamen und einen Typ: "2.0" = 2-Mast-Anlage (Carrier pendelt), "full" = Rundanlage
## (kommt noch). Die Anlage mit "origin": true legt die Spielkoordinaten fest (Startmast = Ursprung, Seil entlang -z).

const INDEX := "res://parks/index.json"
const TYPE_NAMES := {"2.0": "2-Mast-Anlage (2.0)", "full": "Rundanlage"}  # i18n
## Anlagen-Typen, die das Spiel fahren kann ("2.0" = CableSystem, "full" = FullCable). Andere stehen in park.json
## und auf der World Map, werden aber nicht gebaut.
const PLAYABLE := ["2.0", "full"]
## Standard-Überschrift der Anlagen-Auswahl (siehe system_label), nur damit der Text übersetzt wird.
const LABELS := ["ANLAGE"]  # i18n

static var id := ""
static var data := {}
static var _systems := {}             # id -> Dictionary


## Park laden (leer/unbekannt = Standard aus parks/index.json). Gibt die id des geladenen Parks zurück.
static func select(want := "") -> String:
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	var parks: Array = idx.get("parks", []) if idx is Dictionary else []
	var file := ""
	for p: Dictionary in parks:
		if p["id"] == want:
			file = p["file"]
	if file == "":
		var def: String = idx.get("default", "") if idx is Dictionary else ""
		for p: Dictionary in parks:
			if p["id"] == def or file == "":
				file = p["file"]
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	data = d if d is Dictionary else {}
	id = str(data.get("id", ""))
	_systems.clear()
	for s: Dictionary in data.get("systems", []):
		if str(s.get("type", "2.0")) in PLAYABLE:
			_systems[s["id"]] = s
	return id


static func ensure_loaded() -> void:
	if id == "":
		select()


## Alle Parks aus parks/index.json (für die World Map): [{id, file}].
static func list() -> Array:
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	return idx.get("parks", []) if idx is Dictionary else []


static func park_name() -> String:
	ensure_loaded()
	return str(data.get("name", id))


## Daten eines beliebigen Parks aus parks/index.json lesen, ohne ihn zu wählen (World Map). {} = unbekannt.
static func info(park_id: String) -> Dictionary:
	for p: Dictionary in list():
		if p["id"] == park_id:
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p["file"]))
			return d if d is Dictionary else {}
	return {}


## Überschrift der Anlagen-Auswahl auf der Startseite (deutscher Ausgangstext, mit tr() übersetzen):
## Wakeport „TERMINAL“, sonst „ANLAGE“.
static func system_label() -> String:
	ensure_loaded()
	return str(data.get("system_label", "ANLAGE"))


## Art einer Anlage als Text (deutscher Ausgangstext, mit tr() übersetzen).
static func type_name(type: String) -> String:
	return TYPE_NAMES.get(type, type)


# ---------------------------------------------------------------- Anlagen

## ids der fahrbaren Anlagen in Anzeige-Reihenfolge (wie in park.json).
static func system_ids() -> Array:
	ensure_loaded()
	var out: Array = []
	for s: Dictionary in data.get("systems", []):
		if _systems.has(s["id"]):
			out.append(s["id"])
	return out


## ids der Anlagen, die Standard-Anlage zuerst (dort fährt man meist: Ranglisten, Setup-Editor).
static func system_ids_default_first() -> Array:
	var out := system_ids()
	var d := default_system()
	out.erase(d)
	out.push_front(d)
	return out


## Anzeigenamen (deutscher Ausgangstext, mit tr() übersetzen) in Anzeige-Reihenfolge.
static func system_names() -> Array:
	var out: Array = []
	for t: String in system_ids():
		out.append(system_name(t))
	return out


static func system(t: String) -> Dictionary:
	ensure_loaded()
	return _systems.get(t, {})


static func has_system(t: String) -> bool:
	ensure_loaded()
	return _systems.has(t)


static func system_name(t: String) -> String:
	return str(system(t).get("name", t))


## Kurzer Hinweis zur Anlage (Tooltip im Setup-Editor), deutscher Ausgangstext.
static func system_hint(t: String) -> String:
	return str(system(t).get("hint", system_name(t)))


static func default_system() -> String:
	ensure_loaded()
	var d := str(data.get("default_system", ""))
	if _systems.has(d):
		return d
	var ids := system_ids()
	return ids[0] if not ids.is_empty() else ""


## Anlage, die die Spielkoordinaten festlegt (Startmast = Ursprung).
static func origin_system() -> String:
	ensure_loaded()
	for s: Dictionary in data.get("systems", []):
		if s.get("origin", false) and _systems.has(s["id"]):
			return s["id"]
	return default_system()


## Bahnen der fahrbaren Anlagen als [Startmast, Endmast] (Namen in geo.json), in Anzeige-Reihenfolge
## (Bepflanzung, Gras, Strand an den Startmasten).
static func lanes() -> Array:
	var out: Array = []
	for t: String in system_ids():
		var ms: Array = system(t).get("masts", [])
		if ms.size() >= 2:
			out.append([ms[0], ms[ms.size() - 1]])
	return out


## Kann das Spiel diesen Anlagen-Typ schon fahren?
static func playable(type: String) -> bool:
	return type in PLAYABLE


# ---------------------------------------------------------------- Lage, Zeit, Daten

static func lat() -> float:
	ensure_loaded()
	return float(data.get("location", {}).get("lat", 0.0))


static func lon() -> float:
	ensure_loaded()
	return float(data.get("location", {}).get("lon", 0.0))


## Ortszeit -> UTC in Stunden für den Tag im Jahr. "dst": "eu" = Sommerzeit vom letzten Sonntag im März bis zum
## letzten Sonntag im Oktober (+1), "" = keine Sommerzeit (z. B. Türkei: immer UTC+3).
static func utc_offset(year: int, day_of_year: int) -> int:
	ensure_loaded()
	var tz: Dictionary = data.get("timezone", {})
	var base := int(tz.get("utc", 0))
	if str(tz.get("dst", "")) == "eu":
		var start := SunCalc.last_sunday(year, 3)
		var end := SunCalc.last_sunday(year, 10)
		if day_of_year >= start and day_of_year < end:
			return base + 1
	return base


## Ordner der Geodaten (geo.json, terrain.bin, canopy.bin, Luftbilder).
static func geo_dir() -> String:
	ensure_loaded()
	return str(data.get("geo", "res://assets/geo/"))


## Liste der Feature-Setups dieses Parks (Format wie setups/index.json).
static func setups_index() -> String:
	ensure_loaded()
	return str(data.get("setups", "res://setups/index.json"))


## Kulisse (Gebäude, Stege, Menschen am Ufer): bisher nur "wakeport" (scripts/beach.gd).
static func scenery() -> String:
	ensure_loaded()
	return str(data.get("scenery", ""))


## Ranglisten: Präfix vor der Anlagen-id. Der Wakeport hat keins (seine Ranglisten "comp/SEK/T2/…" bleiben), jeder
## andere Park "<park>." – sonst kämen gleich benannte Anlagen zweier Parks in dieselbe Rangliste.
static func board_prefix() -> String:
	ensure_loaded()
	return "" if id == "wakeport" else id + "."
