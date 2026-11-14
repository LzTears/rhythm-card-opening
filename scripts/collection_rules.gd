extends RefCounted
## Pure collection randomisation and settlement. Only the bank writes rewards.

const Catalog = preload("res://scripts/collection_catalog.gd")
const MAX_INT := 9223372036854775807
const DUPLICATE_COINS := [5, 30, 180, 1080, 6480]
const DROP_WEIGHTS := [
	[9000, 900, 90, 9, 1],
	[7000, 2500, 450, 45, 5],
	[4000, 4000, 1800, 180, 20],
	[1500, 3000, 4500, 900, 100],
	[500, 1500, 4000, 3500, 500],
]
const RED_HIDDEN_WEIGHT := 500


static func grade_for_roll(pack_grade: int, roll: int) -> int:
	if pack_grade < 0 or pack_grade > 4 or roll < 0 or roll >= 10000: return -1
	var edge := 0
	for grade in range(5):
		edge += int(DROP_WEIGHTS[pack_grade][grade])
		if roll < edge: return grade
	return -1


static func adjusted_drop_weights(pack_grade: int, identify_level: int = 0) -> Array[int]:
	var result: Array[int] = []
	if pack_grade < 0 or pack_grade > 4: return result
	for grade in range(5): result.append(int(DROP_WEIGHTS[pack_grade][grade]) * (100 + 4 * clampi(identify_level,0,5) if grade >= 2 else 100))
	return result


static func weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights: total += int(weight)
	return total


static func grade_for_scaled_roll(weights: Array, roll: int) -> int:
	if weights.size() != 5 or roll < 0 or roll >= weight_total(weights): return -1
	var edge := 0
	for grade in range(5):
		edge += int(weights[grade])
		if roll < edge: return grade
	return -1




static func identity_weight(card_id: String, album: Dictionary, discovery_level: int) -> int:
	return 5 if bool(album.get(card_id,false)) else 5 + clampi(discovery_level,0,5)


static func draw_card(rng: RandomNumberGenerator, pack_grade: int, options: Dictionary = {}) -> Dictionary:
	var weights := adjusted_drop_weights(pack_grade,int(options.get("identify_level",0)))
	if weights.is_empty(): return {}
	var grade := grade_for_scaled_roll(weights,rng.randi_range(0,weight_total(weights) - 1))
	var hidden := grade == 4 and rng.randi_range(0,9999) < RED_HIDDEN_WEIGHT
	var candidates := Catalog.pool(grade,hidden)
	if candidates.is_empty(): return {}
	var level := int(options.get("discovery_level",0))
	if level == 0: return Catalog.card_definition(candidates[rng.randi_range(0,candidates.size() - 1)])
	var album: Dictionary = options.get("album",{})
	var total := 0
	for id: String in candidates: total += identity_weight(id,album,level)
	var roll := rng.randi_range(0,total - 1)
	var edge := 0
	for id: String in candidates:
		edge += identity_weight(id,album,level)
		if roll < edge: return Catalog.card_definition(id)
	return {}




static func grade_counts(loot: Dictionary) -> Array[int]:
	var result: Array[int] = [0, 0, 0, 0, 0]
	for id: Variant in loot:
		var definition := Catalog.card_definition(str(id))
		if not definition.is_empty(): result[int(definition.grade)] += int(loot[id])
	return result


static func _failure(error: String) -> Dictionary:
	return {"ok":false, "error":error, "rows":[], "new_ids":[], "duplicate_coins":0,
		"pack_coins":0, "total_coins":0, "grade_counts":[0,0,0,0,0], "card_count":0}


static func preview_settlement(profile: Dictionary, result: Dictionary) -> Dictionary:
	var album: Variant = profile.get("album", {})
	if not album is Dictionary or not result.get("loot") is Dictionary: return _failure("invalid_loot")
	for id: Variant in album:
		if not id is String or Catalog.card_definition(id).is_empty() or not album[id] is bool or album[id] != true: return _failure("invalid_album")
	var pack_coins: Variant = result.get("score", result.get("coins", result.get("pack_coins", 0)))
	if not pack_coins is int or pack_coins < 0: return _failure("invalid_integer")
	for field in ["score", "coins", "pack_coins"]:
		if result.has(field) and (not result[field] is int or result[field] != pack_coins): return _failure("invalid_result")
	var rows: Array[Dictionary] = []
	var new_ids: Array[String] = []
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var total_count := 0
	var duplicate_coins := 0
	var duplicate_base := 0
	var bonus: Variant = result.get("duplicate_bonus_percent",5 * clampi(int(profile.get("talents",{}).get("TAL-DUPLICATE",0)),0,5))
	if not bonus is int or bonus < 0 or bonus > 25 or bonus % 5 != 0: return _failure("invalid_result")
	var ids: Array = result.loot.keys()
	for id: Variant in ids:
		if not id is String or Catalog.card_definition(id).is_empty(): return _failure("invalid_loot")
	ids.sort_custom(func(a: String,b: String) -> bool:
		var ga: int = Catalog.card_definition(a).grade
		var gb: int = Catalog.card_definition(b).grade
		return ga < gb if ga != gb else a < b)
	for id: Variant in ids:
		if not id is String or Catalog.card_definition(id).is_empty(): return _failure("invalid_loot")
		var amount: Variant = result.loot[id]
		if not amount is int or amount < 0: return _failure("invalid_loot")
		if amount == 0: continue
		if amount > MAX_INT - total_count: return _failure("integer_overflow")
		var definition := Catalog.card_definition(id)
		var grade: int = definition.grade
		var new_count := 0 if album.get(id, false) else 1
		var duplicate_count: int = amount - new_count
		var price: int = DUPLICATE_COINS[grade]
		if duplicate_count > (MAX_INT - duplicate_base) / price: return _failure("integer_overflow")
		var row_base := duplicate_count * price
		duplicate_base += row_base
		var cumulative := scaled_duplicate_coins(duplicate_base,int(bonus))
		if cumulative < 0: return _failure("integer_overflow")
		var conversion := cumulative - duplicate_coins
		duplicate_coins = cumulative
		total_count += amount
		counts[grade] += amount
		if new_count == 1: new_ids.append(id)
		rows.append({"id":id, "grade":grade, "hidden":definition.hidden, "count":amount,
			"new_count":new_count, "duplicate_count":duplicate_count, "duplicate_coins":conversion})
	for field in ["card_count", "destroyed_pack_count"]:
		if result.has(field) and (not result[field] is int or result[field] != total_count): return _failure("invalid_result")
	if duplicate_coins > MAX_INT - pack_coins: return _failure("integer_overflow")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.grade < b.grade if a.grade != b.grade else a.id < b.id)
	new_ids.sort()
	return {"ok":true, "error":"", "rows":rows, "new_ids":new_ids, "duplicate_coins":duplicate_coins,
		"duplicate_base_coins":duplicate_base, "duplicate_bonus_percent":int(bonus), "pack_coins":pack_coins, "total_coins":pack_coins + duplicate_coins, "grade_counts":counts, "card_count":total_count}


## Integer-only once-rounded total; caller apportions its deltas to sorted rows.
@warning_ignore("integer_division")
static func scaled_duplicate_coins(base: int, bonus: int) -> int:
	if base < 0 or bonus < 0 or bonus > 25: return -1
	var extra := (base / 100) * bonus + ((base % 100) * bonus) / 100
	if extra > MAX_INT - base: return -1
	return base + extra
