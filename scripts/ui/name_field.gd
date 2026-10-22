class_name NameField
extends VBoxContainer
## Eingabe für den Namen in der Rangliste (Startseite → Rangliste und in den Ergebnisfenstern): Textfeld +
## „Speichern“, darunter eine Meldung. Enter speichert. Handy im Browser: das Textfeld hat dort keine
## Bildschirmtastatur – Tippen öffnet den Browser-Dialog (prompt). Speichert über Leaderboard.set_player_name.

signal saved(name: String)         # Name gespeichert (der Server hat ihn angenommen)

var leaderboard: Leaderboard
var mobile := false
var font: Font
var edit: LineEdit
var msg: Label
var _button: Button


## size: Schriftgröße; label: Text vor dem Feld ("" = keiner).
func build(size: int, label: String, button: Button) -> void:
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	if label != "":
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		if font:
			l.add_theme_font_override("font", font)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	edit = LineEdit.new()
	edit.placeholder_text = tr("dein Name")
	edit.max_length = Leaderboard.NAME_MAX
	edit.custom_minimum_size = Vector2(150, 48)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", size)
	edit.add_theme_stylebox_override("focus", MenuNav.focus_box(6))
	edit.text_submitted.connect(func(_t: String) -> void: save())
	if mobile and OS.has_feature("web"):
		edit.editable = false
		edit.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				var r: Variant = JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(tr("Dein Name für die Rangliste (2 bis 16 Zeichen)")),
					JSON.stringify(edit.text)], true)
				if r is String:
					edit.text = (r as String).substr(0, Leaderboard.NAME_MAX)
					save())
	row.add_child(edit)
	_button = button
	_button.pressed.connect(save)
	row.add_child(_button)
	msg = Label.new()
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	if font:
		msg.add_theme_font_override("font", font)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.visible = false
	add_child(msg)


func set_msg(text: String) -> void:
	msg.text = text
	msg.visible = text != ""


func save() -> void:
	var n := edit.text.strip_edges()
	edit.release_focus()
	if n == "" or n == leaderboard.player_name:
		return
	set_msg(tr("Wird gespeichert …"))
	var r := await leaderboard.set_player_name(n)
	if r.get("ok", false):
		set_msg("")
		saved.emit(n)
	else:
		set_msg(str(r.get("error", tr("Fehler"))))
