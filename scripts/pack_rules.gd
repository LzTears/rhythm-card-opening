extends RefCounted
## Single authority: automatic merges, circle attacks, burst and frozen options.
const AttackSpec = preload("res://scripts/attack_spec.gd")
const RhythmConductor = preload("res://scripts/rhythm_conductor.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const CollectionCatalog = preload("res://scripts/collection_catalog.gd")
const RULES_VERSION := "rhythm-workshop-v15"
const BUILD_ID := RULES_VERSION
const BALANCE_VERSION := RULES_VERSION
const RNG_VERSION := "godot-pcg32-rhythm-workshop-v15"
const TICK_RATE := GameConfig.TICK_RATE
const RUN_TICKS := GameConfig.RUN_TICKS
const BASE_INITIAL_COUNT := 24
const BASE_CAPACITY := 24
const BASE_SHOT_DAMAGE := 100
const BASE_CHARGE_PERIOD := 90
const TABLE_HALF_WIDTH := 720.0
const TABLE_DEPTH := 600.0
const DESK_BORDER := 32.0
const PACK_MOVE_INSET := 87.0
const PACK_RADIUS := 50.0
const PACK_VISUAL_SIZE := Vector2(60.0,80.0)
const CIRCLE_CENTER := Vector2(0.0,300.0)
const BASE_CIRCLE_RADIUS := (TABLE_DEPTH - 2.0 * PACK_MOVE_INSET) * 0.25
const EXPAND_MAX_STACKS := 12
const EXPAND_STEP := 0.04
const EXPAND_TALENT_STEP := 0.01
const EXPAND_TALENT_MAX_LEVEL := 6
const EXPAND_PULSES_PER_PHRASE := 4
const FEVER_BASE_THRESHOLD := 5
const FEVER_MIN_THRESHOLD := 2
const FEVER_ENERGY_MAX := 10
const SHOT_RADIUS := BASE_CIRCLE_RADIUS
const NORMAL_SPEED := 0.0
const FAST_SPEED := 0.0
const LANDING_TICKS := 12
const HP := [100,120,150,180,200]
const BASE_COINS := [10,60,360,2160,12960]
const COIN_RANGES := [[10,10],[60,60],[360,360],[2160,2160],[12960,12960]]
const CARD_COUNTS := [0,0,0,0,0]
const CARD_CHANCES := [0,0,0,0,0]
const POWER_DAMAGE := [100,120,150,180,200]
const FEVER_THRESHOLDS := [5,4,3,2]
const SPAWN_POOLS := [[10000,0,0,0,0],[9000,1000,0,0,0],[8000,2000,0,0,0],[7500,2250,250,0,0],[7000,2500,500,0,0],[6575,2650,750,25,0],[6150,2800,1000,50,0],[5770,2900,1250,75,5],[5390,3000,1500,100,10]]
const DISPENSER_MOTION := {
	"top":{"initial":[0.0,600.0],"axis":0,"range":[-590.0,590.0],"velocity":140.0},
	"left":{"initial":[-720.0,300.0],"axis":1,"range":[130.0,470.0],"velocity":100.0},
	"right":{"initial":[720.0,300.0],"axis":1,"range":[130.0,470.0],"velocity":-100.0},
}
const INITIAL_DISPENSER_TICK_RANGES := {"top":[-759,-253],"left":[-306,-102],"right":[-306,-102]}


static func dispenser_position(id: String, at_tick: int) -> Vector2:
	if not DISPENSER_MOTION.has(id): return Vector2.ZERO
	var motion: Dictionary = DISPENSER_MOTION[id]
	var axis := int(motion.axis)
	var position := Vector2(float(motion.initial[0]),float(motion.initial[1]))
	var minimum := float(motion.range[0])
	var length := float(motion.range[1]) - minimum
	var folded := fposmod(position[axis] - minimum + float(motion.velocity) * at_tick / TICK_RATE,2.0 * length)
	position[axis] = minimum + (folded if folded <= length else 2.0 * length - folded)
	return position


static func initial_dispenser_tick(id: String, index: int, count: int) -> int:
	var bounds: Array = INITIAL_DISPENSER_TICK_RANGES.get(id,[-1,-1])
	return roundi(lerpf(float(bounds[0]),float(bounds[1]),float(index) / maxi(1,count - 1)))


static func talent_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"id":"TAL-P","name":"爆发威力","max_level":4,"costs":[500,3250,21100,137000],"requirements_any":[],"effect":"攻击伤害100→200"},
		{"id":"TAL-G1","name":"金币收益","max_level":5,"costs":[300,1240,5170,21400,88900],"requirements_any":[{"TAL-P":1}],"effect":"卡包金币每级＋10%"},
		{"id":"TAL-R","name":"投放品质","max_level":8,"costs":[1500,4190,11700,32700,91500,256000,715000,1998000],"requirements_any":[{"TAL-P":1}],"effect":"提高高阶卡包投放比例"},
		{"id":"TAL-C","name":"桌面容量","max_level":6,"costs":[800,2510,7870,24700,77500,243000],"requirements_any":[{"TAL-P":1}],"effect":"每级容量＋4包"},
		{"id":"TAL-E","name":"扩圈","max_level":EXPAND_TALENT_MAX_LEVEL,"costs":[300,940,2950,9260,29000,91100],"requirements_any":[{"TAL-GATHER":1}],"effect":"每级每拍半径＋1%"},
		{"id":"TAL-GATHER","name":"聚拢数量","max_level":8,"costs":[400,980,2410,5930,14600,35700,87800,216000],"requirements_any":[{"TAL-P":1}],"effect":"每级聚拢＋1包"},
		{"id":"TAL-MERGE","name":"合成比例","max_level":3,"costs":[5000,126000,3000000],"requirements_any":[{"TAL-E":1}],"effect":"合成需求5→2个"},
		{"id":"TAL-FEVER","name":"Fever门槛","max_level":3,"costs":[3000,38100,483000],"requirements_any":[{"TAL-MERGE":1}],"effect":"就绪Combo5→2"},
		{"id":"TAL-PERFECT","name":"Perfect收益","max_level":3,"costs":[200,1030,5280],"requirements_any":[{"TAL-G1":1}],"effect":"Perfect击破金币每级＋3%"},
		{"id":"TAL-COMBO","name":"连击收益","max_level":4,"costs":[100,350,1260,4460],"requirements_any":[{"TAL-PERFECT":1}],"effect":"每5Combo金币＋0.5%/级，最多4档"},
		{"id":"TAL-ECHO","name":"节拍余韵","max_level":3,"costs":[700,3090,13600],"requirements_any":[{"TAL-P":1}],"effect":"断拍保留2／4／6层扩圈"},
		{"id":"TAL-ENERGY","name":"Fever蓄能","max_level":3,"costs":[5000,60100,722000],"requirements_any":[{"TAL-FEVER":1}],"effect":"满能需求10→7格"},
		{"id":"TAL-BIAS","name":"聚拢偏好","max_level":4,"costs":[2000,8560,36600,157000],"requirements_any":[{"TAL-DIRECTED":1}],"effect":"提高高阶包聚拢权重"},
		{"id":"TAL-START-CIRCLE","name":"开局扩圈","max_level":2,"costs":[2500,21700],"requirements_any":[{"TAL-ECHO":1}],"effect":"开局扩圈4／8层"},
		{"id":"TAL-START-ENERGY","name":"开局能量","max_level":2,"costs":[3500,29500],"requirements_any":[{"TAL-ENERGY":1}],"effect":"开局能量1／2格"},
		{"id":"TAL-DIRECTED","name":"定向补给","max_level":3,"costs":[6000,65700,720000],"requirements_any":[{"TAL-C":1}],"effect":"每轮圈内补给2／4／6包"},
		{"id":"TAL-OUTSIDE","name":"圈外回收","max_level":3,"costs":[750,3860,19800],"requirements_any":[{"TAL-COMBO":1}],"effect":"圈外击破金币每级＋3%"},
		{"id":"TAL-DISCOVERY","name":"收藏洞察","max_level":5,"costs":[4000,10200,26000,66300,169000],"requirements_any":[{"TAL-R":1}],"effect":"未收藏卡抽取权重每级＋20%"},
		{"id":"TAL-DUPLICATE","name":"重复精炼","max_level":5,"costs":[300,800,2140,5710,15200],"requirements_any":[{"TAL-DISCOVERY":1}],"effect":"重复卡兑换金币每级＋5%"},
		{"id":"TAL-IDENTIFY","name":"稀有鉴定","max_level":5,"costs":[5000,14000,39100,109000,306000],"requirements_any":[{"TAL-DUPLICATE":1}],"effect":"紫／金／红出卡权重每级＋4%"},
	]
	for row in rows:
		row["requires"] = {}
		row["requirements"] = {}
		row["implemented"] = true
	return rows


static func talent_definition(node_id: String) -> Dictionary:
	var canonical := node_id if node_id.begins_with("TAL-") else "TAL-" + node_id
	for row in talent_definitions():
		if row.id == canonical: return row
	return {}


static func validate_talents(talents: Dictionary) -> bool:
	var seen: Dictionary = {}
	for key: Variant in talents:
		if not key is String: return false
		var row := talent_definition(key)
		if row.is_empty() or seen.has(row.id): return false
		if not whole(talents[key],0,int(row.max_level)): return false
		seen[row.id] = true
	return true


static func normalize_talents(talents: Dictionary) -> Dictionary:
	if not validate_talents(talents): return {}
	var result: Dictionary = {}
	for row in talent_definitions():
		result[row.id] = mini(int(row.max_level),int(talents.get(row.id,talents.get(String(row.id).trim_prefix("TAL-"),0))))
	return result


static func validate_album(album: Dictionary) -> bool:
	for id: Variant in album:
		if not id is String or CollectionCatalog.card_definition(id).is_empty() or not album[id] is bool or album[id] != true: return false
	return true


static func build_run_options(talents: Dictionary = {}, _loadout: Dictionary = {}, _card_levels: Dictionary = {}, album: Dictionary = {}) -> Dictionary:
	if not validate_talents(talents) or not validate_album(album): return {}
	var levels := normalize_talents(talents)
	# Collection identities never compile into combat equipment or attributes.
	var loadout := {"launcher_id":"E01","slots":[null,null,null,null]}
	var count := BASE_CAPACITY + 4 * int(levels["TAL-C"])
	return {
		"album":album.duplicate(true),
		"rules_version":RULES_VERSION,"build_id":BUILD_ID,"balance_version":BALANCE_VERSION,"rng_version":RNG_VERSION,"catalog_version":AttackSpec.CATALOG_VERSION,
		"loadout":loadout,"card_levels":{},"attack_spec":AttackSpec.compile(levels),"talents":levels,
		"tick_rate":TICK_RATE,"run_ticks":RUN_TICKS,"rhythm_enabled":true,"rhythm_bpm":RhythmConductor.BPM,"rhythm_keys":RhythmConductor.KEYS.duplicate(),"rhythm_phrase_lengths":[4],
		"rhythm_input_mode":"relative_cadence","rhythm_combo_handoff_ticks":RhythmConductor.COMBO_HANDOFF_TICKS,"rhythm_min_input_ticks":15,"rhythm_max_input_ticks":42,"rhythm_perfect_window_ticks":6,"rhythm_fever_threshold":FEVER_THRESHOLDS[int(levels["TAL-FEVER"])],
		"rhythm_fever_energy_max":FEVER_ENERGY_MAX - int(levels["TAL-ENERGY"]),"initial_fever_energy":int(levels["TAL-START-ENERGY"]),"rhythm_fever_energy_gain":1,"rhythm_fever_energy_on_miss":"preserve","rhythm_fever_cast_latch":"response_beat_one","rhythm_fever_gate":"active_only",
		"initial_count":count,"capacity":count,"dispenser_ids":["top","left","right"],"spawn_period":0,"landing_ticks":LANDING_TICKS,
		"dispenser_motion":DISPENSER_MOTION.duplicate(true),"initial_dispenser_tick_ranges":INITIAL_DISPENSER_TICK_RANGES.duplicate(true),
		"table_bounds":[-TABLE_HALF_WIDTH,TABLE_HALF_WIDTH,0.0,TABLE_DEPTH],"desk_border":DESK_BORDER,"pack_move_inset":PACK_MOVE_INSET,
		"pack_radius":PACK_RADIUS,"pack_visual_size":[PACK_VISUAL_SIZE.x,PACK_VISUAL_SIZE.y],"shot_radius":BASE_CIRCLE_RADIUS,
		"circle_center":[CIRCLE_CENTER.x,CIRCLE_CENTER.y],"base_circle_radius":BASE_CIRCLE_RADIUS,
		"gather_count":2 + int(levels["TAL-GATHER"]),"gather_selection":"grade_weighted_without_replacement","gather_bias_level":int(levels["TAL-BIAS"]),"merge_ratio":5 - int(levels["TAL-MERGE"]),
		"initial_expand_stacks":4 * int(levels["TAL-START-CIRCLE"]),"echo_retention_stacks":2 * int(levels["TAL-ECHO"]),"directed_refill_count":2 * int(levels["TAL-DIRECTED"]),
		"expand_max_stacks":EXPAND_MAX_STACKS,"expand_step":EXPAND_STEP+EXPAND_TALENT_STEP*int(levels["TAL-E"]),"expand_pulses_per_phrase":EXPAND_PULSES_PER_PHRASE,
		"shot_damage":POWER_DAMAGE[int(levels["TAL-P"])],"coin_bonus_percent":10 * int(levels["TAL-G1"]),"circle_coin_percent":120,
		"perfect_bonus_basis_points":300 * int(levels["TAL-PERFECT"]),"combo_per_band_basis_points":50 * int(levels["TAL-COMBO"]),"outside_bonus_basis_points":300 * int(levels["TAL-OUTSIDE"]),
		"discovery_level":int(levels["TAL-DISCOVERY"]),"duplicate_bonus_percent":5 * int(levels["TAL-DUPLICATE"]),"identify_level":int(levels["TAL-IDENTIFY"]),"charge_period":BASE_CHARGE_PERIOD,
		"hp":HP.duplicate(),"base_coins":BASE_COINS.duplicate(),"coin_ranges":COIN_RANGES.duplicate(true),"spawn_weights":SPAWN_POOLS[int(levels["TAL-R"])].duplicate(),
		"normal_speed":0.0,"fast_speed":0.0,"fast_chance":0,"fast_limit":0,"card_chances":CARD_CHANCES.duplicate(),"card_counts":CARD_COUNTS.duplicate(),"card_weights":[],
		"fast_extra_cards":0,"fast_coin_multiplier":1,"fast_upgrade_chance":0,"card_rewards_enabled":false,
		"merge_health_rounding":"ceil","circle_boundary":"center_inclusive","merge_matching":"grade_then_id","supply_mode":"phrase_complete_refill",
		"merge_mode":"state_change_automatic","circle_open_preset":"merge","circle_open_damage":"shot_damage","fever_target_lock":"windup",
	}


static func quantize_damage(value: float) -> int: return maxi(0,floori(value))


static func validate_run_options(options: Dictionary) -> bool:
	if not options.get("talents") is Dictionary or not validate_talents(options.talents): return false
	if not options.get("album") is Dictionary or not validate_album(options.album): return false
	return _matches_config(options,build_run_options(options.talents,{},{},options.album))


static func _matches_config(actual: Variant, expected: Variant) -> bool:
	if expected is int or expected is float: return (actual is int or actual is float) and is_finite(float(actual)) and actual == expected
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _matches_config(actual[key],expected[key]): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for index in expected.size():
			if not _matches_config(actual[index],expected[index]): return false
		return true
	return typeof(actual) == typeof(expected) and actual == expected


static func grade_for_roll(weights: Array, roll: int) -> int:
	if roll < 0 or roll >= 10000 or weights.size() != 5: return -1
	var sum := 0
	for grade in range(5):
		sum += int(weights[grade])
		if roll < sum: return grade
	return -1


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value)) and value >= minimum and value <= maximum


static func valid_variant_key(key: String) -> bool: return AttackSpec.CATALOG.has(key)
