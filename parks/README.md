# Wakeparks

Jeder Wakepark hat einen eigenen Ordner `parks/<id>/` mit einer `park.json`. Die Liste aller Parks steht in
`parks/index.json` (World Map auf der Startseite, `default` = Standard-Park; Pins aus `location`). Geladen wird der Park von `scripts/park.gd`
(`Park.select(id)`); Test: `--park=ID`. Gespeichert wird die Wahl in `user://settings.cfg [game] park`.

## park.json

| Schlüssel | Bedeutung |
|---|---|
| `id`, `name` | id (Ordnername) und Name des Parks (Eigenname, wird nicht übersetzt) |
| `place`, `country` | Ort (wird übersetzt, deutscher Ausgangstext) und Land (ISO-Code) |
| `location` | `lat`/`lon` (Grad): Sonnenstand, Live-Wetter („Jetzt“) |
| `timezone` | `utc` = Abstand zu UTC in Stunden, `dst`: `"eu"` = Sommerzeit wie in der EU (letzter Sonntag März bis letzter Sonntag Oktober), `""` = keine |
| `geo_axis` | optional `[dE, dN]`: Richtung von −z der Spielkoordinaten (z. B. `[0, 1]` = Norden, damit das Datengebiet gerade liegt); ohne = entlang der Anlage im Ursprung (Wakeport) |
| `geo` | Ordner der Geodaten (`geo.json`, `terrain.bin`, `canopy.bin`, `dop_core.jpg`, `dop_wide.jpg`, siehe `tools/fetch_geodata.mjs`) |
| `setups` | Liste der Feature-Setups (Format wie `setups/index.json`) |
| `plants` | Bepflanzung (Format wie `setups/plants.json`, Setup-Editor Reiter Pflanzen) |
| `system_label` | Überschrift der Anlagen-Auswahl auf der Startseite (Wakeport `"TERMINAL"`, Standard `"ANLAGE"`) |
| `scenery` | Kulisse: `"wakeport"` = nachgebauter Strand (`scripts/beach.gd`) samt SUPs, Badegästen, Tieren, Flugzeugen; sonst je Anlage ein einfacher Startsteg mit Hütte, Steuermann und wartendem Fahrer (`Beach.build_docks`) |
| `default_system` | Anlage, auf der man standardmäßig fährt |
| `systems` | die Anlagen (siehe unten), in Anzeige-Reihenfolge |

### Anlagen (`systems`)

| Schlüssel | Bedeutung |
|---|---|
| `id` | Schlüssel der Anlage: in den Setup-Dateien (`"T2": [...]`), Ranglisten, Einstellungen, `--terminal=` |
| `name`, `hint` | Anzeigename („Terminal 2“) und Hinweis im Setup-Editor (beide übersetzt) |
| `type` | `"2.0"` = 2-Mast-Anlage (Carrier pendelt, `CableSystem`); `"full"` = Rundanlage (`FullCable`: Seil im Kreis über alle `masts` in Fahrtrichtung, Startsteg am ersten Mast, Setups mit `s` entlang des Seils) |
| `origin` | `true` bei genau einer Anlage: ihr Startmast ist der Ursprung der Spielkoordinaten, ihr Seil läuft entlang −z |
| `masts` | Namen der Masten in `geo.json` (`masts`), der Reihe nach (2.0: Start-, Endmast) |
| (Wakeport T2) | `origin` ohne `dock` = alte Maße aus `Lake` (Steg vor der großen Hütte); alle anderen Anlagen werden zwischen ihre Masten gesetzt |
| `end_extend` | Endmast so viele Meter weiter draußen als in den Geodaten (Wakeport: 35, mehr Platz für Wenden) |
| `center_shift` | Features so viele Meter zusätzlich nach hinten (Mittenausgleich, siehe main.gd `_s_offset`) |
| `turn_a_z` | Ufer-Wende (lokales z) |
| `dock` | Startsteg. `{"auto": true}`: am Ufer vor dem Startmast (erste Stelle mit Wasser entlang des Seils, Steg 5 m hinein, Startplatz 3 m im Wasser). Sonst (Wakeport T1) `rel` = Mitte relativ zum Ursprung (dE, dN in m), `size` = Breite/Tiefe, `y` = Oberkante, `start_dx` = Startplatz seitlich, `start_back`/`turn_back` = Carrier-Start bzw. Ufer-Wende so weit draußen |

Ranglisten: Der Wakeport behält seine Schlüssel (`comp/SEK/T2/SETUP`), jeder andere Park bekommt `comp/SEK/<park>.<anlage>/SETUP`
(`Park.board_prefix`). Eigene Setups anderer Parks liegen in `user://setups/<park>/`.

## Parks

- `wakeport/`: Wakeport Raunheim (2 × 2.0: Terminal 1, Terminal 2)
- `hipnotics/`: Hip-Notics Cable Park, Manavgat/Antalya (Rundanlage L2 mit Setup „L2 nach Luftbild“, System 1/2 auf L3; `NOTIZEN.md`)

## Geodaten für neue Parks

Ohne amtliche Daten: `parks/<id>/geo_quelle.json` (Masten als Breite/Länge, UTM-Zone, Gebiet, Quellen) anlegen, dann
`node tools/park_geo.mjs <id>` (Copernicus DEM + Sentinel-2, siehe Kopf der Datei) und
`Godot --headless --path . -s tools/png_to_jpg.gd -- parks/<id>/geo`. Kontrollbild der Uferlinie: `parks/<id>/recherche/ufer_kontrolle.png`. Rundanlagen: `carve_loops` hebt entlang des Seilwegs Wasser aus (`carve_width`, an den Ecken `carve_extend` über den Mast hinaus, nur `carve_mast` um den Mast bleibt Land) – die Uferlinie aus 10-m-Daten ist zu ungenau, an den Ecken lief das Seil sonst über Land.
