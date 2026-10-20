# CLAUDE.md – WakeTheHack

**WakeTheHack** (Titel im Spiel „WAKE THE HACK“, darunter „Wakeport Raunheim“): Wakeboard-Spiel in **Godot 4.7.2** (GDScript), das den **Wakeport Raunheim** nachbaut: Waldsee bei
Frankfurt mit zwei 2-Mast-Seilanlagen (T1, T2). Web-Version auf GitHub Pages:
https://kimpixel.github.io/wakeportGame/ (Repo `kimpixel/wakeportGame`, Build per
`.github/workflows/web.yml` bei jedem Push auf `main`, dauert ca. 1 min).

Spielerdoku: `README.md`. Feature-Setups und Bauteile: `setups/README.md`.

## Begriffe und Kurzformen des Nutzers (immer so verstehen)

Der Nutzer benutzt feste Begriffe (oft mit Erklärung in Klammern) und Kurzformen:

| Nutzer sagt | Bedeutung |
|---|---|
| **Terminal 1 (T1)**, **Terminal 2 (T2)** | die beiden Seilanlagen am See. Terminal = eine Anlage. T2: Strand mit großer Hütte (Standard, hier fährt man meist); T1: Lounge-Steg. Auf der jeweils anderen Anlage fährt ein NPC. **Im Spiel nur „Terminal 1“ / „Terminal 2“ schreiben** (keine Zusätze wie „Strand“/„Lounge-Steg“) |
| **Feature** | Terminus für ein **Hindernis** im Wasser (Kicker, Box, Rail, Pipe …) |
| **Feature Setup (Setup)** | Terminus für die **Aufstellung der Hindernisse** einer Saison/Zeit, z. B. „2026 September“, „Setup A“ … „Setup E“. Datum oft unbekannt → Platzhalter „?“ |
| **„T2 s D“, „t2 S D“, „T2 SE“** | Terminal 2, Setup D bzw. Setup E (so werden Stellen benannt: „auf t2 s D -> …“) |
| **T und S** (Auswahl) | Terminal- und Setup-Auswahl (auf der Startseite; Tasten T/F gibt es nicht mehr) |
| **Hack** | sobald **mehrere Features zusammenstehen**, ist das ein Hack (Kombination). Ausnahme: so gängige Kombinationen heißen nicht Hack – Ollie Box + Ledge, A-Frame + Pyramid Rail (Pyramid Series), zwei Kicker nebeneinander oder als Spine |
| **Feature/Hack** | ein auswählbares Element: einzelnes Feature oder Hack |
| **Startblock / Startdock** | Startsteg mit kleiner Holzhütte davor, dort startet man. Im Startblock sind immer mindestens der Steuermann und optional Gäste |
| **Steuermann (Hebler)** = **Operator** | bedient die Anlage mit einer kleinen gelben viereckigen Fernsteuerung (ca. 30 × 10 cm), bringt nach einem Sturz die Handle |
| **Handle** (geschrieben auch „Handel“) | Griffstange am Seil |
| **Seil verlieren** | Handle loslassen/aus der Hand gerissen → kein Sturz, nur einsinken |
| **Seilzug** | Spannung im Seil; wichtigste HUD-Anzeige, zeigt auch an, ob man gleich einsinkt |
| **Wendepunkt / Wende** | Umkehr am Ende der Bahn (Ufer-Wende am Start, Wende am Endmast) |
| **Rote Boje** | genau an der optimalen Stelle zum **Rauskanten** für die Kurve, mittig unter dem Seil, ein paar Meter vor den weißen |
| **Weiße Bojen** | zwei je Wendepunkt (links und rechts), um die man außen herumfährt |
| **Gelbe Bojenlinie** | lange gelbe Zylinder (ca. 2 m) aneinandergekettet |
| **Rauskanten** | vor der Wende nach außen kanten und um den Carrier pendeln |
| **Absinken / Einsinken / Absaufen** | bei schlaffem Seil und wenig Tempo ins Wasser sinken (wie Wasserstart, keine Punkte) |
| **Invert** (Mehrzahl **Inverts**) | Oberbegriff für alle Tricks aus dem Raley-Absprung (aufgeladener Sprung mit Seilzug und Tempo): Raley, S-Bend, Invert-Backroll, Blind Judge, Krypt, 313 … |
| **Kicker S / M / L** | Small / Medium / Large Kicker; **Spine** = zwei Kicker Rücken an Rücken |
| **Small-Pipe** | Pipe-Hälfte mit beiden Auffahrten |
| **Down Ledge (Rooftop)** | lange Ledge: kleine Safety vorne, steil hoch, lang abfallend, Safety hinten bis ins Wasser |
| **Safety** (geschrieben „Safty“) | flaches/abfallendes Endstück einer Ledge |
| **vorne / hinten** bei einem Feature | vorne = Anfahrtsseite, hinten = Ende/Abfahrt |
| **Auffahrt** | die Schräge vorne bzw. hinten an Box/Rail/Pipe (Rail beginnt und endet am Ende der Auffahrt) |
| **Bindung (Schuh)** | Bindung = hoher Schuh auf dem Board |
| **Einflugschneise** | der See liegt im Landeanflug auf Frankfurt: Flugzeuge tief, groß, laut |
| **Rolle am Mast** | Umlenkrolle (ca. 30 cm), um die das Stahlseil läuft |
| **Startseite / Startscreen** | Menü vor dem Spiel |
| **Hub** | gemeint ist das **HUD** |
| **„passt so“** | Freigabe → committen |

Häufige Schreibweisen: „rayley“ = Raley, „olli“ = Ollie, „triften“ = driften, „downledge“ = Down
Ledge, „cheesewedge“ = Cheese Wedge, „Transitionrail“ = Transition Rail.

## Zusammenarbeit

- Sprache mit dem Nutzer: **Deutsch**. Code-Kommentare und Doku ebenfalls Deutsch.
- Nach jeder fertigen Änderung: kurzer Smoke-Test, **commit und push** (Nutzer testet im Browser).
  Commit-Nachricht auf Deutsch, endet mit `Co-Authored-By: Claude …`.
- **Prüfung macht der Nutzer selbst** (visuell und funktional): er startet das Spiel über den Button
  „▶ Spiel starten“ im Band über dem Prompt (Claude-Mod `wakeport-start`, startet im Worktree der Session,
  sonst im Haupt-Checkout; importiert vorher, falls `.godot` fehlt; liegt außerhalb des Repos in
  `C:/Users/kim/.claude/mods/wakeport-start`, geladen in jeder Session über `CLAUDE_CODE_PLUGIN_DIRS` in
  `~/.claude/settings.json`, Band erscheint nur, wenn der Git-Remote `kimpixel/wakeportGame` ist). Deshalb:
  - **Keine Screenshots für den Nutzer** erstellen oder schicken.
  - **Headless arbeiten, wo es geht** (Smoke-Tests, Log-Ausgaben, `--import`).
  - Das Spiel mit Fenster **nur starten, wenn es für die eigene Selbstkontrolle nötig ist**
    (z. B. Optik/Animation, die headless nicht prüfbar ist) – nicht für den Nutzer.
- Sagt der Nutzer „zeige das Ergebnis und warte auf Freigabe“ (oder ist eine Pose/Optik strittig):
  **nicht committen**, bis er nach eigenem Test „passt so“ sagt.
- „passt so“ = Freigabe, dann commit.
- **Im Worktree** (nicht auf main): vor jedem Push auf die Freigabe des Nutzers warten (er testet über den
  Button im Band), erst dann pushen.
- README.md und die Hilfe im HUD (`scripts/hud.gd`, `HELP`/`HELP_MOBILE`) bei Steuerungs- und
  Regeländerungen mitpflegen.

## Testen

Godot liegt im Repo-Root: `./Godot_v4.7.2-stable_win64_console.exe`. Kein ffmpeg/python, aber node.

```bash
# Headless-Smoke-Test (Autopilot, Log mit TRICK:/CRASH:/t=… Zeilen)
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 120 -- --autotest --set=music=false --quit=30
# Screenshot (mit Fenster, nur zur eigenen Selbstkontrolle; Fenster läuft automatisch unsichtbar im Hintergrund,
# außerhalb des Bildschirms ohne Fokus – auch bei --write-movie bzw. mit --bg; --fg zeigt es), z. B. Nahaufnahme am Fahrer
./Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 120 -- --autotest --jump-at=12 --closeup=0,1.2,4.5,0,1.0,0 --shot=PFAD.png --shot-time=12.4 --set=music=false
# Handy nachstellen
./Godot_v4.7.2-stable_win64_console.exe --path . --resolution 540x1170 -- --mobile --tilt=0
```

Wichtige Test-Argumente (vollständig im Kopf von `scripts/main.gd`): `--autotest`, `--quit=S`,
`--shot=P --shot-time=S`, `--view=x,y,z,lx,ly,lz`, `--closeup=x,y,z[,lx,ly,lz]` (relativ zum Fahrer),
`--terminal=T1|T2`, `--setup=ID`, `--screen[=NAME|@liste|@einstellungen]`, `--no-screen`,
`--mobile --tilt=GRAD`, `--jump-at=S`, `--pitch=±1`, `--hold=AKTION@T0-T1`, `--crash-at=S`, `--letgo-at=S`,
`--game-time=S`, `--scenario=ID`, `--weather=ID --hour=H --day=T`, `--plane=S`, `--passive`.

**Grafik-Aufwand messen**: jedes `--shot` schreibt `RENDER draw calls …, dreiecke …` ins Log; wie im Web mit
`--rendering-method gl_compatibility` und `--set=quality=0|1|2` vergleichen (Handy: Niedrig/Mittel).

**Musik bei eigenen Tests aus**: immer `--set=music=false` anhängen (speichert nichts), außer der Ton/die Musik
selbst soll geprüft werden.

Fallstricke:
- **Neue `class_name`** → erst `--headless --import` laufen lassen, sonst „Could not find type“.
- Screenshots mit Fenster brauchen bei `--fixed-fps 120` lange (Spielzeit wird voll gerendert).
  Früh testen: der Fahrer ist ab ca. 3 s auf dem Wasser, `--jump-at=12` reicht.
- Für einen Trick im Test temporär Grenzwerte ändern (z. B. `RALEY_TENSION := 0.0 #TMP`) und
  **vor dem Commit zurücksetzen**.
- Mehrzeilige GDScript-Änderungen mit Edit/Write statt bash-heredoc/`node -e`: `\\` am Zeilenende
  wird dort leicht zu einem wörtlichen `\n` oder verschluckt.
- „ERROR: BUG: Unreferenced static string“ beim Beenden ist Engine-Rauschen.
- **Audio-Busse nur in `default_bus_layout.tres`** anlegen – zur Laufzeit angelegte Busse sind in der
  Web-Version stumm (Ton am Handy war komplett weg). Web-Probleme zeigen Headless-Tests nicht.
- **Schleifen-Sounds im Web**: Godot schleift dort nicht selbst, sondern startet den Puffer bei jedem Ende per
  JS neu – ab dem Startpunkt von `play(from)`, mit kurzer Lücke. Darum Schleifen mit `Sfx.loop_start()` starten
  (im Web 0, sonst wiederholt sich nur ein Bruchstück), Puffer lang machen, und `playing` nicht trauen
  (eigener Zustand, siehe `Sfx._keep_loop`).

## Architektur (wichtigste Dateien)

| Datei | Inhalt |
|---|---|
| `scripts/main.gd` | Szene aufbauen, Eingabe (`_setup_input`), Spielablauf (Runde, Strafzeiten, Wenden-Wertung), Startseite öffnen/schließen, Test-Argumente |
| `scripts/rider.gd` | Fahrer: Physik (Wasser, Luft, Slider), Seilzug, Tricks und Punkte, Posen (IK am Menschen-Rig), Raley/Überschlag/Press, Sturz/Schwimmen/Deep-Water-Start, Autopilot/NPC |
| `scripts/training.gd`, `scripts/challenge.gd`, `scripts/ui/task_panel.gd` | Spielmodi: Aufgaben/Medaillen (Daten), Ablauf eines Versuchs (Platzieren, Countdown, Messen), Aufgaben-Fenster |
| `scripts/cable_system.gd` | Carrier/Seilbahn einer Anlage (Zustände RUN, BRAKE, PAUSE, FETCH, HOLD, DONE) |
| `scripts/features/` | `feature_set.gd` (Setups laden), `feature_part.gd` (Form = Physik = Grafik), `hacks.gd` (Hack-Erkennung/-Namen) |
| `shaders/feature.gdshader`, `feature_rail.gdshader`, `feature_common.gdshaderinc` | Optik der Features: weißer Kunststoff, **nass glänzend** (Wasserfilm: Klarlack, nass dunkler, Fresnel wie der See; Kratzer und Dreck matt; regelbar im F4-Panel Reiter „Features“: `FeaturePart.WET_DARK`, `WET_FRESNEL`, `WET_ROUGH`, `WET_COAT`, `REFLECT`) und **spiegelt die Umgebung** über Reflection Probes (`FeatureSet.update_reflections`, nahe Teile teilen sich eine – `PROBE_GAP` 3 m, sonst über 60 Probes; UPDATE_ONCE, unsichtbar aufgenommen und danach weich eingeblendet, sonst flackern die Features beim Start; Log `SPIEGELUNG ein`; nur auf die Features über `REFLECT_LAYER`, ab Grafik Mittel, nur im Spiel), mit Kratzern (je Teil eigener Zufall `seed` aus Lage + Bauteil, `FeaturePart._seed`), schwarzes Rail matt mit Längskratzern (`FeaturePart._rail_mat`; graues Pro Rail bleibt Stahl), Verschmutzung vom Wasser aus (`water_dirt`: bis ca. 8 cm über Wasser braun/gelblich, darüber ca. 30 cm grau-fleckiger Verlauf). **Kanten scharf** (`_build_heightfield`): Gitterlinien liegen genau auf den Knickstellen (`_grid_lines`: Auffahrt-Enden, Profilpunkte, seitliche Auffahrt, Bump-Plateau), Maschen werden entlang der passenden Diagonale geteilt, Normalen nur bis `CREASE` 10° geglättet – sonst sahen Kanten rund und am Handy verschwommen aus |
| `scripts/ui/start_screen.gd` | Startseite (responsiv, Popups Einstellungen / Features & Hacks / Detail) |
| `scripts/ui/setup_editor.gd` | Setup-Editor (eigene Seite, Draufsicht/3D, Bauteile, Hacks, Auswahl, Speichern in `user://setups`, JSON); Reiter **Pflanzen**: auf dem Luftbild malen/radieren/Automatik zurückholen (Pinsel, Dichte, eigenes Rückgängig), speichert `setups/plants.json` (aus dem Projekt gestartet; exportiert `user://plants.json`), Spiel baut die Bepflanzung danach neu auf; Test `--screen=@editor:t2:sel=2:3d…`, Pflanzen `…:pflanzen:mitte=S,X:art=ID:malen=S,X,S2,X2:psave` (psave schreibt die Datei!) |
| `scripts/plants.gd`, `setups/plants.json` | Bepflanzung: Arten (Schilf, Ufergras, Wiesengras, Strauch, Laubbaum, Kiefer), **Automatik am Ufer** (Schilf im flachen Wasser, nicht in der Fahrbahn `LANE_FREE`; Ufergras; Sträucher; Büschel per Rauschen) und **von Hand gemalt** (Spielkoordinaten). Gemalt/radiert = Stelle **von Hand gepflegt** (Raster 2 m, je Ebene Boden/Gehölz): dort keine Automatik, auch kein Wald/Wiesengras aus den Daten. Zufall je Rasterpunkt mit `Plants.mix` (nicht `hash()` als Seed: ähnliche Seeds = ähnliche Zufallsfolgen) |
| `scripts/ui/feature_preview.gd` | drehbare 3D-Vorschau eines Features/Hacks (eigene Welt) |
| `scripts/ui/menu_nav.gd` | Menüs mit Tastatur/Gamepad: Menüs melden ihren Bereich an (`MenuNav.add_scope(root, stufe, erster)`; Startseite 0, Popups 10, Editor 15 passiv, Challenge-Fenster 20, Pause 30, Auswahlliste 50), Fokus wandert mit Pfeilen/Steuerkreuz/linkem Stick (Richtung, mit Wiederholung) und Tab, weißer Rahmen `focus_box()`. Leertaste/✕ = Knopf drücken (`ui_accept`, ohne Enter), Enter/PS/Touchpad = `menu_start`, Z/Share = `shuffle` (Szenario würfeln, Startseite und im Spiel, `main.gd _shuffle_scenario`; Handy ☰ „Szenario würfeln“); im Spiel Touchpad = R (`reset`, Steg/neuer Versuch), Esc/○ = `ui_cancel`, O/Options = `settings`, Esc/PS = `pause`. Im Spiel: ○ = Driften, Steuerkreuz = lenken/Rolle, L1/R1 = Tempo (in der Luft schnelle 180, `Rider._quick_spin`, `QUICK_SPIN_RATE`; Invert nur normales Drehtempo), R2 = Sprung analog (`_trig_load` = tiefster Druck), R3 + rechter Stick ↕ = Zoom; im Menü L1/R1 = Reiter. `scripts/pad_fx.gd`: Vibration (Landung `Rider.touched_down`, Sturz, Rumpeln, Sprung-Start, Slider, Seilzug ab 80 % der Grenze) und Lichtleiste in Seilzug-Farbe (`Input.set_joy_light`) |
| `scripts/ui/touch_pad.gd`, `scripts/mobile_input.gd` | Handy: virtuelle Tasten, Neigung, Touch |
| `scripts/ui/debug_params.gd` | Debug-Overlay **F4** (nur lokal am Desktop, nicht Web): kompaktes Panel oben rechts am Rand, feste Pixelgröße (360 px, wächst nicht mit dem Fenster), Bereich per Auswahlfeld, je Parameter eine Zeile mit Regler, Kommentar aus dem Quelltext im Tooltip, „Kopieren“ in die Zwischenablage, nichts gespeichert; Mausrad über dem Panel zoomt nicht die Kamera. Regelbare Werte sind `static var` statt `const` (z. B. `Rider.DPRESS_DRAG`); neue in `GROUPS` eintragen. Test `--debug-params` |
| `scripts/ui/branch_label.gd` | klein unten rechts in der Ecke: im Web die **Build-Version** (`res://version.txt`, schreibt `web.yml`, z. B. „v412 · 502fa0a“ – zeigt am Handy, ob die neue Version geladen ist), lokal am Desktop der Git-Branch (liest `.git/HEAD`, auch im Worktree). Web-Cache: `web.yml` benennt `index.pck` je Build um, `index.js?v=`, und `head_include` lädt die Seite einmal neu, wenn `build.txt` eine neuere Build-Nummer meldet |
| `scripts/leaderboard.gd`, `server/` | Online-Rangliste (Wertungs-Version, Senden/Abrufen) und Cloudflare Worker + D1 (siehe „Rangliste“ unten) |
| `scripts/ui/drift_debug.gd` | Drift-Anzeigen: im Drift-Press immer ein **Balance-Bogen** über dem Fahrer (wie Tony Hawk: Nadel = Drift-Winkel, grün = bei diesem Tempo erlaubt, rot bis `DPRESS_FALL_ANG`, Bremse-Balken); mit **F3** (zusammen mit den Hitboxen) Linien am Brett auf dem Wasser: Fahrtrichtung = Bezug (weiß), Brettachse (gelb), erlaubt (grün), Grenze (rot), Seilzug (orange) + Werte |
| `scripts/hud.gd` | HUD (Zeit, Seilzug-Anzeige mit Marke RALEY aus `Rider.RALEY_TENSION`, **Tempo** mit Marke PRESS MAX aus `Rider.DPRESS_SPEED`, Punkte), Hilfe, Stil (`ACCENT` grün, `PANEL`) |
| `scripts/terrain.gd`, `shaders/foliage.gdshader`, `bark.gdshader`, `grass.gdshader` | Gelände aus DGM/Luftbild; Wald: Kronen aus dunkler Hülle + Blattkarten (Textur zur Laufzeit gemalt), je Art 3 Varianten, MultiMesh-Kacheln `TREE_CHUNK` 160 m, drei Stufen je Grafikstufe: nah mit Blattkarten bis `FAR_RANGES`, fern grobe Hülle + halbe Karten bis `VFAR_RANGES`, sehr fern ein Klumpen + Viertel der Karten (die fernen Kronen waren der größte Teil der Dreiecke); Sichtweiten **ohne Hysterese-Rand**, nah/fern überlappen (`FAR_OVERLAP`) – mit Rand blieben nach Kamerasprüngen kahle Stämme; Kacheln gemischt (`_shuffle`), damit die Baumdichte je Grafikstufe gleichmäßig ausdünnt; Schatten wirft nur die grobe Hülle (eigenes MultiMesh), Mittel nur 2 Schatten-Kaskaden; Uferpflanzen und Gemaltes aus `Plants` (Sträucher/Bäume in den Wald-Kacheln, Schilf/Ufergras eigene Kacheln `PLANT_CHUNK`), `rebuild_vegetation()` nach dem Speichern im Editor; dichter Mischwald aus Laubbäumen und Kiefern, **Fichten nur vereinzelt (2 %)**; **Waldmantel**: bis 14 m vom Wasser Kronen fast bis zum Boden plus Büsche (`_near_water`), damit vom See eine geschlossene grüne Wand steht; Gras am Ufer beider Anlagen (aus SimpleGrassTextured, `assets/grass/`), nicht am Strand der Startmasten. Compatibility-Renderer liefert Instanzfarben schon linear (`to_linear` in den Shadern) |
| `scripts/water.gd`, `shaders/water.gdshaderinc` | Wasser: Höhenfunktion = Physik = Grafik (Grundwellen `_wave`, spitz bei `fx_sharp`; Heckwelle; `impact()` Aufprallwelle beim Landen; **große Bootswelle** `emit_boat_wake` vom Heck des roten Boots in Challenge und Patrouille, eigene Kreiswellen `BOAT_*` in Physik und Shader, Kamm bis ca. 0,6 m – Fahrer, SUPs und Bojen schaukeln mit). Effekte `fx_*` einzeln schaltbar (Reiter **Wasser**, Einstellungen `w_*`), **gekoppelt an die Grafikstufe** (`GameSettings.WATER_PRESETS`, `set_quality`; weicht ein Effekt ab, zeigt die Grafik „Custom“ = `quality_shown()`, gespeichert bleibt die Stufe); nur `w_clear` (Durchsicht) braucht den transparenten Tiefen-Shader `water_depth.gdshader`. Farbe `w_color` Türkis/Seeblau (Standard Seeblau, „ein See ist blau“). Flach geschaut wird die Spiegelung stark gedämpft (sonst wurde der See in der Ferne weiß). **Keine Schaumkränze** (passten nicht) |
| `scripts/spray_sheet.gd`, `scripts/spray.gd` | Gischt, zwei Begriffe: **Wasserwand** (`SpraySheet`, Vorhang aus ballistischen Flugbahnen, Ansatz über die ganze Kante, Fächer von flach bis steil; zur Seilseite; Stärke 0..1 = Summe gewichteter Anteile Seilzug/Tempo/Winkel/Sprung-Ladung, Parameter `WALL_*` im F4-Panel; Seite aus der Neigung des Fahrers, Achse immer in Fahrtrichtung, auch switch) und **Tropfen** (`Spray`, weiche Wolken-Sprites, klein anfangen, groß und durchsichtig am Ende, fliegen nach hinten; kleine Gischt auf der anderen Kante, Landung mit Spritzer-Kranz, Drift-Press, Hecht, Boot). Keine Kugeln, kein Sprühnebel. **Performance**: die Wasserwand rechnet je Bild jeden Punkt einmal und nur mit `Water.ambient` (nie `height_at` je Punkt – das machte das Handy sehr langsam); Zeilen/Takt, Tropfen-Menge und Proximity Fade (Tiefenkopie im Browser, nur Hoch) je Grafikstufe (`set_quality`) |
| `scripts/weather.gd`, `scripts/sun_calc.gd`, `shaders/sky.gdshader` | Wetter, Sonnenstand nach echter Lage; **Szenarien** (`Weather.SCENARIOS`); Himmel mit Wolkenballen (Hash ohne `sin`, sonst kantige Facetten), nachts Mond, Sterne, Milchstraße, Lichtglocke Frankfurt; Regenbogen, Kondensstreifen. Schnee: globaler Shader-Parameter `snow` (project.godot `[shader_globals]`) in Gelände/Laub/Gras. Unbeleuchtete Materialien (Zugleine, Gischt, Regen) mit `Weather.lum` abdunkeln, sonst leuchten sie nachts. **Features ab Blauer Stunde/nachts**: globaler Parameter `feature_light` (0,12 nachts, auch Glanz/Klarlack) dimmt das Weiß, blauer Ball über `Weather.dim_at_night`; **Bojen** (rot/weiß, gelbe Leine) leuchten dann leicht (`Weather.glow_at_night`, Signalfarben sollen auffallen); dazu `Weather.reflect` (Reflection Probes), gedämpfte Himmelsspiegelung (`radiance`, nur `AT_CUBEMAP_PASS`) und kaum Glanz vom Mondlicht – sonst stechen sie grell heraus. Bodennebel: ein Bild-Durchgang `shaders/mist.gdshader` (Nebelmenge je Blickstrahl exakt integriert, Dichte `Weather.MIST_DENSITY` über dem Wasser, nach oben exponentiell dünner; Strahl endet am Tiefenpuffer bzw. bei y = 0) – keine waagrechten Schichten, die schnitten Wellen/Ufer/Features als Treppen |
| `scripts/sfx.gd`, `assets/sounds/` | Sounds; `positiv/` (Jubel), `negativ/` (Ruf beim Sturz), `feature_hit/`, `landing/` aus Videoaufnahmen |
| `scripts/npcs/` | Umgebung (Steuermänner, wartende Fahrer, SUPs), Flugzeuge im Anflug; **Leben nach Jahreszeit** (alle über `apply_season(weather)` bei jedem `Weather.changed`; Werte `Weather.warm`/`heat`/`daylight`/`month()`): `ambient.gd` Hecht nur April–Oktober, SUPs nach Wärme (Winter/Regen/Nacht keine, Hitzetag + `SUP_EXTRA` je Grafikstufe, nie zwischen den Bahnen); `bathers.gd` Hitzetag: Luftmatratzen/Schwimmringe (Person `float`/`ring`, nur einmal posiert) im Badebereich und seeseitig, Liegewiese am Nordstrand (x −200..−120), Obergrenzen je Grafikstufe; `wildlife.gd` Haubentaucher (März–Nov., tauchen vor dem Fahrer), Schwanenpaar (Küken Mai–Sep., Herz), Graureiher, Kranichzug (Feb./März, Okt./Nov.), Libellen, Fledermäuse, Glühwürmchen, Eisschollen (Dez.–Feb.); `storm.gd` Gewitter-Blitze. Herbstlaub/kahle Laubbäume: globale Shader-Parameter `autumn`/`bare` (`Weather._leaves`), Pappelflug im Mai. Kein Wind/keine höheren Wellen (Physik = Rangliste) |
| `scripts/wakeboard.gd`, `shaders/boot*.gdshader*` | Board + Bindungen (Schaft knickt per Shader mit dem Schienbein) |
| `setups/parts.json`, `setups/setup_*.json`, `setups/index.json` | Bauteil-Katalog, Feature-Setups je Terminal |

Koordinaten: Seil T2 entlang −z vom Startmast (z = 0). `s` = Abstand vom Startmast entlang des
Seils, `x` = seitlich (+ rechts mit Blick zum Endmast). Lage: 50,0122 N, 8,4773 E. Seeseite der
Bahn = lokal −x der Anlage. Alle Features stehen im Spiel 10 m weiter draußen als in den
Setup-Dateien (`FEATURE_SHIFT`) plus Mittenausgleich je Anlage (`CENTER_SHIFT`: T1 10,5 m, T2 12,5 m – im
Schnitt gleich viel Platz vorne und hinten), Endmasten 35 m weiter (`END_EXTEND`), rote Bojen 27 m vor dem
Wendepunkt. Ufer-Wende T2 bei 28 m vom Startmast (`cable.turn_a_z` in main.gd).

## Festgelegte Regeln und Entscheidungen

Spielmodi (`scripts/training.gd` Daten, `scripts/challenge.gd` Ablauf, `scripts/ui/task_panel.gd` Fenster):
- **Competition** = die Runde auf Zeit (alles unter „Spiel“). Daneben die **Community Challenge** (im Spiel kurz „Challenge“,
  nie „Training“/„Aufgabe“ schreiben; im Code heißen sie weiter Training/Task): **Wenden, Kicker, Slider, Invert Training**, je
  mehrere Aufgaben (leicht → schwer), jede misst einen Wert → **Bronze/Silber/Gold** (Schwellen in `Training.MODES`,
  vom Nutzer fein justiert). Bestwerte in user://settings.cfg [medaillen]; **Tests speichern nichts**.
- Modi: Wenden, Kicker, Slider, **Pool** (am 6-Stair Pool, siehe Features/Setups), **Invert Training** (id `raley`; je Aufgabe genau ein Trick: `trick` = Name wie im Spiel, `rank` = Zusätze; anderer Trick = fehlgeschlagen, mehr = „Junge mach mal langsam!“; Versuch endet spätestens, wenn die Anlage zur nächsten Wende bremst; Raley zweimal: Höhe (Gold 5 m) und Weite, Messwert `width` = waagrecht Absprung → Landung (Gold 26 m); `"lb": 1` = Ranglisten und eigene Bestwerte neu, Schlüssel `MODUS.ID@lbN`), **Sprung-Start** (Nolli, Raley Start vom Steg), **Driften**, **Transfer** (auf echten Setups, `terminal`/`setup` je Aufgabe, `via` = Start-Feature,
  `target` = Ziel, je per Anzeigename; zählt nur: auf dem Start-Feature fahren, abspringen, aus der Luft aufs Ziel; Klein/Groß/Special messen die Sprunghöhe im Flug Start-Feature → Ziel (`_xfer_h`), Special Press die Press-Sekunden). Nach gewertetem Versuch **1,4 s ausrollen** (`Challenge.OUTRO`), dann Fenster.
  Startseite im Querformat zweispaltig (links Modi, rechts Terminal/Setup bzw. Aufgaben; Handy quer: Start links).
- Aufgabe setzt Fahrer + Carrier **in voller Fahrt** kurz vor die Stelle (`Rider.place`, `CableSystem.place_running`),
  jeder Versuch wieder dort (auch Kamera). Sturz/Seil verloren/verpasst: **kein Bergungs- oder Ergebnis-Fenster** (nach Sturz/Seilverlust erst `Challenge.CRASH_WAIT` 1,2 s den Sturz zeigen),
  sofort neuer Versuch mit Countdown; Fenster nur bei gewertetem Versuch. Immer Terminal 2, 30 km/h, 16 m Seil. Eigene Setups
  `setups/training_*.json` (nicht in index.json): leer (Wenden/Raley), Kicker M+L wie Setup B, Slider-Park
  (rechts Full Pipe, Rail, A-Frame, Pipe; links 100 m Long Rail).
- **Jeder Start mit Countdown 3 – 2 – 1 – GO** (`Challenge.countdown`), dazu Ansage **englisch** „three, two, one, go“
  (`assets/sounds/countdown/`, Windows-Stimme Zira, Stille abgeschnitten; `Sfx.say_count`, spielt auch in der Pause): Competition fährt bei GO los (Szene läuft; auch nach R/☰ zurück zum Steg),
  Aufgaben stehen bis GO (SceneTree.paused).
- **Rail to Rail** (Modus id `r2r`, `kind: "r2r"`, `chain` = so viele Slider hintereinander, jeder per Transfer vom vorigen; Setup `setups/training_rail.json`): **Pipe to Pipe** (rechts außen kurz → innen lang) und **Pipe to Pipe to Pipe** (links drei versetzte Pipes zur Seilmitte); Messwert Meter auf dem letzten Slider (`slide_ended` mit `transfer`); zwischendurch Wasser = kein Wert. Test `--mode=r2r:1 --mode-auto --lane=8.5 --hop=-1,1` bzw. `--mode=r2r:2 --mode-auto --lane=-11.5 --hop=1,2` (Autopilot ca. 13,8 m bzw. 13,1 m).
- **Slider Special** und **Ollie in Boardslide Nosepress** (`kind: "special"`, `combo` je Slider; metric count = geschaffte Slider,
  sonst bester Messwert einer geschafften Station, z. B. Meter; fertig, sobald alle Stationen gewertet sind): Stationen = Slider-Gruppen (Full Pipe = 2 Teile) nach s; je
  Station Ollie on (Slide beginnt < 0,2 s nach Landung, nicht über die Auffahrt), Drehung on/out (halbe Drehungen), Stellung
  überwiegend, Press > halbe Slide-Zeit; Abgang wird gewertet, wenn das Brett wieder im Wasser ist. Test-Ausgabe `SPECIAL …`.
- **Filmteam** (`scripts/npcs/film_crew.gd`, Einstellung `film`: 0 Zufall, 1 Boot, 2 Drohne, 3 aus; pro Challenge gewählt): rotes
  **Kunststoffboot** von T2 (kein Schlauchboot; `FilmCrew.make_boat()`, auch am Liegeplatz in `beach.gd`) fährt auf der Spur
  x = −15 (Seeseite) 12 m vor dem Fahrer mit, bremst vor dem Spurende (15 m vor den Wendepunkten) und wartet, wendet immer
  über die Seeseite; Fahrer an der Pinne (`Person` "boat_driver"), Kamerafrau stehend ("filmer"). Motorgeräusch `Sfx.make_outboard_loop`
  (synthetisch, Zündstöße), Tonhöhe/Lautstärke nach Bootstempo. Oder **FPV-Drohne** vorne-seitlich
  über dem Fahrer, Pilot mit FPV-Brille und Funke an der vorderen Ecke des T2-Startstegs ("pilot"). Jeder Versuch setzt beides neu (`snap`). **Livebild + Fotos** (`scripts/ui/film_cam.gd`, eigener SubViewport in derselben Welt, rendert nur mit Filmteam): Vorschau links oben (Camcorder der Kamerafrau mit Auto-Zoom bzw. Action-Kamera der Drohne, kippt mit; **am Handy ausgeblendet**, `FilmCam.mobile`, Fotos gibt es trotzdem). Fotos im Versuch: Absprung, höchster Punkt, Landung (nach > 0,45 s Flug), Slider (0,35 s drauf), kein Sturzfoto; gewerteter Versuch: letzte 3 im Ergebnisfenster (`TaskPanel.show_result`, ohne Foto eins beim Ende). Headless keine Fotos; Log `FOTO n`.
- **Driften** (`kind` drift_spin / drift_turn / drift_after, `Rider.drifting`): 360er im Drift zwischen den roten Bojen (Brett-Yaw im Drift
  aufsummiert, je volle Umdrehung eine, links/rechts getrennt, höchstens `SPIN_EACH` 5 je Richtung; Drift lösen setzt zurück), Wende im Drift (Anteil vom Bremsen des Carriers bis das Seil wieder zieht,
  nur gleitend: Sinkpegel < `DRIFT_SINK` 0,15; ohne Schwung Silber, mit Rauskanten Gold), Drift nach Feature (T2 Juli & August, längster Drift,
  der bis 0,3 s nach Feature/Sprung beginnt), **Drift-Press** (**Nosepress vorübergehend aus**: `Rider.DPRESS_NOSE_ON` false, Challenges Nosepress/Press-Wechsel geparkt in `Training.NOSE_TASKS`; `kind: "dpress"`, `press` tail/nose/switch; immer T2 vor dem vorderen Wendepunkt, `turn: "a"`; voller Press ab `DPRESS_FULL` 0,6; **↓ drückt immer das in Fahrtrichtung hintere Ende** – switch (Tail voraus) ist alles gespiegelt (`Rider._dpress_lead`, beim Press-Beginn festgehalten; `_dpress_vis` relativ zur Fahrt, `_dpress_board()` am Brett für Pose/Kippung/Hände, Bezug +180°); im Press weiter Drift (Momentum bleibt), ←/→ dreht das Brett langsam (`DPRESS_TURN`), geht bei jedem Tempo; erlaubter Drift-Winkel zur **Fahrtrichtung** (`Rider._drift_angle`, **symmetrisch** links/rechts; Bezug `Rider.drift_ref_yaw`: das gedrückte Ende schleift hinten – Tailpress 0 = Nose in Fahrtrichtung, **Nosepress um `DPRESS_NOSE_REF` 90° versetzt** (0 = Brett quer, vorher eindrehen; Vorzeichen/Wert im F4 regelbar); ohne Press Nose oder Tail, was näher liegt) = unter `DPRESS_SPEED` nur bis zum Anfang des Sweet Spots (`DPRESS_FALL_ANG` − `DPRESS_SWEET`), ab `DPRESS_SPEED` bis `DPRESS_FALL_ANG` 86° (Übergang `DPRESS_SPEED_BAND` 1 m/s darunter) – `DPRESS_SPEED` ist also die Tempo-Schwelle für den Sweet Spot; darüber Sturz; **Sweet Spot**: fest (wandert nicht mit dem Tempo; zu langsam = erlaubter Winkel reicht nicht hinein) in den letzten `DPRESS_SWEET` 15° vor `DPRESS_FALL_ANG` bremst der Press nicht, darunter linear bis `DPRESS_DRAG` (längs voll); Bezug = geglättete Fahrtrichtung (`DPRESS_DIR_RATE`), unter `DPRESS_CRASH_MIN` 3 m/s kein Sturz (Seil dreht einen am Ende der Wende herum); Tail/Nose = **Anteil der Wende im vollen Press** (metric `press_share`, vom Bremsen des Carriers bis das Seil wieder zieht, nur gleitend Sinkpegel < 0,15, Absaufen = kein Wert; Gold 95 % – Technik: hart rauskanten, im Drift erst weit quer drehen, dann pressen), Wechsel = Nose↔Tail in einem Drift; Ende, wenn die Wende durch ist). Test ohne Autopilot (der driftet nicht): `--hold=release@1-40,steer_right@1-40`; Drift-Press: `--dpress-hold=GRAD` hält den Winkel automatisch (Ausgabe `DPRESS …`), z. B. `--mode=drift:4 --go=0.5 --dpress-hold=78 --hold=steer_right@3-3.5,steer_left@3.5-5.2,release@5.2-20,pitch_back@5.6-20` = 91 %.
- Test: `--mode=kicker:2 --go=0.5` (Fenster bestätigen), `--mode-auto` (Autopilot fährt), `--lane=X` (Spur halten),
  `--jump-at=S`. Ausgabe `CHALLENGE …: Wert Medaille N`. Kalibrierung: Autopilot schafft Wenden mit Bronze (ca. 46 % eingesunken, seit schnellerem Einsinken `SINK_RATE` 0,9),
  Kicker M ohne Absprung 1,6 m, mit Absprung bis 3,0 m (L 3,8 m), Full Pipe 13 m.

Geheime Erfolge (`scripts/achievements.gd`, Liste auf der Startseite Taste „Erfolge“, Meldung `Hud.show_achievement`):
- Immer **12 Plätze** (`SLOTS`), nicht erreichte ausgegraut („Geheim“, ohne Text); neue Erfolge hinten an `LIST` hängen.
  Gespeichert in user://settings.cfg [erfolge] (Datum); **Tests speichern nichts** (jedes Kommandozeilen-Argument).
  Freischalten über `main.gd _unlock_achievement(id)` (nicht hinter der Startseite). Test: `--screen=@erfolge --erfolg=fisch`.
- **Fischkontakt** (`fisch`): mit dem springenden Hecht zusammenstoßen (`Ambient.pike_hit`). Damit er erreichbar ist,
  springt er in `PIKE_CLOSE` 15 % der Fälle knapp vor dem Fahrer (±2 m daneben, hinlenken). Test `--pike-at=S` (genau in der Spur).
- **Nass gespritzt** (`sup`): mit > 6 m/s (`SPRAY_SPEED`) bis 3 m an einem SUP vorbei (`Ambient.sup_splashed`, Paddler wackelt).
  **Zwischen den Bahnen fährt nie ein SUP (verboten).** Zwei im Badebereich, zwei in der Seemitte (`SUP_CENTER`); ab und zu
  kommt einer herüber bis x = −12,5 (`SUP_COME_X`, nur einer gleichzeitig). Ab x = −18 legt das **rote Boot** ab
  (`FilmCrew.chase`, Modus "patrol", nur ohne Challenge, nur der Fahrer an Bord): Spur x = −19, hält 4 m seeseitig neben ihm,
  er paddelt zurück (`Ambient.send_back`), Boot legt wieder an. Test `--sup-at=S` (Log `BOOT …`).
- **Steg-Landung** (`steg`): aus der Luft (> 0,3 s) auf dem eigenen Startsteg landen (`Rider.landed_on_dock`). Mit 16 m Seil
  unerreichbar (Ufer-Wende 28 m), erst mit langem Seil (ab ca. 20 m). Test `--drop-at=2` (Fahrer über den Steg in die Luft).
- **Insekten fressen** (`insekt`): Mückenschwärme (`INSECT_S`, 3 m vor dem Waldrand rechts neben T1, 8–20 m vom Seil, Kopfhöhe)
  durchfahren (`Ambient.insect_eaten`). Test `--terminal=T1 --drop-at=8,40.1,0.3,-25.6`.
- **Boot crash** (`boot`): ins rote Boot fahren (= Sturz „Ins Boot gefahren!“) oder beim Sturz als Ragdoll hineinfallen
  (`main.gd _check_boat`, `FilmCrew.in_boat`: Rumpf-Grundriss, fahrend +0,25 m; schwimmend zählt nicht). Gilt für das Filmteam-/Patrouillen-Boot
  und das Boot am Liegeplatz. Innenboden hat einen Kollisionskörper (`LAYER_COLLIDE`), die Ragdoll bleibt im Boot liegen. Test `--drop-at=4,boot`.
- **Was ein Frechdachs** (`frechdachs`): Haubentaucher taucht vor einem ab (liegt in der Fahrspur, ±2,5 m) und hinter einem auf der anderen
  Seite wieder auf (`Wildlife.grebe_sneaked`). Einer lebt nahe der T2-Spur.
- **Schwanenliebe** (`schwanenliebe`): das Schwanenpaar formt mit den Hälsen ein Herz (alle 45–90 s, 11 s lang), Fahrer bis `HEART_SEE` 20 m dran.
  **Keine Tier-Ärgern-Erfolge** (Nutzerwunsch: nichts Tierquälerisches, lieber was Süßes; Schwäne weichen aus).
- **Zugvogel** (`zugvogel`): Raley-Absprung, während der Kranichzug über dem See ist (`Wildlife.cranes_overhead`, Okt./Nov., Feb./März).
- **Badegast** (`badegast`): Hitzetag, Luftmatratze nass spritzen wie beim SUP; ein „Schläfer“ treibt ab und zu bis x = −13,5 an die Bahn.
- **Arschbombe** (`arschbombe`, 12. und letzter Platz): aus der Luft gestürzt und ins Becken des 6-Stair Pools geklatscht (`Rider.pool_bomb`:
  Sturz im Flug, erster Platscher im Becken). Test `--erfolg=arschbombe`.
- **Blitzableiter** (`blitz`): Szenario „Gewitter – YOLO“ (nie gewürfelt): Blitze alle 3–9 s, 22 % knapp neben dem Fahrer, Volltreffer 1,5 %
  (frühestens 90 s nach Start/letztem Treffer) = Sturz „Vom Blitz getroffen!“ (`Storm`, Licht `Weather.flash`, Donner `Sfx.thunder` synthetisch).
- **Ho ho ho!** (`nikolaus`): am 6. Dezember im Schnee eine Wende schaffen (`Weather.is_nikolaus`, in `_track_turn`). Das Szenario
  „Nikolaus-Session“ (Schnee) kommt nur am echten 6. Dezember (dann immer); sonst Datum 6. Dezember + Wetter Schnee von Hand. Test `--scenario=nikolaus`.

Spiel (Competition):
- Runde **7:30** (Einstellung „Competition: Rundenlänge“), Start nach Countdown. Danach holt der Operator den Fahrer zum Start; man bleibt im Spiel, Ergebnis-Fenster (`main.gd round_panel`, `TaskPanel.show_round`): Punkte und Platz in der Rangliste groß, „Erneut spielen“ (Standard) / „Zurück“ (Startseite). Das HUD zeigt Punkte und 0:00 bis zum Neustart.
- **2-Mast-Prinzip: niemand muss zurück zum Start.** Seil verloren → kein Sturz, ausgleiten und
  einsinken. Nach Sturz bringt der Operator die Handle auf Höhe des Fahrers; schwimmen (Bauchlage,
  Kraulen, Brett hinten oben), greifen, **Deep-Water-Start** (liegen bleiben bis das Seil spannt,
  dann langsam aufstehen). Wasserstart immer Richtung des **weiter entfernten** Wendepunkts.
- Strafzeit: Strg nach Sturz −1:00 (sofort unter dem Seil weiter), R zurück zum Steg −2:00.
- Einsinken: Brett trägt nur mit Seilzug oder Tempo. Schlaffes Seil + langsam = absaufen (wie
  Wasserstart, keine Punkte für die Wende). Wende: 15 Punkte, außen um die weiße Boje 30.
- **Szenario** (`Weather.SCENARIOS`: Datum, Uhrzeit, Wetter, Extras `mist`/`rainbow`/`trails`; Name auf der Startseite unter
  „Wakeport Raunheim“): Auswahl **SZENARIO direkt im Startseiten-Menü** mit Shuffle-Taste daneben (würfelt sofort, stellt auf Zufällig; Symbol gezeichnet, `_draw_shuffle`) – die wenigsten gehen in die Einstellungen, Einstellung `scenario`,
  Standard „Zufällig“ = nach jedem Spiel neu gewürfelt, sobald die Startseite aufgeht (`main.gd _roll_scenario`, nie dasselbe zweimal;
  R/Neustart/nächste Challenge würfeln nicht). **Night Session** und **Blaue Stunde** werden nicht gewürfelt (`pick: false`; zu dunkel, vor allem im Web/am Handy → schwerer, unfair für die Rangliste), nur gezielt wählbar.
  Wetter/Datum/Uhrzeit von Hand (Einstellungen → Welt) bleiben bis zum Neustart. Vom Nutzer festgelegt: **After Hour Raley Session** (18. Aug.
  19:45 sonnig), **Early Bird Session** (8. Sep. 8:45 Dunst + Bodennebel), **Hochsommer. Was für eine Hitze** (6. Juli 12:00);
  dazu Regen, Nacht, Sonne hinter den Bäumen (Baumschatten halb über der Bahn), Nach dem Schauer (Regenbogen), Blaue Stunde,
  Goldener Oktober, Kondensstreifen; Nikolaus nur am 6. Dezember. Tests nehmen fest `afterhour` (`--scenario=ID`).
  Wetter/Uhrzeit werden nicht gespeichert, „Jetzt“ nur auf Knopfdruck.
- Jubel (und beim Sturz ein enttäuschter Ruf aus `assets/sounds/negativ`, 0,4 s danach): nur vom **eigenen Operator**, immer nur **ein** Ruf (kein neuer, solange einer läuft + 3 s).
- Flugzeuge: Anflug Frankfurt (Betriebsrichtung 07) tief über dem See. Geräusch **ohne reine Töne**
  (Pfeifen klang am Handy wie Piepen).

Punkte (Konstanten oben in `rider.gd`):
- **Slides vor Drehungen** (sonst „spin to win“). Slide: 150 + 150/s, Boardslide +100, Press +100,
  Rail/Pipe ×1,5, Transition Rail ×1,3. Air: 50/s Flugzeit, 50 pro 180°. Raley +150,
  Front-/Backroll je 300.
- **Kombination**: nächster Trick innerhalb 3 s Fahrt → 2. Trick ×2, 3. ×3 … Sturz/Absaufen beendet.

Steuerung Desktop (Mobil-Code darf Desktop-Eingabe nie beeinflussen, siehe unten):
- ←/→ (A/D) lenken; in der Luft, beim Raley und auf dem Slider drehen (Slider dreht schnell).
- ↑/↓ (W/S): in der Luft **Frontroll/Backroll**; auf dem Slider **Nose-/Tailpress** (kippt entlang
  der Brettlänge, also quer bei quergestelltem Brett).
  **Press vormerken** (`Rider._prepress`, `_slider_landing_time`): bei ↑/↓ in der Luft wird die Flugbahn vorausgerechnet (Schwerkraft + Seil, alle `PREPRESS_EVERY` 0,1 s); endet sie auf einem Slider (Fangzone oder Slide-Fläche) und reicht die Zeit nicht mehr für die (restliche) Rolle (`(TAU − FLIP_LAND_TOL − |flip|) / FLIP_RATE × PREPRESS_MARGIN`), gibt es keine Rolle (bis `FLIP_PRESS_MAX` angefangene wird zurückgenommen), das Brett kippt schon in der Luft (`PREPRESS_TILT`), Landung direkt im Press. Sonst Rolle. **Keine Sperre beim Abspringen** vom Slider: ↑/↓ gehalten = gleich Rolle; nur ohne Absprung übers Ende gerutscht bleibt der Press. Sprung-Start sperrt weiter (`_flip_lock`, ↓ vom Gegenhalten).
- Leertaste: halten + loslassen = Sprung; startet auch die Anlage (dann ohne Sprung). Im Spiel kein Enter (Enter = Start nur in Menüs).
  **Nach Sturz: Leertaste halten = schwimmen, Strg = sofort weiter (−1:00), R = Steg (−2:00)** –
  angezeigt in einem Panel mit Zeitkosten (`Hud.show_recovery`) – erst nach `RECOVERY_DELAY` 5 s (main.gd, man soll den Sturz sehen) und nur, wenn man bis dahin weder schwimmt noch eine Taste drückt; weich eingeblendet (`Hud.fade_in`, auch das Challenge-Fenster)
- Strg (zur Not Alt): **Driften** – keine Kante greift: Lenken ändert die Fahrtrichtung nicht, nur der
  Seilzug zieht einen (nicht festnageln, sonst reißt das Seil); das Seil ist im Drift **keine Feder, sondern fest wie beim Kettenkarussell** (`Rider._drift_rope`: fängt nur die Bewegung vom Carrier weg weich ab, `DRIFT_ROPE_GIVE`; Radius = gedehnte Länge beim Drift-Start, wird nie länger und **zieht nie aktiv rein** (`DRIFT_ROPE_SETTLE` 0 – früheres Reinziehen fraß den Schwung nach außen); der Schwung nach außen geht über das Seil in Vorwärtsfahrt über, kein Schnalzen nach vorne), ←/→ drehen nur das Brett, Wasserwiderstand × `DRIFT_DRAG` 0.7 (leicht schneller), Brett dreht im Drift schneller (`DRIFT_SPIN`). Nur Spieler,
  Autopilot/NPC driften wie früher. „Maximaler Grip“ gibt es nicht mehr.
- **Esc = Pause** (`scripts/ui/pause_menu.gd`, SceneTree.paused; Fenster Weiter/Einstellungen/Hilfe/Startseite). **Einstellungen im Spiel**: Pause-Fenster bzw. ☰-Menü öffnet nur das Einstellungs-Fenster der Startseite (`StartScreen.open_settings_ingame`, ohne Menü/Kamera, Spiel bleibt pausiert, danach zurück ins Pause-Fenster bzw. ☰; `main.gd _open_settings_ingame`; Test `--settings-at=S`). Am Handy
  pausiert das offene ☰-Menü (TouchPad/MobileInput laufen mit PROCESS_MODE_ALWAYS). Test `--pause-at=S`.
- **Sprung-Start** (nur auf dem Startsteg, `Rider._step_dock_start`): ↓ halten (Handy ▼) = gegen das anfahrende Seil stemmen
  (Fahrer bleibt stehen, Seilzug steigt). Bei `DOCK_BRACE_MAX` 90 % der Seilzug-Grenze reißt das Seil los: die gedehnte Leine
  schleudert einen nach vorne, sobald die Spannung raus ist (spätestens an der Stegkante) Absprung = voller Sprung + `DOCK_YANK_LIFT`;
  +100. Vorher loslassen = ohne Sprung. Nur Spieler. **↓ ist immer der Auslöser, egal wie das Brett steht**: Stellung beim Riss
  längs zum Seil (bis 45°, `DOCK_QUER`) = **Nolli**, quer = **Raley Start** (Raley-Schwung, Brett bleibt quer bis `DOCK_RALEY_PHASE`,
  Haltung: tief auf der Kante, Brust zum Seil); Auflade-Power × Genauigkeit². Beim Gegenhalten dreht das Brett nicht zum Seil, beim Riss
  ist der Steg quer so rutschig wie längs. Challenge-Modus **Sprung-Start** (`kind: "dock"`, `jump`, `start: {dock: true}`: Steg, Anlage
  startet bei GO). Test: `--autotest --passive --hold=pitch_back@0-15[,steer_right@0-1.55]`, `--mode=sprungstart:N`.
  **Nolli-Animation** nach Fotoserie: beim Riss Oberkörper nach vorne zum Griff, Brett kippt um die Nose (Ende Richtung Seil,
  `_nolli_lead`) bis `NOLLI_ANG` ca. 60°, Tail hoch, Knie angezogen (Becken macht nur `NOLLI_PELVIS` mit); in der ersten
  Flughälfte wieder flach.
- R, + / −, C, P, H, M, Tab (Startseite) wie in der README. **Keine Tasten T/F** mehr (Terminal/Setup nur auf der Startseite).

Steuerung Handy: lenken mit ← / → (Standard `steer` 1 Tasten; Gyro = Neigen wählbar), Tippen = Start, **Springen nur mit der SPRUNG-Taste (links)**,
DRIFT links über SPRUNG (damit rechts gleichzeitig ▲ ▼ für den Drift-Press geht); nach Sturz Bildschirm halten = schwimmen, DRIFT = sofort weiter;
☰-Menü (Weiter, Einstellungen, Hilfe, Zurück zum Steg, Startseite, Ton, Szenario würfeln); ☰ sitzt **links oben an der HUD-Leiste, nie darin** (`TouchPad._place_menu_button`: **links direkt unter der Leiste** (6 px Abstand), bündig mit ihrer linken Kante, keine feste Position; Aufgabenzeile, Brettzustand und Punkte-Zuwachs rücken rechts daneben (`Hud.left_right`, Aufgabenzeile bricht dann um), Livebild darunter (`Hud.left_reserved`)), Striche selbst gezeichnet (das Zeichen fehlt in der Web-Schrift). Terminal/Setup nur auf der Startseite.
**Handy hochkant** (es wird meist hochkant gespielt): HUD-Leiste **zweispaltig** (links Zeit über Punkte, rechts Seilzug über Tempo, `Hud._arrange_bar`), über die ganze Breite skaliert; Aufgabenzeile, Brettzustand, Livebild des Filmteams und ☰ rücken unter die echte Unterkante (`Hud.bar_bottom`/`info_bottom`). Sturz-Panel hochkant zweispaltig (Taste | Aktion + Kosten darunter), Titel zweizeilig, volle Breite.
**Mobil-Code strikt isolieren**: nur Aktionen loslassen, die er selbst gedrückt hat, nichts
global; Web-Audio-Hacks nur auf Touch-Geräten (früher hakte sonst die Desktop-Tastatur).

Tricks/Optik:
- **Ollie** = normaler Sprung aus dem Wasser; Name nach Absprung (`Rider._launch_surface`): Ollie / **Kicker Air** / **Safety Air**. Haltung: in der Luft am höchsten Punkt am tiefsten in den Knien (`AIR_KNEES`), vor der Landung gestreckt, Landung abfedern (`LAND_TIME`). **Raley** nur mit viel Seilzug: ≥ `RALEY_TENSION` 3358 N beim Absprung (Marke RALEY in der Seilzug-Anzeige, F4), Sprung aufgeladen ≥ `RALEY_LOAD` 0,8; Höhe = voller Sprung + `RALEY_ROPE` je 1000 N über der Schwelle + `RALEY_PER_SPEED` × Tempo (bis `RALEY_MAX_VY`); Ollie wächst kaum mit dem Tempo (`POP_ROPE` klein),
  **kein Feature voraus** (damit man schräg auf Features springen kann). Pose nach Fotoserie:
  Körper schwingt um den Griff, am höchsten Punkt kopfüber unter dem Brett, Hohlkreuz, Knie
  angewinkelt, **Griff vor dem Gesicht** mit angewinkelten Armen (nicht hinter dem Kopf).
- **Frontroll eingerollt** (Knie zur Brust), **Backroll gestreckt** – beides nur bei normalen Sprüngen (Ollie, Kicker …).
- **Inverts** (`Rider._invert`): aus dem Raley-Absprung gibt es keinen Frontroll/Backroll. ↑/↓ nur ganz am Anfang
  (`INVERT_PICK`, gehaltene Taste vom Steg zählt erst nach Loslassen) wählen den Trick, sonst Raley:
  **↑ = S-Bend** (Anfang/Ende wie Raley; gestreckt oben eine ganze Drehung um die Achse **Handle → Brett**: Drehpunkt ist
  die Handle, die Hände bleiben dort, der ganze Körper dreht sich darum – `_sbend_pivot`; langsam, `SBEND_FROM/TO` ca. halbe Flugzeit), **↓ = Backroll** als Invert (ganz anders als vom Kicker: kein Schwung um den Griff, seitlich nach
  außen kopfüber um die eigene Achse, `IBACK_*`, noch grob – wird später verfeinert). Je +300 (`INVERT_POINTS`) zum Raley.
  **Regel: erst wenn ein Invert fast fertig ist, kann ein weiterer Trick folgen** – Drehen (←/→) erst ab
  `INVERT_SPIN_RALEY` (Körper halb zur Landung zurück) bzw. `INVERT_SPIN_BACK`. **←/→ nach der Streckung** (`RALEY_STRETCH`;
  S-Bend: nach der Längsdrehung) **bricht den Raley-Schwung ab** (`_raley_cut`, schnell zurück mit `RALEY_CUT_RATE`), gedreht wird
  erst aufrecht (`RALEY_SPIN_ANG`) – damit die Drehung in aufrechter Haltung passiert. Immer normales Drehtempo – eine 313 danach soll sauschwer sein (nur mit sehr viel Höhe).
  Namen: Raley 180 links = **Blind Judge**, rechts = **Krypt**; Raley 360 links = **313**, rechts = **BS 313**;
  S-Bend + 180 links = **S-Bend to Blind** (Abbruch schon ab `SBEND_CUT`, wenn die Drehung um die Handle fast fertig ist;
  nur mit viel Höhe, ca. 2 m); sonst mit Drehung „S-Bend 180“ usw. Invert-Backroll heißt im Menü „Backroll (todo)“.
- **Press-Pose aus Blender** (Nutzer posiert selbst): `blender/*.blend` (Godot ignoriert den Ordner) -> `tools/export_pose.py` (Nutzer: `.	oolsexport_poses.ps1` in PowerShell, exportiert alle)
  (Blender 5.2 im Hintergrund, IK ausgewertet) -> `assets/poses/nosepress.json`. Übernommen: Becken (Lage im Brettraum),
  Rücken, Kopf, Arme; Füße per IK in den Bindungen, Hände Faust, Handle in der vorderen Hand. 50-50-Tailpress: eigene Pose `tailpress.json` (aus `blender/tailpress.blend`), Boardslide-Tailpress/Goofy gespiegelt,
  Press relativ zur Fahrtrichtung (switch). Animierter Root läuft in Schleife. Vorlage: `blender/nosepress_vorlage.glb`.
  Weitere Vorlagen (aus nosepress.blend abgeleitet, Foto als `Referenz_Foto` eingepackt, Pfeil `Fahrtrichtung`, Nutzer posiert nach):
  `tailpress` (50-50), `bs_vorwaerts_/bs_rueckwaerts_` + `nosepress`/`tailpress` (Boardslide; vorwärts = Brust in Fahrtrichtung).
  Noch nicht im Spiel verwendet – bisher nur nosepress.json (gespiegelt für Tailpress). Im Spiel kippt das Brett um Nose/Tail,
  beim Boardslide-Press rücken Fahrer und Brett seitlich, bis Nose bzw. Tail über dem Slider liegt (`_press_bs_vis`;
  Vorlagen: Rail quer unter Nose bzw. Tail, 22 cm vor der Spitze).
- **Kamera** (Verfolger): auf dem Slider 70 % Abstand, beim Press 50 % (Handy hochkant ×1,35) schräg von hinten auf der Brustseite, Blick in Fahrtrichtung
  (`PRESS_BEHIND`; „vorne“ heißt beim Nutzer: in Fahrtrichtung sehen), Blick zwischen Becken (`Rider.press_body`) und gedrücktem Brett-Ende (`Rider.press_tip`); danach weich zurück.
  Der Blickpunkt zieht mit der Fahrgeschwindigkeit mit (sonst hängt er von der Seite sichtbar ca. 1 m hinterher).
- Handle beim Press immer in der vorderen Hand (auch 50-50-Tailpress, obwohl die Pose gespiegelt ist).
- **Handle Pass** (Seil geht nie durch den Körper): die Handle bleibt beim Seil, der Körper dreht sich darunter weg
  (`Rider._process` „Griff, Arme, Seil“, `_pose_arms`). Brust voran gedreht wandert sie vorne herum (beide Hände), Rücken voran
  hinter dem Rücken: dort hält nur die Hand auf ihrer Seite, in der Rückenmitte Übergabe an die andere. Welche Hand loslässt,
  folgt aus der Lage (Griffende hinter der Brust auf der fremden Körperseite), vorausschauend nach Drehtempo, zeitlich geglättet
  (`HPASS_RATE`); Griff und Hände bleiben außerhalb des Rumpfes (`_torso_out`, `TORSO_DEPTH`/`TORSO_WIDTH`). Switch/Goofy
  spiegeln sich von selbst. Nicht bei Raley, Inverts, Wasserstart.
- Nach Sturz/Absaufen/Neustart wird Raley/Überschlag/Press sofort zurückgesetzt.
- Features haben **Kollisionskörper** aus ihrer Form (`FeaturePart._build_collider`, Ebene `LAYER_COLLIDE`):
  **massive konvexe Säulen** aus `height_local()` bis 1,5 m unter Wasser (`COLLIDE_BOTTOM`; früher hohles Dreiecksnetz –
  Ragdoll rutschte durch, fiel unter das Feature, eingeklemmte Knochen zerrissen die Figur), nasses Plastik federt (bounce 0,3).
  Die Ragdoll prallt ab bzw. bleibt darauf liegen. Fahrphysik nutzt weiter `height_local()`. Physik-Engine **Jolt** (project.godot).
- **Sturz ins Wasser** (`scripts/ragdoll.gd`): Wasser ist keine Fläche (sah aus wie eine Steinplatte), sondern wirkt je Knochen
  nach Eintauchtiefe – Auftrieb (Weste `BUOY_TORSO`), Widerstand linear + quadratisch: man klatscht hinein, taucht kurz unter,
  kommt hoch, prallt nicht ab. Eintauchen = Platscher (`Rider._body_splash`: Spritzer-Kranz, Welle, Ton nach Wucht), schnell
  durchs Wasser rutschen = Gischt (`_crash_spray`), harter Treffer am Feature = dumpfer Schlag. Test `--ragdoll-at=S,side|top|water`.
- **Schwimmen nie durch Features**: Weg großzügig herum (`SWIM_MARGIN` 2 m, `FeatureSet.swim_path`,
  Sichtgraph + Dijkstra, alle 0,4 s neu), harte Grenze `push_out` (0,3 m). Hinter einem Feature zu
  stürzen kostet also mehr Schwimmzeit – gewollt. Die Panel-Schwimmzeit rechnet mit dem Umweg.
  Geschwommen wird **in runden Bögen** wie ein Mensch, nicht Ecke für Ecke: Zielpunkt 2,5 m voraus auf dem
  Weg (`SWIM_LOOKAHEAD`), Schwimmrichtung dreht höchstens `SWIM_TURN` 1,2 rad/s.
- **Fangzone der Slider** (Rail, Pipe, schmale Ledge ≤ 1 m, Rail im Transition Rail): ±0,55 m seitlich,
  0,45 m unter bis 1,3 m über der Oberkante (`FeaturePart.CATCH_*`). Wann ↑/↓ statt Rolle den Press vormerkt, entscheidet die Flugbahn, nicht die Zone (siehe Steuerung Desktop, „Press vormerken“). Wer im Sinkflug hineinkommt, gleitet
  seitlich/nach oben auf die Slide-Linie (`Rider._catch_glide`), kein Hochspringen. Gehört zur Hilfe
  „Einloggen“. Debug: **F3** bzw. `--hitbox` blendet ein: Fangzonen **gelb**, glattes Plastik **blau**, Safety/Auffahrt und
  Kicker **orange** (fährt man wie einen Kicker).
- **Rail to Rail** (`Rider._hop`): auf dem Slider beim Laden (Leertaste gehalten) wählt ←/→ die Seite (`_hop_side`, kein Umspringen); beim Absprung kommt quer zur Fahrtrichtung Tempo dazu: steht bis `HOP_RANGE` 2,8 m (Achse zu Achse) ein Nachbar-Slider (`_hop_target`, `FeaturePart.line_point`), so viel, dass man bei der Landung auf seiner Linie ist (höchstens `HOP_MAX`), sonst `HOP_SPEED` 1,2 m/s. Die Fangzone des Absprung-Sliders zählt in diesem Flug nicht (`_hop_from`, `FeatureSet.catch_at(world, skip)`, Modul = `FeaturePart.same_module`). Gehaltenes ←/→ dreht in der Luft erst nach dem Loslassen (`_hop_steer_lock`). Der Fahrer lehnt sich zur Hop-Seite (`_hop_dir`, Körper und Brett kippen mit): beim Laden `HOP_LEAN_LOAD` 0,2 rad, im Absprung `HOP_LEAN` 0,55 rad, ab der Flugmitte zurück – sonst verschob er sich nur waagrecht (unnatürlich). Direkt auf einem anderen Slider gelandet = **Transfer**: der Slide davor endet sofort (`_finish_slide`, auch sonst beim Wechsel auf ein anderes Modul), der neue heißt „Transfer …“, +`TRANSFER_BONUS` 100. Test `--hop=±1[,N]` (Autopilot springt auf jedem Slider gleich seitlich ab). Setup **Raildorado** (`setup_raildorado.json`, beide Terminals gleich): nur Slider, viele Paare/Dreier mit 0,5–1 m Lücke.
- **Brettstellung auf dem Slider rastet ein** (`Rider._slide_orient`): beim Draufkommen in die nächste Stellung:
  bis 45° zur Achse (`SNAP_5050`) 50-50, darüber Boardslide (früher 12° – schräges Aufspringen ergab ungewollt Boardslide). Auf dem Slider dreht ←/→ (Handy:
  deutlich neigen) je Tipp 90° (Boardslide ↔ 50-50), nicht stufenlos; Wechsel geben `SWITCH_BONUS` 80 und
  stehen im Namen („Boardslide to 50-50 – Rail“). Autopilot/NPC springen nicht um.
- **Abgang quer** (Brett > 50° zur Fahrtrichtung) vom Feature ins Wasser oder quer gelandet = Sturz, außer mit **Drift**
  (Strg) – dann rutscht es quer weiter (`Rider.last_exit_drift`). Autopilot/NPC ausgenommen.
- **Luft-Hilfe** (`AIR_ASSIST`): ohne Lenken dreht das Brett in der Luft zur Flugrichtung zurück – **nicht**, wenn ein Slider
  bis 8 m voraus auf dem Flugweg liegt (`FeatureSet.slider_ahead`, nur Spieler): sonst wäre die Vierteldrehung für den
  Boardslide beim Aufspringen wieder weg. Gelandet wird per Einrasten (nächste Stellung).
- Slider **einloggen** (Auto-Rutschen): bis 35° Abweichung richtet das System die Fahrtrichtung
  entlang des Features aus und zieht zur Spur; erst darüber rutscht man ab.
- Sprung aufladen: stufenlos tiefer in die Knie.
- Sprunghöhe (`POP_SCALE` 0.93, Ollie ca. 1,1 m – „ist ja ein Spiel“, etwas mehr Power); an der Rampe kommt der Absprung nicht voll
  obendrauf (`POP_ON_RAMP`). **Kicker-Absprung hängt vom Winkel an der Kante ab** (`_lip_slope`,
  `KICK_REF`): je steiler, desto höher, überproportional – über der Kante bei 8 m/s (`KICK_REF` 0.31) ca. Kicker M 0,5 m ohne Absprung.
  **Absprung auf dem Kicker: Höhe = Steigung (mit Tempo) + Sprungkraft** (`_kick_vy` + `POP_ON_KICK` 0.6 ×
  Ollie-Schub): z. B. Kicker M an der Kante abgesprungen ca. 2,1 m über der Kante (ohne Absprung 0,5 m).
- **Glattes Plastik** (`"slick"` in parts.json): Pyramid oben, Transition des Transition Rails,
  Ollie Box (nicht die Ledge), Bump nur die flache Spitze (`"slick": "top"`; alle
  Seiten des Bumps sind Kicker). **Safetys/Auffahrten** (`ramp_in`/`ramp_out`, z. B.
  vorne/hinten an der Ollie Box) und die ganze **Transition Curb** (`"kicker": true`) fährt man wie einen **Kicker**: nie glatt,
  kein Slide, keine Slide-Punkte, kein Einloggen (`FeaturePart.on_ramp`). Glatt heißt sonst: kein
  Slide, keine Punkte, man rutscht in der bisherigen Richtung weiter und kann nicht lenken. Das Rail
  im Transition Rail bleibt slidebar.

Features/Setups:
- **Hack** = mehrere Features, die zusammenstehen (≤ 0,8 m). Gängige Kombinationen heißen **nicht**
  „Hack“: Module aus mehreren Teilen (`group_name`, z. B. Pyramid Series, Spine Kicker, Port
  Plaza), Ollie Box + Ollie Box Ledge, Kicker nebeneinander.
- Zwei Cheese Wedges zusammen stehen immer **Rücken an Rücken** (zweiter mit `dir` andersherum).
- Down Ledge: 20 m, Profil `[[0,-0.1],[1.0,0.5],[5.5,1.9],[19.5,0.8],[20,-0.15]]` (kleine Safety
  vorne, steil hoch, lang abfallend, hintere Safety bis ins Wasser). Kein Add-on-Rail.
- A-Frame Rail (Pyramid Series): 0,6 m breit, oben ganz schwarzes Halbrund-Rail, gerade hoch / flache Mitte / gerade runter,
  vorne/hinten steile gerade Safety, die ins Halbrund schneidet (`top_rail`, `safety_slope`); Oberkante 1,5 m.
  Pyramid: 5 Flächen (`FeaturePart._build_pyramid`) – Transitions vorne/hinten (`ramp_curve` 1,6) und seitlich auf der Seilseite (`side_curve` 1,1), alle beginnen unter Wasser; jede ist eine eigene, verlängerte Fläche, ineinandergeschoben (Minimum in `height_local`) – die Schnittlinie ist der scharfe, geschwungene Grat; Top mit klaren Kanten; hinten senkrechte Wand.
- Pop auf Rampen/Kickern nie schwächer als ein Ollie (`Rider._pop`).
- **Port Plaza** = ein Modul (kein eigener Plaza Kicker), Slider mit halbrunder Oberkante (0,9 → 1,55 m), vorne/hinten
  steile gerade Safety ins Halbrund (wie A-Frame Rail), hinten breiter Teil aus Safety 1,2 m + Kicker-Schräge 2,35 m auf 1,1 m; dahinter meist ein normaler Cheese Wedge (1,1 m, keine eigene Höhe) – Plaza + Wedge ist kein Hack.
  Interne Teile `_plaza_*` (mit `_` = nicht im Editor).
- Uprail 7,5 m. Transition Rail: 4 m breit, Körper 1,235 m, flacher Abschluss 36 cm (`TR_FLAT`), darauf ein dickes schwarzes Rail (46 cm, `TR_RAIL_R`): steht
  außen ca. 5 cm über, zur Transition nur 1,5 cm (`TR_TUCK`), nur das untere Viertel steckt im Körper (Oberkante 1,58 m). Seitlich von der Transition ohne Sprung aufs Rail: Fahrphysik hat dort eine weiche Auffahrt (`_tr_lip`, ab `TR_LIP` 0,3 m vor dem Transitions-Ende), sonst wäre die Stufe ein Sturz. Setup-Positionen beziehen sich auf die alte Breite 3,2 m (`FeatureSet.TR_REF_WIDTH`):
  breiter wird es nur zur Seilseite, Rail und Rückwand bleiben, wo Nachbarn anschließen. Rampen vorne/hinten gerade, von allen Seiten befahrbar, löst keinen Sturz aus.
  Grafik aus genau seinen Flächen (`FeaturePart._build_transition_body` / `_build_transition_rail`): Rampen als Ebenen bis exakt auf die Schnittkante (von vorne = Querschnitt), Transition läuft unter dem Überstand weiter, Rail-Rohr von der Rampenebene abgeschnitten (verschmilzt mit der Rampe, setzt sich zur Transition mit der Rundung ab); ohne Rampe hinten (1/2) Wand mit Querschnitt.
- **6-Stair Pool** (UNIT 6SP001, `stair_pool_6`, Utopia, Pool Party, Challenge Pool): Rampe 5 m auf den Rand 1,35 m, Becken 15 × 3,8 m mit **echtem
  Wasser** auf 1,1 m (Typ `pool`: `Water.height_at` liefert im Becken dessen Spiegel + Grundwellen + eigene Kreiswellen
  `_pool_points` (Heckwelle, Landung, Sturz nur im Becken), `FeatureSet.pool_level`, `water.features`; Wasserfläche mit dem
  **See-Shader** (`Water._pool_material`, gleiche Farbe/Effekte; Editor/Vorschau Ersatz `pool_water.gdshader`); Fahren, Landen,
  Einsinken, Gischt, Ragdoll wie auf dem See; Boden nur als Kollision), Rand = Ledge `_pool_coping`. Slider der Ausgänge
  **40 cm höher als der Rand** (1,75 m), vorne eine steile Safety ab Randhöhe (`safety_h` 1,35, `safety_slope`), beim Rail schneidet
  sie ins Halbrund wie beim A-Frame; hinten senkrecht. Am Ende zwei
  Ausgänge (verschachtelte Gruppen `_6sp_*` mit `"pool_exit"`, `@left`/`@right`, Zeile `exit_left`/`exit_right`, `mirror_x`), je Treppe
  innen (Typ `stairs`, 6 Stufen, Physik = Linie über die Stufenkanten) + Ledge/Rail außen. **Treppe nur im Drift** (Strg), hoch wie
  runter, dann glatt wie die Ollie Box; ohne Drift Sturz „Treppe nur im Drift!“ (nur Spieler). Sturz im Becken: schwimmt zur Treppe
  und darüber hinaus (`pool_zone_at`, `pool_exit`, dort kein `push_out`). Maße teils aus Renderbildern geschätzt (Nutzer festgelegt:
  Wasser nicht bündig mit dem Rand, Rest unter Wasser, beide Richtungen befahrbar).
- **Pool-Tricks** (`Rider._pool_jump`, `_track_stairs`, Konstanten `POOL_*`/`STAIR_*`/`COPING_LINK_*`, Signal `pool_trick` mit id/name/points/
  height/width/speed/dist): Pool Drop +100, Pool Gap +400 (Landung hinter dem Becken; bei 30 km/h kaum zu schaffen), Stair Gap +200
  (Landung hinter der Treppe, `FeatureSet.pool_stairs_end`), Stair Drift 150 / Stair Climb 250 (beim Verlassen der Treppe auf der
  anderen Seite), Pool Coping to … +150 (Ausgang beginnt bis `COPING_LINK_GAP` 1,5 s nach dem Rand-Slide). Alle in der Kombination.
- Pools stehen in **Utopia** (T2 s 87,3 rechts; T1 s 99,5 x 11,5 mit Donkey Rail / Double Kinked Ledge), im Setup **Pool Party** (T2 zwei,
  einer zum Steg mit Double Kinked Rail / Flat Down Ledge; T1 einer mit Low to High Rail / Flat Down Ledge) und im Challenge-Setup
  `training_pool.json` (Pool A rechts s 65, Pool B rechts s 120, Pool C links s 65). Challenge-Modus **Pool** (`kind: "pool"`, `trick`
  = gemessener Pool-Trick, `special` mit `need` = Punkte; Messwert `speed` in km/h), dazu Ausgangs-Serie als `kind: "slide"`.
- Schwimmen: liegt die Handle im Sicherheitsabstand eines Features, plant der Weg mit 0,35 m drum herum; Ecken werden erst abgehakt und
  der Zielpunkt voraus nur angepeilt, wenn der Weg dorthin frei ist (`FeatureSet.swim_clear`) – sonst schwamm man gegen dünne Teile.
- Positionen kommen aus den Plan-Fotos (`fotos/`); die Pläne sind nicht maßstäblich, Maße aus
  dem Katalog. Beim Nachstellen von Hacks: vorne/hinten und Seiten genau mit dem Foto abgleichen.
- T1-Steg ist 5 cm höher als T2 (`Lake.DOCK_T1_Y`).

Einstellungen (`scripts/game_settings.gd`, Reiter Spiel/Fahrer/Welt/Technik/Wasser/Musik in `start_screen.gd`,
angewendet in `main.gd` `_apply_setting`): Spielmodus Runde 7:30 / 10:00 / 15:00 / Freies Fahren (keine Uhr, HUD zeigt „MODUS FREI“), Hilfen
(Einloggen, Überschlag ausdrehen; je aus +15 %), Seilzug-Grenze (nur An/Aus, damit die Rangliste fair ist; früher locker/streng werden beim Laden zu An; Taste G
und ☰-Menü schalten Abreißen an/aus), Brett, Stance Regular/Goofy, Helm,
Weste, Seillänge, Anlagen-Tempo, Flugzeuge, NPC, Grafik, Lautstärken (Busse Effekte/Jubel/Flugzeuge),
Kamera, Handy-Neigung. Gespeichert in user://settings.cfg [optionen]; Wetter/Uhrzeit **nicht**. **Nur Abweichungen vom Standard werden
gespeichert** (`save_file`). **Standardwert ändern**: Wert in `DEFAULTS` ändern und in `GameSettings.DEFAULT_CHANGES` eine
neue Version mit dem **alten** Wert anhängen (z. B. `2: {"cam_dist": 5.0}`) – ältere Dateien enthalten noch alle Werte; steht
dort noch der alte Standard, gilt der neue, bewusst anders eingestellte Werte bleiben (Version in [optionen] `ver`).
Test: `--set=NAME=WERT` (ohne Speichern), `--screen=@einstellungenN` (Reiter N).

**Nutzungsstatistik** (`scripts/analytics.gd`, GoatCounter-Seite `kimpixel`, Auswertung https://kimpixel.goatcounter.com): nur Web-Hauptversion (nicht lokal, PR-Vorschau, Tests), count.js wird per JavaScriptBridge geladen; Ereignisse als Pfade `Analytics.count("start/…")` (Start, `runde/ende/…`, `challenge/MODUS/ID/MEDAILLE`, `erfolg/ID`, `editor`, `geraet/…`, `spielzeit/Nmin`). Keine personenbezogenen Daten.

**Rangliste** (`scripts/leaderboard.gd`, Server `server/` = Cloudflare Worker + D1, Anleitung `server/README.md`; Adresse in `Leaderboard.URL`, leer = „noch nicht eingerichtet“):
Ranglisten je Challenge (`ch/MODUS/ID`) und Competition (`comp/SEK/TERMINAL/SETUP`, nur 30 km/h, 16 m, kein Freies Fahren, keine eigenen Setups). **Seilzug-Grenze Aus = keine Rangliste** (auch Challenges; Hinweis an allen Schaltern: Einstellung, G, ☰, Hilfe).
Der Server kennt keine Aufgaben: die **Wertungs-Version** `ver` rechnet das Spiel (Hash der Aufgabe ohne Texte/Medaillen + Features des Setups mit benutzten Bauteilen) –
ändert sich eine Aufgabe/ein Setup, beginnt deren Rangliste automatisch neu. **Physik oder Punkte geändert, sodass alte Werte nicht vergleichbar sind → `Leaderboard.RULES` erhöhen**
(alle neu) bzw. `"lb": N` in einer Aufgabe (nur diese). Jedes gewertete Ergebnis wird eingetragen, ohne Namen anonym („Anonym #XXXX“ aus dem Schlüssel, Server `displayName`), mit Namen (Startseite → Rangliste) alle Einträge des Geräts unter diesem Namen; Schalter „In der Rangliste erscheinen“ Aus = alles auf dem Server löschen und nichts mehr senden (`Leaderboard.hidden`, [rangliste] hidden); echte Einträge aus der Web-Hauptversion **und vom lokalen Spiel am Desktop** (Nutzer spielt lokal mit eigenem Namen mit und sieht die Online-Daten; unveröffentlichte Wertungs-Änderungen landen dabei in einer neuen Rangliste),
nur PR-Vorschauen in Test-Ranglisten (`dev-…`, Name „ dev“); Tests senden nichts außer mit `--lb-url=http://127.0.0.1:8787 --lb-name=X [--lb-id=32HEX]` (feste Geräte-Nummer, dann ist der eigene Eintrag sichtbar; lokal `npx wrangler dev --local` in `server/`, Log `RANGLISTE …`). Fenster: Auswahl der Disziplinen im Kopf (Competition 7:30, Challenges je Modus, Competition 10:00/15:00), **nur die mit Einträgen** (Server `/boards`, bei Fehler alle); vorgewählt das gewählte Spiel, sonst die erste. Test-Bild `--screen=@rangliste[N][+]` (Zeile N, + = Liste offen).
Handy im Browser: Name per `prompt()` (LineEdit hat dort keine Bildschirmtastatur).
**Mini-Rangliste im Spiel** (`scripts/ui/mini_rank.gd`, in `Hud.mini_rank`, rechts in der Mitte; Daten aus `main.gd _step_mini_rank`, je Sekunde geprüft, alle 60 s neu geladen, beste 50): erste 3 + eigene Position mit Nachbarn, dazwischen „…“; Competition: eigene Zeile **DU live** mit den Punkten der Runde (auch vor dem Start mit 0, nach dem Ende bleibt der Endstand bis „Erneut spielen“), dazu gedämpft **BESTWERT** = eigener bisheriger Eintrag mit echtem Platz und Wert, Challenge: eigener Bestwert bzw. „DU –“; immer schmal am Rand im Kasten mit wenig Innenabstand: Desktop/quer Platz + Name, Wert klein in der zweiten Zeile; Handy hochkant nur die Plätze untereinander, keine Werte (eigene Punkte stehen oben), am Handy zwischen ☰ und den Tasten unten rechts; Werte kurz (`Leaderboard.format_short`). Nur wenn die Rangliste gilt (nicht Freies Fahren/Seilzug aus/andere Anlage).
- **Ranglisten-Reset immer ausdrücklich nennen** (gilt für jede Änderung, egal von wem): Setzt eine Änderung Ranglisten
  zurück (neue Wertungs-Version: `Leaderboard.RULES` erhöht, `"lb"` in einer Aufgabe, Aufgabe in `Training.MODES` außer
  Texten/Medaillen geändert, Features eines Setups oder benutzte Bauteile in `parts.json` geändert), das **vor dem Commit
  klar sagen** und **auflisten, welche Ranglisten betroffen sind** (z. B. „alle“, „Kicker: Kicker M mit Absprung“,
  „Competition Terminal 2 · Setup D, alle Rundenlängen“). Immer auch in die Commit-Nachricht („Rangliste neu: …“), damit es
  in der Git-Historie steht. Wird nichts zurückgesetzt, obwohl sich Physik/Punkte ändern, ebenfalls kurz erwähnen
  (alte Werte zählen weiter).

**Musik** (`scripts/music.gd`, Reiter „Musik“, Kanal `Musik`): **nur lizenzfreie Spiel-Musik im Repo** (Pixabay, `assets/music/`, Quellen in `assets/music/QUELLEN.md` pflegen; bekannte Titel bräuchten Master- und Verlagsrechte). `assets/music/` hat ein `.gdignore` (nicht importiert, nicht im index.pck): lokal direkt aus dem Ordner gelesen, im Web kopiert der Workflow die Dateien nach `music/` + `music/index.json`, das Spiel lädt per HTTPRequest nur laufenden + nächsten Titel. Dazu eigene MP3/OGG/WAV des Spielers (Desktop: nativer Dateidialog, Web: `<input type=file>` über JavaScriptBridge), Kopie nach `user://musik`. Einstellungen `music`, `music_src` (0 Spiel, 1 eigene, 2 beides), `vol_music`; gemischt abgespielt (`PROCESS_MODE_ALWAYS`), `Music.duck()` bei Jubel/Sturzruf/Countdown; Pausenmenü „Nächster Titel“; Link `Music.PLAYLIST_URL`. Tests spielen nie eigene Titel (Spiel-Musik schon): `--music=DATEI[,…]`.

Startseite merkt sich das **zuletzt gespielte Spiel** (Modus + Challenge-id in user://settings.cfg [game] `mode`/`task`, gespeichert bei Start und beim Verlassen der Challenge, Tests speichern nichts; `main.gd _remember_game`/`_recall_game`). Startseite: echte Szene im Hintergrund, Kamera schwenkt von der Seeseite; Menü im HUD-Stil
(Spielmodus, Terminal, Feature-Setup, Challenge und alle Einstellungen als **Auswahlboxen** `scripts/ui/select_box.gd` – Liste mit großen Zeilen direkt an der Box, am Handy per Finger scrollbar, Test `--screen=@auswahl[2]`; Einstellungen je Zeile Titel links, Auswahl/Schieber rechts; Medaillen als **Pokale** `scripts/ui/trophy.gd`; Einstellungen, Spiel starten), keine Tasten-Legende, keine
Shortcuts T/F (Enter/PS = Start, Leertaste/✕ drückt den Knopf mit Fokus, Esc/○ zurück, O/Options Einstellungen; `MenuNav`). Taste **Setup-Editor** öffnet den Editor (eigene Seite). Eigene Setups liegen in `user://setups/`
(`FeatureSet.save_user_setup`) und hängen hinten an `list_setups()`. Das Popup „Features & Hacks“ bleibt im Code, aber nicht im Menü.
Responsiv: Desktop Menü links, Handy quer breit/flach, Handy hoch unten.

## Weitere Fachbegriffe (Wakeboard)

| Begriff | Bedeutung |
|---|---|
| 2-Mast-Anlage | Seil zwischen zwei Masten, ein Carrier pendelt hin und her (kein Rundkurs) |
| Carrier | Wagen am Seil, an dem die Leine mit der Handle hängt |
| Deep-Water-Start | Start aus dem Wasser liegend, Brett vorne quer |
| Kante (Heel/Toe) | Brett auf die Kante stellen = Halt quer zum Zug; Kante lösen = Driften |
| Feature / Obstacle | Hindernis im Wasser |
| Cheese Wedge | keilförmiger Kicker/Abfahrt |
| Slider | alles zum Rutschen: Box, Rail, Pipe, Ledge, Curb, Transition Rail |
| Box / Ledge / Ollie Box | breite bzw. schmale Rutschfläche |
| Rail / Pipe | Stange bzw. dickes Rohr; A-Frame = Rail mit Auf- und Abfahrt |
| Transition | konkav geschwungene Auffahrt (Curb = kurzes Modul mit Transition) |
| Uprail | ansteigendes Rail |
| Ollie | einfacher Sprung aus dem Wasser |
| Raley | Sprung mit hohem Schwung nach hinten, Körper gestreckt, Brett über Kopf |
| 180 / 360 / … | Drehung um die Hochachse |
| Frontroll / Backroll | Überschlag um die Brettlängsachse (vorwärts / rückwärts) |
| 50-50 | längs über das Feature rutschen |
| Boardslide | quer zum Feature rutschen |
| Nosepress / Tailpress | auf dem Slider Gewicht auf Nose bzw. Tail, anderes Ende in der Luft |
| Nose / Tail | vorderes / hinteres Brettende (Twin-Tip: symmetrisch) |
| Rocker | Biegung des Bretts zu den Spitzen |
| Duck-Stance | beide Füße leicht nach außen gedreht |
| Combo | mehrere Tricks direkt hintereinander |
