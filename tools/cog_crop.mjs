#!/usr/bin/env node
// Ausschnitt aus einem Cloud-Optimized GeoTIFF (gekachelt, Deflate) per HTTP-Range laden – ohne GDAL, nur node + curl.
// Lädt nur die Kacheln, die der Ausschnitt braucht (Sentinel-2-Kachel ~100 MB, Ausschnitt wenige 100 kB).
//
//   node tools/cog_crop.mjs URL E N HALB AUS.png [HELL]   RGB (8 Bit, z. B. Sentinel-2 TCI.tif) -> PNG, HELL = Faktor (1)
//   node tools/cog_crop.mjs URL E N HALB AUS.txt          1 Kanal Float32 (z. B. Copernicus DEM) -> Höhen als Text
//
// E/N in den Koordinaten des GeoTIFFs (Sentinel-2: UTM der Kachel, Copernicus DEM: Länge/Breite in Grad),
// HALB = halbe Kantenlänge in denselben Einheiten.
// Beispiel Hip-Notics (Sentinel-2, UTM 36, Kachel 36SUF, 15.08.2025, wolkenfrei):
//   node tools/cog_crop.mjs https://sentinel-cogs.s3.us-west-2.amazonaws.com/sentinel-s2-l2a-cogs/36/S/UF/2025/8/S2A_36SUF_20250815_0_L2A/TCI.tif 339847 4086597 600 park.png 1.8
import { execFileSync } from 'child_process';
import zlib from 'zlib';
import fs from 'fs';

const [url, E, N, H, out, gain = '1'] = process.argv.slice(2);
const get = (a, b) => execFileSync('curl', ['-sS', '-r', `${a}-${b - 1}`, url], { maxBuffer: 1 << 28 });

function readIfd(b, off) {
	const n = b.readUInt16LE(off), t = {};
	for (let i = 0; i < n; i++) {
		const e = off + 2 + i * 12, tag = b.readUInt16LE(e), ty = b.readUInt16LE(e + 2), c = b.readUInt32LE(e + 4);
		const sz = { 1: 1, 2: 1, 3: 2, 4: 4, 12: 8, 16: 8 }[ty] || 1;
		const p = c * sz > 4 ? b.readUInt32LE(e + 8) : e + 8;
		const v = [];
		for (let k = 0; k < c; k++) {
			v.push(ty === 3 ? b.readUInt16LE(p + k * 2) : ty === 4 ? b.readUInt32LE(p + k * 4) : ty === 12 ? b.readDoubleLE(p + k * 8)
				: ty === 16 ? Number(b.readBigUInt64LE(p + k * 8)) : b[p + k]);
		}
		t[tag] = v;
	}
	return t;
}

const head = get(0, 1 << 20);
const t = readIfd(head, head.readUInt32LE(4));
const W = t[256][0], TW = t[322][0], TH = t[323][0], O = t[324], C = t[325];
const comp = t[259][0], pred = (t[317] || [1])[0], spp = (t[277] || [1])[0], bps = t[258][0];
const x0 = t[33922][3], y0 = t[33922][4], dx = t[33550][0], dy = t[33550][1];
const c0 = Math.floor((+E - +H - x0) / dx), c1 = Math.floor((+E + +H - x0) / dx);
const r0 = Math.floor((y0 - (+N + +H)) / dy), r1 = Math.floor((y0 - (+N - +H)) / dy);
const w = c1 - c0, h = r1 - r0, tpr = Math.ceil(W / TW), cache = {};
const bpp = spp * bps / 8;

function tile(ti) {
	if (cache[ti]) return cache[ti];
	let d = get(O[ti], O[ti] + C[ti]);
	if (comp === 8 || comp === 32946) d = Buffer.from(zlib.inflateSync(d));
	if (pred === 2) {                                   // horizontale Differenz (8 Bit)
		for (let y = 0; y < TH; y++) for (let x = 1; x < TW; x++) for (let k = 0; k < spp; k++) {
			const i = (y * TW + x) * spp + k;
			d[i] = (d[i] + d[i - spp]) & 255;
		}
	} else if (pred === 3) {                            // Gleitkomma-Prädiktor (Float32)
		const o = Buffer.alloc(d.length);
		for (let y = 0; y < TH; y++) {
			const row = d.subarray(y * TW * 4, (y + 1) * TW * 4);
			for (let i = 1; i < row.length; i++) row[i] = (row[i] + row[i - 1]) & 255;
			for (let x = 0; x < TW; x++) for (let k = 0; k < 4; k++) o[(y * TW + x) * 4 + k] = row[(3 - k) * TW + x];
		}
		d = o;
	}
	return (cache[ti] = d);
}
function px(c, r) {
	const d = tile(Math.floor(r / TH) * tpr + Math.floor(c / TW));
	return [d, ((r % TH) * TW + (c % TW)) * bpp];
}

if (out.endsWith('.txt')) {
	let s = '';
	for (let r = r0; r < r1; r++) {
		const row = [];
		for (let c = c0; c < c1; c++) { const [d, i] = px(c, r); row.push(d.readFloatLE(i).toFixed(1)); }
		s += row.join(' ') + '\n';
	}
	fs.writeFileSync(out, s);
} else {
	const raw = Buffer.alloc((w * 3 + 1) * h);
	for (let r = r0; r < r1; r++) for (let c = c0; c < c1; c++) {
		const [d, i] = px(c, r);
		for (let k = 0; k < 3; k++) raw[(r - r0) * (w * 3 + 1) + 1 + (c - c0) * 3 + k] = Math.min(255, d[i + k] * +gain);
	}
	const crc = (buf) => { let cr = ~0; for (const v of buf) { let c = (cr ^ v) & 255; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; cr = (cr >>> 8) ^ c; } return ~cr >>> 0; };
	const chunk = (ty, dt) => { const l = Buffer.alloc(4); l.writeUInt32BE(dt.length); const td = Buffer.concat([Buffer.from(ty), dt]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
	const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2;
	fs.writeFileSync(out, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih),
		chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}
console.log(`ok: ${w} x ${h} -> ${out}`);
