class_name MiniRank
extends PanelContainer
## Kurze Rangliste im Spiel (rechts in der Mitte, Teil des HUD): die ersten 3 und die eigene Position mit dem
## Nachbarn davor und dahinter, dazwischen „…“. Competition: die eigene Zeile wandert live mit den Punkten der
## Runde mit („DU“), dazu gedämpft der bisherige Bestwert mit seinem echten Platz („BESTWERT“); Challenge: der
## eigene Bestwert. Immer schmal am Rand im Kasten mit wenig Innenabstand:
## Desktop/quer Platz + Name, darunter klein der Wert; hochkant am Handy nur die Plätze untereinander (eigene Punkte
## stehen oben in der Leiste).
## Daten kommen von main.gd (Leaderboard.top), nichts wird hier geladen.

const TOP := 3                    # immer gezeigt
const NAME_W := 96.0              # Namensspalte (Desktop/quer)
const BEST_COLOR := Color(0.55, 0.82, 0.22, 0.55)   # eigener bisheriger Bestwert (gedämpftes Grün)

var compact := false              # Handy hochkant: ohne Namen, schmal
var show_self := false            # eigene Zeile auch ohne Wert („DU –“; main.gd: nimmt an der Rangliste teil)
var _board := {}                  # Leaderboard-Board (für das Format der Werte)
var _entries: Array = []          # vom Server, sortiert (rank, name, value, me)
var _total := 0
var _best := {}                   # eigener Eintrag vom Server {rank, value} (Competition: Platz vor dieser Runde)
var _live := NAN                  # Competition: Punkte der laufenden Runde (NAN = keine eigene Live-Zeile)
var _rows: VBoxContainer
var _title: Label
var _font: Font
var _shown := ""                  # zuletzt gebaute Zeilen (nur neu bauen, wenn sich etwas ändert)


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


## Neue Rangliste (Antwort von Leaderboard.top) – leer/ohne board: ausblenden.
func set_data(board: Dictionary, r: Dictionary) -> void:
	_board = board
	_entries = r.get("entries", []) if r.get("ok", false) else []
	_total = int(r.get("total", 0))
	_best = r.get("me") if r.get("me") is Dictionary else {}      # eigener Bestwert mit Platz (auch hinter Platz 50)
	visible = not board.is_empty() and r.get("ok", false)
	_shown = ""
	_rebuild()


## Competition: aktuelle Punkte der Runde (eigene Zeile live); NAN = keine.
func set_live(score: float) -> void:
	if is_nan(score) and is_nan(_live):
		return
	_live = score
	_rebuild()


## Neu aufbauen (z. B. nach Wechsel hochkant/quer).
func refresh() -> void:
	_shown = ""
	_rebuild()


func clear() -> void:
	_board = {}
	_entries = []
	visible = false


func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Zeilen: [{rank, name, value, me, live}] – mit Live-Zeile statt des eigenen Server-Eintrags.
func _list() -> Array:
	var out: Array = []
	if is_nan(_live):
		for e: Dictionary in _entries:
			out.append(e)
		# Challenge noch ohne eigenen Wert: „DU –“ unten dran
		if show_self and not _entries.any(func(e: Dictionary) -> bool: return e.get("me", false)):
			out.append({"name": "DU", "value": NAN, "me": true, "live": true, "rank": 0})
		return out
	var lower: bool = _board.get("lower", false)
	var placed := false
	for e: Dictionary in _entries:
		if e.get("me", false):
			continue
		var v := float(e.get("value", 0.0))
		if not placed and ((_live < v) if lower else (_live > v)):
			out.append({"name": "DU", "value": _live, "me": true, "live": true})
			placed = true
		out.append(e.duplicate())
	if not placed:
		out.append({"name": "DU", "value": _live, "me": true, "live": true})
	for i in out.size():
		out[i]["rank"] = i + 1
	# hinter der geladenen Liste (nur die besten 50): genauer Platz unbekannt
	var others := _total - (1 if not _best.is_empty() else 0)
	if out.back().get("live", false) and others > out.size() - 1:
		out.back()["rank"] = -out.size()          # negativ = „ab Platz …“
	# der eigene bisherige Bestwert mit seinem echten Platz, nach Wert einsortiert (zählt nicht zu den Plätzen oben)
	if not _best.is_empty():
		var bv := float(_best.get("value", 0.0))
		var at := out.size()
		for i in out.size():
			var v := float(out[i]["value"])
			if (bv < v) if lower else (bv > v):
				at = i
				break
		out.insert(at, {"name": "BESTWERT", "value": bv, "best": true, "rank": int(_best.get("rank", 0))})
	return out


func _rebuild() -> void:
	if not visible:
		return
	var list := _list()
	var me := -1
	var best := -1
	for i in list.size():
		if list[i].get("me", false):
			me = i
		if list[i].get("best", false):
			best = i
	var show: Array = []                          # Indizes, -1 = „…“
	for i in list.size():
		if i < TOP or (me >= 0 and absi(i - me) <= 1) or i == best:
			if not show.is_empty() and show.back() >= 0 and i - show.back() > 1:
				show.append(-1)
			show.append(i)
	var key := ""
	for i: int in show:
		key += ("…" if i < 0 else "%d|%s|%s|" % [list[i]["rank"], list[i]["name"], _value(list[i]["value"])])
	key += str(_total) + str(compact)
	if key == _shown:
		return
	_shown = key
	for c in _rows.get_children():
		c.queue_free()
	var n := _total
	if not is_nan(_live) and not _entries.any(func(e: Dictionary) -> bool: return e.get("me", false)):
		n += 1                                    # die laufende Runde zählt mit
	_title.text = "RANGLISTE · %d" % n if n > 0 else "RANGLISTE"
	_title.visible = not compact
	if list.is_empty():
		if not compact:
			_rows.add_child(_label(14, Color(1, 1, 1, 0.75)))
			(_rows.get_child(-1) as Label).text = "Noch frei – Platz 1 wartet"
		return
	for i: int in show:
		_rows.add_child(_row(list[i]) if i >= 0 else _dots())


func _dots() -> Control:
	var l := _label(12, Color(1, 1, 1, 0.45))
	l.text = "…"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	return l


## Handy hochkant: nur der Platz (eigener grün und etwas größer).
func _row_compact(e: Dictionary) -> Control:
	var me: bool = e.get("me", false)
	var rank := int(e.get("rank", 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Hud.ACCENT if me else (Color(1.0, 0.82, 0.2) if rank >= 1 and rank <= 3 else Color(1, 1, 1, 0.85))
	if e.get("best", false):
		col = BEST_COLOR
	var rl := _label(17 if me else 15, col)
	rl.text = ("%d" % rank) if rank > 0 else (("%d+" % -rank) if rank < 0 else "–")
	v.add_child(rl)
	return v


func _row(e: Dictionary) -> Control:
	if compact:
		return _row_compact(e)
	# Desktop/quer: Platz + Name, darunter klein der Wert (schmal, ohne Kasten)
	var me: bool = e.get("me", false) or e.get("best", false)
	var rank := int(e.get("rank", 0))
	var col := Hud.ACCENT if me else (Color(1.0, 0.82, 0.2) if rank >= 1 and rank <= 3 else Color(1, 1, 1, 0.8))
	if e.get("best", false):
		col = BEST_COLOR
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var rl := _label(14, col)
	rl.text = ("%d." % rank) if rank > 0 else (("%d+" % -rank) if rank < 0 else "–")
	rl.custom_minimum_size.x = 24
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(rl)
	var nl := _label(14, col if me else Color.WHITE)
	nl.text = "DU" if e.get("live", false) else str(e.get("name", "?"))
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size.x = NAME_W
	h.add_child(nl)
	var vl := _label(11, Color(col, 0.9) if me else Color(1, 1, 1, 0.6))
	vl.text = _value(e.get("value", 0.0))
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(vl)
	v.add_child(pad)
	return v


func _value(v: Variant) -> String:
	return "–" if is_nan(float(v)) else Leaderboard.format_short(_board, float(v))
