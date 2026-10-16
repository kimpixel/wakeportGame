extends CanvasLayer
## Klein ganz unten rechts in der Ecke, immer sichtbar:
##  * Web: Build-Version aus res://version.txt (schreibt der Web-Build, z. B. "v412 · 502fa0a") – damit man
##    am Handy sieht, ob die neue Version geladen ist oder noch eine alte aus dem Cache.
##  * lokal am Desktop: Git-Branch, damit man sieht, aus welchem Checkout/Worktree das Spiel läuft.
##    Liest .git/HEAD direkt (auch im Worktree, dort ist .git eine Datei mit "gitdir: …").

const HEIGHT := 22.0      # px, so viel rückt die Technik-Anzeige des HUD nach oben
const VERSION_FILE := "res://version.txt"


## Web/Export: Build-Version vorhanden; lokal am Desktop: Git-Checkout.
static func available() -> bool:
	return text() != ""


## Anzeigetext: Build-Version, sonst (nur Desktop) der Branch; "" wenn nichts davon.
static func text() -> String:
	if FileAccess.file_exists(VERSION_FILE):
		var v := FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
		if v != "":
			return v
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return ""
	var b := branch()
	return "⎇ " + b if b != "" else ""


## Aktueller Branch, bei abgelöstem HEAD die ersten 8 Zeichen des Commits; "" ohne Git.
static func branch() -> String:
	var git := ProjectSettings.globalize_path("res://").path_join(".git")
	var head_path := git.path_join("HEAD")
	if FileAccess.file_exists(git):                     # Worktree: .git ist eine Datei
		var line := FileAccess.get_file_as_string(git).strip_edges()
		if not line.begins_with("gitdir:"):
			return ""
		head_path = line.trim_prefix("gitdir:").strip_edges().path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head := FileAccess.get_file_as_string(head_path).strip_edges()
	if head.begins_with("ref:"):
		return head.trim_prefix("ref:").strip_edges().trim_prefix("refs/heads/")
	return head.substr(0, 8)


func _init() -> void:
	layer = 40                                 # über Startseite, Pause, Debug
	process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.text = text()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_right = -8
	label.offset_bottom = -4
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
