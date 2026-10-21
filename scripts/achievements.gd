class_name Achievements
## Geheime Erfolge: Die Liste auf der Startseite hat SLOTS Einträge, alle ausgegraut und ohne
## Text, bis man einen erreicht hat. Erst dann stehen Name und Beschreibung da.
## Gespeichert in user://settings.cfg [erfolge] (Wert = Datum); Tests speichern nichts (no_save).
## Neue Erfolge hinten an LIST anhängen (die Reihenfolge ist die Reihenfolge in der Liste).

const SECTION := "erfolge"
const SLOTS := 12                 # so viele Plätze zeigt die Liste (auch noch nicht ausgedachte)

const LIST := [
	{"id": "fisch", "name": "Fischkontakt", "text": "Mit einem springenden Hecht zusammengestoßen."},
	{"id": "sup", "name": "Nass gespritzt", "text": "Einen SUP-Paddler mit voller Fahrt nass gespritzt."},
	{"id": "steg", "name": "Steg-Landung", "text": "Aus der Luft auf dem Startsteg gelandet."},
	{"id": "insekt", "name": "Insekten fressen", "text": "Am Waldrand von Terminal 1 durch einen Mückenschwarm gefahren. Mahlzeit!"},
	{"id": "boot", "name": "Boot crash", "text": "Ins rote Boot gefahren oder hineingefallen."},
	{"id": "nikolaus", "name": "Ho ho ho!", "text": "Am Nikolaustag im Schnee eine Wende gefahren."},
	{"id": "frechdachs", "name": "Was ein Frechdachs", "text": "Ein Haubentaucher ist direkt unter dir durchgetaucht."},
	{"id": "schwanenliebe", "name": "Schwanenliebe", "text": "Zwei Schwäne haben mit ihren Hälsen ein Herz geformt – und du warst dabei."},
	{"id": "zugvogel", "name": "Zugvogel", "text": "Einen Raley gesprungen, während die Kraniche über den See ziehen."},
	{"id": "blitz", "name": "Blitzableiter", "text": "Im Gewitter gefahren und vom Blitz getroffen. YOLO!"},
	{"id": "badegast", "name": "Badegast", "text": "An einem heißen Tag einen Badegast auf der Luftmatratze nass gespritzt."},
	{"id": "arschbombe", "name": "Arschbombe", "text": "Aus der Luft ins Becken des 6-Stair Pools gestürzt. Platsch!"},
]

static var no_save := false       # Tests: nur für diese Sitzung merken
static var _session := {}         # id -> Datum (ohne Speichern)


static func get_def(id: String) -> Dictionary:
	for a: Dictionary in LIST:
		if a["id"] == id:
			return a
	return {}


## Datum der Freischaltung ("" = noch geheim).
static func unlocked_at(id: String) -> String:
	if _session.has(id):
		return _session[id]
	if no_save:
		return ""
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.FILE) != OK:
		return ""
	return str(cfg.get_value(SECTION, id, ""))


static func count_unlocked() -> int:
	var n := 0
	for a: Dictionary in LIST:
		if unlocked_at(a["id"]) != "":
			n += 1
	return n


## Erfolg freischalten. Liefert true, wenn er neu ist (dann Meldung im HUD).
static func unlock(id: String) -> bool:
	if get_def(id).is_empty() or unlocked_at(id) != "":
		return false
	var d := Time.get_date_dict_from_system()
	var date := "%02d.%02d.%d" % [d["day"], d["month"], d["year"]]
	_session[id] = date
	if not no_save:
		var cfg := ConfigFile.new()
		cfg.load(GameSettings.FILE)
		cfg.set_value(SECTION, id, date)
		cfg.save(GameSettings.FILE)
	return true
