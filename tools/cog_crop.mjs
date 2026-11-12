#!/usr/bin/env node
// Ausschnitt aus einem Cloud-Optimized GeoTIFF laden (per HTTP-Range, siehe tools/cog.mjs) – ohne GDAL, nur node + curl.
//
//   node tools/cog_crop.mjs URL E N HALB AUS.png [HELL]   RGB (8 Bit, z. B. Sentinel-2 TCI.tif) -> PNG, HELL = Faktor (1)
//   node tools/cog_crop.mjs URL E N HALB AUS.txt          1. Kanal als Text (z. B. Copernicus DEM, Höhen)
//
// E/N in den Koordinaten des GeoTIFFs (Sentinel-2: UTM der Kachel, Copernicus DEM: Länge/Breite in Grad),
// HALB = halbe Kantenlänge in denselben Einheiten.
// Beispiel Hip-Notics (Sentinel-2, UTM 36, Kachel 36SUF, 15.08.2025, wolkenfrei):
//   node tools/cog_crop.mjs https://sentinel-cogs.s3.us-west-2.amazonaws.com/sentinel-s2-l2a-cogs/36/S/UF/2025/8/S2A_36SUF_20250815_0_L2A/TCI.tif 339847 4086597 600 park.png 1.8
import fs from 'fs';
import { openCog } from './cog.mjs';
import { writePng } from './png.mjs';

const [url, E, N, H, out, gain = '1'] = process.argv.slice(2);
const cog = openCog(url);
const c0 = Math.floor((+E - +H - cog.x0) / cog.dx), c1 = Math.floor((+E + +H - cog.x0) / cog.dx);
const r0 = Math.floor((cog.y0 - (+N + +H)) / cog.dy), r1 = Math.floor((cog.y0 - (+N - +H)) / cog.dy);
const w = c1 - c0, h = r1 - r0;
if (out.endsWith('.txt')) {
	let s = '';
	for (let r = r0; r < r1; r++) {
		const row = [];
		for (let c = c0; c < c1; c++) row.push(cog.px(c, r).toFixed(1));
		s += row.join(' ') + '\n';
	}
	fs.writeFileSync(out, s);
} else {
	const rgb = Buffer.alloc(w * h * 3);
	for (let r = r0; r < r1; r++) for (let c = c0; c < c1; c++) for (let k = 0; k < 3; k++)
		rgb[((r - r0) * w + (c - c0)) * 3 + k] = Math.min(255, cog.px(c, r, k) * +gain);
	writePng(out, w, h, rgb);
}
console.log(`ok: ${w} x ${h} -> ${out}`);
