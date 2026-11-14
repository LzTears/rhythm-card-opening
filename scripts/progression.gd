extends RefCounted
## Purchases update the in-memory profile. Manual save or settlement persists it.

const PackRules = preload("res://scripts/pack_rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const CardGrowth = preload("res://scripts/card_growth.gd")
const AttackSpec = preload("res://scripts/attack_spec.gd")
const SkinCatalog = preload("res://scripts/skin_catalog.gd")

var _store: RefCounted
var deferred_writes := true


func _init(save_store: RefCounted = null) -> void:
	_store = save_store if save_store != null else SaveStore.new()


func collection_state(profile: Dictionary) -> Dictionary:
	return SaveStore.collection_counts(profile)


func launcher_states(profile: Dictionary) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var counts := collection_state(profile)
	for definition in SaveStore.launcher_definitions():
		var state: Dictionary = definition.duplicate(true)
		state["unlocked"] = profile.get("unlocked_launchers", {}).get(state.id, false) == true and state.metric != "boss"
		state["selected"] = profile.get("selected_loadout", {}).get("launcher_id", "E01") == state.id
		state["progress"] = profile.get("total_banked_cards", 0) if state.metric == "total_banked_cards" else (counts.card_count if state.metric == "card_count" else 0)
		state["status"] = "unlocked" if state.unlocked else ("boss_unimplemented" if state.metric == "boss" else "locked")
		state["can_select"] = state.unlocked and profile.get("active_run", {}).is_empty()
		states.append(state)
	return states


func card_state(profile: Dictionary, variant: String) -> Dictionary:
	if not AttackSpec.ACTIVE_CARD_IDS.has(variant):
		return {"variant": variant, "status": "invalid_variant", "level": 0, "owned": false}
	var result := CardGrowth.state(int(profile.get("inventory", {}).get(variant, 0)))
	var definition := AttackSpec.card_definition(variant, maxi(1, int(result.level)))
	result["variant"] = variant
	result["name"] = definition.name
	result["grade"] = definition.grade
	result["art_variant"] = definition.get("art_variant", variant)
	result["owned"] = result.level > 0
	result["equipped_slot"] = profile.get("selected_loadout", {}).get("slots", []).find(variant)
	result["status"] = "full" if result.full else ("owned" if result.owned else "undiscovered")
	result["revision"] = profile.get("revision", 0)
	return result


func equip_card(slot: int, profile: Dictionary, variant: String, slot_index: int = -1, expected_revision: int = -1) -> Dictionary:
	var validation := _validate_action(slot, profile, expected_revision)
	if not validation.is_empty():
		return _error(profile, validation)
	if not AttackSpec.ACTIVE_CARD_IDS.has(variant):
		return _error(profile, "invalid_variant")
	if profile.inventory.get(variant, 0) <= 0:
		return _error(profile, "not_owned")
	if slot_index < -1 or slot_index >= 4:
		return _error(profile, "invalid_card_slot")
	var slots: Array = profile.selected_loadout.slots
	# Catalogue numbers are independent cards. An exact card has only one slot.
	if slots.has(variant):
		return _unchanged(profile)
	var target_slot := slot_index
	if target_slot == -1:
		target_slot = slots.find(null)
	if target_slot < 0:
		return _error(profile, "slots_full")
	if slots[target_slot] == variant:
		return _unchanged(profile)
	var candidate := profile.duplicate(true)
	var previous: Variant = candidate.selected_loadout.slots[target_slot]
	candidate.selected_loadout.slots[target_slot] = variant
	return _commit(slot, profile, candidate, {"type": "LoadoutChanged", "slot_index": target_slot, "old_variant": previous, "variant": variant})


func unequip_card(slot: int, profile: Dictionary, slot_index: int, expected_revision: int = -1) -> Dictionary:
	var validation := _validate_action(slot, profile, expected_revision)
	if not validation.is_empty():
		return _error(profile, validation)
	if slot_index < 0 or slot_index >= 4:
		return _error(profile, "invalid_card_slot")
	if profile.selected_loadout.slots[slot_index] == null:
		return _unchanged(profile)
	var candidate := profile.duplicate(true)
	var previous: Variant = candidate.selected_loadout.slots[slot_index]
	candidate.selected_loadout.slots[slot_index] = null
	return _commit(slot, profile, candidate, {"type": "LoadoutChanged", "slot_index": slot_index, "old_variant": previous, "variant": null})


func select_launcher(slot: int, profile: Dictionary, launcher_id: String, expected_revision: int = -1) -> Dictionary:
	var validation := _validate_action(slot, profile, expected_revision)
	if not validation.is_empty():
		return _error(profile, validation)
	var known := false
	for definition in SaveStore.launcher_definitions():
		if definition.id == launcher_id:
			known = true
	if not known:
		return _error(profile, "unknown_launcher")
	if profile.unlocked_launchers.get(launcher_id, false) != true:
		return _error(profile, "launcher_locked")
	if profile.selected_loadout.launcher_id == launcher_id:
		return _unchanged(profile)
	var candidate := profile.duplicate(true)
	candidate.selected_loadout.launcher_id = launcher_id
	return _commit(slot, profile, candidate, {"type": "LauncherSelected", "launcher_id": launcher_id})


func _validate_action(slot: int, profile: Dictionary, expected_revision: int) -> String:
	var validation: String = _store._validate_profile(profile)
	if not validation.is_empty():
		return validation
	if not _store._valid_slot(slot):
		return "invalid_slot"
	if profile.has("slot_id") and profile.slot_id != slot:
		return "slot_mismatch"
	if expected_revision != -1 and expected_revision != profile.revision:
		return "revision_conflict"
	if not profile.active_run.is_empty():
		return "active_run"
	var durable: Dictionary = _store.load_slot(slot)
	if not durable.ok:
		return durable.error
	if (durable.exists and durable.profile.revision != profile.revision) or (not durable.exists and profile.revision != 0):
		return "revision_conflict"
	return ""


func _unchanged(profile: Dictionary) -> Dictionary:
	return {"ok": true, "profile": profile.duplicate(true), "error": "", "changed": false, "event": {}}


func _commit(slot: int, profile: Dictionary, candidate: Dictionary, event: Dictionary) -> Dictionary:
	var saved: Dictionary = _store.save_slot(slot, candidate)
	if not saved.ok:
		return _error(profile, saved.error)
	event["event_version"] = 1
	event["revision"] = saved.profile.revision
	saved["changed"] = true
	saved["event"] = event
	return saved


func talent_states(profile: Dictionary) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for definition in PackRules.talent_definitions():
		states.append(get_talent_state(profile, definition.id))
	return states


func get_talent_state(profile: Dictionary, node_id: String) -> Dictionary:
	var canonical := _canonical_node(node_id)
	var definition: Dictionary = PackRules.talent_definition(canonical)
	if definition.is_empty():
		return {}
	var talents: Dictionary = PackRules.normalize_talents(profile.get("talents", {}))
	var level: int = talents.get(canonical, 0)
	var max_level: int = definition.max_level
	var requirements: Dictionary = definition.get("requirements", definition.get("requires", {}))
	var requirements_any := talent_requirement_groups(definition)
	var requirements_satisfied := _requirements_met(requirements_any, talents)
	# Existing purchases retain their upgrade path when a tree is introduced or
	# rearranged. Prerequisites gate the first purchase only.
	var prerequisites_met := level > 0 or requirements_satisfied
	var implemented: bool = definition.get("implemented", false)
	var cost: int = definition.costs[level] if level < max_level else 0
	var status := "available"
	if not implemented:
		status = "unimplemented"
	elif level >= max_level:
		status = "maxed"
	elif not profile.get("active_run", {}).is_empty():
		status = "in_run"
	elif not prerequisites_met:
		status = "prerequisite"
	elif profile.get("points", 0) < cost:
		status = "insufficient_coins"
	return {
		"id": canonical, "name": definition.name,
		"level": level, "max_level": max_level, "next_level": mini(level + 1, max_level),
		"display_level":level,
		"display_max_level":max_level,
		"next_display_level":mini(level+1,max_level),
		"cost": cost, "status": status, "can_buy": status == "available",
		"implemented": implemented, "requirements": requirements.duplicate(true),
		"requirements_any": requirements_any.duplicate(true),
		"requirements_satisfied": requirements_satisfied, "owned": level > 0,
		"prerequisite_exempt": level > 0 and not requirements_satisfied,
		"prerequisites_met": prerequisites_met, "effect": definition.get("effect", definition.name),
	}


static func talent_requirement_groups(definition: Dictionary) -> Array[Dictionary]:
	# OR between groups; AND within one group. Legacy requirements remain AND.
	var groups: Array[Dictionary] = []
	if definition.has("requirements_any"):
		for raw: Variant in definition.requirements_any:
			if raw is Dictionary: groups.append(raw.duplicate(true))
	else:
		var legacy: Dictionary = definition.get("requirements", definition.get("requires", {}))
		if not legacy.is_empty(): groups.append(legacy.duplicate(true))
	return groups


static func _requirements_met(groups: Array[Dictionary], talents: Dictionary) -> bool:
	if groups.is_empty(): return true
	for group: Dictionary in groups:
		var met := true
		for key: Variant in group:
			if int(talents.get(str(key), 0)) < int(group[key]):
				met = false
				break
		if met: return true
	return false


func buy_talent(slot: int, profile: Dictionary, node_id: String, expected_level: int) -> Dictionary:
	var validation: String = _store._validate_profile(profile)
	if not validation.is_empty():
		return _error(profile, validation)
	if not _store._valid_slot(slot): return _error(profile, "invalid_slot")
	if profile.has("slot_id") and profile.slot_id != slot: return _error(profile, "slot_mismatch")
	if not profile.active_run.is_empty():
		return _error(profile, "active_run")
	var state := get_talent_state(profile, node_id)
	if state.is_empty():
		return _error(profile, "unknown_talent")
	if expected_level != state.level:
		return _error(profile, "level_conflict")
	if state.status != "available":
		return _error(profile, state.status)
	var candidate := profile.duplicate(true)
	candidate["talents"] = PackRules.normalize_talents(profile.get("talents", {}))
	candidate.talents[state.id] = state.level + 1
	candidate.points -= state.cost
	var saved: Dictionary = {"ok":true, "profile":candidate, "error":"", "deferred":true} if deferred_writes else _store.save_slot(slot, candidate)
	if not saved.ok:
		return _error(profile, saved.error)
	saved["purchased"] = true
	saved["event"] = {
		"type": "TalentBought", "event_version": 2, "node_id": state.id,
		"old_level": state.level, "new_level": state.level + 1,
		"cost": state.cost, "balance": saved.profile.points,
		"revision": saved.profile.revision,
	}
	return saved


func skin_states(profile: Dictionary) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for id: String in SkinCatalog.skin_ids():
		var state := SkinCatalog.skin_definition(id)
		state["owned"] = profile.get("skin_owned", {}).get(id, false) == true
		state["equipped"] = profile.get("skin_equipped", {}).get(state.category, "default") == id
		state["can_buy"] = not state.owned and profile.get("points", 0) >= state.price
		state["can_equip"] = state.owned
		state["status"] = "owned" if state.owned else ("available" if state.can_buy else "insufficient_coins")
		states.append(state)
	return states


func buy_skin(profile: Dictionary, id: String) -> Dictionary:
	var validation: String = _store._validate_profile(profile)
	if not validation.is_empty(): return _error(profile, validation)
	var definition := SkinCatalog.skin_definition(id)
	if definition.is_empty(): return _error(profile, "unknown_skin")
	if profile.skin_owned.get(id, false):
		var unchanged := _unchanged(profile)
		unchanged["purchased"] = false
		return unchanged
	if profile.points < definition.price: return _error(profile, "insufficient_coins")
	var candidate := profile.duplicate(true)
	candidate.points -= int(definition.price)
	candidate.skin_owned[id] = true
	return {"ok":true, "profile":candidate, "error":"", "purchased":true, "changed":true, "deferred":true,
		"event":{"type":"SkinBought", "event_version":1, "skin_id":id, "category":definition.category,
			"cost":definition.price, "balance":candidate.points, "revision":candidate.revision}}


## Default is shared by three categories, so the category is required only
## when selecting the free default: equip_skin(profile, "default", "beat").
func equip_skin(profile: Dictionary, id: String, category: String = "") -> Dictionary:
	var validation: String = _store._validate_profile(profile)
	if not validation.is_empty(): return _error(profile, validation)
	var target_category := category
	if id != "default":
		var definition := SkinCatalog.skin_definition(id)
		if definition.is_empty(): return _error(profile, "unknown_skin")
		if not category.is_empty() and category != definition.category: return _error(profile, "invalid_skin_category")
		target_category = definition.category
		if profile.skin_owned.get(id) != true: return _error(profile, "skin_locked")
	if not SkinCatalog.CATEGORIES.has(target_category): return _error(profile, "invalid_skin_category")
	if profile.skin_equipped[target_category] == id: return _unchanged(profile)
	var candidate := profile.duplicate(true)
	candidate.skin_equipped[target_category] = id
	return {"ok":true, "profile":candidate, "error":"", "changed":true, "deferred":true,
		"event":{"type":"SkinEquipped", "event_version":1, "skin_id":id, "category":target_category, "revision":candidate.revision}}


func _canonical_node(node_id: String) -> String:
	return node_id if node_id.begins_with("TAL-") else "TAL-" + node_id


func _error(profile: Dictionary, error: String) -> Dictionary:
	return {"ok": false, "profile": profile.duplicate(true), "error": error, "purchased": false, "changed": false, "event": {}}
