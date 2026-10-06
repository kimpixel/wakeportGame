// WGS84/ETRS89 (Breite/Länge) -> UTM Zone 32N (EPSG:25832), Genauigkeit ~mm.
const a = 6378137.0;
const f = 1 / 298.257222101; // GRS80
const k0 = 0.9996;
const n = f / (2 - f);
const A = (a / (1 + n)) * (1 + n * n / 4 + n ** 4 / 64);
const alpha = [
  n / 2 - (2 / 3) * n * n + (5 / 16) * n ** 3,
  (13 / 48) * n * n - (3 / 5) * n ** 3,
  (61 / 240) * n ** 3,
];

export function toUtm32(lat, lon) {
  const lon0 = 9 * Math.PI / 180;
  const phi = lat * Math.PI / 180;
  const lam = lon * Math.PI / 180 - lon0;
  const e = Math.sqrt(f * (2 - f));
  const t = Math.sinh(Math.atanh(Math.sin(phi)) - e * Math.atanh(e * Math.sin(phi)));
  const xi = Math.atan(t / Math.cos(lam));
  const eta = Math.atanh(Math.sin(lam) / Math.sqrt(1 + t * t));
  let E = eta, N = xi;
  for (let j = 1; j <= 3; j++) {
    E += alpha[j - 1] * Math.cos(2 * j * xi) * Math.sinh(2 * j * eta);
    N += alpha[j - 1] * Math.sin(2 * j * xi) * Math.cosh(2 * j * eta);
  }
  return [500000 + k0 * A * E, k0 * A * N];
}
