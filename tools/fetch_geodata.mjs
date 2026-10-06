// Lädt die echten Geodaten für den Raunheimer Waldsee und schreibt sie nach assets/geo/.
// Quelle: Hessische Verwaltung für Bodenmanagement und Geoinformation (HVBG),
// offene Geobasisdaten Hessen (DGM1, DOM1, DOP20) – Nutzung ohne Einschränkung (§ 18 HVGG).
//
// Aufruf (im Ordner tools):  node fetch_geodata.mjs
//
// Ergebnis:
//   terrain.bin  uint16 LE, 1 m Raster, Zeile 0 = Norden, Spalte 0 = Westen.
//                Wert = (Höhe über Wasserspiegel + 20 m) * 1000. Seeboden ist bereits eingerechnet.
//   canopy.bin   uint8, 2 m Raster, Vegetations-/Objekthöhe (DOM - DGM) in 0,2 m Schritten
//   dop_wide.jpg Luftbild des ganzen Gebiets (0,5 m/px)
//   dop_core.jpg Luftbild rund um die Anlage (0,2 m/px)
//   geo.json     Metadaten (UTM-Ausschnitte, Wasserspiegel, Mastpositionen)
import fs from 'node:fs';
import path from 'node:path';
import { toUtm32 } from './utm.mjs';

const OUT = path.resolve('..', 'assets', 'geo');
fs.mkdirSync(OUT, { recursive: true });

const MASTS = {
  t2_start: [50.012196451207686, 8.47727028633737],
  t2_end: [50.01233983457297, 8.480018702962983],
  t1_start: [50.01191123180912, 8.47721790384666],
  t1_end: [50.01203107847806, 8.480067458337382],
};
const masts = Object.fromEntries(Object.entries(MASTS).map(([k, v]) => [k, toUtm32(...v)]));
const [OE, ON] = masts.t2_start.map(Math.round);

// Gesamtgebiet (ganzer See + Wald drumherum), ganzzahlige UTM-Meter
const AREA = { e0: OE - 260, e1: OE + 780, n0: ON - 240, n1: ON + 640 };
const W = AREA.e1 - AREA.e0;
const H = AREA.n1 - AREA.n0;
// hochaufgelöster Ausschnitt um den Strand
const CORE = { e0: OE - 100, e1: OE + 100, n0: ON - 100, n1: ON + 100 };

const WCS = (cov, id) => `https://inspire-hessen.de/raster/${cov}/ows?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=${id}`;
const WMS = 'https://www.gds-srv.hessen.de/cgi-bin/lika-services/ogc-free-images.ows?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&LAYERS=he_dop20_rgb&STYLES=&SRS=EPSG:25832&FORMAT=image/jpeg';

async function fetchRetry(url, tries = 4) {
  for (let i = 0; ; i++) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': 'wakeport-game/1.0' } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r;
    } catch (e) {
      if (i >= tries) throw e;
      await new Promise((res) => setTimeout(res, 2000 * (i + 1)));
    }
  }
}

// Raster als Float32Array [row (Nord->Süd)][col (West->Ost)], Kachelweise geladen.
async function fetchRaster(cov, id, step) {
  const w = W / step, h = H / step;
  const out = new Float32Array(w * h);
  const T = 200;
  for (let te = AREA.e0; te < AREA.e1; te += T) {
    for (let tn = AREA.n0; tn < AREA.n1; tn += T) {
      const e1 = Math.min(te + T, AREA.e1), n1 = Math.min(tn + T, AREA.n1);
      const url = `${WCS(cov, id)}&SUBSET=E(${te},${e1})&SUBSET=N(${tn},${n1})&FORMAT=application/json`;
      const data = await (await fetchRetry(url)).json();
      // data[iE][iN]: iE West->Ost, iN Nord->Süd (jeweils in Schritten von `step`)
      for (let i = 0; i < data.length; i++) {
        const col = (te - AREA.e0) / step + i;
        for (let j = 0; j < data[i].length; j++) {
          const row = (AREA.n1 - n1) / step + j;
          if (col < w && row < h) out[row * w + col] = data[i][j];
        }
      }
      process.stdout.write('.');
    }
  }
  process.stdout.write('\n');
  return { data: out, w, h };
}

console.log('DGM1 (Gelände) ...');
const dgm = await fetchRaster('dgm1', 'he_dgm1', 1);

// Wasserspiegel: häufigster Höhenwert (10-cm-Klassen) entlang der T2-Seillinie
const idx = (e, n) => (AREA.n1 - 1 - Math.floor(n)) * W + Math.floor(e - AREA.e0);
const samples = [];
for (let t = 0.3; t <= 0.9; t += 0.01) {
  const e = masts.t2_start[0] + (masts.t2_end[0] - masts.t2_start[0]) * t;
  const n = masts.t2_start[1] + (masts.t2_end[1] - masts.t2_start[1]) * t;
  samples.push(dgm.data[idx(e, n)]);
}
samples.sort((a, b) => a - b);
const waterLevel = samples[Math.floor(samples.length / 2)];
console.log('Wasserspiegel', waterLevel.toFixed(2), 'm ü. NHN');

// See-Maske per Flood-Fill ab der Seemitte (Zellen höchstens 12 cm über dem Wasserspiegel)
const water = new Uint8Array(W * H);
{
  const e = (masts.t2_start[0] + masts.t2_end[0]) / 2, n = (masts.t2_start[1] + masts.t2_end[1]) / 2;
  const stack = [idx(e, n)];
  while (stack.length) {
    const k = stack.pop();
    if (water[k] || dgm.data[k] > waterLevel + 0.12) continue;
    water[k] = 1;
    const r = Math.floor(k / W), c = k % W;
    if (c > 0) stack.push(k - 1);
    if (c < W - 1) stack.push(k + 1);
    if (r > 0) stack.push(k - W);
    if (r < H - 1) stack.push(k + W);
  }
}

// Kleine "Inseln" im See sind schwimmende Hindernisse, Stege oder Mastfundamente aus der
// Laservermessung – die werden im Spiel eigens modelliert, also hier zu Wasser machen.
{
  const seen = new Uint8Array(W * H);
  for (let k0 = 0; k0 < W * H; k0++) {
    if (water[k0] || seen[k0]) continue;
    const comp = [];
    let touchesBorder = false;
    const stack = [k0];
    seen[k0] = 1;
    while (stack.length && comp.length <= 400) {
      const k = stack.pop();
      comp.push(k);
      const r = Math.floor(k / W), c = k % W;
      if (r === 0 || c === 0 || r === H - 1 || c === W - 1) touchesBorder = true;
      for (const nk of [c > 0 ? k - 1 : -1, c < W - 1 ? k + 1 : -1, r > 0 ? k - W : -1, r < H - 1 ? k + W : -1]) {
        if (nk >= 0 && !water[nk] && !seen[nk]) { seen[nk] = 1; stack.push(nk); }
      }
    }
    if (comp.length <= 400 && !touchesBorder && stack.length === 0) {
      for (const k of comp) water[k] = 1;
    } else {
      // große Landfläche: restliche Zellen nur noch als gesehen markieren
      while (stack.length) {
        const k = stack.pop();
        const r = Math.floor(k / W), c = k % W;
        for (const nk of [c > 0 ? k - 1 : -1, c < W - 1 ? k + 1 : -1, r > 0 ? k - W : -1, r < H - 1 ? k + W : -1]) {
          if (nk >= 0 && !water[nk] && !seen[nk]) { seen[nk] = 1; stack.push(nk); }
        }
      }
    }
  }
}

// Abstand zum Ufer (für den Seeboden), zweifacher Chamfer-Durchlauf
const dist = new Float32Array(W * H).fill(1e9);
for (let k = 0; k < W * H; k++) if (!water[k]) dist[k] = 0;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const k = r * W + c;
  if (c > 0) dist[k] = Math.min(dist[k], dist[k - 1] + 1);
  if (r > 0) dist[k] = Math.min(dist[k], dist[k - W] + 1);
  if (c > 0 && r > 0) dist[k] = Math.min(dist[k], dist[k - W - 1] + 1.414);
  if (c < W - 1 && r > 0) dist[k] = Math.min(dist[k], dist[k - W + 1] + 1.414);
}
for (let r = H - 1; r >= 0; r--) for (let c = W - 1; c >= 0; c--) {
  const k = r * W + c;
  if (c < W - 1) dist[k] = Math.min(dist[k], dist[k + 1] + 1);
  if (r < H - 1) dist[k] = Math.min(dist[k], dist[k + W] + 1);
  if (c < W - 1 && r < H - 1) dist[k] = Math.min(dist[k], dist[k + W + 1] + 1.414);
  if (c > 0 && r < H - 1) dist[k] = Math.min(dist[k], dist[k + W - 1] + 1.414);
}

const terrain = new Uint16Array(W * H);
let maxY = -99, minY = 99;
for (let k = 0; k < W * H; k++) {
  let y = dgm.data[k] - waterLevel;
  if (water[k]) y = -Math.min(0.6 + dist[k] * 0.35, 12.0); // Baggersee: steile Uferkante
  else y = Math.max(y, 0.05);                               // Land nie unter Wasserniveau
  maxY = Math.max(maxY, y); minY = Math.min(minY, y);
  terrain[k] = Math.round(Math.min(Math.max((y + 20) * 1000, 0), 65535));
}
fs.writeFileSync(path.join(OUT, 'terrain.bin'), Buffer.from(terrain.buffer));
console.log('terrain.bin', W, 'x', H, 'y', minY.toFixed(1), '..', maxY.toFixed(1));

console.log('DOM1 (Oberfläche inkl. Bäume) ...');
const dom = await fetchRaster('dom1', 'dom1_2', 2);
const cw = W / 2, ch = H / 2;
const canopy = new Uint8Array(cw * ch);
for (let r = 0; r < ch; r++) for (let c = 0; c < cw; c++) {
  const g = dgm.data[(r * 2) * W + c * 2];
  const v = (dom.data[r * cw + c] - g) / 0.2;
  canopy[r * cw + c] = Math.max(0, Math.min(255, Math.round(v)));
}
fs.writeFileSync(path.join(OUT, 'canopy.bin'), Buffer.from(canopy.buffer));

console.log('DOP20 (Luftbilder) ...');
async function fetchDop(a, mpp, file) {
  const url = `${WMS}&BBOX=${a.e0},${a.n0},${a.e1},${a.n1}&WIDTH=${(a.e1 - a.e0) / mpp}&HEIGHT=${(a.n1 - a.n0) / mpp}`;
  const buf = Buffer.from(await (await fetchRetry(url)).arrayBuffer());
  fs.writeFileSync(path.join(OUT, file), buf);
  console.log(file, (buf.length / 1e6).toFixed(1), 'MB');
}
await fetchDop(AREA, 0.5, 'dop_wide.jpg');
await fetchDop(CORE, 0.2, 'dop_core.jpg');

fs.writeFileSync(path.join(OUT, 'geo.json'), JSON.stringify({
  source: 'Geobasisdaten Hessen (HVBG): DGM1, DOM1, DOP20',
  water_level: waterLevel,
  area: { ...AREA, w: W, h: H },
  core: CORE,
  canopy: { w: cw, h: ch, step: 2 },
  masts: Object.fromEntries(Object.entries(masts).map(([k, v]) => [k, [+v[0].toFixed(2), +v[1].toFixed(2)]])),
}, null, 2));
console.log('fertig ->', OUT);
