class_name Loc
extends RefCounted
## Sprachen (gettext): Ausgangstext im Code ist Deutsch (msgid), Übersetzungen in locale/*.po.
## Texte im Code mit tr("…") (in Nodes) bzw. Loc.t("…") (statisch, ohne Node) übersetzen; Daten-Tabellen
## (const) mit `# i18n` am Zeilenende bzw. `# i18n-begin schlüssel,…` … `# i18n-end` markieren und beim
## Anzeigen übersetzen. Vorlage und Abgleich: `node tools/i18n.js extract` (siehe dort).
## Tricknamen, Fachbegriffe (Raley, Kicker, Boardslide …) und Namen von Features/Setups bleiben englisch
## bzw. wie sie sind. Einstellung "lang": "" = Sprache des Systems/Browsers (sonst Englisch).
## Sprachwechsel baut die Szene neu auf (main.gd), Texte werden beim Aufbau übersetzt.

## [Code, Name in der eigenen Sprache]
const LANGS := [
	["de", "Deutsch"],
	["en", "English"],
	["fr", "Français"],
	["es", "Español"],
	["nl", "Nederlands"],
	["pl", "Polski"],
	["cs", "Čeština"],
	["pt_BR", "Português (Brasil)"],
]
## ohne passende Sprache des Systems
const FALLBACK := "en"


## Sprache einstellen ("" = automatisch). Liefert den verwendeten Code.
static func apply(code: String) -> String:
	var c := code if has(code) else detect()
	TranslationServer.set_locale(c)
	return c


## Sprache des Systems bzw. Browsers, falls übersetzt; sonst Englisch.
static func detect() -> String:
	var full := OS.get_locale()                      # z. B. "de_DE", "pt_BR", "fr"
	var lang := OS.get_locale_language()
	if has(full):
		return full
	if lang == "pt":
		return "pt_BR"
	if has(lang):
		return lang
	return FALLBACK


static func has(code: String) -> bool:
	for l: Array in LANGS:
		if l[0] == code:
			return true
	return false


## Aktuelle Sprache (Code wie in LANGS).
static func current() -> String:
	var c := TranslationServer.get_locale()
	if has(c):
		return c
	var lang := c.get_slice("_", 0)
	if lang == "pt":
		return "pt_BR"
	return lang if has(lang) else "de"


## Deutsch? (z. B. Artikel vor Feature-Namen nur im Deutschen)
static func is_de() -> bool:
	return current() == "de"


## Übersetzen ohne Node (statische Funktionen, Daten).
static func t(s: String, ctx := "") -> String:
	if s == "":
		return s
	return String(TranslationServer.translate(s, ctx))


## Mehrzahl ohne Node: Loc.tn("%d Punkt", "%d Punkte", n) % n
static func tn(s: String, plural: String, n: int, ctx := "") -> String:
	return String(TranslationServer.translate_plural(s, plural, n, ctx))


## Ganze Zahl mit Tausender-Trennzeichen der Sprache (12.500 / 12,500 / 12 500).
static func thousands(v: int) -> String:
	var sep := "."
	match current():
		"en":
			sep = ","
		"fr", "pl", "cs":
			sep = " "
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


## Zahl im Text mit dem Dezimaltrennzeichen der Sprache ("2.40 m" -> "2,40 m"; Englisch bleibt beim Punkt).
static func dec(s: String) -> String:
	return s if current() == "en" else s.replace(".", ",")


## Name eines Feature-Setups aus setups/index.json übersetzt, z. B. "Juli & August (Jahr ?)"; short: ohne den Zusatz in
## Klammern (Auswahl auf der Startseite, Ranglisten).
static func setup_name(n: String, short := false) -> String:
	var base := n.get_slice(" (", 0)
	if short or base == n:
		return t(base)
	return t(base) + " " + t(n.substr(base.length() + 1))
