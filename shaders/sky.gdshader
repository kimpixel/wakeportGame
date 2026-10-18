shader_type sky;
// Himmel mit Tageszeit und Wetter: Verlauf Horizont -> Zenit, Abend-/Morgenrot zur Sonne hin,
// Sonnenscheibe, ziehende Wolken (Bedeckungsgrad, bei Regen dunkle Wolkenballen), nachts Mond,
// Sterne, Milchstraße und die Lichtglocke von Frankfurt; Extras: Regenbogen, Kondensstreifen.

uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);   // zur Sonne (Welt)
uniform vec3 moon_dir = vec3(0.0, 0.57, 0.82); // zum Mond
uniform vec3 city_dir = vec3(-0.5, 0.0, -0.85); // waagrecht Richtung Frankfurt
uniform float day = 1.0;          // 0 = Nacht, 1 = Tag
uniform float golden = 0.0;       // tief stehende Sonne: warmes Licht
uniform float cloud = 0.0;        // 0 = klar, 1 = bedeckt
uniform float rain = 0.0;
uniform float snow = 0.0;         // Schneehimmel: hell-grau
uniform float rainbow = 0.0;      // Regenbogen (gegenüber der Sonne, 42°)
uniform float trails = 0.0;       // Kondensstreifen
uniform float energy = 1.0;       // Helligkeit (Browser-Renderer etwas dunkler)
uniform float radiance = 1.0;     // nur Spiegelungen/Umgebungslicht (nachts gedämpft, sonst glänzen helle Flächen)
uniform float t = 0.0;            // Zeit für den Wolkenzug

// Hash ohne sin (sin mit großen Werten ist auf der GPU ungenau: Wolken bekamen kantige Facetten)
float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float h3(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));   // jede Stufe gedreht: keine Gitterkanten
	for (int k = 0; k < 5; k++) {
		v += a * n2(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Regenbogenfarbe: u 0 = innen (violett) .. 1 = außen (rot)
vec3 spectrum(float u) {
	float hue = (1.0 - u) * 0.78;
	vec3 k = clamp(abs(fract(hue + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

// Sterne: Zellen auf der Himmelskugel, je Zelle höchstens ein Stern mit eigener Helligkeit und Farbe
float stars(vec3 d, float scale, float thresh) {
	vec3 p = d * scale;
	vec3 c = floor(p);
	float r = h3(c);
	if (r < thresh) {
		return 0.0;
	}
	vec3 off = vec3(h3(c + 1.3), h3(c + 2.7), h3(c + 4.1)) * 0.6 + 0.2;
	float dist = length(fract(p) - off);
	float b = (r - thresh) / (1.0 - thresh);
	return smoothstep(0.32, 0.0, dist) * (0.25 + 1.5 * b * b);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sd = normalize(sun_dir);
	float night = 1.0 - day;
	// Grundfarben Tag/Nacht
	vec3 zen = mix(vec3(0.004, 0.007, 0.022), vec3(0.2, 0.4, 0.78), day);
	vec3 hor = mix(vec3(0.016, 0.022, 0.045), vec3(0.68, 0.78, 0.9), day);
	// Morgen-/Abendrot: am Horizont, zur Sonne hin am stärksten
	vec2 dh = normalize(d.xz + vec2(1e-4));
	vec2 sh = normalize(sd.xz + vec2(1e-4));
	float toward = max(dot(dh, sh), 0.0);
	float twilight = golden * clamp(day * 1.5 + 0.2, 0.0, 1.0);
	hor = mix(hor, vec3(1.0, 0.5, 0.25), twilight * (0.25 + 0.75 * toward * toward));
	// Blaue Stunde: kräftiges Tiefblau im Zenit, rosa Saum gegenüber der Sonne
	float blue_hour = smoothstep(0.05, 0.35, day) * smoothstep(0.75, 0.4, day);
	zen = mix(zen, vec3(0.06, 0.1, 0.32), blue_hour * 0.8);
	hor = mix(hor, vec3(0.55, 0.38, 0.5), blue_hour * 0.35 * (1.0 - toward));
	zen = mix(zen, vec3(0.25, 0.3, 0.55), twilight * 0.4 * (1.0 - blue_hour));
	zen = mix(zen, vec3(0.01, 0.1, 0.5), trails * 0.9 * day);   // Spätsommer-Blau beim Kondensstreifen-Himmel
	hor = mix(hor, vec3(0.42, 0.6, 0.86), trails * 0.6 * day);
	vec3 col = mix(hor, zen, pow(clamp(h, 0.0, 1.0), 0.45));
	// Lichtglocke über Frankfurt (Stadt und Flughafen): orange am Horizont, nachts
	float city = pow(max(dot(dh, normalize(city_dir.xz)), 0.0), 3.0);
	float glow_h = exp(-max(h, 0.0) * 7.0);
	col += vec3(0.075, 0.042, 0.02) * night * glow_h * (0.35 + 0.65 * city) * (1.0 + cloud);
	// Bedeckt: grau, Regen dunkler, Schnee heller
	vec3 grey = mix(vec3(0.55, 0.58, 0.62), vec3(0.74, 0.76, 0.8), snow) * mix(0.05, 1.0, day) * (1.0 - 0.4 * rain);
	col = mix(col, grey, cloud * 0.85);
	// Unter dem Horizont: dunkler Dunst
	if (h < 0.0) {
		col = mix(col, col * 0.55, clamp(-h * 6.0, 0.0, 1.0));
	}
	float clear_sky = 1.0 - cloud * 0.9;
	if (h > 0.0 && day < 0.45) {
		float vis = smoothstep(0.45, 0.05, day) * clear_sky * smoothstep(0.0, 0.25, h);
		// Milchstraße: schwaches, fleckiges Band
		vec3 mw_n = normalize(vec3(0.55, 0.35, 0.76));
		float band = exp(-pow(dot(d, mw_n) / 0.16, 2.0));
		float dust = fbm(vec2(atan(d.z, d.x) * 6.0, d.y * 9.0)) ;
		col += vec3(0.05, 0.055, 0.075) * band * (0.4 + dust) * vis;
		// Sterne: viele schwache, wenige helle, im Band dichter; funkeln leicht
		float st = stars(d, 260.0, 0.985 - band * 0.012);
		st += stars(d, 110.0, 0.994) * 1.6;
		float tw = 0.75 + 0.25 * sin(t * 3.0 + h3(floor(d * 260.0)) * 40.0);
		col += vec3(0.9, 0.93, 1.0) * st * tw * vis * 0.9;
	}
	// Mond (nachts): Scheibe mit Flecken, Hof
	vec3 md = normalize(moon_dir);
	float cm = dot(d, md);
	float moon_vis = smoothstep(0.5, 0.1, day);
	if (moon_vis > 0.0) {
		float disk_m = smoothstep(0.99990, 0.99994, cm);
		vec3 mp = d - md * cm;
		float mare = fbm(mp.xz * 900.0 + mp.y * 600.0);
		vec3 moon_col = vec3(0.95, 0.93, 0.86) * mix(0.62, 1.05, smoothstep(0.35, 0.65, mare));
		float halo = pow(max(cm, 0.0), 2500.0) * 0.25 + pow(max(cm, 0.0), 60.0) * 0.035;
		float in_refl = AT_CUBEMAP_PASS ? 0.05 : 1.0;     // gespiegelt viel schwächer (sonst grelle Flecken auf den Features)
		col = mix(col, moon_col * 1.6 * in_refl, disk_m * moon_vis * (1.0 - 0.9 * cloud));
		col += vec3(0.55, 0.6, 0.7) * halo * moon_vis * (1.0 - 0.5 * cloud) * in_refl;
	}
	// Sonne
	float cs = dot(d, sd);
	vec3 sun_col = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.55, 0.25), golden);
	float disk = smoothstep(0.99955, 0.9998, cs);
	float glow = pow(max(cs, 0.0), 180.0) * 0.6 + pow(max(cs, 0.0), 12.0) * 0.12 * (1.0 - cloud);
	float above = smoothstep(-0.03, 0.02, sd.y);
	col += sun_col * (disk * 12.0 * (1.0 - 0.95 * cloud) + glow) * above;
	// Kondensstreifen ("Chemtrail"-Himmel): viele lange gerade Bahnen (Großkreise) kreuz und quer. Frische sind schmal,
	// hell, oft doppelt und haben vorne das Flugzeug; alte sind breit, fasrig und verwaschen und gehen über den ganzen Himmel.
	if (trails > 0.0 && h > 0.0) {
		float fade = smoothstep(0.0, 0.1, h) * (1.0 - cloud * 0.8);
		vec3 tc = mix(vec3(0.9, 0.92, 0.96), vec3(1.0, 0.85, 0.7), twilight * 0.6) * mix(0.05, 1.0, day);
		float acc = 0.0;
		for (int k = 0; k < 26; k++) {
			float fk = float(k);
			float th = h2(vec2(fk, 1.0)) * 6.2832;
			vec3 n = normalize(vec3(cos(th), (h2(vec2(fk, 2.0)) - 0.5) * 3.2, sin(th)));
			float dn = dot(d, n);
			float age = h2(vec2(fk, 3.0));               // 0 frisch … 1 alt
			float w = 0.0012 + 0.035 * age * age;
			if (abs(dn) > w * 3.5) {
				continue;
			}
			vec3 u = normalize(cross(vec3(0.0, 1.0, 0.0), n));
			vec3 b = cross(n, u);
			float phi = atan(dot(d, b), dot(d, u));
			float br = mix(0.95, 0.35, age);
			float line;
			if (age < 0.3) {
				// frisch: zwei Linien dicht nebeneinander, vorne fliegt das Flugzeug weiter (Streifen wächst)
				line = exp(-pow((dn - w * 0.9) / w, 2.0)) + exp(-pow((dn + w * 0.9) / w, 2.0)) * 0.8;
				float head = mod(h2(vec2(fk, 4.0)) * 6.28 + 0.003 * t, 6.28) - 3.14;
				float behind = mod(head - phi + 6.28, 6.28);
				line *= smoothstep(0.0, 0.03, behind) * (1.0 - smoothstep(1.2, 3.0, behind));
			} else {
				// alt: breit, ausgefranst, stellenweise aufgelöst
				line = exp(-pow(dn / w, 2.0));
				float fib = n2(vec2(phi * 25.0, dn / w * 2.0 + fk * 7.0));
				line *= 0.45 + 0.75 * fib;
				line *= smoothstep(0.15, 0.5, n2(vec2(phi * 3.0, fk * 3.3)));
			}
			acc += line * br;
		}
		col = mix(col, tc, clamp(acc, 0.0, 1.0) * trails * fade);
	}
	// Wolken: Ebene hoch über dem See, ziehen langsam (bei Regen schneller)
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.08) * 0.9 + vec2(t * 0.004, t * 0.0015) * (1.0 + 2.0 * rain);
		float n = fbm(uv * 1.6);
		float cover = smoothstep(1.0 - cloud * 0.85 - 0.12, 1.15 - cloud * 0.85, n + 0.2 * cloud);
		cover *= smoothstep(0.0, 0.12, h);
		float lit = 0.55 + 0.45 * clamp(pow(max(cs, 0.0), 6.0) + sd.y, 0.0, 1.0);
		vec3 cc = mix(vec3(0.35, 0.37, 0.42), vec3(1.0, 1.0, 1.0), lit * (1.0 - 0.6 * cloud) * (1.0 - 0.5 * rain));
		// Wolkenballen: auch bei voller Bedeckung hell/dunkel, Regenwolken mit dunklen Unterseiten
		float mass = fbm(uv * 3.3 + vec2(5.2, 1.3));
		float body = smoothstep(0.25, 0.75, mass);
		cc *= mix(1.0, mix(0.55, 1.2, body), clamp(cloud * 1.2 - 0.2, 0.0, 1.0));
		cc *= 1.0 - rain * 0.45 * smoothstep(0.4, 0.8, n);
		cc = mix(cc, cc * vec3(1.0, 0.65, 0.45), twilight * 0.8);
		cc = mix(cc, vec3(0.8, 0.82, 0.86), snow * 0.5);
		cc *= mix(0.05, 1.0, day);
		cc += vec3(0.05, 0.03, 0.015) * night * (0.4 + 0.6 * city) * glow_h * 2.0;   // von unten orange angestrahlt
		col = mix(col, cc, cover * 0.95);
	}
	// Regenbogen: Hauptbogen 40,5..42,5° um den Gegenpunkt der Sonne (rot außen), schwacher Nebenbogen verkehrt
	if (rainbow > 0.0 && h > -0.01) {
		float a = degrees(acos(clamp(dot(d, -sd), -1.0, 1.0)));
		float u1 = (a - 40.4) / 2.3;
		float w1 = smoothstep(0.0, 0.2, u1) * smoothstep(1.0, 0.8, u1);
		float u2 = (a - 50.2) / 3.2;
		float w2 = smoothstep(0.0, 0.25, u2) * smoothstep(1.0, 0.75, u2);
		float inside = smoothstep(40.5, 30.0, a) * 0.04;     // innen heller
		float strength = rainbow * above * day * smoothstep(-0.01, 0.06, h);
		col += (spectrum(clamp(u1, 0.0, 1.0)) * w1 * 0.22 + spectrum(1.0 - clamp(u2, 0.0, 1.0)) * w2 * 0.07
			+ vec3(inside)) * strength;
	}
	COLOR = col * energy;
	if (AT_CUBEMAP_PASS) {
		COLOR *= radiance;
	}
}
