class_name Helmet
extends Node3D
## Wakeboard-Helm (Skate-Form): Schale mit Innenpolster und Rand, Ohrpolster, Kinnriemen.
## Zweifarbig, in der Mitte von vorne nach hinten geteilt: links gelb, rechts grün.
## Grafik (Teilung, Logo-Felder ohne Schrift, Lüftungslöcher, Nieten) aus shaders/helmet.gdshader.
## Koordinaten wie das Skelett in Ruhepose: +Y oben, +Z vorne (Gesicht), +X links vom Fahrer.
## Ursprung = Kopf-Knochen; die Schale sitzt etwas darüber (CENTER).

const CENTER := Vector3(0.0, 0.07, 0.015)
const OUTER := Vector3(0.116, 0.125, 0.138)    # Halbachsen außen (quer, hoch, längs)
const SHELL := 0.012                           # Dicke der Schale inkl. Polster
const N_AZ := 64                               # Unterteilung rundherum (Vielfaches von 4: Teilung exakt)
const N_EL := 18                               # Unterteilung Scheitel -> Rand


func _init() -> void:
	var shell := MeshInstance3D.new()
	shell.mesh = _build_shell()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/helmet.gdshader")
	mat.set_shader_parameter("center", CENTER)
	mat.set_shader_parameter("radii", OUTER)
	shell.material_override = mat
	add_child(shell)
	var black := Util.mat(Color(0.05, 0.05, 0.055), 0.8)
	# Ohrpolster: weiche schwarze Klappen unter dem seitlichen Rand
	for side: float in [-1.0, 1.0]:
		var pad := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		pad.mesh = m
		pad.material_override = black
		pad.position = CENTER + Vector3(side * 0.098, -0.085, -0.005)
		pad.rotation = Vector3(0.25, 0.0, side * 0.12)
		pad.scale = Vector3(0.022, 0.085, 0.075)
		add_child(pad)
		# Kinnriemen: vom Ohrpolster unter das Kinn
		var a := CENTER + Vector3(side * 0.09, -0.12, 0.01)
		var chin := Vector3(side * 0.02, -0.085, 0.105)
		Util.beam(self, a, chin, 0.006, black)
	Util.beam(self, Vector3(0.02, -0.085, 0.105), Vector3(-0.02, -0.085, 0.105), 0.007, black)


## Rand der Schale (y relativ zu CENTER) abhängig vom Winkel rundherum (0 = vorne):
## vorne über der Stirn, an den Seiten über den Ohren tiefer, hinten am tiefsten.
static func rim_y(az: float) -> float:
	var c := cos(az)
	var s := sin(az)
	return lerpf(-0.012, -0.068, (1.0 - c) * 0.5) - 0.014 * s * s


static func _point(radii: Vector3, az: float, polar: float) -> Vector3:
	return CENTER + Vector3(radii.x * sin(polar) * sin(az), radii.y * cos(polar), radii.z * sin(polar) * cos(az))


func _build_shell() -> ArrayMesh:
	var inner_r := OUTER - Vector3.ONE * SHELL
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for i in N_AZ + 1:
		var az := TAU * float(i) / N_AZ
		var ro := PackedVector3Array()
		var ri := PackedVector3Array()
		var pr_o := acos(clampf(rim_y(az) / OUTER.y, -1.0, 1.0))
		var pr_i := acos(clampf(rim_y(az) / inner_r.y, -1.0, 1.0))
		for j in N_EL + 1:
			var t := float(j) / N_EL
			ro.append(_point(OUTER, az, t * pr_o))
			ri.append(_point(inner_r, az, t * pr_i))
		outer.append(ro)
		inner.append(ri)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surface(st, outer, OUTER, 0.0, false)
	_surface(st, inner, inner_r, 1.0, true)
	# Rand: Außen- und Innenkante verbinden
	st.set_color(Color(0.5, 0, 0))
	for i in N_AZ:
		var a := outer[i][N_EL]
		var b := outer[i + 1][N_EL]
		var c := inner[i + 1][N_EL]
		var d := inner[i][N_EL]
		_tri(st, a, b, c, Vector3.DOWN)
		_tri(st, a, c, d, Vector3.DOWN)
	return st.commit()


func _surface(st: SurfaceTool, g: Array[PackedVector3Array], radii: Vector3, part: float, flip: bool) -> void:
	st.set_color(Color(part, 0, 0))
	for i in N_AZ:
		for j in N_EL:
			var q := [g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var pts: Array[Vector3] = []
				for k: int in tri:
					pts.append(q[k])
				var n_ref := _normal(pts[0] + pts[1] + pts[2], radii)
				if flip:
					n_ref = -n_ref
				_tri(st, pts[0], pts[1], pts[2], n_ref, radii, flip)


## Ellipsoid-Normale an einem Punkt (glatte Schattierung).
static func _normal(p_sum: Vector3, radii: Vector3) -> Vector3:
	var p := p_sum / 3.0 - CENTER
	return Vector3(p.x / (radii.x * radii.x), p.y / (radii.y * radii.y), p.z / (radii.z * radii.z)).normalized()


## Dreieck mit Windung passend zur Normalen (Godot: Vorderseite im Uhrzeigersinn).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n_ref: Vector3, radii := Vector3.ZERO, flip := false) -> void:
	var pts := [a, b, c]
	if (b - a).cross(c - a).dot(n_ref) > 0.0:
		pts = [a, c, b]
	for p: Vector3 in pts:
		var n := n_ref
		if radii != Vector3.ZERO:
			var q := p - CENTER
			n = Vector3(q.x / (radii.x * radii.x), q.y / (radii.y * radii.y), q.z / (radii.z * radii.z)).normalized()
			if flip:
				n = -n
		st.set_normal(n)
		st.add_vertex(p)
