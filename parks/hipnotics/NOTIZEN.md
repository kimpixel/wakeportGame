# Hip-Notics Cable Park – Notizen (Stand 12.11.2026)

Recherche für den zweiten Park. Der Betreiber hat die Nutzung seiner Inhalte erlaubt (laut Nutzer, 12.11.2026).
**Im Spiel seit Phase 3** (`park.json`): System 1 und System 2 auf L3 fahrbar (2.0), L2 als Rundanlage eingetragen
(noch nicht fahrbar, Phase 4), L1 fehlt (Masten). Setup bisher nur „Ohne Features“.

## Eckdaten

- Name: **Hip-Notics** (auch „Hip-Notics Cable Ski“, Website-Titel „Hipnotics“), gegründet 2008
- Adresse: Burunucu Mevkii, Çakış Köyü, 07550 Manavgat / Antalya, Türkei (an der Straße Antalya–Manavgat)
- Lage: ca. **36,9118 N, 31,2022 E** (Tripadvisor/OSM-Knoten 1728510755); 30 min vom Flughafen Antalya
- Zeitzone: Türkei, **UTC+3 ganzjährig** (keine Sommerzeit) → `"timezone": {"utc": 3, "dst": ""}`
- Höhe ca. 10–11 m ü. NN, flach; 300–400 m nördlich ein Hügel bis ca. 85 m (Copernicus DEM)
- Ganzjährig offen, 3 künstliche Seen, ca. **170 cm tief**, von Bergwasser aus dem Taurus gespeist (sehr klar,
  türkisblau, „wie auf den Malediven“), im Winter abgelassen und gereinigt; Seen zusammen ca. 90.000 m²
- Nachtfahren möglich (beleuchtete Seen), Lautsprecher rund um die Seen, Sitzkissen am Ufer, Unterkünfte am See
- Umgebung (Luftbilder der Website): Palmen auf der Insel und am Ufer, Zypressen-Reihe, Obstplantagen, große
  Gewächshäuser, Bungalow-Reihe am Ufer, türkische Fahnen

## Anlagen (alle Rixen)

| See | Anlage | Daten |
|---|---|---|
| **L-1** (Lake 1) | Rundanlage, **6 Masten, 730 m** | Seil ca. 9 m über dem Wasser; Anfänger (langsam) bis Profi, Mono-Ski-Strecke, bis 60+ km/h; „neuer Obstacle Park mit Unit-Features“: Wave Kicker, Large Kicker, Handrail, Ledges, Step-up/-down, Rainbow Box |
| **L-2** (Lake 2) | Rundanlage, **5 Masten, 540 m** | Seil 10 m (Startseite: 12 m); 30+ km/h, „technischeres Setup“ für Fortgeschrittene/Profis; Kicker S/L, Fun Box 16 m, Slider 20 m, Table 12 m, A-Frame 19 m × 3 m hoch |
| **L-3** (Lake 3) | **2 × 2-Mast-Anlage** (2.0) | private Trainingsanlagen, ca. 80 m Fahrlinie, „High Pull“ für Air-Tricks, auch für Kinder/Anfänger |

Zusammen 30–35+ Unit-Parktech-Features. Bilder der Features auf der Website (2023): Kicker L, Pipe, Pro Pipe, Pool,
R2R Transition, Rail to Rail, Step-up Box, Step-down Box, Banana Rail, C-Rail, Handrail, Rainbow, Street Series,
Table, Transition Curb Medium.

## Seen aus Sentinel-2 (15.08.2025, 10 m/Pixel, nur ungefähr ±10 m)

Bild: `recherche/sentinel2_2025-08-15.png` (Ordner mit `.gdignore`: nicht im Spiel) (1200 × 1200 m um 36,9118 N / 31,2022 E, Norden oben, Copernicus Sentinel-2,
frei mit Quellenangabe). UTM-Zone 36 (Mitte 339847 E / 4086597 N).

| See | Mitte (UTM 36) | Größe | Achse |
|---|---|---|---|
| L-1 (Osten, lang) | 340017 E / 4086631 N | ca. 390 × 120 m | fast Ost–West |
| L-2 (Süden, Ring um schmale Insel) | westlich/südlich von L-1 | ca. 280 × 100 m | Nord–Süd |
| L-3 (klein, Westen) | nordwestlich an L-2 | ca. 100 × 70 m | – |

Werkzeuge: `tools/cog_crop.mjs` (Ausschnitt aus Cloud-Optimized GeoTIFF per HTTP-Range, z. B. Sentinel-2 `TCI.tif`
aus `sentinel-cogs.s3.us-west-2.amazonaws.com`, Kachel 36SUF; Copernicus DEM `copernicus-dem-30m.s3.amazonaws.com`,
Kachel `N36_00_E031_00`).

## Lizenzen

- Inhalte des Betreibers (Fotos, Pläne, Videos der Website): Nutzung erlaubt.
- Google-Maps-/Satellitenbilder: nur zum Ausmessen/Nachzeichnen, nicht als Textur ins Spiel.
- Fotos/Videos Dritter (YouTube, Fotografen): Rechte liegen beim Urheber.
- Sentinel-2, Copernicus DEM: frei („Contains modified Copernicus Sentinel data 2025“ bzw. „© DLR e.V. 2014–2018 and
  © Airbus Defence and Space GmbH 2018, provided under COPERNICUS by the European Union and ESA“).

## Im Spiel (Phase 3)

- **Masten** (Wegpunkte des Nutzers, mapy.com): System 1 Start/Ende, System 2 Start/Ende (beide auf L3, 128 bzw. 123 m),
  L2 fünf Masten gegen den Uhrzeigersinn ab dem Start (Umfang 637 m; Website: 540 m). Stehen in `geo_quelle.json`.
- **Geodaten** aus `tools/park_geo.mjs hipnotics` (danach `tools/png_to_jpg.gd`): Gebiet 1120 × 980 m um den Startmast von
  System 1, Seen per Wasserindex (NDWI ≥ 0) aus Sentinel-2, nur Seen bis 60 m an Masten bzw. `lake_seeds` (sonst kamen
  Gewächshäuser mit), Tiefe 1,7 m, flaches Ufer; Gelände außen aus Copernicus DEM (Hügel im Norden, über 35 m weich gekappt);
  Bäume aus NDVI (Obstplantagen); Luftbild Sentinel-2 (10 m, unscharf). Kontrollbild: `recherche/ufer_kontrolle.png`.
- Spielachse nach Norden (`geo_axis`), Anlagen zwischen ihre Masten gesetzt, **Startsteg automatisch** am Ufer vor dem
  Startmast (`dock: {auto}`), einfache Kulisse (Holzsteg, Hütte, Steuermann, wartender Fahrer). Keine SUPs, Badegäste,
  Tiere, Flugzeuge (die sind am Wakeport eingemessen).
- **Knapp auf L3**: nach außen nur 16–23 m (System 1 links) bzw. 13–17 m (System 2 rechts) Wasser – der Autopilot (NPC)
  schwingt in der Wende manchmal ans Ufer. Auf der kurzen Bahn (74 m zwischen den Wenden) reißt beim Autopiloten ab und zu
  das Seil (Zug > 5000 N nach der Wende) – am Wakeport nicht. Uferlinie aus 10-m-Daten ist ±3–5 m ungenau.
- Luftbilder vom Nutzer (aktuell): `recherche/luftbild_von_sueden.jpg`, `recherche/luftbild_von_westen.jpg` – L2 mit vielen
  Features rund um die Insel, Wasser türkis, Palmen, Bungalow-Reihe, Gewächshäuser.

## Rundanlage L2 (Phase 4)

- Fahrbar als `FullCable` (Standard-Anlage im Park): 631 m Seilweg, Ecken als Rollenbogen (14 m), 6 Carrier, Fahrtrichtung
  in Mast-Reihenfolge (gegen den Uhrzeigersinn), Tempo 30 km/h (Nutzer: 30–32 km/h; Einstellung, Rangliste nur bei 30).
- Startblock am Startmast (Nutzer), Steg seitlich außen. Sturz: zurück zum Startsteg (Nutzer: „im Wesentlichen ein Skippen“).
- Setup „L2 nach Luftbild“ (`setups/setup_foto_2025.json`): 8 Features, Lage aus dem Foto von Süden geschätzt, Typen nach der
  Website-Liste: Westseite Kicker S, Fun Box 16 m, A-Frame Rail, Kicker L; Ostseite Down Ledge (Slider 20 m), Pyramid (Table),
  Kicker M, Pro Rail.
- Geodaten: entlang des Seilwegs Wasser ausgehoben (`carve_loops`), an den Ecken 15 m über den Mast hinaus – sonst lief das Seil
  an den Süd-Ecken über Land.
- Autopilot fährt mehrere Runden ohne Sturz (Seilzug max. ~800 N).

## Fehlt noch (vom Nutzer)

1. Masten von L1 (6 Masten) und Fahrtrichtung
2. Startstege (wo genau), Gebäude, aktuelles Feature-Setup je See (Fotos/Plan) – vor allem L2
3. ggf. Uferpunkte von L3 (für eine genauere Uferlinie als aus 10-m-Satellitendaten)

## Quellen

- https://www.hip-notics.com/ , https://www.hip-notics.com/cablepark/ , https://www.hip-notics.com/about/
- https://rixencableway.com/en/success-story-hip-notics-cable-park-turkey/
- https://actiongid.com/en/listing/hip-notics-cable-park/ , https://mapcarta.com/N1728510755
- https://www.tripadvisor.com/Attraction_Review-g15223003-d3702835-Reviews-Hip_Notics_Cable_Ski-Cakis_Manavgat_Turkish_Mediterranean_Coast.html
