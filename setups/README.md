# Feature-Setups (Hindernisse)

Die Hindernisse sind **modular**. Es gibt zwei Ebenen:

1. **`parts.json` – der Bauteile-Katalog:** Hier wird jedes Teil einmal mit seinen Maßen definiert (z. B. `kicker_l`, `pipe`, `transition_rail`).
2. **`terminal1.json` / `terminal2.json` – das Setup einer Anlage:** Jede Zeile stellt ein Bauteil aus dem Katalog an einer Position auf.

Das Spiel liest beide Ebenen beim Start. Für ein neues Setup musst du nur die JSON-Dateien ändern, nicht den Code.

## Eine Setup-Zeile

```json
{ "part": "kicker_l", "s": 62.0, "x": 9.8, "dir": "out", "yaw": -5 }
```

| Feld | Bedeutung |
|---|---|
| `part` | Name des Bauteils aus `parts.json` |
| `s` | Abstand vom Startmast entlang des Seils in Metern, gemessen zur Mitte des Teils. Das Seil von T2 ist ca. 198 m lang. Gefahren wird etwa zwischen 30 m und 175 m |
| `x` | Seitlicher Abstand zum Seil in Metern: + rechts, − links, jeweils mit Blick vom Startsteg zum Endmast |
| `dir` | `out` = befahrbar Richtung Endmast, `in` = Richtung Startsteg |
| `yaw` | Zusätzliche Drehung in Grad (optional) |

Einzelne Maße kannst du pro Zeile überschreiben, ohne den Katalog zu ändern, z. B. `"height": 1.2` oder `"length": 12`.

## Bauteil-Typen im Katalog

| Typ | Form | Werte |
|---|---|---|
| `ramp` | Kicker oder Wedge: steigt aus dem Wasser an, hinten eine senkrechte Kante | `length`, `width`, `height`, `curve` (1 = gerade, > 1 = geschwungen) |
| `block` | Box, Ledge, Pyramid, Curb | `length`, `width`, `height`, `height_end` (Down Ledge), `ramp_in` / `ramp_out` (Auffahrten, 0 = senkrechte Kante) |
| `rail` | Rail/Rohr auf Stützen | `length`, `height`, `ramp_in` / `ramp_out` (Transitions), `radius`, `color` (`grey` / `black`) |
| `pipe` | Liegendes Rohr | `length`, `radius`, `center_y`, `ramp_in` / `ramp_out` |
| `bump` | Kleine Pyramide | `length`, `width`, `height`, `top` (Breite der Spitze) |

Physik und Grafik nutzen dieselbe Form. Was du hier einträgst, ist also genau so befahrbar, wie es aussieht.

## Fahrverhalten an den Features

- **Mit Auffahrt** (Kicker, Wedge, Pyramid, Curb, Transitions, Pipe-Rampe) fährst du direkt aus dem Wasser hoch.
- **Ohne Auffahrt** (Ollie Box, Ledges, Add-on Rail) musst du vorher mit der Leertaste abspringen. Fährst du seitlich oder von hinten dagegen, stürzt du.
- **Auf dem Feature** rutscht das Brett. Mit A/D drehst du es quer für einen Boardslide.
- **Punkte für Slides** gibt es beim Verlassen des Features: „50-50“ längs, „Boardslide“ quer.

## Testen

Mit diesem Befehl fährt der Autopilot auf einer festen Spur, hier 6 m rechts vom Seil, direkt über die Features:

```
godot --headless --path . --fixed-fps 120 -- --autotest --lane=6 --quit=100
```

Im Log siehst du dann `TRICK:`- und `CRASH:`-Zeilen.
