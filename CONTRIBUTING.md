# Mitentwickeln an WakeTheHack

Schön, dass du mitmachst! Hier steht, wie du das Projekt einrichtest und wie Änderungen ins Spiel kommen.

## Ablauf in Kürze

1. Du bekommst eine Einladung als **Collaborator** (Schreibrechte, kein Fork nötig).
2. Du arbeitest immer auf einem **eigenen Branch**, nie direkt auf `main`.
3. Fertige Änderung → **Pull Request** auf `main`.
4. Kim schaut den PR an und gibt ihn frei (Review). Erst danach kann gemergt werden.
5. Jeder Merge auf `main` baut automatisch die Web-Version und stellt sie nach ca. 1 Minute live:
   https://kimpixel.github.io/wakeportGame/

`main` ist geschützt: direkte Pushes gehen nicht, jeder PR braucht die Freigabe von Kim (`.github/CODEOWNERS`).

## Einrichten

```bash
git clone https://github.com/kimpixel/wakeportGame.git
cd wakeportGame
```

- **Godot 4.7.2** (genau diese Version, Standard-Variante, nicht .NET): https://godotengine.org/download/archive/
  Für die Test-Befehle unten die Datei `Godot_v4.7.2-stable_win64_console.exe` ins Repo-Root legen
  (`*.exe` ist in `.gitignore`, wird also nicht eingecheckt). Auf Linux/macOS den Pfad entsprechend anpassen.
- Einmal importieren, sonst fehlen Klassen („Could not find type“):
  ```bash
  ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
  ```
- Projekt im Godot-Editor öffnen (`project.godot`) und mit F5 starten.
- Optional **Blender 5.2**, nur für Posen (`blender/`, Export mit `tools/export_poses.ps1`).
- Die Plan-Fotos (`fotos/`) sind nicht im Repo. Wer Setups nachbaut, bekommt sie bei Bedarf von Kim.

## Branch und Pull Request

```bash
git switch main
git pull
git switch -c mein-thema        # kurzer, sprechender Name, z. B. neues-setup-oktober
# ... ändern, testen ...
git add -A
git commit -m "Kurze Beschreibung auf Deutsch"
git push -u origin mein-thema
```

Dann auf GitHub „Compare & pull request“ klicken (oder `gh pr create`).

- **Ein Thema pro PR**, lieber klein als riesig.
- Im PR beschreiben: was, warum, wie getestet. Bei Optik/Animation **Screenshots** anhängen.
- Wenn `main` inzwischen weiter ist: `git pull origin main` in deinen Branch und Konflikte lösen.
- Wenn Kim Änderungen wünscht: einfach weitere Commits auf denselben Branch pushen, der PR aktualisiert sich.
- Vorher kurz absprechen, wer woran arbeitet. Vor allem `scripts/rider.gd` und `scripts/main.gd` sind groß –
  zwei Leute gleichzeitig darin gibt schnell Merge-Konflikte.

## Testen vor dem PR

```bash
# Headless-Smoke-Test (Autopilot fährt 30 s; Log mit TRICK:/CRASH:-Zeilen, darf keine Script-Fehler zeigen)
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 120 -- --autotest --quit=30
# Screenshot mit Fenster
./Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 120 -- --autotest --jump-at=12 --shot=test.png --shot-time=12.4
# Handy nachstellen
./Godot_v4.7.2-stable_win64_console.exe --path . --resolution 540x1170 -- --mobile --tilt=0
```

Alle Test-Argumente stehen im Kopf von `scripts/main.gd` und in `CLAUDE.md`.
„ERROR: BUG: Unreferenced static string“ beim Beenden ist Engine-Rauschen und kann ignoriert werden.

## Regeln

- **Sprache:** Deutsch – Code-Kommentare, Doku, Commit-Nachrichten, Texte im Spiel.
- **Code-Stil:** so wie der umgebende Code (GDScript, Tabs, deutsche Kommentare).
- **Doku mitpflegen:** bei Änderungen an Steuerung oder Regeln `README.md` und die Hilfe im HUD
  (`scripts/hud.gd`, `HELP`/`HELP_MOBILE`) anpassen.
- **Handy-Code strikt getrennt:** Touch/Neigung/Web-Audio-Tricks dürfen die Desktop-Eingabe nie beeinflussen.
- **Audio-Busse** nur in `default_bus_layout.tres` anlegen (zur Laufzeit angelegte Busse sind im Browser stumm).
- Temporäre Test-Werte (z. B. `RALEY_SPEED := 0.0 #TMP`) vor dem Commit zurücksetzen.

## Wo was steht

- `README.md` – Spielerdoku (Steuerung, Punkte, Anlage)
- `CLAUDE.md` – ausführliche Projektdoku: Fachbegriffe, Architektur, festgelegte Regeln und Entscheidungen.
  Lohnt sich zu lesen, auch ohne Claude Code. Wer mit Claude Code arbeitet, bekommt sie automatisch.
- `setups/README.md` – Feature-Setups und Bauteil-Katalog
