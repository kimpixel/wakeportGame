// Gemeinsamer Wasser-Shader. Eingebunden von water.gdshader (undurchsichtig) und
// water_depth.gdshader (mit Szenentiefe: Durchsicht im Flachen).
// Die Höhenfunktion muss mit scripts/water.gd übereinstimmen (Physik = Grafik).
// Jeder Effekt hat einen Schalter (fx_*), gesetzt aus den Einstellungen (Reiter "Wasser").

#define WAKE_COUNT 96

uniform vec4 wake_points[WAKE_COUNT]; // x, z, Entstehungszeit, Stärke
uniform float sim_time = 0.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.15, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.33, 0.35);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.97);
uniform bool use_wake = true;
uniform vec2 hole_center;       // grobes Gitter: unter dem feinen Gitter absenken
uniform float hole_half = 0.0;

// Schalter (Einstellungen -> Wasser)
uniform bool fx_detail = true;  // Oberflächenstruktur aus zwei gleitenden Normal-Texturen
uniform bool fx_fresnel = true; // flach geschaut spiegelt das Wasser den Himmel, von oben sieht man hinein
uniform bool fx_glitter = true; // Sonnenglitzern
uniform bool fx_crest = true;   // Licht scheint durch die Wellenkämme
uniform bool fx_foam = true;    // Schaum mit Struktur (fleckig, reißt auf)
uniform bool fx_sharp = true;   // spitze Wellenkämme (gleiche Formel in water.gd)
uniform bool fx_clear = true;   // Durchsicht im Flachen (nur water_depth)

uniform sampler2D detail_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.3);      // zur Sonne (Welt)
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float sun_energy = 1.0;
uniform vec3 sky_color : source_color = vec3(0.55, 0.7, 0.88);   // Himmel am Horizont (Spiegelung)

const float WAKE_SPEED = 2.6;
const float WAKE_WIDTH = 0.9;
const float WAKE_K = 3.0;
const float WAKE_AMP = 0.2;
const float WAKE_DECAY = 0.55;
const float WAKE_LIFE = 5.6;

varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying float v_foam;
varying float v_height;

// Grundwelle: Sinus oder spitz (exp(sin): spitze Kämme, flache Täler, Mittelwert 0)
float wave(float a) {
	if (fx_sharp) {
		return (exp(sin(a)) - 1.2661) * 0.69;
	}
	return sin(a);
}

float ambient(vec2 p, float t) {
	return 0.045 * wave(p.x * 0.31 + p.y * 0.17 + t * 1.15)
		+ 0.03 * wave(-p.x * 0.23 + p.y * 0.47 + t * 1.6)
		+ 0.018 * wave(p.x * 0.71 - p.y * 0.53 + t * 2.3);
}

float surface(vec2 p, float t, out float foam) {
	float h = ambient(p, t);
	foam = 0.0;
	if (!use_wake) {
		return h;
	}
	for (int i = 0; i < WAKE_COUNT; i++) {
		vec4 w = wake_points[i];
		float age = t - w.z;
		if (age < 0.0 || age > WAKE_LIFE) {
			continue;
		}
		float r = distance(p, w.xy);
		float front = WAKE_SPEED * age + 0.3;
		float d = r - front;
		float env = exp(-d * d / (WAKE_WIDTH * WAKE_WIDTH));
		float decay = (1.0 - exp(-age * 3.0)) * exp(-age * WAKE_DECAY) / sqrt(1.0 + 0.35 * front);
		float ring = w.w * WAKE_AMP * env * decay * cos(d * WAKE_K);
		h += ring;
		// Schaumspur hinter dem Brett + Schaum auf den Wellenkämmen
		foam += w.w * 0.22 * exp(-age * 1.4) * exp(-r * r / (0.2 + age * 0.7));
		foam += max(ring - 0.06, 0.0) * 2.5;
	}
	return h;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float foam;
	float unused;
	const float EPS = 0.3;
	float h = surface(wp.xz, sim_time, foam);
	float hx = surface(wp.xz + vec2(EPS, 0.0), sim_time, unused);
	float hz = surface(wp.xz + vec2(0.0, EPS), sim_time, unused);
	VERTEX.y += h;
	if (hole_half > 0.0 && abs(wp.x - hole_center.x) < hole_half && abs(wp.z - hole_center.y) < hole_half) {
		VERTEX.y -= 1.5;
	}
	v_world_normal = normalize(vec3(h - hx, EPS, h - hz));
	v_world_pos = wp + vec3(0.0, h, 0.0);
	v_foam = foam;
	v_height = h;
}

// Normal-Map (Tangentenraum, Wasser liegt flach: x -> Welt x, y -> Welt z) als Welt-Verschiebung
vec2 detail_offset(sampler2D tex, vec2 uv) {
	vec3 t = texture(tex, uv).rgb * 2.0 - 1.0;
	return t.xy;
}

void fragment() {
	vec2 p = v_world_pos.xz;
	float t = sim_time;
	vec3 n = v_world_normal;
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	if (fx_detail) {
		// zwei Strukturen gleiten gegeneinander; in der Ferne schwächer (sonst flimmert es)
		vec2 da = detail_offset(detail_a, p * 0.11 + vec2(t * 0.021, t * 0.013));
		vec2 db = detail_offset(detail_b, p * 0.27 + vec2(-t * 0.017, t * 0.029));
		float fade = 1.0 - smoothstep(25.0, 140.0, dist);
		vec2 off = (da * 0.22 + db * 0.14) * (0.35 + 0.65 * fade);
		n = normalize(n + vec3(off.x, 0.0, off.y));
	} else {
		// alte feine Kräuselung (Sinus)
		vec2 ripple = vec2(
			sin(p.x * 2.3 + t * 2.1 + sin(p.y * 1.7)) + 0.5 * sin((p.x + p.y) * 5.1 + t * 3.3),
			cos(p.y * 2.9 - t * 1.8 + sin(p.x * 1.3)) + 0.5 * cos((p.x - p.y) * 4.7 - t * 2.9)
		) * 0.05;
		n = normalize(n + vec3(ripple.x, 0.0, ripple.y));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float facing = clamp(dot(n, to_cam), 0.0, 1.0);

	// Schaum
	float foam = v_foam;
	if (fx_foam) {
		// fleckig und zerfasert: Rauschen zerreißt die Fläche, Ränder bleiben weich
		float nz = texture(foam_noise, p * 0.35 + vec2(t * 0.03, -t * 0.02)).r;
		float nz2 = texture(foam_noise, p * 1.1 - vec2(t * 0.05, t * 0.04)).r;
		float pattern = nz * 0.65 + nz2 * 0.35;
		foam = smoothstep(0.25, 0.75, foam * (0.45 + 1.1 * pattern));
	}
	foam = clamp(foam, 0.0, 0.85);

	// Grundfarbe: von oben tief/türkis
	vec3 col = mix(shallow_color, deep_color, facing);
	float spec = 0.5;
	float rough = 0.04;
	vec3 emit = vec3(0.0);

	if (fx_fresnel) {
		// Schlick: flach über den See spiegelt der Himmel, steil schaut man hinein
		float fres = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
		// Spiegelbild: Himmel, etwas tiefer/blauer als der Dunst am Horizont (sonst milchig)
		vec3 refl = sky_color * vec3(0.5, 0.62, 0.78);
		col = mix(mix(shallow_color, deep_color, 0.55), refl, clamp(fres * 1.3, 0.0, 0.55));
		spec = 0.5;            // Glanz am Horizont nicht erhöhen: Himmelsspiegelung macht sonst alles milchig
		rough = 0.03;
	}
	if (fx_crest) {
		// dünne Wellenkämme lassen Licht durch: helleres, grünlicheres Türkis, vor allem gegen die Sonne
		float crest = smoothstep(0.02, 0.12, v_height);
		float back = 0.5 + 0.5 * clamp(dot(-to_cam, normalize(vec3(sun_dir.x, 0.0, sun_dir.z))), 0.0, 1.0);
		emit += shallow_color * 1.4 * crest * back * sun_energy * 0.35;   // Farbe folgt dem Wasser
	}
	if (fx_glitter) {
		// Sonnenglitzern: winzige Spiegel in der Struktur, die genau zur Sonne zeigen
		vec3 hv = normalize(normalize(sun_dir) + to_cam);
		float g = pow(clamp(dot(n, hv), 0.0, 1.0), 900.0);
		float sparkle = texture(foam_noise, p * 2.7 + vec2(t * 0.4, -t * 0.3)).r;
		g *= smoothstep(0.55, 0.8, sparkle);
		emit += sun_color * g * sun_energy * 6.0 * (1.0 - foam);
	}

#ifdef WATER_DEPTH
	// Wassertiefe entlang des Blickstrahls bis zum Grund/Feature dahinter
	float raw = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vpos.xyz /= vpos.w;
	float thick = max(-vpos.z - (-VERTEX.z), 0.0);
	float alpha = 1.0;
	if (fx_clear) {
		// im Flachen durchsichtig und heller, schnell trüber mit der Tiefe (Waldsee)
		alpha = mix(0.6, 1.0, smoothstep(0.0, 1.0, thick));   // trüber Waldsee: nur am Rand etwas durchsichtig
		col = mix(shallow_color * 1.15, col, smoothstep(0.0, 1.0, thick));
	}
	ALPHA = max(alpha, foam);
#endif

	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(rough, 0.7, foam);
	SPECULAR = mix(spec, 0.3, foam);
	METALLIC = 0.0;
	EMISSION = emit * (1.0 - foam);
}
