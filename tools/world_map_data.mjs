#!/usr/bin/env node
// Kartendaten für die World Map (scripts/ui/world_map.gd) aus Natural Earth (gemeinfrei, https://www.naturalearthdata.com/)
// erzeugen: Land, große Seen und Landesgrenzen, vereinfacht (Douglas-Peucker) und auf 1/100 Grad gerundet.
//
//   node tools/world_map_data.mjs ORDNER          ORDNER mit ne_50m_land.geojson, ne_50m_lakes.geojson,
//                                                 ne_50m_admin_0_boundary_lines_land.geojson
//   (Quelle: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/<name>.geojson)
//
// Ausgabe assets/map/world.json: {"land": [[lon*100, lat*100, …], …], "lakes": […], "borders": […]} – Ringe bzw. Linien
// als flache Ganzzahl-Listen.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = process.argv[2];
const TOL = { land: 0.04, lakes: 0.04, borders: 0.06 };      // Grad
const MIN_AREA = { land: 0.02, lakes: 0.3 };                  // Grad² – kleinere Inseln/Seen weglassen

function dp(pts, tol) {
	if (pts.length < 3) return pts;
	const keep = new Uint8Array(pts.length);
	keep[0] = keep[pts.length - 1] = 1;
	const st = [[0, pts.length - 1]];
	while (st.length) {
		const [a, b] = st.pop();
		const [ax, ay] = pts[a], [bx, by] = pts[b];
		const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy;
		let best = -1, bi = -1;
		for (let i = a + 1; i < b; i++) {
			const [px, py] = pts[i];
			let t = l2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0;
			t = Math.max(0, Math.min(1, t));
			const d = Math.hypot(px - ax - t * dx, py - ay - t * dy);
			if (d > best) { best = d; bi = i; }
		}
		if (best > tol) { keep[bi] = 1; st.push([a, bi], [bi, b]); }
	}
	return pts.filter((_, i) => keep[i]);
}

function area(r) {
	let s = 0;
	for (let i = 0; i < r.length; i++) {
		const [x0, y0] = r[i], [x1, y1] = r[(i + 1) % r.length];
		s += x0 * y1 - x1 * y0;
	}
	return Math.abs(s) / 2;
}

function flat(pts) {
	const out = [];
	let px = null, py = null;
	for (const [x, y] of pts) {
		const qx = Math.round(x * 100), qy = Math.round(y * 100);
		if (qx === px && qy === py) continue;
		out.push(qx, qy);
		px = qx; py = qy;
	}
	return out;
}

function rings(file, kind) {
	const gj = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
	const out = [];
	for (const f of gj.features) {
		const g = f.geometry;
		const polys = g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : [];
		for (const poly of polys) {
			const outer = poly[0];                    // Löcher (Binnenseen im Land) kommen aus der Seen-Ebene
			if (area(outer) < MIN_AREA[kind]) continue;
			const s = dp(outer, TOL[kind]);
			if (s.length >= 4) out.push(flat(s));
		}
	}
	return out;
}

function lines(file) {
	const gj = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
	const out = [];
	for (const f of gj.features) {
		const g = f.geometry;
		const ls = g.type === 'LineString' ? [g.coordinates] : g.type === 'MultiLineString' ? g.coordinates : [];
		for (const l of ls) {
			const s = dp(l, TOL.borders);
			if (s.length >= 2) out.push(flat(s));
		}
	}
	return out;
}

const data = {
	_info: 'Natural Earth 1:50m (gemeinfrei), vereinfacht mit tools/world_map_data.mjs. Koordinaten: Länge/Breite × 100.',
	land: rings('ne_50m_land.geojson', 'land'),
	lakes: rings('ne_50m_lakes.geojson', 'lakes'),
	borders: lines('ne_50m_admin_0_boundary_lines_land.geojson'),
};
const outFile = path.join(ROOT, 'assets/map/world.json');
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, JSON.stringify(data));
const n = (a) => a.reduce((s, r) => s + r.length / 2, 0);
console.log(`land ${data.land.length} Ringe/${n(data.land)} Punkte, Seen ${data.lakes.length}/${n(data.lakes)}, Grenzen ${data.borders.length}/${n(data.borders)} -> ${outFile} (${fs.statSync(outFile).size} Bytes)`);
