extends RefCounted
## One owner writes complete profiles. Reads never overwrite a damaged or incompatible file.
## Type paths preserve arbitrary snapshot int64s and IEEE-754 doubles without guessing fields.

const SCHEMA_VERSION := 3
const BUILD_ID := "rhythm-workshop-v15"
const BALANCE_VERSION := "rhythm-workshop-v15"
const PACK_RULES_VERSION := "rhythm-workshop-v15"
const ACTIVE_SNAPSHOT_VERSION := 20
const GameConfig = preload("res://scripts/game_config.gd")
const PackRules = preload("res://scripts/pack_rules.gd")
const AttackSpec = preload("res://scripts/attack_spec.gd")
const CardGrowth = preload("res://scripts/card_growth.gd")
const CollectionCatalog = preload("res://scripts/collection_catalog.gd")
const CollectionRules = preload("res://scripts/collection_rules.gd")
const SkinCatalog = preload("res://scripts/skin_catalog.gd")
const WebSaveSession = preload("res://scripts/web_save_session.gd")
const MAX_INT := 9223372036854775807
const MAX_DEPTH := 96
const VERIFIED_CACHE_LIMIT := 8
const EMPTY_LEASE_GRACE_SECONDS := 5

var _base_dir: String
var _writing := false
var _lease_token := ""
var _web_lease_sequence := 0
## A battle keeps the existing cross-process slot lease until its journal closes.
## Worker stores share only this lease and its mutex; their decoded caches remain private.
var _battle_lease := {}
var _battle_slot := 0
## Content-addressed, bounded cache: every read still reads and hashes all disk
## bytes. Only an exact digest of previously fully verified bytes can reuse a
## decoded profile; no timestamp/size shortcut or mutable profile is shared.
var _verified_content := {}
var _verified_order: Array[String] = []


func _init(base_dir: String = "user://rhythm-workshop-v15") -> void:
	_base_dir = ProjectSettings.globalize_path(base_dir).simplify_path()


func default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "talent_economy_version":15, "revision": 0, "points": 0,
		"inventory": {},
		"album": {}, "skin_owned": {}, "skin_equipped": SkinCatalog.default_equipped(),
		"banked_collection_runs": {},
		"discovery_flags": {}, "talents": {},
		"unlocked_launchers": {"E01": true},
		"selected_loadout": {"launcher_id": "E01", "slots": [null, null, null, null]},
		"active_run": {}, "last_result": {}, "total_banked_cards": 0,
		"settings": {"music_volume": GameConfig.DEFAULT_MUSIC_VOLUME, "sfx_volume": GameConfig.DEFAULT_SFX_VOLUME, "reduce_effects": false},
		"build_id": BUILD_ID, "balance_version": BALANCE_VERSION,
	}


static func launcher_definitions() -> Array[Dictionary]:
	return [
		{"id": "E01", "name": "重击", "condition": "新档免费", "metric": "free", "target": 0},
	]


static func collection_counts(profile: Dictionary) -> Dictionary:
	return CollectionCatalog.collection_counts(profile)


static func legacy_collection_counts(profile: Dictionary) -> Dictionary:
	var discovered := {}
	var effects := {}
	var reds := {}
	var catalogue := {}
	var grade_totals := [0, 0, 0, 0, 0]
	var grade_counts := [0, 0, 0, 0, 0]
	for variant in AttackSpec.card_ids():
		var definition := AttackSpec.card_definition(variant)
		catalogue[variant] = definition
		grade_totals[int(definition.grade)] += 1
	for variant in profile.get("discovery_flags", {}):
		if catalogue.has(variant) and profile.discovery_flags[variant] == true:
			discovered[variant] = true
	# Positive ownership is also evidence of discovery, including fresh fixtures.
	for variant in profile.get("inventory", {}):
		if catalogue.has(variant) and profile.inventory[variant] is int and profile.inventory[variant] > 0:
			discovered[variant] = true
			if catalogue[variant].grade == 4:
				reds[variant] = true
	for variant in discovered:
		var definition: Dictionary = catalogue[variant]
		grade_counts[int(definition.grade)] += 1
		for effect_id in definition.get("effects", {}):
			effects[effect_id] = true
	return {"card_count": discovered.size(), "card_total": catalogue.size(),
		"grade_counts": grade_counts, "grade_totals": grade_totals,
		"effect_count": effects.size(), "red_owned_count": reds.size(), "red_total": grade_totals[4]}


func _grant_launchers(profile: Dictionary) -> Array[String]:
	var counts := collection_counts(profile)
	var newly_unlocked: Array[String] = []
	for definition in launcher_definitions():
		if definition.metric == "boss":
			continue
		var progress: int = profile.total_banked_cards if definition.metric == "total_banked_cards" else counts.card_count
		if definition.metric == "free" or progress >= definition.target:
			if not profile.unlocked_launchers.get(definition.id, false):
				newly_unlocked.append(definition.id)
			profile.unlocked_launchers[definition.id] = true
	return newly_unlocked


func load_slot(slot: int) -> Dictionary:
	var loaded := _resolve_slot(slot)
	loaded.erase("source")
	return loaded


func save_slot(slot: int, profile: Dictionary) -> Dictionary:
	if not _battle_lease.is_empty():
		return save_slot_owned(slot, profile, _battle_lease)
	if _writing:
		return _save_error(profile, "save_busy")
	if not _valid_slot(slot):
		return _save_error(profile, "invalid_slot")
	var lease := _acquire_slot_lease(slot)
	if not lease.ok:
		return _save_error(profile, lease.error)
	_writing = true
	_lease_token = lease.token
	var saved := _save_slot_locked(slot, profile)
	_lease_token = ""
	_writing = false
	_release_slot_lease(lease)
	return saved


func begin_battle_session(slot: int, profile: Dictionary) -> Dictionary:
	if _writing or not _battle_lease.is_empty():
		return {"ok": false, "error": "save_busy"}
	if not _valid_slot(slot):
		return {"ok": false, "error": "invalid_slot"}
	var validation := _validate_profile(profile)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	if profile.has("slot_id") and profile.slot_id != slot:
		return {"ok": false, "error": "slot_mismatch"}
	var lease := _acquire_slot_lease(slot)
	if not lease.ok:
		return lease
	var current := _resolve_slot(slot)
	if not current.ok or not current.exists or current.profile.revision != profile.get("revision", -1):
		_release_slot_lease(lease)
		return {"ok": false, "error": current.error if not current.ok else "revision_conflict"}
	if current.profile.active_run.get("run_id", "") != profile.get("active_run", {}).get("run_id", "") or profile.get("active_run", {}).is_empty():
		_release_slot_lease(lease)
		return {"ok": false, "error": "run_mismatch"}
	lease["guard"] = Mutex.new()
	lease["slot"] = slot
	_battle_lease = lease
	_battle_slot = slot
	return {"ok": true, "error": "", "lease": lease}


func end_battle_session() -> Dictionary:
	if _battle_lease.is_empty():
		return {"ok": true, "error": ""}
	var guard: Mutex = _battle_lease.guard
	if not guard.try_lock():
		return {"ok": false, "error": "save_busy"}
	_release_slot_lease(_battle_lease)
	_battle_lease = {}
	_battle_slot = 0
	guard.unlock()
	return {"ok": true, "error": ""}


## The caller passes an immutable snapshot, never its live simulation dictionary.
## Holding the original token is insufficient after release/replacement: ownership
## is checked under the shared guard before touching any profile file.
func save_slot_owned(slot: int, profile: Dictionary, lease: Dictionary) -> Dictionary:
	if not _owned_lease_valid(slot, lease):
		return _save_error(profile, "save_busy")
	var guard: Mutex = lease.guard
	if not guard.try_lock():
		return _save_error(profile, "save_busy")
	if _writing or not _owned_lease_valid(slot, lease):
		guard.unlock()
		return _save_error(profile, "save_busy")
	_writing = true
	_lease_token = lease.token
	var saved := _save_slot_locked(slot, profile)
	_lease_token = ""
	_writing = false
	guard.unlock()
	return saved


func _owned_lease_valid(slot: int, lease: Dictionary) -> bool:
	if lease.get("slot", 0) != slot or not lease.get("guard") is Mutex:
		return false
	if OS.has_feature("web") and not WebSaveSession.owns(str(lease.get("directory", "")), str(lease.get("token", ""))):
		return false
	var owner: String = lease.get("owner", "")
	return not owner.is_empty() and lease.get("directory", "") == _slot_path(slot, "lock") and FileAccess.get_file_as_string(owner) == lease.get("token", "") and DirAccess.get_files_at(lease.directory) == PackedStringArray([str(lease.token) + ".owner"]) and DirAccess.get_directories_at(lease.directory).is_empty()


func _save_slot_locked(slot: int, profile: Dictionary) -> Dictionary:
	var validation := _validate_profile(profile)
	if not validation.is_empty():
		return _save_error(profile, validation)
	if profile.has("slot_id") and profile.slot_id != slot:
		return _save_error(profile, "slot_mismatch")
	var current := _resolve_slot(slot)
	if not current.ok:
		return _save_error(profile, current.error)
	if current.exists and current.profile.revision != profile.revision:
		return _save_error(profile, "revision_conflict")
	if not current.exists and profile.revision != 0:
		return _save_error(profile, "revision_conflict")
	if current.exists:
		if not current.profile.active_run.is_empty() and profile.active_run.get("run_id", "") == current.profile.active_run.get("run_id", "") and profile.inventory != current.profile.inventory:
			return _save_error(profile, "frozen_inventory_mismatch")
		for variant in current.profile.inventory:
			if profile.inventory.get(variant, 0) < current.profile.inventory[variant]:
				return _save_error(profile, "inventory_regression")
		for variant in current.profile.discovery_flags:
			if current.profile.discovery_flags[variant] and not profile.discovery_flags.get(variant, false):
				return _save_error(profile, "discovery_regression")
		for launcher_id in current.profile.unlocked_launchers:
			if current.profile.unlocked_launchers[launcher_id] and not profile.unlocked_launchers.get(launcher_id, false):
				return _save_error(profile, "unlock_regression")
		for field in ["album", "skin_owned", "banked_collection_runs"]:
			for id: String in current.profile.get(field, {}):
				if profile.get(field, {}).get(id) != true:
					return _save_error(profile, "collection_regression")
	if profile.revision == MAX_INT:
		return _save_error(profile, "integer_overflow")
	var candidate := profile.duplicate(true)
	candidate["slot_id"] = slot
	candidate.revision += 1
	var paths: Array = []
	var float_paths: Array = []
	var encoded := _encode_value(candidate, [], paths, float_paths, 0)
	if not encoded.ok:
		return _save_error(profile, encoded.error)
	var envelope := {
		"schema_version": SCHEMA_VERSION, "build_id": candidate.build_id,
		"balance_version": candidate.balance_version, "slot_id": slot,
		"revision": str(candidate.revision), "profile": encoded.value,
		"integer_paths": paths, "float_paths": float_paths,
	}
	var error := _write_transaction(slot, envelope, current, candidate)
	if not error.is_empty():
		return _save_error(profile, error)
	return {"ok": true, "profile": candidate, "error": ""}


func bank_run(slot: int, profile: Dictionary, result: Dictionary) -> Dictionary:
	if not _battle_lease.is_empty():
		var lease := _battle_lease
		if not _owned_lease_valid(slot, lease):
			return _bank_error(profile, "save_busy")
		var guard: Mutex = lease.guard
		if not guard.try_lock():
			return _bank_error(profile, "save_busy")
		if _writing or not _owned_lease_valid(slot, lease):
			guard.unlock()
			return _bank_error(profile, "save_busy")
		_writing = true
		_lease_token = lease.token
		var banked := _bank_run_locked(slot, profile, result)
		_lease_token = ""
		_writing = false
		guard.unlock()
		return banked
	if _writing:
		return _bank_error(profile, "save_busy")
	if not _valid_slot(slot):
		return _bank_error(profile, "invalid_slot")
	var lease := _acquire_slot_lease(slot)
	if not lease.ok:
		return _bank_error(profile, lease.error)
	_writing = true
	_lease_token = lease.token
	var banked := _bank_run_locked(slot, profile, result)
	_lease_token = ""
	_writing = false
	_release_slot_lease(lease)
	return banked


func _bank_run_locked(slot: int, profile: Dictionary, result: Dictionary) -> Dictionary:
	var validation := _validate_profile(profile)
	if validation.is_empty():
		validation = _validate_result(result)
	if not validation.is_empty():
		return _bank_error(profile, validation)
	if not _valid_slot(slot):
		return _bank_error(profile, "invalid_slot")
	if profile.has("slot_id") and profile.slot_id != slot:
		return _bank_error(profile, "slot_mismatch")
	var committed := _resolve_slot(slot)
	if not committed.ok:
		return _bank_error(profile, committed.error)
	# Return the latest durable profile even when a caller retries a stale result.
	# This precedes active_run checks so an old result never closes a newer run.
	if profile.last_result.get("run_id", "") == result.run_id:
		return {"ok": true, "profile": committed.profile if committed.exists else profile.duplicate(true), "error": "", "banked": false}
	# A caller may retry its original pre-commit dictionary after a successful write.
	if committed.exists and committed.profile.last_result.get("run_id", "") == result.run_id:
		return {"ok": true, "profile": committed.profile, "error": "", "banked": false}
	if profile.active_run.get("run_id", "") != result.run_id:
		return _bank_error(profile, "run_mismatch")
	if result.reason == "completed" and profile.active_run.has("closed") and profile.active_run.closed != true:
		return _bank_error(profile, "run_not_closed")
	var normalized_result := _normalize_result(result)
	var candidate := profile.duplicate(true)
	var count := 0
	var overflow_cards := 0
	var overflow_coins := 0
	var upgrades: Array[Dictionary] = []
	for variant in result.loot:
		var amount: int = result.loot[variant]
		var owned: int = candidate.inventory.get(variant, 0)
		if amount > MAX_INT - count:
			return _bank_error(profile, "integer_overflow")
		count += amount
		if amount > 0:
			var growth := CardGrowth.apply(owned, amount)
			var price: int = CardGrowth.OVERFLOW_COIN_VALUES[int(variant.substr(4, 1))]
			var overflow: int = growth.overflow_cards
			# Quotient guard prevents overflow before performing multiplication.
			if overflow > (MAX_INT - overflow_coins) / price:
				return _bank_error(profile, "integer_overflow")
			overflow_cards += overflow
			overflow_coins += overflow * price
			candidate.inventory[variant] = growth.total
			candidate.discovery_flags[variant] = true
			if growth.level > growth.from_level:
				upgrades.append({"variant": variant, "from_level": growth.from_level,
					"to_level": growth.level, "copies": growth.copies})
	if overflow_coins > MAX_INT - normalized_result.score:
		return _bank_error(profile, "integer_overflow")
	var total_coins: int = normalized_result.score + overflow_coins
	if total_coins > MAX_INT - candidate.points or count > MAX_INT - candidate.total_banked_cards:
		return _bank_error(profile, "integer_overflow")
	if candidate.revision == MAX_INT:
		return _bank_error(profile, "integer_overflow")
	candidate.points += total_coins
	candidate.total_banked_cards += count
	var new_launchers := _grant_launchers(candidate)
	candidate.active_run = {}
	candidate.last_result = normalized_result
	candidate.last_result["card_upgrades"] = upgrades
	candidate.last_result["overflow_cards"] = overflow_cards
	candidate.last_result["overflow_coins"] = overflow_coins
	candidate.last_result["total_coins"] = total_coins
	candidate.last_result["card_count"] = count
	candidate.last_result["new_launchers"] = new_launchers
	candidate.last_result.committed_revision = candidate.revision + 1
	var saved := _save_slot_locked(slot, candidate)
	if not saved.ok:
		return _bank_error(profile, saved.error)
	saved["banked"] = saved.ok
	saved["new_launchers"] = new_launchers
	return saved


## Final settlement uses the latest in-memory profile and one existing atomic
## profile transaction. No durable active-run checkpoint is required.
func bank_collection(slot: int, profile: Dictionary, result: Dictionary) -> Dictionary:
	if not _battle_lease.is_empty():
		var lease := _battle_lease
		if not _owned_lease_valid(slot, lease): return _bank_error(profile, "save_busy")
		var guard: Mutex = lease.guard
		if not guard.try_lock(): return _bank_error(profile, "save_busy")
		if _writing or not _owned_lease_valid(slot, lease):
			guard.unlock()
			return _bank_error(profile, "save_busy")
		_writing = true
		_lease_token = lease.token
		var banked := _bank_collection_locked(slot, profile, result)
		_lease_token = ""
		_writing = false
		guard.unlock()
		return banked
	if _writing: return _bank_error(profile, "save_busy")
	if not _valid_slot(slot): return _bank_error(profile, "invalid_slot")
	var lease := _acquire_slot_lease(slot)
	if not lease.ok: return _bank_error(profile, lease.error)
	_writing = true
	_lease_token = lease.token
	var banked := _bank_collection_locked(slot, profile, result)
	_lease_token = ""
	_writing = false
	_release_slot_lease(lease)
	return banked


func _bank_collection_locked(slot: int, profile: Dictionary, result: Dictionary) -> Dictionary:
	var validation := _validate_profile(profile)
	if not validation.is_empty(): return _bank_error(profile, validation)
	if not result.get("run_id") is String or result.run_id.is_empty() or result.run_id.length() > 256 or result.get("reason") not in ["completed", "early_settlement"]:
		return _bank_error(profile, "invalid_result")
	for field in ["shots", "elapsed_ticks"]:
		if not _nonnegative_integer(result.get(field, result.get("elapsed_tick") if field == "elapsed_ticks" else null)):
			return _bank_error(profile, "invalid_integer")
	if profile.has("slot_id") and profile.slot_id != slot: return _bank_error(profile, "slot_mismatch")
	var committed := _resolve_slot(slot)
	if not committed.ok: return _bank_error(profile, committed.error)
	# Consult every previously committed collection run, so replaying an older
	# result after a later game cannot award it twice.
	if committed.exists and committed.profile.banked_collection_runs.get(result.run_id, false):
		var latest: Dictionary = committed.profile
		var returned: Dictionary = profile.duplicate(true) if profile.revision == latest.revision else latest
		return {"ok":true, "profile":returned, "error":"", "banked":false,
			"settlement":latest.last_result.duplicate(true) if latest.last_result.get("run_id") == result.run_id else {}}
	if profile.banked_collection_runs.get(result.run_id, false): return _bank_error(profile, "uncommitted_run")
	# Freeze the profile's purchased multiplier; callers cannot mint a higher one.
	result = result.duplicate(true)
	result["duplicate_bonus_percent"] = 5 * int(PackRules.normalize_talents(profile.get("talents",{})).get("TAL-DUPLICATE",0))
	var preview := CollectionRules.preview_settlement(profile, result)
	if not preview.ok: return _bank_error(profile, preview.error)
	if preview.total_coins > MAX_INT - profile.points or preview.card_count > MAX_INT - profile.total_banked_cards:
		return _bank_error(profile, "integer_overflow")
	if profile.revision == MAX_INT: return _bank_error(profile, "integer_overflow")
	var candidate := profile.duplicate(true)
	for id: String in preview.new_ids: candidate.album[id] = true
	candidate.points += preview.total_coins
	candidate.total_banked_cards += preview.card_count
	candidate.active_run = {}
	candidate.banked_collection_runs[result.run_id] = true
	var settlement := _normalize_result(result)
	settlement["collection_version"] = 1
	for field in ["rows", "new_ids", "duplicate_coins", "duplicate_base_coins", "duplicate_bonus_percent", "pack_coins", "total_coins", "grade_counts", "card_count"]:
		settlement[field] = preview[field]
	settlement["committed_revision"] = candidate.revision + 1
	candidate.last_result = settlement
	var saved := _save_slot_locked(slot, candidate)
	if not saved.ok: return _bank_error(profile, saved.error)
	saved["banked"] = true
	saved["settlement"] = settlement.duplicate(true)
	return saved


## Call only after explicit delete confirmation (or against isolated test directories).
func delete_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "invalid_slot"}
	if _writing:
		return {"ok": false, "error": "save_busy"}
	var lease := _acquire_slot_lease(slot)
	if not lease.ok:
		return {"ok": false, "error": lease.error}
	_writing = true
	var result := {"ok": true, "error": ""}
	for suffix in ["main", "tmp", "bak"]:
		var path := _slot_path(slot, suffix)
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(path) != OK:
				result = {"ok": false, "error": "delete_failed"}
				break
	if result.ok:
		var journal_path := _base_dir.path_join("slot_%d.battle-wal" % slot)
		if FileAccess.file_exists(journal_path) and DirAccess.remove_absolute(journal_path) != OK:
			result = {"ok": false, "error": "delete_failed"}
	_writing = false
	_release_slot_lease(lease)
	return result


## mkdir is the cross-process arbitration point. A token-named owner avoids a
## delayed cleanup/release ever removing another claimant's owner file.
func _acquire_slot_lease(slot: int) -> Dictionary:
	if OS.has_feature("web"):
		return _acquire_web_slot_lease(slot)
	if DirAccess.make_dir_recursive_absolute(_base_dir) != OK:
		return {"ok": false, "error": "directory_failed"}
	var directory := _slot_path(slot, "lock")
	var token := "%d-%s" % [OS.get_process_id(), Crypto.new().generate_random_bytes(16).hex_encode()]
	var owner := directory.path_join(token + ".owner")
	for _attempt in range(3):
		if DirAccess.make_dir_absolute(directory) == OK:
			var file := FileAccess.open(owner, FileAccess.WRITE)
			if file == null:
				DirAccess.remove_absolute(directory)
				return {"ok": false, "error": "save_busy"}
			file.store_string(token)
			file.flush()
			var error := file.get_error()
			file.close()
			var lease := {"ok": true, "error": "", "directory": directory, "owner": owner, "token": token}
			var owners := DirAccess.get_files_at(directory)
			if error == OK and owners.size() == 1 and owners[0] == token + ".owner" and DirAccess.get_directories_at(directory).is_empty() and FileAccess.get_file_as_string(owner) == token:
				return lease
			_release_slot_lease(lease)
			return {"ok": false, "error": "save_busy"}
		if not _reclaim_dead_lease(directory):
			return {"ok": false, "error": "save_busy"}
	return {"ok": false, "error": "save_busy"}


func _acquire_web_slot_lease(slot: int) -> Dictionary:
	var session := WebSaveSession.check(_base_dir)
	if not session.ok:
		return session
	var directory := _slot_path(slot, "lock")
	_web_lease_sequence += 1
	# RefCounted instance IDs may be represented as negative signed int64s.
	var instance_token := str(get_instance_id()).trim_prefix("-")
	var token := "web-%s-%s-%d" % [session.token, instance_token, _web_lease_sequence]
	if not WebSaveSession.reserve(directory, token):
		return {"ok": false, "error": "save_busy"}
	if DirAccess.make_dir_recursive_absolute(_base_dir) != OK:
		WebSaveSession.release(directory, token)
		return {"ok": false, "error": "directory_failed"}
	# The shell's run lock excludes other pages, and the registry excludes live
	# stores in this page. A prior run's IDBFS lease can therefore be reclaimed.
	if DirAccess.dir_exists_absolute(directory) and not _reclaim_web_lease(directory, session.token):
		WebSaveSession.release(directory, token)
		return {"ok": false, "error": "save_busy"}
	if DirAccess.make_dir_absolute(directory) != OK:
		WebSaveSession.release(directory, token)
		return {"ok": false, "error": "save_busy"}
	var owner := directory.path_join(token + ".owner")
	var lease := {"ok": true, "error": "", "directory": directory, "owner": owner, "token": token, "web": true}
	var file := FileAccess.open(owner, FileAccess.WRITE)
	if file == null:
		_release_slot_lease(lease)
		return {"ok": false, "error": "write_failed"}
	file.store_string(token)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(owner) != token or DirAccess.get_files_at(directory) != PackedStringArray([token + ".owner"]) or not DirAccess.get_directories_at(directory).is_empty():
		_release_slot_lease(lease)
		return {"ok": false, "error": "save_busy"}
	return lease


func _reclaim_web_lease(directory: String, session_token: String) -> bool:
	if not DirAccess.get_directories_at(directory).is_empty():
		return false
	var observed := DirAccess.get_files_at(directory)
	for name in observed:
		if not name.ends_with(".owner"):
			return false
		var token := name.trim_suffix(".owner")
		var parts := token.split("-")
		if parts.size() != 4 or parts[0] != "web" or parts[1].length() != 32 or parts[1] == session_token:
			return false
		for character in parts[1]:
			if not character in "0123456789abcdef":
				return false
		for index in [2, 3]:
			if parts[index].is_empty() or parts[index].length() > 20 or parts[index] == "0":
				return false
			for character in parts[index]:
				if not character in "0123456789":
					return false
		if FileAccess.get_file_as_string(directory.path_join(name)) != token:
			return false
	# Reserve() proves no current transaction can be between mkdir and owner
	# creation. Empty directories left by a closed page need no PID/TTL guess.
	for name in observed:
		var path := directory.path_join(name)
		if FileAccess.get_file_as_string(path) != name.trim_suffix(".owner") or DirAccess.remove_absolute(path) != OK:
			return false
	return DirAccess.remove_absolute(directory) == OK


func _reclaim_dead_lease(directory: String) -> bool:
	if not DirAccess.get_directories_at(directory).is_empty():
		return false
	var observed := DirAccess.get_files_at(directory)
	if observed.is_empty():
		# A creator may be between mkdir and owner creation. A fresh empty lease
		# is busy; a crashed empty lease is removed only after a second check.
		var modified := FileAccess.get_modified_time(directory)
		if modified <= 0 or int(Time.get_unix_time_from_system()) - modified < EMPTY_LEASE_GRACE_SECONDS:
			return false
		if FileAccess.get_modified_time(directory) != modified or not DirAccess.get_files_at(directory).is_empty() or not DirAccess.get_directories_at(directory).is_empty():
			return false
		return DirAccess.remove_absolute(directory) == OK
	for name in observed:
		var pid := _lease_owner_pid(name)
		if pid <= 0 or _lease_pid_running(pid):
			return false
	for name in observed:
		# Only the exact dead token that was read may be deleted. Another
		# reclaimer can already have replaced the directory with a live lease.
		var pid := _lease_owner_pid(name)
		if _lease_pid_running(pid):
			return false
		var path := directory.path_join(name)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			return false
	return DirAccess.remove_absolute(directory) == OK


func _lease_pid_running(pid: int) -> bool:
	if pid == OS.get_process_id() or OS.is_process_running(pid):
		return true
	# Godot on Windows only tracks child processes in is_process_running.
	# Query arbitrary competing owners only when reclaiming a busy lease;
	# ordinary uncontended saves never launch a process. Probe failures keep
	# the lease busy rather than risking a live owner's transaction.
	if OS.get_name() != "Windows":
		return true
	var system_root := OS.get_environment("SystemRoot")
	var executable := system_root.path_join("System32/tasklist.exe")
	var output: Array = []
	var status := OS.execute(executable,PackedStringArray(["/FI","PID eq %d" % pid,"/FO","CSV","/NH"]),output,false,false)
	if status != 0 or output.is_empty() or str(output[0]).strip_edges().is_empty():
		return true
	for line in str(output[0]).split("\n"):
		var fields := line.strip_edges().split("\",\"")
		if fields.size() > 1 and fields[1] == str(pid):
			return true
	return false


func _lease_owner_pid(name: String) -> int:
	if not name.ends_with(".owner"):
		return -1
	var token := name.trim_suffix(".owner")
	var split := token.split("-")
	if split.size() != 2 or not split[0].is_valid_int() or str(split[0].to_int()) != split[0] or split[1].length() != 32:
		return -1
	for character in split[1]:
		if not character in "0123456789abcdef":
			return -1
	return split[0].to_int()


func _release_slot_lease(lease: Dictionary) -> void:
	var owner: String = lease.owner
	if FileAccess.file_exists(owner):
		DirAccess.remove_absolute(owner)
	# An old release cannot remove a replacement containing a new owner.
	DirAccess.remove_absolute(str(lease.directory))
	if lease.get("web", false):
		WebSaveSession.release(str(lease.directory), str(lease.token))


func _resolve_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return _load_error("invalid_slot", false)
	if OS.has_feature("web"):
		var session := WebSaveSession.check(_base_dir)
		if not session.ok:
			return _load_error(str(session.error), false)
	var main_path := _slot_path(slot, "main")
	var backup_path := _slot_path(slot, "bak")
	var has_main := FileAccess.file_exists(main_path)
	var has_backup := FileAccess.file_exists(backup_path)
	if not has_main and not has_backup:
		return {"ok": true, "profile": default_profile(), "error": "", "recovered": false, "exists": false, "source": ""}
	if has_main:
		var main := _read_envelope(main_path, slot)
		if main.ok:
			return _loaded(main.profile, false, main_path)
		if main.error in ["future_schema", "unsupported_schema", "build_mismatch", "balance_mismatch", "simulation_mismatch"]:
			return _load_error(main.error, true)
	if has_backup:
		var backup := _read_envelope(backup_path, slot)
		if backup.ok:
			return _loaded(backup.profile, true, backup_path)
		if backup.error in ["future_schema", "unsupported_schema", "build_mismatch", "balance_mismatch", "simulation_mismatch"]:
			return _load_error(backup.error, true)
	return _load_error("corrupt_save", true)


func _write_transaction(slot: int, envelope: Dictionary, current: Dictionary, candidate: Dictionary) -> String:
	if DirAccess.make_dir_recursive_absolute(_base_dir) != OK:
		return "directory_failed"
	var temporary := _transaction_temporary_path(slot)
	var main := _slot_path(slot, "main")
	var backup := _slot_path(slot, "bak")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "write_failed"
	# Indentation multiplies every numeric type path in large reward ledgers.
	# Compact JSON keeps the exact same schema, checksum and number encodings.
	var expected_bytes := _serialize_envelope(envelope)
	file.store_buffer(expected_bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return "write_failed"
	# Candidate validation and lossless encoding already happened before opening
	# the file. Read the physical bytes back: exact equality proves this complete
	# versioned envelope (including checksum/type paths) reached the temporary.
	if not _verify_temporary(temporary, expected_bytes):
		DirAccess.remove_absolute(temporary)
		return "verify_failed"
	# Never rotate a damaged main over the known-good backup used for recovery.
	if current.exists and current.source == main:
		if DirAccess.copy_absolute(main, backup) != OK:
			DirAccess.remove_absolute(temporary)
			return "backup_failed"
		var verified_backup := _read_envelope(backup, slot)
		if not verified_backup.ok or verified_backup.profile.revision != current.profile.revision:
			DirAccess.remove_absolute(temporary)
			return "backup_failed"
	# Same-directory replacement is a single filesystem rename; main is never deleted first.
	if DirAccess.rename_absolute(temporary, main) != OK:
		DirAccess.remove_absolute(temporary)
		return "replace_failed"
	if not _verify_physical_bytes(main, expected_bytes):
		return "verify_failed"
	_remember_verified(slot, _bytes_digest(expected_bytes), {"ok": true, "profile": candidate, "error": ""})
	# On Web, file close marks /userfs dirty; Godot schedules its asynchronous
	# IndexedDB sync on the next main-loop iteration. This synchronous return
	# verifies the virtual filesystem, not completion of that browser commit.
	return ""


func _transaction_temporary_path(slot: int) -> String:
	return _slot_path(slot, "tmp." + _lease_token)


func _verify_temporary(path: String, expected_bytes: PackedByteArray) -> bool:
	return _verify_physical_bytes(path, expected_bytes)


func _verify_physical_bytes(path: String, expected_bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual := file.get_buffer(file.get_length())
	var error := file.get_error()
	file.close()
	return error == OK and actual == expected_bytes


func _bytes_digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _remember_verified(slot: int, digest: String, result: Dictionary) -> void:
	var cache_key := "%d:%d:%s" % [SCHEMA_VERSION, slot, digest]
	_verified_content[cache_key] = {"slot": slot, "result": result.duplicate(true)}
	_verified_order.erase(cache_key)
	_verified_order.append(cache_key)
	while _verified_order.size() > VERIFIED_CACHE_LIMIT:
		_verified_content.erase(_verified_order.pop_front())


func _read_envelope(path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "read_failed"}
	var raw_bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return {"ok": false, "error": "read_failed"}
	var content_digest := _bytes_digest(raw_bytes)
	var cache_key := "%d:%d:%s" % [SCHEMA_VERSION, slot, content_digest]
	if _verified_content.has(cache_key):
		var cached: Dictionary = _verified_content[cache_key]
		if cached.slot == slot:
			_verified_order.erase(cache_key)
			_verified_order.append(cache_key)
			return cached.result.duplicate(true)
	var serialized := raw_bytes.get_string_from_utf8()
	var parser := JSON.new()
	if parser.parse(serialized) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "invalid_json"}
	var envelope: Dictionary = parser.data
	var schema := _small_integer(envelope.get("schema_version"))
	if schema < 0:
		return {"ok": false, "error": "invalid_envelope"}
	if schema > SCHEMA_VERSION:
		return {"ok": false, "error": "future_schema"}
	if schema != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema"}
	if _small_integer(envelope.get("slot_id")) != slot:
		return {"ok": false, "error": "slot_mismatch"}
	if not envelope.get("profile") is Dictionary or not envelope.get("integer_paths") is Array or not envelope.get("float_paths") is Array:
		return {"ok": false, "error": "invalid_envelope"}
	if not envelope.get("revision") is String or not _valid_int64_string(envelope.revision):
		return {"ok": false, "error": "invalid_integer"}
	# Normalize only the two small metadata integers before canonical checksum calculation.
	envelope.schema_version = schema
	envelope.slot_id = slot
	if not envelope.get("checksum") is String or envelope.checksum != _checksum(envelope):
		return {"ok": false, "error": "checksum_mismatch"}
	var profile: Dictionary = envelope.profile
	for path_value in envelope.integer_paths:
		if not path_value is Array or not _restore_number(profile, path_value, false):
			return {"ok": false, "error": "invalid_integer"}
	for path_value in envelope.float_paths:
		if not path_value is Array or not _restore_number(profile, path_value, true):
			return {"ok": false, "error": "invalid_float"}
	# Loading is read-only; the v15 namespace accepts only complete new profiles.
	profile = normalize_collection_profile(profile)
	var validation := _validate_profile(profile)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	if profile.revision != int(envelope.revision) or profile.build_id != envelope.get("build_id") or profile.balance_version != envelope.get("balance_version") or profile.get("slot_id", slot) != slot:
		return {"ok": false, "error": "metadata_mismatch"}
	var result := {"ok": true, "profile": profile, "error": ""}
	_remember_verified(slot, content_digest, result)
	return result


static func normalize_collection_profile(profile: Dictionary) -> Dictionary:
	# New economy starts a new profile namespace. Old schemas are not migrated.
	return profile.duplicate(true)


func _validate_profile(profile: Dictionary) -> String:
	for field in default_profile():
		if not profile.has(field):
			return "missing_profile_field"
	if not profile.get("talent_economy_version") is int or profile.talent_economy_version != 15: return "invalid_talent_economy"
	if not profile.schema_version is int or profile.schema_version != SCHEMA_VERSION:
		return "future_schema" if _small_integer(profile.schema_version) > SCHEMA_VERSION else "unsupported_schema"
	for field in ["revision", "points", "total_banked_cards"]:
		if not _nonnegative_integer(profile[field]):
			return "invalid_integer"
	if profile.has("slot_id") and (not profile.slot_id is int or not _valid_slot(profile.slot_id)):
		return "invalid_slot"
	for field in ["inventory", "discovery_flags", "unlocked_launchers", "selected_loadout", "active_run", "last_result", "settings", "album", "banked_collection_runs"]:
		if not profile[field] is Dictionary:
			return "invalid_profile"
	for id: Variant in profile.album:
		if not id is String or CollectionCatalog.card_definition(id).is_empty() or not profile.album[id] is bool or profile.album[id] != true:
			return "invalid_album"
	for id: Variant in profile.banked_collection_runs:
		if not id is String or id.is_empty() or id.length() > 256 or not profile.banked_collection_runs[id] is bool or profile.banked_collection_runs[id] != true:
			return "invalid_collection_runs"
	var skin_error := SkinCatalog.validate_profile(profile)
	if not skin_error.is_empty(): return skin_error
	for field in ["build_id", "balance_version"]:
		if not profile[field] is String or profile[field].is_empty():
			return "invalid_profile"
	if profile.build_id != BUILD_ID:
		return "build_mismatch"
	if profile.balance_version != BALANCE_VERSION:
		return "balance_mismatch"
	if not profile.get("talents", {}) is Dictionary or not PackRules.validate_talents(profile.get("talents", {})):
		return "invalid_talents"
	for level in profile.talents.values():
		if not level is int:
			return "invalid_talents"
	for variant in profile.inventory:
		if not _valid_variant(variant) or not profile.inventory[variant] is int or profile.inventory[variant] < 1 or profile.inventory[variant] > CardGrowth.MAX_COPIES:
			return "invalid_inventory"
	for variant in profile.discovery_flags:
		if not _valid_variant(variant) or not profile.discovery_flags[variant] is bool:
			return "invalid_discovery"
	for launcher_id in profile.unlocked_launchers:
		if not AttackSpec.LAUNCHERS.has(launcher_id) or not profile.unlocked_launchers[launcher_id] is bool:
			return "invalid_launchers"
	if profile.unlocked_launchers.get("E01") != true:
		return "invalid_launchers"
	var loadout: Dictionary = profile.selected_loadout
	if loadout.size() != 2 or not loadout.get("launcher_id") is String or profile.unlocked_launchers.get(loadout.launcher_id) != true or not loadout.get("slots") is Array or loadout.slots.size() != 4:
		return "invalid_loadout"
	var equipped_variants := {}
	for variant in loadout.slots:
		if variant != null and (not _valid_variant(variant) or profile.inventory.get(variant, 0) <= 0):
			return "invalid_loadout"
		if variant != null:
			if equipped_variants.has(variant):
				return "duplicate_variant"
			equipped_variants[variant] = true
	if not profile.active_run.is_empty():
		if not profile.active_run.get("run_id") is String or profile.active_run.run_id.is_empty():
			return "invalid_active_run"
		var active_version_error := _validate_active_version(profile.active_run)
		if not active_version_error.is_empty():
			return active_version_error
		if profile.active_run.has("snapshot_version") and not profile.active_run.has("run_options"):
			return "invalid_run_options"
		# Full simulation checkpoints carry the compiled options. Minimal run headers
		# remain useful for settlement fixtures, but present configuration is strict.
		if profile.active_run.has("run_options"):
			var options: Variant = profile.active_run.run_options
			if not options is Dictionary or not PackRules.validate_run_options(options):
				return "invalid_run_options"
			if options.get("loadout") != loadout or PackRules.normalize_talents(options.get("talents", {})) != PackRules.normalize_talents(profile.talents):
				return "frozen_loadout_mismatch"
			var expected_levels := {}
			for variant in loadout.slots:
				if variant != null:
					expected_levels[variant] = CardGrowth.level_for_count(profile.inventory[variant])
			if options.get("card_levels") != expected_levels:
				return "frozen_card_levels_mismatch"
	if not profile.last_result.is_empty():
		var result_error := _validate_collection_result(profile.last_result) if profile.last_result.has("collection_version") else _validate_result(profile.last_result)
		if not result_error.is_empty():
			return "invalid_last_result"
		if profile.last_result.has("collection_version"):
			if profile.banked_collection_runs.get(profile.last_result.run_id) != true: return "invalid_last_result"
			for id: String in profile.last_result.new_ids:
				if profile.album.get(id) != true: return "invalid_last_result"
		if profile.last_result.has("committed_revision") and not _nonnegative_integer(profile.last_result.committed_revision):
			return "invalid_last_result"
	for field in ["music_volume", "sfx_volume"]:
		var volume: Variant = profile.settings.get(field)
		if not (volume is float or volume is int) or not is_finite(float(volume)) or volume < 0 or volume > 1:
			return "invalid_settings"
	if not profile.settings.get("reduce_effects") is bool:
		return "invalid_settings"
	return ""


func _validate_collection_result(result: Dictionary) -> String:
	if result.get("collection_version") != 1 or not result.get("collection_version") is int: return "invalid_result"
	if not result.get("run_id") is String or result.run_id.is_empty() or result.get("reason") not in ["completed","early_settlement"]: return "invalid_result"
	for field in ["score","shots","elapsed_ticks","duplicate_coins","total_coins","card_count","committed_revision"]:
		if not _nonnegative_integer(result.get(field)): return "invalid_integer"
	if not result.get("rows") is Array or not result.get("new_ids") is Array: return "invalid_result"
	var album_before := {}
	var seen := {}
	for raw: Variant in result.rows:
		if not raw is Dictionary or not raw.get("id") is String or seen.has(raw.id): return "invalid_result"
		var definition := CollectionCatalog.card_definition(raw.id)
		if definition.is_empty(): return "invalid_result"
		for field in ["grade","count","new_count","duplicate_count","duplicate_coins"]:
			if not _nonnegative_integer(raw.get(field)): return "invalid_integer"
		if not raw.get("hidden") is bool or raw.hidden != definition.hidden or raw.grade != definition.grade: return "invalid_result"
		if raw.count < 1 or raw.new_count > 1 or raw.duplicate_count != raw.count - raw.new_count: return "invalid_result"
		if raw.new_count == 0: album_before[raw.id] = true
		seen[raw.id] = true
	var checked := CollectionRules.preview_settlement({"album":album_before},result)
	if not checked.ok: return checked.error
	for field in ["rows","new_ids","grade_counts","card_count","duplicate_coins","total_coins"]:
		if result.get(field) != checked[field]: return "invalid_result"
	if result.has("duplicate_base_coins") and result.duplicate_base_coins != checked.duplicate_base_coins: return "invalid_result"
	return ""


func _validate_result(result: Dictionary) -> String:
	if not result.get("run_id") is String or result.run_id.is_empty():
		return "invalid_result"
	if not result.get("loot") is Dictionary or not result.get("reason") in ["completed", "early_exit"]:
		return "invalid_result"
	var normalized := _normalize_result(result)
	for field in ["score", "shots", "elapsed_ticks"]:
		if not _nonnegative_integer(normalized.get(field)):
			return "invalid_integer"
	for field in ["score", "coins"]:
		if result.has(field) and (not _nonnegative_integer(result[field]) or result[field] != normalized.score):
			return "invalid_result"
	if result.has("elapsed_tick") and (not _nonnegative_integer(result.elapsed_tick) or result.elapsed_tick != normalized.elapsed_ticks):
		return "invalid_result"
	for field in ["destroyed_pack_count", "card_count", "pack_coins", "boss_bonus"]:
		if result.has(field) and not _nonnegative_integer(result[field]):
			return "invalid_integer"
	if result.has("pack_coins"):
		var bonus: int = result.get("boss_bonus", 0)
		if bonus > MAX_INT - result.pack_coins or result.pack_coins + bonus != normalized.score:
			return "invalid_result"
	var count := 0
	for variant in result.loot:
		if not _valid_variant(variant) or not _nonnegative_integer(result.loot[variant]):
			return "invalid_loot"
		if result.loot[variant] > MAX_INT - count:
			return "integer_overflow"
		count += result.loot[variant]
	if result.has("card_count") and result.card_count != count:
		return "invalid_result"
	var overflow: Variant = result.get("overflow_cards", 0)
	var conversion: Variant = result.get("overflow_coins", 0)
	if not _nonnegative_integer(overflow) or not _nonnegative_integer(conversion):
		return "invalid_result"
	if overflow > count or (overflow == 0 and conversion != 0) or conversion < overflow:
		return "invalid_result"
	if overflow <= MAX_INT / 50 and conversion > overflow * 50:
		return "invalid_result"
	if conversion > MAX_INT - normalized.score:
		return "integer_overflow"
	if result.has("total_coins") and (not _nonnegative_integer(result.total_coins) or result.total_coins != normalized.score + conversion):
		return "invalid_result"
	if result.has("card_upgrades"):
		if not result.card_upgrades is Array:
			return "invalid_result"
		var upgraded := {}
		for entry in result.card_upgrades:
			if not entry is Dictionary or not _valid_variant(entry.get("variant")) or upgraded.has(entry.variant):
				return "invalid_result"
			for field in ["from_level", "to_level", "copies"]:
				if not _nonnegative_integer(entry.get(field)):
					return "invalid_result"
			if entry.from_level >= entry.to_level or entry.to_level > CardGrowth.MAX_LEVEL or entry.copies < 1 or entry.copies > CardGrowth.MAX_COPIES or entry.copies > result.loot.get(entry.variant, 0):
				return "invalid_result"
			# Some starting invested count in the reported old level must be able
			# to reach the reported new level using exactly these new copies.
			var old_min: int = entry.from_level * (entry.from_level + 1) / 2
			var old_max: int = (entry.from_level + 1) * (entry.from_level + 2) / 2 - 1
			var new_min: int = entry.to_level * (entry.to_level + 1) / 2
			var new_max: int = mini(CardGrowth.MAX_COPIES, (entry.to_level + 1) * (entry.to_level + 2) / 2 - 1)
			if old_max + entry.copies < new_min or old_min + entry.copies > new_max:
				return "invalid_result"
			upgraded[entry.variant] = true
	return ""


func _normalize_result(result: Dictionary) -> Dictionary:
	var normalized := result.duplicate(true)
	normalized["score"] = result.get("score", result.get("coins", result.get("total_coins")))
	normalized["elapsed_ticks"] = result.get("elapsed_ticks", result.get("elapsed_tick"))
	if normalized.get("score") is int and result.get("boss_bonus", 0) is int:
		normalized["pack_coins"] = result.get("pack_coins", normalized.score - result.get("boss_bonus", 0))
	return normalized


func _validate_active_version(active: Dictionary) -> String:
	# This development slice accepts only explicitly versioned pack simulations.
	# Keep the v14 profile envelope readable after banking; only active simulation
	# checkpoints changed semantics for the active-only Fever command gate.
	if active.has("snapshot_version") and active.snapshot_version != ACTIVE_SNAPSHOT_VERSION:
		return "simulation_mismatch"
	var rules: Variant = active.get("rules_version", "")
	if rules != PACK_RULES_VERSION:
		return "simulation_mismatch"
	if active.has("simulation_version") and active.simulation_version != PACK_RULES_VERSION:
		return "simulation_mismatch"
	if active.has("simulation_version") and rules != PACK_RULES_VERSION:
		return "simulation_mismatch"
	for field in ["build_id", "build"]:
		if active.has(field) and active[field] != BUILD_ID:
			return "build_mismatch"
	if active.has("balance_version") and active.balance_version != BALANCE_VERSION:
		return "balance_mismatch"
	return ""


func _encode_value(value: Variant, path: Array, paths: Array, float_paths: Array, depth: int) -> Dictionary:
	# Keep one result/error wrapper per complete value instead of allocating a
	# {ok, value} dictionary for every scalar in a growing reward ledger.
	var errors: Array[String] = []
	var encoded: Variant = _encode_tree(value, path, paths, float_paths, depth, errors)
	if not errors.is_empty():
		return {"ok": false, "error": errors[0]}
	return {"ok": true, "value": encoded}


func _encode_tree(value: Variant, path: Array, paths: Array, float_paths: Array, depth: int, errors: Array[String]) -> Variant:
	if depth > MAX_DEPTH:
		errors.append("snapshot_too_deep")
		return null
	match typeof(value):
		TYPE_INT:
			paths.append(path.duplicate())
			return str(value)
		TYPE_FLOAT:
			if not is_finite(value):
				errors.append("snapshot_not_json_safe")
				return null
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, value)
			float_paths.append(path.duplicate())
			return bytes.hex_encode()
		TYPE_DICTIONARY:
			var dictionary := {}
			for key in value:
				if not (key is String or key is StringName):
					errors.append("snapshot_not_json_safe")
					return null
				path.append(String(key))
				var child: Variant = _encode_tree(value[key], path, paths, float_paths, depth + 1, errors)
				path.pop_back()
				if child == null and not errors.is_empty():
					return null
				dictionary[String(key)] = child
			return dictionary
		TYPE_ARRAY:
			var array: Array = []
			for index in value.size():
				path.append(str(index))
				var child: Variant = _encode_tree(value[index], path, paths, float_paths, depth + 1, errors)
				path.pop_back()
				if child == null and not errors.is_empty():
					return null
				array.append(child)
			return array
		TYPE_NIL, TYPE_STRING, TYPE_BOOL:
			return value
	errors.append("snapshot_not_json_safe")
	return null


func _restore_number(profile: Dictionary, path: Array, is_float: bool) -> bool:
	if path.is_empty() or path.size() > MAX_DEPTH + 1:
		return false
	var container: Variant = profile
	for index in path.size():
		if not path[index] is String:
			return false
		var key: Variant = path[index]
		if container is Dictionary:
			if not container.has(key):
				return false
		elif container is Array:
			if not _valid_int64_string(key) or key.begins_with("-"):
				return false
			key = int(key)
			if key >= container.size():
				return false
		else:
			return false
		if index == path.size() - 1:
			if not container[key] is String:
				return false
			if is_float:
				var text: String = container[key]
				if text.length() != 16:
					return false
				for character in text:
					if not character in "0123456789abcdef":
						return false
				var bytes := text.hex_decode()
				if bytes.size() != 8:
					return false
				var number := bytes.decode_double(0)
				if not is_finite(number):
					return false
				container[key] = number
			else:
				if not _valid_int64_string(container[key]):
					return false
				container[key] = int(container[key])
		else:
			container = container[key]
	return true


func _serialize_envelope(envelope: Dictionary) -> PackedByteArray:
	var checked := envelope.duplicate(false)
	checked.erase("checksum")
	var canonical := JSON.stringify(checked, "", true, true)
	var digest := canonical.sha256_text()
	envelope.checksum = digest
	# In this fixed SaveEnvelope schema, checksum sorts immediately before
	# float_paths. That key precedes profile, and quoted text inside either
	# header value is escaped by JSON, so it cannot impersonate this key.
	# Reuse the exact canonical body, retaining byte-for-byte sorted JSON while
	# avoiding a second complete traversal of all numeric paths and snapshots.
	if checked.size() != 8 or not checked.has("float_paths"):
		return JSON.stringify(envelope, "", true, true).to_utf8_buffer()
	var insert_at := canonical.find('"float_paths":')
	if insert_at < 0:
		return JSON.stringify(envelope, "", true, true).to_utf8_buffer()
	var bytes := canonical.substr(0, insert_at).to_utf8_buffer()
	bytes.append_array(('"checksum":"' + digest + '",').to_utf8_buffer())
	bytes.append_array(canonical.substr(insert_at).to_utf8_buffer())
	return bytes


func _checksum(envelope: Dictionary) -> String:
	# Only remove a top-level field; none of the nested encoded values mutate.
	var checked := envelope.duplicate(false)
	checked.erase("checksum")
	return JSON.stringify(checked, "", true, true).sha256_text()


func _valid_int64_string(value: String) -> bool:
	if value.is_empty():
		return false
	var digits := value.substr(1) if value.begins_with("-") else value
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) or value == "-0":
		return false
	for code in digits.to_ascii_buffer():
		if code < 48 or code > 57:
			return false
	var limit := "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	return digits.length() < 19 or (digits.length() == 19 and digits <= limit)


func _small_integer(value: Variant) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and value >= 0 and value <= 2147483647 and value == floor(value):
		return int(value)
	return -1


func _valid_variant(value: Variant) -> bool:
	return value is String and not AttackSpec.card_definition(value).is_empty()


func _nonnegative_integer(value: Variant) -> bool:
	return value is int and value >= 0


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= 3


func _slot_path(slot: int, suffix: String) -> String:
	return _base_dir.path_join("slot_%d.%s.json" % [slot, suffix])


func _save_error(profile: Dictionary, error: String) -> Dictionary:
	return {"ok": false, "profile": profile.duplicate(true), "error": error}


func _bank_error(profile: Dictionary, error: String) -> Dictionary:
	var response := _save_error(profile, error)
	response["banked"] = false
	return response


func _load_error(error: String, exists: bool) -> Dictionary:
	return {"ok": false, "profile": {}, "error": error, "recovered": false, "exists": exists, "source": ""}


func _loaded(profile: Dictionary, recovered: bool, source: String) -> Dictionary:
	return {"ok": true, "profile": profile, "error": "", "recovered": recovered, "exists": true, "source": source}
