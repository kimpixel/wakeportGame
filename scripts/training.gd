class_name Training
extends RefCounted
## Spielmodi: "Competition" (Runde auf Zeit, wie bisher) und Trainings-Modi mit Aufgaben, die von
## Aufgabe zu Aufgabe schwieriger werden. Jede Aufgabe misst einen Wert und vergibt Bronze, Silber
## oder Gold. Die Aufgabe setzt den Fahrer in voller Fahrt kurz vor die Stelle (Wende, Kicker,
## Slider); jeder Versuch beginnt wieder dort (Challenge). Bestwerte: user://settings.cfg [medaillen].
##
## Felder einer Aufgabe:
##   id, name (kurz, Liste), title, goal, keys / keys_mobile (Steuerung), tip
##   kind     turn | kick | slide | chain | raley | special | drift_spin | drift_turn | drift_after | dpress | dock | pool | r2r
##   trick    pool: gemessener Pool-Trick (Rider.pool_trick: drop, gap, stair_gap, stair_down, stair_up, coping_link)
##            oder "special" (alle aus need in einem Versuch, Wert = Punkte); miss = Text, wenn verpasst
##   chain    r2r: so viele Slider hintereinander, jeder per Transfer (seitlicher Hop) vom vorigen; Messwert auf dem letzten
##   press    dpress: "tail" / "nose" (längster Press am Stück) oder "switch" (Wechsel in einem Drift)
##   jump     dock: verlangter Sprung-Start "nolli" (Brett längs) oder "raley" (quer); start {dock: true} = auf dem Steg
##   setup    Setup-Datei (Terminal 2)
##   start    {s, x, dir}: s = Abstand vom Startmast wie in den Setup-Dateien (ohne Verschiebung),
##            dir +1 = Richtung Endmast, -1 = Richtung Startsteg. Wende: {turn: "a"|"b", before, x}
##   metric   Messwert: sink, height, width (Weite eines Sprungs), speed (km/h), dist, dist_5050, dist_bs, switches, press, time (s auf dem Slider), count, spin, points,
##            spins (360er im Drift), share (Anteil der Wende im Drift)
##   medals   Schwellen [Bronze, Silber, Gold]; lower = true: kleiner ist besser
##   target   kick/slide: {s0, s1, side} – Features mit Mitte in diesem Bereich (Setup-Koordinaten),
##            side +1/-1 = rechte/linke Seite
##   end_s    Versuch endet spätestens hier (Setup-Koordinaten, in Fahrtrichtung)
##   combo    special: je Slider der Kette (nach s sortiert) eine Kombination {name, on, stance, press, out}:
##            immer Ollie on (aus der Luft direkt auf den Slider, nicht über die Auffahrt), on/out =
##            halbe Drehungen beim Aufspringen/Abgang (1 = 180, 2 = 360; fehlt = egal bzw. 0 beim on),
##            stance "5050"/"bs" (überwiegend), press "nose"/"tail" (mehr als die halbe Slide-Zeit)

const COMPETITION := "competition"
const MEDALS := ["", "Bronze", "Silber", "Gold"]  # i18n
const MEDAL_COLORS := [Color(1, 1, 1, 0.25), Color(0.80, 0.50, 0.25), Color(0.80, 0.82, 0.86), Color(1.0, 0.80, 0.20)]

const SPEED := 30.0             # km/h Anlagen-Tempo in allen Aufgaben (vergleichbar)
const ROPE := 16.0              # m Seillänge in allen Aufgaben

const LEER := "res://setups/training_leer.json"
const KICKER := "res://setups/training_kicker.json"
const SLIDER := "res://setups/training_slider.json"
const POOL := "res://setups/training_pool.json"
const RAIL := "res://setups/training_rail.json"

## TEMP: Drift-Nosepress ist abgeschaltet (Rider.DPRESS_NOSE_ON) – diese Challenges stehen solange nicht im
## Modus Driften. Zum Zurückholen wieder hinter "tailpress" in MODES einfügen.
## Texte (name, title, goal, keys, tip …) sind Ausgangstexte, übersetzt beim Anzeigen (tr).
# i18n-begin name,title,goal,keys,keys_mobile,tip,text,miss,via_fail
const NOSE_TASKS := [
	{"id": "nosepress", "name": "Nosepress im Drift", "title": "Nosepress im Drift",
	 "kind": "dpress", "press": "nose", "setup": LEER, "start": {"turn": "a", "before": 70.0, "x": 2.0},
	 "metric": "press_share", "medals": [0.5, 0.8, 0.95],
	 "goal": "Wie der Tailpress, nur über die Nose: das Brett im Drift erst um 90° quer drehen, dann ins vordere Ende drücken, das Tail steht hoch. Der Winkel zählt von der Querstellung. Gemessen: Anteil der Wende im vollen Nosepress – ohne einzusinken. Gold = die ganze Wende.",
	 "keys": "Strg halten  driften     ↑ halten  Nosepress     ← / →  Drift-Winkel halten",
	 "keys_mobile": "DRIFT halten  driften     ▲ halten  Nosepress     Neigen  Winkel halten",
	 "tip": "Erst quer drehen, dann drücken – mit der Nose vorne stehst du 90° falsch. Je schneller, desto querer darfst du driften. Den Drift nicht loslassen – dann ist der Press sofort vorbei."},
	{"id": "presswechsel", "name": "Press-Wechsel", "title": "Nose- und Tailpress im Wechsel",
	 "kind": "dpress", "press": "switch", "setup": LEER, "start": {"turn": "a", "before": 70.0, "x": 2.0},
	 "metric": "switches", "medals": [1.0, 3.0, 5.0],
	 "goal": "In einem Drift zwischen Nosepress und Tailpress hin und her wechseln. Gemessen: Wechsel in einem Drift (jeder volle Press auf das andere Ende zählt; Drift loslassen fängt neu an).",
	 "keys": "Strg halten  driften     ↑ / ↓  Nose- / Tailpress",
	 "keys_mobile": "DRIFT halten  driften     ▲ / ▼  Nose- / Tailpress",
	 "tip": "Der Press braucht knapp eine Sekunde, bis er ganz drin ist – nicht zu hektisch wechseln."},
]

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
		 "keys": "Auf der Pipe ← / → tippen (Boardslide), vor dem Ende nochmal tippen (zurück auf 50-50)",
		 "keys_mobile": "Auf der Pipe deutlich neigen (Boardslide), vor dem Ende nochmal neigen (zurück auf 50-50)",
		 "tip": "Oder schon in der Luft quer drehen – das Brett rastet in die nächste Stellung ein. Kurz vor dem Ende umspringen oder auf der Abfahrt gerade drehen."},
		{"id": "board_drift", "name": "Drift", "title": "Boardslide mit Drift-Abgang", "drift_exit": true,
		 "kind": "slide", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 65.0, "side": 1}, "end_s": 75.0,
		 "metric": "dist_bs", "medals": [4.0, 8.0, 12.0],
		 "goal": "Boardslide über die Pipe und quer bleiben – beim Abgang Drift halten: dann rutscht das Brett quer weiter, ohne einzuhaken.",
		 "keys": "Auf der Pipe ← / → tippen (Boardslide), Strg (Drift) halten, wenn das Brett das Wasser berührt",
		 "keys_mobile": "Auf der Pipe deutlich neigen (Boardslide), DRIFT halten, wenn das Brett das Wasser berührt",
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
		{"id": "bs_nose", "name": "BS Nosepress", "title": "Ollie in Boardslide Nosepress",
		 "kind": "special", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 65.0, "side": 1}, "end_s": 75.0,
		 "metric": "dist", "medals": [4.0, 7.0, 10.0],
		 "combo": [{"name": "Full Pipe", "stance": "bs", "press": "nose"}],
		 "goal": "Mit einem Ollie aus dem Wasser direkt auf die Full Pipe, in der Luft quer drehen und im Boardslide mit Nosepress rutschen. Gemessen: gerutschte Meter – nur wenn Ollie on, Boardslide und Nosepress stimmen.",
		 "keys": "Leertaste  Ollie     in der Luft ← / → kurz tippen (Vierteldrehung)     auf der Pipe ↑ halten",
		 "keys_mobile": "SPRUNG  Ollie     in der Luft kurz neigen (Vierteldrehung)     auf der Pipe ▲ halten",
		 "tip": "Nicht über die Auffahrt fahren, sondern vor der Pipe abspringen. Eine Vierteldrehung reicht – das Brett rastet quer ein. Am Ende das Brett gerade stellen (← / →) oder Drift halten, sonst stürzt man quer ins Wasser."},
		{"id": "special", "name": "Special", "title": "Slider Special",
		 "kind": "special", "setup": SLIDER, "start": {"s": 22.0, "x": 6.0, "dir": 1},
		 "target": {"s0": 45.0, "s1": 155.0, "side": 1}, "end_s": 160.0,
		 "metric": "count", "medals": [2.0, 3.0, 4.0],
		 "combo": [
			{"name": "Full Pipe", "stance": "5050", "press": "nose"},
			{"name": "Rail", "stance": "bs", "press": "tail"},
			{"name": "A-Frame", "stance": "bs", "press": "nose", "out": 1},
			{"name": "Pipe", "on": 1, "stance": "5050", "press": "tail", "out": 2},
		 ],
		 "goal": "Die Slider-Kette rechts, an jedem Slider eine feste Kombination. Gezählt: geschaffte Slider.",
		 "keys": "Leertaste  Ollie on / out     ← / →  in der Luft drehen, auf dem Slider Boardslide / 50-50     ↑ / ↓  Nose- / Tailpress",
		 "keys_mobile": "SPRUNG  Ollie on / out     Neigen  in der Luft drehen, auf dem Slider Boardslide / 50-50     ▲ / ▼  Nose- / Tailpress",
		 "tip": "Ollie on heißt: aus dem Wasser direkt auf das Rohr springen, nicht über die Auffahrt fahren. Den Press mehr als die halbe Slide-Zeit halten."},
	]},
	# Invert Training: jede Aufgabe verlangt genau einen Trick ("trick" = Name wie im Spiel, "rank" = Anzahl
	# Zusätze: Drehung je 180, Invert-Trick); mehr gemacht = fehlgeschlagen. Gemessen wird die Höhe.
	{"id": "raley", "name": "Invert Training", "text": "Inverts: Tricks aus dem Raley-Absprung nach der Wende.", "tasks": [
		{"id": "first", "name": "Raley – Höhe", "title": "Höchster Raley",
		 "kind": "raley", "lb": 1, "trick": "Raley", "rank": 0, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [3.0, 4.0, 5.0],
		 "goal": "Nach der Ufer-Wende Seilzug aufbauen und einen Raley stehen – ohne Drehung, ohne Extras. Gemessen: größte Höhe.",
		 "keys": "Leertaste lange halten (voll aufladen) + loslassen, wenn der Seilzug über der Marke RALEY ist",
		 "keys_mobile": "SPRUNG lange halten (voll aufladen) + loslassen, wenn der Seilzug über der Marke RALEY ist",
		 "tip": "Nach der Wende weit nach außen fahren, dann hart gegen den Zug zur Seilmitte kanten – loslassen, solange der Seilzug über der Marke RALEY ist – je mehr Zug und Tempo, desto höher."},
		{"id": "weit", "name": "Raley – Weite", "title": "Weitester Raley",
		 "kind": "raley", "lb": 1, "trick": "Raley", "rank": 0, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "width", "medals": [14.0, 20.0, 26.0],
		 "goal": "Nach der Ufer-Wende Seilzug aufbauen und einen Raley stehen – ohne Drehung, ohne Extras. Gemessen: Weite vom Absprung bis zur Landung.",
		 "keys": "Leertaste lange halten (voll aufladen) + loslassen, wenn der Seilzug über der Marke RALEY ist",
		 "keys_mobile": "SPRUNG lange halten (voll aufladen) + loslassen, wenn der Seilzug über der Marke RALEY ist",
		 "tip": "Weit nach außen, dann hart zur Seilmitte kanten – je mehr Zug und Tempo, desto weiter."},
		{"id": "krypt", "name": "Krypt", "title": "Krypt (Raley 180 rechts)",
		 "kind": "raley", "lb": 1, "trick": "Krypt", "rank": 1, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "Raley mit genau einer halben Drehung nach rechts. Gemessen: größte Höhe.",
		 "keys": "Raley, dann gegen Ende →  halten (180)",
		 "keys_mobile": "Raley, dann gegen Ende nach rechts neigen (180)",
		 "tip": "Erst strecken lassen, dann ← / → : der Schwung bricht ab, du schwingst zurück und drehst aufrecht – rechtzeitig loslassen."},
		{"id": "blindjudge", "name": "Blind Judge", "title": "Blind Judge (Raley 180 links)",
		 "kind": "raley", "lb": 1, "trick": "Blind Judge", "rank": 1, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "Raley mit genau einer halben Drehung nach links. Gemessen: größte Höhe.",
		 "keys": "Raley, dann gegen Ende ←  halten (180)",
		 "keys_mobile": "Raley, dann gegen Ende nach links neigen (180)",
		 "tip": "Erst strecken lassen, dann ← / → : der Schwung bricht ab, du schwingst zurück und drehst aufrecht – rechtzeitig loslassen."},
		{"id": "313", "name": "313", "title": "313 (Raley 360 links)",
		 "kind": "raley", "lb": 1, "trick": "313", "rank": 2, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "Raley mit genau einer ganzen Drehung nach links. Gemessen: größte Höhe.",
		 "keys": "Raley, dann gegen Ende ←  halten (360)",
		 "keys_mobile": "Raley, dann gegen Ende nach links neigen (360)",
		 "tip": "Viel Höhe holen – die ganze Drehung braucht die Zeit vom höchsten Punkt bis zur Landung."},
		{"id": "sbend", "name": "S-Bend", "title": "S-Bend",
		 "kind": "raley", "lb": 1, "trick": "S-Bend", "rank": 1, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "Raley-Absprung und gestreckt einmal um die eigene Längsachse – ohne Drehung danach. Gemessen: größte Höhe.",
		 "keys": "Raley, gleich nach dem Absprung ↑",
		 "keys_mobile": "Raley, gleich nach dem Absprung ▲",
		 "tip": "Die Taste nur ganz am Anfang drücken – später wird es ein normaler Raley."},
		{"id": "backroll", "name": "Backroll (todo)", "title": "Backroll (Invert, todo)",
		 "kind": "raley", "lb": 1, "trick": "Backroll", "rank": 1, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "Raley-Absprung und seitlich nach außen kopfüber rollen – ohne Drehung danach. Gemessen: größte Höhe.",
		 "keys": "Raley, gleich nach dem Absprung ↓",
		 "keys_mobile": "Raley, gleich nach dem Absprung ▼",
		 "tip": "Die Taste nur ganz am Anfang drücken – später wird es ein normaler Raley."},
		{"id": "sbend_blind", "name": "Special - S-Bend to Blind", "title": "Special: S-Bend to Blind",
		 "kind": "raley", "lb": 1, "trick": "S-Bend to Blind", "rank": 2, "setup": LEER, "start": {"turn": "a", "before": 45.0, "x": -2.0}, "end_after": 90.0,
		 "metric": "height", "medals": [0.5, 1.5, 4.3],
		 "goal": "S-Bend und danach genau eine halbe Drehung nach links – blind landen. Gemessen: größte Höhe.",
		 "keys": "Raley, gleich nach dem Absprung ↑, nach der Drehung um die Handle ←  (180)",
		 "keys_mobile": "Raley, gleich nach dem Absprung ▲, nach der Drehung um die Handle nach links neigen (180)",
		 "tip": "Viel Höhe holen: ← erst, wenn der S-Bend durch ist – dann schwingst du zurück und drehst aufrecht. Rechtzeitig loslassen."},
	]},
	{"id": "sprungstart", "name": "Sprung-Start", "text": "Vom Startsteg: gegen das Seil stemmen, bis es dich losreißt.", "tasks": [
		{"id": "nolli", "name": "Nolli", "title": "Nolli vom Steg",
		 "kind": "dock", "jump": "nolli", "setup": LEER, "start": {"dock": true},
		 "metric": "height", "medals": [3.0, 3.7, 4.1],
		 "goal": "Bleib auf dem Startsteg mit dem Brett längs zum Seil (50-50) stehen und halte ↓: du stemmst dich gegen das anfahrende Seil, der Seilzug lädt sich auf. Bei maximaler Seilspannung reißt es dich nach vorne – ein Nolli. Gemessen: größte Höhe.",
		 "keys": "↓ halten (schon beim Countdown), bis das Seil losreißt",
		 "keys_mobile": "▼ halten (schon beim Countdown), bis das Seil losreißt",
		 "tip": "Je genauer das Brett längs zum Seil steht, desto mehr Power. Nicht vorher loslassen – sonst ist es ein normaler Start."},
		{"id": "nolli_spin", "name": "Nolli 180/360", "title": "Nolli mit Drehung",
		 "kind": "dock", "jump": "nolli", "setup": LEER, "start": {"dock": true},
		 "metric": "spin", "medals": [180.0, 360.0, 540.0],
		 "goal": "Nolli vom Steg und in der Luft drehen: 180 = Bronze, 360 = Silber, 540 = Gold.",
		 "keys": "↓ halten bis zum Riss, dann in der Luft ← / →  drehen",
		 "keys_mobile": "▼ halten bis zum Riss, dann in der Luft neigen = drehen",
		 "tip": "Gleich nach dem Riss drehen und rechtzeitig loslassen – das Brett muss zur Landung in Fahrtrichtung zeigen."},
		{"id": "raley", "name": "Raley Start", "title": "Raley Start vom Steg",
		 "kind": "dock", "jump": "raley", "setup": LEER, "start": {"dock": true},
		 "metric": "height", "medals": [3.0, 3.7, 4.1],
		 "goal": "Dreh dich auf dem Steg um 90°, sodass das Brett quer zum Seil steht, und halte ↓: du sitzt tief auf der Kante, Brust zum Seil. Reißt das Seil los, schwingt dein Körper um den Griff wie beim Raley. Gemessen: größte Höhe.",
		 "keys": "← / →  auf dem Steg quer drehen     ↓ halten, bis das Seil losreißt",
		 "keys_mobile": "Neigen  auf dem Steg quer drehen     ▼ halten, bis das Seil losreißt",
		 "tip": "Schon beim Countdown drehen – je genauer quer, desto höher. Ab 45° Abweichung wird es ein Nolli."},
		{"id": "raley_roll", "name": "Raley Start + Invert", "title": "Raley Start mit Invert",
		 "kind": "dock", "jump": "raley", "setup": LEER, "start": {"dock": true},
		 "metric": "points", "medals": [380.0, 640.0, 740.0],
		 "goal": "Raley Start und in der Luft noch etwas dazu: 180 = Bronze, S-Bend oder Backroll = Silber, S-Bend/Backroll + 360 = Gold. Gemessen: Punkte des Sprungs.",
		 "keys": "Quer drehen, ↓ halten bis zum Riss, in der Luft loslassen, dann gleich ↑ S-Bend / ↓ Backroll, gegen Ende ← / →  drehen",
		 "keys_mobile": "Quer drehen, ▼ halten bis zum Riss, in der Luft loslassen, dann gleich ▲ S-Bend / ▼ Backroll, gegen Ende neigen  drehen",
		 "tip": "Das gehaltene ↓ zählt nicht – erst loslassen, dann sofort ↑ oder ↓ drücken: der Trick wird nur ganz am Anfang gewählt."},
	]},
	{"id": "drift", "name": "Driften", "text": "Kante lösen und gleiten: das Brett dreht frei, die Fahrtrichtung bleibt.", "tasks": [
		{"id": "spin", "name": "360 im Drift", "title": "360er im Drift",
		 "kind": "drift_spin", "setup": LEER, "start": {"s": 18.0, "x": 0.0, "dir": 1},
		 "metric": "spins", "medals": [4.0, 7.0, 10.0],
		 "goal": "Driften heißt: die Kante lösen. Das Brett liegt flach und greift nicht mehr – Lenken ändert die Fahrtrichtung nicht, nur der Seilzug zieht dich, und das Brett lässt sich frei herumdrehen. Dreh so zwischen den roten Bojen (Ufer bis Endmast) fünf 360er in die eine und fünf in die andere Richtung – gezählt wird jede volle Umdrehung im Drift, höchstens fünf je Richtung.",
		 "keys": "Strg halten  driften     ← / →  Brett drehen",
		 "keys_mobile": "DRIFT halten  driften     Neigen  Brett drehen",
		 "tip": "Erst fünf in eine Richtung, dann umsteuern – die Strecke reicht nur knapp, also nicht trödeln. Wer den Drift loslässt, verliert die angefangene Umdrehung – und quer greift die Kante hart und bremst."},
		{"id": "wende", "name": "Wende im Drift", "title": "Die Wende durchgleiten",
		 "kind": "drift_turn", "setup": LEER, "start": {"turn": "b", "before": 60.0, "x": 2.0},
		 "metric": "share", "medals": [0.5, 0.75, 0.9],
		 "goal": "Vor der Wende am Endmast mächtig Schwung holen und dann die ganze Wende im Drift durchgleiten – ohne einzusinken. Gemessen: Anteil der Wende, in dem du im Drift gleitest, ohne einzusinken (vom Bremsen des Carriers, bis das Seil in der neuen Richtung wieder zieht).",
		 "keys": "← / →  lenken (Schwung holen)     Strg halten  driften",
		 "keys_mobile": "Neigen  lenken (Schwung holen)     DRIFT halten  driften",
		 "tip": "An der roten Boje weit rauskanten und Tempo aufbauen. Im Drift bremst das Wasser weniger – du gleitest weiter. Ist zu wenig Schwung da, sinkst du ein."},
		{"id": "feature", "name": "Drift nach Feature", "title": "Nach dem Feature driften",
		 "kind": "drift_after", "setup": "res://setups/setup_f.json", "terminal": "T2",
		 "start": {"s": 150.0, "x": 0.0, "dir": -1}, "end_s": 40.0,
		 "metric": "dist", "medals": [10.0, 20.0, 30.0],
		 "goal": "Terminal 2, Setup Juli & August: von der Mitte Richtung Steg über ein Feature deiner Wahl und gleich danach driften – mindestens 10 m. Gemessen: der längste Drift, der direkt nach einem Feature beginnt (auch nach dem Sprung davon).",
		 "keys": "Strg schon auf dem Feature halten und danach nicht loslassen",
		 "keys_mobile": "DRIFT schon auf dem Feature halten und danach nicht loslassen",
		 "tip": "Mit Drift darf das Brett beim Abgang auch quer stehen. Der Seilzug zieht dich im Drift zur Seilmitte – vorher weit außen auf das Feature fahren."},
		{"id": "tailpress", "name": "Tailpress im Drift", "title": "Tailpress im Drift",
		 "kind": "dpress", "press": "tail", "setup": LEER, "start": {"turn": "a", "before": 70.0, "x": 2.0},
		 "metric": "press_share", "medals": [0.5, 0.8, 0.95],
		 "goal": "Auf dem Weg zum vorderen Wendepunkt driften und dabei ins Tail drücken: das Brett kippt um das Tail, die Nose steht hoch, die freie Hand streift das Wasser. Du gleitest mit dem ganzen Schwung weiter. Driftest du querer, als es dein Tempo erlaubt (höchstens 86°, nach links wie nach rechts), stürzt du – mit ← / → den Winkel halten. Gemessen: Anteil der Wende im vollen Tailpress (vom Bremsen des Carriers, bis das Seil in der neuen Richtung wieder zieht) – ohne einzusinken. Gold = die ganze Wende.",
		 "keys": "Strg halten  driften     ↓ halten  Tailpress     ← / →  Drift-Winkel halten",
		 "keys_mobile": "DRIFT halten  driften     ▼ halten  Tailpress     Neigen  Winkel halten",
		 "tip": "Hart rauskanten, im Drift das Brett erst weit quer drehen (um 75°), dann ins Tail drücken – so bremst nichts. Im goldenen Bereich des Bogens (die letzten rund 45° vor der Grenze) bremst der Press gar nicht; querer als 86° reißt es dich um. Den Winkel mit ← / → halten, während dich das Seil um den Carrier schwingt."},
	]},
	{"id": "transfer", "name": "Transfer", "text": "Von einem Feature auf ein anderes springen.", "tasks": [
		{"id": "klein", "name": "Klein", "title": "Pyramid auf Pyramid-Rail",
		 "kind": "slide", "setup": "res://setups/setup_c.json", "terminal": "T2",
		 "start": {"s": 33.0, "x": -6.6, "dir": 1}, "end_s": 92.0,
		 "via": {"name": "Pyramid"}, "target": {"name": "A-Frame Rail"},
		 "via_fail": "Erst auf die Pyramid, dann aufs Rail springen",
		 "metric": "height", "medals": [1.8, 2.1, 2.4],
		 "goal": "Terminal 2, Setup C: über die Pyramid fahren und oben seitlich auf das A-Frame Rail daneben springen. Gemessen: Sprunghöhe – so hoch wie möglich, aber das Rail noch erwischen.",
		 "keys": "Leertaste halten + loslassen  Absprung, in der Luft ← / →  Richtung Rail",
		 "keys_mobile": "SPRUNG halten + loslassen  Absprung, in der Luft neigen  Richtung Rail",
		 "tip": "Auf der Pyramid nahe an der Rail-Seite fahren, dann kurz abspringen – das Einloggen zieht dich aufs Rail."},
		{"id": "gross", "name": "Groß", "title": "Wedge auf Down Ledge",
		 "kind": "slide", "setup": "res://setups/setup_a.json", "terminal": "T1",
		 "start": {"s": 150.0, "x": -4.9, "dir": -1}, "end_s": 92.0,
		 "via": {"name": "Cheese Wedge"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst über den Wedge, dann auf die Down Ledge springen",
		 "metric": "height", "medals": [2.4, 2.8, 3.2],
		 "goal": "Terminal 1, Setup A: über den Wedge (Kicker-Höhe wie Kicker M) und seitlich hoch auf die Down Ledge springen. Gemessen: Sprunghöhe – so hoch wie möglich, aber die Ledge noch erwischen.",
		 "keys": "Leertaste halten (auf dem Wedge) + an der Kante loslassen, in der Luft ← / →  Richtung Ledge",
		 "keys_mobile": "SPRUNG halten (auf dem Wedge) + an der Kante loslassen, in der Luft neigen",
		 "tip": "Die Ledge ist höher als die Kante des Wedges – voll aufladen und kräftig abspringen."},
		{"id": "special", "name": "Special", "title": "Curb auf Down Ledge",
		 "kind": "slide", "setup": "res://setups/setup_d.json", "terminal": "T2",
		 "start": {"s": 150.0, "x": 4.05, "dir": -1}, "end_s": 95.0,
		 "via": {"name": "Transition Curb"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst auf die Transition Curb, dann auf die Down Ledge springen",
		 "metric": "height", "medals": [1.6, 2.0, 2.4],
		 "goal": "Terminal 2, Setup D: mit einem Ollie auf die Transition Curb, darauf hoch und dann auf die Down Ledge daneben springen. Wie du slidest, ist egal. Gemessen: Sprunghöhe von der Curb – so hoch wie möglich, aber die Ledge noch erwischen.",
		 "keys": "Leertaste: Ollie auf die Curb, auf der Curb nochmal abspringen, in der Luft ← / →",
		 "keys_mobile": "SPRUNG: Ollie auf die Curb, auf der Curb nochmal abspringen, in der Luft neigen",
		 "tip": "Auf der Curb ist glattes Plastik – lenken geht nicht. Schon vor dem Ollie auf die richtige Linie gehen."},
		{"id": "special2", "name": "Special Press", "title": "Curb auf Down Ledge mit Nosepress",
		 "kind": "slide", "setup": "res://setups/setup_d.json", "terminal": "T2",
		 "start": {"s": 150.0, "x": 4.05, "dir": -1}, "end_s": 95.0,
		 "via": {"name": "Transition Curb"}, "target": {"name": "Down Ledge"},
		 "via_fail": "Erst auf die Transition Curb, dann auf die Down Ledge springen",
		 "metric": "press", "medals": [0.3, 0.6, 0.9],
		 "goal": "Wie Transfer special, aber auf der Down Ledge einen Nosepress halten. Gemessen: Sekunden im Press.",
		 "keys": "Auf der Ledge ↑ halten (Nosepress)",
		 "keys_mobile": "Auf der Ledge ▲ halten (Nosepress)",
		 "tip": "Erst sauber auf der Ledge landen, dann ↑ drücken – beim Abgang loslassen."},
	]},
	# Pool: Challenges am 6-Stair Pool (Terminal 2, eigenes Setup mit drei Pools). Pool A rechts (x 4,2):
	# Rampe ab s 55, Becken bis 75, Treppe bis 79, Ausgänge bis 85. Pool B dahinter (ab s 110), Pool C links.
	{"id": "pool", "name": "Pool", "text": "Der 6-Stair Pool: rein ins Becken, die Treppe im Drift, auf den Rand und die Ausgänge.", "tasks": [
		{"id": "drop", "name": "Pool Drop", "title": "Pool Drop – Höhe",
		 "kind": "pool", "trick": "drop", "setup": POOL, "start": {"s": 25.0, "x": 4.2, "dir": 1}, "end_s": 90.0,
		 "miss": "Nicht über die Rampe ins Becken",
		 "metric": "height", "medals": [1.9, 2.3, 2.6],
		 "goal": "Fahr über die Rampe des Pools und spring ins Becken. Gemessen: höchster Punkt über dem See.",
		 "keys": "← / →  lenken     Leertaste halten + an der Kante loslassen  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG halten + an der Kante loslassen  Absprung",
		 "tip": "Mittig auf die Rampe zielen, voll aufladen und genau an der Kante loslassen. Nicht zu weit springen – hinter dem Becken kommt die Treppe."},
		{"id": "drop_weit", "name": "Pool Drop – Weite", "title": "Pool Drop – Weite",
		 "kind": "pool", "trick": "drop", "setup": POOL, "start": {"s": 25.0, "x": 4.2, "dir": 1}, "end_s": 90.0,
		 "miss": "Nicht über die Rampe ins Becken",
		 "metric": "width", "medals": [5.5, 7.5, 8.5],
		 "goal": "Wie eben, aber so weit wie möglich ins Becken. Gemessen: Weite vom Absprung bis zur Landung im Becken.",
		 "keys": "Leertaste halten + an der Kante loslassen",
		 "keys_mobile": "SPRUNG halten + an der Kante loslassen",
		 "tip": "Mit vollem Tempo und voller Ladung – das Becken ist 15 m lang, die Landung muss im Wasser sein."},
		{"id": "stair_down", "name": "Treppe runter", "title": "Die Treppe im Drift hinunter",
		 "kind": "pool", "trick": "stair_down", "setup": POOL, "start": {"s": 25.0, "x": 4.2, "dir": 1}, "end_s": 95.0,
		 "miss": "Nicht über die Treppe",
		 "metric": "speed", "medals": [35.0, 38.0, 40.0],
		 "goal": "Rein ins Becken, durchfahren und die Treppe am Ende im Drift hinunter in den See. Gemessen: Tempo unten.",
		 "keys": "Strg (Drift) halten, bevor das Brett die Treppe erreicht",
		 "keys_mobile": "DRIFT halten, bevor das Brett die Treppe erreicht",
		 "tip": "Ohne Drift ist die Treppe ein Sturz. Gerade auf die Treppe zielen – die Stufen sind glatt, lenken geht dort nicht."},
		{"id": "stair_up", "name": "Treppe hoch", "title": "Die Treppe im Drift hinauf",
		 "kind": "pool", "trick": "stair_up", "setup": POOL, "start": {"s": 100.0, "x": 4.2, "dir": -1}, "end_s": 60.0,
		 "miss": "Nicht über die Treppe ins Becken",
		 "metric": "speed", "medals": [8.0, 13.0, 18.0],
		 "goal": "Von hinten zwischen den Ausgängen auf die Treppe zu und im Drift hinauf ins Becken. Gemessen: Tempo oben.",
		 "keys": "Strg (Drift) halten, bevor das Brett die Treppe erreicht",
		 "keys_mobile": "DRIFT halten, bevor das Brett die Treppe erreicht",
		 "tip": "Hinauf braucht Schwung: mit vollem Tempo und gespanntem Seil kommen. Im Becken vor der Rampe abspringen, sonst fährt man gegen die Wand."},
		{"id": "coping", "name": "Coping", "title": "Auf dem Rand sliden",
		 "kind": "slide", "setup": POOL, "start": {"s": 25.0, "x": 6.3, "dir": 1}, "end_s": 95.0,
		 "target": {"name": "Pool Coping"},
		 "metric": "dist", "medals": [8.0, 11.0, 13.5],
		 "goal": "Fahr außen über die Rampe direkt auf den Rand des Beckens (Coping) und rutsch so weit wie möglich. Gemessen: Meter auf dem Rand.",
		 "keys": "← / →  lenken (auf dem Rand: Boardslide / 50-50)",
		 "keys_mobile": "Neigen  lenken (auf dem Rand deutlich neigen: Boardslide / 50-50)",
		 "tip": "Die Spur genau auf den Rand legen (ganz rechts auf der Rampe). Der Rand ist nur 40 cm breit – das Einloggen hilft."},
		{"id": "coping_link", "name": "Coping to Ledge", "title": "Rand und Ausgang in einem Zug",
		 "kind": "pool", "trick": "coping_link", "setup": POOL, "start": {"s": 25.0, "x": 6.3, "dir": 1}, "end_s": 95.0,
		 "miss": "Nicht vom Rand auf den Ausgang",
		 "metric": "dist", "medals": [12.0, 17.0, 21.5],
		 "goal": "Auf dem Rand sliden und am Ende über die Safety ohne Absetzen auf die Down Ledge. Gemessen: Meter auf Rand und Ledge zusammen.",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Die Safety am Anfang der Ledge wirft dich ein Stück hoch – gerade bleiben, dann landest du wieder auf der Ledge."},
		{"id": "stair_gap", "name": "Stair Gap", "title": "Über die Treppe springen",
		 "kind": "pool", "trick": "stair_gap", "setup": POOL, "start": {"s": 25.0, "x": 4.2, "dir": 1}, "end_s": 95.0,
		 "miss": "Kein Sprung aus dem Becken über die Treppe",
		 "metric": "width", "medals": [6.0, 8.5, 10.5],
		 "goal": "Im Becken Anlauf nehmen und am Ende über die ganze Treppe in den See springen. Gemessen: Weite des Sprungs.",
		 "keys": "Leertaste halten + am Ende des Beckens loslassen",
		 "keys_mobile": "SPRUNG halten + am Ende des Beckens loslassen",
		 "tip": "Erst kurz vor der Treppe loslassen. Landest du auf den Stufen, brauchst du Drift."},
		{"id": "special", "name": "Pool Special", "title": "Pool Special",
		 "kind": "pool", "trick": "special", "need": ["drop", "stair_down"], "setup": POOL, "start": {"s": 25.0, "x": 4.2, "dir": 1}, "end_s": 95.0,
		 "miss": "Pool Drop und Treppe im Drift nicht geschafft",
		 "metric": "points", "medals": [420.0, 470.0, 520.0],
		 "goal": "Die Pool-Linie in einem Zug: Pool Drop (gern mit Drehung) und dann die Treppe im Drift hinunter – als Kombination. Gemessen: Punkte der Pool-Tricks.",
		 "keys": "Leertaste  Absprung an der Rampe     ← / →  in der Luft drehen     Strg  Drift auf der Treppe",
		 "keys_mobile": "SPRUNG  Absprung an der Rampe     Neigen  in der Luft drehen     DRIFT  auf der Treppe",
		 "tip": "Die Kombination läuft 3 s – nach dem Drop nicht trödeln. Drehungen im Drop bringen mehr Punkte, die Treppe zählt in der Kombination doppelt."},
		{"id": "donkey", "name": "Donkey Rail", "title": "Ausgang: Donkey Rail",
		 "kind": "slide", "setup": POOL, "start": {"s": 88.0, "x": 2.2, "dir": 1}, "end_s": 145.0,
		 "target": {"name": "Donkey Rail"},
		 "metric": "dist", "medals": [4.0, 7.0, 9.0],
		 "goal": "Pool B (hinten rechts): links über die Rampe auf den Rand und über die Safety auf das Donkey Rail. Gemessen: Meter auf dem Rail.",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Erst runter, dann flach: auf dem flachen Stück bremst es nicht mehr, dort ruhig bleiben."},
		{"id": "lth", "name": "Low to High Ledge", "title": "Ausgang: Low to High Ledge",
		 "kind": "slide", "setup": POOL, "start": {"s": 88.0, "x": 6.3, "dir": 1}, "end_s": 145.0,
		 "target": {"name": "Low to High Ledge"},
		 "metric": "dist", "medals": [5.0, 8.0, 10.5],
		 "goal": "Pool B: rechts auf den Rand und auf die Low to High Ledge – sie steigt noch an. Gemessen: Meter auf der Ledge.",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Bergauf kostet Tempo: mit gespanntem Seil auf den Rand kommen. Hinten ist sie 2 m hoch – gerade abspringen."},
		{"id": "dk_rail", "name": "Double Kinked Rail", "title": "Ausgang: Double Kinked Rail",
		 "kind": "slide", "setup": POOL, "start": {"s": 25.0, "x": -6.3, "dir": 1}, "end_s": 95.0,
		 "target": {"name": "Double Kinked Rail"},
		 "metric": "dist", "medals": [6.0, 9.0, 11.0],
		 "goal": "Pool C (links): außen über die Rampe auf den Rand und auf das Double Kinked Rail mit zwei Knicken. Gemessen: Meter auf dem Rail.",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Außen zieht das Seil dich zur Mitte – auf dem Rand nicht gegenlenken, das Einloggen hält die Spur."},
		{"id": "fd_ledge", "name": "Flat Down Ledge", "title": "Ausgang: Flat Down Ledge",
		 "kind": "slide", "setup": POOL, "start": {"s": 25.0, "x": -2.2, "dir": 1}, "end_s": 95.0,
		 "target": {"name": "Flat Down Ledge"},
		 "metric": "dist", "medals": [5.0, 8.0, 10.0],
		 "goal": "Pool C: innen (zum Seil hin) auf den Rand und auf die Flat Down Ledge – erst flach, dann abwärts. Gemessen: Meter auf der Ledge.",
		 "keys": "← / →  lenken     Leertaste  Absprung",
		 "keys_mobile": "Neigen  lenken     SPRUNG  Absprung",
		 "tip": "Die innere Seite liegt nah am Seil – das Seil zieht kaum quer, dafür ist die Spur schmal."},
	]},
	# Rail to Rail: vom Slider seitlich auf den Nachbar-Slider springen (auf dem Slider Sprung laden, dabei
	# ←/→ = Seite). "chain" = so viele Slider hintereinander, jeder per Transfer vom vorigen; gemessen auf dem letzten.
	{"id": "r2r", "name": "Rail to Rail", "text": "Auf dem Slider seitlich auf den Nachbarn hinüberspringen.", "tasks": [
		{"id": "pipe2", "name": "Pipe to Pipe", "title": "Pipe to Pipe",
		 "kind": "r2r", "chain": 2, "setup": RAIL, "start": {"s": 30.0, "x": 7.0, "dir": 1}, "end_s": 85.0,
		 "metric": "dist", "medals": [5.0, 9.0, 12.0],
		 "goal": "Rechts stehen zwei Pipes nebeneinander (0,8 m Lücke). Über die Auffahrt auf die äußere, kurze Pipe, dann seitlich auf die innere, lange Pipe hinüberspringen. Gemessen: gerutschte Meter auf der zweiten Pipe – je früher der Transfer, desto mehr.",
		 "keys": "Auf der Pipe Leertaste halten, dabei ← (Seite), Leertaste loslassen = Hop",
		 "keys_mobile": "Auf der Pipe SPRUNG halten, dabei ← (Seite), SPRUNG loslassen = Hop",
		 "tip": "Schon auf der Auffahrt laden, auf der Pipe ← dazu und loslassen. Die Hop-Hilfe zielt auf die Mitte der Nachbar-Pipe. In der Luft dreht ←/→ erst wieder, wenn du es einmal losgelassen hast."},
		{"id": "pipe3", "name": "Pipe to Pipe to Pipe", "title": "Pipe to Pipe to Pipe",
		 "kind": "r2r", "chain": 3, "setup": RAIL, "start": {"s": 30.0, "x": -8.0, "dir": 1}, "end_s": 90.0,
		 "metric": "dist", "medals": [4.0, 8.0, 11.0],
		 "goal": "Links stehen drei Pipes versetzt nebeneinander wie eine Treppe zur Seilmitte. Auf die erste, dann zweimal hinüber: Pipe 1 → Pipe 2 → Pipe 3. Gemessen: gerutschte Meter auf der dritten Pipe.",
		 "keys": "Auf der Pipe Leertaste halten, dabei → (Seite), Leertaste loslassen = Hop – auf Pipe 2 gleich nochmal",
		 "keys_mobile": "Auf der Pipe SPRUNG halten, dabei → (Seite), SPRUNG loslassen = Hop – auf Pipe 2 gleich nochmal",
		 "tip": "Pipe 2 ist kurz: sofort nach der Landung wieder laden. Ein kurzer Druck reicht für den Hop – voll aufladen muss man nicht."},
	]},
]
# i18n-end

const SECTION := "medaillen"


static func mode_index(id: String) -> int:
	for i in MODES.size():
		if MODES[i]["id"] == id:
			return i
	return 0


static func tasks(mode_id: String) -> Array:
	return MODES[mode_index(mode_id)].get("tasks", [])


## Medaille für einen Messwert: 0 keine, 1 Bronze, 2 Silber, 3 Gold. Es zählt der angezeigte
## (gerundete) Wert – wer „5,0 m“ sieht, hat die 5 m geschafft.
static func medal_for(task: Dictionary, value: float) -> int:
	var th: Array = task["medals"]
	var lower: bool = task.get("lower", false)
	value = shown(task, value)
	var m := 0
	for i in 3:
		if (value <= float(th[i])) if lower else (value >= float(th[i])):
			m = i + 1
	return m


## Messwert so gerundet, wie format_value ihn zeigt – mit diesem Wert wird gewertet (Medaille, Bestwert, Rangliste).
static func shown(task: Dictionary, value: float) -> float:
	match task["metric"]:
		"height", "width", "dist", "dist_5050", "dist_bs", "sink", "share", "press_share":
			return snappedf(value, 0.01)
		"press", "time", "speed":
			return snappedf(value, 0.1)
	return roundf(value)


## Messwert lesbar, z. B. "2,4 m", "35 %", "3 Wechsel".
static func format_value(task: Dictionary, value: float) -> String:
	match task["metric"]:
		"sink":
			return Loc.t("%d %% eingesunken") % roundi(value * 100.0)
		"height", "width", "dist", "dist_5050", "dist_bs":
			return Loc.dec("%.2f m" % value)   # cm-genau: so wird auch gewertet
		"press", "time":
			return Loc.dec("%.1f s" % value)
		"speed":
			return Loc.dec("%.1f km/h" % value)
		"press_share":
			return Loc.t("%d %% im Press") % roundi(value * 100.0)
		"switches":
			return Loc.tn("%d Wechsel", "%d Wechsel", roundi(value)) % roundi(value)
		"count":
			return Loc.tn("%d Slider", "%d Slider", roundi(value)) % roundi(value)
		"spins":
			return Loc.tn("%d Umdrehung", "%d Umdrehungen", roundi(value)) % roundi(value)
		"share":
			return Loc.t("%d %% im Drift") % roundi(value * 100.0)
		"spin":
			return "%d°" % roundi(value)
		"points":
			return Loc.tn("%d Punkt", "%d Punkte", roundi(value)) % roundi(value)
	return str(value)


## Schwelle als Text, z. B. "ab 2,8 m" bzw. "bis 10 %" (Sonderzeichen fehlen in der Web-Schrift).
static func format_threshold(task: Dictionary, i: int) -> String:
	var v: float = float(task["medals"][i])
	var lower: bool = task.get("lower", false)
	if task["metric"] == "sink":
		return Loc.t("bis %d %%") % roundi(v * 100.0) if v > 0.0 else Loc.t("nicht einsinken")
	var t := format_value(task, v)
	return (Loc.t("bis %s") if lower else Loc.t("ab %s")) % t


## Schlüssel der Bestleistung in [medaillen]. Mit "lb" in der Aufgabe (Rangliste neu, z. B. nach geänderter
## Physik) beginnen auch die eigenen Bestwerte neu: "MODUS.ID@lbN".
static func _key(mode_id: String, task_id: String) -> String:
	var key := mode_id + "." + task_id
	for t: Dictionary in tasks(mode_id):
		if t["id"] == task_id and t.has("lb"):
			return key + "@lb%d" % int(t["lb"])
	return key


## Gespeicherte Bestleistung: [Medaille, Bestwert] (Bestwert NAN = noch kein Versuch gewertet).
static func best(mode_id: String, task_id: String) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.FILE) != OK:
		return [0, NAN]
	var v: Variant = cfg.get_value(SECTION, _key(mode_id, task_id), [0, NAN])
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
	cfg.set_value(SECTION, _key(mode_id, task["id"]), [maxi(int(old[0]), medal_for(task, value)), value])
	cfg.save(GameSettings.FILE)
	return true

