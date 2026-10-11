class_name Music
extends Node
## Hintergrundmusik aus eigenen Dateien des Spielers (MP3, OGG, WAV). Das Spiel liefert keine
## Musik mit (Lizenzen): der Spieler wählt seine Titel selbst, sie werden nach user://musik kopiert
## (Browser: IndexedDB des Browsers, bleibt erhalten) und laufen gemischt in Schleife.
## Kanal "Musik" (default_bus_layout.tres). Bei Jubel und Countdown wird die Musik kurz leiser.

signal changed            # Titelliste oder laufender Titel geändert

const DIR := "user://musik"
const EXTS := ["mp3", "ogg", "wav"]
## Vorschlag zum Nebenher-Hören (nur ein Link, nichts wird ins Spiel geladen)
const PLAYLIST_URL := "https://open.spotify.com/search/skate%20punk/playlists"
const DUCK_DB := -9.0             # so viel leiser, solange Jubel/Ansage läuft

var enabled := true
var no_save := false              # Tests: Dateien nicht kopieren, nur in diesem Lauf abspielen
var tracks: Array[String] = []    # Pfade (user://musik/… bzw. im Test direkt)
var current := ""                 # Titel, der gerade läuft ("" = nichts)

var _player: AudioStreamPlayer
var _queue: Array[String] = []
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
	if enabled:
		next()


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


static func title_of(path: String) -> String:
	return path.get_file().get_basename()


## Musik an/aus (Einstellung).
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_player.stop()
		current = ""
		changed.emit()
	elif not _player.playing:
		next()


## Nächster Titel (gemischt; jeder kommt einmal dran, dann neu gemischt).
func next() -> void:
	_player.stop()
	current = ""
	if enabled and not tracks.is_empty():
		for _i in tracks.size():
			if _queue.is_empty():
				_queue = tracks.duplicate()
				_queue.shuffle()
			var path: String = _queue.pop_back()
			var s := _load(path)
			if s != null:
				_player.stream = s
				_player.play()
				current = title_of(path)
				print("MUSIK: ", current)
				break
	changed.emit()


func _load(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
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
	if enabled and not _player.playing:
		next()
	else:
		changed.emit()


## Alle eigenen Titel wieder entfernen (nur die Kopien im Spiel).
func clear_all() -> void:
	_player.stop()
	if not no_save:
		for p in tracks:
			DirAccess.remove_absolute(p)
	tracks.clear()
	_queue.clear()
	current = ""
	changed.emit()


## Musik kurz leiser (Jubel, Countdown-Ansage): Sfx ruft das auf.
static func duck(sec: float) -> void:
	duck_until = maxf(duck_until, Time.get_ticks_msec() / 1000.0 + sec)


func _process(delta: float) -> void:
	var loud := Time.get_ticks_msec() / 1000.0 < duck_until
	_duck = move_toward(_duck, 1.0 if loud else 0.0, delta * (6.0 if loud else 1.2))
	_player.volume_db = DUCK_DB * _duck
