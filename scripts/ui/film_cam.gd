class_name FilmCam
extends CanvasLayer
## Kamera des Filmteams in den Challenges: Livebild links als kleine Vorschau (Boot: Camcorder der
## Kamerafrau, Drohne: Action-Kamera der FPV-Drohne). Während eines Versuchs drückt sie an den
## besten Stellen ab (Absprung, höchster Punkt, Landung, auf dem Slider); die Fotos eines gewerteten
## Versuchs zeigt das Ergebnisfenster.
## Eigener SubViewport mit eigener Kamera in derselben Welt (rendert nur, solange er zu sehen ist).

const RES := Vector2i(480, 270)  # Auflösung von Livebild und Fotos
const PREVIEW_W := 220.0         # Breite der Vorschau (bei 720 px Bildhöhe)
const MARGIN := 16.0
const TOP := 128.0               # unter der HUD-Leiste und der Aufgabenzeile
const PHOTO_GAP := 0.3           # s Mindestabstand zwischen zwei Fotos
const TAKEOFF_SHOT := 0.12       # s nach dem Absprung abdrücken
const LAND_SHOT := 0.12          # s nach der Landung abdrücken ...
const LAND_MIN_AIR := 0.45       # ... wenn man so lange in der Luft war
const MAX_PHOTOS := 3            # so viele Fotos zeigt das Ergebnis
const SLIDE_SHOT := 0.35         # s auf dem Slider, dann abdrücken
const FRAME := 2.6               # Bildhöhe (m) am Fahrer – Zoom passt sich der Entfernung an (Fahrer bildfüllend)

var crew: FilmCrew
var mobile := false               # Handy: Livebild ausgeblendet
var recording := false
var photos: Array[Texture2D] = []

var _vp: SubViewport
var _cam: Camera3D
var _live := false                # Filmteam da, Kamera läuft
var _live_box: PanelContainer
var _live_title: Label
var _rec_dot: Label
var _t := 0.0
var _last_shot := -99.0
var _prev_vy := 0.0
var _slide_t := 0.0
var _air_t := 0.0
var _land_t := -1.0
var _look := Vector3.ZERO
var _font: Font


func _init() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS     # Livebild läuft auch im Countdown (Pause) weiter


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	sf.font_weight = 700
	_font = sf
	_vp = SubViewport.new()
	_vp.size = RES
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = get_viewport().msaa_3d
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.near = 0.2
	_cam.far = 1500.0
	_cam.current = true
	_vp.add_child(_cam)

	# Livebild: dunkler Rahmen, oben "● REC  BOOT" bzw. "DROHNE"
	_live_box = _frame(Color(0.05, 0.07, 0.09, 0.85), Hud.ACCENT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_live_box.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	_rec_dot = _label(14, Color(1.0, 0.2, 0.15))
	_rec_dot.text = "● REC"
	head.add_child(_rec_dot)
	_live_title = _label(14, Color(1, 1, 1, 0.85))
	head.add_child(_live_title)
	var live := TextureRect.new()
	live.texture = _vp.get_texture()
	live.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	live.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	live.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_W * RES.y / RES.x)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(live)

	_set_live(false)


func _frame(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Am Handy kein Livebild (zu wenig Platz) – die Kamera läuft trotzdem für die Fotos im Ergebnis.
func _set_live(on: bool) -> void:
	_live = on
	_live_box.visible = on and not mobile
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Filmteam ist da (Boot oder Drohne) bzw. weg.
func set_source(mode: String) -> void:
	var on := mode == "boat" or mode == "drone"
	_live_title.text = tr("BOOT") if mode == "boat" else tr("DROHNE")
	_set_live(on)
	if not on:
		recording = false
	else:
		_update_cam(0.0, true)


## Versuch läuft (nach GO): Fotos sammeln.
func begin() -> void:
	recording = _live
	photos.clear()
	_last_shot = -99.0
	_slide_t = 0.0
	_prev_vy = 0.0
	_air_t = 0.0
	_land_t = -1.0


## Versuch gewertet: Fotos fürs Ergebnis (gibt es noch keins, jetzt eins).
func finish() -> Array[Texture2D]:
	if recording and photos.is_empty():
		_shoot()
	recording = false
	return photos.slice(-MAX_PHOTOS)


func stop_recording() -> void:
	recording = false


func _process(delta: float) -> void:
	_t += delta
	if not _live:
		return
	_update_cam(delta, false)
	if _live_box.visible:
		_rec_dot.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.25
		_layout()


func _physics_process(delta: float) -> void:
	if not recording or get_tree().paused:
		return
	var r: Rider = crew.game.rider
	if r.mode == Rider.Mode.CRASHED:
		return
	# Sprung als Serie: Absprung, höchster Punkt, Landung (Landung nur nach echtem Flug)
	if r.mode == Rider.Mode.AIR:
		_air_t += delta
		if _air_t - delta < TAKEOFF_SHOT and _air_t >= TAKEOFF_SHOT:
			_shoot()
		if _prev_vy > 0.0 and r.vel.y <= 0.0:          # höchster Punkt
			_shoot()
		_prev_vy = r.vel.y
	else:
		if _air_t > LAND_MIN_AIR:
			_land_t = LAND_SHOT
		_air_t = 0.0
		_prev_vy = 0.0
	if _land_t >= 0.0:
		_land_t -= delta
		if _land_t < 0.0:
			_shoot()
	if r.is_sliding():
		_slide_t += delta
		if _slide_t - delta < SLIDE_SHOT and _slide_t >= SLIDE_SHOT:
			_shoot()
	else:
		_slide_t = 0.0


## Abdrücken: aktuelles Bild der Filmkamera als Foto.
func _shoot() -> Texture2D:
	if _t - _last_shot < PHOTO_GAP:
		return null
	if DisplayServer.get_name() == "headless":       # ohne Grafik gibt es kein Bild
		return null
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	_last_shot = _t
	var tex := ImageTexture.create_from_image(img)
	photos.append(tex)
	if crew.game._test_log:
		print("FOTO %d (%.1f s)" % [photos.size(), _t])
	return tex



## Kamera auf Boot bzw. Drohne setzen und weich auf den Fahrer richten.
func _update_cam(delta: float, snap: bool) -> void:
	var r: Rider = crew.game.rider
	var target := r.pos + Vector3(0, 0.9, 0)
	target.y = maxf(target.y, 0.6)
	var from := crew.camera_origin()
	# eng gezoomt: Blick fest auf dem Fahrer (nur die Höhe weich, sonst hängt das Bild hinterher)
	if snap:
		_look = target
	else:
		_look = Vector3(target.x, lerpf(_look.y, target.y, clampf(delta * 10.0, 0.0, 1.0)), target.z)
	if from.distance_to(_look) < 0.5:
		return
	_cam.global_transform = Transform3D(Basis.looking_at(_look - from, Vector3.UP), from)
	var d := from.distance_to(_look)
	_cam.fov = clampf(rad_to_deg(2.0 * atan(FRAME * 0.5 / d)), 6.0, 70.0)   # Fahrer füllt das Bild
	if crew.mode == "drone":
		_cam.rotate_object_local(Vector3.FORWARD, crew.drone_roll())   # FPV: Bild kippt mit der Drohne


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := clampf(vs.y / 720.0, 0.8, 2.5)
	var top := TOP * k
	if vs.x < vs.y:                              # hochkant: schmaler
		k = clampf(vs.x / 900.0, 0.6, 2.0)
	# nie in die HUD-Leiste (hochkant zweispaltig und höher), Aufgabenzeile und Brettzustand
	var hud: Hud = crew.game.hud
	top = maxf(top, (hud.info_bottom() if vs.x < vs.y else hud.bar_bottom()) + 8.0 * k)
	top = maxf(top, hud.left_reserved + 8.0 * k)    # Handy: unter das ☰
	_live_box.scale = Vector2(k, k)
	_live_box.position = Vector2(MARGIN, top)
