shader_type sky;
// Himmel mit Tageszeit und Wetter: Verlauf Horizont -> Zenit, Abend-/Morgenrot zur Sonne hin,
// Sonnenscheibe, ziehende Wolken (Bedeckungsgrad), nachts Sterne.

uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);   // zur Sonne (Welt)
uniform float day = 1.0;          // 0 = Nacht, 1 = Tag
uniform float golden = 0.0;       // tief stehende Sonne: warmes Licht
uniform float cloud = 0.0;        // 0 = klar, 1 = bedeckt
uniform float rain = 0.0;
uniform float energy = 1.0;       // Helligkeit (Browser-Renderer etwas dunkler)
uniform float t = 0.0;            // Zeit für den Wolkenzug

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * n2(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sd = normalize(sun_dir);
	// Grundfarben Tag/Nacht
	vec3 zen = mix(vec3(0.008, 0.012, 0.035), vec3(0.2, 0.4, 0.78), day);
	vec3 hor = mix(vec3(0.03, 0.04, 0.08), vec3(0.68, 0.78, 0.9), day);
	// Morgen-/Abendrot: am Horizont, zur Sonne hin am stärksten
	vec2 dh = normalize(d.xz + vec2(1e-4));
	vec2 sh = normalize(sd.xz + vec2(1e-4));
	float toward = max(dot(dh, sh), 0.0);
	float twilight = golden * clamp(day * 1.5 + 0.2, 0.0, 1.0);
	hor = mix(hor, vec3(1.0, 0.5, 0.25), twilight * (0.25 + 0.75 * toward * toward));
	zen = mix(zen, vec3(0.25, 0.3, 0.55), twilight * 0.4);
	vec3 col = mix(hor, zen, pow(clamp(h, 0.0, 1.0), 0.45));
	// Bedeckt: grau, Regen dunkler
	vec3 grey = vec3(0.55, 0.58, 0.62) * mix(0.06, 1.0, day) * (1.0 - 0.35 * rain);
	col = mix(col, grey, cloud * 0.85);
	// Unter dem Horizont: dunkler Dunst
	if (h < 0.0) {
		col = mix(col, col * 0.55, clamp(-h * 6.0, 0.0, 1.0));
	}
	// Sterne (klare Nacht)
	if (h > 0.0 && day < 0.3) {
		vec2 sp = d.xz / (h + 0.3) * 120.0;
		float star = step(0.9975, h2(floor(sp)));
		col += vec3(star) * (0.3 - day) * 3.0 * (1.0 - cloud) * smoothstep(0.0, 0.2, h);
	}
	// Sonne
	float cs = dot(d, sd);
	vec3 sun_col = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.55, 0.25), golden);
	float disk = smoothstep(0.99955, 0.9998, cs);
	float glow = pow(max(cs, 0.0), 180.0) * 0.6 + pow(max(cs, 0.0), 12.0) * 0.12 * (1.0 - cloud);
	float above = smoothstep(-0.03, 0.02, sd.y);
	col += sun_col * (disk * 12.0 * (1.0 - 0.95 * cloud) + glow) * above;
	// Wolken: Ebene hoch über dem See, ziehen langsam
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.08) * 0.9 + vec2(t * 0.004, t * 0.0015);
		float n = fbm(uv * 1.6);
		float cover = smoothstep(1.0 - cloud * 0.85 - 0.12, 1.15 - cloud * 0.85, n + 0.2 * cloud);
		cover *= smoothstep(0.0, 0.12, h);
		float lit = 0.55 + 0.45 * clamp(pow(max(cs, 0.0), 6.0) + sd.y, 0.0, 1.0);
		vec3 cc = mix(vec3(0.35, 0.37, 0.42), vec3(1.0, 1.0, 1.0), lit * (1.0 - 0.6 * cloud) * (1.0 - 0.5 * rain));
		cc = mix(cc, cc * vec3(1.0, 0.65, 0.45), twilight * 0.8);
		cc *= mix(0.05, 1.0, day);
		col = mix(col, cc, cover * 0.95);
	}
	COLOR = col * energy;
}
