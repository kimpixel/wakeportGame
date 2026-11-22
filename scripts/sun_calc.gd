class_name SunCalc
## Sonnenstand am gewählten Park (NOAA-Näherung, auf etwa ein Grad genau) und Ortszeit des Parks
## (Lage und Zeitzone aus parks/<id>/park.json, siehe Park).

# i18n-begin
const MONTHS := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
	"September", "Oktober", "November", "Dezember"]
# i18n-end


## Sonnenstand: x = Höhe über dem Horizont, y = Azimut (Grad, von Norden im Uhrzeigersinn).
## day_of_year: 1..365, hour_utc: Stunde in UTC.
## lat/lon: NAN = Lage des Parks.
static func position(day_of_year: int, hour_utc: float, lat := NAN, lon := NAN) -> Vector2:
	if is_nan(lat):
		lat = Park.lat()
	if is_nan(lon):
		lon = Park.lon()
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


## Unterschied Ortszeit des Parks -> UTC für den Tag im Jahr (Wakeport: 1 = MEZ, 2 = MESZ).
static func utc_offset(year: int, day_of_year: int) -> int:
	return Park.utc_offset(year, day_of_year)


## Tag im Jahr -> "21. Juni"
static func date_text(year: int, day_of_year: int) -> String:
	var d := _date(year, day_of_year)
	# {tag}/{monat} statt %: die Reihenfolge ist je Sprache anders („18. August“, „August 18“)
	return Loc.t("{tag}. {monat}").format({"tag": d["day"], "monat": Loc.t(MONTHS[int(d["month"]) - 1])})


static func day_of_year(year: int, month: int, day: int) -> int:
	var t0 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1})
	var t := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	return int((t - t0) / 86400) + 1


static func _date(year: int, doy: int) -> Dictionary:
	var t0 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1})
	return Time.get_datetime_dict_from_unix_time(t0 + (doy - 1) * 86400)


## Tag im Jahr des letzten Sonntags im Monat (Sommerzeit-Umstellung).
static func last_sunday(year: int, month: int) -> int:
	var last := day_of_year(year, month + 1, 1) - 1
	var wd: int = _date(year, last)["weekday"]          # 0 = Sonntag
	return last - wd
