class_name MenuNav
extends Node
## Menüs mit Tastatur und Gamepad bedienen: Fokus wandert mit ←/→/↑/↓ (Steuerkreuz und linker Stick)
## zum nächsten Knopf in dieser Richtung, Tab / Umschalt+Tab der Reihe nach. Leertaste bzw. Gamepad X
## (ui_accept) drückt den Knopf mit Fokus (macht Godot selbst), Esc bzw. Kreis (ui_cancel) und
## Enter bzw. PS (menu_start) behandeln die Menüs selbst.
## Menüs melden ihren Bereich mit add_scope an; bedient wird immer der sichtbare Bereich mit der
## höchsten Stufe (Liste einer Auswahlbox über Popup über Startseite). Ohne sichtbaren Bereich (im Spiel)
## tut MenuNav nichts. Fokus bekommt jeder sichtbare Knopf, Schieber oder Textfeld im Bereich.

const REPEAT_DELAY := 0.35       # s gehalten, bis die Richtung wiederholt
const REPEAT_RATE := 0.1         # s zwischen Wiederholungen

static var _scopes: Array = []   # {root, prio, first, passive, last}

var touch := false               # Handy: Fokus erst zeigen, wenn Tastatur/Gamepad benutzt wird
var _used := false
var _cur: Dictionary = {}
var _held := Vector2.ZERO
var _hold_t := 0.0


## Bereich anmelden. first: Knopf mit Fokus beim Öffnen (sonst der erste); passive: Bereich bedient
## sich selbst (Setup-Editor), MenuNav lässt dann alles durch.
static func add_scope(root: Control, prio: int, first: Control = null, passive := false) -> void:
	remove_scope(root)
	_scopes.append({"root": root, "prio": prio, "first": first, "passive": passive, "last": null})


static func remove_scope(root: Control) -> void:
	for i in range(_scopes.size() - 1, -1, -1):
		if _scopes[i]["root"] == root or not is_instance_valid(_scopes[i]["root"]):
			_scopes.remove_at(i)


## Beim nächsten Öffnen wieder auf den ersten Knopf (statt den zuletzt gewählten).
static func reset_focus(root: Control) -> void:
	for s: Dictionary in _scopes:
		if s["root"] == root:
			s["last"] = null


## Rahmen für den Fokus (über dem normalen Aussehen des Knopfs).
static func focus_box(radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(3)
	sb.border_color = Color.WHITE
	sb.set_corner_radius_all(radius)
	sb.set_expand_margin_all(3)
	return sb


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_used = not touch


static func _shown(c: Variant) -> bool:
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	var n: Node = c
	while n:
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			return false
		n = n.get_parent()
	return true


func _active() -> Dictionary:
	var best: Dictionary = {}
	for s: Dictionary in _scopes:
		if is_instance_valid(s["root"]) and _shown(s["root"]) and (best.is_empty() or int(s["prio"]) >= int(best["prio"])):
			best = s
	return best


func _focusables(root: Control) -> Array[Control]:
	var out: Array[Control] = []
	_collect(root, out)
	return out


func _collect(n: Node, out: Array[Control]) -> void:
	for c in n.get_children():
		var ctl := c as Control
		if ctl == null or not ctl.visible:
			continue
		if (ctl is BaseButton and not (ctl as BaseButton).disabled) or ctl is Slider or ctl is LineEdit:
			out.append(ctl)
		_collect(ctl, out)


func _inside(c: Variant, root: Variant) -> bool:
	return is_instance_valid(c) and is_instance_valid(root) and (c == root or (root as Node).is_ancestor_of(c))


func _focus(c: Control) -> void:
	if c == null:
		return
	if c.focus_mode == Control.FOCUS_NONE:
		c.focus_mode = Control.FOCUS_ALL
	c.grab_focus()
	var n := c.get_parent()
	while n:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(c)
			break
		n = n.get_parent()


func _default_focus(s: Dictionary) -> Control:
	for key: String in ["last", "first"]:
		var c: Control = s[key] if is_instance_valid(s[key]) else null
		if c and _shown(c) and _inside(c, s["root"]):
			return c
	for c in _focusables(s["root"]):
		if not c.has_meta("nav_close"):
			return c
	return null


func _process(delta: float) -> void:
	var s := _active()
	var owner := get_viewport().gui_get_focus_owner()
	if s != _cur:
		if not _cur.is_empty() and _inside(owner, _cur["root"]):
			_cur["last"] = owner
		if s.is_empty() and owner and _cur.size() > 0 and _inside(owner, _cur["root"]):
			owner.release_focus()
		_cur = s
		owner = null
	if s.is_empty() or s["passive"] or not _used:
		return
	if owner == null or not _inside(owner, s["root"]) or not _shown(owner):
		_focus(_default_focus(s))
		owner = get_viewport().gui_get_focus_owner()
	s["last"] = owner
	# Richtung (Steuerkreuz, linker Stick, Pfeiltasten) mit Wiederholung beim Halten
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir = Vector2.LEFT
	elif Input.is_action_pressed("ui_right"):
		dir = Vector2.RIGHT
	elif Input.is_action_pressed("ui_up"):
		dir = Vector2.UP
	elif Input.is_action_pressed("ui_down"):
		dir = Vector2.DOWN
	if dir == Vector2.ZERO:
		_held = Vector2.ZERO
		return
	if dir != _held:
		_held = dir
		_hold_t = -REPEAT_DELAY
	else:
		_hold_t += delta
		if _hold_t < REPEAT_RATE:
			return
		_hold_t = 0.0
	_step(s, owner, dir)


func _step(s: Dictionary, owner: Control, dir: Vector2) -> void:
	if owner is LineEdit and dir.y == 0.0:
		return                                     # Textfeld: ←/→ bewegen den Cursor
	if owner is Slider and dir.y == 0.0:
		var sl := owner as Slider
		var st := sl.step if sl.step > 0.0 else (sl.max_value - sl.min_value) / 20.0
		st = maxf(st, (sl.max_value - sl.min_value) / 40.0)
		sl.value = clampf(sl.value + dir.x * st, sl.min_value, sl.max_value)
		return
	var from := owner.get_global_rect() if owner else Rect2()
	var c0 := from.get_center()
	var best: Control = null
	var best_score := INF
	for c in _focusables(s["root"]):
		if c == owner or not _shown(c):
			continue
		var r := c.get_global_rect()
		var v := r.get_center() - c0
		var along := v.dot(dir)
		# Abstand in Richtung: Kante zu Kante, damit breite Knöpfe nicht benachteiligt sind
		var gap := along - (absf(dir.x) * (from.size.x + r.size.x) + absf(dir.y) * (from.size.y + r.size.y)) * 0.5
		if along <= 1.0 or gap < -4.0:
			continue
		# quer dazu: Überlappung zählt als 0
		var perp: float
		if dir.x != 0.0:
			perp = maxf(0.0, maxf(r.position.y - from.end.y, from.position.y - r.end.y))
		else:
			perp = maxf(0.0, maxf(r.position.x - from.end.x, from.position.x - r.end.x))
		var score := maxf(gap, 0.0) + perp * 3.0 + absf(v.dot(Vector2(dir.y, -dir.x))) * 0.05
		if score < best_score:
			best_score = score
			best = c
	if best:
		_focus(best)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		if not _used:
			_used = true
	var s := _cur
	if s.is_empty() or s["passive"] or not _used or not _shown(s["root"]):
		return
	var owner := get_viewport().gui_get_focus_owner()
	var prev := event.is_action("ui_focus_prev", true)      # genau: Umschalt+Tab passt sonst auch zu Tab
	if prev or event.is_action("ui_focus_next", true):
		if event.is_pressed():
			var list := _focusables(s["root"]).filter(func(c: Control) -> bool: return _shown(c))
			if not list.is_empty():
				var i := list.find(owner)
				var d := -1 if prev else 1
				_focus(list[posmod(i + d, list.size()) if i >= 0 else 0])
		get_viewport().set_input_as_handled()
		return
	var horiz := event.is_action("ui_left") or event.is_action("ui_right")
	if horiz and owner is LineEdit:
		return
	if horiz or event.is_action("ui_up") or event.is_action("ui_down"):
		get_viewport().set_input_as_handled()     # Richtung macht _process (mit Wiederholung)
