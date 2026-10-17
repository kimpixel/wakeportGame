shader_type spatial;
// Schwarzes Rail (Rohr, Halbrund-Rail, Rail im Transition Rail, schwarze Gleitflächen):
//  * matter Kunststoff/Pulverlack, kaum Glanz
//  * viele feine Kratzer längs (von Brettkanten und Finnen), oben auf der Gleitfläche am meisten
//  * vom Wasser aus verdreckt wie die weißen Teile (water_dirt)
// Längs = Achse des Rails: bei Rohren aus Util.beam (Einheitszylinder, Höhe gestreckt) lokal Y, sonst lokal -Z.

uniform vec3 base_color : source_color = vec3(0.06, 0.06, 0.07);
uniform bool tube = false;           // Zylinder aus Util.beam: Achse lokal Y, Länge = Streckung der Y-Achse
uniform float tube_r = 0.05;         // Radius des Rohrs (m), für den Umfang
uniform float seed = 0.0;            // Zufall je Teil (0..20)

varying vec3 mp;                     // Position im Mesh
varying vec3 wp;                     // Weltposition
varying vec3 wn;                     // Welt-Normale
varying float axis_len;              // Streckung der Rohrachse

#include "res://shaders/feature_common.gdshaderinc"

void vertex() {
	mp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	axis_len = length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	float sd = seed;
	// c.x = quer (m, um den Umfang), c.y = längs (m)
	vec2 c;
	if (tube) {
		c = vec2(atan(mp.z, mp.x) * tube_r, mp.y * axis_len);
	} else {
		c = vec2(mp.x, -mp.z);
	}
	vec3 col = base_color;
	float rough = 0.78;
	// leicht fleckig: ausgeblichen von Sonne, Wachs- und Kalkreste
	float mott = fbm(vec3(c.x * 4.0, c.y * 0.5, sd));
	col *= mix(0.85, 1.35, smoothstep(0.3, 0.8, mott));
	rough += (mott - 0.5) * 0.12;
	// oben (Gleitfläche) zerkratzt, unten kaum
	float top = smoothstep(-0.3, 0.75, normalize(wn).y);
	// Kratzer: sehr fein, lang gezogen, mehrere Lagen mit leicht verschiedener Richtung
	float s1 = noise(vec3(c.x * 150.0, c.y * 0.7, 2.3 + sd));
	float s2 = noise(vec3((c.x + c.y * 0.012) * 260.0 + 5.0, c.y * 1.3, 6.1 + sd));
	float s3 = noise(vec3((c.x - c.y * 0.02) * 80.0 + 11.0, c.y * 2.2, 9.7 + sd)) * smoothstep(0.35, 0.65, noise(vec3(c.x * 3.0, c.y * 0.8, sd + 4.0)));
	// in der Ferne (Linien feiner als ein Pixel) ausblenden, sonst Moiré; dann nur noch etwas heller
	float px = fwidth(c.x);
	float aa1 = 1.0 - smoothstep(0.35, 0.8, px * 150.0);
	float aa2 = 1.0 - smoothstep(0.35, 0.8, px * 260.0);
	float aa3 = 1.0 - smoothstep(0.35, 0.8, px * 80.0);
	float fine = smoothstep(0.8, 0.95, s1) * aa1 + smoothstep(0.82, 0.95, s2) * aa2 * 0.8;
	float deep = smoothstep(0.88, 0.97, s3) * aa3;
	col = mix(col, vec3(0.11), (1.0 - aa2) * 0.3 * top);
	float scratch = clamp(fine * 0.7 + deep, 0.0, 1.0) * mix(0.25, 1.0, top);
	// Kratzer im schwarzen Kunststoff sind heller grau und rauer
	col = mix(col, vec3(0.2, 0.2, 0.2), scratch * 0.55);
	rough = mix(rough, 0.9, scratch * 0.6);
	// abgeriebene, etwas glattere Laufspur oben in der Mitte
	float wear = smoothstep(0.85, 1.0, normalize(wn).y) * smoothstep(0.35, 0.7, noise(vec3(c.x * 30.0, c.y * 0.3, sd + 2.0)));
	rough = mix(rough, 0.6, wear * 0.5);
	col = water_dirt(col, wp.y, vec3(c.x, mp.y, c.y), sd, 1.0, rough);
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	SPECULAR = 0.3;
}
