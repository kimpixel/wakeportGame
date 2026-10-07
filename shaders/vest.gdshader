shader_type spatial;
render_mode cull_disabled;
// Aufdruck der Impact-Weste: "Sticker-Bomb"-Collage aus überlappenden, gedrehten Aufklebern
// (eigenes Design, keine echten Logos). Liegt in UV-Koordinaten, bewegt sich also mit dem Stoff.
// Sorten: schwarzer Streifen mit gelber Block-Schrift, weißer Aufkleber mit schwarzer Schrift,
// roter Stern auf Streifen, runder cremefarbener Button mit Ring-Schrift, roter Schriftzug auf
// Weiß, "Foto"-Fleck in Orange/Braun, Comic-Fleck in Grün.

uniform float cells = 20.0;         // Aufkleber pro UV-Breite

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) { return vec2(h21(p), h21(p + vec2(17.3, 5.1))); }
vec2 rot(vec2 p, float a) { float c = cos(a); float s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

// Block-"Schrift": Zeile aus Balken mit Lücken (u, v in 0..1 innerhalb der Schriftzeile)
float letters(vec2 uv, float seed, float count) {
	float cell = floor(uv.x * count);
	float f = fract(uv.x * count);
	float on = step(0.18, f) * step(f, 0.86);
	// einige "Buchstaben" mit Querbalken-Loch
	float hole = step(0.42, uv.y) * step(uv.y, 0.58) * step(0.4, f) * step(f, 0.64) * step(0.5, h21(vec2(cell, seed)));
	return on * (1.0 - hole) * step(0.08, uv.y) * step(uv.y, 0.92);
}

// Farbe eines Aufklebers an Position q (Aufkleberkoordinaten -1..1), Sorte k
vec3 sticker(vec2 q, int k, float seed) {
	vec3 black = srgb(vec3(0.06, 0.06, 0.06));
	vec3 white = srgb(vec3(0.95, 0.93, 0.88));
	vec3 cream = srgb(vec3(0.86, 0.80, 0.68));
	vec3 yellow = srgb(vec3(0.97, 0.8, 0.12));
	vec3 red = srgb(vec3(0.85, 0.15, 0.12));
	vec2 u = q * 0.5 + 0.5;
	if (k == 0) {          // schwarz mit gelber Block-Schrift
		vec2 t = vec2((u.x - 0.08) / 0.84, (u.y - 0.25) / 0.5);
		bool in_t = t.x > 0.0 && t.x < 1.0 && t.y > 0.0 && t.y < 1.0;
		return (in_t && letters(t, seed, 6.0) > 0.5) ? yellow : black;
	} else if (k == 1) {   // weiß mit schwarzer Schrift in zwei Zeilen
		float line = floor(u.y * 3.0);
		vec2 t = vec2((u.x - 0.08) / 0.84, fract(u.y * 3.0));
		bool in_t = t.x > 0.0 && t.x < 1.0 && line > 0.0 && line < 3.0;
		return (in_t && letters(t, seed + line, 5.0 + line) > 0.5) ? black : white;
	} else if (k == 2) {   // Streifen schwarz/weiß mit rotem Stern
		vec3 c = fract(u.x * 7.0) < 0.5 ? black : white;
		vec2 s = q * 1.3;
		float a = atan(s.y, s.x);
		float r = length(s);
		float star = 0.55 + 0.35 * cos(5.0 * a + 1.57);
		return r < star ? red : c;
	} else if (k == 3) {   // runder Button: creme, Ring-Schrift, dunkle Mitte
		float r = length(q);
		if (r > 1.0) return vec3(-1.0);
		float ang = atan(q.y, q.x);
		float ring = step(0.62, r) * step(r, 0.88) * step(0.35, fract(ang * 4.0 + seed));
		vec3 c = r < 0.45 ? black : cream;
		return ring > 0.5 ? black : c;
	} else if (k == 4) {   // roter Schriftzug auf Weiß
		vec2 t = vec2((u.x - 0.06) / 0.88, (u.y - 0.3) / 0.4);
		bool in_t = t.x > 0.0 && t.x < 1.0 && t.y > 0.0 && t.y < 1.0;
		return (in_t && letters(t, seed, 9.0) > 0.5) ? red : white;
	} else if (k == 5) {   // "Foto": warmer Verlauf mit dunklen Flecken
		float n = h21(floor(u * 6.0) + seed);
		vec3 a = srgb(vec3(0.75, 0.35, 0.12));
		vec3 b = srgb(vec3(0.22, 0.12, 0.08));
		return mix(a, b, smoothstep(0.2, 0.9, u.y * 0.7 + n * 0.5));
	} else {               // Comic-Fleck grün/gelb mit schwarzen Linien
		vec3 c = srgb(vec3(0.62, 0.72, 0.28));
		return fract((u.x + u.y) * 6.0) < 0.15 ? black : c;
	}
}

void fragment() {
	vec2 p = UV * cells;
	vec2 cell = floor(p);
	vec3 col = srgb(vec3(0.07, 0.07, 0.07));
	float best = -1.0;
	// 3x3 Nachbarzellen: jeder Aufkleber kann in die Nachbarzellen ragen; der mit der
	// höchsten "Lage" (Zufallswert) liegt oben
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			for (int n = 0; n < 2; n++) {
				vec2 id = c + vec2(float(n) * 0.37, float(n) * 0.71);
				vec2 h = h22(id);
				vec2 center = c + 0.5 + (h - 0.5) * 0.8;
				float ang = (h21(id + 3.1) - 0.5) * 0.9;
				int kind = int(floor(h21(id + 7.7) * 7.0));
				vec2 size = kind == 3 ? vec2(0.55) : vec2(0.55 + 0.45 * h.x, 0.25 + 0.2 * h.y);
				if (kind == 2 || kind == 5 || kind == 6) size = vec2(0.5 + 0.3 * h.y, 0.45 + 0.3 * h.x);
				vec2 q = rot(p - center, -ang) / size;
				if (abs(q.x) <= 1.0 && abs(q.y) <= 1.0) {
					float layer = h21(id + 11.0);
					if (layer > best) {
						vec3 s = sticker(q, kind, h21(id + 5.0) * 10.0);
						if (s.x >= 0.0) {
							best = layer;
							col = s;
						}
					}
				}
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.7;
}
