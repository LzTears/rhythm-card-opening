extends RefCounted
## Fixed collection identities. Combat rewards never expose these definitions.

const DATA_PATH := "res://data/collection_cards.json"
const GRADE_NAMES := ["普通", "稀有", "史诗", "传说", "绝版"]
const GRADE_COLOURS := [Color("e7e5ee"), Color("70d58b"), Color("ba80f5"), Color("f4c562"), Color("ef6581")]
const THEME_ORDER := ["galaxy", "digimon", "meme"]
const THEME_NAMES := {"galaxy":"星系", "digimon":"数码宝贝", "meme":"非主流"}
static var _cards: Dictionary = {}
static var _ids: Array[String] = []


static func _ensure_loaded() -> void:
	if not _ids.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		push_error("Collection catalogue could not be loaded")
		return
	for raw: Variant in parsed:
		if not raw is Dictionary: continue
		var definition: Dictionary = raw.duplicate(true)
		definition.grade = int(definition.grade)
		var id := str(definition.id)
		_cards[id] = definition
		_ids.append(id)


static func card_ids() -> Array[String]:
	_ensure_loaded()
	return _ids.duplicate()


static func card_definition(id: String) -> Dictionary:
	_ensure_loaded()
	return _cards.get(id, {}).duplicate(true)


static func theme_name(id: String) -> String:
	return str(THEME_NAMES.get(id,id))


static func themes() -> Array[Dictionary]:
	_ensure_loaded()
	var totals := {}
	for id: String in _ids:
		var theme_id := str(_cards[id].get("theme",""))
		if not theme_id.is_empty(): totals[theme_id] = int(totals.get(theme_id,0)) + 1
	var ordered: Array[String] = []
	for theme_id: String in THEME_ORDER:
		if totals.has(theme_id): ordered.append(theme_id)
	var remaining: Array = totals.keys()
	remaining.sort()
	for theme_id: String in remaining:
		if not ordered.has(theme_id): ordered.append(theme_id)
	var result: Array[Dictionary] = []
	for theme_id: String in ordered:
		result.append({"id":theme_id, "name":theme_name(theme_id), "total":int(totals[theme_id])})
	return result


static func grade_names() -> Array[String]:
	var result: Array[String] = []
	result.assign(GRADE_NAMES)
	return result


static func grade_colours() -> Array[Color]:
	var result: Array[Color] = []
	result.assign(GRADE_COLOURS)
	return result


static func pool(grade: int, hidden: bool = false) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id: String in _ids:
		var definition: Dictionary = _cards[id]
		if int(definition.grade) == grade and (grade != 4 or definition.hidden == hidden): result.append(id)
	return result


static func collection_counts(profile: Dictionary) -> Dictionary:
	_ensure_loaded()
	var counts := [0, 0, 0, 0, 0]
	var totals := [0, 0, 0, 0, 0]
	var theme_counts := {}
	for theme: Dictionary in themes(): theme_counts[theme.id] = 0
	for id: String in _ids: totals[int(_cards[id].grade)] += 1
	var hidden_count := 0
	for id: Variant in profile.get("album", {}):
		var definition := card_definition(str(id))
		if definition.is_empty() or profile.album[id] != true: continue
		counts[int(definition.grade)] += 1
		theme_counts[definition.theme] += 1
		if definition.hidden: hidden_count += 1
	return {"card_count":counts.reduce(func(total: int, value: int) -> int: return total + value, 0), "card_total":_ids.size(),
		"grade_counts":counts, "grade_totals":totals, "theme_counts":theme_counts,
		"hidden_count":hidden_count, "red_owned_count":counts[4], "red_total":totals[4], "effect_count":0}
