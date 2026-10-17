class_name Leaderboard
extends Node
## Online-Rangliste (Cloudflare Worker + D1, Code in server/). Ranglisten gibt es für jede Challenge und für
## die Competition (je Rundenlänge, Terminal und Setup). Der Server kennt keine Aufgaben: jede Rangliste ist
## ein Name (board) plus eine **Wertungs-Version** (ver), die das Spiel selbst ausrechnet:
##   * Challenge: Hash der Aufgaben-Daten aus Training.MODES (ohne Texte und Medaillen-Schwellen) und der
##     Features im Setup (Lage + Bauteile aus parts.json)
##   * Competition: Hash der Features im Setup
##   * dazu RULES (von Hand erhöhen, wenn sich Physik oder Punkte so ändern, dass alte Werte nicht mehr
##     vergleichbar sind) bzw. "lb" in einer Aufgabe (nur diese eine neu)
## Ändert sich etwas davon, beginnt eine neue, leere Rangliste – die alte bleibt auf dem Server.
##
## Eingetragen wird nur mit Namen (= Einwilligung, Startseite → Rangliste). Echte Einträge nur aus der
## Web-Hauptversion; lokal und in PR-Vorschauen landen sie in eigenen Test-Ranglisten (ver "dev-…"),
## damit unfertige Änderungen nichts verfälschen. Tests (Kommandozeile) senden nichts, außer mit
## --lb-url=URL [--lb-name=NAME] (lokaler Worker, nichts gespeichert).
## Gespeichert in user://settings.cfg [rangliste]: id (geheime Geräte-Nummer), name.

const URL := "https://wakethehack-rangliste.kimpixel.workers.dev"   # Adresse des Workers (siehe server/README.md)
const HOST := "kimpixel.github.io"
const RULES := 1                 # erhöhen = alle Ranglisten beginnen neu
const SECTION := "rangliste"
const TIMEOUT := 8.0             # s
const NAME_MAX := 16
## Felder einer Aufgabe, die die Messung nicht ändern (nicht in der Wertungs-Version)
const COSMETIC := ["name", "title", "goal", "keys", "keys_mobile", "tip", "medals", "via_fail"]
## Competition zählt nur mit der Standard-Anlage (wie in den Challenges)
const COMP_SPEED := 30.0
const COMP_ROPE := 16.0

signal name_changed

var url := URL
var dev := true                  # Test-Ranglisten (lokal, PR-Vorschau)
var player_id := ""
var player_name := ""
var _test := false
var _build := ""
var _fp_cache := {}


func _init() -> void:
	name = "Leaderboard"
	process_mode = Node.PROCESS_MODE_ALWAYS    # Ergebnisfenster pausiert das Spiel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_test = not args.is_empty()
	if _test:
		url = ""
		for a in args:
			if a.begins_with("--lb-url="):
				url = a.substr(9).trim_suffix("/")
			elif a.begins_with("--lb-name="):
				player_name = a.substr(10)
		player_id = _new_id()
	else:
		_load()
		dev = not _main_web()
	var bl: GDScript = preload("res://scripts/ui/branch_label.gd")
	_build = bl.text() if bl.available() else "lokal"


func enabled() -> bool:
	return url != ""


func has_name() -> bool:
	return player_name != ""


## Web-Hauptversion (nicht lokal, nicht PR-Vorschau)?
static func _main_web() -> bool:
	if not OS.has_feature("web"):
		return false
	var loc: Variant = JavaScriptBridge.eval("window.location.hostname + window.location.pathname", true)
	var s := str(loc) if loc != null else ""
	return s.begins_with(HOST + "/") and not s.contains("/pr-preview/")


static func _new_id() -> String:
	var b := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 16:
		b.append(rng.randi() & 0xff)
	b.append_array(Crypto.new().generate_random_bytes(16))
	return b.hex_encode().sha256_text().substr(0, 32)


func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.FILE)
	player_id = str(cfg.get_value(SECTION, "id", ""))
	player_name = str(cfg.get_value(SECTION, "name", ""))
	if player_id.length() != 32:
		player_id = _new_id()
		_save()


func _save() -> void:
	if _test:
		return
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.FILE)
	cfg.set_value(SECTION, "id", player_id)
	cfg.set_value(SECTION, "name", player_name)
	cfg.save(GameSettings.FILE)


## Name, wie er gesendet wird (Test-Ranglisten: mit " dev", damit er den echten nicht belegt).
func _sent_name(n: String) -> String:
	return n if not dev else n.substr(0, NAME_MAX - 4) + " dev"


# ---------------------------------------------------------------- Ranglisten

## Rangliste einer Challenge: {board, ver, lower, task}.
func challenge_board(mode_id: String, task: Dictionary) -> Dictionary:
	var t := task.duplicate(true)
	for k: String in COSMETIC:
		t.erase(k)
	var ver := "%d-%s-%s" % [RULES, _hash(t), setup_fp(task.get("setup", ""), task.get("terminal", "T2"))]
	return {"board": "ch/%s/%s" % [mode_id, task["id"]], "ver": _ver(ver), "lower": task.get("lower", false),
		"task": task, "title": "%s · %s" % [Training.MODES[Training.mode_index(mode_id)]["name"], task["title"]]}


## Rangliste der Competition: {board, ver, lower, title}. setup: Eintrag aus FeatureSet.list_setups().
func competition_board(seconds: int, terminal: String, setup: Dictionary, terminal_name := "") -> Dictionary:
	var ver := "%d-c-%s" % [RULES, setup_fp(setup.get("file", ""), terminal)]
	var sname := str(setup.get("name", setup.get("id", "?"))).get_slice(" (", 0)
	return {"board": "comp/%d/%s/%s" % [seconds, terminal, setup.get("id", "?")], "ver": _ver(ver), "lower": false,
		"title": "Competition · %s · %s · Runde %d:%02d" % [terminal_name if terminal_name != "" else terminal, sname,
			seconds / 60, seconds % 60]}


## Warum eine Competition-Runde nicht in die Rangliste kommt ("" = sie zählt).
static func competition_blocked(settings: GameSettings, seconds: int, setup: Dictionary) -> String:
	if seconds <= 0:
		return "Freies Fahren hat keine Rangliste"
	if setup.get("user", false):
		return "Eigene Setups haben keine Rangliste"
	if not is_equal_approx(float(settings.get_v("speed")), COMP_SPEED) \
			or not is_equal_approx(float(settings.get_v("rope")), COMP_ROPE):
		return "Rangliste nur mit %d km/h und %d m Seil" % [int(COMP_SPEED), int(COMP_ROPE)]
	if int(settings.get_v("grip")) == 3:
		return "Rangliste nicht mit Seilzug-Grenze „Aus“"
	return ""


func _ver(v: String) -> String:
	return ("dev-" + v) if dev else v


static func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text().substr(0, 8)


## Fingerabdruck der Features eines Setups auf einer Anlage: Lage aus der Setup-Datei und die benutzten
## Bauteile aus parts.json (auch Teile in Gruppen). Andere Bauteile ändern ihn nicht.
func setup_fp(file: String, terminal: String) -> String:
	var key := file + "|" + terminal
	if _fp_cache.has(key):
		return _fp_cache[key]
	var setup: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if file != "" else null
	var feats: Variant = setup.get(terminal, []) if setup is Dictionary else []
	var parts: Variant = JSON.parse_string(FileAccess.get_file_as_string(FeatureSet.PARTS_FILE))
	var used := {}
	if parts is Dictionary:
		_collect_parts(feats, parts, used)
	var fp := _hash({"f": feats, "p": used})
	_fp_cache[key] = fp
	return fp


static func _collect_parts(v: Variant, parts: Dictionary, used: Dictionary) -> void:
	if v is String:
		if parts.has(v) and not used.has(v):
			used[v] = parts[v]
			_collect_parts(parts[v], parts, used)
	elif v is Array:
		for e: Variant in v:
			_collect_parts(e, parts, used)
	elif v is Dictionary:
		for k: Variant in v:
			_collect_parts(v[k], parts, used)


## Wert lesbar (wie im Ergebnisfenster).
static func format(b: Dictionary, value: float) -> String:
	if b.has("task"):
		return Training.format_value(b["task"], value)
	return "%d Punkte" % roundi(value)


static func format_date(ms: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0))
	return "%02d.%02d.%02d" % [d["day"], d["month"], d["year"] % 100]


# ---------------------------------------------------------------- Server

## Ergebnis eintragen (Server behält den Bestwert). {ok, improved, value, rank, total} oder {error}.
## Ohne Namen bzw. Server: {error, skip: true}.
func submit(b: Dictionary, value: float) -> Dictionary:
	if not enabled() or (_test and not has_name()):
		return {"error": "", "skip": true}
	if not has_name():
		return {"error": "Name fehlt", "skip": true}
	var r := await _post("/score", {"id": player_id, "name": _sent_name(player_name), "board": b["board"],
		"ver": b["ver"], "value": value, "lower": b["lower"], "build": _build})
	if _test:
		print("RANGLISTE %s %s: %s" % [b["board"], b["ver"], r])
	return r


## Beste n Einträge: {ok, entries: [{rank, name, value, date, me}], total, me, older} oder {error}.
func top(b: Dictionary, n := 10) -> Dictionary:
	if not enabled():
		return {"error": "Rangliste noch nicht eingerichtet"}
	return await _post("/top", {"id": player_id, "board": b["board"], "ver": b["ver"], "lower": b["lower"], "n": n})


## Ranglisten mit Einträgen: {"board|ver": Anzahl} (echte bzw. Test-Ranglisten je nach dev); null bei Fehler
## oder älterem Server ohne /boards (dann alle zeigen).
func boards_with_entries() -> Variant:
	if not enabled():
		return null
	var r := await _post("/boards", {"dev": dev})
	if not r.get("ok", false):
		return null
	var out := {}
	for e: Variant in r.get("boards", []):
		if e is Dictionary:
			out["%s|%s" % [e.get("board", ""), e.get("ver", "")]] = int(e.get("n", 0))
	return out


## Namen festlegen (prüft der Server: erlaubte Zeichen, nicht vergeben). {ok} oder {error}.
func set_player_name(n: String) -> Dictionary:
	n = n.strip_edges()
	if not enabled():
		return {"error": "Rangliste noch nicht eingerichtet"}
	var r := await _post("/name", {"id": player_id, "name": _sent_name(n)})
	if r.get("ok", false):
		player_name = n
		_save()
		name_changed.emit()
	return r


## Nicht mehr teilnehmen: alle Einträge löschen, Name weg, neue Geräte-Nummer.
func forget() -> Dictionary:
	var r := {"ok": true}
	if enabled():
		r = await _post("/forget", {"id": player_id})
	if r.get("ok", false):
		player_name = ""
		player_id = _new_id()
		_save()
		name_changed.emit()
	return r


func _post(path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var err := http.request(url + path, PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"error": "Keine Verbindung"}
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Keine Verbindung"}
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		return {"error": "Serverfehler (%d)" % int(res[1])}
	return data
