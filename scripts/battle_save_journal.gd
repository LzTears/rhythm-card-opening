extends RefCounted
## A write-ahead input log keeps every acknowledged battle tick recoverable while
## complete, unchanged SaveEnvelopes are committed by an isolated worker Store.
## flush() has the same OS/process-crash durability contract as SaveStore saves.
const Store = preload("res://scripts/save_store.gd")
const FORMAT_VERSION := 4
const MAGIC := "RCWAL04\n"
const Conductor = preload("res://scripts/rhythm_conductor.gd")
const RHYTHM_KEYS := Conductor.KEYS
const MAX_RHYTHM_INPUTS := 6
const RECORD_BYTES := 64
const MAX_HEADER_BYTES := 16384
const MAX_TICKS := Conductor.RUN_TICKS

var _store: RefCounted
var _slot := 0
var _lease := {}
var _file: FileAccess
var _path := ""
var _run_id := ""
var _last_tick := 0
var _previous := PackedByteArray()
var _thread: Thread
var _worker_error := ""
var _open := false
var appended_ticks := 0
var append_max_usec := 0
var collect_wait_max_usec := 0
var collect_release_max_usec := 0
var collect_timings: Array = []


func begin(storage: RefCounted, slot: int, profile: Dictionary, simulation: RefCounted) -> Dictionary:
	if _open or _thread != null:
		return _error("journal_busy")
	_store = storage
	_slot = slot
	_path = storage._base_dir.path_join("slot_%d.battle-wal" % slot)
	var session: Dictionary = storage.begin_battle_session(slot, profile)
	if not session.ok:
		return _error(session.error)
	_lease = session.lease
	var snapshot: Dictionary = profile.get("active_run", {})
	_run_id = str(snapshot.get("run_id", ""))
	if simulation.tick != snapshot.get("tick", -1) or simulation.run_id != snapshot.get("run_id", ""):
		return _begin_failure("journal_snapshot_mismatch")
	var pending: Dictionary = snapshot.get("_pending_tick_input", {})
	var replayed := 0
	var recovered := {}
	# The pre-journal build's pre-root marker represents precisely the next tick.
	if not pending.is_empty():
		var aim: Variant = pending.get("aim")
		if not aim is Array or aim.size() != 2 or not pending.get("valid") is bool:
			return _begin_failure("journal_invalid_pending")
		if not _replay_rhythm(simulation, pending.get("rhythm_inputs", [])):
			return _begin_failure("journal_invalid_rhythm_input")
		simulation.step(Vector2(float(aim[0]), float(aim[1])), pending.valid)
		if not str(simulation.fault).is_empty():
			return _begin_failure("journal_replay_fault")
		replayed += 1
	if FileAccess.file_exists(_path):
		recovered = _read_journal(_path, snapshot, int(profile.revision))
		if not recovered.ok:
			return _begin_failure(recovered.error)
		if recovered.matching:
			for input: Dictionary in recovered.inputs:
				if input.tick <= simulation.tick:
					continue
				if input.tick != simulation.tick + 1 or simulation.closed:
					return _begin_failure("journal_tick_gap")
				if not _replay_rhythm(simulation, input.get("rhythm_inputs", [])):
					return _begin_failure("journal_invalid_rhythm_input")
				simulation.step(input.aim, input.valid)
				if not str(simulation.fault).is_empty():
					return _begin_failure("journal_replay_fault")
				replayed += 1
	# Keep the original anchor and complete record history across resumptions.
	# Store.bak can precede the current main checkpoint; rebasing here would make
	# that otherwise valid backup unable to reconstruct the newer battle state.
	var created := _resume_journal(recovered) if recovered.get("matching", false) else _create_journal(snapshot, int(profile.revision))
	if not created.is_empty():
		return _begin_failure(created)
	_open = true
	_worker_error = ""
	# A legacy marker is already durable but has no binary record yet. Materialize
	# it before clearing the marker in a full profile, so backup recovery works too.
	if not pending.is_empty() and _last_tick == int(snapshot.tick):
		var pending_aim: Array = pending.aim
		var appended := append_tick(int(snapshot.tick) + 1, Vector2(float(pending_aim[0]),float(pending_aim[1])),pending.valid,pending.get("rhythm_inputs",[]))
		if not appended.ok:
			return _begin_failure(appended.error)
	if _last_tick != simulation.tick:
		return _begin_failure("journal_checkpoint_gap")
	var restored_profile := profile
	if replayed > 0:
		restored_profile = profile.duplicate(true)
		restored_profile.active_run = simulation.snapshot()
		var saved: Dictionary = storage.save_slot(slot, restored_profile)
		if not saved.ok:
			return _begin_failure(saved.error)
		restored_profile = saved.profile
	appended_ticks = 0
	append_max_usec = 0
	return {"ok": true, "error": "", "profile": restored_profile, "replayed": replayed}


## Must succeed before simulation.step(); failed appends never acknowledge a tick.
func append_tick(tick: int, aim: Vector2, valid: bool, rhythm_inputs: Array = []) -> Dictionary:
	if not _open or _file == null:
		return _error("journal_closed")
	if not _worker_error.is_empty():
		return _error(_worker_error)
	if tick != _last_tick + 1 or tick > MAX_TICKS or (valid and not aim.is_finite()):
		return _error("journal_invalid_tick")
	if not _valid_rhythm_inputs(rhythm_inputs):
		return _error("journal_invalid_rhythm_input")
	var started := Time.get_ticks_usec()
	var payload := PackedByteArray()
	payload.resize(32)
	payload.encode_s64(0, tick)
	payload.encode_double(8, aim.x)
	payload.encode_double(16, aim.y)
	payload[24] = 1 if valid else 0
	payload[25] = rhythm_inputs.size()
	for index in range(rhythm_inputs.size()):
		payload[26 + index] = RHYTHM_KEYS.find(str(rhythm_inputs[index].get("key", ""))) + 1
	var digest := _record_digest(_previous, payload)
	var record := payload
	record.append_array(digest)
	_file.store_buffer(record)
	_file.flush()
	if _file.get_error() != OK:
		_worker_error = "journal_write_failed"
		return _error(_worker_error)
	_last_tick = tick
	_previous = digest
	appended_ticks += 1
	append_max_usec = maxi(append_max_usec, Time.get_ticks_usec() - started)
	return {"ok": true, "error": ""}


## profile must contain the current simulation snapshot and current revision.
## Main-thread copy isolates all mutable dictionaries before Thread.start().
func checkpoint(profile: Dictionary) -> Dictionary:
	if not _open:
		return _error("journal_closed")
	if not _worker_error.is_empty():
		return _error(_worker_error)
	if _thread != null:
		return {"ok": true, "error": "", "started": false}
	var copy := profile.duplicate(true)
	if int(copy.get("active_run", {}).get("tick", -1)) != _last_tick:
		return _error("journal_snapshot_mismatch")
	_thread = Thread.new()
	var status := _thread.start(_save_checkpoint.bind(copy, _store._base_dir, _slot, _lease))
	if status != OK:
		_thread = null
		_worker_error = "journal_worker_failed"
		return _error(_worker_error)
	return {"ok": true, "error": "", "started": true}


func poll() -> Dictionary:
	if _thread == null or _thread.is_alive():
		return {"ok": _worker_error.is_empty(), "error": _worker_error, "completed": false}
	return _collect_checkpoint()


## For pause/settings/bank/exit only. Never call this in the per-frame path.
func finish_checkpoint() -> Dictionary:
	if _thread == null:
		return {"ok": _worker_error.is_empty(), "error": _worker_error, "completed": false}
	return _collect_checkpoint()


func _collect_checkpoint() -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Dictionary = _thread.wait_to_finish()
	var joined := Time.get_ticks_usec()
	collect_wait_max_usec = maxi(collect_wait_max_usec,joined-started)
	_thread = null
	var released := Time.get_ticks_usec()
	collect_release_max_usec = maxi(collect_release_max_usec,released-joined)
	collect_timings.append({"tick":_last_tick,"wait_usec":joined-started,"release_usec":released-joined})
	if not result.ok:
		_worker_error = result.error
		return {"ok": false, "error": result.error, "completed": true}
	return {"ok": true, "error": "", "completed": true, "revision": result.revision}


func _save_checkpoint(profile: Dictionary, base_dir: String, slot: int, lease: Dictionary) -> Dictionary:
	var worker := Store.new(base_dir)
	var saved: Dictionary = worker.save_slot_owned(slot, profile, lease)
	var small_result := {"ok": saved.ok, "error": saved.error, "revision": saved.profile.revision}
	# Thread retains the bound Dictionary until wait_to_finish(). Empty only
	# this worker-owned deep copy while still on the worker; never the lease.
	profile.clear()
	return small_result


## Preserve the log on ordinary close or failed checkpoint. It remains sufficient
## to recover every flushed tick even if the latest full snapshot failed.
func end() -> Dictionary:
	var finished := finish_checkpoint()
	if _file != null:
		_file.close()
		_file = null
	_open = false
	var released: Dictionary = _store.end_battle_session() if _store != null else {"ok": true, "error": ""}
	_lease = {}
	if not finished.ok:
		return finished
	return finished if finished.get("completed", false) else released


## Call after bank_run has committed active_run={} and its idempotent last_result.
func clear_committed() -> Dictionary:
	var finished := finish_checkpoint()
	if not finished.ok:
		return finished
	if _store == null:
		return _error("journal_closed")
	var current: Dictionary = _store.load_slot(_slot)
	if not current.ok or not current.profile.active_run.is_empty() or current.profile.last_result.get("run_id", "") != _run_id:
		return _error("journal_run_not_committed")
	if _file != null:
		_file.close()
		_file = null
	var removed := not FileAccess.file_exists(_path) or DirAccess.remove_absolute(_path) == OK
	var closed := end()
	if not removed:
		# A retained settled-run log is harmless: its run_id cannot match a new run.
		return {"ok": true, "error": "", "cleanup_pending": true}
	return closed


func is_open() -> bool:
	return _open


func _create_journal(snapshot: Dictionary, revision: int) -> String:
	var header := {
		"format_version": FORMAT_VERSION, "run_id": snapshot.run_id,
		"configuration": _identity(snapshot), "start_tick": int(snapshot.tick),
		"anchor_revision": str(revision), "anchor_snapshot": _snapshot_digest(snapshot),
	}
	var header_bytes := JSON.stringify(header, "", true, true).to_utf8_buffer()
	var header_digest := _digest(header_bytes)
	var bytes := MAGIC.to_ascii_buffer()
	var length_bytes := PackedByteArray()
	length_bytes.resize(4)
	length_bytes.encode_u32(0, header_bytes.size())
	bytes.append_array(length_bytes)
	bytes.append_array(header_bytes)
	bytes.append_array(header_digest)
	var temporary := _path + ".tmp." + str(_lease.token)
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return "journal_write_failed"
	output.store_buffer(bytes)
	output.flush()
	var status := output.get_error()
	output.close()
	if status != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary)
		return "journal_write_failed"
	if DirAccess.rename_absolute(temporary, _path) != OK:
		DirAccess.remove_absolute(temporary)
		return "journal_replace_failed"
	_file = FileAccess.open(_path, FileAccess.READ_WRITE)
	if _file == null:
		return "journal_write_failed"
	_file.seek_end()
	_previous = header_digest
	_last_tick = int(snapshot.tick)
	return ""


func _resume_journal(recovered: Dictionary) -> String:
	if int(recovered.get("torn_tail_bytes", 0)) > 0:
		var temporary := _path + ".tmp." + str(_lease.token)
		var output := FileAccess.open(temporary, FileAccess.WRITE)
		if output == null:
			return "journal_write_failed"
		output.store_buffer(recovered.complete_bytes)
		output.flush()
		var status := output.get_error()
		output.close()
		if status != OK or FileAccess.get_file_as_bytes(temporary) != recovered.complete_bytes:
			DirAccess.remove_absolute(temporary)
			return "journal_write_failed"
		if DirAccess.rename_absolute(temporary,_path) != OK:
			DirAccess.remove_absolute(temporary)
			return "journal_replace_failed"
	_file = FileAccess.open(_path, FileAccess.READ_WRITE)
	if _file == null:
		return "journal_write_failed"
	_file.seek_end()
	_previous = recovered.last_digest
	_last_tick = int(recovered.last_tick)
	return ""


func _read_journal(path: String, snapshot: Dictionary, revision: int = -1) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 8).get_string_from_ascii() != MAGIC:
		return _error("journal_corrupt_header")
	var length := bytes.decode_u32(8)
	if length <= 0 or length > MAX_HEADER_BYTES or bytes.size() < 12 + length + 32:
		return _error("journal_corrupt_header")
	var header_bytes := bytes.slice(12, 12 + length)
	var previous := bytes.slice(12 + length, 44 + length)
	if _digest(header_bytes) != previous:
		return _error("journal_corrupt_header")
	var parsed: Variant = JSON.parse_string(header_bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("format_version") != FORMAT_VERSION or not parsed.get("run_id") is String or not parsed.get("configuration") is String or not parsed.get("anchor_snapshot") is String or not parsed.get("anchor_revision") is String:
		return _error("journal_unsupported_header")
	if parsed.run_id != snapshot.get("run_id", ""):
		return {"ok": true, "error": "", "matching": false, "inputs": []}
	if parsed.configuration != _identity(snapshot):
		return _error("journal_configuration_mismatch")
	var start_value: Variant = parsed.get("start_tick")
	if not (start_value is int or start_value is float) or not is_finite(float(start_value)) or start_value != floor(start_value) or start_value < -1 or start_value > MAX_TICKS:
		return _error("journal_corrupt_header")
	if not parsed.anchor_revision.is_valid_int() or str(int(parsed.anchor_revision)) != parsed.anchor_revision or int(parsed.anchor_revision) < 1:
		return _error("journal_corrupt_header")
	if revision >= 0 and int(parsed.anchor_revision) > revision:
		return _error("journal_checkpoint_gap")
	var tick := int(start_value)
	if int(snapshot.tick) < tick:
		return _error("journal_checkpoint_gap")
	if int(snapshot.tick) == tick and not snapshot.has("_pending_tick_input") and parsed.anchor_snapshot != _snapshot_digest(snapshot):
		return _error("journal_anchor_mismatch")
	var position := 44 + length
	var inputs: Array[Dictionary] = []
	while position + RECORD_BYTES <= bytes.size():
		var payload := bytes.slice(position, position + 32)
		var digest := bytes.slice(position + 32, position + RECORD_BYTES)
		if _record_digest(previous, payload) != digest:
			# An entire damaged record (including one at EOF) cannot be identified as
			# an unacknowledged append. Preserve it and stop instead of dropping it.
			return _error("journal_corrupt_record")
		var next_tick := payload.decode_s64(0)
		var aim := Vector2(payload.decode_double(8), payload.decode_double(16))
		if next_tick != tick + 1 or next_tick > MAX_TICKS or payload[24] > 1 or (payload[24] == 1 and not aim.is_finite()):
			return _error("journal_tick_gap")
		var rhythm_inputs: Array = []
		var input_count := int(payload[25])
		if input_count > MAX_RHYTHM_INPUTS:
			return _error("journal_corrupt_record")
		for index in range(MAX_RHYTHM_INPUTS):
			var code := int(payload[26 + index])
			if index < input_count:
				if code < 1 or code > RHYTHM_KEYS.size():
					return _error("journal_corrupt_record")
				rhythm_inputs.append({"key": RHYTHM_KEYS[code - 1], "tick": next_tick})
			elif code != 0:
				return _error("journal_corrupt_record")
		tick = next_tick
		inputs.append({"tick": tick, "aim": aim, "valid": payload[24] == 1, "rhythm_inputs": rhythm_inputs})
		previous = digest
		position += RECORD_BYTES
	# Only a physically incomplete final record is an unacknowledged torn tail.
	return {"ok": true, "error": "", "matching": true, "inputs": inputs, "torn_tail_bytes": bytes.size() - position, "complete_bytes":bytes.slice(0,position), "last_digest":previous, "last_tick":tick}


func _valid_rhythm_inputs(inputs: Variant) -> bool:
	if not inputs is Array or inputs.size() > MAX_RHYTHM_INPUTS:
		return false
	for item: Variant in inputs:
		if not item is Dictionary or not RHYTHM_KEYS.has(item.get("key", "")):
			return false
	return true


func _replay_rhythm(simulation: RefCounted, inputs: Variant) -> bool:
	if not _valid_rhythm_inputs(inputs):
		return false
	if not inputs.is_empty() and not simulation.has_method("submit_rhythm_key"):
		return false
	for item: Dictionary in inputs:
		simulation.submit_rhythm_key(str(item.key))
	return true


func _identity(snapshot: Dictionary) -> String:
	var identity := {}
	for key in ["run_id", "seed", "snapshot_version", "rules_version", "simulation_version", "build_id", "balance_version", "rng_version", "run_options"]:
		identity[key] = snapshot.get(key)
	return JSON.stringify(identity, "", true, true).sha256_text()


func _snapshot_digest(snapshot: Dictionary) -> String:
	var clean := snapshot.duplicate(false)
	clean.erase("_pending_tick_input")
	return JSON.stringify(clean, "", true, true).sha256_text()


func _record_digest(previous: PackedByteArray, payload: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(previous)
	hashing.update(payload)
	return hashing.finish()


func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()


func _begin_failure(error: String) -> Dictionary:
	if _file != null:
		_file.close()
		_file = null
	_open = false
	_store.end_battle_session()
	_lease = {}
	return _error(error)


func _error(error: String) -> Dictionary:
	return {"ok": false, "error": error}
