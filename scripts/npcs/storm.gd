class_name Storm
extends Node3D
## Gewitter (Szenario "Gewitter – YOLO", nie gewürfelt): alle paar Sekunden schlägt ein Blitz ein – meist irgendwo
## in der Umgebung (See, Wald), ab und zu knapp neben dem Fahrer (Spritzer, lauter Knall). Ganz selten trifft es den
## Fahrer selbst: Sturz "Vom Blitz getroffen!" und der geheime Erfolg "Blitzableiter" (struck). Riskantes Spiel – YOLO.
## Licht: Weather.flash, Donner: Sfx.thunder (kommt mit Schallgeschwindigkeit).

signal struck                        # Fahrer wurde getroffen

const EVERY := Vector2(3.0, 9.0)     # s zwischen zwei Blitzen
const NEAR_CHANCE := 0.22            # Anteil knapp neben dem Fahrer (5–14 m)
const HIT_CHANCE := 0.015            # Anteil Volltreffer (im Schnitt etwa alle 6 Minuten)
const HIT_MIN_GAP := 90.0            # s: frühestens so lange nach Spielbeginn bzw. dem letzten Treffer
const CLOUD_Y := 260.0

var weather: Weather
var sfx: Sfx
var water: Water
var player: Rider
var active := false

var _next := 4.0
var _since_hit := 0.0
var _mat: StandardMaterial3D
var _glow: StandardMaterial3D        # breiter, durchscheinender Lichtschein um den Kanal
var _splash: CPUParticles3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.92, 0.95, 1.0)
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.albedo_color = Color(0.45, 0.55, 1.0, 0.35)
	_splash = CPUParticles3D.new()
	_splash.emitting = false
	_splash.one_shot = true
	_splash.amount = 80
	_splash.lifetime = 1.0
	_splash.explosiveness = 0.95
	_splash.direction = Vector3.UP
	_splash.spread = 35.0
	_splash.initial_velocity_min = 3.0
	_splash.initial_velocity_max = 8.0
	_splash.gravity = Vector3(0, -9.8, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Util.mat(Color(0.9, 0.95, 1.0), 0.3)
	_splash.mesh = drop
	_splash.top_level = true
	add_child(_splash)


## Weather.changed: nur im Gewitter.
func apply_season(w: Weather) -> void:
	active = w.storm > 0.0
	_since_hit = 0.0


func _process(delta: float) -> void:
	if not active or player == null:
		return
	_since_hit += delta
	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(EVERY.x, EVERY.y)
	var pp := player.pos
	var on_lake := player.mode in [Rider.Mode.WATER, Rider.Mode.AIR] and player.attached
	var r := randf()
	if on_lake and _since_hit > HIT_MIN_GAP and r < HIT_CHANCE:
		_since_hit = 0.0
		strike(Vector3(pp.x, pp.y + 1.6, pp.z), true)
		player.crash("Vom Blitz getroffen!")
		struck.emit()
	elif r < NEAR_CHANCE:
		var a := randf() * TAU
		var d := randf_range(5.0, 14.0)
		strike(Vector3(pp.x + cos(a) * d, 0.0, pp.z + sin(a) * d), false)
	else:
		var a := randf() * TAU
		var d := randf_range(60.0, 600.0)
		var x := pp.x + cos(a) * d
		var z := pp.z + sin(a) * d
		var y := maxf(Geo.height(x, z) + Geo.canopy(x, z), 0.0) if Geo.in_area(x, z) else 0.0
		strike(Vector3(x, y, z), false)


## Ein Blitz an der Stelle (Boden/Wasser bzw. Fahrer): gezackter Kanal aus den Wolken, Licht, Donner, Spritzer.
func strike(at: Vector3, hit: bool) -> void:
	var dist := Vector2(at.x - player.pos.x, at.z - player.pos.z).length() if player else 100.0
	var bolt := Node3D.new()
	bolt.top_level = true
	add_child(bolt)
	var width := clampf(dist * 0.01, 0.12, 3.0)           # fern dicker, sonst nur ein Strich
	var top := at + Vector3(randf_range(-40.0, 40.0), CLOUD_Y, randf_range(-40.0, 40.0))
	_zigzag(bolt, top, at, width, 22)
	for b in 2:                                           # Verästelungen
		var t := randf_range(0.2, 0.6)
		var from := top.lerp(at, t) + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		var to := from + Vector3(randf_range(-40.0, 40.0), -randf_range(30.0, 80.0), randf_range(-40.0, 40.0))
		_zigzag(bolt, from, to, width * 0.5, 6)
	# kurz an, aus, nochmal an (Nachblitz), dann weg
	var tw := create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func() -> void: bolt.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: bolt.visible = true)
	tw.tween_interval(0.09)
	tw.tween_callback(bolt.queue_free)
	if weather:
		weather.flash(clampf(1.2 - dist / 500.0, 0.25, 1.0))
	if sfx:
		sfx.thunder(dist)
	if dist < 30.0 and water:
		_splash.global_position = Vector3(at.x, water.height_at(at.x, at.z), at.z)
		_splash.restart()


func _zigzag(parent: Node3D, a: Vector3, b: Vector3, width: float, n: int) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t)
		if i < n:
			var jitter := (1.0 - t * 0.4) * a.distance_to(b) / n * 1.1
			p += Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter) * 0.3, randf_range(-jitter, jitter))
		Util.beam(parent, prev, p, width, _mat)
		Util.beam(parent, prev, p, width * 5.0, _glow)
		prev = p
