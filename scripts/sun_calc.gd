class_name SunCalc
## Sonnenstand am Wakeport (NOAA-Näherung, auf etwa ein Grad genau) und deutsche Zeit
## (MEZ/MESZ mit Umstellung am letzten Sonntag im März bzw. Oktober).

const LAT := 50.0122               # T2-Startmast, aus den UTM-Koordinaten der Geodaten
const LON := 8.4773

const MONTHS := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
	"September", "Oktober", "November", "Dezember"]


## Sonnenstand: x = Höhe über dem Horizont, y = Azimut (Grad, von Norden im Uhrzeigersinn).
## day_of_year: 1..365, hour_utc: Stunde in UTC.
static func position(day_of_year: int, hour_utc: float, lat := LAT, lon := LON) -> Vector2:
	var g := TAU / 365.0 * (day_of_year - 1 + (hour_utc - 12.0) / 24.0)
	var eqtime := 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g)
		- 0.014615 * cos(2.0 * g) - 0.040849 * sin(2.0 * g))
	var decl := 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2.0 * g) \
		+ 0.000907 * sin(2.0 * g) - 0.002697 * cos(3.0 * g) + 0.00148 * sin(3.0 * g)
	var tst := hour_utc * 60.0 + eqtime + 4.0 * lon          # wahre Sonnenzeit (min)
	var ha := deg_to_rad(tst / 4.0 - 180.0)
	var phi := deg_to_rad(lat)
	var cos_z := sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha)
	var el := 90.0 - rad_to_deg(acos(clampf(cos_z, -1.0, 1.0)))
	var az := rad_to_deg(atan2(sin(ha), cos(ha) * sin(phi) - tan(decl) * cos(phi))) + 180.0
	return Vector2(el, fposmod(az, 360.0))


## Unterschied deutsche Zeit -> UTC (1 = MEZ, 2 = MESZ) für den Tag im Jahr.
static func utc_offset(year: int, day_of_year: int) -> int:
	var start := _last_sunday(year, 3)
	var end := _last_sunday(year, 10)
	return 2 if day_of_year >= start and day_of_year < end else 1


## Tag im Jahr -> "21. Juni"
static func date_text(year: int, day_of_year: int) -> String:
	var d := _date(year, day_of_year)
	return "%d. %s" % [d["day"], MONTHS[int(d["month"]) - 1]]


static func day_of_year(year: int, month: int, day: int) -> int:
	var t0 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1})
	var t := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	return int((t - t0) / 86400) + 1


static func _date(year: int, doy: int) -> Dictionary:
	var t0 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1})
	return Time.get_datetime_dict_from_unix_time(t0 + (doy - 1) * 86400)


static func _last_sunday(year: int, month: int) -> int:
	var last := day_of_year(year, month + 1, 1) - 1
	var wd: int = _date(year, last)["weekday"]          # 0 = Sonntag
	return last - wd
