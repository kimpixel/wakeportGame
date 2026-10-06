shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Muss mit scripts/water.gd übereinstimmen (gleiche Höhenfunktion für Physik und Grafik).
#define WAKE_COUNT 56

uniform vec4 wake_points[WAKE_COUNT]; // x, z, Entstehungszeit, Stärke
uniform float sim_time = 0.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.15, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.33, 0.35);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.97);
uniform bool use_wake = true;
uniform vec2 hole_center;       // grobes Gitter: unter dem feinen Gitter absenken
uniform float hole_half = 0.0;

const float WAKE_SPEED = 2.6;
const float WAKE_WIDTH = 0.9;
const float WAKE_K = 3.0;
const float WAKE_AMP = 0.2;
const float WAKE_DECAY = 0.55;
const float WAKE_LIFE = 5.6;

varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying float v_foam;

float ambient(vec2 p, float t) {
	return 0.045 * sin(p.x * 0.31 + p.y * 0.17 + t * 1.15)
		+ 0.03 * sin(-p.x * 0.23 + p.y * 0.47 + t * 1.6)
		+ 0.018 * sin(p.x * 0.71 - p.y * 0.53 + t * 2.3);
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
}

void fragment() {
	vec2 p = v_world_pos.xz;
	float t = sim_time;
	// feine Kräuselung nur für die Optik
	vec2 ripple = vec2(
		sin(p.x * 2.3 + t * 2.1 + sin(p.y * 1.7)) + 0.5 * sin((p.x + p.y) * 5.1 + t * 3.3),
		cos(p.y * 2.9 - t * 1.8 + sin(p.x * 1.3)) + 0.5 * cos((p.x - p.y) * 4.7 - t * 2.9)
	) * 0.05;
	vec3 n = normalize(v_world_normal + vec3(ripple.x, 0.0, ripple.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float foam = clamp(v_foam, 0.0, 0.85);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, facing);
	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(0.04, 0.7, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
