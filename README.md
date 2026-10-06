# Wakeport 2-Mast

Ein kleines 3D-Wakeboard-Spiel in **Godot 4.7**: Wakeboarden an einer **2-Mast-Seilbahn** auf einem See, wie man sie in Europa oft findet. Es geht also nicht ums Fahren hinter einem Boot.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf)

## Die Anlage

- **Mast 1** steht am Ufer, **Mast 2** in der Mitte des Sees.
- Ein Stahlseil ist als Schlaufe um zwei Rollen (Ø 30 cm) oben an den Masten gespannt.
- Ein **Carrier** sitzt fest auf einem der beiden Stränge. Der Motor kehrt an jedem Ende die Richtung um, so wird der Fahrer hin und her gezogen.
- Am Carrier hängt das 18 m lange Zugseil des Fahrers.

## Steuerung

Die Fahrphysik ist komplett selbst geschrieben und beruht auf dem Zugseil:
- Das Seil zieht nur, wenn es gespannt ist, und ist etwas elastisch.
- Längs zum Brett bremst das Wasser wenig. Quer dazu hält die Kante dagegen.
- Wenn du schräg zum Seil fährst, schwingst du deshalb nach außen und kannst schneller werden als der Carrier.

| Taste | Gamepad | Funktion |
|---|---|---|
| A / D | linker Stick | Über die Kante lenken (in der Luft: drehen) |
| W | RT | Kante belasten: mehr Grip, weite Bögen, mehr Zug |
| S | LT | Kante lösen = **Driften**: Brett rutscht quer, dreht schneller (gut für die Wende) |
| Leertaste halten + loslassen | A | Absprung |
| Enter | Start | Anlage starten |
| R | Back | Neustart |
| + / − | Steuerkreuz ↑/↓ | Tempo der Anlage (16–40 km/h) |
| C | Y | Kamera: Verfolger, Orbit oder Ufer |
| Maus / Mausrad | rechter Stick | Umsehen / Zoom |
| P | – | Autopilot |

**Tipp für die Wende:** Wenn der Carrier am Ende bremst, wird das Seil locker. Mit **S** driften und mit **A/D** herumdrehen. Danach zieht die Anlage dich in die neue Richtung.

## Im Browser spielen

**▶ https://kimpixel.github.io/wakeportGame/**

Funktioniert am besten in Chrome, Edge oder Firefox am PC. Einmal ins Bild klicken, damit Tastatur und Maus reagieren.

## Lokal starten

1. [Godot 4.7](https://godotengine.org/download) herunterladen.
2. Im Projektmanager diesen Ordner importieren (`project.godot`).
3. Mit **F5** starten.

## Projektaufbau

| Datei | Inhalt |
|---|---|
| `scripts/rider.gd` | Fahrerphysik und Steuerung. Die Werte zum Feintuning stehen oben in der Datei |
| `scripts/cable_system.gd` | Masten, Rollen, Seilschlaufe und Abläufe des Carriers (Wende, Anfahren) |
| `scripts/water.gd`, `shaders/water.gdshader` | Wasser: Grundwellen und Heckwelle. Physik und Grafik nutzen dieselbe Höhenfunktion |
| `scripts/chase_camera.gd` | 3rd-Person-Kamera |
| `scripts/lake.gd` | Alle Maße der Anlage |
| `scripts/main.gd` | Szenenaufbau, Eingabe, HUD-Anbindung |

Testlauf ohne Fenster:

```
godot --headless --path . --fixed-fps 120 -- --autotest --quit=120
```
