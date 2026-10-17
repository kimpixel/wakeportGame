// Rangliste für WAKE THE HACK – Cloudflare Worker mit D1-Datenbank (Bindung DB).
//
// Der Server kennt keine Aufgaben und keine Wertung: eine Rangliste ist nur ein Name (board) plus eine
// Wertungs-Version (ver), beides schickt das Spiel mit. Ändert sich im Spiel eine Aufgabe oder die
// Physik, ändert sich ver -> neue, leere Rangliste, ohne dass hier etwas angepasst werden muss.
//
// Öffentlich (JSON per POST):
//   /score   {id, name, board, ver, value, lower, build}  Bestwert eintragen (nur wenn besser)
//   /top     {board, ver, lower, n, id?}                   beste n Einträge + eigener Platz
//   /name    {id, name}                                    Namen festlegen bzw. ändern
//   /forget  {id}                                          Spieler und alle Einträge löschen
//   /boards  {dev?}                                        alle Ranglisten mit Einträgen (board, ver, n)
// Admin (Header "Authorization: Bearer <ADMIN_TOKEN>"):
//   /admin/boards                       alle Ranglisten mit Version und Anzahl
//   /admin/delete {board, ver?, name}   Eintrag eines Spielers löschen (ohne ver: alle Versionen)
//   /admin/ban    {name, banned?}       Spieler sperren (Einträge verschwinden aus den Listen)
//   /admin/limit  {board, min?, max?}   Grenzen für eine Rangliste (beide null = Grenze löschen)
//   /admin/purge  {board, ver}          ganze Rangliste einer Version löschen
//
// Die Geräte-Nummer (id) ist geheim: gespeichert wird nur ihr SHA-256, ausgegeben wird sie nie.

const NAME_RE = /^[\p{L}\p{N}][\p{L}\p{N} ._\-]{0,14}[\p{L}\p{N}._\-]$/u;
const BOARD_RE = /^[a-z0-9_\-./]{1,80}$/i;
const VER_RE = /^[a-z0-9_\-.]{1,40}$/i;
const RATE_WINDOW = 10 * 60 * 1000;   // ms
const RATE_MAX = 60;                  // Schreibzugriffe je IP und Fenster
const TOP_MAX = 50;
// grob: Namen, die nicht in eine öffentliche Liste gehören (Teilwort, klein, ohne Leerzeichen)
const BAD = ["fick", "fuck", "nazi", "hitler", "hure", "fotze", "nigg", "neger", "wichser", "schwuchtel",
  "spast", "cunt", "whore", "bitch", "penis", "vagina", "porn", "sieg heil", "kanake", "missgeburt"];

export default {
  async fetch(req, env) {
    const origin = req.headers.get("Origin") || "";
    const cors = corsHeaders(origin, env);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (req.method !== "POST") return json({ error: "nur POST" }, 405, cors);
    let body;
    try {
      body = await req.json();
    } catch {
      return json({ error: "kein JSON" }, 400, cors);
    }
    const path = new URL(req.url).pathname.replace(/\/+$/, "");
    try {
      if (path.startsWith("/admin/")) {
        if (!env.ADMIN_TOKEN || req.headers.get("Authorization") !== "Bearer " + env.ADMIN_TOKEN)
          return json({ error: "kein Zugriff" }, 401, cors);
        return json(await admin(path.slice(7), body, env), 200, cors);
      }
      const now = Date.now();
      if (path !== "/top" && path !== "/boards" && !(await rateOk(req, env, now)))
        return json({ error: "zu viele Anfragen, bitte später" }, 429, cors);
      switch (path) {
        case "/score": return await score(body, env, now, cors);
        case "/top": return json(await top(body, env), 200, cors);
        case "/boards": return json(await boards(body, env), 200, cors);
        case "/name": return await setName(body, env, now, cors);
        case "/forget": return await forget(body, env, cors);
      }
      return json({ error: "unbekannt" }, 404, cors);
    } catch (e) {
      return json({ error: "Serverfehler", detail: String(e && e.message || e) }, 500, cors);
    }
  },
};

function corsHeaders(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  const ok = allowed.includes(origin) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const h = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (ok) h["Access-Control-Allow-Origin"] = origin;
  return h;
}

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

async function sha256(text) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function playerKey(id) {
  if (typeof id !== "string" || !/^[0-9a-f]{32}$/.test(id)) return null;
  return sha256("player:" + id);
}

// Rate-Limit je IP und 10-Minuten-Fenster; gespeichert wird nur ein Hash (mit Tagessalz).
async function rateOk(req, env, now) {
  const ip = req.headers.get("CF-Connecting-IP") || "?";
  const day = Math.floor(now / 86400000);
  const key = await sha256(`${env.RATE_SALT || "wth"}:${day}:${ip}`);
  const row = await env.DB.prepare("SELECT n, until FROM rate WHERE key = ?").bind(key).first();
  if (!row || row.until < now) {
    await env.DB.batch([
      env.DB.prepare("DELETE FROM rate WHERE until < ?").bind(now),
      env.DB.prepare("INSERT OR REPLACE INTO rate (key, n, until) VALUES (?, 1, ?)").bind(key, now + RATE_WINDOW),
    ]);
    return true;
  }
  if (row.n >= RATE_MAX) return false;
  await env.DB.prepare("UPDATE rate SET n = n + 1 WHERE key = ?").bind(key).run();
  return true;
}

// Namen prüfen: liefert [Name, Fehlertext]
function cleanName(raw) {
  const name = String(raw || "").replace(/\s+/g, " ").trim();
  if (name.length < 2 || name.length > 16) return [null, "Name: 2 bis 16 Zeichen"];
  if (!NAME_RE.test(name)) return [null, "Name: nur Buchstaben, Ziffern, Leerzeichen, . _ -"];
  const flat = name.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "")
    .replace(/0/g, "o").replace(/1/g, "i").replace(/3/g, "e").replace(/4/g, "a").replace(/5/g, "s");
  if (BAD.some((w) => flat.includes(w.replace(/ /g, "")))) return [null, "Diesen Namen bitte nicht"];
  return [name, null];
}

// Spieler anlegen oder umbenennen. Liefert {key} oder {error, status}.
async function upsertPlayer(env, key, rawName, now) {
  const p = await env.DB.prepare("SELECT name, banned FROM players WHERE key = ?").bind(key).first();
  if (p && p.banned) return { error: "gesperrt", status: 403 };
  if (rawName === undefined || rawName === null || rawName === "") {
    return p ? { key, name: p.name } : { error: "Name fehlt", status: 400 };
  }
  const [name, err] = cleanName(rawName);
  if (err) return { error: err, status: 400 };
  if (p && p.name === name) return { key, name };
  const taken = await env.DB.prepare("SELECT key FROM players WHERE lname = ?").bind(name.toLowerCase()).first();
  if (taken && taken.key !== key) return { error: "Name schon vergeben", status: 409 };
  if (p) await env.DB.prepare("UPDATE players SET name = ?, lname = ? WHERE key = ?").bind(name, name.toLowerCase(), key).run();
  else await env.DB.prepare("INSERT INTO players (key, name, lname, created) VALUES (?, ?, ?, ?)")
    .bind(key, name, name.toLowerCase(), now).run();
  return { key, name };
}

function boardArgs(b) {
  if (typeof b.board !== "string" || !BOARD_RE.test(b.board)) return null;
  if (typeof b.ver !== "string" || !VER_RE.test(b.ver)) return null;
  return { board: b.board, ver: b.ver, lower: b.lower ? 1 : 0 };
}

// Platz eines Werts (1 = bester); bei Gleichstand zählt, wer ihn früher hatte.
async function rankOf(env, a, value, updated) {
  const cmp = a.lower ? "<" : ">";
  const r = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM scores s JOIN players p ON p.key = s.player
     WHERE s.board = ? AND s.ver = ? AND p.banned = 0
       AND (s.value ${cmp} ? OR (s.value = ? AND s.updated < ?))`
  ).bind(a.board, a.ver, value, value, updated).first();
  return r.n + 1;
}

async function total(env, a) {
  const r = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM scores s JOIN players p ON p.key = s.player
     WHERE s.board = ? AND s.ver = ? AND p.banned = 0`
  ).bind(a.board, a.ver).first();
  return r.n;
}

async function score(b, env, now, cors) {
  const a = boardArgs(b);
  const key = await playerKey(b.id);
  const value = Number(b.value);
  if (!a || !key || !Number.isFinite(value) || Math.abs(value) > 1e7) return json({ error: "ungültig" }, 400, cors);
  const lim = await env.DB.prepare("SELECT min, max FROM limits WHERE board = ?").bind(a.board).first();
  if (lim && ((lim.min !== null && value < lim.min) || (lim.max !== null && value > lim.max)))
    return json({ error: "Wert außerhalb der Grenzen" }, 422, cors);
  const pl = await upsertPlayer(env, key, b.name, now);
  if (pl.error) return json({ error: pl.error }, pl.status, cors);
  const old = await env.DB.prepare("SELECT value, updated FROM scores WHERE board = ? AND ver = ? AND player = ?")
    .bind(a.board, a.ver, key).first();
  const better = !old || (a.lower ? value < old.value : value > old.value);
  const build = String(b.build || "").slice(0, 40);
  if (better) {
    await env.DB.prepare(
      `INSERT INTO scores (board, ver, player, value, lower, build, updated) VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(board, ver, player) DO UPDATE SET value = excluded.value, build = excluded.build, updated = excluded.updated`
    ).bind(a.board, a.ver, key, value, a.lower, build, now).run();
  }
  const best = better ? value : old.value;
  const rank = await rankOf(env, a, best, better ? now : old.updated);
  return json({ ok: true, improved: better, value: best, rank, total: await total(env, a), name: pl.name }, 200, cors);
}

async function top(b, env) {
  const a = boardArgs(b);
  if (!a) return { error: "ungültig" };
  const n = Math.max(1, Math.min(TOP_MAX, Number(b.n) || 10));
  const key = await playerKey(b.id);
  const order = a.lower ? "ASC" : "DESC";
  const rows = await env.DB.prepare(
    `SELECT p.name, s.value, s.updated, s.player = ? AS me FROM scores s JOIN players p ON p.key = s.player
     WHERE s.board = ? AND s.ver = ? AND p.banned = 0
     ORDER BY s.value ${order}, s.updated ASC LIMIT ?`
  ).bind(key || "", a.board, a.ver, n).all();
  const entries = rows.results.map((r, i) => ({ rank: i + 1, name: r.name, value: r.value, date: r.updated, me: !!r.me }));
  let me = null;
  if (key) {
    const own = await env.DB.prepare(
      `SELECT s.value, s.updated, p.name FROM scores s JOIN players p ON p.key = s.player
       WHERE s.board = ? AND s.ver = ? AND s.player = ? AND p.banned = 0`
    ).bind(a.board, a.ver, key).first();
    if (own) me = { rank: await rankOf(env, a, own.value, own.updated), value: own.value, name: own.name, date: own.updated };
  }
  // Einträge in älteren Wertungs-Versionen derselben Rangliste (Hinweis „Wertung geändert“)
  const older = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE board = ? AND ver <> ?")
    .bind(a.board, a.ver).first();
  return { ok: true, entries, total: await total(env, a), me, older: older.n };
}

// Ranglisten mit Einträgen (für die Auswahl im Spiel); dev = Test-Ranglisten statt echter
async function boards(b, env) {
  const r = await env.DB.prepare(
    `SELECT s.board, s.ver, COUNT(*) AS n FROM scores s JOIN players p ON p.key = s.player
     WHERE p.banned = 0 AND (s.ver LIKE 'dev-%') = ? GROUP BY s.board, s.ver`
  ).bind(b.dev ? 1 : 0).all();
  return { ok: true, boards: r.results };
}

async function setName(b, env, now, cors) {
  const key = await playerKey(b.id);
  if (!key) return json({ error: "ungültig" }, 400, cors);
  const pl = await upsertPlayer(env, key, b.name, now);
  if (pl.error) return json({ error: pl.error }, pl.status, cors);
  return json({ ok: true, name: pl.name }, 200, cors);
}

async function forget(b, env, cors) {
  const key = await playerKey(b.id);
  if (!key) return json({ error: "ungültig" }, 400, cors);
  const p = await env.DB.prepare("SELECT banned FROM players WHERE key = ?").bind(key).first();
  if (p && p.banned) {
    // gesperrte Spieler: Einträge löschen, Sperre (ohne Namen) bleibt
    await env.DB.prepare("DELETE FROM scores WHERE player = ?").bind(key).run();
    return json({ ok: true }, 200, cors);
  }
  await env.DB.batch([
    env.DB.prepare("DELETE FROM scores WHERE player = ?").bind(key),
    env.DB.prepare("DELETE FROM players WHERE key = ?").bind(key),
  ]);
  return json({ ok: true }, 200, cors);
}

async function admin(cmd, b, env) {
  const byName = async (name) =>
    await env.DB.prepare("SELECT key FROM players WHERE lname = ?").bind(String(name || "").toLowerCase()).first();
  switch (cmd) {
    case "boards": {
      const r = await env.DB.prepare(
        `SELECT board, ver, COUNT(*) AS n, MAX(updated) AS last, MIN(lower) AS lower FROM scores
         GROUP BY board, ver ORDER BY board, last DESC`
      ).all();
      return { ok: true, boards: r.results };
    }
    case "delete": {
      const p = await byName(b.name);
      if (!p) return { error: "Spieler unbekannt" };
      const q = b.ver
        ? env.DB.prepare("DELETE FROM scores WHERE board = ? AND ver = ? AND player = ?").bind(b.board, b.ver, p.key)
        : env.DB.prepare("DELETE FROM scores WHERE board = ? AND player = ?").bind(b.board, p.key);
      const r = await q.run();
      return { ok: true, deleted: r.meta.changes };
    }
    case "ban": {
      const p = await byName(b.name);
      if (!p) return { error: "Spieler unbekannt" };
      await env.DB.prepare("UPDATE players SET banned = ? WHERE key = ?").bind(b.banned === false ? 0 : 1, p.key).run();
      return { ok: true };
    }
    case "limit": {
      if (b.min == null && b.max == null) {
        await env.DB.prepare("DELETE FROM limits WHERE board = ?").bind(b.board).run();
      } else {
        await env.DB.prepare("INSERT OR REPLACE INTO limits (board, min, max) VALUES (?, ?, ?)")
          .bind(b.board, b.min ?? null, b.max ?? null).run();
      }
      return { ok: true };
    }
    case "purge": {
      const r = await env.DB.prepare("DELETE FROM scores WHERE board = ? AND ver = ?").bind(b.board, b.ver).run();
      return { ok: true, deleted: r.meta.changes };
    }
  }
  return { error: "unbekannt" };
}
