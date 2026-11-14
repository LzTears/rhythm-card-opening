extends RefCounted
## Free start and 15..42 tick inputs; each call keeps its 120 BPM cycle floor.
## Perfect is one executable four-word phrase, anchored by its first input.
const VERSION := 19
const BPM := 120
const GameConfig = preload("res://scripts/game_config.gd")
const RUN_TICKS := GameConfig.RUN_TICKS
const BEAT_TICKS := 30
const PHRASE_LENGTH := 4
const PHRASE_TICKS := BEAT_TICKS * PHRASE_LENGTH
const MIN_INPUT_TICKS := 15
const MAX_INPUT_TICKS := 42
const PERFECT_WINDOW_TICKS := 6
## Only this duration is tuned; the window uses the simulation clock.
const COMBO_HANDOFF_SECONDS := 2
const COMBO_HANDOFF_TICKS := COMBO_HANDOFF_SECONDS * GameConfig.TICK_RATE
const FEVER_BASE_THRESHOLD := 5
const FEVER_MIN_THRESHOLD := 2
const FEVER_ENERGY_MAX := 10
const MAX_KEYS_PER_TICK := 6
const MAX_COMMANDS := RUN_TICKS * MAX_KEYS_PER_TICK / PHRASE_LENGTH
const KEYS := ["pata", "pon", "don", "chaka"]
const PRESETS := {"gather": ["pata", "pata", "pata", "pon"], "expand": ["pon", "pon", "pata", "pon"], "merge": ["chaka", "chaka", "pata", "pon"], "fever": ["don", "don", "pata", "pon"]}
## Keep the historical routing key merge; its command now opens the circle.
const LABELS := {"gather": "聚拢", "expand": "扩圈", "merge": "圈内开卡", "fever": "爆发"}
const COMMAND_KINDS := {"gather":"gather","expand":"expand","merge":"circle_open","fever":"fever"}
var enabled := true
var buffer: Array[String] = []
var buffer_ticks: Array[int] = []
var sequence: Array[String] = []
var preset_id := ""
var recognized := false
var command_executed := false
var command_status := "pending"
var command_stage := "idle"
var command_serial := 0
var resolved_count := 0
var last_command_tick := -1
var last_input_tick := -1
var last_tick := -1
var total_valid := 0
var total_perfect := 0
var total_miss := 0
var total_wrong := 0
var successful_phrases := 0
var unknown_phrases := 0
var incomplete_phrases := 0
var executed_commands := 0
var phrase_combo := 0
var max_phrase_combo := 0
var basic_chain := 0
var fever_active := false
var fever_threshold := FEVER_BASE_THRESHOLD
var fever_energy_max := FEVER_ENERGY_MAX
var initial_fever_energy := 0
var fever_energy := 0
var fever_activations := 0
var fever_casts := 0
var combo_handoff_start_tick := -1
var combo_handoff_deadline_tick := -1
var last_judgement: Dictionary = {}
var queued_judgements: Array[Dictionary] = []
var queued_commands: Array[int] = []
var phrase_history: Array[Dictionary] = []
var command_event: Dictionary = {}
var last_command: Dictionary = {}
var active_echo: Dictionary = {}
var response_event: Dictionary = {}
var input_log: Array[Dictionary] = []
var resolution_log: Array[Dictionary] = []
var closed := false
var _seed_value := 0
var _input_tick := -1
var _input_count := 0


static func preset_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in PRESETS: ids.append(id)
	return ids


static func preset_sequence(id: String) -> Array[String]:
	var tokens: Array[String] = []
	for key: String in PRESETS.get(id, []): tokens.append(key)
	return tokens


static func preset_definition(id: String) -> Dictionary:
	return {"id": id, "preset_id": id, "command_kind":COMMAND_KINDS[id], "label": LABELS[id], "sequence": preset_sequence(id), "phrase_length": 4, "bpm": BPM, "duration_ticks": 150} if PRESETS.has(id) else {}


static func preset_for_sequence(tokens: Array) -> String:
	for id: String in PRESETS:
		if tokens == PRESETS[id]: return id
	return ""


static func preset_lengths() -> Array[int]:
	return [4]


func start(options: Dictionary, seed_value: int = 0) -> void:
	enabled = bool(options.get("rhythm_enabled", true))
	fever_threshold = clampi(int(options.get("rhythm_fever_threshold",FEVER_BASE_THRESHOLD)),FEVER_MIN_THRESHOLD,FEVER_BASE_THRESHOLD)
	fever_energy_max = clampi(int(options.get("rhythm_fever_energy_max",FEVER_ENERGY_MAX)),7,FEVER_ENERGY_MAX)
	initial_fever_energy = clampi(int(options.get("initial_fever_energy",0)),0,2)
	fever_energy = initial_fever_energy
	_seed_value = seed_value
	for field in ["buffer", "buffer_ticks", "sequence", "queued_judgements", "queued_commands", "phrase_history", "input_log", "resolution_log"]: get(field).clear()
	for field in ["last_judgement", "command_event", "last_command", "active_echo", "response_event"]: get(field).clear()
	for field in ["command_serial", "resolved_count", "total_valid", "total_perfect", "total_miss", "total_wrong", "successful_phrases", "unknown_phrases", "incomplete_phrases", "executed_commands", "phrase_combo", "max_phrase_combo", "basic_chain", "fever_activations", "fever_casts", "_input_count"]: set(field, 0)
	last_tick = -1
	last_command_tick = -1
	last_input_tick = -1
	_clear_combo_handoff()
	_input_tick = -1
	preset_id = ""
	recognized = false
	command_executed = false
	command_status = "pending"
	command_stage = "idle"
	fever_active = false
	closed = false


func _miss(at_tick: int, reason: String, key: String = "") -> void:
	var slot := buffer.size()
	buffer.clear()
	buffer_ticks.clear()
	last_input_tick = -1
	_clear_combo_handoff()
	total_miss += 1
	incomplete_phrases += 1
	basic_chain = 0
	fever_active = false
	phrase_combo = 0
	last_judgement = {"type": "rhythm_judgement", "accepted": false, "grade": "miss", "reason": reason, "key": key, "expected": "", "beat": slot, "word_index": slot, "tick": at_tick, "input_index": total_valid, "offset": 0}
	queued_judgements.append(last_judgement.duplicate(true))


func _expire_input(at_tick: int, before_step: bool) -> bool:
	if buffer.is_empty(): return false
	var elapsed := at_tick - last_input_tick
	if elapsed > MAX_INPUT_TICKS or (not before_step and elapsed == MAX_INPUT_TICKS):
		_miss(last_input_tick + MAX_INPUT_TICKS, "timeout")
		return true
	return false


func _clear_combo_handoff() -> void:
	combo_handoff_start_tick = -1
	combo_handoff_deadline_tick = -1


func _can_wait_for_combo_handoff() -> bool:
	return enabled and not closed and phrase_combo>0 and buffer.is_empty() and active_echo.is_empty() and queued_commands.is_empty() and resolved_count==command_serial


func _begin_combo_handoff(at_tick: int) -> void:
	_clear_combo_handoff()
	if not _can_wait_for_combo_handoff(): return
	combo_handoff_start_tick = at_tick
	combo_handoff_deadline_tick = at_tick + COMBO_HANDOFF_TICKS


func _expire_combo_handoff(at_tick: int) -> void:
	if combo_handoff_deadline_tick<0: return
	if not _can_wait_for_combo_handoff():
		_clear_combo_handoff()
		return
	# Inputs are submitted before advance, including on this final boundary.
	# A first accepted word clears the wait before this check can emit a Miss.
	if at_tick>=combo_handoff_deadline_tick:
		_miss(combo_handoff_deadline_tick,"handoff_timeout")


func _finish_echo(at_tick: int) -> void:
	if active_echo.is_empty() or at_tick < int(active_echo.end_tick): return
	var completed_at := int(active_echo.end_tick)
	var row: Dictionary = phrase_history[int(active_echo.command_serial) - 1]
	row.stage = "complete"
	_update_latest(row)
	queued_judgements.append({"type":"rhythm_complete", "tick":int(active_echo.end_tick), "command_serial":int(row.command_serial), "preset_id":row.preset_id, "command_kind":COMMAND_KINDS.get(row.preset_id,""), "executed":true, "stage":"complete"})
	active_echo.clear()
	_begin_combo_handoff(completed_at)


func submit(key: String, at_tick: int) -> Dictionary:
	if not enabled: return {"accepted": false, "reason": "disabled", "tick": at_tick}
	if key not in KEYS: return {"accepted": false, "reason": "invalid_key", "tick": at_tick}
	if closed or at_tick >= RUN_TICKS: return {"accepted": false, "reason": "closed", "tick": at_tick}
	if at_tick != last_tick + 1: return {"accepted": false, "reason": "wrong_tick", "tick": at_tick}
	if _input_tick != at_tick:
		_input_tick = at_tick
		_input_count = 0
	if _input_count >= MAX_KEYS_PER_TICK: return {"accepted": false, "reason": "input_capacity", "tick": at_tick}
	_input_count += 1
	input_log.append({"key": key, "tick": at_tick})
	_finish_echo(at_tick)
	if not active_echo.is_empty(): return {"accepted": false, "reason": "respond", "tick": at_tick}
	if not queued_commands.is_empty() or resolved_count<command_serial: return {"accepted": false, "reason": "pending", "tick": at_tick}
	var restarted := _expire_input(at_tick, true)
	var delta := at_tick - last_input_tick if last_input_tick >= 0 else -1
	if not buffer.is_empty() and delta < MIN_INPUT_TICKS:
		_miss(at_tick, "too_fast", key)
		return {"accepted": false, "reason": "too_fast", "grade": "miss", "tick": at_tick}
	var slot := buffer.size()
	if slot==0: _clear_combo_handoff()
	buffer.append(key)
	buffer_ticks.append(at_tick)
	last_input_tick = at_tick
	total_valid += 1
	var grade := "input" if delta < 0 else "good"
	last_judgement = {"type": "rhythm_judgement", "accepted": true, "grade": grade, "reason": "restart_after_timeout" if restarted else "input", "key": key, "expected": "", "beat": slot, "word_index": slot, "tick": at_tick, "input_index": total_valid, "offset": delta}
	queued_judgements.append(last_judgement.duplicate(true))
	if buffer.size() == PHRASE_LENGTH:
		command_serial += 1
		last_command_tick = at_tick
		sequence.assign(buffer)
		preset_id = preset_for_sequence(sequence)
		recognized = not preset_id.is_empty()
		var row := {"type": "rhythm_command", "serial": command_serial, "command_serial": command_serial, "id": preset_id, "preset_id": preset_id, "command_kind":COMMAND_KINDS.get(preset_id,""), "label": LABELS.get(preset_id, "未知指令"), "recognized": recognized, "valid": recognized, "executed": false, "status": "queued", "reason": "queued", "stage": "queued", "sequence": sequence.duplicate(), "input_ticks": buffer_ticks.duplicate(), "phrase_length": 4, "tick": at_tick}
		row["perfect_candidate"] = _anchored_perfect(buffer_ticks)
		row["perfect"] = false
		phrase_history.append(row)
		queued_commands.append(command_serial)
		_update_latest(row)
		buffer.clear()
		buffer_ticks.clear()
		last_input_tick = -1
	return last_judgement.duplicate(true)


func _update_latest(row: Dictionary) -> void:
	if int(row.command_serial) != command_serial: return
	last_command = row.duplicate(true)
	command_event = row.duplicate(true)
	preset_id = str(row.preset_id)
	recognized = row.recognized
	command_executed = row.executed
	command_status = str(row.status)
	command_stage = str(row.stage)


static func _anchored_perfect(ticks: Array) -> bool:
	if ticks.size() != PHRASE_LENGTH: return false
	for index in range(1,PHRASE_LENGTH):
		if absi(int(ticks[index])-int(ticks[0])-BEAT_TICKS*index)>PERFECT_WINDOW_TICKS: return false
	return true


func take_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for serial: int in queued_commands: result.append(phrase_history[serial - 1].duplicate(true))
	queued_commands.clear()
	return result


func resolve_command(serial: int, allow: bool, reason: String = "") -> Dictionary:
	if serial != resolved_count + 1 or serial > phrase_history.size(): return {}
	resolution_log.append({"serial": serial, "tick": last_tick, "allow": allow, "reason": reason})
	var row: Dictionary = phrase_history[serial - 1]
	var id := str(row.preset_id)
	# Fast legal inputs may finish early, but cannot move the response or the
	# next sentence ahead of the first input's four-beat 120 BPM reference.
	var echo_start := maxi(int(row.tick) + BEAT_TICKS, int(row.input_ticks[0]) + PHRASE_TICKS)
	var echo_end := echo_start + PHRASE_TICKS
	if not row.recognized:
		allow = false
		reason = "unknown"
		unknown_phrases += 1
		basic_chain = 0
		phrase_combo = 0
		fever_active = false
	else:
		# An understood but unavailable Fever is a neutral blocked command.
		# Its four input words are complete, so the next sentence starts freely;
		# it neither impersonates a successful sentence nor causes a cadence miss.
		if id == "fever" and not fever_active:
			allow = false
			reason = "no_fever"
		elif echo_end > RUN_TICKS:
			allow = false
			reason = "deadline"
	if allow:
		row.perfect = bool(row.get("perfect_candidate",false))
		if row.perfect:
			total_perfect += 1
			# Resolution is after advance in the production tick. Return the committed
			# judgement with this row so Simulation presents it in this same tick,
			# rather than queueing a stale input event for the following tick.
			last_judgement = {"type":"rhythm_judgement","accepted":true,"grade":"perfect","reason":"whole_phrase","scope":"phrase","key":str(row.sequence[3]),"expected":"","beat":3,"word_index":3,"tick":int(row.tick),"input_index":total_valid,"offset":int(row.input_ticks[3])-int(row.input_ticks[2]),"command_serial":serial,"phrase_length":PHRASE_LENGTH,"sequence":row.sequence.duplicate(),"input_ticks":row.input_ticks.duplicate()}
			row["perfect_judgement"] = last_judgement.duplicate(true)
		active_echo = {"serial": serial, "command_serial": serial, "preset_id": id, "command_kind":COMMAND_KINDS[id], "mode": id, "sequence": row.sequence.duplicate(), "completed_tick": int(row.tick), "start_tick": echo_start, "end_tick": echo_end, "started": false, "beat": -1,"fever_full_cast":false}
		row["echo_start_tick"] = echo_start
		row["echo_end_tick"] = echo_end
		row.status = "scheduled"
		row.reason = "scheduled"
		row.stage = "scheduled"
	else:
		row.status = "blocked" if row.recognized else "unknown"
		row.reason = reason if not reason.is_empty() else "busy"
		row.stage = "blocked"
	resolved_count += 1
	if not allow: _begin_combo_handoff(last_tick)
	_update_latest(row)
	return row.duplicate(true)


func advance(at_tick: int) -> Array[Dictionary]:
	if at_tick >= RUN_TICKS:
		close_run()
		return []
	last_tick = at_tick
	_finish_echo(at_tick)
	_expire_input(at_tick, false)
	_expire_combo_handoff(at_tick)
	var events: Array[Dictionary] = []
	for event: Dictionary in queued_judgements: events.append(event.duplicate(true))
	queued_judgements.clear()
	if active_echo.is_empty(): return events
	var first := int(active_echo.start_tick)
	if at_tick < first or (at_tick - first) % BEAT_TICKS != 0: return events
	var beat := (at_tick - first) / BEAT_TICKS
	if beat > 3 or beat <= int(active_echo.beat): return events
	active_echo.beat = beat
	var row: Dictionary = phrase_history[int(active_echo.command_serial) - 1]
	var energy_before := fever_energy
	if beat == 0:
		active_echo.started = true
		# The whole sentence owns one immutable attack scope. A final charge
		# earned on its final beat can only power the following Fever sentence.
		active_echo.fever_full_cast = row.preset_id == "fever" and fever_active and fever_energy == fever_energy_max
		row["fever_full_cast"] = active_echo.fever_full_cast
		row.executed = true
		row.status = "recognized"
		row.reason = "executed"
		row.stage = "started"
		executed_commands += 1
		if row.preset_id == "fever": fever_casts += 1
		_update_latest(row)
		events.append(row.duplicate(true))
	elif beat == 3:
		row.stage = "impact"
		successful_phrases += 1
		phrase_combo += 1
		max_phrase_combo = maxi(max_phrase_combo,phrase_combo)
		# Historical basic_chain remains a compatibility counter. All four
		# legitimate commands now contribute to the same continuous Combo.
		basic_chain += 1
		if phrase_combo >= fever_threshold and not fever_active:
			fever_active = true
			fever_activations += 1
		fever_energy = 0 if active_echo.fever_full_cast else mini(fever_energy_max,fever_energy + 1)
		_update_latest(row)
	response_event = {"type": "rhythm_response", "phase": "respond", "serial": int(row.serial), "command_serial": int(row.serial), "preset_id": row.preset_id, "command_kind":COMMAND_KINDS[row.preset_id], "mode": row.preset_id, "key": row.sequence[beat], "beat": beat, "word_index": beat, "tick": at_tick, "executed": true, "stage": ["started", "respond", "windup", "impact"][beat],"perfect":bool(row.get("perfect",false)),"fever_full_cast":active_echo.fever_full_cast,"global_burst":active_echo.fever_full_cast,"fever_energy":fever_energy,"fever_energy_max":fever_energy_max,"fever_threshold":fever_threshold}
	events.append(response_event.duplicate(true))
	if beat == 3:
		events.append({"type":"fever_energy","tick":at_tick,"command_serial":int(row.serial),"preset_id":row.preset_id,"energy_before":energy_before,"fever_energy":fever_energy,"energy_after":fever_energy,"fever_energy_max":fever_energy_max,"delta":fever_energy - energy_before,"consumed":bool(active_echo.fever_full_cast),"fever_full_cast":active_echo.fever_full_cast,"fever_threshold":fever_threshold})
	return events


func close_run() -> void:
	closed = true
	_finish_echo(RUN_TICKS)
	_clear_combo_handoff()


func valid_beats() -> int:
	return buffer.size()


func perfect_beats() -> int:
	return total_perfect


func state() -> Dictionary:
	var slots: Array[String] = []
	slots.assign(buffer)
	while slots.size() < 4: slots.append("")
	var phase := "respond" if not active_echo.is_empty() else ("input" if not buffer.is_empty() else "idle")
	var next_echo := -1
	if not active_echo.is_empty() and int(active_echo.beat) < 3: next_echo = int(active_echo.start_tick) + (int(active_echo.beat) + 1) * BEAT_TICKS
	var deadline := last_input_tick + MAX_INPUT_TICKS if not buffer.is_empty() else -1
	return {"enabled": enabled, "phase": phase, "bpm": BPM, "beat_ticks": BEAT_TICKS, "cycle_ticks": 0, "beat": buffer.size(), "beat_progress": 0.0, "phrase_length": 4,
		"combo_handoff_ticks":COMBO_HANDOFF_TICKS,"combo_handoff_start_tick":combo_handoff_start_tick,"combo_handoff_deadline_tick":combo_handoff_deadline_tick,"combo_handoff_waiting":combo_handoff_deadline_tick>=0,"combo_handoff_remaining_ticks":maxi(0,combo_handoff_deadline_tick-last_tick) if combo_handoff_deadline_tick>=0 else 0,
		"slots": slots, "buffer": buffer.duplicate(), "buffer_ticks": buffer_ticks.duplicate(), "sequence": sequence.duplicate(), "preset_id": preset_id,
		"command_serial": command_serial, "last_command_tick": last_command_tick, "last_input_tick": last_input_tick,
		"next_input_min_tick": last_input_tick + MIN_INPUT_TICKS if not buffer.is_empty() else -1, "deadline_tick": deadline, "next_input_deadline_tick": deadline, "remaining_ticks": maxi(0, deadline - last_tick) if deadline >= 0 else 0,
		"next_beat_tick": next_echo, "active_echo": active_echo.duplicate(true), "response_event": response_event.duplicate(true), "recognized": recognized, "command_executed": command_executed,
		"command_status": command_status, "command_stage": command_stage, "command_event": command_event.duplicate(true), "last_command": last_command.duplicate(true),
		"last_judgement": last_judgement.duplicate(true), "valid_beats": total_valid, "perfect_beats": total_perfect, "perfect_phrases":total_perfect, "total_valid": total_valid, "total_perfect": total_perfect, "total_miss": total_miss, "total_wrong": 0,
		"successful_phrases": successful_phrases, "unknown_phrases": unknown_phrases, "incomplete_phrases": incomplete_phrases, "executed_commands": executed_commands,
		"phrase_combo": phrase_combo, "max_phrase_combo": max_phrase_combo, "basic_chain": basic_chain, "fever_active": fever_active,"fever_ready":fever_active,"fever_command_available":fever_active,"fever_threshold":fever_threshold,"fever_energy":fever_energy,"fever_energy_max":fever_energy_max,"initial_fever_energy":initial_fever_energy,"fever_full_cast":bool(active_echo.get("fever_full_cast",false)), "can_fever": fever_active and fever_energy == fever_energy_max, "fever_activations": fever_activations, "fever_casts": fever_casts, "response_label": LABELS.get(preset_id, "自由起手"), "tick": last_tick}


func snapshot() -> Dictionary:
	return {"version": VERSION, "enabled": enabled, "seed": str(_seed_value), "closed": closed,"fever_threshold":fever_threshold,"fever_energy":fever_energy,"fever_energy_max":fever_energy_max,"initial_fever_energy":initial_fever_energy,
		"combo_handoff_ticks":COMBO_HANDOFF_TICKS,"combo_handoff_start_tick":combo_handoff_start_tick,"combo_handoff_deadline_tick":combo_handoff_deadline_tick,
		"buffer": buffer.duplicate(), "buffer_ticks": buffer_ticks.duplicate(), "sequence": sequence.duplicate(), "command_serial": command_serial, "resolved_count": resolved_count,
		"last_tick": last_tick, "last_input_tick": last_input_tick, "last_command_tick": last_command_tick, "input_tick": _input_tick, "input_count": _input_count,
		"total_valid": total_valid, "total_perfect": total_perfect, "total_miss": total_miss, "successful_phrases": successful_phrases, "unknown_phrases": unknown_phrases, "incomplete_phrases": incomplete_phrases,
		"executed_commands": executed_commands, "phrase_combo": phrase_combo, "max_phrase_combo": max_phrase_combo, "basic_chain": basic_chain, "fever_active": fever_active, "fever_activations": fever_activations, "fever_casts": fever_casts,
		"phrase_history": phrase_history.duplicate(true), "queued_commands": queued_commands.duplicate(), "last_judgement": last_judgement.duplicate(true), "queued_judgements": queued_judgements.duplicate(true),
		"command_event": command_event.duplicate(true), "last_command": last_command.duplicate(true), "active_echo": active_echo.duplicate(true), "response_event": response_event.duplicate(true), "input_log": input_log.duplicate(true), "resolution_log": resolution_log.duplicate(true)}


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= maximum


static func _same(left: Variant, right: Variant) -> bool:
	if right is int or right is float: return (left is int or left is float) and is_finite(float(left)) and left == right
	if right is Dictionary:
		if not left is Dictionary or left.size() != right.size(): return false
		for key in right:
			if not left.has(key) or not _same(left[key], right[key]): return false
		return true
	if right is Array:
		if not left is Array or left.size() != right.size(): return false
		for index in right.size():
			if not _same(left[index], right[index]): return false
		return true
	return typeof(left) == typeof(right) and left == right


static func _replay(data: Dictionary, sim_tick: int, seed_value: int):
	if not data.get("input_log") is Array or not data.get("resolution_log") is Array or data.input_log.size() > RUN_TICKS * MAX_KEYS_PER_TICK or data.resolution_log.size() > MAX_COMMANDS: return null
	var previous := -1
	var per_tick := 0
	for attempt: Variant in data.input_log:
		if not attempt is Dictionary or attempt.size() != 2 or attempt.get("key") not in KEYS or not _whole(attempt.get("tick"), 0, mini(RUN_TICKS - 1, sim_tick + 1)) or int(attempt.tick) < previous: return null
		per_tick = per_tick + 1 if int(attempt.tick) == previous else 1
		if per_tick > MAX_KEYS_PER_TICK: return null
		previous = int(attempt.tick)
	for entry: Variant in data.resolution_log:
		if not entry is Dictionary or entry.size() != 4 or not _whole(entry.get("serial"), 1, MAX_COMMANDS) or not _whole(entry.get("tick"), 0, mini(RUN_TICKS - 1, sim_tick)) or not entry.get("allow") is bool or not entry.get("reason") is String: return null
	var script := load("res://scripts/rhythm_conductor.gd") as Script
	var replay = script.new()
	replay.start({"rhythm_enabled": data.get("enabled", true),"rhythm_fever_threshold":data.get("fever_threshold",FEVER_BASE_THRESHOLD),"rhythm_fever_energy_max":data.get("fever_energy_max",FEVER_ENERGY_MAX),"initial_fever_energy":data.get("initial_fever_energy",0)}, seed_value)
	var input_cursor := 0
	var resolution_cursor := 0
	for at_tick in range(mini(sim_tick, RUN_TICKS - 1) + 1):
		while input_cursor < data.input_log.size() and int(data.input_log[input_cursor].tick) == at_tick:
			replay.submit(str(data.input_log[input_cursor].key), at_tick)
			input_cursor += 1
		replay.advance(at_tick)
		for command: Dictionary in replay.take_commands():
			if resolution_cursor >= data.resolution_log.size(): return null
			var entry: Dictionary = data.resolution_log[resolution_cursor]
			if entry.serial != command.serial or entry.tick != at_tick: return null
			replay.resolve_command(int(entry.serial), entry.allow, str(entry.reason))
			resolution_cursor += 1
	while input_cursor < data.input_log.size():
		if int(data.input_log[input_cursor].tick) != sim_tick + 1: return null
		replay.submit(str(data.input_log[input_cursor].key), sim_tick + 1)
		input_cursor += 1
	if resolution_cursor != data.resolution_log.size(): return null
	if sim_tick >= RUN_TICKS: replay.close_run()
	return replay


static func valid_snapshot(data: Variant, sim_tick: int, seed_value: int = 0) -> bool:
	if not data is Dictionary or data.get("version") != VERSION or not data.get("enabled") is bool or data.get("seed") != str(seed_value) or not _whole(sim_tick, -1, RUN_TICKS) or not _whole(data.get("fever_threshold"),FEVER_MIN_THRESHOLD,FEVER_BASE_THRESHOLD) or not _whole(data.get("fever_energy_max"),7,FEVER_ENERGY_MAX) or not _whole(data.get("initial_fever_energy"),0,2) or not _whole(data.get("fever_energy"),0,int(data.get("fever_energy_max",FEVER_ENERGY_MAX))): return false
	if data.get("combo_handoff_ticks")!=COMBO_HANDOFF_TICKS or not _whole(data.get("combo_handoff_start_tick"),-1,RUN_TICKS) or not _whole(data.get("combo_handoff_deadline_tick"),-1,RUN_TICKS+COMBO_HANDOFF_TICKS): return false
	var replay = _replay(data, sim_tick, seed_value)
	return replay != null and _same(data, replay.snapshot())


func restore(data: Dictionary) -> void:
	if data.get("version") != VERSION: return
	var sim_tick := RUN_TICKS if data.closed else int(data.last_tick)
	var replay = _replay(data, sim_tick, String(data.seed).to_int())
	if replay == null: return
	for field in ["enabled", "buffer", "buffer_ticks", "sequence", "preset_id", "recognized", "command_executed", "command_status", "command_stage", "command_serial", "resolved_count", "last_command_tick", "last_input_tick", "last_tick", "total_valid", "total_perfect", "total_miss", "total_wrong", "successful_phrases", "unknown_phrases", "incomplete_phrases", "executed_commands", "phrase_combo", "max_phrase_combo", "basic_chain", "fever_active","fever_threshold","fever_energy_max","initial_fever_energy","fever_energy", "fever_activations", "fever_casts", "combo_handoff_start_tick", "combo_handoff_deadline_tick", "last_judgement", "queued_judgements", "queued_commands", "phrase_history", "command_event", "last_command", "active_echo", "response_event", "input_log", "resolution_log", "closed", "_seed_value", "_input_tick", "_input_count"]: set(field, replay.get(field))
