# WakeTheHack

**Wake the Hack** ist ein kleines 3D-Wakeboard-Spiel in **Godot 4.7**: Wakeboarden an einer **2-Mast-Seilbahn** auf einem See, wie man sie in Europa oft findet. Es geht also nicht ums Fahren hinter einem Boot.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf)

## Die Anlage

Nachgebaut ist der **Wakeport am Raunheimer Waldsee** (Hessen). **Auf der Startseite wählst du, an welcher Anlage du fährst: T2 oder T1.** An der anderen fährt ein NPC (blaue Weste) mit Sprüngen und 180ern. An beiden Startstegen steht ein Steuermann mit der gelben Fernsteuerung; der Jubel kommt immer aus dem Startblock deiner Anlage.

- Der Startmast steht am Strand (echte Koordinaten), der Endmast rund 233 m weiter draußen im See (T1: 240 m). Die Endmasten stehen 35 m weiter draußen als in den Geodaten, damit zwischen Features und Wendebojen genug Platz ist (`Lake.END_EXTEND`).
- Ein Stahlseil ist als Schlaufe um zwei Rollen (Ø 30 cm) oben an den A-förmigen Gittermasten gespannt.
- Ein **Carrier** sitzt fest auf einem der beiden Stränge. Der Motor kehrt an jedem Ende die Richtung um, so wird der Fahrer hin und her gezogen.
- Gelände, Ufer, Wald und Luftbild stammen aus den offenen Geodaten Hessens. Den Strandbereich mit den Hütten habe ich nach Fotos nachgebaut.

## Hindernisse

Die echten Feature-Setups von T1 und T2 stehen modular in [setups/](setups/README.md): ein Bauteile-Katalog mit den echten Modulen (Pipe-Hälften mit an-/absteckbaren Auffahrten, Port Plaza aus Plaza Kicker und Plaza Rail, Spine Kicker aus zwei Kicker M) und mehrere Setups, je eine Datei für beide Terminals. **Auf der Startseite wählst du, welches Setup du fährst.** Aktuell ist „2026 September“, dazu sechs ältere Setups, deren Datum noch als Platzhalter drinsteht.

**Setup-Editor** (Taste auf der Startseite): eigene Setups für T1 und T2 bauen. Links die Bahn von oben (Raster, Seil, Masten, Wenden, Bojen; umschaltbar auf 3D), rechts die Bauteile, alle Hacks aus den echten Setups, die Eigenschaften der Auswahl mit 3D-Vorschau und das Setup selbst (Vorlage laden, Terminal leeren/kopieren, JSON kopieren/einfügen). Teil antippen = auswählen (doppelt = ganzer Hack, Umschalt/Strg = mehrere), ziehen = verschieben, freie Fläche ziehen = Karte bewegen, Rad bzw. + / − = Zoom. Tasten: Pfeile 0,1 m (Umschalt 1 m), Q/E drehen, F Richtung, M spiegeln, Strg+D duplizieren, Entf löschen, Strg+Z/Strg+Y. Zusammenstehende Teile werden als Hack orange markiert. **Speichern** legt ein eigenes Setup an (im Browser bzw. auf dem Gerät gespeichert), es erscheint dann unter FEATURE-SETUP; **Speichern & Fahren** startet gleich.

Über den weißen Schwimmsteg, den Holzsteg und die Wendebojen fährt man einfach drüber: Die Boje wird unter Wasser gedrückt, der Fahrer macht ein kleines „Ups“. Der blaue Gummiball (in manchen Setups) dagegen muss übersprungen werden.

## Steuerung

Die Fahrphysik ist komplett selbst geschrieben und beruht auf dem Zugseil:
- Das Seil zieht nur, wenn es gespannt ist, und ist etwas elastisch.
- Längs zum Brett bremst das Wasser wenig. Quer dazu hält die Kante dagegen.
- Wenn du schräg zum Seil fährst, schwingst du deshalb nach außen und kannst schneller werden als der Carrier.

| Taste | Gamepad | Funktion |
|---|---|---|
| ← / → (A / D) | linker Stick ↔ | Über die Kante lenken. In der Luft und beim Raley: drehen. **Auf dem Slider:** je Tipp eine Vierteldrehung, Boardslide ↔ 50-50 (rastet ein) |
| ↑ / ↓ (W / S) | linker Stick ↕ | In der Luft: **Frontroll / Backroll**. Halten dreht, loslassen dreht zur nächsten ganzen Umdrehung aus. Schief landen = Sturz. Auf dem Slider: **Nosepress / Tailpress** – schon kurz vor dem Aufkommen über dem Slider gedrückt, gibt es keine Rolle, sondern gleich den Press |
| Strg (zur Not Alt) | LT | **Driften**: Kante gelöst – man rutscht weiter, Lenken ändert die Richtung nicht (nur der Seilzug zieht einen), das Brett lässt sich dabei frei drehen; weniger Wasserwiderstand, also leicht schneller. Nach Sturz: sofort weiterfahren (−1:00) |
| Leertaste halten + loslassen | A | Absprung: langsam ein **Ollie**, über 40 km/h, voll aufgeladen und ohne Feature voraus automatisch ein **Raley** |
| – | Start | Die Anlage startet von selbst nach dem Countdown 3 – 2 – 1 – GO (auch nach R oder einer Bergung am Steg) |
| R | Back | zurück zum Startsteg (kostet 2:00 Spielzeit) |
| Leertaste halten | A | nach Sturz oder Seilverlust: zur Handle schwimmen (Bauchlage, Brett hinten oben). Ein Panel zeigt, was geht und was es kostet |
| + / − | Steuerkreuz ↑/↓ | Tempo der Anlage (16–40 km/h) |
| C | Y | Kamera: Verfolger, Orbit oder Ufer |
| Tab | – | zurück zur Startseite (mit ihr beginnt das Spiel). Im Hintergrund die echte Szene, die Kamera schwenkt langsam von der Seeseite über die gewählte Anlage. Darüber das Menü: Spielmodus, Terminal und Feature-Setup bzw. die Aufgaben, **Einstellungen** (Wetter, Datum, Uhrzeit, Jetzt) und **Spiel starten**. Tasten: Leertaste Start, Esc schließt ein Fenster. Passt sich an Handy (hoch und quer) und Desktop an |
| Maus / Mausrad | rechter Stick | Umsehen / Zoom |
| P | – | Autopilot (fährt auch Features) |
| Esc | Start | **Pause** (Fenster mit Weiter, Hilfe, Startseite); am Handy pausiert das ☰-Menü |
| M | – | Ton aus/an |
| G | – | Seil-Abreißen an/aus (bei „Aus“ wird einem die Handle nie aus der Hand gerissen; auch unter Einstellungen → Spiel → Seilzug-Grenze) |
| F3 | – | Debug: Fangzonen der Slider einblenden (gelb; wer im Sprung hineinkommt, gleitet aufs Rail) glattes Plastik (blau; nur rutschen, kein Slide, kein Lenken) und Safetys/Auffahrten und Kicker (orange; fährt man wie einen Kicker, kein Slide) |

**Auf dem Handy/Tablet** (im Browser, wird automatisch erkannt):

| Geste | Funktion |
|---|---|
| – | Start: Countdown 3 – 2 – 1 – GO, die Anlage fährt von selbst los |
| Handy nach links/rechts neigen | lenken (volle Neigung bei etwa 25°, hoch- und querformatig) |
| SPRUNG (unten links) halten + loslassen | Absprung (schnell: Raley). Tippen auf den Bildschirm springt nicht |
| Bildschirm halten | nach Sturz: zur Handle schwimmen |
| ▲ / ▼ (unten rechts) | in der Luft Frontroll / Backroll, auf dem Slider Nose- / Tailpress |
| DRIFT (rechts, über ▲ ▼) | Kante lösen = Driften; nach Sturz: sofort weiterfahren (−1:00) |
| ☰ (oben links) | Menü: Hilfe, Zurück zum Steg (−2:00), Startseite, Ton, Seil-Abreißen an/aus |

Auf dem iPhone fragt Safari beim ersten Tippen nach der Erlaubnis für Bewegungs- und Ausrichtungssensoren. Ohne sie kann man nicht lenken.

Das Handy vibriert kurz bei Landungen, beim Aufschlagen auf ein Feature, beim Rumpeln über Boje/Steg und stärker bei einem Sturz (je nach Wucht). Das geht im Browser nur auf Android; Safari auf dem iPhone unterstützt keine Vibration.

**Wende:** An jedem Wendepunkt liegen drei Bojen:
- **Rote Boje** mittig unter dem Seil: hier rauskanten.
- **Zwei weiße Bojen** links und rechts: um eine davon fährst du herum.

Solange der Carrier noch nicht zurückzieht, schwingst du quer zum Seil um ihn herum und drehst erst dann in die neue Richtung. Das Brett trägt nur mit **Seilzug oder viel Tempo**. Hängt das Seil durch (z. B. in der Wende, wenn der Carrier bremst) und wird man langsamer, sinkt man ein – der Seilzug-Anzeiger oben zeigt es. Ist man ganz eingesunken, ist man **abgesoffen**: Man liegt im Wasser wie beim Wasserstart und steht erst wieder auf, wenn das Seil zieht. Eine gute Wende hält das Seil gespannt: früh seitlich ausschwingen und um den Carrier herumpendeln. Nur wer die Wende schafft, ohne abzusaufen, bekommt **Punkte** (15, um die weiße Boje 30). Der Operator jubelt nur bei großen Tricks ab 300 Punkten.

**Driften (Technik):** Strg halten (am Handy DRIFT) löst die Kante. Das Brett liegt flach auf dem Wasser und greift nicht mehr: Lenken ändert die Fahrtrichtung nicht, man rutscht weiter, und nur der Seilzug zieht einen (zur Seilmitte). Dafür lässt sich das Brett frei herumdrehen – quer, rückwärts, ganze 360er –, und weil es flach aufliegt, bremst das Wasser weniger: man gleitet weiter. Wozu: mit Schwung durch die Wende gleiten, ohne einzusinken; quer vom Slider abgehen (ohne Drift hakt die Kante ein = Sturz) oder quer landen; Drehungen auf dem Wasser. Loslassen = die Kante greift wieder (steht das Brett dabei quer, bremst es hart).

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

**Wetter, Jahreszeit und Uhrzeit** stellst du auf der Startseite unter Einstellungen ein (Wetter, Datum, Uhrzeit). Die Sonne steht dabei wie in echt am Raunheimer Waldsee (50,01° N, 8,48° E, deutsche Zeit mit Sommerzeit): Mittagssonne im Süden, im Sommer lange Abende, im Winter tief stehende Sonne, nachts Mondlicht und Sterne. Wetter: Sonnig, Heiter, Bewölkt, Bedeckt, Regen, Dunst. **Jetzt** übernimmt das heutige Datum und die Uhrzeit (läuft dann mit) und holt das aktuelle Wetter am See von open-meteo.com. Jeder Spielstart beginnt an einem sonnigen Sommertag um 10:30, damit es nie dunkel ist. Die Wahl gilt nur bis zum Neustart.

**Einstellungen** (Startseite, vier Reiter; alles außer Wetter und Uhrzeit wird gespeichert):
- **Spiel:** Rundenlänge der Competition *Runde 7:30*, *Runde 10:00*, *Runde 15:00* oder *Freies Fahren* (keine Uhr – oben steht „FREI“, kein Zeitende, keine Strafzeit). Hilfen *Auf dem Slider einloggen* und *Überschlag dreht von selbst zu Ende* – jede ausgeschaltete Hilfe gibt +15 % auf alle Tricks. *Seilzug-Grenze* Locker / Normal / Streng / Aus (Handle wird nie aus der Hand gerissen; im Spiel G).
- **Fahrer:** Brett aus der Brett-Bibliothek, Stance *Regular* (links vorne) oder *Goofy* (rechts vorne), Helm und Westenfarbe.
- **Welt:** Wetter, Datum, Uhrzeit, Jetzt; **Seillänge** (12–22 m, Standard 16) und **Anlagen-Tempo** (16–40 km/h, Standard 30) deiner Anlage (+ / − im Spiel ändert das Tempo ebenfalls); Flugzeuge *Aus / Normal / Rush Hour*; Fahrer auf der anderen Anlage an/aus; **Challenge: Filmteam** *Zufall / Boot / Drohne / Aus*.
- **Technik:** Grafik *Niedrig / Mittel / Hoch* (Auflösung, Schatten, Baumdichte; am Handy Standard *Mittel*), Lautstärke für Effekte, Jubel und Flugzeuge, Kamera und Kamera-Abstand, am Handy Neigungs-Empfindlichkeit und Neigung umkehren.

**Spielmodi** (Startseite, ganz oben):
- **Competition:** die Runde auf Zeit (Regeln unten). Terminal, Feature-Setup und Rundenlänge sind frei wählbar.
- **Community Challenge** (kurz **Challenge**): Modi mit Challenges, die von Challenge zu Challenge schwieriger werden. Jede Challenge misst einen Wert und vergibt **Bronze, Silber oder Gold**. Die beste Medaille steht in der Liste. Vor dem ersten Versuch erklärt ein Fenster Ziel, Steuerung, Tipp und die Schwellen. Jeder Versuch setzt dich in voller Fahrt kurz vor die Stelle, auch die Kamera. Nach einem Sturz (oder verpasstem Feature) gibt es kein Bergungs-Fenster, es geht gleich mit dem nächsten Versuch weiter. Nach einem gewerteten Versuch fährt man noch kurz aus, dann: Leertaste = nochmal, N = nächste Challenge, Esc = Startseite; während der Fahrt R = neuer Versuch. Gefahren wird immer auf Terminal 2 mit 30 km/h und 16 m Seil, damit die Werte vergleichbar sind. Gefilmt wirst du dabei (Einstellung *Challenge: Filmteam*, Standard Zufall) entweder vom **roten Kunststoffboot** von T2 – hinten einer am Außenborder, in der Mitte steht eine mit der Kamera; das Boot fährt seeseitig etwas vor dir mit und wartet vor den Wenden – oder von einer **FPV-Drohne**, die vorne-seitlich über dir fliegt; ihr Pilot steht mit FPV-Brille und Funke auf dem Startsteg. Ohne Challenge liegt das Boot am weißen Steg.
  - **Wenden** (3 Challenges): Wende am Endmast, Ufer-Wende, Wende außen um die weiße Boje. Gemessen wird, wie tief man einsinkt. Abgesoffen = kein Wert.
  - **Kicker** (3): Kicker M ohne Absprung, Kicker M mit Absprung, Kicker L mit Absprung. Gemessen wird die größte Höhe über dem Wasser. Kicker M und L stehen nebeneinander wie in Setup B.
  - **Slider** (9) auf einem eigenen Setup: rechts vier Slider hintereinander (Full Pipe, Rail, A-Frame, Pipe), links ein 100 m langes Rail. Challenges: auf die Full Pipe, Boardslide (am Ende gerade stellen), Boardslide mit Drift-Abgang, Umspringen, Nose-/Tailpress, Long Rail, Slider-Kette, **Ollie in Boardslide Nosepress** (Ollie direkt auf die Full Pipe, quer, Nosepress; Meter), **Slider Special** (an jedem Slider der Kette eine feste Kombination: 1. Full Pipe Ollie on – 50-50 Nosepress, 2. Rail Ollie on – Boardslide Tailpress, 3. A-Frame Ollie on – Boardslide Nosepress – 180 out, 4. Pipe Ollie 180 on – 50-50 Tailpress – 360 out; „Ollie on“ = aus dem Wasser direkt auf den Slider springen, nicht über die Auffahrt; Press mehr als die halbe Slide-Zeit; gezählt werden die geschafften Slider).
  - **Driften** (3): 360er im Drift zwischen den roten Bojen (gezählt: volle Umdrehungen des Bretts im Drift), die Wende am Endmast durchgleiten (Anteil der Wende im Drift, ohne einzusinken – vorher Schwung holen), nach einem Feature driften (Terminal 2, Juli & August, von der Mitte Richtung Steg; längster Drift direkt nach einem Feature, ab 10 m Bronze).
  - **Raley** (3) nach der Ufer-Wende: erster Raley (Höhe), Raley mit Drehung (180/360/540), Raley mit Überschlag (Punkte).
  - **Transfer** (4) auf den echten Setups: Klein (Terminal 2, Setup C: von der Pyramid aufs A-Frame Rail), Groß (Terminal 1, Setup A: vom Wedge auf die Down Ledge), Special (Terminal 2, Setup D: Ollie auf die Transition Curb, von dort auf die Down Ledge; Sekunden auf der Ledge), Special Press (dasselbe mit Nosepress auf der Ledge). Gezählt wird nur, wer auf dem Start-Feature fährt, von dort abspringt und aus der Luft aufs Ziel kommt – das Ziel von vorne anzufahren oder aus dem Wasser seitlich draufzuspringen zählt nicht.
- **Jeder Start beginnt mit einem Countdown 3 – 2 – 1 – GO**, angesagt auf Englisch („three, two, one, go“). In der Competition fährt die Anlage bei GO los (auch nach R zurück zum Steg); in den Challenges steht das Spiel bis GO.
- **Geheime Erfolge** (Taste *Erfolge* auf der Startseite): eine Liste mit 10 ausgegrauten Einträgen. Was es gibt, steht erst da, wenn man es geschafft hat – im Spiel kommt dann die Meldung „Geheimer Erfolg freigeschaltet“. Bleibt im Browser bzw. auf dem Gerät gespeichert.

**Spielregeln (Competition):** Eine Runde dauert **7:30** (Uhr oben links), sie beginnt nach dem Countdown mit dem Start vom Steg. Es zählen die Punkte in dieser Zeit. Danach bringt dich der Operator nur noch zum Start, dann kommt die Startseite mit deinem Ergebnis. **Punkte:** Slides zählen am meisten: 150 Grundpunkte, dazu 150 pro Sekunde und 100 für den Boardslide. Wer auf einen Slider kommt, rastet in die nächste Stellung ein: eher längs im **50-50**, eher quer (über 45°, z. B. in der Luft gedreht) im **Boardslide**; mit ←/→ (Handy: deutlich neigen) springt man in 90°-Schritten zwischen Boardslide und 50-50 um – jeder Wechsel bringt 80 extra und zählt im Namen mit (z. B. „Boardslide to 50-50“). Nose- oder Tailpress (mehr als die halbe Slide-Zeit gehalten) bringt 100 extra. **Abgang:** Wer mit quer stehendem Brett vom Slider ins Wasser fährt oder quer landet, stürzt – vorher gerade stellen (Tipp ←/→ zurück auf 50-50, auf der Abfahrt drehen) oder beim Abgang Strg (Drift) halten, dann rutscht das Brett quer weiter. Auf Rail und Pipe gibt es das 1,5-fache, auf dem Transition Rail das 1,3-fache. Airs und Drehungen bringen weniger, 50 pro Sekunde Flugzeit und 50 pro 180°. Ein Raley bringt 150 extra, jeder Frontroll oder Backroll 300. **Kombinationen** zählen am meisten: Wer innerhalb von 3 s Fahrt den nächsten Trick macht, z. B. 180 auf das Rail, Boardslide, 180 raus, bekommt für den 2. Trick das Doppelte, für den 3. das Dreifache usw. Ein Sturz oder Absaufen beendet die Kombination. Wer stürzt, muss zur Handle schwimmen und verliert Zeit, je weiter weg vom Seil desto mehr. Große Sprünge sind also ein Risiko. Abkürzungen kosten Strafzeit: Strg nach einem Sturz −1:00 (dafür bist du sofort direkt unter dem Seil und fährst weiter), R zurück zum Steg −2:00. Der Wasserstart geht immer Richtung des weiter entfernten Wendepunkts.

**Sturz und Bergung wie an der echten 2-Mast-Anlage – niemand muss zurück zum Start:** Wer zu viel Zug bekommt, verliert die Handle (kein Sturz), gleitet aus und sinkt ins Wasser. Nach einem Sturz oder Seilverlust fährt der Operator den Carrier so, dass die Handle auf deiner Höhe neben der Seillinie liegt. Dann schwimmst du in Bauchlage hin (Leertaste halten, am Handy Bildschirm halten), (immer großzügig um die Features herum – wer hinter einem Feature stürzt, schwimmt länger), greifst die Handle und es geht mit einem Deep-Water-Start weiter: liegen bleiben, bis das Seil spannt, dann langsam aufstehen. Mit Strg (am Handy DRIFT) geht es sofort weiter, Richtung des weiter entfernten Wendepunkts. NPC und Autopilot machen das selbst. Nur wer an Land oder im Steg landet, startet am Steg neu (oder mit R).

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
