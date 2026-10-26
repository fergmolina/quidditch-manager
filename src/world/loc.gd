class_name Loc
## Names that come from the data (countries, regions, leagues, houses), translated with the keys in
## locale/strings.csv; if the key is missing, the name from the data is used.



static func name(key: String, fallback: String) -> String:
	var t := str(TranslationServer.translate(key))
	return t if t != key and t != "" else fallback


static func region(reg: Dictionary, rid: String) -> String:
	return name("region." + rid, str(reg.get("name_es", rid)))
