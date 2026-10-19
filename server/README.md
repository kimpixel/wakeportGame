# Rangliste – Cloudflare Worker + D1

Kleiner Server für die Online-Rangliste (`scripts/leaderboard.gd` im Spiel). Läuft kostenlos im
Gratis-Kontingent von Cloudflare (Worker + D1-Datenbank), keine eigene Maschine.

## Einmal einrichten

Im Ordner `server/` (node ist da):

```bash
npm install
npx wrangler login                        # Browser: Cloudflare-Konto (kostenlos) anlegen bzw. anmelden
npx wrangler d1 create wakethehack        # gibt eine database_id aus -> in wrangler.toml eintragen
npm run schema                            # Tabellen anlegen (darf beliebig oft laufen)
npx wrangler secret put ADMIN_TOKEN       # langes Zufallspasswort für die Admin-Befehle
npx wrangler secret put RATE_SALT         # beliebiger Zufallstext (Salz für den IP-Hash)
npm run deploy                            # gibt die Adresse aus, z. B. https://wakethehack-rangliste.<name>.workers.dev
```

Die Adresse dann in `scripts/leaderboard.gd` bei `const URL` eintragen, committen, fertig.
Code geändert → `npm run deploy` erneut.

## Wie es mit den ständigen Änderungen klarkommt

Der Server weiß nichts über Aufgaben oder Punkte. Jede Rangliste ist `board` (z. B. `ch/kicker/m_pop`,
`comp/450/T2/setup_d`) plus `ver`, die **Wertungs-Version**, die das Spiel selbst ausrechnet:

| Was sich ändert | Folge |
|---|---|
| Aufgabe in `Training.MODES` (Start, Ziel, Messwert, Setup …) | nur diese Challenge beginnt neu |
| Texte, Tipps, **Medaillen-Schwellen** | nichts (zählen nicht zur Version) |
| Features im Setup (Lage oder benutzte Bauteile in `parts.json`) | Ranglisten mit diesem Setup beginnen neu |
| Physik/Punkte im Code (`rider.gd` …) | von Hand: `Leaderboard.RULES` erhöhen (alle neu) oder `"lb": 2` in einer Aufgabe (nur diese) |

Neue Version = neue, leere Rangliste. Die alten Einträge bleiben in der Datenbank (Hinweis „Wertung
geändert“ im Spiel), mit `/admin/purge` lassen sie sich löschen.

Echte Einträge kommen aus der Web-Hauptversion und vom lokalen Spiel am Desktop. Nur PR-Vorschauen schreiben
in Test-Ranglisten (`ver` beginnt mit `dev-`, Name mit „ dev“). Lokale, noch unveröffentlichte Wertungs-Änderungen
landen automatisch in einer neuen Rangliste (andere `ver`), die alten bleiben unberührt.

## Lokal testen

```bash
npm run schema-local
npx wrangler dev --local --port 8787
```

Spiel dagegen (Kommandozeile, speichert nichts):

```bash
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 120 -- --autotest --mode=wende:1 --go=0.5 --mode-auto --lb-url=http://127.0.0.1:8787 --lb-name=Test --quit=40
```

`127.0.0.1` statt `localhost` (Godot versucht sonst IPv6 und wartet bis zum Timeout).

## Schummeln und Aufräumen (Admin)

Das Spiel läuft im Browser, gesendete Werte lassen sich fälschen. Dagegen: Rate-Limit je IP, Grenzen je
Rangliste und Löschen von Hand. Admin-Befehle per POST mit `Authorization: Bearer <ADMIN_TOKEN>`:

```bash
curl -X POST https://…workers.dev/admin/boards -H "Authorization: Bearer $T" -d '{}'
curl -X POST https://…workers.dev/admin/delete -H "Authorization: Bearer $T" -d '{"board":"ch/kicker/m_pop","name":"Cheater"}'
curl -X POST https://…workers.dev/admin/ban    -H "Authorization: Bearer $T" -d '{"name":"Cheater"}'
curl -X POST https://…workers.dev/admin/limit  -H "Authorization: Bearer $T" -d '{"board":"ch/kicker/m_pop","max":5}'
curl -X POST https://…workers.dev/admin/purge  -H "Authorization: Bearer $T" -d '{"board":"ch/kicker/m_pop","ver":"1-…"}'
```

## Datenschutz

Gespeichert werden nur Name, Bestwerte, Datum, Spielversion und der SHA-256 einer zufälligen Geräte-Nummer.
Die IP nur gehasht mit Tagessalz für das Rate-Limit (nach 10 Minuten gelöscht). Ohne Namen wird anonym
eingetragen („Anonym #XXXX“ aus dem Schlüssel, keine personenbezogenen Daten). Der Schalter „In der Rangliste
erscheinen“ auf Aus löscht Spieler und Einträge (`/forget`) und sendet danach nichts mehr. Admin-Befehle nehmen auch
„Anonym #XXXX“ als Namen.
