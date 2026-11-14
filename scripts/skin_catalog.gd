extends RefCounted
## Cosmetics are permanent purchases; equipping has no simulation effect.

const CATEGORIES := ["beat", "board", "pack"]
const DEFINITIONS := [
	{"id":"beat_starlight", "name":"星河流光", "category":"beat", "style":"starlight", "price":60000},
	{"id":"beat_neon", "name":"霓虹数码", "category":"beat", "style":"neon", "price":60000},
	{"id":"pack_starlight", "name":"星河流光", "category":"pack", "style":"starlight", "price":120000},
	{"id":"pack_neon", "name":"霓虹数码", "category":"pack", "style":"neon", "price":120000},
	{"id":"board_starlight", "name":"星河流光", "category":"board", "style":"starlight", "price":240000},
	{"id":"board_neon", "name":"霓虹数码", "category":"board", "style":"neon", "price":240000},
]


static func skin_ids() -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in DEFINITIONS: result.append(definition.id)
	return result


static func skin_definition(id: String) -> Dictionary:
	for definition: Dictionary in DEFINITIONS:
		if definition.id == id: return definition.duplicate(true)
	return {}


static func default_equipped() -> Dictionary:
	return {"beat":"default", "board":"default", "pack":"default"}


static func validate_profile(profile: Dictionary) -> String:
	var owned: Variant = profile.get("skin_owned")
	var equipped: Variant = profile.get("skin_equipped")
	if not owned is Dictionary or not equipped is Dictionary or equipped.size() != 3: return "invalid_skins"
	for id: Variant in owned:
		if not id is String or skin_definition(id).is_empty() or not owned[id] is bool or owned[id] != true: return "invalid_skins"
	for category: String in CATEGORIES:
		var id: Variant = equipped.get(category)
		if not id is String: return "invalid_skins"
		if id == "default": continue
		var definition := skin_definition(id)
		if definition.is_empty() or definition.category != category or owned.get(id) != true: return "invalid_skins"
	return ""
