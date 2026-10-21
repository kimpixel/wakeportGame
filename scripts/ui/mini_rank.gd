class_name MiniRank
extends PanelContainer
## Kurze Rangliste im Spiel (rechts in der Mitte, Teil des HUD): die ersten 3 und die eigene Position mit dem
## Nachbarn davor und dahinter, dazwischen „…“.
##
## **Durchgehend nummeriert, jede Nummer einmal.** Competition: die echte Rangliste – der eigene bisherige Rekord ist
## eine normale Zeile mit Platz und Namen, markiert mit einer Raute („dein Rekord“) – plus **DU** mit den Punkten der
## laufenden Runde, nach Wert einsortiert. Erreicht DU den Rekord, verschmelzen beide: Rekord-Zeile weg, DU gold
## („DU · REKORD“, Stern), Titel kurz „Neuer Rekord!“. Unter DU klein das nächste Ziel („noch 150 bis 6.“).
## Überholt man jemanden, blitzt die DU-Zeile auf und oben steht kurz „Jonas überholt!“.
## Challenge: DU = eigener Bestwert mit Platz; nach einem neuen Bestwert gold (`mark_record`).
##
## Immer schmal am Rand im Kasten mit wenig Innenabstand: Desktop/quer Platz + Name, darunter klein der Wert;
## hochkant am Handy nur die Plätze untereinander (Rekord mit kleiner Raute, eigene Punkte stehen oben in der Leiste).
## Daten kommen von main.gd (Leaderboard.top), nichts wird hier geladen.

const TOP := 3                    # immer gezeigt
const NAME_W := 96.0              # Namensspalte (Desktop/quer)
const FLAG_COLOR := Color(0.55, 0.82, 0.22, 0.6)    # Markierung „dein Rekord“ (gedämpftes Grün)
const GOLD := Color(1.0, 0.82, 0.2)

var compact := false              # Handy hochkant: ohne Namen, schmal
var show_self := false            # eigene Zeile auch ohne Wert („DU –“; main.gd: nimmt an der Rangliste teil)
var _board := {}                  # Leaderboard-Board (für das Format der Werte)
var _entries: Array = []          # vom Server, sortiert (rank, name, value, me)
var _total := 0
var _best := {}                   # eigener Eintrag vom Server {rank, value} = Rekord vor dieser Runde
var _live := NAN                  # Competition: Punkte der laufenden Runde (NAN = keine eigene Live-Zeile)
var _record := false              # Challenge: gerade einen neuen Bestwert gefahren (gold)
var _last_rank := 0               # Competition: Platz von DU beim letzten Bild (für „überholt“)
var _flash := 0.0                 # s, DU-Zeile blitzt nach dem Überholen
var _toast := 0.0                 # s, Titel zeigt „… überholt!“
var _toast_text := ""
var _rows: VBoxContainer
var _title: Label
var _font: Font
var _shown := ""                  # zuletzt gebaute Zeilen (nur neu bauen, wenn sich etwas ändert)
var _me_row: Control
var _blocked: Array = []          # [lang, kurz]: hier gilt keine Rangliste (Hinweis statt Liste)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Kasten im HUD-Stil, aber mit wenig Innenabstand – die Spalte soll schmal am Rand stehen
	var sb := StyleBoxFlat.new()
	sb.bg_color = Hud.PANEL
	sb.set_corner_radius_all(8)
	sb.border_width_left = 3
	sb.border_color = Hud.ACCENT
	sb.content_margin_left = 6
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	sf.font_weight = 700
	_font = sf
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = _label(13, Color(1, 1, 1, 0.6))
	v.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_rows)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		if is_instance_valid(_me_row):
			_me_row.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.4), _flash / 0.8)
	if _toast > 0.0:
		_toast -= delta
		if _toast <= 0.0:
			_shown = ""
			_rebuild()


## Neue Rangliste (Antwort von Leaderboard.top) – leer/ohne board: ausblenden.
func set_data(board: Dictionary, r: Dictionary) -> void:
	if board.get("board", "") != _board.get("board", "") or board.get("ver", "") != _board.get("ver", ""):
		_last_rank = 0                            # andere Rangliste: kein „überholt“ aus dem Wechsel
		_record = false
	_blocked = []
	_board = board
	_entries = r.get("entries", []) if r.get("ok", false) else []
	_total = int(r.get("total", 0))
	_best = r.get("me") if r.get("me") is Dictionary else {}
	visible = not board.is_empty() and r.get("ok", false)
	_shown = ""
	_rebuild()


## Competition: aktuelle Punkte der Runde (eigene Zeile live); NAN = keine. Bei 0 Punkten (neue Runde) beginnt
## das Zählen fürs Überholen neu.
func set_live(score: float) -> void:
	if is_nan(score) and is_nan(_live):
		return
	if not is_nan(score) and (is_nan(_live) or score < _live):
		_last_rank = 0
	_live = score
	_rebuild()


## Challenge: neuer Bestwert gefahren – DU gold, bis clear_record().
func mark_record() -> void:
	_record = true
	refresh()


func clear_record() -> void:
	if _record:
		_record = false
		refresh()


## Neu aufbauen (z. B. nach Wechsel hochkant/quer).
func refresh() -> void:
	if not _blocked.is_empty():
		var why := _blocked
		_blocked = []
		set_blocked(why)
		return
	_shown = ""
	_rebuild()


func clear() -> void:
	_board = {}
	_entries = []
	_blocked = []
	visible = false


## Hier gilt keine Rangliste: statt der Liste ein Hinweis warum ([lang, kurz]; hochkant am Handy der kurze, schmal).
func set_blocked(why: Array) -> void:
	if why == _blocked and visible:
		return
	_blocked = why
	_board = {}
	_entries = []
	visible = true
	for c in _rows.get_children():
		c.queue_free()
	_me_row = null
	_shown = ""
	_title.visible = true
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_title.text = "RANG-\nLISTE\nAUS" if compact else "KEINE RANGLISTE"
	var l := _label(11 if compact else 12, Color(1, 1, 1, 0.8))
	l.text = str(why[1] if compact else why[0])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 52.0 if compact else 130.0
	_rows.add_child(l)


func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _better(a: float, b: float) -> bool:
	return (a < b) if _board.get("lower", false) else (a > b)


## Zeilen: [{rank, name, value, me, gold, flag, target}].
func _list() -> Array:
	var out: Array = []
	if is_nan(_live):
		# Challenge: der eigene Server-Eintrag ist DU
		for e: Dictionary in _entries:
			var d: Dictionary = e.duplicate()
			if d.get("me", false):
				d["name"] = "DU"
				d["gold"] = _record
			out.append(d)
		if show_self and not _entries.any(func(e: Dictionary) -> bool: return e.get("me", false)):
			if _best.is_empty():
				out.append({"name": "DU", "value": NAN, "me": true, "rank": 0})
			else:                                 # eigener Eintrag hinter den geladenen 50
				out.append({"name": "DU", "value": float(_best["value"]), "me": true, "gold": _record,
					"rank": int(_best.get("rank", 0))})
		return out
	# Competition: die echte Rangliste (mit dem eigenen Rekord als Zeile, Raute) plus DU mit den Punkten der Runde,
	# alle durchgehend nummeriert. Erreicht DU den Rekord, verschmelzen beide: Rekord-Zeile weg, DU gold.
	var beaten := not _best.is_empty() and not _better(float(_best.get("value", 0.0)), _live)
	for e: Dictionary in _entries:
		var d: Dictionary = e.duplicate()
		if d.get("me", false):
			if beaten:
				continue
			d.erase("me")
			d["flag"] = true
		out.append(d)
	if not beaten and not _best.is_empty() and not _entries.any(func(e: Dictionary) -> bool: return e.get("me", false)):
		out.append({"name": str(_best.get("name", "DU")), "value": float(_best["value"]), "flag": true})  # hinter Platz 50
	var du := {"name": "DU", "value": _live, "me": true, "live": true, "gold": beaten}
	var at := out.size()
	for i in out.size():
		if _better(_live, float(out[i]["value"])):
			at = i
			break
	out.insert(at, du)
	for i in out.size():
		out[i]["rank"] = i + 1
	# hinter der geladenen Liste (nur die besten 50): genauer Platz unbekannt
	if at == out.size() - 1 and _rows_total() > out.size():
		du["rank"] = -out.size()                  # negativ = „ab Platz …“
	if at > 0:                                    # nächstes Ziel: der direkt vor DU
		var above: Dictionary = out[at - 1]
		du["target"] = [absf(float(above["value"]) - _live), int(above["rank"])]
	return out


## Competition: so viele Zeilen hat die ganze Liste (alle Fahrer + DU; geknackter Rekord und DU sind eine).
func _rows_total() -> int:
	var beaten := not _best.is_empty() and not _better(float(_best.get("value", 0.0)), _live)
	return _total + (0 if beaten else 1)


func _rebuild() -> void:
	if not visible or not _blocked.is_empty():
		return
	var list := _list()
	var me := -1
	var flag := -1
	for i in list.size():
		if list[i].get("me", false):
			me = i
		if list[i].get("flag", false):
			flag = i
	_check_overtake(list, me)
	var show: Array = []                          # Indizes, -1 = „…“
	for i in list.size():
		if i < TOP or (me >= 0 and absi(i - me) <= 1) or i == flag:
			if not show.is_empty() and show.back() >= 0 and i - show.back() > 1:
				show.append(-1)
			show.append(i)
	var key := ""
	for i: int in show:
		if i < 0:
			key += "…"
			continue
		var e: Dictionary = list[i]
		key += "%s|%s|%s|%s|%s|" % [e.get("rank", 0), e["name"], _value(e["value"]), e.get("gold", false), e.get("target", [])]
	key += str(_total) + str(compact) + (_toast_text if _toast > 0.0 else "")
	if key == _shown:
		return
	_shown = key
	for c in _rows.get_children():
		c.queue_free()
	_me_row = null
	var n := _total if is_nan(_live) else _rows_total()
	_title.text = "RANGLISTE · %d" % n if n > 0 else "RANGLISTE"
	_title.add_theme_color_override("font_color", GOLD if _toast > 0.0 else Color(1, 1, 1, 0.6))
	if _toast > 0.0:
		_title.text = _toast_text
	_title.visible = not compact
	if list.is_empty():
		if not compact:
			_rows.add_child(_label(14, Color(1, 1, 1, 0.75)))
			(_rows.get_child(-1) as Label).text = "Noch frei – Platz 1 wartet"
		return
	for i: int in show:
		var c := _row(list[i]) if i >= 0 else _dots()
		_rows.add_child(c)
		if i >= 0 and list[i].get("me", false):
			_me_row = c


## Competition: DU ist aufgestiegen -> DU-Zeile blitzt, oben kurz „Name überholt!“ (mehrere: „2 überholt!“).
func _check_overtake(list: Array, me: int) -> void:
	if is_nan(_live) or me < 0:
		return
	var rank := int(list[me].get("rank", 0))
	if rank <= 0:
		return
	if _last_rank > 0 and rank < _last_rank and _live > 0.0:
		var names: Array = []
		for e: Dictionary in list:
			var r := int(e.get("rank", 0))
			if not e.get("me", false) and not e.get("flag", false) and r > rank and r <= _last_rank:
				names.append(str(e.get("name", "?")))
		_flash = 0.8
		_toast = 2.5
		if names.is_empty():                      # nur am eigenen Rekord vorbei
			_toast_text = "Neuer Rekord!"
		else:
			_toast_text = ("%s überholt!" % names[0]) if names.size() == 1 else ("%d überholt!" % names.size())
	_last_rank = rank


func _dots() -> Control:
	var l := _label(12, Color(1, 1, 1, 0.45))
	l.text = "…"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	return l


func _rank_text(e: Dictionary, dot: bool) -> String:
	var rank := int(e.get("rank", 0))
	if rank > 0:
		return ("%d." % rank) if dot else str(rank)
	return ("%d+" % -rank) if rank < 0 else "–"


func _color(e: Dictionary) -> Color:
	if e.get("gold", false):
		return GOLD
	if e.get("me", false):
		return Hud.ACCENT
	if e.get("flag", false):
		return FLAG_COLOR
	var rank := int(e.get("rank", 0))
	return Color(1.0, 0.82, 0.2, 0.9) if rank >= 1 and rank <= 3 else Color(1, 1, 1, 0.8)


## Handy hochkant: nur der Platz (DU grün und etwas größer, mit Rekord gold mit Stern; Rekord-Markierung = Raute).
func _row_compact(e: Dictionary) -> Control:
	var me: bool = e.get("me", false)
	var col := _color(e)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(17 if me else 15, col)
	l.text = _rank_text(e, false)
	h.add_child(l)
	if e.get("gold", false) or e.get("flag", false):   # Stern = neuer Rekord, Raute = bisheriger Rekord
		h.add_child(Mark.new(not e.get("flag", false), col, 11.0 if e.get("gold", false) else 9.0))
	return h


func _row(e: Dictionary) -> Control:
	if compact:
		return _row_compact(e)
	# Desktop/quer: Platz + Name, darunter klein der Wert (DU: und das nächste Ziel)
	var me: bool = e.get("me", false)
	var flag: bool = e.get("flag", false)
	var col := _color(e)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var rl := _label(14, col)
	rl.text = _rank_text(e, true)
	rl.custom_minimum_size.x = 24
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(rl)
	var nl := _label(14, col if (me or flag) else Color.WHITE)
	nl.text = str(e.get("name", "?"))
	if e.get("gold", false):
		nl.text = "DU · REKORD"
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size.x = NAME_W
	h.add_child(nl)
	if e.get("gold", false) or flag:              # Stern = neuer Rekord, Raute = dein bisheriger Rekord
		h.add_child(Mark.new(not flag, col, 12.0 if not flag else 10.0))
	var sub := _value(e.get("value", 0.0))
	if flag:
		sub = "dein Rekord · " + sub
	v.add_child(_sub(sub, Color(col, 0.9) if (me or flag) else Color(1, 1, 1, 0.6)))
	var t: Array = e.get("target", [])
	if me and not t.is_empty():                   # nächstes Ziel
		v.add_child(_sub("noch %s bis %d." % [_value(t[0]), t[1]], Color(1, 1, 1, 0.7)))
	return v


## Kleine Zeile unter dem Namen (eingerückt wie der Name).
func _sub(text: String, c: Color) -> Control:
	var vl := _label(11, c)
	vl.text = text
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(vl)
	return pad


func _value(v: Variant) -> String:
	return "–" if is_nan(float(v)) else Leaderboard.format_short(_board, float(v))


## Kleines Zeichen, selbst gezeichnet (◆/★ fehlen in der Web-Schrift): Raute = Rekord-Markierung, Stern = neuer Rekord.
class Mark extends Control:
	var star := false
	var color := Color.WHITE

	func _init(s: bool, c: Color, size_px: float) -> void:
		star = s
		color = c
		custom_minimum_size = Vector2(size_px, size_px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var pts := PackedVector2Array()
		var n := 10 if star else 4
		for i in n:
			var a := -PI * 0.5 + TAU * i / n
			var rr := r if (not star or i % 2 == 0) else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, color)
