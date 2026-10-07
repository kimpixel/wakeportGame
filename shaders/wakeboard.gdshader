shader_type spatial;
// Wakeboard-Grafik, eigenes Design im Stil eines Cable-Boards:
//  Oberseite: schwarz, an den Spitzen eine Collage aus Zeitungsausschnitten (Blindtext),
//             in der Mitte eine Zeitungs-Raute, Inserts (Gewindelöcher) auf der Mittellinie
//  Unterseite: creme mit großer dunkelgrauer Welle und kleinem Aufkleber
//  Kante: dunkel
// Koordinaten: x quer, z längs (Meter, Brettmitte = 0). COLOR.r: 0 oben, 0.5 Kante, 1 unten.

uniform float half_len = 0.71;
uniform float half_w = 0.215;
// optionale Foto-Textur der Unterseite (von unten gesehen, Länge senkrecht im Bild)
uniform sampler2D bottom_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_bottom_tex = false;

varying vec3 lp;
varying float part;

void vertex() {
	lp = VERTEX;
	part = COLOR.r;
}

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 rot(vec2 p, float a) { float c = cos(a); float s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

// Blindtext einer Zeitungsseite (p in Metern): Spalten mit Textzeilen, dazwischen Schlagzeilen.
float ink(vec2 p, float seed) {
	float hrow = floor(p.y * 26.0);
	float head = step(0.72, hash(vec2(hrow, seed * 5.0)));
	// Schlagzeile: fette Balkenbuchstaben
	float hf = fract(p.y * 26.0);
	float hline = step(0.22, hf) * step(hf, 0.82);
	float hword = step(0.28, hash(vec2(floor(p.x * 22.0), hrow + seed)));
	float hgap = step(0.12, fract(p.x * 22.0));
	float headline = hline * hword * hgap;
	// Fließtext
	float row = floor(p.y * 110.0);
	float in_line = step(0.45, fract(p.y * 110.0));
	float col = fract(p.x * 6.5 + seed);
	float gutter = step(0.05, col) * step(col, 0.96);
	float word = step(0.2, hash(vec2(floor(p.x * 70.0 + row * 3.1), row + seed * 17.0)));
	float body = in_line * gutter * word * 0.55;
	// gelegentlich ein Bildkasten
	float pic = step(0.86, hash(vec2(floor(p.x * 5.0), floor(p.y * 7.0) + seed * 3.0))) * 0.45;
	return max(mix(body, headline, head), pic);
}

// Großes S aus zwei Bögen (Mittellinien-Radius r, Strichstärke sw); p: u quer, v längs.
// Oberer Bogen um (0, r) von rechts oben gegen den Uhrzeigersinn bis zur Mitte,
// unterer Bogen um (0, -r) von der Mitte im Uhrzeigersinn bis links unten.
float s_letter(vec2 p, float r, float sw) {
	vec2 a = p - vec2(0.0, r);
	vec2 b = p - vec2(0.0, -r);
	float ang_a = degrees(atan(a.y, a.x));
	float ang_b = degrees(atan(b.y, b.x));
	float ring_a = step(abs(length(a) - r), sw * 0.5);
	float ring_b = step(abs(length(b) - r), sw * 0.5);
	float arc_a = (ang_a >= 25.0 || ang_a <= -90.0) ? 1.0 : 0.0;
	float arc_b = (ang_b >= -155.0 && ang_b <= 90.0) ? 1.0 : 0.0;
	return max(ring_a * arc_a, ring_b * arc_b);
}

// Ein Ausschnitt: x = deckt ab, y = Tinte, z = Papierhelligkeit (Rand etwas dunkler)
vec3 clipping(vec2 p, vec2 c, vec2 h, float a, float seed) {
	vec2 q = rot(p - c, -a);
	vec2 d = abs(q) - h;
	float m = max(d.x, d.y);
	float inside = step(m, 0.0);
	float shade = 0.9 + 0.1 * hash(vec2(seed, 3.0)) - smoothstep(-0.005, 0.0, m) * 0.3;
	return vec3(inside, ink(q + h, seed), shade);
}

void fragment() {
	vec3 col;
	float rough = 0.4;
	if (part < 0.25) {
		// ---------------- Oberseite
		col = srgb(vec3(0.07, 0.075, 0.1));
		rough = 0.35;
		float paper = 0.0;
		float tinte = 0.0;
		float light = 1.0;
		// Spitzen: Collage, an beiden Enden gespiegelt
		float sg = sign(lp.z);
		vec2 P = vec2(lp.x * sg, half_len - abs(lp.z));      // y = Abstand von der Spitze
		float seed0 = sg > 0.0 ? 10.0 : 0.0;
		vec3 c1 = clipping(P, vec2(-0.09, 0.09), vec2(0.15, 0.12), 0.10, seed0 + 1.0);
		vec3 c2 = clipping(P, vec2(0.11, 0.07), vec2(0.13, 0.12), -0.16, seed0 + 2.0);
		vec3 c3 = clipping(P, vec2(0.02, 0.20), vec2(0.18, 0.055), 0.06, seed0 + 3.0);
		vec3 c4 = clipping(P, vec2(-0.16, 0.22), vec2(0.07, 0.05), -0.28, seed0 + 4.0);
		vec3 c5 = clipping(P, vec2(0.17, 0.21), vec2(0.06, 0.045), 0.22, seed0 + 5.0);
		vec3 cs[5] = vec3[5](c1, c2, c4, c5, c3);
		for (int i = 0; i < 5; i++) {
			if (cs[i].x > 0.5) {
				paper = 1.0;
				tinte = cs[i].y;
				light = cs[i].z;
			}
		}
		// Mitte: Raute aus gefalteten Zeitungsseiten
		float rh = abs(lp.x) / 0.085 + abs(lp.z) / 0.2;
		if (rh < 1.0) {
			paper = 1.0;
			tinte = ink(vec2(lp.x + 0.085, lp.z + 0.2), 7.0);
			light = (lp.x < 0.0 ? 0.86 : 0.97) - smoothstep(0.93, 1.0, rh) * 0.25;
		}
		if (paper > 0.5) {
			vec3 pc = srgb(vec3(0.86, 0.80, 0.66)) * light;
			col = mix(pc, srgb(vec3(0.16, 0.14, 0.12)), tinte);
			rough = 0.6;
		}
		// Inserts auf der Mittellinie (zwei Gruppen für die Bindungen)
		float dmin = 1.0;
		for (int k = 0; k < 7; k++) {
			float zk = 0.17 + 0.033 * float(k);
			dmin = min(dmin, length(vec2(lp.x, abs(lp.z) - zk)));
		}
		if (dmin < 0.0045) {
			col = dmin < 0.0026 ? srgb(vec3(0.05)) : srgb(vec3(0.6, 0.6, 0.62));
			rough = 0.3;
		}
	} else if (part < 0.75) {
		// ---------------- Kante
		col = srgb(vec3(0.09, 0.09, 0.1));
		rough = 0.3;
	} else {
		// ---------------- Unterseite
		col = srgb(vec3(0.93, 0.88, 0.72));
		rough = 0.28;
		if (use_bottom_tex) {
			// von unten gesehen ist links/rechts gespiegelt
			vec2 uv = vec2(0.5 - lp.x / (2.0 * half_w), 0.5 + lp.z / (2.0 * half_len));
			vec4 t = texture(bottom_tex, uv);
			col = mix(srgb(vec3(0.95, 0.91, 0.75)), t.rgb, t.a);
		} else {
			// großes, schräg gestelltes S über die ganze Unterseite (von unten richtig lesbar)
			vec2 sp = vec2(-lp.x, -lp.z);
			sp.x -= sp.y * 0.08;                          // Schräglage
			if (s_letter(sp, 0.125, 0.095) > 0.5) {
				col = srgb(vec3(0.30, 0.33, 0.36));
			}
			// kleiner Aufkleber am Tail
			vec2 s = vec2(lp.x - 0.03, lp.z - 0.52);
			if (abs(s.x) < 0.045 && abs(s.y) < 0.03) {
				col = srgb(vec3(0.95));
				if (abs(s.x) < 0.04 && abs(s.y) < 0.025 && fract(s.y * 160.0) < 0.35 && hash(vec2(floor(s.x * 90.0), floor(s.y * 160.0))) > 0.2) {
					col = srgb(vec3(0.35));
				}
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
