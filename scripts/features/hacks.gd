class_name Hacks
## Zusammenstehende Teile einer Anlage = ein Hack. Teile, die sich (mit GAP Abstand) berühren,
## werden zusammengefasst. Übliche Kombinationen heißen nicht "Hack" (siehe hack_name).

const GAP := 0.8                 # so nah (m) beieinander gilt als Hack


## Teile einer Anlage zu Hacks gruppieren: Array von Arrays mit FeatureParts (nach s sortiert).
static func group(parts: Array, cable: CableSystem) -> Array:
	var n := parts.size()
	var root: Array[int] = []
	for i in n:
		root.append(i)
	var find := func(i: int) -> int:
		while root[i] != i:
			i = root[i]
		return i
	var grown: Array[PackedVector2Array] = []
	for p: FeaturePart in parts:
		grown.append(footprint(p, cable, GAP * 0.5))
	for i in n:
		for j in range(i + 1, n):
			if _overlap(grown[i], grown[j]):
				root[find.call(i)] = find.call(j)
	var by_root := {}
	for i in n:
		var r: int = find.call(i)
		if not by_root.has(r):
			by_root[r] = []
		by_root[r].append(parts[i])
	var out: Array = by_root.values()
	for h: Array in out:
		h.sort_custom(func(a: FeaturePart, b: FeaturePart) -> bool: return a.s_center < b.s_center)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0].s_center < b[0].s_center)
	return out


## Name eines Features bzw. Hacks. Übliche Kombinationen sind kein Hack: Module aus mehreren
## Teilen (Pyramid Series, Spine Kicker …), Ollie Box mit Ledge und Kicker nebeneinander.
static func hack_name(hack: Array) -> String:
	if hack.size() == 1:
		return (hack[0] as FeaturePart).display_name
	var group_name := (hack[0] as FeaturePart).group_name
	var ids := {}
	for p: FeaturePart in hack:
		if p.group_name != group_name:
			group_name = ""
		ids[p.part_id] = true
	if group_name != "":
		return group_name
	var counts := {}
	var seen := {}
	for p: FeaturePart in hack:
		# Module (Gruppe) zählen einmal mit ihrem Namen, nicht jedes Teil einzeln
		var nm := p.group_name if p.group_name != "" else p.display_name
		var key := "%s#%d" % [nm, p.row_index] if p.group_name != "" else str(p.get_instance_id())
		if seen.has(key):
			continue
		seen[key] = true
		counts[nm] = counts.get(nm, 0) + 1
	var names: Array[String] = []
	for nm: String in counts:
		names.append(("%d× %s" % [counts[nm], nm]) if counts[nm] > 1 else nm)
	names.sort()
	return ("" if is_standard(hack) else "Hack: ") + " + ".join(names)


## Gängige Kombination (kein Hack): ein Modul, Kicker nebeneinander, Ollie Box mit Ledge.
static func is_standard(hack: Array) -> bool:
	if hack.size() == 1:
		return true
	var group_name := (hack[0] as FeaturePart).group_name
	if group_name != "" and hack.all(func(p: FeaturePart) -> bool: return p.group_name == group_name):
		return true
	var ids: Array = []
	for p: FeaturePart in hack:
		ids.append(p.part_id)
	return ids.all(func(i: String) -> bool: return i.begins_with("kicker_")) \
		or ids.all(func(i: String) -> bool: return i in ["ollie_box", "ollie_box_half", "ollie_ledge"]) \
		or (ids.has("_plaza_wall") and ids.all(func(i: String) -> bool: return i in ["_plaza_wall", "_plaza_safety", "_plaza_ramp", "cheese_wedge"]))


## Grundriss eines Teils in Anlagenkoordinaten (s, x), um margin vergrößert.
static func footprint(p: FeaturePart, cable: CableSystem, margin: float) -> PackedVector2Array:
	var hw := p.width * 0.5 + margin
	var hl := p.length * 0.5 + margin
	var out := PackedVector2Array()
	var inv := cable.transform.affine_inverse()
	for c: Vector2 in [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl)]:
		var l := inv * (p.global_transform * Vector3(c.x, 0.0, c.y))
		out.append(Vector2(cable.mast_a_z - l.z, l.x))
	return out


## Trennende Achse: überlappen zwei konvexe Vierecke?
static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly: PackedVector2Array in [a, b]:
		for k in poly.size():
			var e := poly[(k + 1) % poly.size()] - poly[k]
			var axis := Vector2(-e.y, e.x)
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for q in a:
				amin = minf(amin, q.dot(axis))
				amax = maxf(amax, q.dot(axis))
			for q in b:
				bmin = minf(bmin, q.dot(axis))
				bmax = maxf(bmax, q.dot(axis))
			if amax < bmin or bmax < amin:
				return false
	return true


## Kennung zum Zusammenfassen gleicher Features/Hacks aus verschiedenen Setups: Teile und
## ihre Lage zueinander (auf 0,5 m bzw. 15° gerundet).
static func signature(hack: Array, cable: CableSystem) -> String:
	if hack.size() == 1:
		return (hack[0] as FeaturePart).part_id
	var inv := cable.transform.affine_inverse()
	var first := hack[0] as FeaturePart
	var o := inv * first.global_position
	var bits: Array[String] = []
	for p: FeaturePart in hack:
		var l := inv * p.global_position - o
		var yaw := rad_to_deg((inv.basis * p.forward_world()).signed_angle_to(Vector3.FORWARD, Vector3.UP))
		bits.append("%s@%d,%d,%d" % [p.part_id, roundi(l.x * 2.0), roundi(l.z * 2.0), roundi(yaw / 15.0)])
	bits.sort()
	return "|".join(bits)
