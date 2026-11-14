extends RefCounted
## Renderer-independent authority. Tick is the last completed simulation boundary.
const Rules = preload("res://scripts/pack_rules.gd")
const AttackSpec = preload("res://scripts/attack_spec.gd")
const RhythmConductor = preload("res://scripts/rhythm_conductor.gd")
const CollectionRules = preload("res://scripts/collection_rules.gd")
const SNAPSHOT_VERSION := 20
const RULES_VERSION := Rules.RULES_VERSION
const BUILD_ID := Rules.BUILD_ID
const BALANCE_VERSION := Rules.BALANCE_VERSION
const RUN_TICKS := Rules.RUN_TICKS
const CHARGE_PERIOD := Rules.BASE_CHARGE_PERIOD
const INITIAL_TARGETS := Rules.BASE_INITIAL_COUNT
const BASE_CAPACITY := Rules.BASE_CAPACITY
const SHOT_DAMAGE := Rules.BASE_SHOT_DAMAGE
const SHOT_RADIUS := Rules.SHOT_RADIUS
const PACK_RADIUS := Rules.PACK_RADIUS
const PACK_MOVE_INSET := Rules.PACK_MOVE_INSET
const MOTION_SALT := 0x6A09E667F3BCC909
const LOOT_SALT := 0x3C6EF372FE94F82B
const GATHER_SALT := 0x510E527FADE682D1
const COIN_DENOMINATOR := 100000000

var tick := -1
var targets: Array[Dictionary] = []
var loot: Dictionary = {}
var score := 0
## Integer fixed-point carry belongs to this run, including snapshot replay.
var _coin_numerator_total := 0
var shots := 0
var closed := false
var run_id := ""
var charge_ticks := 0
var capacity := BASE_CAPACITY
var destroyed_pack_count := 0
var run_options: Dictionary = {}
var dispensers: Array[Dictionary] = []
var current_charge_period := CHARGE_PERIOD
var charge_cells := 0
var charge_remainder := 0
var haste_marks := 0
var haste_queue := 0
var fault := ""
var diagnostics: Array[String] = []
var pending: Array[Dictionary] = []
var roots: Dictionary = {}
var root_limits: Dictionary = {}
var expand_stacks := 0
var _seed_value := 0
var _spawn_rng := RandomNumberGenerator.new()
var _motion_rng := RandomNumberGenerator.new()
var _loot_rng := RandomNumberGenerator.new()
var _gather_rng := RandomNumberGenerator.new()
var _rhythm := RhythmConductor.new()
var _next_target_id := 1
var _next_event_id := 1
var _refill_count := 0
var _refill_cursor := 0
var _reward_ledger: Array[Dictionary] = []
var _rhythm_stats: Dictionary = {}
var _rhythm_last_response: Dictionary = {}
var _preview_ids: Array[int] = []
## A real first response beat commits one random selection for this sentence.
## Rendering and preview queries never advance the authoritative RNG.
var _gather_plan: Dictionary = {}
var _current_command: Dictionary = {}
var _last_effect_feedback: Dictionary = {}
## Dirty work is caused by committed spatial changes, never by idle polling.
var _auto_merge_triggers: Array[String] = []
var _auto_merge_due_tick := -1
var _auto_merge_source_serial := 0
var _burst_target_ids: Array[int] = []
var _burst_locked := false


func start(seed_value: int, run_identifier: String, options: Dictionary = {}) -> bool:
	var frozen := Rules.build_run_options() if options.is_empty() else options.duplicate(true)
	if run_identifier.is_empty() or not Rules.validate_run_options(frozen): return false
	run_options = frozen.duplicate(true)
	tick = -1
	run_id = run_identifier
	_seed_value = seed_value
	_spawn_rng.seed = seed_value
	_motion_rng.seed = seed_value ^ MOTION_SALT
	_loot_rng.seed = seed_value ^ LOOT_SALT
	_gather_rng.seed = seed_value ^ GATHER_SALT
	targets.clear()
	loot.clear()
	score = 0
	_coin_numerator_total = 0
	shots = 0
	closed = false
	charge_ticks = 0
	charge_cells = 0
	charge_remainder = 0
	haste_marks = 0
	haste_queue = 0
	current_charge_period = CHARGE_PERIOD
	capacity = int(frozen.capacity)
	destroyed_pack_count = 0
	expand_stacks = int(frozen.initial_expand_stacks)
	fault = ""
	diagnostics.clear()
	pending.clear()
	roots.clear()
	root_limits.clear()
	_next_target_id = 1
	_next_event_id = 1
	_refill_count = 0
	_refill_cursor = 0
	_reward_ledger.clear()
	_preview_ids.clear()
	_gather_plan.clear()
	_current_command.clear()
	_last_effect_feedback.clear()
	_rhythm_last_response.clear()
	_auto_merge_triggers.clear()
	_auto_merge_due_tick = -1
	_auto_merge_source_serial = 0
	_burst_target_ids.clear()
	_burst_locked = false
	_rhythm_stats = {"responses":0,"main_strikes":0,"circle_open_strikes":0,"pulls":0,"merged_groups":0,"gather":0,"expand":0,"merge":0,"fever":0,"refills":0,"refilled_packs":0}
	_rhythm.start(frozen,seed_value)
	dispensers.clear()
	for id: String in frozen.dispenser_ids:
		dispensers.append({"id":id,"period":0,"phase":0,"next_emit_tick":-1})
	# The preparation scene has already landed the initial supply; battle time
	# begins with all packs stationary. Later supply is an actual 12-tick transit.
	for index in range(int(frozen.initial_count)):
		_spawn_pack(String(frozen.dispenser_ids[index % 3]),-1,true)
	_request_auto_merge("initial_landing",0)
	return true


func step(_aim: Vector2, _valid: bool = true) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if closed or run_options.is_empty() or not fault.is_empty(): return events
	if tick + 1 >= RUN_TICKS:
		tick = RUN_TICKS
		closed = true
		_rhythm.close_run()
		events.append(_event("finished"))
		return events
	tick += 1
	for target in targets:
		if _move_target(target) and is_inside_circle(target.pos): _request_auto_merge("landing",tick)
	_flush_auto_merge(events)
	_step_rhythm(events)
	_flush_auto_merge(events)
	return events


func _event(kind: String) -> Dictionary:
	var result := {"type":kind,"event_version":15,"event_id":_next_event_id,"run_id":run_id,"tick":tick,"executed":true}
	_next_event_id += 1
	return result


func _skill(kind: String, word_index: int) -> Dictionary:
	var event := _event("skill_event")
	event.merge({"kind":kind,"pos":Rules.CIRCLE_CENTER,"radius":circle_radius(),"element":"E01","command_serial":int(_current_command.get("command_serial",0)),
		"preset_id":str(_current_command.get("preset_id","")),"command_kind":str(_current_command.get("command_kind","")),"word_index":word_index,"root_id":shots,"branch_id":0,"root_anchor":Rules.CIRCLE_CENTER,
		"fever_full_cast":bool(_current_command.get("fever_full_cast",false)),"global_burst":bool(_current_command.get("fever_full_cast",false))})
	return event


func submit_rhythm_key(key: String) -> Dictionary:
	if closed or tick + 1 >= RUN_TICKS or not fault.is_empty() or run_options.is_empty(): return {"accepted":false,"reason":"closed","tick":tick + 1}
	return _rhythm.submit(key,tick + 1)


func circle_radius() -> float:
	return AttackSpec.fixed(float(run_options.get("base_circle_radius",Rules.BASE_CIRCLE_RADIUS)) * (1.0 + mini(expand_stacks,int(run_options.get("expand_max_stacks",Rules.EXPAND_MAX_STACKS))) * float(run_options.get("expand_step",Rules.EXPAND_STEP))))


func is_inside_circle(position: Vector2) -> bool:
	return position.distance_squared_to(Rules.CIRCLE_CENTER) <= circle_radius() * circle_radius() + 0.00000001


func get_rhythm_state() -> Dictionary:
	var state := _rhythm.state()
	var locks: Array[Dictionary] = []
	for id in _preview_ids:
		var target := _target_by_id(id)
		if not target.is_empty(): locks.append({"id":id,"pos":_vec(target.pos)})
	state.merge({"aim":_vec(Rules.CIRCLE_CENTER),"target_id":0,"aim_locked":not _rhythm.active_echo.is_empty(),"stats":_rhythm_summary(),
		"response_event":_rhythm_last_response.duplicate(true),"command_radius":circle_radius(),"circle_center":_vec(Rules.CIRCLE_CENTER),
		"base_radius":Rules.BASE_CIRCLE_RADIUS,"circle_radius":circle_radius(),"expand_stacks":expand_stacks,
		"expand_max_stacks":int(run_options.get("expand_max_stacks",Rules.EXPAND_MAX_STACKS)),"expand_step":float(run_options.get("expand_step",Rules.EXPAND_STEP)),"expand_pulses_per_phrase":int(run_options.get("expand_pulses_per_phrase",Rules.EXPAND_PULSES_PER_PHRASE)),
		"gather_count":int(run_options.get("gather_count",2)),"gather_selection":str(run_options.get("gather_selection","random_without_replacement")),"selected_gather_ids":_gather_plan.get("target_ids",[]).duplicate(),"merge_ratio":int(run_options.get("merge_ratio",5)),"shot_damage":int(run_options.get("shot_damage",Rules.BASE_SHOT_DAMAGE)),
		"locked_targets":locks,"burst_targets_locked":_burst_locked,"last_effect_feedback":_last_effect_feedback.duplicate(true),
		"card_grade_counts":CollectionRules.grade_counts(loot)})
	return state


func get_command_spec() -> Dictionary:
	var result: Dictionary = run_options.get("attack_spec",{}).duplicate(true)
	result["circle_radius"] = circle_radius()
	if result.has("presentation_geometry"):
		result.presentation_geometry.radius = circle_radius()
		result.presentation_geometry.width = 2.0 * circle_radius()
	return result


func preview_aim(_aim: Vector2) -> Vector2: return Rules.CIRCLE_CENTER


func _step_rhythm(events: Array[Dictionary]) -> void:
	var was_fever := _rhythm.fever_active
	var emitted := _rhythm.advance(tick)
	for raw: Dictionary in emitted:
		var event := _event(str(raw.type))
		event.merge(raw,true)
		if raw.type == "rhythm_command":
			event["completed_tick"] = int(raw.tick)
			event.tick = tick
		if raw.type == "rhythm_judgement" and raw.get("grade") == "miss":
			_reset_preparation(events,str(raw.get("reason","miss")))
		if raw.type == "rhythm_complete":
			events.append(event)
			_refill(events,int(raw.command_serial))
			_preview_ids.clear()
			_gather_plan.clear()
			continue
		if raw.type != "rhythm_response":
			events.append(event)
			continue
		_current_command = _rhythm.phrase_history[int(raw.command_serial) - 1].duplicate(true)
		var mode := str(raw.preset_id)
		var beat := int(raw.word_index)
		if beat == 0:
			_rhythm_stats[mode] = int(_rhythm_stats[mode]) + 1
			_preview_ids.clear()
			if mode in ["gather","fever"]: _commit_gather_plan()
		event.merge({"pos":Rules.CIRCLE_CENTER,"aim":_vec(Rules.CIRCLE_CENTER),"target_id":0,"root_id":shots,"command_radius":circle_radius(),"selected_ids":_preview_ids.duplicate()})
		_rhythm_stats.responses = int(_rhythm_stats.responses) + 1
		_rhythm_last_response = event.duplicate(true)
		events.append(event)
		match mode:
			"expand":
				_expand(events,beat)
			"gather":
				if beat == 3: _gather(events,beat)
			"merge":
				if beat == 3: _circle_open(events)
			"fever":
				match beat:
					0: _gather(events,beat)
					1: _merge(events,beat,false,"fever_phase")
					2: _windup(events)
					3: _burst(events)
	if not was_fever and _rhythm.fever_active:
		var entry := _event("fever_enter")
		entry.merge({"command_serial":_rhythm.command_serial,"active":true,"pos":Rules.CIRCLE_CENTER,"radius":circle_radius(),"fever_threshold":_rhythm.fever_threshold,"fever_energy":_rhythm.fever_energy,"fever_energy_max":_rhythm.fever_energy_max})
		events.append(entry)
	for command: Dictionary in _rhythm.take_commands():
		var result := _rhythm.resolve_command(int(command.command_serial),true)
		if result.is_empty():
			fault = "command serial out of order"
			return
		if not result.recognized: _reset_preparation(events,"unknown")
		var resolved := _event("rhythm_command")
		resolved.merge(result,true)
		events.append(resolved)
		# Executability is known only after resolve. Emit the one phrase Perfect
		# on this same boundary so Main/audio never receive a stale judgement.
		var phrase_judgement: Dictionary = result.get("perfect_judgement",{})
		if not phrase_judgement.is_empty():
			var judged := _event(str(phrase_judgement.type))
			judged.merge(phrase_judgement,true)
			events.append(judged)
	_current_command.clear()


func _reset_preparation(events: Array[Dictionary], reason: String) -> void:
	var old_radius := circle_radius()
	expand_stacks = mini(expand_stacks,int(run_options.echo_retention_stacks))
	_preview_ids.clear()
	_gather_plan.clear()
	var event := _event("preparation_reset")
	event.merge({"reason":reason,"old_radius":old_radius,"radius":circle_radius(),"stacks":expand_stacks,"retained_stacks":expand_stacks,"active":false,"pos":Rules.CIRCLE_CENTER})
	events.append(event)


func _expand(events: Array[Dictionary], beat: int = 3) -> void:
	var old_radius := circle_radius()
	expand_stacks = mini(int(run_options.expand_max_stacks),expand_stacks + 1)
	var radius := circle_radius()
	var included: Array[int] = []
	for target in targets:
		if target.state == "active" and target.pos.distance_squared_to(Rules.CIRCLE_CENTER) > old_radius * old_radius + 0.00000001 and is_inside_circle(target.pos): included.append(int(target.id))
	var event := _skill("expand",beat)
	event.merge({"old_radius":old_radius,"new_radius":radius,"radius":radius,"newly_inside":included,"at_cap":is_equal_approx(old_radius,radius),"stacks":expand_stacks})
	_effect_feedback("范围已满" if is_equal_approx(old_radius,radius) else "范围扩大")
	events.append(event)
	if not is_equal_approx(old_radius,radius): _request_auto_merge("expand",tick)


func _gather_candidates() -> Array[int]:
	if not _gather_plan.is_empty():
		var committed: Array[int] = []
		committed.assign(_gather_plan.target_ids)
		return committed
	# A prediction uses the exact same RNG state and pool as the next commit.
	# It is safe to call this any number of times from inspection or presentation.
	var preview_rng := RandomNumberGenerator.new()
	preview_rng.seed = _gather_rng.seed
	preview_rng.state = _gather_rng.state
	return _select_gather_candidates(preview_rng)


func _select_gather_candidates(selection_rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for target in targets:
		if target.state == "active" and not is_inside_circle(target.pos): pool.append(int(target.id))
	# Stable ID order and weighted removal; no target can be selected twice.
	pool.sort()
	var result: Array[int] = []
	for _index in range(mini(int(run_options.gather_count),pool.size())):
		var total := 0
		for id: int in pool:
			var target := _target_by_id(id)
			total += 16 + int(target.pack_grade) * int(run_options.gather_bias_level)
		var roll := selection_rng.randi_range(0,total - 1)
		var edge := 0
		for index in range(pool.size()):
			var target := _target_by_id(pool[index])
			edge += 16 + int(target.pack_grade) * int(run_options.gather_bias_level)
			if roll < edge:
				result.append(pool[index])
				pool.remove_at(index)
				break
	return result


func _commit_gather_plan() -> void:
	var serial := int(_current_command.get("command_serial",0))
	if not _gather_plan.is_empty() and int(_gather_plan.command_serial) == serial: return
	_gather_plan = {"command_serial":serial,"target_ids":_select_gather_candidates(_gather_rng),"selection_tick":tick}
	_preview_ids.assign(_gather_plan.target_ids)


func _gather_destination(ignore_id: int) -> Vector2:
	# Deterministic best-clearance search in a disk. It never changes the chosen
	# outside targets, never consumes RNG and never admits a point beyond the rim.
	var best := Rules.CIRCLE_CENTER
	var best_clearance := -1.0
	for index in range(96):
		var angle := float(index) * 2.399963229728653
		var radial := sqrt(float(index) / 96.0) * maxf(0.0,circle_radius() - 12.0)
		var candidate := Rules.CIRCLE_CENTER + Vector2(cos(angle),sin(angle)) * radial
		candidate.x = clampf(candidate.x,-Rules.TABLE_HALF_WIDTH + PACK_MOVE_INSET,Rules.TABLE_HALF_WIDTH - PACK_MOVE_INSET)
		candidate.y = clampf(candidate.y,PACK_MOVE_INSET,Rules.TABLE_DEPTH - PACK_MOVE_INSET)
		var clearance := 1000000000.0
		for other in targets:
			if int(other.id) != ignore_id and other.state == "active": clearance = minf(clearance,candidate.distance_squared_to(other.pos))
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


func _gather(events: Array[Dictionary], beat: int) -> void:
	var ids: Array[int] = []
	if _current_command.is_empty():
		ids.assign(_select_gather_candidates(_gather_rng))
	else:
		_commit_gather_plan()
		ids.assign(_gather_plan.target_ids)
	var moves: Array[Dictionary] = []
	for id in ids:
		var target := _target_by_id(id)
		var origin: Vector2 = target.pos
		var destination := _gather_destination(id)
		target.pos = destination
		target.destination = destination
		target.spawn_from = destination
		target.velocity = Vector2.ZERO
		target.state = "active"
		target.landing_tick = tick
		moves.append({"target_id":id,"from":origin,"to":destination})
	_rhythm_stats.pulls = int(_rhythm_stats.pulls) + ids.size()
	var event := _skill("pull",beat)
	event.merge({"targets":ids,"moves":moves,"empty":ids.is_empty(),"count":ids.size(),"duration_ticks":12,"gather_selection":run_options.gather_selection})
	_effect_feedback("无圈外卡包" if ids.is_empty() else "聚拢%d包" % ids.size())
	if moves.size() == 1: event.merge({"target_id":moves[0].target_id,"from":moves[0].from,"to":moves[0].to})
	events.append(event)
	if not ids.is_empty(): _request_auto_merge("gather_complete",tick + Rules.LANDING_TICKS)


func _request_auto_merge(trigger: String, due_tick: int) -> void:
	if not _auto_merge_triggers.has(trigger): _auto_merge_triggers.append(trigger)
	_auto_merge_due_tick = maxi(_auto_merge_due_tick,due_tick)
	if not _current_command.is_empty(): _auto_merge_source_serial = int(_current_command.get("command_serial",0))


func _flush_auto_merge(events: Array[Dictionary]) -> void:
	if _auto_merge_triggers.is_empty() or tick < _auto_merge_due_tick or _burst_locked: return
	# Fever owns its first two beats: its gathered packs merge on beat two.
	var echo: Dictionary = _rhythm.active_echo
	if echo.get("preset_id") == "fever" and int(echo.get("beat",-1)) < 1: return
	_merge(events,-1,true,",".join(_auto_merge_triggers))


func _merge(events: Array[Dictionary], beat: int, automatic: bool = false, trigger: String = "explicit") -> void:
	# No merge may invalidate the real IDs committed by the windup event.
	if _burst_locked: return
	var source_serial := _auto_merge_source_serial
	_auto_merge_triggers.clear()
	_auto_merge_due_tick = -1
	_auto_merge_source_serial = 0
	var groups: Array[Dictionary] = []
	var ratio := int(run_options.merge_ratio)
	for grade in range(4):
		while true:
			var candidates: Array[Dictionary] = []
			for target in targets:
				if target.state == "active" and int(target.pack_grade) == grade and is_inside_circle(target.pos): candidates.append(target)
			candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.id) < int(b.id))
			if candidates.size() < ratio: break
			var materials: Array[Dictionary] = []
			var ids: Array[int] = []
			var remaining_sum := 0
			var maximum_sum := 0
			var center := Vector2.ZERO
			for index in range(ratio):
				var target: Dictionary = candidates[index]
				materials.append(target.duplicate(true))
				ids.append(int(target.id))
				remaining_sum += int(target.remaining)
				maximum_sum += int(target.max_hp)
				center += target.pos
			center /= ratio
			for id in ids:
				targets.erase(_target_by_id(id))
			var maximum := int(run_options.hp[grade + 1])
			var health := clampi(ceili(float(remaining_sum * maximum) / maximum_sum),1,maximum)
			var result := _new_target(grade + 1,center,"merge",tick,true)
			result.remaining = health
			targets.append(result)
			groups.append({"material_ids":ids,"materials":materials,"result":result.duplicate(true),"from_grade":grade,"to_grade":grade + 1})
	_rhythm_stats.merged_groups = int(_rhythm_stats.merged_groups) + groups.size()
	if automatic and groups.is_empty(): return
	var event := _skill("merge",beat)
	event.merge({"groups":groups,"empty":groups.is_empty(),"ratio":ratio,"health_rounding":"ceil","duration_ticks":36,"automatic":automatic,"trigger":trigger,"source_command_serial":source_serial})
	if not groups.is_empty(): _effect_feedback("自动合成%d组" % groups.size() if automatic else "完成%d组合成" % groups.size())
	events.append(event)


func _effect_feedback(text: String) -> void:
	_last_effect_feedback = {"text":text,"tick":tick,"command_serial":int(_current_command.get("command_serial",0))}


func _active_ids(inside_only: bool = false) -> Array[int]:
	var result: Array[int] = []
	for target in targets:
		if target.state == "active" and (not inside_only or is_inside_circle(target.pos)): result.append(int(target.id))
	result.sort()
	return result


func _windup(events: Array[Dictionary]) -> void:
	var full_cast := bool(_current_command.get("fever_full_cast",false))
	_burst_target_ids.assign(_active_ids(not full_cast))
	_burst_locked = true
	_preview_ids.assign(_burst_target_ids)
	var event := _skill("burst_windup",2)
	event.merge({"target_ids":_burst_target_ids.duplicate(),"in_circle_ids":_active_ids(true),"targets_locked":true,"global":full_cast,"attack_kind":"fever"})
	events.append(event)


func _burst(events: Array[Dictionary]) -> void:
	_attack(events,not bool(_current_command.get("fever_full_cast",false)),"fever")


func _circle_open(events: Array[Dictionary]) -> void:
	_attack(events,true)


func _attack(events: Array[Dictionary], inside_only: bool, attack_kind: String = "") -> void:
	if attack_kind.is_empty(): attack_kind = "circle_open" if inside_only else "fever"
	var is_fever := attack_kind == "fever"
	shots += 1
	_rhythm_stats.main_strikes = int(_rhythm_stats.main_strikes) + 1
	if attack_kind == "circle_open": _rhythm_stats.circle_open_strikes = int(_rhythm_stats.circle_open_strikes) + 1
	var ids := _active_ids(inside_only)
	if is_fever and _burst_locked: ids.assign(_burst_target_ids)
	var inside_ids := _active_ids(true)
	if is_fever and _burst_locked:
		inside_ids.assign(inside_ids.filter(func(id: int) -> bool: return _burst_target_ids.has(id)))
	var damage := int(run_options.shot_damage)
	var shot := _event("shot")
	shot.merge({"root_id":shots,"pos":Rules.CIRCLE_CENTER,"aim":Rules.CIRCLE_CENTER,"damage":damage,"element":"E01","global":not inside_only,"attack_kind":attack_kind})
	events.append(shot)
	var visual := _skill("burst",3)
	visual.merge({"global":not inside_only,"attack_kind":attack_kind,"target_ids":ids,"targets":ids,"in_circle_ids":inside_ids,"damage":damage})
	events.append(visual)
	var total_coins := 0
	var deaths := 0
	var reward_options := run_options.duplicate(false)
	reward_options["attack_perfect"] = bool(_current_command.get("perfect",false))
	reward_options["attack_combo"] = _rhythm.phrase_combo
	for id in ids:
		var target := _target_by_id(id)
		if target.is_empty() or target.state != "active": continue
		var effective := mini(damage,int(target.remaining))
		target.remaining = maxi(0,int(target.remaining) - damage)
		var hit := _event("hit")
		hit.merge({"target":target.duplicate(true),"target_id":id,"damage":damage,"effective_damage":effective,"damage_style":"direct","root_id":shots,"element":"E01","in_circle":is_inside_circle(target.pos),"attack_kind":attack_kind,"global":not inside_only})
		events.append(hit)
		if int(target.remaining) > 0: continue
		var inside := is_inside_circle(target.pos)
		var reward := draw_reward_with_rng(_loot_rng,reward_options,int(target.pack_grade),false,1,inside)
		# Keep sub-coin percentage gains through every claim in this run. A claim
		# shows only its integer balance delta, so visible claims still sum to score.
		_coin_numerator_total += int(reward.coin_numerator)
		reward.coins = _whole_coins(_coin_numerator_total) - score
		for card_id: String in reward.cards:
			loot[card_id] = int(loot.get(card_id,0)) + int(reward.cards[card_id])
		# Identities remain inside the authority until settlement. All render/audio
		# consumers see a grade and count, including the legacy claim reward shape.
		var visible_reward := reward.duplicate(true)
		visible_reward.cards = {}
		var claim := _event("claim")
		claim.merge({"target":target.duplicate(true),"target_id":id,"reward":visible_reward,"root_id":shots,"in_circle":inside,"coin_multiplier":1.2 if inside else 1.0,"attack_kind":attack_kind,"global":not inside_only})
		events.append(claim)
		var card_drop := _event("card_drop")
		card_drop.merge({"grade":int(reward.card_grade),"count":1,"target_id":id,"root_id":shots})
		events.append(card_drop)
		score += int(reward.coins)
		total_coins += int(reward.coins)
		destroyed_pack_count += 1
		deaths += 1
		_reward_ledger.append({"target_id":id,"tick":tick,"root_id":shots,"pack_grade":int(target.pack_grade),"in_circle":inside,"reward":reward.duplicate(true)})
		targets.erase(target)
	var summary := _event("burst_result")
	summary.merge({"root_id":shots,"command_serial":int(_current_command.get("command_serial",0)),"attack_kind":attack_kind,"global":not inside_only,"hit_count":ids.size(),"destroyed":deaths,"coins":total_coins,"cards":{},"pos":Rules.CIRCLE_CENTER})
	events.append(summary)
	_effect_feedback(("圈内开卡：击破%d包" if attack_kind == "circle_open" else ("Fever圈内攻击：击破%d包" if inside_only else "Fever全屏爆发：击破%d包")) % deaths)
	if is_fever:
		_burst_locked = false
		_burst_target_ids.clear()
		_preview_ids.clear()


@warning_ignore("integer_division")
static func _whole_coins(numerator: int) -> int:
	return numerator / COIN_DENOMINATOR


static func draw_reward_with_rng(_rng: RandomNumberGenerator, options: Dictionary, pack_grade: int, _is_fast: bool, _claim_index: int = 1, in_circle: bool = false) -> Dictionary:
	if pack_grade < 0 or pack_grade >= 5: return {}
	var base := int(options.base_coins[pack_grade])
	var circle_percent := int(options.get("circle_coin_percent",120)) if in_circle else 100
	var perfect_bp := int(options.get("perfect_bonus_basis_points",0)) if bool(options.get("attack_perfect",false)) else 0
	@warning_ignore("integer_division")
	var combo_bands := mini(maxi(0,int(options.get("attack_combo",0))) / 5,4)
	var combo_bp := int(options.get("combo_per_band_basis_points",0)) * combo_bands
	var outside_bp := 0 if in_circle else int(options.get("outside_bonus_basis_points",0))
	var numerator := base * (100 + int(options.coin_bonus_percent)) * circle_percent * (10000 + perfect_bp + combo_bp + outside_bp)
	var card := CollectionRules.draw_card(_rng,pack_grade,options)
	return {"coins":_whole_coins(numerator),"coin_numerator":numerator,"cards":{card.id:1},"card_grade":int(card.grade),"card_count":1,"pack_grade":pack_grade,"is_fast":false,"base_coins":base,
		"in_circle":in_circle,"coin_multiplier":float(circle_percent)/100.0,"coin_bonus_percent":int(options.coin_bonus_percent),"perfect_basis_points":perfect_bp,"combo_basis_points":combo_bp,"outside_basis_points":outside_bp,"flags":["circle_x1_2"] if in_circle else []}


func _refill(events: Array[Dictionary], serial: int) -> void:
	# Freeze one normal supply batch before landings/merges can open new slots.
	var due := maxi(0,capacity - targets.size())
	var directed := mini(int(run_options.directed_refill_count),due)
	for index in range(due):
		var source := String(run_options.dispenser_ids[_refill_cursor % 3])
		_refill_cursor += 1
		var target := _spawn_pack(source,tick,false,index < directed)
		var event := _event("spawn")
		event.merge({"source":"refill","dispenser_id":source,"target":target.duplicate(true),"command_serial":serial,"directed":index < directed})
		events.append(event)
	_refill_count += 1
	_rhythm_stats.refills = int(_rhythm_stats.refills) + 1
	_rhythm_stats.refilled_packs = int(_rhythm_stats.refilled_packs) + due
	var refill := _event("refill")
	refill.merge({"count":due,"directed_count":directed,"frozen_deficit":due,"capacity":capacity,"command_serial":serial,"empty":due == 0})
	events.append(refill)


func _directed_destination() -> Vector2:
	var best := Rules.CIRCLE_CENTER
	var best_clearance := -1.0
	for _attempt in range(24):
		var angle := _motion_rng.randf_range(0.0,TAU)
		var radial := sqrt(_motion_rng.randf()) * maxf(0.0,circle_radius() - 12.0)
		var candidate := Rules.CIRCLE_CENTER + Vector2(cos(angle),sin(angle)) * radial
		candidate.x = clampf(candidate.x,-Rules.TABLE_HALF_WIDTH + PACK_MOVE_INSET,Rules.TABLE_HALF_WIDTH - PACK_MOVE_INSET)
		candidate.y = clampf(candidate.y,PACK_MOVE_INSET,Rules.TABLE_DEPTH - PACK_MOVE_INSET)
		var clearance := 1000000000.0
		for target in targets: clearance = minf(clearance,candidate.distance_squared_to(target.destination))
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


func _spawn_destination() -> Vector2:
	# Pick a random destination from 24 independent candidates, selecting the
	# largest clearance. Existing packs (including planned landings) reserve space.
	var best := Rules.CIRCLE_CENTER
	var best_clearance := -1.0
	for _attempt in range(24):
		var candidate := Vector2(_motion_rng.randf_range(-Rules.TABLE_HALF_WIDTH + PACK_MOVE_INSET,Rules.TABLE_HALF_WIDTH - PACK_MOVE_INSET),_motion_rng.randf_range(PACK_MOVE_INSET,Rules.TABLE_DEPTH - PACK_MOVE_INSET))
		var clearance := 1000000000.0
		for target in targets: clearance = minf(clearance,candidate.distance_squared_to(target.destination))
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


func _new_target(grade: int, destination: Vector2, source: String, at_tick: int, landed: bool) -> Dictionary:
	var origin := destination if landed else Rules.dispenser_position(source,at_tick)
	var maximum := int(run_options.hp[grade])
	var result := {"id":_next_target_id,"kind":"pack","pack_grade":grade,"grade":grade,"is_fast":false,
		"pos":origin,"velocity":Vector2.ZERO if landed else (destination - origin) * (60.0 / Rules.LANDING_TICKS),"state":"active" if landed else "entering",
		"remaining":maximum,"max_hp":maximum,"dispenser_id":source,"spawn_from":origin,"destination":destination,"spawn_tick":at_tick,"landing_tick":at_tick if landed else at_tick + Rules.LANDING_TICKS}
	_next_target_id += 1
	return result


func _spawn_pack(source: String, at_tick: int, landed: bool = false, directed: bool = false) -> Dictionary:
	if targets.size() >= capacity: return {}
	var grade := Rules.grade_for_roll(run_options.spawn_weights,_spawn_rng.randi_range(0,9999))
	var destination := _directed_destination() if directed else _spawn_destination()
	var target := _new_target(grade,destination,source,at_tick,landed)
	target["directed"] = directed
	targets.append(target)
	return target


func _move_target(target: Dictionary) -> bool:
	if target.state != "entering": return false
	var duration := int(target.landing_tick) - int(target.spawn_tick)
	var progress := clampf(float(tick - int(target.spawn_tick)) / maxi(1,duration),0.0,1.0)
	var origin: Vector2 = target.spawn_from
	target.pos = origin.lerp(target.destination,progress)
	if tick >= int(target.landing_tick):
		target.pos = target.destination
		target.velocity = Vector2.ZERO
		target.state = "active"
		return true
	return false


static func reflected_motion(position: Vector2, _velocity: Vector2, _seconds: float) -> Dictionary:
	return {"pos":position,"velocity":Vector2.ZERO}


func _target_by_id(id: int) -> Dictionary:
	for target in targets:
		if int(target.id) == id: return target
	return {}


static func _vec(position: Vector2) -> Array: return [position.x,position.y]


static func _encode(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_encode(item))
		return result
	return value


func snapshot() -> Dictionary:
	return {"snapshot_version":SNAPSHOT_VERSION,"rules_version":RULES_VERSION,"simulation_version":RULES_VERSION,"build_id":BUILD_ID,"balance_version":BALANCE_VERSION,"rng_version":Rules.RNG_VERSION,
		"tick":tick,"run_id":run_id,"seed":str(_seed_value),"closed":closed,"run_options":run_options.duplicate(true),"targets":_encode(targets),
		"loot":loot.duplicate(true),"score":score,"coins":score,"coin_numerator_total":str(_coin_numerator_total),"shots":shots,"capacity":capacity,"destroyed_pack_count":destroyed_pack_count,
		"expand_stacks":expand_stacks,"circle_radius":circle_radius(),"dispensers":dispensers.duplicate(true),"next_target_id":_next_target_id,"next_event_id":_next_event_id,
		"spawn_seed":str(_spawn_rng.seed),"spawn_state":str(_spawn_rng.state),"motion_seed":str(_motion_rng.seed),"motion_state":str(_motion_rng.state),
		"loot_seed":str(_loot_rng.seed),"loot_state":str(_loot_rng.state),"gather_seed":str(_gather_rng.seed),"gather_state":str(_gather_rng.state),"rhythm":_rhythm.snapshot(),"rhythm_stats":_rhythm_stats.duplicate(true),
		"rhythm_last_response":_encode(_rhythm_last_response),"preview_ids":_preview_ids.duplicate(),"gather_plan":_gather_plan.duplicate(true),"refill_count":_refill_count,"refill_cursor":_refill_cursor,
		"reward_ledger":_reward_ledger.duplicate(true),"last_effect_feedback":_last_effect_feedback.duplicate(true),
		"auto_merge_triggers":_auto_merge_triggers.duplicate(),"auto_merge_due_tick":_auto_merge_due_tick,"auto_merge_source_serial":_auto_merge_source_serial,
		"burst_target_ids":_burst_target_ids.duplicate(),"burst_locked":_burst_locked,"fault":fault,"diagnostics":diagnostics.duplicate()}


static func _decimal_i64(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(value.to_int()) == value


func restore(data: Dictionary) -> bool:
	# A complete replay validates targets, merges, rewards, RNG, response phase,
	# pending next-tick input and every derived counter together. Header version
	# rejection happens before reading old WAL under different semantics.
	if data.get("snapshot_version") != SNAPSHOT_VERSION or data.get("rules_version") != RULES_VERSION or data.get("rng_version") != Rules.RNG_VERSION: return false
	if not Rules.whole(data.get("tick"),-1,RUN_TICKS) or not _decimal_i64(data.get("seed")) or not data.get("run_id") is String or data.run_id.is_empty(): return false
	if not data.get("run_options") is Dictionary or not Rules.validate_run_options(data.run_options): return false
	if not data.get("rhythm") is Dictionary or not data.rhythm.get("input_log") is Array: return false
	var attempts: Array = data.rhythm.input_log
	if attempts.size() > RUN_TICKS * RhythmConductor.MAX_KEYS_PER_TICK: return false
	var previous := -1
	var count := 0
	var requested_tick := int(data.tick)
	for raw: Variant in attempts:
		if not raw is Dictionary or raw.size() != 2 or raw.get("key") not in RhythmConductor.KEYS or not Rules.whole(raw.get("tick"),0,mini(RUN_TICKS - 1,requested_tick + 1)): return false
		var at := int(raw.tick)
		if at < previous: return false
		count = count + 1 if at == previous else 1
		if count > RhythmConductor.MAX_KEYS_PER_TICK: return false
		previous = at
	var script := load("res://scripts/simulation.gd") as Script
	var replay = script.new()
	if not replay.start(String(data.seed).to_int(),String(data.run_id),data.run_options): return false
	var cursor := 0
	for boundary in range(requested_tick + 1):
		while cursor < attempts.size() and int(attempts[cursor].tick) == boundary:
			replay.submit_rhythm_key(String(attempts[cursor].key))
			cursor += 1
		replay.step(Rules.CIRCLE_CENTER,true)
	while cursor < attempts.size():
		if int(attempts[cursor].tick) != requested_tick + 1: return false
		replay.submit_rhythm_key(String(attempts[cursor].key))
		cursor += 1
	var canonical := data.duplicate(true)
	canonical.erase("_pending_tick_input") # Outer Store/WAL owns this marker.
	if not Rules._matches_config(canonical,replay.snapshot()): return false
	# Only commit after the entire object has passed; a corrupt restore is atomic.
	for field in ["tick","targets","loot","score","_coin_numerator_total","shots","closed","run_id","charge_ticks","capacity","destroyed_pack_count","run_options","dispensers","current_charge_period","charge_cells","charge_remainder","haste_marks","haste_queue","fault","diagnostics","pending","roots","root_limits","expand_stacks","_seed_value","_spawn_rng","_motion_rng","_loot_rng","_gather_rng","_rhythm","_next_target_id","_next_event_id","_refill_count","_refill_cursor","_reward_ledger","_rhythm_stats","_rhythm_last_response","_preview_ids","_gather_plan","_current_command","_last_effect_feedback","_auto_merge_triggers","_auto_merge_due_tick","_auto_merge_source_serial","_burst_target_ids","_burst_locked"]:
		set(field,replay.get(field))
	return true


func _rhythm_summary() -> Dictionary:
	var result := _rhythm_stats.duplicate(true)
	result.merge({"enabled":true,"cycles":_rhythm.resolved_count,"phrases":_rhythm.command_serial,"valid_beats":_rhythm.total_valid,"perfect_beats":_rhythm.total_perfect,"perfect_phrases":_rhythm.total_perfect,
		"miss_beats":_rhythm.total_miss,"wrong_beats":0,"combo":0,"max_combo":0,"successful_phrases":_rhythm.successful_phrases,"unknown_phrases":_rhythm.unknown_phrases,
		"incomplete_phrases":_rhythm.incomplete_phrases,"phrase_combo":_rhythm.phrase_combo,"max_phrase_combo":_rhythm.max_phrase_combo,"basic_chain":_rhythm.basic_chain,
		"fever_active":_rhythm.fever_active,"fever_threshold":_rhythm.fever_threshold,"fever_energy":_rhythm.fever_energy,"fever_energy_max":_rhythm.fever_energy_max,"fever_activations":_rhythm.fever_activations,"fever_casts":_rhythm.fever_casts,"commands_started":_rhythm.executed_commands,"executed_commands":_rhythm.executed_commands})
	return result


func get_summary() -> Dictionary:
	var active := 0
	for target in targets:
		if target.state == "active": active += 1
	return {"tick":tick,"elapsed_tick":tick,"elapsed_ticks":tick,"run_id":run_id,"rules_version":RULES_VERSION,"score":score,"coins":score,"pack_coins":score,"total_coins":score,"duplicate_bonus_percent":int(run_options.get("duplicate_bonus_percent",0)),"boss_bonus":0,
		"shots":shots,"closed":closed,"charge_ticks":0,"capacity":capacity,"target_count":targets.size(),"active":active,"moving":targets.size() - active,"entering":targets.size() - active,
		"exposed":active,"fast_count":0,"maximum_stack":0,"loot":loot.duplicate(true),"destroyed_pack_count":destroyed_pack_count,"card_count":destroyed_pack_count,"card_grade_counts":CollectionRules.grade_counts(loot),"replacement_count":0,
		"timed_count":0,"timed_skipped":0,"dispensers":dispensers.duplicate(true),"run_options":run_options.duplicate(true),"current_charge_period":CHARGE_PERIOD,"charge_cells":0,
		"charge_remainder":0,"haste_marks":0,"haste_queue":0,"pending_count":0,"active_roots":0,"fault":fault,"circle_radius":circle_radius(),"expand_stacks":expand_stacks,
		"refill_count":_refill_count,"rhythm":_rhythm_summary()}


func debug_state() -> Dictionary: return get_summary()


func get_exposed_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target in targets:
		if target.state == "active": result.append(target.duplicate(true))
	return result
