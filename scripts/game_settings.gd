class_name GameSettings
extends RefCounted
## Einstellungen von der Startseite (Spiel, Fahrer, Welt, Technik). Werden in
## user://settings.cfg (Abschnitt "optionen") gespeichert – außer Wetter/Uhrzeit, die beginnen
## jeden Start neu mit einem sonnigen Sommertag (siehe Weather / main.gd).
## main.gd hört auf `changed` und wendet den jeweiligen Wert an.

signal changed(key: String)

const FILE := "user://settings.cfg"
const SECTION := "optionen"

## Spielmodus: Rundenlänge in Sekunden, 0 = Freies Fahren (ohne Zeit und Strafzeit)
const MODES := [[450, "Runde 7:30"], [600, "Runde 10:00"], [900, "Runde 15:00"], [0, "Freies Fahren"]]
## Westenfarben (Impact-Weste) zur Auswahl
const VESTS := [Color(1.0, 0.45, 0.05), Color(0.85, 0.12, 0.12), Color(0.15, 0.45, 0.95),
	Color(0.2, 0.7, 0.3), Color(0.95, 0.85, 0.15), Color(0.6, 0.25, 0.75), Color(0.1, 0.1, 0.12),
	Color(0.92, 0.92, 0.9)]
## Seilzug-Grenze: ab so viel Zug wird einem die Handle aus der Hand gerissen
const GRIP_TENSION := [7200.0, 5400.0, 4300.0, INF]   # INF = Seil reißt nie ab
## Neigungs-Empfindlichkeit am Handy: Grad Neigung für vollen Lenkausschlag
const TILT_DEG := [35.0, 25.0, 16.0]
## Profi-Bonus auf alle Tricks je ausgeschalteter Hilfe
const ASSIST_BONUS := 0.15

const DEFAULTS := {
	"mode": 450,            # Sekunden, 0 = Freies Fahren
	"board": 0,             # BoardLibrary
	"goofy": false,         # Stance: false = Regular (links vorne), true = Goofy (rechts vorne)
	"helmet": 0,            # Helmet.DESIGNS
	"vest": 0,              # VESTS
	"assist_lock": true,    # Hilfe: auf dem Slider einloggen
	"assist_flip": true,    # Hilfe: Überschlag dreht losgelassen von selbst zu Ende
	"grip": 1,              # 0 locker, 1 normal, 2 streng, 3 aus (reißt nie ab)
	"rope": 16.0,           # m Seillänge der eigenen Anlage
	"speed": 30.0,          # km/h Anlagen-Tempo
	"planes": 1,            # 0 aus, 1 normal, 2 Rush Hour
	"npc": true,            # Fahrer auf der anderen Anlage
	"film": 0,              # Challenge-Filmteam: 0 Zufall, 1 Boot, 2 FPV-Drohne, 3 aus
	"vol_fx": 1.0,          # Lautstärke Effekte (0..1)
	"vol_cheer": 1.0,       # Lautstärke Jubel
	"vol_planes": 1.0,      # Lautstärke Flugzeuge
	"quality": 2,           # Grafik 0 niedrig, 1 mittel, 2 hoch
	"tilt": 1,              # Handy: Neigungs-Empfindlichkeit 0 niedrig, 1 mittel, 2 hoch
	"tilt_invert": false,   # Handy: Neigung umkehren
	"cam_mode": 0,          # ChaseCamera.CamMode
	"cam_dist": 7.5,        # m Kamera-Abstand
}

var values := DEFAULTS.duplicate()


## Gespeicherte Werte laden. mobile: Handy startet mit mittlerer Grafik.
func load_file(mobile: bool) -> void:
	if mobile:
		values["quality"] = 1
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	for k: String in DEFAULTS:
		if cfg.has_section_key(SECTION, k):
			values[k] = type_convert(cfg.get_value(SECTION, k), typeof(DEFAULTS[k]))
	# frühere Version: Seillänge/Tempo standen im Abschnitt "anlage"
	if not cfg.has_section_key(SECTION, "rope") and cfg.has_section_key("anlage", "rope"):
		values["rope"] = float(cfg.get_value("anlage", "rope"))
		values["speed"] = float(cfg.get_value("anlage", "speed", 30.0))


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	for k: String in values:
		cfg.set_value(SECTION, k, values[k])
	cfg.save(FILE)


func get_v(key: String) -> Variant:
	return values[key]


## Wert setzen, speichern und melden (nur bei Änderung).
func set_v(key: String, v: Variant) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	save_file()
	changed.emit(key)


## Alle Werte einmal melden (beim Start, damit main.gd alles anwendet).
func emit_all() -> void:
	for k: String in values:
		changed.emit(k)


## Faktor auf alle Trickpunkte: je ausgeschalteter Hilfe mehr.
func trick_bonus() -> float:
	return 1.0 + ASSIST_BONUS * (int(not values["assist_lock"]) + int(not values["assist_flip"]))
