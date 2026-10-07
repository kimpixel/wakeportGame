shader_type spatial;
// Helmschale: links gelb, rechts grün (Teilung genau in der Mitte, von vorne nach hinten),
// auf jeder Seite ein Logo-Feld in der Gegenfarbe mit neutraler Blockgrafik (keine Schrift),
// Lüftungslöcher oben, ein Belüftungsloch seitlich hinten, Nieten unten.
// Innenseite und Rand: schwarzes Polster. COLOR.r: 0 außen, 0.5 Rand, 1 innen.

uniform vec3 center = vec3(0.0, 0.07, 0.015);
uniform vec3 radii = vec3(0.116, 0.125, 0.138);

varying vec3 lp;
varying float part;

void vertex() {
	lp = VERTEX;
	part = COLOR.r;
}

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

// Richtung vom Helm-Mittelpunkt, auf die Kugel normiert (für Löcher/Nieten)
vec3 dir_of(vec3 p) { return normalize((p - center) / radii); }

vec3 dir_from(float az_deg, float polar_deg) {
	float az = radians(az_deg);
	float po = radians(polar_deg);
	return vec3(sin(po) * sin(az), cos(po), sin(po) * cos(az));
}

float spot(vec3 d, vec3 target, float size) {
	return step(cos(size), dot(d, target));
}

void fragment() {
	vec3 yellow = srgb(vec3(0.93, 0.78, 0.08));
	vec3 green = srgb(vec3(0.18, 0.47, 0.12));
	vec3 col;
	float rough = 0.55;
	if (part > 0.25) {
		col = srgb(vec3(0.06, 0.06, 0.065));     // Polster
		rough = 0.9;
	} else {
		bool left = lp.x > 0.0;
		col = left ? yellow : green;
		vec3 q = lp - center;
		// Logo-Feld: gelbe Seite = langes grünes Feld (Schläfe bis Hinterkopf),
		// grüne Seite = kurzes gelbes Feld vorne
		vec2 box_c = left ? vec2(0.0, 0.03) : vec2(0.085, 0.0);     // (längs z, Höhe y)
		vec2 box_h = left ? vec2(0.075, 0.016) : vec2(0.042, 0.014);
		vec2 b = vec2(q.z, q.y) - box_c;
		if (abs(q.x) > 0.06 && abs(b.x) < box_h.x && abs(b.y) < box_h.y) {
			col = left ? green : yellow;
			// neutrale Blockgrafik: Balkenreihe in der Gegenfarbe
			vec2 u = (b + box_h) / (2.0 * box_h);
			float bar = step(0.12, fract(u.x * 9.0)) * step(fract(u.x * 9.0), 0.78);
			if (u.x > 0.06 && u.x < 0.94 && u.y > 0.22 && u.y < 0.78 && bar > 0.5) {
				col = left ? srgb(vec3(0.97, 0.92, 0.55)) : green;
			}
		}
		vec3 d = dir_of(lp);
		// Lüftungslöcher oben (zwei Reihen, vorne und Mitte)
		float vent = 0.0;
		vent = max(vent, spot(d, dir_from(18.0, 28.0), 0.07));
		vent = max(vent, spot(d, dir_from(-18.0, 28.0), 0.07));
		vent = max(vent, spot(d, dir_from(35.0, 52.0), 0.06));
		vent = max(vent, spot(d, dir_from(-35.0, 52.0), 0.06));
		vent = max(vent, spot(d, dir_from(150.0, 30.0), 0.06));
		vent = max(vent, spot(d, dir_from(-150.0, 30.0), 0.06));
		// seitliches Belüftungsloch hinten (mit rötlichem Ring)
		float side_ring = max(spot(d, dir_from(118.0, 68.0), 0.13), spot(d, dir_from(-118.0, 68.0), 0.13));
		float side_hole = max(spot(d, dir_from(118.0, 68.0), 0.095), spot(d, dir_from(-118.0, 68.0), 0.095));
		if (side_ring > 0.5) col = srgb(vec3(0.45, 0.18, 0.1));
		if (vent > 0.5 || side_hole > 0.5) {
			col = srgb(vec3(0.05, 0.05, 0.05));
			rough = 0.9;
		}
		// Nieten (silbern) vorne und hinten unten an jeder Seite
		float rivet = 0.0;
		rivet = max(rivet, spot(d, dir_from(62.0, 93.0), 0.035));
		rivet = max(rivet, spot(d, dir_from(-62.0, 93.0), 0.035));
		rivet = max(rivet, spot(d, dir_from(112.0, 100.0), 0.035));
		rivet = max(rivet, spot(d, dir_from(-112.0, 100.0), 0.035));
		if (rivet > 0.5) {
			col = srgb(vec3(0.72, 0.72, 0.74));
			rough = 0.25;
			METALLIC = 0.8;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
