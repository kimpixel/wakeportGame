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
## Grafikstufen Niedrig, Mittel, Hoch; "Custom" = Wasser-Effekte weichen von der Stufe ab (nur Anzeige,
## gespeichert bleibt die Stufe für Auflösung, Schatten, Bäume, Gischt)
const QUALITY_NAMES := ["Niedrig", "Mittel", "Hoch", "Custom"]
const QUALITY_CUSTOM := 3
## Wasser-Effekte je Grafikstufe (Wasserfarbe gehört nicht dazu)
const WATER_PRESETS := [
	{"w_detail": false, "w_fresnel": true, "w_glitter": false, "w_crest": false, "w_foam": false,
		"w_sharp": false, "w_clear": false, "w_ssr": false},
	{"w_detail": true, "w_fresnel": true, "w_glitter": false, "w_crest": true, "w_foam": false,
		"w_sharp": true, "w_clear": false, "w_ssr": false},
	{"w_detail": true, "w_fresnel": true, "w_glitter": true, "w_crest": true, "w_foam": true,
		"w_sharp": true, "w_clear": true, "w_ssr": false},
]
## Erhöhen, wenn die Wasser-Effekte einmalig neu aus der Grafikstufe gesetzt werden sollen
const PRESET_VER := 1

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
	"music": true,          # Hintergrundmusik an/aus (siehe Music)
	"music_src": 2,         # Music.Source: 0 Spiel-Musik, 1 eigene Titel, 2 beides
	"vol_music": 0.6,       # Lautstärke Musik
	"quality": 2,           # Grafik 0 niedrig, 1 mittel, 2 hoch
	"steer": 1,             # Handy: Lenkung 0 Neigung (Gyro), 1 Tasten (Steuerkreuz rechts)
	"tilt": 1,              # Handy: Neigungs-Empfindlichkeit 0 niedrig, 1 mittel, 2 hoch
	"tilt_invert": false,   # Handy: Neigung umkehren
	"cam_mode": 0,          # ChaseCamera.CamMode
	"cam_dist": 5.0,        # m Kamera-Abstand
	# Wasser-Effekte (Reiter "Wasser", zum Ausprobieren je an/aus; siehe Water.FX_KEYS)
	"w_color": 1,           # Wasserfarbe: 0 Türkis (bisher), 1 Seeblau
	"w_detail": true,       # Oberflächenstruktur
	"w_fresnel": true,      # Spiegelung je nach Blickwinkel
	"w_glitter": true,      # Sonnenglitzern
	"w_crest": true,        # Licht durch die Wellenkämme
	"w_foam": true,         # Schaum mit Struktur
	"w_sharp": true,        # spitze Wellen (auch Physik)
	"w_clear": true,        # Durchsicht im Flachen (Szenentiefe)
	"w_ssr": false,         # echte Spiegelbilder (nur Desktop, teuer)
	"preset_ver": 0,        # Stand der Wasser-Voreinstellungen (PRESET_VER)
}

## Standardwert ändern: Wert in DEFAULTS ändern und hier eine neue Version mit dem ALTEN Wert anhängen.
## Gespeichert werden nur Abweichungen vom Standard. Ältere Dateien enthalten aber noch alle Werte:
## steht dort für den Schlüssel noch der alte Standard, gilt danach der neue (bewusst anders
## eingestellte Werte bleiben). Version der Datei in [optionen] "ver".
const DEFAULT_CHANGES := {
	1: {"steer": 0, "cam_dist": 7.5},
}

var values := DEFAULTS.duplicate()
var _mobile := false


## Standardwert eines Schlüssels (Handy: Grafik Mittel).
func default_of(key: String) -> Variant:
	if key == "quality" and _mobile:
		return 1
	return DEFAULTS[key]


## Aktuelle Version der Standardwerte (höchste in DEFAULT_CHANGES).
static func defaults_ver() -> int:
	var v := 0
	for n: int in DEFAULT_CHANGES:
		v = maxi(v, n)
	return v


## Gespeicherte Werte laden. mobile: Handy startet mit mittlerer Grafik.
func load_file(mobile: bool) -> void:
	_mobile = mobile
	values["quality"] = default_of("quality")
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK and cfg.has_section(SECTION):
		var ver := int(cfg.get_value(SECTION, "ver", 0))
		for k: String in DEFAULTS:
			if cfg.has_section_key(SECTION, k):
				var v: Variant = type_convert(cfg.get_value(SECTION, k), typeof(DEFAULTS[k]))
				if not _old_default(k, v, ver):
					values[k] = v
		# frühere Version: Seillänge/Tempo standen im Abschnitt "anlage"
		if not cfg.has_section_key(SECTION, "rope") and cfg.has_section_key("anlage", "rope"):
			values["rope"] = float(cfg.get_value("anlage", "rope"))
			values["speed"] = float(cfg.get_value("anlage", "speed", 30.0))
	# Wasser-Effekte passend zur Grafikstufe (neu, und einmalig nach dem Update, das sie gekoppelt hat)
	if int(values["preset_ver"]) < PRESET_VER:
		values.merge(WATER_PRESETS[clampi(int(values["quality"]), 0, 2)], true)
		values["preset_ver"] = PRESET_VER
	# ältere Datei: einmal neu schreiben (nur Abweichungen, aktuelle Version)
	if cfg.has_section(SECTION) and int(cfg.get_value(SECTION, "ver", 0)) < defaults_ver():
		save_file()


## true, wenn v der Standard von key war, als die Datei (Version ver) geschrieben wurde,
## und der Standard sich seitdem geändert hat.
## Maßgeblich ist die erste Änderung nach ver: ihr alter Wert war der Standard bei ver.
func _old_default(key: String, v: Variant, ver: int) -> bool:
	var first := -1
	for n: int in DEFAULT_CHANGES:
		if n > ver and DEFAULT_CHANGES[n].has(key) and (first < 0 or n < first):
			first = n
	return first >= 0 and type_convert(DEFAULT_CHANGES[first][key], typeof(DEFAULTS[key])) == v


## Speichert nur Werte, die vom Standard abweichen (sonst greift ein später geänderter Standard nicht).
func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	if cfg.has_section("anlage"):      # frühere Version, sonst käme die alte Seillänge zurück
		cfg.erase_section("anlage")
	for k: String in values:
		if values[k] == default_of(k):
			if cfg.has_section_key(SECTION, k):
				cfg.erase_section_key(SECTION, k)
		else:
			cfg.set_value(SECTION, k, values[k])
	cfg.set_value(SECTION, "ver", defaults_ver())
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


## Grafikstufe wählen: setzt auch alle Wasser-Effekte auf die Voreinstellung der Stufe.
func set_quality(q: int) -> void:
	q = clampi(q, 0, 2)
	var news: Dictionary = WATER_PRESETS[q].duplicate()
	news["quality"] = q
	var diff: Array[String] = []
	for k: String in news:
		if values.get(k) != news[k]:
			values[k] = news[k]
			diff.append(k)
	if diff.is_empty():
		return
	save_file()
	for k in diff:
		changed.emit(k)


## Angezeigte Grafikstufe: die gespeicherte, oder QUALITY_CUSTOM, wenn ein Wasser-Effekt abweicht.
func quality_shown() -> int:
	var q := clampi(int(values["quality"]), 0, 2)
	var p: Dictionary = WATER_PRESETS[q]
	for k: String in p:
		if bool(values[k]) != bool(p[k]):
			return QUALITY_CUSTOM
	return q


## Alle Werte einmal melden (beim Start, damit main.gd alles anwendet).
func emit_all() -> void:
	for k: String in values:
		changed.emit(k)


## Faktor auf alle Trickpunkte: je ausgeschalteter Hilfe mehr.
func trick_bonus() -> float:
	return 1.0 + ASSIST_BONUS * (int(not values["assist_lock"]) + int(not values["assist_flip"]))
