extends CanvasLayer
## Git-Branch klein ganz unten rechts in der Ecke (nur lokal am Desktop): damit man sieht, aus welchem
## Checkout/Worktree das Spiel gestartet wurde. Liest .git/HEAD direkt (auch im Worktree, dort ist
## .git eine Datei mit "gitdir: …"). Ohne .git (Web, Export) bleibt die Ebene leer.

const HEIGHT := 22.0      # px, so viel rückt die Technik-Anzeige des HUD nach oben


## Nur Desktop und nur, wenn das Projekt in einem Git-Checkout liegt.
static func available() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile") and branch() != ""


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
	label.text = "⎇ " + branch()
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
