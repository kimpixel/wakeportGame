# Wakeport 2-Mast

Ein kleines 3D-Wakeboard-Spiel in **Godot 4.7**: Wakeboarden an einer **2-Mast-Seilbahn** auf einem See, wie man sie in Europa oft findet. Es geht also nicht ums Fahren hinter einem Boot.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf)

## Die Anlage

Nachgebaut ist der **Wakeport am Raunheimer Waldsee** (Hessen). Gespielt wird auf **T2**. Auf T1 daneben fährt ein NPC (blaue Weste) mit Sprüngen und 180ern.

- Der Startmast steht am Strand, der Endmast etwa 198 m weiter draußen im See. Beide Positionen sind echte Koordinaten.
- Ein Stahlseil ist als Schlaufe um zwei Rollen (Ø 30 cm) oben an den A-förmigen Gittermasten gespannt.
- Ein **Carrier** sitzt fest auf einem der beiden Stränge. Der Motor kehrt an jedem Ende die Richtung um, so wird der Fahrer hin und her gezogen.
- Gelände, Ufer, Wald und Luftbild stammen aus den offenen Geodaten Hessens. Den Strandbereich mit den Hütten habe ich nach Fotos nachgebaut.

## Hindernisse

Die echten Feature-Setups von T1 und T2 stehen modular in [setups/](setups/README.md): ein Bauteile-Katalog und pro Terminal eine Setup-Datei, in der jede Zeile ein Teil aufstellt. Zum Umbauen musst du nur die JSON-Dateien ändern.

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
| P | – | Autopilot (fährt auch Features) |
| M | – | Ton aus/an |

**Tipp für die Wende:** Wenn der Carrier am Ende bremst, wird das Seil locker. Mit **S** driften und mit **A/D** herumdrehen. Danach zieht die Anlage dich in die neue Richtung.

## Im Browser spielen

**▶ https://kimpixel.github.io/wakeportGame/**

Funktioniert am besten in Chrome, Edge oder Firefox am PC. Einmal ins Bild klicken, damit Tastatur und Maus reagieren.

## Lokal starten

1. [Godot 4.7](https://godotengine.org/download) herunterladen.
2. Im Projektmanager diesen Ordner importieren (`project.godot`).
3. Mit **F5** starten.

## Geodaten

Grundlage sind die **offenen Geobasisdaten Hessen** der Hessischen Verwaltung für Bodenmanagement und Geoinformation (HVBG):
- **DGM1:** Geländemodell mit 1 m Raster
- **DOM1:** Oberflächenmodell; die Differenz zum Geländemodell ergibt die Baumhöhen
- **DOP20:** Luftbilder

Die aufbereiteten Daten liegen in `assets/geo/`. Neu laden kannst du sie mit:

```
cd tools
node fetch_geodata.mjs
```

## Projektaufbau

| Datei | Inhalt |
|---|---|
| `scripts/rider.gd` | Fahrerphysik und Steuerung. Die Werte zum Feintuning stehen oben in der Datei |
| `scripts/cable_system.gd` | Masten, Rollen, Seilschlaufe und Abläufe des Carriers (Wende, Anfahren) |
| `scripts/water.gd`, `shaders/water.gdshader` | Wasser: Grundwellen und Heckwelle. Physik und Grafik nutzen dieselbe Höhenfunktion |
| `scripts/chase_camera.gd` | 3rd-Person-Kamera |
| `scripts/lake.gd` | Maße der Anlage T2 (Masten, Startsteg, Kicker) |
| `scripts/geo.gd` | Lädt die Geodaten und rechnet zwischen echten Koordinaten und Spielkoordinaten um |
| `scripts/terrain.gd`, `shaders/terrain.gdshader` | Gelände mit Luftbild und Wald |
| `scripts/beach.gd` | Strandbereich (Hütten, Stege, Hauptgebäude, Palmen …) |
| `tools/fetch_geodata.mjs` | Lädt und bereitet die Geodaten auf |
| `scripts/main.gd` | Szenenaufbau, Eingabe, HUD-Anbindung |

Testlauf ohne Fenster:

```
godot --headless --path . --fixed-fps 120 -- --autotest --quit=120
```

## Lizenz

[MIT](LICENSE) – du darfst den Code frei verwenden, verändern und weitergeben, solange der Lizenzhinweis erhalten bleibt.
