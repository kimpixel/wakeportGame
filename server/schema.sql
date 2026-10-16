-- Rangliste (Cloudflare D1 / SQLite). Anlegen bzw. erweitern:
--   npx wrangler d1 execute wakethehack --remote --file schema.sql
-- Alles mit IF NOT EXISTS: darf beliebig oft laufen.

-- Spieler: key = SHA-256 der geheimen Geräte-Nummer (die Nummer selbst wird nie gespeichert)
CREATE TABLE IF NOT EXISTS players (
  key     TEXT PRIMARY KEY,
  name    TEXT NOT NULL,
  lname   TEXT NOT NULL,              -- Name klein geschrieben (eindeutig)
  banned  INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS players_lname ON players(lname);

-- Bestwert je Rangliste (board), Wertungs-Version (ver) und Spieler.
-- board z. B. "ch/kicker/m_pop" oder "comp/450/T2/setup_d"; ver wechselt, sobald sich die Wertung ändert
-- (eine neue Version = neue, leere Rangliste, die alten bleiben gespeichert).
CREATE TABLE IF NOT EXISTS scores (
  board   TEXT NOT NULL,
  ver     TEXT NOT NULL,
  player  TEXT NOT NULL,              -- players.key
  value   REAL NOT NULL,
  lower   INTEGER NOT NULL DEFAULT 0, -- 1 = kleiner ist besser
  build   TEXT,                       -- Spielversion (version.txt), zum Nachvollziehen
  updated INTEGER NOT NULL,           -- Zeitpunkt des Bestwerts (ms), bei Gleichstand gewinnt der frühere
  PRIMARY KEY (board, ver, player)
);
CREATE INDEX IF NOT EXISTS scores_rank ON scores(board, ver, value);

-- Optionale Grenzen je Rangliste (vom Admin gesetzt): Werte außerhalb werden abgewiesen.
CREATE TABLE IF NOT EXISTS limits (
  board TEXT PRIMARY KEY,
  min   REAL,
  max   REAL
);

-- Rate-Limit je IP (nur Hash mit Salz, zählt je 10-Minuten-Fenster)
CREATE TABLE IF NOT EXISTS rate (
  key   TEXT PRIMARY KEY,
  n     INTEGER NOT NULL,
  until INTEGER NOT NULL
);
