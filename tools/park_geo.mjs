#!/usr/bin/env node
// Geodaten eines Wakeparks aus freien Quellen erzeugen (für Parks ohne amtliche Geodaten wie in Hessen):
//   - Gelände: Copernicus DEM GLO-30 (30 m, Oberflächenmodell) – nur für die Umgebung (Hügel), weich ausgeblendet
//   - Uferlinie: Sentinel-2 L2A, Wasserindex NDWI aus Grün (B03) und Nahinfrarot (B08), 10 m, bilinear auf 1 m
//     verfeinert -> Seen mit flachem Ufer und Tiefe "lake_depth"
//   - Bäume (canopy): Sentinel-2 Vegetationsindex NDVI (B04/B08), nur abseits der Seen
//   - Luftbild: Sentinel-2 Echtfarben (TCI), aufgehellt
// Quellen und Masten stehen in parks/<id>/geo_quelle.json. Ausgabe wie tools/fetch_geodata.mjs (siehe dort) nach
// parks/<id>/geo/: terrain.bin, canopy.bin, geo.json und dop_wide.png / dop_core.png (danach mit Godot in JPG
// umwandeln: tools/png_to_jpg.gd, siehe Ausgabe am Ende).
//
//   node tools/park_geo.mjs hipnotics
//
// Lizenzen: Copernicus DEM © DLR e.V. 2014–2018 und © Airbus Defence and Space GmbH 2018, bereitgestellt im Rahmen von
// COPERNICUS durch die EU und ESA; Sentinel-2: „Contains modified Copernicus Sentinel data“ (frei).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { openCog } from './cog.mjs';
import { writePng } from './png.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = process.argv[2];
const dir = path.join(ROOT, 'parks', id);
const Q = JSON.parse(fs.readFileSync(path.join(dir, 'geo_quelle.json'), 'utf8'));
const OUT = path.join(dir, 'geo');
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- UTM (WGS84)
const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996, n = f / (2 - f);
const A = (a / (1 + n)) * (1 + n * n / 4 + n ** 4 / 64);
const alpha = [n / 2 - (2 / 3) * n * n + (5 / 16) * n ** 3, (13 / 48) * n * n - (3 / 5) * n ** 3, (61 / 240) * n ** 3];
const lon0 = (Q.utm_zone - 1) * 6 - 180 + 3;
function toUtm(lat, lon) {
	const phi = lat * Math.PI / 180, lam = (lon - lon0) * Math.PI / 180, e = Math.sqrt(f * (2 - f));
	const t = Math.sinh(Math.atanh(Math.sin(phi)) - e * Math.atanh(e * Math.sin(phi)));
	const xi = Math.atan(t / Math.cos(lam)), eta = Math.atanh(Math.sin(lam) / Math.sqrt(1 + t * t));
	let E = eta, N = xi;
	for (let j = 1; j <= 3; j++) {
		E += alpha[j - 1] * Math.cos(2 * j * xi) * Math.sinh(2 * j * eta);
		N += alpha[j - 1] * Math.sin(2 * j * xi) * Math.cosh(2 * j * eta);
	}
	return [500000 + k0 * A * E, k0 * A * N];
}

const masts = Object.fromEntries(Object.entries(Q.masts).map(([k, v]) => [k, toUtm(v[0], v[1])]));
const [OE, ON] = masts[Q.origin].map(Math.round);
const AREA = { e0: OE - Q.area.west, e1: OE + Q.area.east, n0: ON - Q.area.south, n1: ON + Q.area.north };
const W = AREA.e1 - AREA.e0, H = AREA.n1 - AREA.n0;
const CORE = { e0: OE - Q.core, e1: OE + Q.core, n0: ON - Q.core, n1: ON + Q.core };

// UTM -> Länge/Breite linear um die Gebietsmitte (auf 1 km genauer als 0,1 m)
const [mlat, mlon] = Q.masts[Q.origin];
const d = 1e-4;
const p0 = toUtm(mlat, mlon), pa = toUtm(mlat + d, mlon), po = toUtm(mlat, mlon + d);
const J = [[(po[0] - p0[0]) / d, (pa[0] - p0[0]) / d], [(po[1] - p0[1]) / d, (pa[1] - p0[1]) / d]];   // dE,dN je dLon,dLat
const det = J[0][0] * J[1][1] - J[0][1] * J[1][0];
function toLonLat(e, nn) {
	const de = e - p0[0], dn = nn - p0[1];
	return [mlon + (J[1][1] * de - J[0][1] * dn) / det, mlat + (-J[1][0] * de + J[0][0] * dn) / det];
}

console.log(`Gebiet ${W} x ${H} m, Ursprung ${Q.origin} ${OE}/${ON}`);
const dem = openCog(Q.dem);
const band = (b) => openCog(Q.sentinel + b + '.tif');
const B03 = band('B03'), B04 = band('B04'), B08 = band('B08'), TCI = band('TCI');

// ---------------------------------------------------------------- Raster 1 m
const N1 = W * H;
const demRel = new Float32Array(N1);
const wet = new Uint8Array(N1);
const ndvi = new Float32Array(N1);
for (let r = 0; r < H; r++) {
	const nn = AREA.n1 - r - 0.5;
	for (let c = 0; c < W; c++) {
		const e = AREA.e0 + c + 0.5, i = r * W + c;
		const [lo, la] = toLonLat(e, nn);
		demRel[i] = dem.at(lo, la);
		const g = B03.at(e, nn), rd = B04.at(e, nn), ir = B08.at(e, nn);
		wet[i] = (g - ir) / Math.max(g + ir, 1) > Q.ndwi ? 1 : 0;
		ndvi[i] = (ir - rd) / Math.max(ir + rd, 1);
	}
	if (r % 200 === 0) console.log(`  Zeile ${r}/${H}`);
}

// kleine Wasserflecken weg (Pools, Pfützen), kleine Inseln im See bleiben
function components(mask, val) {
	const lab = new Int32Array(N1).fill(-1), sizes = [];
	for (let s = 0; s < N1; s++) {
		if (mask[s] !== val || lab[s] >= 0) continue;
		const id = sizes.length, st = [s];
		lab[s] = id;
		let cnt = 0;
		while (st.length) {
			const p = st.pop();
			cnt++;
			const x = p % W, y = (p - x) / W;
			for (const [qx, qy] of [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]) {
				if (qx < 0 || qy < 0 || qx >= W || qy >= H) continue;
				const q = qy * W + qx;
				if (mask[q] === val && lab[q] < 0) { lab[q] = id; st.push(q); }
			}
		}
		sizes.push(cnt);
	}
	return { lab, sizes };
}
{
	const { lab, sizes } = components(wet, 1);
	// nur Seen an den Masten bzw. an "lake_seeds" (Länge/Breite) – sonst kommen Gewächshäuser und Kanäle mit
	const keep = new Set();
	const seeds = Object.values(masts).concat((Q.lake_seeds || []).map(([la, lo]) => toUtm(la, lo)));
	for (const [e, nn] of seeds) {
		const c0 = Math.round(e - AREA.e0), r0 = Math.round(AREA.n1 - nn);
		let best = -1, bd = 60 * 60;
		for (let y = -60; y <= 60; y++) for (let x = -60; x <= 60; x++) {
			const c = c0 + x, r = r0 + y;
			if (c < 0 || r < 0 || c >= W || r >= H || !wet[r * W + c]) continue;
			if (x * x + y * y < bd) { bd = x * x + y * y; best = lab[r * W + c]; }
		}
		if (best >= 0) keep.add(best);
	}
	for (let i = 0; i < N1; i++) if (wet[i] && (sizes[lab[i]] < Q.min_lake || !keep.has(lab[i]))) wet[i] = 0;
	console.log(`Seen: ${[...keep].map((k) => sizes[k] + ' m²').join(', ')}`);
}

// Abstand zum Ufer (Chamfer 3-4, in Metern), innen und außen
function distance(inside) {
	const D = new Float32Array(N1).fill(1e9);
	for (let i = 0; i < N1; i++) if (wet[i] !== inside) D[i] = 0;
	const s = 1, dg = Math.SQRT2;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
		const i = y * W + x;
		if (x > 0) D[i] = Math.min(D[i], D[i - 1] + s);
		if (y > 0) {
			D[i] = Math.min(D[i], D[i - W] + s);
			if (x > 0) D[i] = Math.min(D[i], D[i - W - 1] + dg);
			if (x < W - 1) D[i] = Math.min(D[i], D[i - W + 1] + dg);
		}
	}
	for (let y = H - 1; y >= 0; y--) for (let x = W - 1; x >= 0; x--) {
		const i = y * W + x;
		if (x < W - 1) D[i] = Math.min(D[i], D[i + 1] + s);
		if (y < H - 1) {
			D[i] = Math.min(D[i], D[i + W] + s);
			if (x < W - 1) D[i] = Math.min(D[i], D[i + W + 1] + dg);
			if (x > 0) D[i] = Math.min(D[i], D[i + W - 1] + dg);
		}
	}
	return D;
}
const din = distance(1), dout = distance(0);

// Wasserspiegel = Mittel des Oberflächenmodells über den Seen (Wasser ist dort die Oberfläche)
let ws = 0, wn = 0;
for (let i = 0; i < N1; i++) if (wet[i] && din[i] > 8) { ws += demRel[i]; wn++; }
const WATER = wn ? ws / wn : 0;
console.log(`Wasserspiegel ${WATER.toFixed(2)} m (aus ${wn} Punkten)`);

const sm = (e0, e1, x) => { const t = Math.min(Math.max((x - e0) / (e1 - e0), 0), 1); return t * t * (3 - 2 * t); };
const height = new Float32Array(N1);
for (let i = 0; i < N1; i++) {
	if (wet[i]) {
		height[i] = -Math.min(Q.lake_depth, 0.12 + din[i] * 0.45);          // flaches Ufer, dann eben
	} else {
		// am See ein flacher Parkrasen (0,45 m über dem Wasser), weiter weg das Gelände aus dem DEM
		const park = 0.15 + Math.min(dout[i] * 0.15, 0.3);
		const far = Math.max(demRel[i] - WATER, 0.3);
		height[i] = park + (far - park) * sm(60, 160, dout[i]);
	}
}
// am Rand des Datengebiets (letzte 80 m) sanft auf die Höhe des Ferngrunds (2 m, terrain.gd) auslaufen
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
	const edge = Math.min(r, c, H - 1 - r, W - 1 - c);
	if (edge < 80) { const i = r * W + c; height[i] = 2.0 + (height[i] - 2.0) * sm(0, 80, edge); }
}
const terrain = Buffer.alloc(N1 * 2);
// Format: (Höhe + 20) * 1000 als uint16 -> höchstens 45,5 m über dem Wasser; Hügel darüber weich gekappt
const cap = (h) => h < 35 ? h : 35 + 10 * Math.tanh((h - 35) / 10);
for (let i = 0; i < N1; i++) terrain.writeUInt16LE(Math.round((cap(height[i]) + 20) * 1000), i * 2);
fs.writeFileSync(path.join(OUT, 'terrain.bin'), terrain);

// Bäume: 2 m Raster aus NDVI (Obstplantagen, Hecken), nicht am See (Parkrasen) und nicht im Wasser
const CW = W / 2, CH = H / 2;
const canopy = Buffer.alloc(CW * CH);
for (let r = 0; r < CH; r++) for (let c = 0; c < CW; c++) {
	const i = (r * 2) * W + c * 2;
	if (wet[i] || dout[i] < 25) continue;
	const v = ndvi[i];
	if (v > 0.55) canopy[r * CW + c] = Math.round(Math.min(3 + (v - 0.55) * 30, 9) / 0.2);
}

// Luftbilder aus Sentinel-2 Echtfarben (aufgehellt), Seeboden hell türkis
function dop(rect, mpp, file) {
	const w = Math.round((rect.e1 - rect.e0) / mpp), h = Math.round((rect.n1 - rect.n0) / mpp);
	const rgb = Buffer.alloc(w * h * 3);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		const e = rect.e0 + (x + 0.5) * mpp, nn = rect.n1 - (y + 0.5) * mpp;
		const c = Math.floor(e - AREA.e0), r = Math.floor(AREA.n1 - nn);
		const inside = c >= 0 && r >= 0 && c < W && r < H;
		const water = inside && wet[r * W + c];
		for (let k = 0; k < 3; k++) {
			let v = TCI.at(e, nn, k) * 1.15;
			if (water) v = [150, 205, 200][k] * 0.8 + v * 0.2;
			rgb[(y * w + x) * 3 + k] = Math.max(0, Math.min(255, v));
		}
	}
	writePng(path.join(OUT, file), w, h, rgb);
	return [w, h];
}
const wide = dop(AREA, 0.5, 'dop_wide.png');
const core = dop(CORE, 0.25, 'dop_core.png');
fs.writeFileSync(path.join(OUT, 'canopy.bin'), canopy);

// Kontrollbild der Uferlinie (für tools/../recherche, nicht im Spiel)
const chk = Buffer.alloc(W * H * 3);
for (let i = 0; i < N1; i++) {
	const v = wet[i] ? [40, 120, 200] : canopy[Math.floor(i / W / 2) * CW + Math.floor((i % W) / 2)] ? [40, 110, 40] : [150, 140, 110];
	chk[i * 3] = v[0]; chk[i * 3 + 1] = v[1]; chk[i * 3 + 2] = v[2];
}
for (const [k, [e, nn]] of Object.entries(masts)) {
	const c = Math.round(e - AREA.e0), r = Math.round(AREA.n1 - nn);
	for (let y = -3; y <= 3; y++) for (let x = -3; x <= 3; x++) {
		const q = (r + y) * W + c + x;
		if (q >= 0 && q < N1) { chk[q * 3] = 255; chk[q * 3 + 1] = k.startsWith('l2') ? 200 : 40; chk[q * 3 + 2] = 40; }
	}
}
fs.mkdirSync(path.join(dir, 'recherche'), { recursive: true });
writePng(path.join(dir, 'recherche', 'ufer_kontrolle.png'), W, H, chk);

const meta = {
	source: 'Copernicus DEM GLO-30, Sentinel-2 L2A (NDWI/NDVI/TCI) – tools/park_geo.mjs',
	water_level: +WATER.toFixed(2),
	area: { ...AREA, w: W, h: H },
	core: CORE,
	canopy: { w: CW, h: CH, step: 2 },
	masts: Object.fromEntries(Object.entries(masts).map(([k, v]) => [k, [+v[0].toFixed(2), +v[1].toFixed(2)]])),
};
fs.writeFileSync(path.join(OUT, 'geo.json'), JSON.stringify(meta, null, 2));
for (const [k, [e, nn]] of Object.entries(masts)) {
	const i = Math.round(AREA.n1 - nn) * W + Math.round(e - AREA.e0);
	console.log(`  Mast ${k}: ${wet[i] ? 'im Wasser' : 'an Land'}, Ufer ${(wet[i] ? din[i] : dout[i]).toFixed(1)} m`);
}
console.log(`fertig: dop_wide ${wide.join('x')}, dop_core ${core.join('x')} -> ${OUT}`);
console.log(`JPG: Godot --headless --path . -s tools/png_to_jpg.gd -- ${path.relative(ROOT, OUT)}`);
