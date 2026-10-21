class_name Analytics
## Anonyme Nutzungsstatistik der Web-Version über GoatCounter (https://www.goatcounter.com):
## keine Cookies, keine IP-Adressen, keine personenbezogenen Daten – daher kein Cookie-Banner nötig.
## GoatCounter zählt den Seitenaufruf selbst (mit Browser, Bildschirmgröße, Land, Herkunft); das Spiel
## meldet zusätzlich Ereignisse als Pfade, z. B. „start/challenge/kicker/ID“, „challenge/kicker/ID/gold“.
## Nur auf der Hauptversion (kimpixel.github.io/wakeportGame/), nicht in PR-Vorschauen, lokal oder in Tests.
## Auswertung: https://kimpixel.goatcounter.com

const CODE := "kimpixel"                    # GoatCounter-Seite (Account auf goatcounter.com)
## Spielzeit-Marken in Minuten (aktive Zeit im Vordergrund, je Sitzung höchstens einmal gemeldet)
const PLAYTIME := [1, 5, 15, 30, 60, 120]

static var _on := false
static var _played := 0.0
static var _mark := 0


## Beim Start einmal aufrufen: lädt count.js (zählt den Seitenaufruf) und meldet das Gerät.
static func init() -> void:
	if not OS.has_feature("web") or not OS.get_cmdline_user_args().is_empty():
		return
	# Rückgabewerte von JavaScriptBridge.eval kamen im Browser nicht als bool an (nie gezählt): darum
	# nichts zurückgeben, alles im Browser entscheiden. Ohne window.wthCount (falscher Host) zählt count() nichts.
	_on = true
	JavaScriptBridge.eval("""(function () {
	var l = window.location;
	if (l.hostname !== '%s' || l.pathname.indexOf('/pr-preview/') >= 0) return;
	/* Ereignisse vor dem Laden von count.js zwischenspeichern */
	var q = [];
	window.wthCount = function (p, t) {
		var go = function () { window.goatcounter.count({path: p, title: t || p, event: true}); };
		if (window.goatcounter && window.goatcounter.count) go(); else q.push(go);
	};
	var s = document.createElement('script');
	s.async = true;
	s.src = 'https://gc.zgo.at/count.js';
	s.setAttribute('data-goatcounter', 'https://%s.goatcounter.com/count');
	s.onload = function () { q.forEach(function (f) { try { f(); } catch (e) {} }); q = []; };
	document.head.appendChild(s);
	window.wthCount('geraet/' + (navigator.maxTouchPoints > 0 ? 'touch' : 'desktop'));
})()""" % [Leaderboard.HOST, CODE], true)


## Ereignis melden (Pfad ohne führenden Schrägstrich, nur Kleinbuchstaben/Ziffern/-/_ und /).
static func count(path: String) -> void:
	if not _on:
		return
	var p := path.to_lower().replace(" ", "-")
	# als JSON-String eingesetzt: Anführungszeichen, Backslashes und Zeilenumbrüche können das Skript nicht aufbrechen
	JavaScriptBridge.eval("window.wthCount && window.wthCount(%s)" % JSON.stringify(p), true)


## Jeden Frame aufrufen: meldet die Spielzeit-Marken (1, 5, 15 … Minuten).
static func tick(delta: float) -> void:
	if not _on or _mark >= PLAYTIME.size():
		return
	_played += delta
	if _played >= PLAYTIME[_mark] * 60.0:
		count("spielzeit/%dmin" % PLAYTIME[_mark])
		_mark += 1


## Punkte einer Competition-Runde grob einordnen (für „runde/ende/…“).
static func score_bucket(score: int) -> String:
	for b: int in [500, 1000, 2500, 5000, 10000]:
		if score < b:
			return "unter-%d" % b
	return "ab-10000"
