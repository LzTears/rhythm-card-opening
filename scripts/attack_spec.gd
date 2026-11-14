extends RefCounted
## New combat has no equipment effects. Compatibility APIs expose an empty pool.
const VERSION := 14
const CATALOG_VERSION := "rhythm-workshop-v15-no-combat-cards"
const MAX_LEVEL := 30
const BASE_LANDING_RADIUS := 106.5
const PRIMARY_RADIUS_CAP := 234.3
const ACTIVE_CARD_IDS := []
const CATALOG := {}
const GRADE_COUNTS := [0,0,0,0,0]
const FAMILY_NAMES := []
const LAUNCHERS := {"E01":{"id":"E01","name":"节拍工坊","period":1.5,"energy":100.0,"shape":"circle","radius":BASE_LANDING_RADIUS,"length":0.0,"pulse_ticks":[0]}}

static func fixed(value: float) -> float:
	return String.num(value,6).to_float()

static func launcher_definition(id: String) -> Dictionary:
	return LAUNCHERS.get(id,{}).duplicate(true)

static func normalize_loadout(loadout: Dictionary = {}) -> Dictionary:
	if loadout.is_empty(): return {"launcher_id":"E01","slots":[null,null,null,null]}
	if loadout.size() != 2 or loadout.get("launcher_id") != "E01" or not loadout.get("slots") is Array or loadout.slots != [null,null,null,null]: return {}
	return {"launcher_id":"E01","slots":[null,null,null,null]}

static func normalize_card_levels(_loadout: Dictionary, levels: Dictionary = {}) -> Dictionary:
	return {} if levels.is_empty() else {"invalid":true}

static func active_card_ids() -> Array[String]: return []
static func archived_card_ids() -> Array[String]: return []
static func card_ids() -> Array[String]: return []
static func card_ids_by_grade(_rank: int) -> Array[String]: return []
static func card_rows(_level: int = 1) -> Array[Dictionary]: return []
static func card_definition(_variant: String, _level: int = 1) -> Dictionary: return {}
static func card_description(_variant: String, _level: int = 1) -> String: return ""
static func params(_spec: Dictionary, _family: String) -> Dictionary: return {}
static func grade(_spec: Dictionary, _family: String) -> int: return -1
static func bounded_params(_family: String, _value: Dictionary) -> Dictionary: return {}

static func compile(talents: Dictionary, _loadout: Dictionary = {}, _levels: Dictionary = {}) -> Dictionary:
	var damage: int = [100,120,150,180,200][clampi(int(talents.get("TAL-P",0)),0,4)]
	var spec := {"version":VERSION,"catalog_version":CATALOG_VERSION,"launcher":launcher_definition("E01"),"variants":[],"card_levels":{},"card_instances":{},"cards":{},"bonds":[],
		"energy":damage,"energy_numerator":damage * 100,"energy_denominator":100,"period_ticks":90,"period_numerator":9000,"period_denominator":100,
		"circle_radius":BASE_LANDING_RADIUS,"presentation_geometry":{"shape":"circle","radius":BASE_LANDING_RADIUS,"width":BASE_LANDING_RADIUS * 2.0,"length":0.0,"element":"E01","focus_radius":0.0}}
	spec["hash"] = JSON.stringify(spec,"",true,true).sha256_text()
	return spec

static func primary_radius(spec: Dictionary) -> float:
	return float(spec.get("circle_radius",BASE_LANDING_RADIUS))
