class_name BoardLibrary
extends RefCounted
## Bibliothek der Wakeboard-Designs. Form von Brett und Bindung ist bei allen exakt gleich
## (scripts/wakeboard.gd), es variieren nur Muster und Farben:
##   top_style / bottom_style: Muster der Ober-/Unterseite (siehe shaders/wakeboard.gdshader)
##     0 = Zeitungs-Design (bzw. Foto-Texturen, falls vorhanden)
##     oben:  1 Diagonal-Streifen, 2 Farbverlauf mit Chevrons, 3 Höhenlinien, 4 Rasterpunkte
##     unten: 1 Querband mit Linien, 2 Verlauf mit Retro-Sonne, 3 Zickzack-Bänder, 4 Karo an den Spitzen
##   top_a/b/c, bottom_a/b/c: Farben (Grund, Muster, Akzent)
##   boot_upper: Obermaterial der Bindung, boot_accent: Akzente (Sohlenstreifen, Fersenschlaufe),
##   boot_panel: Seitenfeld einfarbig – oder camo: vier Tarnfarben für das Seitenfeld
## Benutzung überall in der Welt:  var board := BoardLibrary.make(2)

const DESIGNS := [
	{
		"name": "Zeitung",
		"top_style": 0, "bottom_style": 0,
		# Bindung wie gehabt: oliv, orange Akzente, Camo-Seitenfeld
	},
	{
		"name": "Sunset",
		"top_style": 1, "top_a": Color(0.08, 0.10, 0.22), "top_b": Color(0.98, 0.50, 0.15), "top_c": Color(0.95, 0.36, 0.52),
		"bottom_style": 2, "bottom_a": Color(0.98, 0.62, 0.20), "bottom_b": Color(0.45, 0.16, 0.42), "bottom_c": Color(1.0, 0.86, 0.30),
		"boot_upper": Color(0.12, 0.12, 0.14), "boot_accent": Color(1.0, 0.45, 0.12), "boot_panel": Color(0.28, 0.29, 0.31),
	},
	{
		"name": "Ice",
		"top_style": 2, "top_a": Color(0.93, 0.96, 1.0), "top_b": Color(0.22, 0.55, 0.86), "top_c": Color(0.06, 0.12, 0.30),
		"bottom_style": 1, "bottom_a": Color(0.95, 0.96, 0.97), "bottom_b": Color(0.07, 0.14, 0.32), "bottom_c": Color(0.20, 0.75, 0.90),
		"boot_upper": Color(0.86, 0.87, 0.89), "boot_accent": Color(0.15, 0.70, 0.90), "boot_panel": Color(0.08, 0.14, 0.30),
	},
	{
		"name": "Topo",
		"top_style": 3, "top_a": Color(0.17, 0.22, 0.16), "top_b": Color(0.80, 0.72, 0.50), "top_c": Color(0.90, 0.45, 0.15),
		"bottom_style": 3, "bottom_a": Color(0.82, 0.74, 0.56), "bottom_b": Color(0.10, 0.10, 0.10), "bottom_c": Color(0.90, 0.45, 0.15),
		"boot_upper": Color(0.70, 0.62, 0.45), "boot_accent": Color(0.12, 0.12, 0.12),
		"camo": [Color(0.80, 0.72, 0.52), Color(0.62, 0.52, 0.36), Color(0.45, 0.35, 0.24), Color(0.25, 0.22, 0.18)],
	},
	{
		"name": "Dots",
		"top_style": 4, "top_a": Color(0.93, 0.93, 0.91), "top_b": Color(0.85, 0.12, 0.12), "top_c": Color(0.08, 0.08, 0.08),
		"bottom_style": 4, "bottom_a": Color(0.85, 0.12, 0.12), "bottom_b": Color(0.95, 0.95, 0.93), "bottom_c": Color(0.08, 0.08, 0.08),
		"boot_upper": Color(0.80, 0.12, 0.12), "boot_accent": Color(0.95, 0.95, 0.93), "boot_panel": Color(0.08, 0.08, 0.08),
	},
]


static func count() -> int:
	return DESIGNS.size()


static func design(id: int) -> Dictionary:
	return DESIGNS[posmod(id, DESIGNS.size())]


## Neues Brett mit Bindungen im Design id (Brettkoordinaten siehe Wakeboard).
static func make(id: int) -> Wakeboard:
	return Wakeboard.new(design(id))
