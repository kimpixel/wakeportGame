# Wakeport 2-Mast

Ein kleines 3D-Wakeboard-Spiel in **Godot 4.7**: Wakeboarden an einer **2-Mast-Seilbahn** auf einem See, wie man sie in Europa oft findet. Es geht also nicht ums Fahren hinter einem Boot.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf)

## Die Anlage

Nachgebaut ist der **Wakeport am Raunheimer Waldsee** (Hessen). **Vor dem Start wählst du oben rechts, an welcher Anlage du fährst: T2 oder T1** (oder mit T). An der anderen fährt ein NPC (blaue Weste) mit Sprüngen und 180ern. An beiden Startstegen steht ein Steuermann mit der gelben Fernsteuerung; der Jubel kommt immer aus dem Startblock deiner Anlage.

- Der Startmast steht am Strand (echte Koordinaten), der Endmast rund 233 m weiter draußen im See (T1: 240 m). Die Endmasten stehen 35 m weiter draußen als in den Geodaten, damit zwischen Features und Wendebojen genug Platz ist (`Lake.END_EXTEND`).
- Ein Stahlseil ist als Schlaufe um zwei Rollen (Ø 30 cm) oben an den A-förmigen Gittermasten gespannt.
- Ein **Carrier** sitzt fest auf einem der beiden Stränge. Der Motor kehrt an jedem Ende die Richtung um, so wird der Fahrer hin und her gezogen.
- Gelände, Ufer, Wald und Luftbild stammen aus den offenen Geodaten Hessens. Den Strandbereich mit den Hütten habe ich nach Fotos nachgebaut.

## Hindernisse

Die echten Feature-Setups von T1 und T2 stehen modular in [setups/](setups/README.md): ein Bauteile-Katalog mit den echten Modulen (Pipe-Hälften mit an-/absteckbaren Auffahrten, Port Plaza aus Plaza Kicker und Plaza Rail, Spine Kicker aus zwei Kicker M) und mehrere Setups, je eine Datei für beide Terminals. **Vor dem Start wählst du oben rechts, welches Setup du fährst** (oder mit F). Aktuell ist „2026 September“, dazu sechs ältere Setups, deren Datum noch als Platzhalter drinsteht.

Über den weißen Schwimmsteg, den Holzsteg und die Wendebojen fährt man einfach drüber: Die Boje wird unter Wasser gedrückt, der Fahrer macht ein kleines „Ups“. Der blaue Gummiball (in manchen Setups) dagegen muss übersprungen werden.

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
| R | Back | zurück zum Startsteg (kostet 5:00 Spielzeit) |
| W halten | – | nach Sturz oder Seilverlust: zur Handle schwimmen (Bauchlage, Brett hinten oben) |
| Leertaste | A | nach Sturz oder Seilverlust: sofort weiterfahren, direkt unter dem Seil (kostet 3:00 Spielzeit) |
| + / − | Steuerkreuz ↑/↓ | Tempo der Anlage (16–40 km/h) |
| C | Y | Kamera: Verfolger, Orbit oder Ufer |
| T | – | Terminal T1/T2 (vor dem Start) |
| F | – | Feature-Setup (vor dem Start) |
| Tab | – | zurück zum Startscreen (mit ihm beginnt das Spiel): oben die Bahn live, isometrisch von der Seeseite (Start rechts, Features/Hacks anklicken, Doppelklick zoomt), unten das Feature in 3D (ziehen = drehen). Dort: T Terminal, F Feature-Setup, ←/→ Feature, Enter Start |
| Maus / Mausrad | rechter Stick | Umsehen / Zoom |
| P | – | Autopilot (fährt auch Features) |
| M | – | Ton aus/an |

**Auf dem Handy/Tablet** (im Browser, wird automatisch erkannt):

| Geste | Funktion |
|---|---|
| Tippen | Anlage starten |
| Handy nach links/rechts neigen | lenken (volle Neigung bei etwa 25°, hoch- und querformatig) |
| Finger halten + loslassen | Absprung |

Auf dem iPhone fragt Safari beim ersten Tippen nach der Erlaubnis für Bewegungs- und Ausrichtungssensoren. Ohne sie kann man nicht lenken.

**Wende:** An jedem Wendepunkt liegen drei Bojen:
- **Rote Boje** mittig unter dem Seil: hier rauskanten.
- **Zwei weiße Bojen** links und rechts: um eine davon fährst du herum.

Solange der Carrier noch nicht zurückzieht, schwingst du quer zum Seil um ihn herum und drehst erst dann in die neue Richtung. Das Brett trägt nur mit **Seilzug oder viel Tempo**. Hängt das Seil durch (z. B. in der Wende, wenn der Carrier bremst) und wird man langsamer, sinkt man ein – der Seilzug-Anzeiger oben zeigt es. Ist man ganz eingesunken, ist man **abgesoffen**: Man liegt im Wasser wie beim Wasserstart und steht erst wieder auf, wenn das Seil zieht. Eine gute Wende hält das Seil gespannt: früh seitlich ausschwingen und um den Carrier herumpendeln. Nur wer die Wende schafft, ohne abzusaufen, bekommt **Punkte** (15, um die weiße Boje 30). Der Operator jubelt nur bei großen Tricks ab 300 Punkten.

## Im Browser spielen

**▶ https://kimpixel.github.io/wakeportGame/**

Funktioniert am besten in Chrome, Edge oder Firefox am PC. Einmal ins Bild klicken, damit Tastatur und Maus reagieren.

## Figuren

Fahrer, NPC, Steuermann und Gäste sind realistische Menschen aus **MakeHuman** (MPFB für Blender, alle Assets CC0). Erzeugt werden sie per Skript:

```
blender -b --python tools/character/build_character.py -- rider assets/characters/rider.glb
```

Presets: `rider`, `operator`, `guest_f`, `guest_m`.

Die Haltung wird im Spiel live aus der Physik berechnet, mit einer eigenen IK in `scripts/human_rig.gd`: Füße in den Bindungen, Hände am Griff, Oberkörper gegen den Seilzug. Die Arme sind nie überstreckt: Liegt der Griff zu weit weg, holen die Hände ihn heran.

**Einflugschneise:** Der Wakeport liegt direkt im Landeanflug auf Frankfurt (Betriebsrichtung 07). Alle ein, zwei Minuten kommt ein Jet aus Westsüdwest über den Strand, überfliegt den See im 3°-Gleitpfad in rund 260 m Höhe (Fahrwerk draußen, Lichter an) – Mittelstrecke, Langstrecke oder Jumbo – und ist entsprechend laut (mit Dopplereffekt).

**Wetter, Jahreszeit und Uhrzeit** stellst du im Startscreen ein (Wetter, Datum, Uhrzeit). Die Sonne steht dabei wie in echt am Raunheimer Waldsee (50,01° N, 8,48° E, deutsche Zeit mit Sommerzeit): Mittagssonne im Süden, im Sommer lange Abende, im Winter tief stehende Sonne, nachts Mondlicht und Sterne. Wetter: Sonnig, Heiter, Bewölkt, Bedeckt, Regen, Dunst. **Jetzt** übernimmt das heutige Datum und die Uhrzeit (läuft dann mit) und holt das aktuelle Wetter am See von open-meteo.com. Die Wahl wird gespeichert.

**Spielregeln:** Eine Runde dauert **7:30** (Uhr oben links), sie beginnt mit dem Start vom Steg. Es zählen die Punkte in dieser Zeit. Danach bringt dich der Operator nur noch zum Start, dann kommt der Startscreen mit deinem Ergebnis. **Punkte:** Slides zählen am meisten: 150 Grundpunkte, dazu 150 pro Sekunde und 100 für den Boardslide. Auf Rail und Pipe gibt es das 1,5-fache, auf dem Transition Rail das 1,3-fache. Airs und Drehungen bringen weniger, 50 pro Sekunde Flugzeit und 50 pro 180°. **Kombinationen** zählen am meisten: Wer innerhalb von 3 s Fahrt den nächsten Trick macht, z. B. 180 auf das Rail, Boardslide, 180 raus, bekommt für den 2. Trick das Doppelte, für den 3. das Dreifache usw. Ein Sturz oder Absaufen beendet die Kombination. Wer stürzt, muss zur Handle schwimmen und verliert Zeit, je weiter weg vom Seil desto mehr. Große Sprünge sind also ein Risiko. Abkürzungen kosten Strafzeit: Leertaste nach einem Sturz −3:00 (dafür bist du sofort direkt unter dem Seil und fährst weiter), R zurück zum Steg −5:00. Der Wasserstart geht immer Richtung des weiter entfernten Wendepunkts.

**Sturz und Bergung wie an der echten 2-Mast-Anlage – niemand muss zurück zum Start:** Wer zu viel Zug bekommt, verliert die Handle (kein Sturz), gleitet aus und sinkt ins Wasser. Nach einem Sturz oder Seilverlust fährt der Operator den Carrier so, dass die Handle auf deiner Höhe neben der Seillinie liegt. Dann schwimmst du in Bauchlage hin (W halten), greifst die Handle und es geht mit einem Deep-Water-Start weiter: liegen bleiben, bis das Seil spannt, dann langsam aufstehen. Mit der Leertaste (am Handy Tippen) geht es sofort weiter, Richtung des weiter entfernten Wendepunkts. NPC und Autopilot machen das selbst. Nur wer an Land oder im Steg landet, startet am Steg neu (oder mit R).

Beim Sturz wird die Figur zur **Ragdoll** (`scripts/ragdoll.gd`): Physik-Knochen mit Gelenkgrenzen, Wasserdämpfung und Auftrieb an der Oberfläche. Die Weste dreht den Fahrer auf den Rücken, das Brett bleibt an den Füßen. Am Griff bilden die Hände eine Faust um die Stange (Finger darüber, Daumen darunter).

## Brett und Bindungen

Das Twin-Tip-Board (`scripts/wakeboard.gd`) hat einen nach einem echten Cable-Board gemessenen Umriss, durchgehenden Rocker und dünnere Kanten. Die Grafik kommt aus `shaders/wakeboard.gdshader`: oben schwarz mit Zeitungscollage, unten creme mit großem S. Die Bindungen sind hohe Schuhe mit Riemen, Camo-Feld und weißer Sohle, erzeugt per Skript:

```
blender -b --factory-startup --python tools/board/build_boot.py -- assets/board/boot.glb
```

**Foto-Texturen:** Ober- und Unterseite (`assets/board/top.png`, `bottom.png`) sind aus einem Produktfoto ausgeschnitten. Ansicht 0 ist oben, 1 ist unten. Fehlen die Dateien, zeichnet der Shader ein eigenes Design.

```
godot --headless --path . --script tools/board/make_texture.gd -- foto.png 1 assets/board/bottom.png
```

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

**Ausgenommen:** `assets/board/top.png` und `assets/board/bottom.png` zeigen ein Board von Slingshot. Foto, Grafik und Logo © Slingshot. Sie stehen nicht unter der MIT-Lizenz und dürfen nicht weiterverwendet werden.
