extends RefCounted
## A variant's cumulative invested copies are the sole permanent level source.

const CARD_COUNT := 4
const ARCHIVED_CARD_COUNT := 70
const MAX_LEVEL := 30
const MAX_COPIES := 465
const OVERFLOW_COIN_VALUES := [1, 3, 8, 20, 50]


static func level_for_count(total: int) -> int:
	var level := 0
	var threshold := 0
	for next_level in range(1, MAX_LEVEL + 1):
		threshold += next_level
		if total < threshold:
			break
		level = next_level
	return level


static func state(total: int) -> Dictionary:
	var invested := clampi(total, 0, MAX_COPIES)
	var level := level_for_count(invested)
	var threshold := 0
	for current_level in range(1, level + 1):
		threshold += current_level
	var full := level == MAX_LEVEL
	return {"level": level, "progress": 0 if full else invested - threshold,
		"next_required": 0 if full else level + 1, "total": invested,
		"max_level": MAX_LEVEL, "full": full}


static func level_map(inventory: Dictionary) -> Dictionary:
	var levels := {}
	for variant in inventory:
		if inventory[variant] is int and inventory[variant] > 0:
			levels[variant] = level_for_count(inventory[variant])
	return levels


## Avoid adding unbounded loot to an already invested count before capping it.
static func apply(total: int, copies: int) -> Dictionary:
	var before := clampi(total, 0, MAX_COPIES)
	var applied := mini(maxi(copies, 0), MAX_COPIES - before)
	var result := state(before + applied)
	result["from_level"] = level_for_count(before)
	result["copies"] = applied
	result["overflow_cards"] = maxi(copies, 0) - applied
	return result
