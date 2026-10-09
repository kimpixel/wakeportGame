# Feature-Setups (Hindernisse)

Die Hindernisse sind **modular**, genau wie die echten Module am Wakeport. Es gibt drei Ebenen:

1. **`parts.json` – der Bauteile-Katalog:** Hier wird jedes Teil einmal mit seinen Maßen definiert (z. B. `kicker_l`, `pipe_half`, `transition_rail`).
2. **`setup_*.json` – ein Feature-Setup:** Für beide Terminals (`T1`, `T2`) je eine Liste. Jede Zeile stellt ein Bauteil aus dem Katalog an einer Position auf.
3. **`index.json` – die Liste der Setups** für das Auswahlmenü im Spiel (oben = Standard). Unbekannte Monate oder Jahre stehen als Platzhalter `?` drin.

Die Dateien `training_*.json` gehören zu den Spielmodi (Training) und stehen nicht im Menü: `training_leer.json` (Wenden, Raley), `training_kicker.json` (Kicker M und L nebeneinander), `training_slider.json` (Slider-Park mit 100 m Long Rail).

Das Setup wählst du auf der Startseite aus. Für ein neues Setup legst du eine `setup_*.json` an und trägst sie in `index.json` ein. Am Code ändert sich nichts.

Bequemer geht es mit dem **Setup-Editor** im Spiel (Startseite): Er speichert eigene Setups auf dem Gerät (`user://setups/`). Mit „Als JSON kopieren“ bekommst du genau dieses Dateiformat – als `setup_*.json` hier ablegen und in `index.json` eintragen, dann ist es fest im Spiel.

## Modulare Teile

| Modul | Aufbau |
|---|---|
| **Pipe** | `pipe_half` = halbe Pipe (6,5 m Rohr). Die Auffahrten vorne (`ramp_in`) und hinten (`ramp_out`) steckst du einzeln an (2,2) oder ab (0). `s` meint immer die Rohrmitte. `pipe_long` = zwei Hälften ohne Auffahrten in der Mitte; `ramp_in`/`ramp_out` der Zeile gelten für die Enden. |
| **Port Plaza** | `port_plaza` = `plaza_kicker` + `plaza_rail` (das Rail beginnt oben auf dem Kicker). Beide Teile gibt es auch einzeln; die Plaza Rail hat dann eine eigene kleine Auffahrt. |
| **Spine Kicker** | `spine_kicker` = zwei `kicker_m` Rücken an Rücken. Einzeln stellst du sie als `kicker_m` auf. |
| **1/2 Transition Rail** | `transition_rail_half` (11 m, eine Auffahrt). Für zwei gespiegelt nebeneinander legst du mit `inner_v` (+1/−1) fest, auf welcher Seite die Transition liegt. |
| **Pyramid Series** | Gruppe mit `mirror`: Das A-Frame Rail steht immer außen (weg vom Seil), egal auf welcher Seite. |
| **Transition Curb** | `transition_curb` (7,3 × 3 m): kurze Auffahrt (0,85 m), dann eine konkave Transition von 0,35 auf 1,1 m (`body_curve`), hinten senkrecht. Oft kombiniert mit einem `cheese_wedge` direkt am hohen Ende als Abfahrt (Wedge-Mitte 5,65 m hinter der Curb-Mitte, gleiche Spur, Gegenrichtung `dir`). Einzeln ist das hohe Ende eine Kante zum Abspringen. |
| **Down Ledge (Rooftop)** | `down_ledge`: lange, schmale Ledge mit Längsprofil (`profile`), 20 m lang: kleine flache Safety vorne auf 0,5 m, steiler hoch auf 1,9 m (Spitze bei 5,5 m), lang abfallend auf 0,8 m, hinten steile Safety bis ins Wasser. |
| **Ollie Box** | `ollie_box` (8,2 × 2,25 m) und `ollie_box_half`, an beiden Enden kurze Auffahrten; daneben meist die `ollie_ledge` (0,7 m breit, Endstücke als Auffahrt). Maße nach „Feature Setup Terminal 1.png“. |
| **Ball** | `ball`: blauer Gummiball, 1 m Durchmesser, treibt hoch auf dem Wasser. Nur mit einem Sprung zu überwinden – wer dagegen fährt oder darauf landet, stürzt. |

Die Pläne zeigen vor allem die **Positionen**; Größen und Abstände sind dort nicht maßstäblich. Die Maße der Teile kommen deshalb aus dem Katalog.

## Eine Setup-Zeile

```json
{ "part": "kicker_l", "s": 62.0, "x": 9.8, "dir": "out", "yaw": -5 }
```

| Feld | Bedeutung |
|---|---|
| `part` | Name des Bauteils aus `parts.json` |
| `s` | Abstand vom Startmast entlang des Seils in Metern, gemessen zur Mitte des Teils. Das Seil von T2 ist ca. 233 m lang. Im Spiel stehen alle Teile 10 m weiter draußen als hier angegeben (`FEATURE_SHIFT` in main.gd), dazu je Anlage ein Mittenausgleich (`CENTER_SHIFT`: Terminal 1 10,5 m, Terminal 2 12,5 m), damit vor und hinter den Features im Schnitt gleich viel Platz bis zu den roten Bojen ist. Gefahren wird etwa zwischen 30 m und 210 m |
| `x` | Seitlicher Abstand zum Seil in Metern: + rechts, − links, jeweils mit Blick vom Startsteg zum Endmast |
| `dir` | `out` = befahrbar Richtung Endmast, `in` = Richtung Startsteg |
| `yaw` | Zusätzliche Drehung in Grad (optional) |
| `inner_v` | Nur Transition: Seite der Transition erzwingen (+1/−1), sonst zeigt sie zum Seil |

Einzelne Maße kannst du pro Zeile überschreiben, ohne den Katalog zu ändern, z. B. `"height": 1.2` oder `"length": 12`.

## Bauteil-Typen im Katalog

| Typ | Form | Werte |
|---|---|---|
| `ramp` | Kicker oder Wedge: steigt aus dem Wasser an, hinten eine senkrechte Kante | `length`, `width`, `height`, `curve` (1 = gerade, > 1 = geschwungen) |
| `block` | Box, Ledge, Pyramid, Curb | `length`, `width`, `height`, `height_end` (Down Ledge), `ramp_in` / `ramp_out` (Auffahrten, 0 = senkrechte Kante) |
| `rail` | Rail/Rohr auf Stützen | `length`, `height`, `ramp_in` / `ramp_out` (Transitions), `radius`, `color` (`grey` / `black`) |
| `pipe` | Liegendes Rohr | `length`, `radius`, `center_y`, `ramp_in` / `ramp_out` |
| `bump` | Kleine Pyramide | `length`, `width`, `height`, `top` (Breite der Spitze) |
| `transition` | Transition Rail: auf der Seilseite eine geschwungene Transition, oben ein schwarzes Rail, hinten eine senkrechte Wand | `length`, `width`, `height`, `ramp_in` / `ramp_out` (schräge Auffahrten an den Enden) |
| `group` | Mehrere Teile als ein Feature, z. B. die Pyramid Series (A-Frame Rail + Pyramid) | `parts`: Liste mit `part`, `s`, `x` (relativ zur Gruppe) |

Bei `block`, `rail` und `pipe` legt `ramp_curve` die Form der Auffahrten fest: `1` = gerade (A-Frame), `2` = konkav (Transition). Mit `color` (`grey`) färbst du ein Teil grau.

Mit `side_ramp` (Meter) bekommt ein `block` auf der Seilseite eine geschwungene seitliche Auffahrt. Dort kann man von der Seite hochfahren, ohne zu stürzen; ohne `side_ramp` ist die Seite eine senkrechte Wand. Die Pyramid der Pyramid Series hat 2 m. Das Transition Rail hat diese Seite immer.

Mit `slick` wird eine Fläche zu glattem Plastik: Dort gibt es keinen Slide (keine Punkte), man rutscht in der bisherigen Richtung weiter und kann nicht lenken. `"all"` = ganze Oberseite (Pyramid, Transition Curb, Ollie Box)  –  aber nie die Auffahrten (`ramp_in`/`ramp_out`, die „Safety“): die fährt man wie einen Kicker, ohne Slide, `"transition"` = die Transition, aber nicht das Rail (Transition Rail), `"top"` = nur die flache Spitze (Bump; seine Seiten fährt man wie Kicker).

Physik und Grafik nutzen dieselbe Form. Was du hier einträgst, ist also genau so befahrbar, wie es aussieht.

## Fahrverhalten an den Features

- **Mit Auffahrt** (Kicker, Wedge, Pyramid, Curb, Transitions, Pipe-Rampe) fährst du direkt aus dem Wasser hoch.
- **Ohne Auffahrt** (Ollie Box, Ledges) musst du vorher mit der Leertaste abspringen. Fährst du seitlich oder von hinten dagegen, stürzt du.
- **Auf dem Feature** rutscht das Brett. Mit A/D drehst du es quer für einen Boardslide.
- **Punkte für Slides** gibt es beim Verlassen des Features: „50-50“ längs, „Boardslide“ quer.

## Autopilot und NPC

Der Autopilot (P) und der NPC auf T1 fahren Features selbstständig an. Dafür muss jeweils gelten:
- **Auffahrt:** Das Teil hat eine Auffahrt, oder es ist maximal 1 m hoch und mindestens 0,8 m breit (dann springen sie ab).
- **Freie Spur:** Bis zum Einstieg liegt kein anderes Teil im Weg.
- **Kein höheres Teil daneben:** Auf der Seilseite steht kein höheres Teil, gegen das der Seilzug sie beim Rutschen ziehen würde.

## Testen

Mit diesem Befehl fährt der Autopilot auf einer festen Spur, hier 6 m rechts vom Seil, direkt über die Features:

```
godot --headless --path . --fixed-fps 120 -- --autotest --setup=a --lane=6 --quit=100
```

Im Log siehst du dann `TRICK:`- und `CRASH:`-Zeilen.
