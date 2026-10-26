class_name WDate
extends RefCounted
## World dates as days since the Unix epoch (integers). Days before 1970 are negative.

const DAY := 86400

static func from_ymd(y: int, m: int, d: int) -> int:
	var unix: int = Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	return (unix - posmod(unix, DAY)) / DAY


static func from_string(s: String) -> int:
	var parts := s.split("-")
	return from_ymd(int(parts[0]), int(parts[1]), int(parts[2]))


static func to_dict(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(day * DAY + 43200)


static func year(day: int) -> int:
	return int(to_dict(day)["year"])


static func month(day: int) -> int:
	return int(to_dict(day)["month"])


static func day_of_month(day: int) -> int:
	return int(to_dict(day)["day"])


## 0 = Sunday … 6 = Saturday
static func weekday(day: int) -> int:
	return int(to_dict(day)["weekday"])


static func to_iso(day: int) -> String:
	var d := to_dict(day)
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func age_at(birth_day: int, today: int) -> int:
	var b := to_dict(birth_day)
	var t := to_dict(today)
	var a: int = int(t["year"]) - int(b["year"])
	if int(t["month"]) < int(b["month"]) or (int(t["month"]) == int(b["month"]) and int(t["day"]) < int(b["day"])):
		a -= 1
	return a


## Season a date belongs to: the "1993" season runs from July 1993 to June 1994.
static func season_of(day: int) -> int:
	var d := to_dict(day)
	return int(d["year"]) if int(d["month"]) >= 7 else int(d["year"]) - 1
