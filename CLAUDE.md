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
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 120 -- --autotest --quit=30
# Screenshot (mit Fenster, nur zur eigenen Selbstkontrolle), z. B. Nahaufnahme am Fahrer
./Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 120 -- --autotest --jump-at=12 --closeup=0,1.2,4.5,0,1.0,0 --shot=PFAD.png --shot-time=12.4
# Handy nachstellen
./Godot_v4.7.2-stable_win64_console.exe --path . --resolution 540x1170 -- --mobile --tilt=0
```

Wichtige Test-Argumente (vollständig im Kopf von `scripts/main.gd`): `--autotest`, `--quit=S`,
`--shot=P --shot-time=S`, `--view=x,y,z,lx,ly,lz`, `--closeup=x,y,z[,lx,ly,lz]` (relativ zum Fahrer),
`--terminal=T1|T2`, `--setup=ID`, `--screen[=NAME|@liste|@einstellungen]`, `--no-screen`,
`--mobile --tilt=GRAD`, `--jump-at=S`, `--pitch=±1`, `--hold=AKTION@T0-T1`, `--crash-at=S`, `--letgo-at=S`,
`--game-time=S`, `--weather=ID --hour=H --day=T`, `--plane=S`, `--passive`.

Fallstricke:
- **Neue `class_name`** → erst `--headless --import` laufen lassen, sonst „Could not find type“.
- Screenshots mit Fenster brauchen bei `--fixed-fps 120` lange (Spielzeit wird voll gerendert).
  Früh testen: der Fahrer ist ab ca. 3 s auf dem Wasser, `--jump-at=12` reicht.
- Für einen Trick im Test temporär Grenzwerte ändern (z. B. `RALEY_SPEED := 0.0 #TMP`) und
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
| `scripts/ui/start_screen.gd` | Startseite (responsiv, Popups Einstellungen / Features & Hacks / Detail) |
| `scripts/ui/setup_editor.gd` | Setup-Editor (eigene Seite, Draufsicht/3D, Bauteile, Hacks, Auswahl, Speichern in `user://setups`, JSON); Test `--screen=@editor:t2:sel=2:3d…` |
| `scripts/ui/feature_preview.gd` | drehbare 3D-Vorschau eines Features/Hacks (eigene Welt) |
| `scripts/ui/touch_pad.gd`, `scripts/mobile_input.gd` | Handy: virtuelle Tasten, Neigung, Touch |
| `scripts/ui/debug_params.gd` | Debug-Overlay **F4** (nur lokal am Desktop, nicht Web): kompaktes Panel oben rechts am Rand, feste Pixelgröße (360 px, wächst nicht mit dem Fenster), Bereich per Auswahlfeld, je Parameter eine Zeile mit Regler, Kommentar aus dem Quelltext im Tooltip, „Kopieren“ in die Zwischenablage, nichts gespeichert; Mausrad über dem Panel zoomt nicht die Kamera. Regelbare Werte sind `static var` statt `const` (z. B. `Rider.DPRESS_DRAG`); neue in `GROUPS` eintragen. Test `--debug-params` |
| `scripts/ui/branch_label.gd` | klein unten rechts in der Ecke: im Web die **Build-Version** (`res://version.txt`, schreibt `web.yml`, z. B. „v412 · 502fa0a“ – zeigt am Handy, ob die neue Version geladen ist), lokal am Desktop der Git-Branch (liest `.git/HEAD`, auch im Worktree). Web-Cache: `web.yml` benennt `index.pck` je Build um, `index.js?v=`, und `head_include` lädt die Seite einmal neu, wenn `build.txt` eine neuere Build-Nummer meldet |
| `scripts/leaderboard.gd`, `server/` | Online-Rangliste (Wertungs-Version, Senden/Abrufen) und Cloudflare Worker + D1 (siehe „Rangliste“ unten) |
| `scripts/hud.gd` | HUD (Zeit, Seilzug-Anzeige, **Tempo** mit Marken PRESS/RALEY aus `Rider.DPRESS_SPEED`/`RALEY_SPEED`, Punkte), Hilfe, Stil (`ACCENT` grün, `PANEL`) |
| `scripts/terrain.gd`, `shaders/foliage.gdshader`, `bark.gdshader`, `grass.gdshader` | Gelände aus DGM/Luftbild; Wald: Kronen aus dunkler Hülle + Blattkarten (Textur zur Laufzeit gemalt), je Art 3 Varianten, MultiMesh-Kacheln `TREE_CHUNK` 160 m, ab `FAR_RANGE` nur grobe Hülle (Sichtweiten), Schatten wirft nur die grobe Hülle (eigenes MultiMesh); dichter Mischwald aus Laubbäumen und Kiefern, **Fichten nur vereinzelt (2 %)**; **Waldmantel**: bis 14 m vom Wasser Kronen fast bis zum Boden plus Büsche (`_near_water`), damit vom See eine geschlossene grüne Wand steht; Gras am Ufer beider Anlagen (aus SimpleGrassTextured, `assets/grass/`), nicht am Strand der Startmasten. Compatibility-Renderer liefert Instanzfarben schon linear (`to_linear` in den Shadern) |
| `scripts/water.gd`, `shaders/water.gdshaderinc` | Wasser: Höhenfunktion = Physik = Grafik (Grundwellen `_wave`, spitz bei `fx_sharp`; Heckwelle; `impact()` Aufprallwelle beim Landen). Effekte `fx_*` einzeln schaltbar (Reiter **Wasser**, Einstellungen `w_*`), **gekoppelt an die Grafikstufe** (`GameSettings.WATER_PRESETS`, `set_quality`; weicht ein Effekt ab, zeigt die Grafik „Custom“ = `quality_shown()`, gespeichert bleibt die Stufe); nur `w_clear` (Durchsicht) braucht den transparenten Tiefen-Shader `water_depth.gdshader`. Farbe `w_color` Türkis/Seeblau (Standard Seeblau, „ein See ist blau“). Flach geschaut wird die Spiegelung stark gedämpft (sonst wurde der See in der Ferne weiß). **Keine Schaumkränze** (passten nicht) |
| `scripts/spray_sheet.gd`, `scripts/spray.gd` | Gischt, zwei Begriffe: **Wasserwand** (`SpraySheet`, Vorhang aus ballistischen Flugbahnen, Ansatz über die ganze Kante, Fächer von flach bis steil; zur Seilseite; Stärke 0..1 = Summe gewichteter Anteile Seilzug/Tempo/Winkel/Sprung-Ladung, Parameter `WALL_*` im F4-Panel; Seite aus der Neigung des Fahrers, Achse immer in Fahrtrichtung, auch switch) und **Tropfen** (`Spray`, weiche Wolken-Sprites, klein anfangen, groß und durchsichtig am Ende, fliegen nach hinten; kleine Gischt auf der anderen Kante, Landung mit Spritzer-Kranz, Drift-Press, Hecht, Boot). Keine Kugeln, kein Sprühnebel. **Performance**: die Wasserwand rechnet je Bild jeden Punkt einmal und nur mit `Water.ambient` (nie `height_at` je Punkt – das machte das Handy sehr langsam); Zeilen/Takt, Tropfen-Menge und Proximity Fade (Tiefenkopie im Browser, nur Hoch) je Grafikstufe (`set_quality`) |
| `scripts/weather.gd`, `scripts/sun_calc.gd`, `shaders/sky.gdshader` | Wetter, Sonnenstand nach echter Lage |
| `scripts/sfx.gd`, `assets/sounds/` | Sounds; `positiv/` (Jubel), `negativ/` (Ruf beim Sturz), `feature_hit/`, `landing/` aus Videoaufnahmen |
| `scripts/npcs/` | Umgebung (Steuermänner, wartende Fahrer, SUPs), Flugzeuge im Anflug |
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
  nie „Training“/„Aufgabe“ schreiben; im Code heißen sie weiter Training/Task): **Wenden, Kicker, Slider, Raley**, je
  mehrere Aufgaben (leicht → schwer), jede misst einen Wert → **Bronze/Silber/Gold** (Schwellen in `Training.MODES`,
  vom Nutzer fein justiert). Bestwerte in user://settings.cfg [medaillen]; **Tests speichern nichts**.
- Modi: Wenden, Kicker, Slider, Raley, **Sprung-Start** (Nolli, Raley Start vom Steg), **Driften**, **Transfer** (auf echten Setups, `terminal`/`setup` je Aufgabe, `via` = Start-Feature,
  `target` = Ziel, je per Anzeigename; zählt nur: auf dem Start-Feature fahren, abspringen, aus der Luft aufs Ziel; Klein/Groß/Special messen die Sprunghöhe im Flug Start-Feature → Ziel (`_xfer_h`), Special Press die Press-Sekunden). Nach gewertetem Versuch **1,4 s ausrollen** (`Challenge.OUTRO`), dann Fenster.
  Startseite im Querformat zweispaltig (links Modi, rechts Terminal/Setup bzw. Aufgaben; Handy quer: Start links).
- Aufgabe setzt Fahrer + Carrier **in voller Fahrt** kurz vor die Stelle (`Rider.place`, `CableSystem.place_running`),
  jeder Versuch wieder dort (auch Kamera). Sturz/Seil verloren/verpasst: **kein Bergungs- oder Ergebnis-Fenster**,
  sofort neuer Versuch mit Countdown; Fenster nur bei gewertetem Versuch. Immer Terminal 2, 30 km/h, 16 m Seil. Eigene Setups
  `setups/training_*.json` (nicht in index.json): leer (Wenden/Raley), Kicker M+L wie Setup B, Slider-Park
  (rechts Full Pipe, Rail, A-Frame, Pipe; links 100 m Long Rail).
- **Jeder Start mit Countdown 3 – 2 – 1 – GO** (`Challenge.countdown`), dazu Ansage **englisch** „three, two, one, go“
  (`assets/sounds/countdown/`, Windows-Stimme Zira, Stille abgeschnitten; `Sfx.say_count`, spielt auch in der Pause): Competition fährt bei GO los (Szene läuft; auch nach R/☰ zurück zum Steg),
  Aufgaben stehen bis GO (SceneTree.paused).
- **Slider Special** und **Ollie in Boardslide Nosepress** (`kind: "special"`, `combo` je Slider; metric count = geschaffte Slider,
  sonst bester Messwert einer geschafften Station, z. B. Meter; fertig, sobald alle Stationen gewertet sind): Stationen = Slider-Gruppen (Full Pipe = 2 Teile) nach s; je
  Station Ollie on (Slide beginnt < 0,2 s nach Landung, nicht über die Auffahrt), Drehung on/out (halbe Drehungen), Stellung
  überwiegend, Press > halbe Slide-Zeit; Abgang wird gewertet, wenn das Brett wieder im Wasser ist. Test-Ausgabe `SPECIAL …`.
- **Filmteam** (`scripts/npcs/film_crew.gd`, Einstellung `film`: 0 Zufall, 1 Boot, 2 Drohne, 3 aus; pro Challenge gewählt): rotes
  **Kunststoffboot** von T2 (kein Schlauchboot; `FilmCrew.make_boat()`, auch am Liegeplatz in `beach.gd`) fährt auf der Spur
  x = −15 (Seeseite) 12 m vor dem Fahrer mit, bremst vor dem Spurende (15 m vor den Wendepunkten) und wartet, wendet immer
  über die Seeseite; Fahrer an der Pinne (`Person` "boat_driver"), Kamerafrau stehend ("filmer"). Motorgeräusch `Sfx.make_outboard_loop`
  (synthetisch, Zündstöße), Tonhöhe/Lautstärke nach Bootstempo. Oder **FPV-Drohne** vorne-seitlich
  über dem Fahrer, Pilot mit FPV-Brille und Funke an der vorderen Ecke des T2-Startstegs ("pilot"). Jeder Versuch setzt beides neu (`snap`). **Livebild + Fotos** (`scripts/ui/film_cam.gd`, eigener SubViewport in derselben Welt, rendert nur mit Filmteam): Vorschau links oben (Camcorder der Kamerafrau mit Auto-Zoom bzw. Action-Kamera der Drohne, kippt mit). Fotos im Versuch: Absprung, höchster Punkt, Landung (nach > 0,45 s Flug), Slider (0,35 s drauf), kein Sturzfoto; gewerteter Versuch: letzte 3 im Ergebnisfenster (`TaskPanel.show_result`, ohne Foto eins beim Ende). Headless keine Fotos; Log `FOTO n`.
- **Driften** (`kind` drift_spin / drift_turn / drift_after, `Rider.drifting`): 360er im Drift zwischen den roten Bojen (Brett-Yaw im Drift
  aufsummiert, je volle Umdrehung eine, links/rechts getrennt, höchstens `SPIN_EACH` 5 je Richtung; Drift lösen setzt zurück), Wende im Drift (Anteil vom Bremsen des Carriers bis das Seil wieder zieht,
  nur gleitend: Sinkpegel < `DRIFT_SINK` 0,15; ohne Schwung Silber, mit Rauskanten Gold), Drift nach Feature (T2 Juli & August, längster Drift,
  der bis 0,3 s nach Feature/Sprung beginnt), **Drift-Press** (`kind: "dpress"`, `press` tail/nose/switch; immer T2 vor dem vorderen Wendepunkt, `turn: "a"`; voller Press ab `DPRESS_FULL` 0,6; im Press weiter Drift (Momentum bleibt), ←/→ dreht das Brett langsam (`DPRESS_TURN`), geht bei jedem Tempo; erlaubter Drift-Winkel zur **Fahrtrichtung** (`Rider._drift_angle`, mit Vorzeichen: Tailpress zur Seite `DPRESS_SIDE`, Nosepress spiegelverkehrt, Toleranz `DPRESS_WRONG` 10° zur falschen Seite) = `DPRESS_FALL_ANG` 86° × Tempo/`DPRESS_SPEED` (33 km/h), darüber Sturz; Bremse `DPRESS_DRAG` sinkt mit dem Drift-Winkel (längs voll, an der Sturzgrenze 0); Tail/Nose = längster Press am Stück, Wechsel = Nose↔Tail in einem Drift; Ende, wenn die Wende durch ist). Test ohne Autopilot (der driftet nicht): `--hold=release@1-40,steer_right@1-40`.
- Test: `--mode=kicker:2 --go=0.5` (Fenster bestätigen), `--mode-auto` (Autopilot fährt), `--lane=X` (Spur halten),
  `--jump-at=S`. Ausgabe `CHALLENGE …: Wert Medaille N`. Kalibrierung: Autopilot schafft Wenden mit Bronze (ca. 46 % eingesunken, seit schnellerem Einsinken `SINK_RATE` 0,9),
  Kicker M ohne Absprung 1,6 m, mit Absprung bis 3,0 m (L 3,8 m), Full Pipe 13 m.

Geheime Erfolge (`scripts/achievements.gd`, Liste auf der Startseite Taste „Erfolge“, Meldung `Hud.show_achievement`):
- Immer **10 Plätze** (`SLOTS`), nicht erreichte ausgegraut („Geheim“, ohne Text); neue Erfolge hinten an `LIST` hängen.
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

Spiel (Competition):
- Runde **7:30** (Einstellung „Competition: Rundenlänge“), Start nach Countdown. Danach holt der Operator den Fahrer zum Start, dann Startseite mit Ergebnis.
- **2-Mast-Prinzip: niemand muss zurück zum Start.** Seil verloren → kein Sturz, ausgleiten und
  einsinken. Nach Sturz bringt der Operator die Handle auf Höhe des Fahrers; schwimmen (Bauchlage,
  Kraulen, Brett hinten oben), greifen, **Deep-Water-Start** (liegen bleiben bis das Seil spannt,
  dann langsam aufstehen). Wasserstart immer Richtung des **weiter entfernten** Wendepunkts.
- Strafzeit: Strg nach Sturz −1:00 (sofort unter dem Seil weiter), R zurück zum Steg −2:00.
- Einsinken: Brett trägt nur mit Seilzug oder Tempo. Schlaffes Seil + langsam = absaufen (wie
  Wasserstart, keine Punkte für die Wende). Wende: 15 Punkte, außen um die weiße Boje 30.
- Jeder Start: **Do. 6. August (2026), 19:45, sonnig** (Abendsonne). Wetter/Uhrzeit werden nicht gespeichert,
  „Jetzt“ nur auf Knopfdruck. (Grund: es darf nie nachts dunkel starten.)
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
  Wer beim Abheben ↑/↓ noch hält (Press vom Slider), bekommt keinen Überschlag, bis er loslässt.
- Leertaste: halten + loslassen = Sprung; startet auch die Anlage (dann ohne Sprung). Kein Enter.
  **Nach Sturz: Leertaste halten = schwimmen, Strg = sofort weiter (−1:00), R = Steg (−2:00)** –
  angezeigt in einem Panel mit Zeitkosten (`Hud.show_recovery`).
- Strg (zur Not Alt): **Driften** – keine Kante greift: Lenken ändert die Fahrtrichtung nicht, nur der
  Seilzug zieht einen (nicht festnageln, sonst reißt das Seil); das Seil ist im Drift **keine Feder, sondern fest wie beim Kettenkarussell** (`Rider._drift_rope`: fängt nur die Bewegung vom Carrier weg weich ab, `DRIFT_ROPE_GIVE`; der Schwung nach außen bleibt, kein Schnalzen nach vorne), ←/→ drehen nur das Brett, Wasserwiderstand × `DRIFT_DRAG` 0.7 (leicht schneller), Brett dreht im Drift schneller (`DRIFT_SPIN`). Nur Spieler,
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
☰-Menü (Weiter, Einstellungen, Hilfe, Zurück zum Steg, Startseite, Ton); ☰ sitzt **rechts unter der HUD-Leiste, nie darin** (`TouchPad._place_menu_button`). Terminal/Setup nur auf der Startseite.
**Handy hochkant** (es wird meist hochkant gespielt): HUD-Leiste **zweispaltig** (links Zeit über Punkte, rechts Seilzug über Tempo, `Hud._arrange_bar`), über die ganze Breite skaliert; Aufgabenzeile, Brettzustand, Livebild des Filmteams und ☰ rücken unter die echte Unterkante (`Hud.bar_bottom`/`info_bottom`). Sturz-Panel hochkant zweispaltig (Taste | Aktion + Kosten darunter), Titel zweizeilig, volle Breite.
**Mobil-Code strikt isolieren**: nur Aktionen loslassen, die er selbst gedrückt hat, nichts
global; Web-Audio-Hacks nur auf Touch-Geräten (früher hakte sonst die Desktop-Tastatur).

Tricks/Optik:
- **Ollie** = normaler Sprung aus dem Wasser; Name nach Absprung (`Rider._launch_surface`): Ollie / **Kicker Air** / **Safety Air**. Haltung: in der Luft am höchsten Punkt am tiefsten in den Knien (`AIR_KNEES`), vor der Landung gestreckt, Landung abfedern (`LAND_TIME`). **Raley** nur mit viel Power: > 40 km/h, Sprung voll aufgeladen,
  **kein Feature voraus** (damit man schräg auf Features springen kann). Pose nach Fotoserie:
  Körper schwingt um den Griff, am höchsten Punkt kopfüber unter dem Brett, Hohlkreuz, Knie
  angewinkelt, **Griff vor dem Gesicht** mit angewinkelten Armen (nicht hinter dem Kopf).
- **Frontroll eingerollt** (Knie zur Brust), **Backroll gestreckt**.
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
- Nach Sturz/Absaufen/Neustart wird Raley/Überschlag/Press sofort zurückgesetzt.
- Features haben **Kollisionskörper** aus ihrer Form (`FeaturePart._build_collider`, Ebene `LAYER_COLLIDE`):
  die Ragdoll prallt ab bzw. bleibt darauf liegen. Fahrphysik nutzt weiter `height_local()`.
- **Schwimmen nie durch Features**: Weg großzügig herum (`SWIM_MARGIN` 2 m, `FeatureSet.swim_path`,
  Sichtgraph + Dijkstra, alle 0,4 s neu), harte Grenze `push_out` (0,3 m). Hinter einem Feature zu
  stürzen kostet also mehr Schwimmzeit – gewollt. Die Panel-Schwimmzeit rechnet mit dem Umweg.
  Geschwommen wird **in runden Bögen** wie ein Mensch, nicht Ecke für Ecke: Zielpunkt 2,5 m voraus auf dem
  Weg (`SWIM_LOOKAHEAD`), Schwimmrichtung dreht höchstens `SWIM_TURN` 1,2 rad/s.
- **Fangzone der Slider** (Rail, Pipe, schmale Ledge ≤ 1 m, Rail im Transition Rail): ±0,55 m seitlich,
  0,45 m unter bis 1,3 m über der Oberkante (`FeaturePart.CATCH_*`). Im Sinkflug in der Zone startet ↑/↓ keine Rolle (`FLIP_PRESS_MAX`: kaum angefangene wird zurückgenommen) – man will pressen. Wer im Sinkflug hineinkommt, gleitet
  seitlich/nach oben auf die Slide-Linie (`Rider._catch_glide`), kein Hochspringen. Gehört zur Hilfe
  „Einloggen“. Debug: **F3** bzw. `--hitbox` blendet ein: Fangzonen **gelb**, glattes Plastik **blau**, Safety/Auffahrt und
  Kicker **orange** (fährt man wie einen Kicker).
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
  Pyramid: Auffahrten vorne/hinten sind Transitions (konkav, beginnen unter Wasser), seitlich 12 cm Kante (`side_lip`).
- Pop auf Rampen/Kickern nie schwächer als ein Ollie (`Rider._pop`).
- **Port Plaza** = ein Modul (kein eigener Plaza Kicker), Slider mit halbrunder Oberkante (0,9 → 1,55 m), vorne/hinten
  steile gerade Safety ins Halbrund (wie A-Frame Rail), hinten breiter Teil aus Safety 1,2 m + Kicker-Schräge 2,35 m auf 1,1 m; dahinter meist ein normaler Cheese Wedge (1,1 m, keine eigene Höhe) – Plaza + Wedge ist kein Hack.
  Interne Teile `_plaza_*` (mit `_` = nicht im Editor).
- Uprail 7,5 m. Transition Rail: Rail 40 cm dick, im flachen Abschluss (ca. 36 cm) **versenkt**,
  ragt 8 cm heraus (ca. 32 cm breit sichtbar), Teil der Oberfläche: die Auffahrten schneiden hinein; von allen Seiten befahrbar, löst keinen Sturz aus.
- Positionen kommen aus den Plan-Fotos (`fotos/`); die Pläne sind nicht maßstäblich, Maße aus
  dem Katalog. Beim Nachstellen von Hacks: vorne/hinten und Seiten genau mit dem Foto abgleichen.
- T1-Steg ist 5 cm höher als T2 (`Lake.DOCK_T1_Y`).

Einstellungen (`scripts/game_settings.gd`, Reiter Spiel/Fahrer/Welt/Technik/Wasser/Musik in `start_screen.gd`,
angewendet in `main.gd` `_apply_setting`): Spielmodus Runde 7:30 / 10:00 / 15:00 / Freies Fahren (keine Uhr, HUD zeigt „MODUS FREI“), Hilfen
(Einloggen, Überschlag ausdrehen; je aus +15 %), Seilzug-Grenze (Locker/Normal/Streng/Aus; Taste G
und ☰-Menü schalten Abreißen an/aus), Brett, Stance Regular/Goofy, Helm,
Weste, Seillänge, Anlagen-Tempo, Flugzeuge, NPC, Grafik, Lautstärken (Busse Effekte/Jubel/Flugzeuge),
Kamera, Handy-Neigung. Gespeichert in user://settings.cfg [optionen]; Wetter/Uhrzeit **nicht**. **Nur Abweichungen vom Standard werden
gespeichert** (`save_file`). **Standardwert ändern**: Wert in `DEFAULTS` ändern und in `GameSettings.DEFAULT_CHANGES` eine
neue Version mit dem **alten** Wert anhängen (z. B. `2: {"cam_dist": 5.0}`) – ältere Dateien enthalten noch alle Werte; steht
dort noch der alte Standard, gilt der neue, bewusst anders eingestellte Werte bleiben (Version in [optionen] `ver`).
Test: `--set=NAME=WERT` (ohne Speichern), `--screen=@einstellungenN` (Reiter N).

**Nutzungsstatistik** (`scripts/analytics.gd`, GoatCounter-Seite `kimpixel`, Auswertung https://kimpixel.goatcounter.com): nur Web-Hauptversion (nicht lokal, PR-Vorschau, Tests), count.js wird per JavaScriptBridge geladen; Ereignisse als Pfade `Analytics.count("start/…")` (Start, `runde/ende/…`, `challenge/MODUS/ID/MEDAILLE`, `erfolg/ID`, `editor`, `geraet/…`, `spielzeit/Nmin`). Keine personenbezogenen Daten.

**Rangliste** (`scripts/leaderboard.gd`, Server `server/` = Cloudflare Worker + D1, Anleitung `server/README.md`; Adresse in `Leaderboard.URL`, leer = „noch nicht eingerichtet“):
Ranglisten je Challenge (`ch/MODUS/ID`) und Competition (`comp/SEK/TERMINAL/SETUP`, nur 30 km/h, 16 m, Seilzug-Grenze an, kein Freies Fahren, keine eigenen Setups).
Der Server kennt keine Aufgaben: die **Wertungs-Version** `ver` rechnet das Spiel (Hash der Aufgabe ohne Texte/Medaillen + Features des Setups mit benutzten Bauteilen) –
ändert sich eine Aufgabe/ein Setup, beginnt deren Rangliste automatisch neu. **Physik oder Punkte geändert, sodass alte Werte nicht vergleichbar sind → `Leaderboard.RULES` erhöhen**
(alle neu) bzw. `"lb": N` in einer Aufgabe (nur diese). Eintragen nur mit gespeichertem Namen (Startseite → Rangliste, = Einwilligung); echte Einträge nur aus der Web-Hauptversion,
lokal/PR-Vorschau in Test-Ranglisten (`dev-…`, Name „ dev“); Tests senden nichts außer mit `--lb-url=http://127.0.0.1:8787 --lb-name=X` (lokal `npx wrangler dev --local` in `server/`, Log `RANGLISTE …`). Test-Bild `--screen=@rangliste`.
Handy im Browser: Name per `prompt()` (LineEdit hat dort keine Bildschirmtastatur).

**Musik** (`scripts/music.gd`, Reiter „Musik“, Kanal `Musik`): **nur lizenzfreie Spiel-Musik im Repo** (Pixabay, `assets/music/`, Quellen in `assets/music/QUELLEN.md` pflegen; bekannte Titel bräuchten Master- und Verlagsrechte). `assets/music/` hat ein `.gdignore` (nicht importiert, nicht im index.pck): lokal direkt aus dem Ordner gelesen, im Web kopiert der Workflow die Dateien nach `music/` + `music/index.json`, das Spiel lädt per HTTPRequest nur laufenden + nächsten Titel. Dazu eigene MP3/OGG/WAV des Spielers (Desktop: nativer Dateidialog, Web: `<input type=file>` über JavaScriptBridge), Kopie nach `user://musik`. Einstellungen `music`, `music_src` (0 Spiel, 1 eigene, 2 beides), `vol_music`; gemischt abgespielt (`PROCESS_MODE_ALWAYS`), `Music.duck()` bei Jubel/Sturzruf/Countdown; Pausenmenü „Nächster Titel“; Link `Music.PLAYLIST_URL`. Tests spielen nie eigene Titel (Spiel-Musik schon): `--music=DATEI[,…]`.

Startseite merkt sich das **zuletzt gespielte Spiel** (Modus + Challenge-id in user://settings.cfg [game] `mode`/`task`, gespeichert bei Start und beim Verlassen der Challenge, Tests speichern nichts; `main.gd _remember_game`/`_recall_game`). Startseite: echte Szene im Hintergrund, Kamera schwenkt von der Seeseite; Menü im HUD-Stil
(Spielmodus, Terminal, Feature-Setup, Challenge und alle Einstellungen als **Auswahlboxen** `scripts/ui/select_box.gd` – Liste mit großen Zeilen direkt an der Box, am Handy per Finger scrollbar, Test `--screen=@auswahl[2]`; Einstellungen je Zeile Titel links, Auswahl/Schieber rechts; Medaillen als **Pokale** `scripts/ui/trophy.gd`; Einstellungen, Spiel starten), keine Tasten-Legende, keine
Shortcuts T/F (nur Leertaste = Start, Esc). Taste **Setup-Editor** öffnet den Editor (eigene Seite). Eigene Setups liegen in `user://setups/`
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
