class_name Music
extends Node
## Hintergrundmusik: **Spiel-Musik** (lizenzfreie Titel von Pixabay in assets/music/, Quellen in
## assets/music/QUELLEN.md) und/oder **eigene Titel** des Spielers (MP3, OGG, WAV).
## Spiel-Musik: assets/music/ hat ein .gdignore – nicht importiert, nicht im Spielpaket (index.pck).
## Lokal liest das Spiel die Dateien direkt aus dem Ordner, im Browser lädt es sie einzeln vom Server
## nach (der Web-Build kopiert sie nach music/ und schreibt music/index.json), immer nur den laufenden
## und den nächsten Titel. Eigene Titel werden nach user://musik kopiert (Browser: IndexedDB, bleibt
## erhalten). Alles läuft gemischt in Schleife. Kanal "Musik" (default_bus_layout.tres); bei Jubel und
## Countdown wird die Musik kurz leiser (duck).

signal changed            # Titelliste oder laufender Titel geändert

const DIR := "user://musik"
const GAME_DIR := "res://assets/music"
const WEB_DIR := "music/"         # im Browser relativ zur Seite (auch in der PR-Vorschau)
const EXTS := ["mp3", "ogg", "wav"]
## Quelle: Spiel-Musik, eigene Titel oder beides (Einstellung "music_src")
enum Source { GAME, OWN, BOTH }
## Vorschlag zum Nebenher-Hören (nur ein Link, nichts wird ins Spiel geladen)
const PLAYLIST_URL := "https://open.spotify.com/search/skate%20punk/playlists"
const DUCK_DB := -9.0             # so viel leiser, solange Jubel/Ansage läuft

var enabled := true
var source := Source.BOTH
var no_save := false              # Tests: eigene Titel nicht kopieren/laden, nur in diesem Lauf
var tracks: Array[String] = []    # eigene Titel (user://musik/… bzw. im Test direkt)
var game_tracks: Array[String] = []   # Spiel-Musik (res://… lokal, music/… im Browser)
var current := ""                 # Titel, der gerade läuft ("" = nichts)
var loading := ""                 # Titel, der gerade geladen wird (Browser)

var _player: AudioStreamPlayer
var _queue: Array[String] = []
var _cache := {}                  # Browser: Eintrag -> AudioStream (laufender + nächster)
var _fetching := {}               # Browser: Eintrag -> true, solange er lädt
var _pending := ""                # Browser: soll spielen, sobald geladen
var _web_base := ""               # Browser: absolute Adresse von music/
var _js_cb: JavaScriptObject      # Rückruf aus dem Browser (Referenz halten, sonst weg)
var _duck := 0.0
static var duck_until := 0.0      # bis dahin geduckt (Sekunden seit Start)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # läuft auch in der Pause und auf der Startseite


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = Sfx.BUS_MUSIC
	add_child(_player)
	_player.finished.connect(next)
	_scan()
	_scan_game()


func _scan() -> void:
	if no_save:
		return
	tracks.clear()
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension().to_lower() in EXTS:
			tracks.append(DIR.path_join(f))
	tracks.sort()


## Spiel-Musik finden: lokal im Ordner, im Browser über music/index.json vom Server.
func _scan_game() -> void:
	game_tracks.clear()
	if OS.has_feature("web"):
		_web_base = str(JavaScriptBridge.eval("new URL('%s', document.baseURI).href" % WEB_DIR, true))
		_fetch(_web_base + "index.json", func(bytes: PackedByteArray) -> void:
			var list: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if list is Array:
				for f: Variant in list:
					if str(f).get_extension().to_lower() in EXTS:
						game_tracks.append(WEB_DIR + str(f))
			_restart())
		return
	var d := DirAccess.open(GAME_DIR)
	if d != null:
		for f in d.get_files():
			if f.get_extension().to_lower() in EXTS:
				game_tracks.append(GAME_DIR.path_join(f))
		game_tracks.sort()
	_restart()


## Titel der aktuellen Quelle(n).
func playlist() -> Array[String]:
	var list: Array[String] = []
	if source != Source.OWN:
		list.append_array(game_tracks)
	if source != Source.GAME:
		list.append_array(tracks)
	return list


static func title_of(path: String) -> String:
	return path.get_file().get_basename()


## Musik an/aus (Einstellung).
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_player.stop()
		current = ""
		loading = ""
		_pending = ""
		changed.emit()
	elif not _player.playing and _pending == "":
		next()


## Quelle wählen (Einstellung): neu mischen und neu anfangen.
func set_source(s: int) -> void:
	if s == source:
		return
	source = s as Source
	_restart()


func _restart() -> void:
	_queue.clear()
	if enabled and is_inside_tree():
		next()
	else:
		changed.emit()


## Nächster Titel (gemischt; jeder kommt einmal dran, dann neu gemischt).
func next() -> void:
	_player.stop()
	current = ""
	loading = ""
	_pending = ""
	var list := playlist()
	if enabled and not list.is_empty():
		for _i in list.size():
			var e := _pop(list)
			if e.begins_with(WEB_DIR):
				if _cache.has(e):
					_play(e, _cache[e])
				else:
					_pending = e                  # spielt, sobald geladen
					loading = title_of(e)
					_prefetch(e)
				break
			var s := _decode(e, FileAccess.get_file_as_bytes(e))
			if s != null:
				_play(e, s)
				break
	changed.emit()


func _pop(list: Array[String]) -> String:
	if _queue.is_empty():
		_queue = list.duplicate()
		_queue.shuffle()
	return _queue.pop_back()


func _play(e: String, s: AudioStream) -> void:
	_player.stream = s
	_player.play()
	current = title_of(e)
	loading = ""
	_pending = ""
	print("MUSIK: ", current)
	# Browser: nur laufenden und nächsten Titel im Speicher halten, den nächsten schon laden
	if e.begins_with(WEB_DIR):
		var keep := {e: true}
		var nxt: String = "" if _queue.is_empty() else _queue.back()
		if nxt.begins_with(WEB_DIR):
			keep[nxt] = true
			_prefetch(nxt)
		for k: String in _cache.keys():
			if not keep.has(k):
				_cache.erase(k)
	changed.emit()


## Browser: Titel vom Server laden (einmal; spielt sofort, wenn er gerade dran ist).
func _prefetch(e: String) -> void:
	if _cache.has(e) or _fetching.has(e):
		return
	_fetching[e] = true
	_fetch(_web_base + e.substr(WEB_DIR.length()).uri_encode(), func(bytes: PackedByteArray) -> void:
		_fetching.erase(e)
		var s := _decode(e, bytes)
		if s == null:
			if _pending == e:                    # kaputt/fehlt: weiter zum nächsten
				game_tracks.erase(e)
				next()
			return
		_cache[e] = s
		if _pending == e and enabled:
			_play(e, s))


func _fetch(url: String, done: Callable) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			push_warning("Musik: %s nicht geladen (%d/%d)" % [url, result, code])
			body = PackedByteArray()
		done.call(body))
	if req.request(url) != OK:
		req.queue_free()
		done.call(PackedByteArray())


func _decode(path: String, bytes: PackedByteArray) -> AudioStream:
	if bytes.is_empty():
		return null
	var s: AudioStream
	match path.get_extension().to_lower():
		"mp3":
			s = AudioStreamMP3.load_from_buffer(bytes)
		"ogg":
			s = AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			s = AudioStreamWAV.load_from_buffer(bytes)
	if s == null:
		push_warning("Musik: kann %s nicht lesen" % path)
	return s


## Dateien wählen: Desktop nativer Dateidialog, Browser/Handy das Datei-Fenster des Browsers.
func pick_files() -> void:
	if OS.has_feature("web"):
		_pick_web()
		return
	var filters := PackedStringArray(["*.mp3, *.ogg, *.wav ; Musik"])
	var home := OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Musik hinzufügen", home, "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILES, filters,
			func(ok: bool, paths: PackedStringArray, _f: int) -> void:
				if ok:
					add_paths(paths))
		return
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	fd.filters = filters
	fd.current_dir = home
	fd.files_selected.connect(add_paths)
	fd.visibility_changed.connect(func() -> void:
		if not fd.visible:
			fd.queue_free())
	add_child(fd)
	fd.popup_centered_ratio(0.7)


func _pick_web() -> void:
	if _js_cb == null:
		_js_cb = JavaScriptBridge.create_callback(_on_web_file)
		JavaScriptBridge.get_interface("window").wakeMusicAdd = _js_cb
	JavaScriptBridge.eval("""(function () {
	var i = document.createElement('input');
	i.type = 'file';
	i.multiple = true;
	i.accept = '.mp3,.ogg,.wav,audio/mpeg,audio/ogg,audio/wav';
	i.style.display = 'none';
	document.body.appendChild(i);
	i.addEventListener('change', function () {
		Array.prototype.forEach.call(i.files, function (f) {
			f.arrayBuffer().then(function (b) { window.wakeMusicAdd(f.name, b); });
		});
		i.remove();
	});
	i.click();
})();""", true)


func _on_web_file(args: Array) -> void:
	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(args[1])
	add_bytes(str(args[0]), bytes)


func add_paths(paths: PackedStringArray) -> void:
	for p in paths:
		if no_save:
			if FileAccess.file_exists(p) and not p in tracks:
				tracks.append(p)
		else:
			add_bytes(p.get_file(), FileAccess.get_file_as_bytes(p), false)
	_added()


## Eine Datei übernehmen (nach user://musik kopieren).
func add_bytes(file_name: String, bytes: PackedByteArray, single := true) -> void:
	var ext := file_name.get_extension().to_lower()
	if bytes.is_empty() or not ext in EXTS:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var clean := file_name.get_file().validate_filename()
	var f := FileAccess.open(DIR.path_join(clean), FileAccess.WRITE)
	if f == null:
		push_warning("Musik: kann %s nicht speichern" % clean)
		return
	f.store_buffer(bytes)
	f.close()
	if single:
		_added()


func _added() -> void:
	_scan()
	_queue.clear()
	if enabled and not _player.playing and _pending == "":
		next()
	else:
		changed.emit()


## Alle eigenen Titel wieder entfernen (nur die Kopien im Spiel; Spiel-Musik bleibt).
func clear_all() -> void:
	var was_own := current != "" and tracks.any(func(t: String) -> bool: return title_of(t) == current)
	if not no_save:
		for p in tracks:
			DirAccess.remove_absolute(p)
	tracks.clear()
	_queue.clear()
	if was_own:
		next()
	else:
		changed.emit()


## Musik kurz leiser (Jubel, Countdown-Ansage): Sfx ruft das auf.
static func duck(sec: float) -> void:
	duck_until = maxf(duck_until, Time.get_ticks_msec() / 1000.0 + sec)


func _process(delta: float) -> void:
	var loud := Time.get_ticks_msec() / 1000.0 < duck_until
	_duck = move_toward(_duck, 1.0 if loud else 0.0, delta * (6.0 if loud else 1.2))
	_player.volume_db = DUCK_DB * _duck
