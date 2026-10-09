class_name Training
extends RefCounted
## Spielmodi: "Competition" (Runde auf Zeit, wie bisher) und Trainings-Modi mit Aufgaben, die von
## Aufgabe zu Aufgabe schwieriger werden. Jede Aufgabe misst einen Wert und vergibt Bronze, Silber
## oder Gold. Die Aufgabe setzt den Fahrer in voller Fahrt kurz vor die Stelle (Wende, Kicker,
## Slider); jeder Versuch beginnt wieder dort (Challenge). Bestwerte: user://settings.cfg [medaillen].
##
## Felder einer Aufgabe:
##   id, name (kurz, Liste), title, goal, keys / keys_mobile (Steuerung), tip
##   kind     turn | kick | slide | chain | raley
##   setup    Setup-Datei (Terminal 2)
##   start    {s, x, dir}: s = Abstand vom Startmast wie in den Setup-Dateien (ohne Verschiebung),
##            dir +1 = Richtung Endmast, -1 = Richtung Startsteg. Wende: {turn: "a"|"b", before, x}
##   metric   Messwert: sink, height, dist, dist_5050, dist_bs, switches, press, count, spin, points
##   medals   Schwellen [Bronze, Silber, Gold]; lower = true: kleiner ist besser
##   target   kick/slide: {s0, s1, side} – Features mit Mitte in diesem Bereich (Setup-Koordinaten),
##            side +1/-1 = rechte/linke Seite
##   end_s    Versuch endet spätestens hier (Setup-Koordinaten, in Fahrtrichtung)

const COMPETITION := "competition"
const MEDALS := ["", "Bronze", "Silber", "Gold"]
const MEDAL_COLORS := [Color(1, 1, 1, 0.25), Color(0.80, 0.50, 0.25), Color(0.80, 0.82, 0.86), Color(1.0, 0.80, 0.20)]

const SPEED := 30.0             # km/h Anlagen-Tempo in allen Aufgaben (vergleichbar)
const ROPE := 16.0              # m Seillänge in allen Aufgaben

const LEER := "res://setups/training_leer.json"
const KICKER := "res://setups/training_kicker.json"
const SLIDER := "res://setups/training_slider.json"

const MODES := [
	{"id": COMPETITION, "name": "Competition",
	 "text": "Runde auf Zeit: so viele Punkte wie möglich. Terminal, Feature-Setup und Rundenlänge frei wählbar."},
	{"id": "wende", "name": "Wenden", "text": "Wenden fahren, ohne einzusinken.", "tasks": [
		{"id": "endmast", "name": "Wende Endmast", "title": "Wende am Endmast",
		 "kind": "turn", "setup": LEER, "start": {"turn": "b", "before": 60.0, "x": 2.0},
		 "metric": "sink", "lower": true, "medals": [0.95, 0.4, 0.1],
		 "goal": "Fahr durch die Wende am Endmast, ohne einzusinken. Gemessen wird, wie tief du einsinkst.",
		 "keys": "← / →  lenken     Strg  driften",
		 "keys_mobile": "Neigen  lenken     DRIFT  driften",
		 "tip": "An der roten Boje nach außen rauskanten und Tempo aufbauen, dann um den Carrier pendeln – das Seil muss gespannt bleiben. Wird es locker, weiter nach außen ziehen."},
		{"id": "ufer", "name": "Ufer-Wende", "title": "Wende am Ufer",
		 "kind": "turn", "setup": LEER, "start": {"turn": "a", "before": 60.0, "x": -2.0},
		 "metric": "sink", "lower": true, "medals": [0.95, 0.4, 0.1],
		 "goal": "Die Wende vor dem Startsteg: hier ist weniger Platz. Wieder ohne einzusinken.",
		 "keys": "← / →  lenken     Strg  driften",
		 "keys_mobile": "Neigen  lenken     DRIFT  driften",
		 "tip": "Früh rauskanten – zum Ufer hin bleibt wenig Raum zum Ausschwingen."},
		{"id": "boje", "name": "Um die Boje", "title": "Wende um die weiße Boje",
		 "kind": "turn", "setup": LEER, "start": {"turn": "b", "before": 60.0, "x": 2.0}, "buoy": true,
		 "metric": "sink", "lower": true, "medals": [0.95, 0.3, 0.05],
		 "goal": "Fahr außen um eine der weißen Bojen und komm sauber aus der Wende. Ohne Boje gibt es keine Medaille.",
		 "keys": "← / →  lenken     Strg  driften",
		 "keys_mobile": "Neigen  lenken     DRIFT  driften",
		 "tip": "Schon vor der roten Boje weit nach außen ziehen, sonst reicht der Schwung nicht um die weiße Boje."},
	]},
	{"id": "kicker", "name": "Kicker", "text": "Über den Kicker – so hoch wie möglich.", "tasks": [
		{"id": "m_roll", "name": "Kicker M", "title": "Kicker M überfahren", "no_pop": true,
		 "kind": "kick", "setup": KICKER, "start": {"s": 104.0, "x": 4.6, "dir": -1},
		 "target": {"s0": 60.0, "s1": 69.0, "side": 1, "x": 4.6}, "end_s": 45.0,
		 "metric": "height", "medals": [1.3, 1.5, 1.7],
		 "goal": "Fahr ohne Absprung gerade über den Kicker M (der kleinere, näher am Seil). Gemessen wird die größte Höhe über dem Wasser.",
		 "keys": "← / →  lenken     Leertaste halten + loslassen  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG halten + loslassen  Absprung",
		 "tip": "Gerade und mit Tempo anfahren – schräg verliert man Höhe. Kurz vor dem Kicker nicht mehr lenken."},
		{"id": "m_pop", "name": "M mit Absprung", "title": "Kicker M mit Absprung",
		 "kind": "kick", "setup": KICKER, "start": {"s": 104.0, "x": 4.6, "dir": -1},
		 "target": {"s0": 60.0, "s1": 69.0, "side": 1, "x": 4.6}, "end_s": 45.0,
		 "metric": "height", "medals": [2.2, 2.6, 3.0],
		 "goal": "Wie eben, aber an der Kante abspringen: Kicker-Steigung + Sprungkraft = Höhe.",
		 "keys": "Leertaste halten (auf dem Kicker) + an der Kante loslassen",
		 "keys_mobile": "SPRUNG halten (auf dem Kicker) + an der Kante loslassen",
		 "tip": "Schon auf dem Kicker voll aufladen und genau an der Kante loslassen – zu früh verschenkt den Wurf der Rampe."},
		{"id": "l_pop", "name": "Kicker L", "title": "Kicker L mit Absprung",
		 "kind": "kick", "setup": KICKER, "start": {"s": 106.0, "x": 7.8, "dir": -1},
		 "target": {"s0": 62.0, "s1": 71.0, "side": 1, "x": 7.8}, "end_s": 45.0,
		 "metric": "height", "medals": [2.8, 3.3, 3.8],
		 "goal": "Der große Kicker L (rechts): höher, steiler – und härter bei der Landung.",
		 "keys": "Leertaste halten + an der Kante loslassen",
		 "keys_mobile": "SPRUNG halten + an der Kante loslassen",
		 "tip": "Bei der Landung gerade bleiben – wer quer aufkommt, stürzt."},
	]},
	{"id": "slider", "name": "Slider", "text": "Slider fahren: aufspringen, 50-50, Boardslide, Press.", "tasks": [
		{"id": "pipe", "name": "Full Pipe", "title": "Rauf auf die Full Pipe",
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 65.0, "side": 1}, "end_s": 75.0,
		 "metric": "dist", "medals": [4.0, 8.0, 12.0],
		 "goal": "Fahr über die Auffahrt auf die Full Pipe und rutsch sie so weit wie möglich ab. Gemessen: gerutschte Meter.",
		 "keys": "← / →  lenken (auf dem Slider: Boardslide / 50-50)",
		 "keys_mobile": "Neigen  lenken (auf dem Slider deutlich neigen: Boardslide / 50-50)",
		 "tip": "Mittig auf die Auffahrt zielen. Auf dem Rohr hält dich das Einloggen in der Spur."},
		{"id": "board", "name": "Boardslide", "title": "Boardslide auf der Pipe",
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 65.0, "side": 1}, "end_s": 75.0,
		 "metric": "dist_bs", "medals": [4.0, 8.0, 12.0],
		 "goal": "Quer über die Pipe: nur Meter im Boardslide zählen. Am Ende das Brett wieder gerade stellen – wer quer ins Wasser fährt, stürzt.",
		 "keys": "Schräg anfahren – das Brett rastet quer ein; vor dem Ende ← / → tippen (zurück auf 50-50)",
		 "keys_mobile": "Schräg anfahren – das Brett rastet quer ein; vor dem Ende deutlich neigen (zurück auf 50-50)",
		 "tip": "Leicht schräg auf die Auffahrt fahren. Kurz vor dem Ende umspringen oder auf der Abfahrt gerade drehen."},
		{"id": "board_drift", "name": "Drift", "title": "Boardslide mit Drift-Abgang", "drift_exit": true,
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 65.0, "side": 1}, "end_s": 75.0,
		 "metric": "dist_bs", "medals": [4.0, 8.0, 12.0],
		 "goal": "Boardslide über die Pipe und quer bleiben – beim Abgang Drift halten: dann rutscht das Brett quer weiter, ohne einzuhaken.",
		 "keys": "Strg (Drift) halten, wenn das Brett das Wasser berührt",
		 "keys_mobile": "DRIFT halten, wenn das Brett das Wasser berührt",
		 "tip": "Drift rechtzeitig drücken – kurz vor dem Ende der Pipe. Wer das Brett gerade stellt, bekommt hier keinen Wert."},
		{"id": "switch", "name": "Umspringen", "title": "Boardslide / 50-50 umspringen",
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": -6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 155.0, "side": -1}, "end_s": 165.0,
		 "metric": "switches", "medals": [1.0, 2.0, 4.0],
		 "goal": "Auf dem Long Rail (links, 100 m) zwischen Boardslide und 50-50 wechseln. Gezählt werden die Wechsel.",
		 "keys": "Auf dem Slider: je Tipp ← / →  90° drehen",
		 "keys_mobile": "Auf dem Slider: deutlich neigen, zurück, wieder neigen",
		 "tip": "Nach jedem Tipp loslassen – erst dann geht der nächste Wechsel."},
		{"id": "press", "name": "Press", "title": "Nose- oder Tailpress",
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": -6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 155.0, "side": -1}, "end_s": 165.0,
		 "metric": "press", "medals": [1.0, 2.5, 4.0],
		 "goal": "Auf dem Long Rail Gewicht auf Nose oder Tail: gemessen werden die Sekunden im Press.",
		 "keys": "Auf dem Slider: ↑  Nosepress    ↓  Tailpress (halten)",
		 "keys_mobile": "Auf dem Slider: ▲  Nosepress    ▼  Tailpress (halten)",
		 "tip": "Erst sauber auf dem Rail stehen, dann ↑ oder ↓ halten. Beim Absprung loslassen, sonst gibt es keinen Überschlag."},
		{"id": "long", "name": "Long Rail", "title": "Long Rail: 100 m",
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": -6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 155.0, "side": -1}, "end_s": 165.0,
		 "metric": "dist", "medals": [30.0, 60.0, 90.0],
		 "goal": "So weit wie möglich auf dem 100-m-Rail bleiben.",
		 "keys": "← / →  lenken",
		 "keys_mobile": "Neigen  lenken",
		 "tip": "Der Seilzug zieht dich zur Seilmitte – auf dem Rail nicht gegenlenken, das Einloggen hält die Spur."},
		{"id": "chain", "name": "Slider-Kette", "title": "Slider-Kette",
		 "kind": "chain", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 155.0, "side": 1}, "end_s": 160.0,
		 "metric": "count", "medals": [2.0, 3.0, 4.0],
		 "goal": "Rechts stehen vier Slider hintereinander: Full Pipe, Rail, A-Frame, Pipe. Wie viele schaffst du in einer Fahrt?",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Nach jedem Slider zieht dich das Seil nach innen: sofort wieder nach außen auf Linie lenken – alle stehen auf derselben Spur."},
	]},
	{"id": "raley", "name": "Raley", "text": "Raley: mit viel Power nach der Wende.", "tasks": [
		{"id": "first", "name": "Erster Raley", "title": "Den ersten Raley stehen",
		 "kind": "raley", "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 2.2],
		 "goal": "Nach der Ufer-Wende Tempo aufbauen und einen Raley stehen. Gemessen: größte Höhe.",
		 "keys": "Leertaste lange halten (voll aufladen) + loslassen bei über 40 km/h",
		 "keys_mobile": "SPRUNG lange halten (voll aufladen) + loslassen bei über 40 km/h",
		 "tip": "Nach der Wende weit nach außen fahren, dann hart gegen den Zug zur Seilmitte kanten – im schnellsten Moment loslassen."},
		{"id": "spin", "name": "Raley 180/360", "title": "Raley mit Drehung",
		 "kind": "raley", "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "spin", "medals": [180.0, 360.0, 540.0],
		 "goal": "Raley und dabei drehen: 180 = Bronze, 360 = Silber, 540 = Gold.",
		 "keys": "In der Luft ← / →  drehen",
		 "keys_mobile": "In der Luft neigen = drehen",
		 "tip": "Früh mit dem Drehen anfangen und rechtzeitig loslassen – das Brett muss zur Landung in Fahrtrichtung zeigen."},
		{"id": "roll", "name": "Raley + Roll", "title": "Raley mit Überschlag",
		 "kind": "raley", "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "points", "medals": [450.0, 600.0, 800.0],
		 "goal": "Raley mit Frontroll oder Backroll (und gern einer Drehung). Gemessen: Punkte des Sprungs.",
		 "keys": "In der Luft ↑  Frontroll   ↓  Backroll   ← / →  drehen",
		 "keys_mobile": "In der Luft ▲  Frontroll   ▼  Backroll   neigen  drehen",
		 "tip": "Die Rolle braucht Zeit: gleich nach dem Absprung ↑ oder ↓ drücken."},
	]},
	{"id": "transfer", "name": "Transfer", "text": "Von einem Feature auf ein anderes springen.", "tasks": [
		{"id": "klein", "name": "Klein", "title": "Pyramid auf Pyramid-Rail",
		 "kind": "slide", "setup": "res://setups/setup_c.json", "terminal": "T2",
		 "start": {"s": 33.0, "x": -6.6, "dir": 1}, "end_s": 92.0,
		 "via": {"name": "Pyramid"}, "target": {"name": "A-Frame Rail"},
		 "via_fail": "Erst auf die Pyramid, dann aufs Rail springen",
		 "metric": "dist", "medals": [2.0, 5.0, 8.0],
		 "goal": "Terminal 2, Setup C: über die Pyramid fahren und oben seitlich auf das A-Frame Rail daneben springen. Gemessen: gerutschte Meter auf dem Rail.",
		 "keys": "Leertaste halten + loslassen  Absprung, in der Luft ← / →  Richtung Rail",
		 "keys_mobile": "SPRUNG halten + loslassen  Absprung, in der Luft neigen  Richtung Rail",
		 "tip": "Auf der Pyramid nahe an der Rail-Seite fahren, dann kurz abspringen – das Einloggen zieht dich aufs Rail."},
		{"id": "gross", "name": "Groß", "title": "Wedge auf Down Ledge",
		 "kind": "slide", "setup": "res://setups/setup_a.json", "terminal": "T1",
		 "start": {"s": 150.0, "x": -4.9, "dir": -1}, "end_s": 92.0,
		 "via": {"name": "Cheese Wedge"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst über den Wedge, dann auf die Down Ledge springen",
		 "metric": "dist", "medals": [2.0, 5.0, 9.0],
		 "goal": "Terminal 1, Setup A: über den Wedge (Kicker-Höhe wie Kicker M) und seitlich hoch auf die Down Ledge springen. Gemessen: gerutschte Meter auf der Ledge.",
		 "keys": "Leertaste halten (auf dem Wedge) + an der Kante loslassen, in der Luft ← / →  Richtung Ledge",
		 "keys_mobile": "SPRUNG halten (auf dem Wedge) + an der Kante loslassen, in der Luft neigen",
		 "tip": "Die Ledge ist höher als die Kante des Wedges – voll aufladen und kräftig abspringen."},
		{"id": "special", "name": "Special", "title": "Curb auf Down Ledge",
		 "kind": "slide", "setup": "res://setups/setup_d.json", "terminal": "T2",
		 "start": {"s": 150.0, "x": 4.05, "dir": -1}, "end_s": 95.0,
		 "via": {"name": "Transition Curb"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst auf die Transition Curb, dann auf die Down Ledge springen",
		 "metric": "dist", "medals": [2.0, 5.0, 9.0],
		 "goal": "Terminal 2, Setup D: mit einem Ollie auf die Transition Curb, darauf hoch und dann auf die Down Ledge daneben springen. Wie du slidest, ist egal. Gemessen: Meter auf der Ledge.",
		 "keys": "Leertaste: Ollie auf die Curb, auf der Curb nochmal abspringen, in der Luft ← / →",
		 "keys_mobile": "SPRUNG: Ollie auf die Curb, auf der Curb nochmal abspringen, in der Luft neigen",
		 "tip": "Auf der Curb ist glattes Plastik – lenken geht nicht. Schon vor dem Ollie auf die richtige Linie gehen."},
		{"id": "special2", "name": "Special Press", "title": "Curb auf Down Ledge mit Nosepress",
		 "kind": "slide", "setup": "res://setups/setup_d.json", "terminal": "T2",
		 "start": {"s": 150.0, "x": 4.05, "dir": -1}, "end_s": 95.0,
		 "via": {"name": "Transition Curb"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst auf die Transition Curb, dann auf die Down Ledge springen",
		 "metric": "press", "medals": [0.5, 1.5, 2.5],
		 "goal": "Wie Transfer special, aber auf der Down Ledge einen Nosepress halten. Gemessen: Sekunden im Press.",
		 "keys": "Auf der Ledge ↑ halten (Nosepress)",
		 "keys_mobile": "Auf der Ledge ▲ halten (Nosepress)",
		 "tip": "Erst sauber auf der Ledge landen, dann ↑ drücken – beim Abgang loslassen."},
	]},
]

const SECTION := "medaillen"


static func mode_index(id: String) -> int:
	for i in MODES.size():
		if MODES[i]["id"] == id:
			return i
	return 0


static func tasks(mode_id: String) -> Array:
	return MODES[mode_index(mode_id)].get("tasks", [])


## Medaille für einen Messwert: 0 keine, 1 Bronze, 2 Silber, 3 Gold.
static func medal_for(task: Dictionary, value: float) -> int:
	var th: Array = task["medals"]
	var lower: bool = task.get("lower", false)
	var m := 0
	for i in 3:
		if (value <= float(th[i])) if lower else (value >= float(th[i])):
			m = i + 1
	return m


## Messwert lesbar, z. B. "2,4 m", "35 %", "3 Wechsel".
static func format_value(task: Dictionary, value: float) -> String:
	match task["metric"]:
		"sink":
			return "%d %% eingesunken" % roundi(value * 100.0)
		"height", "dist", "dist_5050", "dist_bs":
			return ("%.1f m" % value).replace(".", ",")
		"press":
			return ("%.1f s" % value).replace(".", ",")
		"switches":
			return "%d Wechsel" % roundi(value)
		"count":
			return "%d Slider" % roundi(value)
		"spin":
			return "%d°" % roundi(value)
		"points":
			return "%d Punkte" % roundi(value)
	return str(value)


## Schwelle als Text, z. B. "ab 2,8 m" bzw. "bis 10 %" (Sonderzeichen fehlen in der Web-Schrift).
static func format_threshold(task: Dictionary, i: int) -> String:
	var v: float = float(task["medals"][i])
	var lower: bool = task.get("lower", false)
	if task["metric"] == "sink":
		return "bis %d %%" % roundi(v * 100.0) if v > 0.0 else "nicht einsinken"
	var t := format_value(task, v)
	return ("bis " if lower else "ab ") + t


## Gespeicherte Bestleistung: [Medaille, Bestwert] (Bestwert NAN = noch kein Versuch gewertet).
static func best(mode_id: String, task_id: String) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.FILE) != OK:
		return [0, NAN]
	var v: Variant = cfg.get_value(SECTION, mode_id + "." + task_id, [0, NAN])
	return v if v is Array and (v as Array).size() == 2 else [0, NAN]


## Neues Ergebnis eintragen (nur wenn besser). Liefert true bei neuer Bestleistung.
static func record(mode_id: String, task: Dictionary, value: float) -> bool:
	var old := best(mode_id, task["id"])
	var lower: bool = task.get("lower", false)
	var old_v: float = old[1]
	if not is_nan(old_v) and ((value >= old_v) if lower else (value <= old_v)):
		return false
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.FILE)
	cfg.set_value(SECTION, mode_id + "." + task["id"], [maxi(int(old[0]), medal_for(task, value)), value])
	cfg.save(GameSettings.FILE)
	return true
