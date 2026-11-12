# Wakeparks

Jeder Wakepark hat einen eigenen Ordner `parks/<id>/` mit einer `park.json`. Die Liste aller Parks steht in
`parks/index.json` (später die World Map, `default` = Standard-Park). Geladen wird der Park von `scripts/park.gd`
(`Park.select(id)`); Test: `--park=ID`. Gespeichert wird die Wahl in `user://settings.cfg [game] park`.

## park.json

| Schlüssel | Bedeutung |
|---|---|
| `id`, `name` | id (Ordnername) und Name des Parks (Eigenname, wird nicht übersetzt) |
| `place`, `country` | Ort (wird übersetzt, deutscher Ausgangstext) und Land (ISO-Code) |
| `location` | `lat`/`lon` (Grad): Sonnenstand, Live-Wetter („Jetzt“) |
| `timezone` | `utc` = Abstand zu UTC in Stunden, `dst`: `"eu"` = Sommerzeit wie in der EU (letzter Sonntag März bis letzter Sonntag Oktober), `""` = keine |
| `geo` | Ordner der Geodaten (`geo.json`, `terrain.bin`, `canopy.bin`, `dop_core.jpg`, `dop_wide.jpg`, siehe `tools/fetch_geodata.mjs`) |
| `setups` | Liste der Feature-Setups (Format wie `setups/index.json`) |
| `scenery` | Kulisse (Gebäude, Stege, Leute am Ufer): bisher nur `"wakeport"` (`scripts/beach.gd`) |
| `default_system` | Anlage, auf der man standardmäßig fährt |
| `systems` | die Anlagen (siehe unten), in Anzeige-Reihenfolge |

### Anlagen (`systems`)

| Schlüssel | Bedeutung |
|---|---|
| `id` | Schlüssel der Anlage: in den Setup-Dateien (`"T2": [...]`), Ranglisten, Einstellungen, `--terminal=` |
| `name`, `hint` | Anzeigename („Terminal 2“) und Hinweis im Setup-Editor (beide übersetzt) |
| `type` | `"2.0"` = 2-Mast-Anlage (Carrier pendelt); `"full"` = Rundanlage (noch nicht umgesetzt) |
| `origin` | `true` bei genau einer Anlage: ihr Startmast ist der Ursprung der Spielkoordinaten, ihr Seil läuft entlang −z |
| `masts` | Namen der Masten in `geo.json` (`masts`), der Reihe nach (2.0: Start-, Endmast) |
| `end_extend` | Endmast so viele Meter weiter draußen als in den Geodaten (Wakeport: 35, mehr Platz für Wenden) |
| `center_shift` | Features so viele Meter zusätzlich nach hinten (Mittenausgleich, siehe main.gd `_s_offset`) |
| `turn_a_z` | Ufer-Wende (lokales z) |
| `dock` | Startsteg (nicht bei `origin`, die nimmt `Lake.DOCK_*`): `rel` = Mitte relativ zum Ursprung (dE, dN in m), `size` = Breite/Tiefe, `y` = Oberkante, `start_dx` = Startplatz seitlich, `start_back`/`turn_back` = Carrier-Start bzw. Ufer-Wende so weit draußen |

Ranglisten: Der Wakeport behält seine Schlüssel (`comp/SEK/T2/SETUP`), jeder andere Park bekommt `comp/SEK/<park>.<anlage>/SETUP`
(`Park.board_prefix`). Eigene Setups anderer Parks liegen in `user://setups/<park>/`.

## Parks

- `wakeport/`: Wakeport Raunheim (2 × 2.0: Terminal 1, Terminal 2)
- `hipnotics/`: Hip-Notics Cable Park, Manavgat/Antalya – noch keine `park.json`, nur Notizen (`NOTIZEN.md`)
