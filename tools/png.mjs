// PNG schreiben (RGB, 8 Bit) – ohne Bibliotheken, nur node (zlib).
import fs from 'fs';
import zlib from 'zlib';

const TABLE = new Int32Array(256).map((_, n) => {
	let c = n;
	for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
	return c;
});
function crc(buf) {
	let c = ~0;
	for (const v of buf) c = TABLE[(c ^ v) & 255] ^ (c >>> 8);
	return ~c >>> 0;
}
function chunk(type, data) {
	const l = Buffer.alloc(4);
	l.writeUInt32BE(data.length);
	const td = Buffer.concat([Buffer.from(type), data]);
	const c = Buffer.alloc(4);
	c.writeUInt32BE(crc(td));
	return Buffer.concat([l, td, c]);
}

/** rgb: Buffer w*h*3, Zeile 0 = oben. */
export function writePng(file, w, h, rgb) {
	const raw = Buffer.alloc((w * 3 + 1) * h);
	for (let y = 0; y < h; y++) rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
	const ih = Buffer.alloc(13);
	ih.writeUInt32BE(w, 0);
	ih.writeUInt32BE(h, 4);
	ih[8] = 8;
	ih[9] = 2;
	fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih),
		chunk('IDAT', zlib.deflateSync(raw, { level: 6 })), chunk('IEND', Buffer.alloc(0))]));
}
