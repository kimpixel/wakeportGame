class_name Wakeboard
extends Node3D
## Twin-Tip-Cable-Wakeboard mit zwei Bindungsschuhen.
## Brettkoordinaten: Länge entlang Z (Nose = -Z, dort steht der vordere Fuß), quer X, oben +Y.
## Unterkante der Brettmitte liegt bei y = 0.
##  * Umriss: fast parallele Kanten, eckige Spitzen mit runden Ecken
##  * durchgehender Rocker (Aufbiegung zu den Spitzen), Kanten dünner als die Mitte
##  * Grafik per Shader (Oberseite schwarz mit Zeitungscollage, Unterseite creme)
##  * Bindungen: hohe Schuhe aus assets/board/boot.glb (tools/board/build_boot.py)

const LENGTH := 1.49           # 149er Board
const HALF_W := 0.22           # halbe Breite in der Mitte (Seitenverhältnis wie auf dem Foto)
# Umriss, gemessen am Produktfoto: (Abstand vom Brettende, halbe Breite), Bezugsmaß 1.42 × 0.43 m;
# wird auf LENGTH/HALF_W skaliert. Das Brett wird zu den Spitzen schmaler und endet in einem flachen Bogen.
const OUTLINE_LEN := 1.42
const OUTLINE_HALF_W := 0.215
const OUTLINE := [
	[0.0, 0.0235], [0.003, 0.042], [0.007, 0.063], [0.014, 0.0865], [0.021, 0.1025],
	[0.028, 0.1167], [0.042, 0.1377], [0.055, 0.1428], [0.083, 0.1503], [0.111, 0.1579],
	[0.139, 0.1638], [0.208, 0.1772], [0.277, 0.1881], [0.416, 0.2041], [0.555, 0.2125],
	[0.71, 0.215],
]
# Foto-Texturen von Ober- und Unterseite (tools/board/make_texture.gd). Foto/Logo © Slingshot,
# nicht unter MIT. Fehlen sie, zeichnet der Shader ein eigenes Design.
const BOTTOM_TEX := "res://assets/board/bottom.png"
const TOP_TEX := "res://assets/board/top.png"
const ROCKER := 0.068          # Aufbiegung an den Spitzen
const THICK := 0.016           # Dicke in der Mitte
const STANCE := 0.27           # halber Abstand der Bindungen
const DUCK := 0.157            # Bindungswinkel ±9° (Zehen leicht nach außen)
const ANKLE := 0.12            # Knöchel über der Unterkante der Bindung
const BOOT_CENTER := 0.063     # Schuhmitte liegt so weit vor dem Knöchel (Schuh 35 cm lang)
const BOOT_PATH := "res://assets/board/boot.glb"

const NZ := 120
const NX := 20


static func half_width(z: float) -> float:
	var d := (LENGTH * 0.5 - absf(z)) * OUTLINE_LEN / LENGTH
	var sw := HALF_W / OUTLINE_HALF_W
	for k in range(1, OUTLINE.size()):
		var b: Array = OUTLINE[k]
		if d <= b[0]:
			var a: Array = OUTLINE[k - 1]
			return lerpf(a[1], b[1], (d - a[0]) / (b[0] - a[0])) * sw
	return HALF_W


static func rocker(z: float) -> float:
	return ROCKER * pow(absf(z) / (LENGTH * 0.5), 2.2)


## Oberseite: zu den Kanten und Spitzen hin dünner.
static func top_y(x: float, z: float) -> float:
	var e := absf(x) / maxf(half_width(z), 0.01)
	var a := absf(z) / (LENGTH * 0.5)
	return rocker(z) + THICK * (1.0 - 0.6 * pow(e, 6.0)) * (1.0 - 0.45 * pow(a, 4.0))


## Schuhrichtung (Zehen) auf dem Brett: zur Brust des Fahrers (+X), gedreht um den Duck-Winkel.
static func toe_dir(front: bool) -> Vector3:
	return Basis(Vector3.UP, foot_yaw(front)) * Vector3.RIGHT


## Unterkante der Bindung unter dem Knöchel (Brettkoordinaten). Der Schuh ist auf dem Brett
## zentriert, damit er vorne und hinten nicht übersteht (je gut 3 cm Luft zur Kante).
static func boot_origin(front: bool) -> Vector3:
	var s := -STANCE if front else STANCE
	var o := Vector3(0.0, 0.0, s) - toe_dir(front) * BOOT_CENTER
	o.y = top_y(o.x, o.z)
	return o


## Knöchel des vorderen/hinteren Fußes (Brettkoordinaten).
static func ankle_local(front: bool) -> Vector3:
	return boot_origin(front) + Vector3(0.0, ANKLE, 0.0)


## Fußdrehung auf dem Brett relativ zur Fahrerausrichtung (Duck-Stance).
static func foot_yaw(front: bool) -> float:
	return DUCK if front else -DUCK


func _init() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wakeboard.gdshader")
	mat.set_shader_parameter("half_len", LENGTH * 0.5)
	mat.set_shader_parameter("half_w", HALF_W)
	for side: String in ["bottom", "top"]:
		var path := BOTTOM_TEX if side == "bottom" else TOP_TEX
		if ResourceLoader.exists(path):
			mat.set_shader_parameter(side + "_tex", load(path))
			mat.set_shader_parameter("use_" + side + "_tex", true)
	mi.material_override = mat
	add_child(mi)
	if ResourceLoader.exists(BOOT_PATH):
		var scene: PackedScene = load(BOOT_PATH)
		var camo := ShaderMaterial.new()
		camo.shader = load("res://shaders/camo.gdshader")
		for front: bool in [true, false]:
			var boot: Node3D = scene.instantiate()
			# Schuh-Zehen zeigen im Modell nach -Z; hier zur Brust des Fahrers (+X), plus Duck-Winkel
			boot.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5 + foot_yaw(front)), boot_origin(front))
			add_child(boot)
			_apply_camo(boot, camo)


func _apply_camo(n: Node, camo: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name.begins_with("camo"):
				mi.set_surface_override_material(i, camo)
	for c in n.get_children():
		_apply_camo(c, camo)


# ---------------------------------------------------------------- Mesh

func _build_mesh() -> ArrayMesh:
	var top: Array[PackedVector3Array] = []
	var bot: Array[PackedVector3Array] = []
	for i in NZ:
		# an den Spitzen dichter (runder Abschluss)
		var z := LENGTH * 0.5 * sin(lerpf(-PI * 0.5, PI * 0.5, float(i) / (NZ - 1)))
		var w := half_width(z)
		var rt := PackedVector3Array()
		var rb := PackedVector3Array()
		for j in NX:
			var x := lerpf(-w, w, float(j) / (NX - 1))
			rt.append(Vector3(x, top_y(x, z), z))
			rb.append(Vector3(x, rocker(z), z))
		top.append(rt)
		bot.append(rb)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, top, true, 0.0)
	_grid(st, bot, false, 1.0)
	# Kante rundherum (Umfang: Nose-Ende, rechte Kante, Tail-Ende, linke Kante)
	var ring: Array[Vector2i] = []
	for j in NX:
		ring.append(Vector2i(0, j))
	for i in range(1, NZ):
		ring.append(Vector2i(i, NX - 1))
	for j in range(NX - 2, -1, -1):
		ring.append(Vector2i(NZ - 1, j))
	for i in range(NZ - 2, 0, -1):
		ring.append(Vector2i(i, 0))
	st.set_color(Color(0.5, 0, 0))
	for k in ring.size():
		var a := ring[k]
		var b := ring[(k + 1) % ring.size()]
		var ta := top[a.x][a.y]
		var tb := top[b.x][b.y]
		var ba := bot[a.x][a.y]
		var bb := bot[b.x][b.y]
		var t := tb - ta
		var n := Vector3(t.z, 0.0, -t.x).normalized()
		if n.dot(Vector3(ta.x, 0.0, ta.z)) < 0.0:
			n = -n
		_quad(st, ta, tb, bb, ba, n, n)
	return st.commit()


## Fläche aus einem Gitter; Normalen aus den Nachbarpunkten (glatt).
func _grid(st: SurfaceTool, g: Array[PackedVector3Array], up: bool, part: float) -> void:
	st.set_color(Color(part, 0, 0))
	var normals: Array[PackedVector3Array] = []
	for i in NZ:
		var row := PackedVector3Array()
		for j in NX:
			var dx := g[i][mini(j + 1, NX - 1)] - g[i][maxi(j - 1, 0)]
			var dz := g[mini(i + 1, NZ - 1)][j] - g[maxi(i - 1, 0)][j]
			var n := dz.cross(dx).normalized()
			row.append(n if up else -n)
		normals.append(row)
	for i in NZ - 1:
		for j in NX - 1:
			_quad(st, g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j],
				normals[i][j], normals[i + 1][j + 1], [normals[i][j], normals[i][j + 1], normals[i + 1][j + 1], normals[i + 1][j]])


## Viereck als zwei Dreiecke, Windung passend zur gewünschten Normalen (Godot: Vorderseite im Uhrzeigersinn).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n_ref: Vector3, _n2: Vector3, ns: Array = []) -> void:
	var pts := [a, b, c, d]
	var nrm: Array = ns if ns.size() == 4 else [n_ref, n_ref, n_ref, n_ref]
	var order := [0, 1, 2, 0, 2, 3]
	if (b - a).cross(c - a).dot(n_ref) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(nrm[k])
		st.add_vertex(pts[k])
