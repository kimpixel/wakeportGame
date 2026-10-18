# WakeTheHack

**Wake the Hack** ist ein kleines 3D-Wakeboard-Spiel in **Godot 4.7**: Wakeboarden an einer **2-Mast-Seilbahn** auf einem See, wie man sie in Europa oft findet. Es geht also nicht ums Fahren hinter einem Boot.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf) [![Ko-fi](https://img.shields.io/badge/Ko--fi-Kaffee_spendieren-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/kimpixel)

## Die Anlage

Nachgebaut ist der **Wakeport am Raunheimer Waldsee** (Hessen). **Auf der Startseite wählst du, an welcher Anlage du fährst: T2 oder T1.** An der anderen fährt ein NPC (blaue Weste) mit Sprüngen und 180ern. An beiden Startstegen steht ein Steuermann mit der gelben Fernsteuerung; der Jubel kommt immer aus dem Startblock deiner Anlage.

- Der Startmast steht am Strand (echte Koordinaten), der Endmast rund 233 m weiter draußen im See (T1: 240 m). Die Endmasten stehen 35 m weiter draußen als in den Geodaten, damit zwischen Features und Wendebojen genug Platz ist (`Lake.END_EXTEND`).
- Ein Stahlseil ist als Schlaufe um zwei Rollen (Ø 30 cm) oben an den A-förmigen Gittermasten gespannt.
- Ein **Carrier** sitzt fest auf einem der beiden Stränge. Der Motor kehrt an jedem Ende die Richtung um, so wird der Fahrer hin und her gezogen.
- Gelände, Ufer, Wald und Luftbild stammen aus den offenen Geodaten Hessens. Den Strandbereich mit den Hütten habe ich nach Fotos nachgebaut.
- Dichter Mischwald aus Laubbäumen und Kiefern, am Ufer ein geschlossener Waldmantel bis zum Wasser (Kronen mit Blattkarten, in der Ferne vereinfacht). Das Gras am Ufer stammt aus [SimpleGrassTextured](https://github.com/IcterusGames/SimpleGrassTextured) von IcterusGames (MIT, Textur CC0), siehe `assets/grass/`.

## Hindernisse

Die echten Feature-Setups von T1 und T2 stehen modular in [setups/](setups/README.md): ein Bauteile-Katalog mit den echten Modulen (Pipe-Hälften mit an-/absteckbaren Auffahrten, Port Plaza aus Plaza Kicker und Plaza Rail, Spine Kicker aus zwei Kicker M) und mehrere Setups, je eine Datei für beide Terminals. **Auf der Startseite wählst du, welches Setup du fährst.** Aktuell ist „2026 September“, dazu sechs ältere Setups, deren Datum noch als Platzhalter drinsteht.

**Setup-Editor** (Taste auf der Startseite): eigene Setups für T1 und T2 bauen. Links die Bahn von oben (Raster, Seil, Masten, Wenden, Bojen; umschaltbar auf 3D), rechts die Bauteile, alle Hacks aus den echten Setups, die Eigenschaften der Auswahl mit 3D-Vorschau und das Setup selbst (Vorlage laden, Terminal leeren/kopieren, JSON kopieren/einfügen). Teil antippen = auswählen (doppelt = ganzer Hack, Umschalt/Strg = mehrere), ziehen = verschieben, freie Fläche ziehen = Karte bewegen, Rad bzw. + / − = Zoom. Tasten: Pfeile 0,1 m (Umschalt 1 m), Q/E drehen, F Richtung, M spiegeln, Strg+D duplizieren, Entf löschen, Strg+Z/Strg+Y. Zusammenstehende Teile werden als Hack orange markiert. **Speichern** legt ein eigenes Setup an (im Browser bzw. auf dem Gerät gespeichert), es erscheint dann unter FEATURE-SETUP; **Speichern & Fahren** startet gleich.

Im Reiter **Pflanzen** bepflanzt man die Ufer auf dem Luftbild: Pflanze wählen (Schilf, Ufergras, Wiesengras, Strauch, Laubbaum, Kiefer), Pinselgröße und Dichte, dann **Malen**, **Radieren** oder **Automatik** (Stelle wieder dem Spiel überlassen); rechte Maustaste bzw. Werkzeug *Schieben* bewegt die Karte. Das Spiel setzt am Ufer selbst Schilf, Ufergras und Sträucher. Wo man malt oder radiert, gilt nur noch das Gemalte (Bodenpflanzen und Gehölze getrennt). **Pflanzen speichern** baut die Bepflanzung im Spiel sofort neu auf.

Über den weißen Schwimmsteg, den Holzsteg und die Wendebojen fährt man einfach drüber: Die Boje wird unter Wasser gedrückt, der Fahrer macht ein kleines „Ups“. Der blaue Gummiball (in manchen Setups) dagegen muss übersprungen werden.

## Steuerung

Die Fahrphysik ist komplett selbst geschrieben und beruht auf dem Zugseil:
- Das Seil zieht nur, wenn es gespannt ist, und ist etwas elastisch.
- Längs zum Brett bremst das Wasser wenig. Quer dazu hält die Kante dagegen.
- Wenn du schräg zum Seil fährst, schwingst du deshalb nach außen und kannst schneller werden als der Carrier.

Gamepad-Namen wie beim PS4-Controller (Xbox: ✕ = A, ○ = B, △ = Y, Options = Start, Share = Back, PS = Guide). Das Gamepad vibriert bei Landung (je härter, desto stärker), Sturz, Rumpeln und Sprung-Start, brummt leicht auf dem Slider und warnt kurz vor dem Seilabriss; die Lichtleiste (DS4/DualSense) leuchtet in der Farbe der Seilzug-Anzeige (grün – gelb – rot, rot blinkend beim Sturz).

| Taste | Gamepad | Funktion |
|---|---|---|
| ← / → (A / D) | linker Stick ↔, Steuerkreuz ↔ | Über die Kante lenken. In der Luft und beim Raley: drehen. **Auf dem Slider:** je Tipp eine Vierteldrehung, Boardslide ↔ 50-50 (rastet ein) |
| ↑ / ↓ (W / S) | linker Stick ↕, Steuerkreuz ↕ | In der Luft: **Frontroll / Backroll** (nach Ollie, Kicker usw.). Halten dreht, loslassen dreht zur nächsten ganzen Umdrehung aus. Schief landen = Sturz. **Beim Invert** (siehe Leertaste) gleich nach dem Absprung: ↑ = **S-Bend**, ↓ = **Backroll** (Invert-Backroll, seitlich nach außen kopfüber), keine Taste = Raley. Im Drift (Strg): **Drift-Press** (siehe unten). Auf dem Slider: **Nosepress / Tailpress** – schon kurz vor dem Aufkommen über dem Slider gedrückt, gibt es keine Rolle, sondern gleich den Press. Auf dem Startsteg: **Sprung-Start** – ↓ halten (Handy ▼), man stemmt sich gegen das anfahrende Seil, der Seilzug lädt sich bis zur maximalen Seilspannung auf (Anzeige „SPRUNG-START %“); dann reißt das Seil einen nach vorne vom Steg in einen großen Sprung (voller Sprung plus Auflade-Power, +100). Die Brettstellung beim Riss entscheidet: **längs zum Seil (50-50) = Nolli**, **quer (mit ←/→ auf dem Steg um 90° gedreht) = Raley Start** – man sitzt tief auf der Kante, Brust zum Seil, und schwingt wie beim Raley um den Griff (+150 dazu). Je genauer längs bzw. quer, desto mehr Power. Vorher loslassen = normaler Start ohne Sprung |
| Strg (zur Not Alt) | ○ oder L2 | **Driften**: Kante gelöst – man rutscht weiter, Lenken ändert die Richtung nicht (nur der Seilzug zieht einen), das Brett lässt sich dabei frei drehen; weniger Wasserwiderstand, also leicht schneller. Nach Sturz: sofort weiterfahren (−1:00) |
| Leertaste halten + loslassen | ✕, oder R2 (analog: so tief gedrückt, so viel Ladung – durchgedrückt sofort voll) | Absprung: ein **Ollie**; voll aufgeladen mit Seilzug über der Marke **RALEY** (Seilzug-Anzeige) und ohne Feature voraus automatisch ein **Invert** – Höhe aus Seilzug plus Tempo (Raley; mit ↑/↓ S-Bend bzw. Backroll). Erst wenn der Invert fast fertig ist, lässt sich drehen – beim Raley bricht ←/→ nach der Streckung den Schwung ab, man schwingt schnell zurück und dreht aufrecht: Raley 180 = **Blind Judge** (links) / **Krypt** (rechts), Raley 360 = **313** (links) / **BS 313** (rechts) |
| – | – | Die Anlage startet von selbst nach dem Countdown 3 – 2 – 1 – GO (auch nach R oder einer Bergung am Steg) |
| R | Share | zurück zum Startsteg (kostet 2:00 Spielzeit) |
| Leertaste halten | ✕ | nach Sturz oder Seilverlust: zur Handle schwimmen (Bauchlage, Brett hinten oben). Ein Panel zeigt, was geht und was es kostet |
| + / − | R1 / L1 (auf dem Wasser) | Tempo der Anlage (16–40 km/h) |
| – | L1 / R1 (in der Luft) | schnelle halbe Drehung nach links / rechts (mehrmals tippen = 360, 540 …; beim Invert im normalen Drehtempo) |
| C | – | Kamera: Verfolger, Orbit oder Ufer |
| Tab | – | zurück zur Startseite (mit ihr beginnt das Spiel). Im Hintergrund die echte Szene, die Kamera schwenkt langsam von der Seeseite über die gewählte Anlage. Darüber das Menü: Spielmodus, Terminal und Feature-Setup bzw. die Aufgaben, **Einstellungen** (Wetter, Datum, Uhrzeit, Jetzt) und **Spiel starten**. Passt sich an Handy (hoch und quer) und Desktop an |
| Maus / Mausrad | rechter Stick | Umsehen / Zoom. Mit dem Stick: loslassen = Kamera geht gleich wieder hinter den Fahrer; R3 halten + rechter Stick ↕ = Zoom |
| P | – | Autopilot (fährt auch Features) |
| Esc | PS | **Pause** (Fenster mit Weiter, Einstellungen, Hilfe, Startseite); am Handy pausiert das ☰-Menü |
| O | Options | **Einstellungen** direkt über dem pausierten Spiel (danach geht es weiter); auf der Startseite das Einstellungs-Fenster |
| M | – | Ton aus/an |
| G | – | Seil-Abreißen an/aus (bei „Aus“ wird einem die Handle nie aus der Hand gerissen – dann **keine Rangliste**; auch unter Einstellungen → Spiel → Seilzug-Grenze) |
| Tab / Umschalt+Tab, Pfeile | Steuerkreuz, linker Stick | **Menüs** (Startseite, Fenster, Pause, Challenge): Knopf wählen (weißer Rahmen); in einer Auswahlliste die Zeile, auf einem Schieber ←/→ den Wert |
| Leertaste | ✕ | Menüs: gewählten Knopf drücken (Auswahlbox öffnen, Zeile wählen) |
| Enter | PS (oder Touchpad) | Menüs: **Spiel starten** bzw. Los / Nochmal / Weiter |
| – | L1 / R1 | Menüs: Reiter der Einstellungen wechseln |
| Esc | ○ | Menüs: zurück (Liste oder Fenster schließen; in der Challenge zur Startseite) |
| F3 | – | Debug: Fangzonen der Slider einblenden (gelb; wer im Sprung hineinkommt, gleitet aufs Rail) glattes Plastik (blau; nur rutschen, kein Slide, kein Lenken) und Safetys/Auffahrten und Kicker (orange; fährt man wie einen Kicker, kein Slide) |

**Auf dem Handy/Tablet** (im Browser, wird automatisch erkannt):

| Geste | Funktion |
|---|---|
| – | Start: Countdown 3 – 2 – 1 – GO, die Anlage fährt von selbst los |
| ← / → (unten rechts) | lenken (Standard *Lenkung: Tasten*, Steuerkreuz mit Pfeil hoch/runter) |
| Handy nach links/rechts neigen | lenken statt Tasten, mit Einstellung *Lenkung: Gyro* (volle Neigung bei etwa 25°, hoch- und querformatig) |
| SPRUNG (unten links) halten + loslassen | Absprung (schnell: Raley). Tippen auf den Bildschirm springt nicht |
| SCHWIMMEN (statt SPRUNG) oder Bildschirm halten | nach Sturz: zur Handle schwimmen |
| Pfeil hoch / runter (unten rechts) | in der Luft Frontroll / Backroll (Invert: S-Bend / Backroll), auf dem Slider Nose- / Tailpress |
| DRIFT (links, über SPRUNG) | Kante lösen = Driften; nach Sturz heißt die Taste SKIP: sofort weiterfahren (−1:00) |
| ☰ (rechts unter der Anzeige) | Menü: Einstellungen, Hilfe, Zurück zum Steg (−2:00), Startseite, Ton, Seil-Abreißen an/aus (aus: keine Rangliste; Spiel pausiert) |

Auf dem iPhone fragt Safari beim ersten Tippen nach der Erlaubnis für Bewegungs- und Ausrichtungssensoren. Ohne sie lenkt man nur mit *Lenkung: Tasten* (Einstellungen → Technik).

Das Handy vibriert kurz bei Landungen, beim Aufschlagen auf ein Feature, beim Rumpeln über Boje/Steg und stärker bei einem Sturz (je nach Wucht). Das geht im Browser nur auf Android; Safari auf dem iPhone unterstützt keine Vibration.

**Wende:** An jedem Wendepunkt liegen drei Bojen:
- **Rote Boje** mittig unter dem Seil: hier rauskanten.
- **Zwei weiße Bojen** links und rechts: um eine davon fährst du herum.

Solange der Carrier noch nicht zurückzieht, schwingst du quer zum Seil um ihn herum und drehst erst dann in die neue Richtung. Das Brett trägt nur mit **Seilzug oder viel Tempo**. Hängt das Seil durch (z. B. in der Wende, wenn der Carrier bremst) und wird man langsamer, sinkt man ein – der Seilzug-Anzeiger oben zeigt es. Ist man ganz eingesunken, ist man **abgesoffen**: Man liegt im Wasser wie beim Wasserstart und steht erst wieder auf, wenn das Seil zieht. Eine gute Wende hält das Seil gespannt: früh seitlich ausschwingen und um den Carrier herumpendeln. Nur wer die Wende schafft, ohne abzusaufen, bekommt **Punkte** (15, um die weiße Boje 30). Der Operator jubelt nur bei großen Tricks ab 300 Punkten.

**Driften (Technik):** Strg halten (am Handy DRIFT) löst die Kante. Das Brett liegt flach auf dem Wasser und greift nicht mehr: Lenken ändert die Fahrtrichtung nicht, man rutscht weiter, und nur der Seilzug zieht einen (zur Seilmitte). Den Schwung nimmst du mit wie im Kettenkarussell: wer nach außen fährt und dann driftet, schwingt im Bogen weiter nach außen um den Carrier. Dafür lässt sich das Brett frei herumdrehen – quer, rückwärts, ganze 360er –, und weil es flach aufliegt, bremst das Wasser weniger: man gleitet weiter. Wozu: mit Schwung durch die Wende gleiten, ohne einzusinken; quer vom Slider abgehen (ohne Drift hakt die Kante ein = Sturz) oder quer landen; Drehungen auf dem Wasser. Loslassen = die Kante greift wieder (steht das Brett dabei quer, bremst es hart).

**Drift-Press (Nose-/Tailpress auf dem Wasser):** im Drift ↑ halten (Handy ▲) = Nosepress, ↓ (▼) = Tailpress. Das Brett kippt weit um das belastete Ende, der Oberkörper legt sich nach hinten, die freie Hand streift das Wasser. Man bleibt im Drift und nimmt den Schwung mit. Das Ende im Wasser bremst: längs zur Fahrtrichtung am stärksten, je querer man driftet (Drift-Winkel zwischen Brett und Fahrtrichtung), desto weniger. Wie quer man driften darf, hängt vom Tempo ab: je schneller, desto mehr Winkel, voll (86°) ab 33 km/h – also vorher rauskanten. Der Tailpress geht nur zur einen Seite, der Nosepress spiegelverkehrt zur anderen. Zu quer oder zur falschen Seite reißt es einen um (Sturz) – mit ←/→ (Handy: neigen, im Press langsam) muss man den Winkel halten. Unter dem Seilzug steht der aktuelle Winkel. Challenges im Modus Driften: Tailpress, Nosepress und Press-Wechsel (Terminal 2, vorderer Wendepunkt).

## Im Browser spielen

**▶ https://kimpixel.github.io/wakeportGame/**

Funktioniert am besten in Chrome, Edge oder Firefox am PC. Einmal ins Bild klicken, damit Tastatur und Maus reagieren.

## Nutzungsstatistik

Die Web-Version zählt anonym mit [GoatCounter](https://www.goatcounter.com) (ohne Cookies, ohne IP-Adressen,
keine personenbezogenen Daten): Seitenaufrufe, Gerät (Touch/Desktop), gestartete Spiele (Competition mit
Terminal/Setup, Challenge), Rundenende (Punkte grob), Challenge-Medaillen, Erfolge, Setup-Editor und
Spielzeit-Marken (1, 5, 15, 30, 60, 120 min). Nur auf kimpixel.github.io, nicht lokal, in PR-Vorschauen
oder Tests (`scripts/analytics.gd`).

## Figuren

Fahrer, NPC, Steuermann und Gäste sind realistische Menschen aus **MakeHuman** (MPFB für Blender, alle Assets CC0). Erzeugt werden sie per Skript:

```
blender -b --python tools/character/build_character.py -- rider assets/characters/rider.glb
```

Presets: `rider`, `operator`, `guest_f`, `guest_m`.

Die Haltung wird im Spiel live aus der Physik berechnet, mit einer eigenen IK in `scripts/human_rig.gd`: Füße in den Bindungen, Hände am Griff, Oberkörper gegen den Seilzug. Die Arme sind nie überstreckt: Liegt der Griff zu weit weg, holen die Hände ihn heran.

**Einflugschneise:** Der Wakeport liegt direkt im Landeanflug auf Frankfurt (Betriebsrichtung 07). Alle ein, zwei Minuten kommt ein Jet aus Westsüdwest über den Strand, überfliegt den See im 3°-Gleitpfad in rund 260 m Höhe (Fahrwerk draußen, Lichter an) – Mittelstrecke, Langstrecke oder Jumbo – und ist entsprechend laut (mit Dopplereffekt).

**Wetter, Jahreszeit und Uhrzeit** stellst du auf der Startseite unter Einstellungen ein (Wetter, Datum, Uhrzeit). Die Sonne steht dabei wie in echt am Raunheimer Waldsee (50,01° N, 8,48° E, deutsche Zeit mit Sommerzeit): Mittagssonne im Süden, im Sommer lange Abende, im Winter tief stehende Sonne, nachts Mondlicht und Sterne. Wetter: Sonnig, Heiter, Bewölkt, Bedeckt, Schauer, Regen, Dunst, Schnee. **Jetzt** übernimmt das heutige Datum und die Uhrzeit (läuft dann mit) und holt das aktuelle Wetter am See von open-meteo.com. Auf der Startseite wählst du unter **Szenario** eine feste Stimmung aus Datum, Uhrzeit und Wetter; Standard ist **Zufällig** – dann gibt es nach jedem Spiel ein neues, die Shuffle-Taste daneben würfelt sofort ein anderes (die Night Session nur, wenn du sie gezielt wählst). Der Name steht oben links: *After Hour Raley Session* (Abendsonne), *Early Bird Session* (Morgendunst über dem See), *Hochsommer. Was für eine Hitze* (Mittag im Juli), *Schöne Regen-Session*, *Night Session* (Mond und Sterne), *Sonne hinter den Bäumen* (Baumschatten über der Bahn), *Nach dem Schauer* (Regenbogen), *Blaue Stunde*, *Goldener Oktober* und *Chemtrails, oder Kondensstreifen? ;-)*. Wetter, Datum und Uhrzeit von Hand (Einstellungen → Welt) gelten nur bis zum Neustart.

**Einstellungen** (Startseite, sechs Reiter; alles außer Wetter und Uhrzeit wird gespeichert):
- **Spiel:** Rundenlänge der Competition *Runde 7:30*, *Runde 10:00*, *Runde 15:00* oder *Freies Fahren* (keine Uhr – oben steht „FREI“, kein Zeitende, keine Strafzeit). Hilfen *Auf dem Slider einloggen* und *Überschlag dreht von selbst zu Ende* – jede ausgeschaltete Hilfe gibt +15 % auf alle Tricks. *Seilzug-Grenze* An / Aus (Aus: Handle wird nie aus der Hand gerissen, dann keine Rangliste – weder Competition noch Challenge; im Spiel G).
- **Fahrer:** Brett aus der Brett-Bibliothek, Stance *Regular* (links vorne) oder *Goofy* (rechts vorne), Helm und Westenfarbe.
- **Welt:** Wetter, Datum, Uhrzeit, Jetzt; **Seillänge** (12–22 m, Standard 16) und **Anlagen-Tempo** (16–40 km/h, Standard 30) deiner Anlage (+ / − im Spiel ändert das Tempo ebenfalls); Flugzeuge *Aus / Normal / Rush Hour*; Fahrer auf der anderen Anlage an/aus; **Challenge: Filmteam** *Zufall / Boot / Drohne / Aus*.
- **Technik:** Grafik *Niedrig / Mittel / Hoch* (Auflösung, Schatten, Baumdichte, Gischt und alle Wasser-Effekte; am Handy Standard *Mittel*; *Custom*, sobald ein Wasser-Effekt von der Stufe abweicht), Lautstärke für Effekte, Jubel und Flugzeuge, Kamera und Kamera-Abstand (Standard 5 m), am Handy Lenkung (Tasten = Steuerkreuz rechts, Standard, oder Gyro = Handy neigen), Neigungs-Empfindlichkeit und Neigung umkehren.
- **Wasser:** oben dieselbe Grafikstufe (stellt alle Effekte passend ein), Wasserfarbe *Türkis* oder *Seeblau* (Standard) und jeder Wasser-Effekt einzeln an/aus (dann Grafik *Custom*): Oberflächenstruktur, Spiegelung je nach Blickwinkel, Sonnenglitzern, Licht durch die Wellenkämme, Schaum mit Struktur, spitze Wellen, Durchsicht im Flachen, echte Spiegelbilder (nur Desktop, teuer).
- **Musik:** Im Hintergrund läuft **Spiel-Musik**: lizenzfreie Rock-Titel von Pixabay (Quellen in [assets/music/QUELLEN.md](assets/music/QUELLEN.md)), im Browser wird jeder Titel erst geladen, wenn er dran ist. Mit *Titel hinzufügen* wählst du zusätzlich eigene MP3-, OGG- oder WAV-Dateien; sie bleiben auf dem Gerät bzw. im Browser gespeichert. *Quelle*: Spiel-Musik, eigene Titel oder beides (gemischt). Läuft auch in der Pause, bei Jubel und Countdown kurz leiser. Dazu Musik an/aus, Lautstärke, *Nächster Titel* (auch im Pausenmenü) und *Eigene entfernen*. Alternativ öffnet *Skate-Punk bei Spotify* Playlists zum Nebenher-Hören.

**Spielmodi** (Startseite, ganz oben):
- **Competition:** die Runde auf Zeit (Regeln unten). Terminal, Feature-Setup und Rundenlänge sind frei wählbar.
- **Community Challenge** (kurz **Challenge**): Modi mit Challenges, die von Challenge zu Challenge schwieriger werden. Jede Challenge misst einen Wert und vergibt **Bronze, Silber oder Gold**. Der Pokal für die beste Medaille steht in der Auswahl. Vor dem ersten Versuch erklärt ein Fenster Ziel, Steuerung, Tipp und die Schwellen. Jeder Versuch setzt dich in voller Fahrt kurz vor die Stelle, auch die Kamera. Nach einem Sturz (oder verpasstem Feature) gibt es kein Bergungs-Fenster, es geht gleich mit dem nächsten Versuch weiter. Nach einem gewerteten Versuch fährt man noch kurz aus, dann: Leertaste = nochmal, N = nächste Challenge, Esc = Startseite; während der Fahrt R = neuer Versuch. Gefahren wird immer auf Terminal 2 mit 30 km/h und 16 m Seil, damit die Werte vergleichbar sind. Gefilmt wirst du dabei (Einstellung *Challenge: Filmteam*, Standard Zufall) entweder vom **roten Kunststoffboot** von T2 – hinten einer am Außenborder, in der Mitte steht eine mit der Kamera; das Boot fährt seeseitig etwas vor dir mit und wartet vor den Wenden – oder von einer **FPV-Drohne**, die vorne-seitlich über dir fliegt; ihr Pilot steht mit FPV-Brille und Funke auf dem Startsteg. Links oben siehst du das **Livebild** dieser Kamera als kleine Vorschau. Das Filmteam fotografiert beim Absprung, am höchsten Punkt, bei der Landung und auf dem Slider; nach einem gewerteten Versuch zeigt das Ergebnisfenster die Fotos. Ohne Challenge liegt das Boot am weißen Steg.
  - **Wenden** (3 Challenges): Wende am Endmast, Ufer-Wende, Wende außen um die weiße Boje. Gemessen wird, wie tief man einsinkt. Abgesoffen = kein Wert.
  - **Kicker** (3): Kicker M ohne Absprung, Kicker M mit Absprung, Kicker L mit Absprung. Gemessen wird die größte Höhe über dem Wasser. Kicker M und L stehen nebeneinander wie in Setup B.
  - **Slider** (9) auf einem eigenen Setup: rechts vier Slider hintereinander (Full Pipe, Rail, A-Frame, Pipe), links ein 100 m langes Rail. Challenges: auf die Full Pipe, Boardslide (am Ende gerade stellen), Boardslide mit Drift-Abgang, Umspringen, Nose-/Tailpress, Long Rail, Slider-Kette, **Ollie in Boardslide Nosepress** (Ollie direkt auf die Full Pipe, quer, Nosepress; Meter), **Slider Special** (an jedem Slider der Kette eine feste Kombination: 1. Full Pipe Ollie on – 50-50 Nosepress, 2. Rail Ollie on – Boardslide Tailpress, 3. A-Frame Ollie on – Boardslide Nosepress – 180 out, 4. Pipe Ollie 180 on – 50-50 Tailpress – 360 out; „Ollie on“ = aus dem Wasser direkt auf den Slider springen, nicht über die Auffahrt; Press mehr als die halbe Slide-Zeit; gezählt werden die geschafften Slider).
  - **Sprung-Start** (4) vom Startsteg (die Anlage fährt bei GO los, ↓ schon beim Countdown halten): Nolli (Höhe), Nolli mit Drehung (180/360/540), Raley Start (Höhe, Brett quer), Raley Start mit S-Bend, Backroll oder Drehung (Punkte).
  - **Driften** (3): 360er im Drift zwischen den roten Bojen (fünf in die eine, fünf in die andere Richtung; gezählt: volle Umdrehungen des Bretts im Drift, höchstens fünf je Richtung), die Wende am Endmast durchgleiten (Anteil der Wende im Drift, ohne einzusinken – vorher Schwung holen), nach einem Feature driften (Terminal 2, Juli & August, von der Mitte Richtung Steg; längster Drift direkt nach einem Feature, ab 10 m Bronze).
  - **Invert Training** (8) nach der Ufer-Wende: Raley – Höhe, Raley – Weite (Absprung bis Landung), Krypt, Blind Judge, 313, S-Bend, Backroll (noch in Arbeit), Special – S-Bend to Blind (außer Raley – Weite je Höhe). Es zählt nur genau dieser Trick – mehr Drehung oder ein Extra ist daneben („Junge mach mal langsam!“). Spätestens an der nächsten Wende ist der Versuch vorbei.
  - **Transfer** (4) auf den echten Setups: Klein (Terminal 2, Setup C: von der Pyramid aufs A-Frame Rail), Groß (Terminal 1, Setup A: vom Wedge auf die Down Ledge), Special (Terminal 2, Setup D: Ollie auf die Transition Curb, von dort auf die Down Ledge), Special Press (dasselbe mit Nosepress auf der Ledge, Sekunden im Press). Klein, Groß und Special messen die **Sprunghöhe** (höchster Punkt im Flug vom Start-Feature aufs Ziel): so hoch wie möglich abspringen und den Slider trotzdem noch erwischen. Gezählt wird nur, wer auf dem Start-Feature fährt, von dort abspringt und aus der Luft aufs Ziel kommt – das Ziel von vorne anzufahren oder aus dem Wasser seitlich draufzuspringen zählt nicht.
- **Jeder Start beginnt mit einem Countdown 3 – 2 – 1 – GO**, angesagt auf Englisch („three, two, one, go“). In der Competition fährt die Anlage bei GO los (auch nach R zurück zum Steg); in den Challenges steht das Spiel bis GO.
- **Geheime Erfolge** (Taste *Erfolge* auf der Startseite): eine Liste mit 10 ausgegrauten Einträgen. Was es gibt, steht erst da, wenn man es geschafft hat – im Spiel kommt dann die Meldung „Geheimer Erfolg freigeschaltet“. Bleibt im Browser bzw. auf dem Gerät gespeichert.
- **Rangliste** (Taste *Rangliste* auf der Startseite): die besten Fahrer der gewählten Challenge bzw. Competition (je Terminal, Setup und Rundenlänge), dein eigener Platz ist hervorgehoben. Oben in der Auswahl stehen alle Disziplinen, in denen schon jemand eingetragen ist (vorgewählt ist das gewählte Spiel). Mitmachen nur, wenn du dort einen **Namen** speicherst – dann kommen deine Bestwerte automatisch hinein, der Platz steht im Ergebnisfenster bzw. unter dem Titel. Mit Seilzug-Grenze Aus gibt es keine Rangliste. Competition zählt nur mit 30 km/h und 16 m Seil, nicht im Freien Fahren und nicht auf eigenen Setups. Ändert sich eine Challenge oder ein Setup, beginnt deren Rangliste neu. *Nicht mehr teilnehmen* löscht Name und alle Einträge. Server: [server/README.md](server/README.md).

**Spielregeln (Competition):** Eine Runde dauert **7:30** (Uhr oben links), sie beginnt nach dem Countdown mit dem Start vom Steg. Es zählen die Punkte in dieser Zeit. Danach bringt dich der Operator nur noch zum Start, dann kommt die Startseite mit deinem Ergebnis. **Punkte:** Slides zählen am meisten: 150 Grundpunkte, dazu 150 pro Sekunde und 100 für den Boardslide. Wer auf einen Slider kommt, rastet in die nächste Stellung ein: eher längs im **50-50**, eher quer (über 45°, z. B. in der Luft gedreht) im **Boardslide**; mit ←/→ (Handy: deutlich neigen) springt man in 90°-Schritten zwischen Boardslide und 50-50 um – jeder Wechsel bringt 80 extra und zählt im Namen mit (z. B. „Boardslide to 50-50“). Nose- oder Tailpress (mehr als die halbe Slide-Zeit gehalten) bringt 100 extra. **Abgang:** Wer mit quer stehendem Brett vom Slider ins Wasser fährt oder quer landet, stürzt – vorher gerade stellen (Tipp ←/→ zurück auf 50-50, auf der Abfahrt drehen) oder beim Abgang Strg (Drift) halten, dann rutscht das Brett quer weiter. Auf Rail und Pipe gibt es das 1,5-fache, auf dem Transition Rail das 1,3-fache. Airs und Drehungen bringen weniger, 50 pro Sekunde Flugzeit und 50 pro 180°. Ein einfacher Sprung heißt nach dem Absprung: **Ollie** (aus dem Wasser), **Kicker Air** (vom Kicker, Wedge, Bump oder von der Transition Curb) oder **Safety Air** (von einer Safety bzw. Auffahrt). In der Luft geht der Fahrer in die Knie (am höchsten Punkt am tiefsten), streckt sich vor der Landung und federt sie in den Knien ab. Ein Raley bringt 150 extra, jeder Frontroll oder Backroll 300, S-Bend oder Invert-Backroll 300 zum Raley dazu. **Kombinationen** zählen am meisten: Wer innerhalb von 3 s Fahrt den nächsten Trick macht, z. B. 180 auf das Rail, Boardslide, 180 raus, bekommt für den 2. Trick das Doppelte, für den 3. das Dreifache usw. Ein Sturz oder Absaufen beendet die Kombination. Wer stürzt, muss zur Handle schwimmen und verliert Zeit, je weiter weg vom Seil desto mehr. Große Sprünge sind also ein Risiko. Abkürzungen kosten Strafzeit: Strg nach einem Sturz −1:00 (dafür bist du sofort direkt unter dem Seil und fährst weiter), R zurück zum Steg −2:00. Der Wasserstart geht immer Richtung des weiter entfernten Wendepunkts.

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
| `scripts/water.gd`, `shaders/water.gdshaderinc` (+ `water.gdshader`, `water_depth.gdshader`) | Wasser: Grundwellen, Heckwelle und Aufprallwelle beim Landen. Physik und Grafik nutzen dieselbe Höhenfunktion. Effekte einzeln schaltbar (Reiter Wasser) |
| `scripts/spray_sheet.gd`, `scripts/spray.gd` | Gischt: **Wasserwand** (zusammenhängender Vorhang beim Schneiden, Stärke aus Seilzug, Tempo, Winkel und Sprung-Ladung) und **Tropfen** (weiche Wolken-Sprites: Kante, Landung, Drift-Press, Hecht, Boot) |
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

## Unterstützen

Das Spiel ist kostenlos und Open Source, ich entwickle es in meiner Freizeit (und zahle die KI-Werkzeuge dafür selbst). Wenn es dir gefällt, freue ich mich über einen Kaffee: **[ko-fi.com/kimpixel](https://ko-fi.com/kimpixel)**. Auf der Startseite im Spiel steht derselbe Link.

## Lizenz

[MIT](LICENSE) – du darfst den Code frei verwenden, verändern und weitergeben, solange der Lizenzhinweis erhalten bleibt.

**Ausgenommen:** `assets/board/top.png` und `assets/board/bottom.png` zeigen ein Board von Slingshot. Foto, Grafik und Logo © Slingshot. Sie stehen nicht unter der MIT-Lizenz und dürfen nicht weiterverwendet werden.
