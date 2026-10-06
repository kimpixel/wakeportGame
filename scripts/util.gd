class_name Util
extends RefCounted
## Kleine Helfer für die einfache Platzhalter-Grafik.


static func mat(color: Color, roughness := 0.85, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func box(parent: Node, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, center: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mi.mesh = s
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	return mi


## Zylinder von a nach b (Koordinaten im Raum des Elternknotens).
static func beam(parent: Node, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = material
	parent.add_child(mi)
	place_beam(mi, a, b)
	return mi


static func place_beam(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.0001:
		mi.visible = false
		return
	mi.visible = true
	var up := axis / length
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := up.cross(ref).normalized()
	var z := x.cross(up)
	mi.transform = Transform3D(Basis(x, up * length, z), (a + b) * 0.5)
