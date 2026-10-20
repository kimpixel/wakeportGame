class_name DriftDebug
extends Node3D
## Drift-Anzeigen am Brett (gold = Sweet Spot DPRESS_SWEET vor der Grenze: dort bremst der Press nicht).
##  * Im Spiel (immer, nur im Drift-Press): Balance-Bogen über dem Fahrer wie bei Tony Hawk – die
##    Nadel ist der Drift-Winkel, grün der bei diesem Tempo erlaubte Bereich, rot bis zur Grenze
##    DPRESS_FALL_ANG (dort stürzt man), darunter die Press-Bremse.
##  * Debug (F3, mit den Hitboxen): Linien auf dem Wasser direkt am Brett – Fahrtrichtung (Bezug, weiß),
##    Brettachse (gelb), erlaubter Bereich (grün), Grenze (rot), Seilzug (orange) – und die Werte als Text.

const LINE_Y := 0.06            # m über dem Wasser
const R_ARC := 2.2              # m Radius der Winkelbögen auf dem Wasser
const METER_R := 58.0           # px Radius des Balance-Bogens

var rider: Rider
var show_lines := false          # F3

var _mesh: ImmediateMesh
var _label: Label3D
var _meter: Control


func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	mi.material_override = mat
	add_child(mi)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.modulate = Color.WHITE
	_label.render_priority = 11
	add_child(_label)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_meter = Control.new()
	_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	layer.add_child(_meter)


func _pressing() -> bool:
	return rider != null and absf(rider.drift_press()) > 0.3


func _process(_delta: float) -> void:
	_meter.queue_redraw()
	_mesh.clear_surfaces()
	var on := show_lines and rider != null and rider.mode == Rider.Mode.WATER and rider.horizontal_speed() > 0.5
	_label.visible = on
	if not on:
		return
	var c := rider.visual_position()
	c.y = rider.water.height_at(c.x, c.z) + LINE_Y
	var v := Vector3(rider.vel.x, 0.0, rider.vel.z)
	var ty := rider.drift_ref_yaw()                # Bezug: Fahrtrichtung (Nosepress: 180° versetzt)
	var tv := atan2(-v.x, -v.z)                    # echte Fahrtrichtung (Pfeil)
	var a := rider.drift_angle_signed()
	var allowed := rider.dpress_allowed
	var limit := Rider.DPRESS_FALL_ANG
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Grenze (rot) und erlaubter Bereich (grün), beidseitig der Fahrtrichtung
	for s: float in [-1.0, 1.0]:
		_line(c, c + _dir(ty + s * limit) * (R_ARC + 0.4), Color(1.0, 0.25, 0.2))
		_line(c, c + _dir(ty + s * allowed) * (R_ARC + 0.4), Color(0.4, 1.0, 0.3))
		_arc(c, ty + s * allowed, ty + s * limit, R_ARC, Color(1.0, 0.25, 0.2))
	_arc(c, ty - allowed, ty + allowed, R_ARC, Color(0.4, 1.0, 0.3))
	# Sweet Spot (gold): hier bremst der Press nicht
	var sweet0 := maxf(limit - Rider.DPRESS_SWEET, 0.0)      # fest vor der Grenze, wandert nicht mit dem Tempo
	for s: float in [-1.0, 1.0]:
		_arc(c, ty + s * sweet0, ty + s * limit, R_ARC - 0.12, Color(1.0, 0.8, 0.2))
		_arc(c, ty + s * sweet0, ty + s * limit, R_ARC - 0.24, Color(1.0, 0.8, 0.2))
	# Fahrtrichtung mit Pfeilspitze (weiß), Bezug (hellblau) wenn 180° versetzt
	var tip := c + _dir(tv) * 3.2
	_line(c, tip, Color.WHITE)
	_line(tip, tip - _dir(tv + 0.4) * 0.4, Color.WHITE)
	_line(tip, tip - _dir(tv - 0.4) * 0.4, Color.WHITE)
	if absf(wrapf(ty - tv, -PI, PI)) > 0.5:
		_line(c, c + _dir(ty) * 2.8, Color(0.5, 0.85, 1.0))
	# Brettachse (gelb, durch das ganze Brett und darüber hinaus) und Winkelbogen dazwischen
	var b := _dir(ty + a)
	_line(c - b * 1.4, c + b * 2.6, Color(1.0, 0.9, 0.1))
	_arc(c, ty, ty + a, 1.2, Color(1.0, 0.9, 0.1))
	# Seilzug (orange), Länge nach Seilzug
	var rh := Vector3(rider.rope_dir.x, 0.0, rider.rope_dir.z)
	if rh.length() > 0.05 and rider.attached:
		_line(c, c + rh.normalized() * clampf(rider.tension_smooth / 400.0, 0.3, 4.0), Color(1.0, 0.55, 0.1))
	_mesh.surface_end()
	_label.global_position = c + Vector3.UP * 0.7 + _dir(tv - PI * 0.5) * 3.2     # rechts neben dem Brett (über dem Fahrer ist der Bogen)
	var dp := rider.drift_press()
	_label.text = "Drift-Winkel %+d°   erlaubt ±%d°   Grenze %d°\n%s   Press-Bremse %.2f / %.2f\nTempo %d km/h   Seilzug %d N" % [
		roundi(rad_to_deg(a)), roundi(rad_to_deg(allowed)), roundi(rad_to_deg(limit)),
		("NOSEPRESS" if dp > 0.0 else "TAILPRESS") if absf(dp) > 0.3 else ("DRIFT" if rider.drifting else "Kante"),
		rider.dpress_drag_now, Rider.DPRESS_DRAG, roundi(rider.horizontal_speed() * 3.6), roundi(rider.tension_smooth)]


func _dir(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


func _line(a: Vector3, b: Vector3, col: Color) -> void:
	_mesh.surface_set_color(col)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(col)
	_mesh.surface_add_vertex(b)


func _arc(c: Vector3, y0: float, y1: float, r: float, col: Color) -> void:
	var n := maxi(2, int(absf(y1 - y0) / 0.08))
	for i in n:
		_line(c + _dir(lerpf(y0, y1, float(i) / n)) * r, c + _dir(lerpf(y0, y1, float(i + 1) / n)) * r, col)


## Balance-Bogen über dem Fahrer (nur im Drift-Press): oben die Mitte (Brett längs zur Fahrt),
## links/rechts bis zur Grenze; Nadel nach links = Brett nach links gedreht.
func _draw_meter() -> void:
	if not _pressing():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := rider.visual_position() + Vector3.UP * 2.3
	if cam.is_position_behind(head):
		return
	var p := cam.unproject_position(head)
	var limit := maxf(Rider.DPRESS_FALL_ANG, 0.01)
	var to_screen := func(ang: float) -> float: return PI * 1.5 - clampf(ang / limit, -1.0, 1.0) * PI * 0.5
	var allowed := rider.dpress_allowed
	var a := rider.drift_angle_signed()
	_meter.draw_arc(p, METER_R, PI, TAU, 40, Color(0, 0, 0, 0.45), 16.0, true)
	_meter.draw_arc(p, METER_R, PI, TAU, 40, Color(1.0, 0.25, 0.2, 0.9), 9.0, true)
	_meter.draw_arc(p, METER_R, to_screen.call(allowed), to_screen.call(-allowed), 32, Color(0.4, 1.0, 0.3), 9.0, true)
	# Sweet Spot (gold) innen am Bogen: dort bremst der Press nicht
	var sweet0 := maxf(limit - Rider.DPRESS_SWEET, 0.0)      # fest vor der Grenze, wandert nicht mit dem Tempo
	_meter.draw_arc(p, METER_R - 9.0, to_screen.call(sweet0), to_screen.call(limit), 12, Color(1.0, 0.8, 0.2), 6.0, true)
	_meter.draw_arc(p, METER_R - 9.0, to_screen.call(-limit), to_screen.call(-sweet0), 12, Color(1.0, 0.8, 0.2), 6.0, true)
	var danger := absf(a) > allowed - deg_to_rad(4.0)
	var na: float = to_screen.call(a)
	var needle_col := Color(1.0, 0.3, 0.2) if danger else Color.WHITE
	_meter.draw_line(p, p + Vector2(cos(na), sin(na)) * (METER_R + 10.0), Color(0, 0, 0, 0.6), 6.0, true)
	_meter.draw_line(p, p + Vector2(cos(na), sin(na)) * (METER_R + 10.0), needle_col, 3.0, true)
	_meter.draw_circle(p, 5.0, needle_col)
	var f := ThemeDB.fallback_font
	var txt := "%d° / %d°" % [roundi(rad_to_deg(absf(a))), roundi(rad_to_deg(allowed))]
	_meter.draw_string_outline(f, p + Vector2(-60, 24), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 6, Color(0, 0, 0, 0.8))
	_meter.draw_string(f, p + Vector2(-60, 24), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, needle_col)
	# Press-Bremse als kleiner Balken darunter
	var brake := clampf(rider.dpress_drag_now / maxf(Rider.DPRESS_DRAG, 0.001), 0.0, 1.0)
	var r := Rect2(p + Vector2(-40, 32), Vector2(80, 6))
	_meter.draw_rect(r, Color(0, 0, 0, 0.5))
	_meter.draw_rect(Rect2(r.position, Vector2(80 * brake, 6)), Color(0.5, 0.85, 1.0))
	var bt := "Bremse %d %%" % roundi(brake * 100.0)
	_meter.draw_string_outline(f, p + Vector2(-60, 54), bt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 5, Color(0, 0, 0, 0.8))
	_meter.draw_string(f, p + Vector2(-60, 54), bt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.7, 0.9, 1.0))
