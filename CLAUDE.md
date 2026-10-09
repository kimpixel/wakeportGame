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
- Sagt der Nutzer „zeige das Ergebnis und warte auf Freigabe“ (oder ist eine Pose/Optik strittig):
  Screenshots schicken, **nicht committen**, bis er „passt so“ sagt.
- „passt so“ = Freigabe, dann commit.
- Bei Optik/Animation immer Screenshots machen und selbst ansehen, bevor man Erfolg meldet.
- README.md und die Hilfe im HUD (`scripts/hud.gd`, `HELP`/`HELP_MOBILE`) bei Steuerungs- und
  Regeländerungen mitpflegen.

## Testen

Godot liegt im Repo-Root: `./Godot_v4.7.2-stable_win64_console.exe`. Kein ffmpeg/python, aber node.

```bash
# Headless-Smoke-Test (Autopilot, Log mit TRICK:/CRASH:/t=… Zeilen)
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 120 -- --autotest --quit=30
# Screenshot (mit Fenster), z. B. Nahaufnahme am Fahrer
./Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 120 -- --autotest --jump-at=12 --closeup=0,1.2,4.5,0,1.0,0 --shot=PFAD.png --shot-time=12.4
# Handy nachstellen
./Godot_v4.7.2-stable_win64_console.exe --path . --resolution 540x1170 -- --mobile --tilt=0
```

Wichtige Test-Argumente (vollständig im Kopf von `scripts/main.gd`): `--autotest`, `--quit=S`,
`--shot=P --shot-time=S`, `--view=x,y,z,lx,ly,lz`, `--closeup=x,y,z[,lx,ly,lz]` (relativ zum Fahrer),
`--terminal=T1|T2`, `--setup=ID`, `--screen[=NAME|@liste|@einstellungen]`, `--no-screen`,
`--mobile --tilt=GRAD`, `--jump-at=S`, `--pitch=±1`, `--crash-at=S`, `--letgo-at=S`,
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
| `scripts/hud.gd` | HUD (Zeit, Seilzug-Anzeige, Punkte), Hilfe, Stil (`ACCENT` grün, `PANEL`) |
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
- **Competition** = die Runde auf Zeit (alles unter „Spiel“). Daneben Training: **Wenden, Kicker, Slider, Raley**, je
  mehrere Aufgaben (leicht → schwer), jede misst einen Wert → **Bronze/Silber/Gold** (Schwellen in `Training.MODES`,
  vom Nutzer fein justiert). Bestwerte in user://settings.cfg [medaillen]; **Tests speichern nichts**.
- Modi: Wenden, Kicker, Slider, Raley, **Transfer** (auf echten Setups, `terminal`/`setup` je Aufgabe, `via` = Start-Feature,
  `target` = Ziel, je per Anzeigename; zählt nur: auf dem Start-Feature fahren, abspringen, aus der Luft aufs Ziel). Nach gewertetem Versuch **1,4 s ausrollen** (`Challenge.OUTRO`), dann Fenster.
  Startseite im Querformat zweispaltig (links Modi, rechts Terminal/Setup bzw. Aufgaben; Handy quer: Start links).
- Aufgabe setzt Fahrer + Carrier **in voller Fahrt** kurz vor die Stelle (`Rider.place`, `CableSystem.place_running`),
  jeder Versuch wieder dort (auch Kamera). Sturz/Seil verloren/verpasst: **kein Bergungs- oder Ergebnis-Fenster**,
  sofort neuer Versuch mit Countdown; Fenster nur bei gewertetem Versuch. Immer Terminal 2, 30 km/h, 16 m Seil. Eigene Setups
  `setups/training_*.json` (nicht in index.json): leer (Wenden/Raley), Kicker M+L wie Setup B, Slider-Park
  (rechts Full Pipe, Rail, A-Frame, Pipe; links 100 m Long Rail).
- **Jeder Start mit Countdown 3 – 2 – 1 – GO** (`Challenge.countdown`), dazu Ansage **englisch** „three, two, one, go“
  (`assets/sounds/countdown/`, Windows-Stimme Zira, Stille abgeschnitten; `Sfx.say_count`, spielt auch in der Pause): Competition fährt bei GO los (Szene läuft; auch nach R/☰ zurück zum Steg),
  Aufgaben stehen bis GO (SceneTree.paused).
- Test: `--mode=kicker:2 --go=0.5` (Fenster bestätigen), `--mode-auto` (Autopilot fährt), `--lane=X` (Spur halten),
  `--jump-at=S`. Ausgabe `CHALLENGE …: Wert Medaille N`. Kalibrierung: Autopilot schafft Wenden mit Silber,
  Kicker M ohne Absprung 1,6 m, mit Absprung bis 3,0 m (L 3,8 m), Full Pipe 13 m.

Spiel (Competition):
- Runde **7:30** (Einstellung „Competition: Rundenlänge“), Start nach Countdown. Danach holt der Operator den Fahrer zum Start, dann Startseite mit Ergebnis.
- **2-Mast-Prinzip: niemand muss zurück zum Start.** Seil verloren → kein Sturz, ausgleiten und
  einsinken. Nach Sturz bringt der Operator die Handle auf Höhe des Fahrers; schwimmen (Bauchlage,
  Kraulen, Brett hinten oben), greifen, **Deep-Water-Start** (liegen bleiben bis das Seil spannt,
  dann langsam aufstehen). Wasserstart immer Richtung des **weiter entfernten** Wendepunkts.
- Strafzeit: Strg nach Sturz −1:00 (sofort unter dem Seil weiter), R zurück zum Steg −2:00.
- Einsinken: Brett trägt nur mit Seilzug oder Tempo. Schlaffes Seil + langsam = absaufen (wie
  Wasserstart, keine Punkte für die Wende). Wende: 15 Punkte, außen um die weiße Boje 30.
- Jeder Start: **sonniger Sommertag 10:30** (21. Juni). Wetter/Uhrzeit werden nicht gespeichert,
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
  Seilzug zieht einen (nicht festnageln, sonst reißt das Seil), ←/→ drehen nur das Brett, Wasserwiderstand × `DRIFT_DRAG` 0.7 (leicht schneller). Nur Spieler,
  Autopilot/NPC driften wie früher. „Maximaler Grip“ gibt es nicht mehr.
- **Esc = Pause** (`scripts/ui/pause_menu.gd`, SceneTree.paused; Fenster Weiter/Hilfe/Startseite). Am Handy
  pausiert das offene ☰-Menü (TouchPad/MobileInput laufen mit PROCESS_MODE_ALWAYS). Test `--pause-at=S`.
- R, + / −, C, P, H, M, Tab (Startseite) wie in der README. **Keine Tasten T/F** mehr (Terminal/Setup nur auf der Startseite).

Steuerung Handy: Neigen = lenken, Tippen = Start, **Springen nur mit der SPRUNG-Taste (links)**,
rechts DRIFT über ▲ ▼; nach Sturz Bildschirm halten = schwimmen, DRIFT = sofort weiter;
☰-Menü (Weiter, Hilfe, Zurück zum Steg, Startseite, Ton). Terminal/Setup nur auf der Startseite.
**Mobil-Code strikt isolieren**: nur Aktionen loslassen, die er selbst gedrückt hat, nichts
global; Web-Audio-Hacks nur auf Touch-Geräten (früher hakte sonst die Desktop-Tastatur).

Tricks/Optik:
- **Ollie** = normaler Sprung. **Raley** nur mit viel Power: > 40 km/h, Sprung voll aufgeladen,
  **kein Feature voraus** (damit man schräg auf Features springen kann). Pose nach Fotoserie:
  Körper schwingt um den Griff, am höchsten Punkt kopfüber unter dem Brett, Hohlkreuz, Knie
  angewinkelt, **Griff vor dem Gesicht** mit angewinkelten Armen (nicht hinter dem Kopf).
- **Frontroll eingerollt** (Knie zur Brust), **Backroll gestreckt**.
- **Press-Pose aus Blender** (Nutzer posiert selbst): `blender/*.blend` (Godot ignoriert den Ordner) -> `tools/export_pose.py` (Nutzer: `.	oolsexport_poses.ps1` in PowerShell, exportiert alle)
  (Blender 5.2 im Hintergrund, IK ausgewertet) -> `assets/poses/nosepress.json`. Übernommen: Becken (Lage im Brettraum),
  Rücken, Kopf, Arme; Füße per IK in den Bindungen, Hände Faust, Handle in der vorderen Hand. Tailpress/Goofy gespiegelt,
  Press relativ zur Fahrtrichtung (switch). Animierter Root läuft in Schleife. Vorlage: `blender/nosepress_vorlage.glb`.
  Weitere Vorlagen (aus nosepress.blend abgeleitet, Foto als `Referenz_Foto` eingepackt, Pfeil `Fahrtrichtung`, Nutzer posiert nach):
  `tailpress` (50-50), `bs_vorwaerts_/bs_rueckwaerts_` + `nosepress`/`tailpress` (Boardslide; vorwärts = Brust in Fahrtrichtung).
  Noch nicht im Spiel verwendet – bisher nur nosepress.json (gespiegelt für Tailpress). Im Spiel kippt das Brett um Nose/Tail,
  beim Boardslide-Press rücken Fahrer und Brett seitlich, bis Nose bzw. Tail über dem Slider liegt (`_press_bs_vis`;
  Vorlagen: Rail quer unter Nose bzw. Tail, 22 cm vor der Spitze).
- **Kamera** (Verfolger): auf dem Slider 70 % Abstand, beim Press 50 % und von der Brustseite; danach weich zurück.
- Nach Sturz/Absaufen/Neustart wird Raley/Überschlag/Press sofort zurückgesetzt.
- Features haben **Kollisionskörper** aus ihrer Form (`FeaturePart._build_collider`, Ebene `LAYER_COLLIDE`):
  die Ragdoll prallt ab bzw. bleibt darauf liegen. Fahrphysik nutzt weiter `height_local()`.
- **Schwimmen nie durch Features**: Weg großzügig herum (`SWIM_MARGIN` 2 m, `FeatureSet.swim_path`,
  Sichtgraph + Dijkstra, alle 0,4 s neu), harte Grenze `push_out` (0,3 m). Hinter einem Feature zu
  stürzen kostet also mehr Schwimmzeit – gewollt. Die Panel-Schwimmzeit rechnet mit dem Umweg.
  Geschwommen wird **in runden Bögen** wie ein Mensch, nicht Ecke für Ecke: Zielpunkt 2,5 m voraus auf dem
  Weg (`SWIM_LOOKAHEAD`), Schwimmrichtung dreht höchstens `SWIM_TURN` 1,2 rad/s.
- **Fangzone der Slider** (Rail, Pipe, schmale Ledge ≤ 1 m, Rail im Transition Rail): ±0,55 m seitlich,
  0,45 m unter bis 0,4 m über der Oberkante (`FeaturePart.CATCH_*`). Wer im Sinkflug hineinkommt, gleitet
  seitlich/nach oben auf die Slide-Linie (`Rider._catch_glide`), kein Hochspringen. Gehört zur Hilfe
  „Einloggen“. Debug: **F3** bzw. `--hitbox` blendet ein: Fangzonen **gelb**, glattes Plastik **blau**, Safety/Auffahrt und
  Kicker **orange** (fährt man wie einen Kicker).
- **Brettstellung auf dem Slider rastet ein** (`Rider._slide_orient`): beim Draufkommen in die nächste Stellung:
  bis 45° zur Achse (`SNAP_5050`) 50-50, darüber Boardslide (früher 12° – schräges Aufspringen ergab ungewollt Boardslide). Auf dem Slider dreht ←/→ (Handy:
  deutlich neigen) je Tipp 90° (Boardslide ↔ 50-50), nicht stufenlos; Wechsel geben `SWITCH_BONUS` 80 und
  stehen im Namen („Boardslide to 50-50 – Rail“). Autopilot/NPC springen nicht um.
- **Abgang quer** (Brett > 50° zur Fahrtrichtung) vom Feature ins Wasser oder quer gelandet = Sturz, außer mit **Drift**
  (Strg) – dann rutscht es quer weiter (`Rider.last_exit_drift`). Autopilot/NPC ausgenommen.
- Slider **einloggen** (Auto-Rutschen): bis 35° Abweichung richtet das System die Fahrtrichtung
  entlang des Features aus und zieht zur Spur; erst darüber rutscht man ab.
- Sprung aufladen: stufenlos tiefer in die Knie.
- Sprunghöhe (`POP_SCALE` 0.93, Ollie ca. 1,1 m – „ist ja ein Spiel“, etwas mehr Power); an der Rampe kommt der Absprung nicht voll
  obendrauf (`POP_ON_RAMP`). **Kicker-Absprung hängt vom Winkel an der Kante ab** (`_lip_slope`,
  `KICK_REF`): je steiler, desto höher, überproportional – über der Kante bei 8 m/s (`KICK_REF` 0.31) ca. Kicker M 0,5 m ohne Absprung.
  **Absprung auf dem Kicker: Höhe = Steigung (mit Tempo) + Sprungkraft** (`_kick_vy` + `POP_ON_KICK` 0.6 ×
  Ollie-Schub): z. B. Kicker M an der Kante abgesprungen ca. 2,1 m über der Kante (ohne Absprung 0,5 m).
- **Glattes Plastik** (`"slick"` in parts.json): Pyramid oben, Transition des Transition Rails,
  Transition Curb, Ollie Box (nicht die Ledge), Bump nur die flache Spitze (`"slick": "top"`; alle
  Seiten des Bumps sind Kicker). **Safetys/Auffahrten** (`ramp_in`/`ramp_out`, z. B.
  vorne an der Transition Curb, vorne/hinten an der Ollie Box) fährt man wie einen **Kicker**: nie glatt,
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
- Uprail 7,5 m. Transition Rail: Rail 28 cm dick, im flachen Abschluss (ca. 26 cm) **versenkt**,
  ragt 7 cm heraus, von allen Seiten befahrbar, löst keinen Sturz aus.
- Positionen kommen aus den Plan-Fotos (`fotos/`); die Pläne sind nicht maßstäblich, Maße aus
  dem Katalog. Beim Nachstellen von Hacks: vorne/hinten und Seiten genau mit dem Foto abgleichen.
- T1-Steg ist 5 cm höher als T2 (`Lake.DOCK_T1_Y`).

Einstellungen (`scripts/game_settings.gd`, Reiter Spiel/Fahrer/Welt/Technik in `start_screen.gd`,
angewendet in `main.gd` `_apply_setting`): Spielmodus Runde 7:30 / 10:00 / 15:00 / Freies Fahren (keine Uhr, HUD zeigt „MODUS FREI“), Hilfen
(Einloggen, Überschlag ausdrehen; je aus +15 %), Seilzug-Grenze (Locker/Normal/Streng/Aus; Taste G
und ☰-Menü schalten Abreißen an/aus), Brett, Stance Regular/Goofy, Helm,
Weste, Seillänge, Anlagen-Tempo, Flugzeuge, NPC, Grafik, Lautstärken (Busse Effekte/Jubel/Flugzeuge),
Kamera, Handy-Neigung. Gespeichert in user://settings.cfg [optionen]; Wetter/Uhrzeit **nicht**.
Test: `--set=NAME=WERT` (ohne Speichern), `--screen=@einstellungenN` (Reiter N).

Startseite: echte Szene im Hintergrund, Kamera schwenkt von der Seeseite; Menü im HUD-Stil
(Terminal, Feature-Setup als Tasten, Einstellungen, Spiel starten), keine Tasten-Legende, keine
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
