// Cloud-Optimized GeoTIFF (gekachelt, Deflate/ohne) per HTTP-Range lesen – ohne GDAL, nur node + curl.
// Lädt nur die Kacheln, die gebraucht werden. Unterstützt 8/16 Bit Ganzzahl und 32 Bit Float, 1..n Kanäle,
// Prädiktor 1/2/3. Verwendet von tools/cog_crop.mjs und tools/park_geo.mjs.
import { execFileSync } from 'child_process';
import zlib from 'zlib';

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

/** COG öffnen: liefert Kopfdaten und px(c, r, k) = Wert von Kanal k an Spalte c / Zeile r. */
export function openCog(url) {
	const get = (a, b) => execFileSync('curl', ['-sS', '-f', '-r', `${a}-${b - 1}`, url], { maxBuffer: 1 << 28 });
	const head = get(0, 1 << 20);
	const t = readIfd(head, head.readUInt32LE(4));
	const W = t[256][0], H = t[257][0], TW = t[322][0], TH = t[323][0], O = t[324], C = t[325];
	const comp = t[259][0], pred = (t[317] || [1])[0], spp = (t[277] || [1])[0], bps = t[258][0];
	const fmt = (t[339] || [1])[0];                           // 1 = Ganzzahl, 3 = Float
	const x0 = t[33922][3], y0 = t[33922][4], dx = t[33550][0], dy = t[33550][1];
	const bytes = bps / 8, tpr = Math.ceil(W / TW), cache = new Map();

	function tile(ti) {
		if (cache.has(ti)) return cache.get(ti);
		let d = Buffer.from(get(O[ti], O[ti] + C[ti]));
		if (comp === 8 || comp === 32946) d = Buffer.from(zlib.inflateSync(d));
		const row = TW * spp * bytes;
		if (pred === 2) {                                     // horizontale Differenz je Kanal
			for (let y = 0; y < TH; y++) for (let x = 1; x < TW; x++) for (let k = 0; k < spp; k++) {
				const i = (y * TW + x) * spp + k, j = i - spp;
				if (bytes === 1) d[i] = (d[i] + d[j]) & 255;
				else if (bytes === 2) d.writeUInt16LE((d.readUInt16LE(i * 2) + d.readUInt16LE(j * 2)) & 0xffff, i * 2);
			}
		} else if (pred === 3) {                              // Gleitkomma-Prädiktor (Bytes je Zeile umsortiert)
			const o = Buffer.alloc(d.length);
			for (let y = 0; y < TH; y++) {
				const r = d.subarray(y * row, (y + 1) * row);
				for (let i = 1; i < r.length; i++) r[i] = (r[i] + r[i - 1]) & 255;
				const n = TW * spp;
				for (let x = 0; x < n; x++) for (let k = 0; k < bytes; k++) o[y * row + x * bytes + k] = r[(bytes - 1 - k) * n + x];
			}
			d = o;
		}
		cache.set(ti, d);
		return d;
	}

	function px(c, r, k = 0) {
		c = Math.max(0, Math.min(W - 1, c));
		r = Math.max(0, Math.min(H - 1, r));
		const d = tile(Math.floor(r / TH) * tpr + Math.floor(c / TW));
		const i = (((r % TH) * TW + (c % TW)) * spp + k) * bytes;
		if (bytes === 1) return d[i];
		if (bytes === 2) return d.readUInt16LE(i);
		return fmt === 3 ? d.readFloatLE(i) : d.readUInt32LE(i);
	}

	/** Wert an Koordinate (x, y) im Bezugssystem des GeoTIFFs, bilinear. */
	function at(x, y, k = 0) {
		const fc = (x - x0) / dx - 0.5, fr = (y0 - y) / dy - 0.5;
		const c = Math.floor(fc), r = Math.floor(fr), tx = fc - c, ty = fr - r;
		const a = px(c, r, k) * (1 - tx) + px(c + 1, r, k) * tx;
		const b = px(c, r + 1, k) * (1 - tx) + px(c + 1, r + 1, k) * tx;
		return a * (1 - ty) + b * ty;
	}

	return { W, H, TW, TH, spp, bps, x0, y0, dx, dy, px, at };
}
