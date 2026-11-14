extends Control
## Relative four-beat calls in the original footer; no global target track.
const WorkshopSkin = preload("res://scripts/workshop_skin.gd")
const Rules = preload("res://scripts/pack_rules.gd")
const ORANGE := Color("#e8a0a6")
const CREAM := Color("#f2dfbc")
const MUTED := Color("#b6a5c5")
const SUCCESS := Color("#b9d3be")
const WORDS := {"pata":"PATA","pon":"PON","don":"DON","chaka":"CHAKA"}
const COMMAND_LABELS := {"gather":"聚拢","expand":"扩圈","merge":"圈内开卡","fever":"爆发"}
const INPUT_LEGENDS := {"keyboard":"键盘 ←PATA →PON ↓DON ↑CHAKA","joypad":"Xbox X PATA · B PON · A DON · Y CHAKA"}
const XBOX_TONES := {"pata":Color("#439bf6"),"pon":Color("#f06461"),"don":Color("#79d261"),"chaka":Color("#ffdc51")}
const PHRASE_RECT := Rect2(432,949,684,55)
const FEEDBACK_RECT := Rect2(1180,951,216,68)
const WORD_LIFETIME_TICKS := 10
const COMPLETED_DISPLAY_TICKS := 36
const FAILURE_DISPLAY_TICKS := 36
const FEVER_READY_TICKS := 42
const BEAT_TICKS := 30
const GUIDE_KEY_SIZE := 32.0
const GUIDE_KEY_SPACING := 44.0
const GUIDE_KEY_START := 178.0
const UNKNOWN_FEEDBACK_TICKS := 24
const FEEDBACK_ORDER := ["gather","expand","merge","fever"]
const FEEDBACK_RECIPES := {"gather":["pata","pata","pata","pon"],"expand":["pon","pon","pata","pon"],"merge":["chaka","chaka","pata","pon"],"fever":["don","don","pata","pon"]}
var theme_skin := "default"
var display_font: Font
var body_font: Font
var rhythm: Dictionary = {}
var is_paused := false
var reduced := false
var word_pulses: Array[Dictionary] = []
var last_input_key := ""
var input_device := "keyboard"
var presented_command: Dictionary = {}
var presented_judgement: Dictionary = {}
var last_response_token := ""
var last_judgement_token := ""
var last_response_serial := -1
var last_response_beat := -1
var fever_ready_tick := -1
var fever_ready_count := 0
var _guide_skins: Dictionary = {}
var _completed_echo_tick := -1
var _completed_echo_serial := -1
var _accepted_prefix: Array[String] = []
var _unknown_feedback: Dictionary = {}
var _unknown_token := ""

func _ready() -> void:
	name = "RhythmHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

func set_fonts(pixel: Font, body: Font) -> void:
	display_font = pixel
	body_font = body

func set_input_device(value: String) -> void:
	if not INPUT_LEGENDS.has(value) or input_device==value: return
	input_device = value
	queue_redraw()

func set_state(value: Dictionary, _preparation: int=0, _preparation_total: int=0, stopped: bool=false) -> void:
	var now := int(value.get("tick",-1))
	var initial := rhythm.is_empty() or now<int(rhythm.get("tick",-1))
	if not rhythm.is_empty() and value.has("run_id") and rhythm.has("run_id") and str(value.run_id)!=str(rhythm.run_id): initial = true
	if stopped and not initial:
		is_paused = true
		queue_redraw()
		return
	var had_fever := bool(rhythm.get("fever_active",false))
	if initial:
		word_pulses.clear()
		presented_command.clear()
		presented_judgement.clear()
		last_input_key = ""
		last_judgement_token = ""
		last_response_token = ""
		last_response_serial = -1
		last_response_beat = -1
		fever_ready_tick = -1
		fever_ready_count = 0
		_completed_echo_tick = -1
		_completed_echo_serial = -1
		_accepted_prefix.clear()
		_unknown_feedback.clear()
		_unknown_token = ""
	rhythm = value.duplicate(true)
	is_paused = stopped
	if initial:
		var judgement: Dictionary = rhythm.get("last_judgement",{})
		last_judgement_token = "%d:%d:%d:%s" % [int(judgement.get("tick",-1)),int(judgement.get("input_index",-1)),int(judgement.get("word_index",judgement.get("beat",-1))),str(judgement.get("grade",""))]
		var response: Dictionary = rhythm.get("response_event",{})
		if bool(response.get("executed",false)):
			last_response_serial = int(response.get("command_serial",response.get("serial",-1)))
			last_response_beat = int(response.get("word_index",response.get("beat",-1)))
			last_response_token = "%d:%d" % [last_response_serial,last_response_beat]
	else:
		_consume_judgement(rhythm.get("last_judgement",{}))
		_consume_response(rhythm.get("response_event",{}))
		pulse_command(rhythm.get("command_event",rhythm.get("last_command",{})))
		if not had_fever and bool(rhythm.get("fever_active",false)):
			fever_ready_tick = now
			fever_ready_count += 1
	if not bool(rhythm.get("fever_active",false)): fever_ready_tick = -1
	for index in range(word_pulses.size()-1,-1,-1):
		if now-int(word_pulses[index].tick)>=WORD_LIFETIME_TICKS: word_pulses.remove_at(index)
	if str(rhythm.get("phase","idle"))=="idle" and str(_latest_judgement().get("grade",""))=="miss": word_pulses.clear()
	var command := _latest_command()
	if str(command.get("status","")) in ["blocked","unknown"] and int(command.get("tick",-2))>=int(_latest_judgement().get("tick",-1)):
		word_pulses.clear()
	queue_redraw()

func pulse_word(key: String, response: bool=false, at_tick: int=-1) -> void:
	# Main calls this only after accepted=true, before the simulation emits its
	# indexed judgement. Defer the visual to that event instead of guessing a slot.
	if not is_paused and not response and WORDS.has(key) and at_tick>=int(rhythm.get("tick",-1)):
		last_input_key = key

func pulse_command(event: Dictionary) -> void:
	if is_paused or not _event_is_current(event): return
	if int(event.get("command_serial",event.get("serial",-1)))<int(presented_command.get("command_serial",presented_command.get("serial",-1))): return
	presented_command = event.duplicate(true)
	if str(event.get("status",""))=="unknown": _show_unknown(event)
	if str(event.get("status","")) in ["blocked","unknown"]:
		word_pulses.clear()
		last_input_key = ""
	queue_redraw()

func pulse_response(event: Dictionary) -> void:
	_consume_response(event)
	queue_redraw()

func pulse_judgement(event: Dictionary) -> void:
	_consume_judgement(event)
	queue_redraw()

func _event_is_current(event: Dictionary) -> bool:
	if is_paused: return false
	var at := int(event.get("tick",-999))
	var now := int(rhythm.get("tick",-1))
	return at>=now and at<=now+1

func _consume_judgement(event: Dictionary) -> void:
	if event.is_empty() or not _event_is_current(event): return
	var at := int(event.get("tick",-1))
	if at<int(presented_judgement.get("tick",-1)): return
	if at==int(presented_judgement.get("tick",-1)):
		var incoming := int(event.get("input_index",-1))
		var previous := int(presented_judgement.get("input_index",-1))
		if incoming<previous or (incoming==previous and str(presented_judgement.get("grade",""))=="miss" and str(event.get("grade",""))!="miss"): return
	var index := int(event.get("word_index",event.get("beat",-1)))
	var token := "%d:%d:%d:%s" % [at,int(event.get("input_index",-1)),index,str(event.get("grade",""))]
	if token==last_judgement_token: return
	last_judgement_token = token
	presented_judgement = event.duplicate(true)
	# A committed Perfect describes the completed sentence. Its last-key metadata
	# lets the circle wordmark/audio consume it without adding a fifth key pulse.
	if str(event.get("scope",""))=="phrase": return
	if str(event.get("grade",""))=="miss":
		word_pulses.clear()
		last_input_key = ""
		_accepted_prefix.clear()
		return
	var key := str(event.get("key",""))
	if not bool(event.get("accepted",false)) or not WORDS.has(key) or index<0 or index>3: return
	if index==0:
		word_pulses.clear()
		_accepted_prefix.clear()
		_unknown_feedback.clear()
	if index==_accepted_prefix.size(): _accepted_prefix.append(key)
	last_input_key = key
	word_pulses.append({"key":key,"tick":at,"response":false,"word_index":index,"token":token})
	while word_pulses.size()>4: word_pulses.pop_front()

func _show_unknown(event: Dictionary) -> void:
	var token := "%s:%s" % [str(event.get("command_serial",event.get("serial",-1))),str(event.get("tick",-1))]
	if token==_unknown_token: return
	_unknown_token = token
	var prefix: Array = event.get("sequence",_accepted_prefix).duplicate()
	var targets: Array[String] = []
	if not prefix.is_empty() and prefix.size()<=4:
		for id: String in FEEDBACK_ORDER:
			var recipe: Array = FEEDBACK_RECIPES[id]
			var matches := true
			for slot in range(prefix.size()):
				if str(prefix[slot])!=str(recipe[slot]): matches = false
			if matches: targets.append(id)
	# A wholly unknown recipe points to no individual instruction. A short
	# gesture on the four-card group preserves that uncertainty without guessing.
	if targets.is_empty(): targets.assign(FEEDBACK_ORDER)
	_unknown_feedback = {"tick":int(event.get("tick",-1)),"sequence":prefix,"targets":targets,"token":token}

func _unknown_card_style(id: String) -> Dictionary:
	var age := int(rhythm.get("tick",-1))-int(_unknown_feedback.get("tick",-100000))
	var active: bool = not _unknown_feedback.is_empty() and age>=0 and age<UNKNOWN_FEEDBACK_TICKS and id in _unknown_feedback.get("targets",[])
	var offset := Vector2.ZERO
	if active and not reduced:
		var decay := 1.0-float(age)/float(UNKNOWN_FEEDBACK_TICKS)
		offset.x = roundf(cos(float(age)*PI*.65)*3.0*decay)
	return {"active":active,"offset":offset,"border_visible":active,"age_ticks":age,"motion_enabled":active and not reduced}

func _unknown_state() -> Dictionary:
	var rows: Array[Dictionary] = []
	var visible := false
	for index in range(FEEDBACK_ORDER.size()):
		var id: String = FEEDBACK_ORDER[index]
		var style := _unknown_card_style(id)
		var rect := Rect2(28+index*360,946,348,92)
		visible = visible or bool(style.active)
		rows.append({"id":id,"active":style.active,"draw_offset":style.offset,"rect":rect,"drawn_rect":Rect2(rect.position+Vector2(style.offset),rect.size),"border_visible":style.border_visible})
	return {"visible":visible,"tick":int(_unknown_feedback.get("tick",-100000)),"age_ticks":int(rhythm.get("tick",-1))-int(_unknown_feedback.get("tick",-100000)),"lifetime_ticks":UNKNOWN_FEEDBACK_TICKS,"sequence":_unknown_feedback.get("sequence",[]).duplicate(),"targets":_unknown_feedback.get("targets",[]).duplicate(),"cards":rows,"motion_enabled":visible and not reduced,"text_visible":false,"miss_visible":false,"energy_offset":Vector2.ZERO,"clock":"simulation"}

func _consume_response(event: Dictionary) -> void:
	if event.is_empty() or not bool(event.get("executed",false)) or not _event_is_current(event): return
	var serial := int(event.get("command_serial",event.get("serial",-1)))
	var index := int(event.get("word_index",event.get("beat",-1)))
	var key := str(event.get("key",""))
	var echo: Dictionary = rhythm.get("active_echo",{})
	if serial<=0 or index<0 or index>3 or not WORDS.has(key): return
	if int(echo.get("command_serial",-1))!=serial or echo.get("sequence",[]).size()!=4 or str(echo.sequence[index])!=key: return
	if int(event.get("tick",-1))!=int(echo.get("start_tick",-999))+index*30: return
	if serial<last_response_serial or (serial==last_response_serial and index<=last_response_beat): return
	last_response_serial = serial
	last_response_beat = index
	last_response_token = "%d:%d" % [serial,index]
	if index==3:
		_completed_echo_serial = serial
		_completed_echo_tick = int(echo.get("end_tick",int(event.tick)+BEAT_TICKS))
	word_pulses.clear()
	word_pulses.append({"key":key,"tick":int(event.tick),"response":true,"word_index":index,"command_serial":serial,"token":last_response_token})

func _fresh(at_tick: int, lifetime: int) -> bool:
	var age := int(rhythm.get("tick",-1))-at_tick
	return at_tick>=0 and age>=0 and age<lifetime

func _fever_ready() -> bool:
	return bool(rhythm.get("fever_active",false)) and _fresh(fever_ready_tick,FEVER_READY_TICKS)

func _latest_judgement() -> Dictionary:
	var judgement: Dictionary = rhythm.get("last_judgement",{})
	return presented_judgement if int(presented_judgement.get("tick",-1))>int(judgement.get("tick",-1)) else judgement

func _latest_command() -> Dictionary:
	var event: Dictionary = rhythm.get("command_event",rhythm.get("last_command",{}))
	var serial := int(event.get("command_serial",event.get("serial",-1)))
	var presented_serial := int(presented_command.get("command_serial",presented_command.get("serial",-1)))
	return presented_command if presented_serial>serial else event

func _visible_slots() -> Array[String]:
	var result: Array[String] = ["","","",""]
	var source: Array = rhythm.get("slots",rhythm.get("buffer",[]))
	var echo: Dictionary = rhythm.get("active_echo",{})
	if str(rhythm.get("phase","idle"))=="respond": source = echo.get("sequence",rhythm.get("sequence",[]))
	var has_input := false
	for key: Variant in source:
		if WORDS.has(str(key)): has_input = true
	if not has_input and str(_latest_judgement().get("grade",""))!="miss":
		var event := _latest_command()
		if _fresh(int(event.get("tick",-999)),COMPLETED_DISPLAY_TICKS): source = event.get("sequence",[])
	for index in range(mini(4,source.size())):
		var key := str(source[index])
		if WORDS.has(key): result[index] = key
	return result

func _command_feedback() -> Dictionary:
	var event := _latest_command()
	var status := str(event.get("status",rhythm.get("command_status","pending")))
	var command_id := str(event.get("id",event.get("preset_id",rhythm.get("preset_id",""))))
	var executed := bool(event.get("executed",rhythm.get("command_executed",false)))
	var label := str(COMMAND_LABELS.get(command_id,""))
	var caption := "输入四字成招"
	var color := MUTED
	var kind := "idle"
	var judgement := _latest_judgement()
	var command_tick := int(event.get("tick",-1))
	var failure_fresh := _fresh(command_tick,FAILURE_DISPLAY_TICKS)
	var echo: Dictionary = rhythm.get("active_echo",{})
	var input_count := 0
	for word: Variant in rhythm.get("buffer",rhythm.get("slots",[])):
		if WORDS.has(str(word)): input_count += 1
	if str(rhythm.get("phase","idle"))=="input" and input_count>0:
		caption = "连续输入 %d/4" % input_count
		color = CREAM
		kind = "input"
	elif str(judgement.get("grade",""))=="miss" and int(judgement.get("tick",-1))>=command_tick and _fresh(int(judgement.get("tick",-1)),FAILURE_DISPLAY_TICKS):
		caption = "过快" if str(judgement.get("reason",""))=="too_fast" else "漏拍"
		color = Color("#cf8978")
		kind = "miss"
	elif status=="unknown" and failure_fresh:
		caption = "未知指令"
		color = Color("#cf8978")
		kind = "rejected"
	elif status=="blocked" and failure_fresh:
		match str(event.get("reason","")):
			"no_fever": caption = "进入 Fever 后可用"
			"busy": caption = "攻击繁忙，重新起手"
			"deadline": caption = "时间不足，无法复述"
			_: caption = "指令未执行"
		color = MUTED
		kind = "neutral"
	elif str(rhythm.get("phase","idle"))=="respond" and not echo.is_empty():
		var beat := int(echo.get("beat",-1))
		var stage := "待复述"
		if bool(echo.get("started",false)):
			if command_id=="fever":
				var global_cast := bool(echo.get("fever_full_cast",echo.get("fever_global",false)))
				stage = ["聚拢","合成","蓄势","全屏重击" if global_cast else "圈内攻击"][clampi(beat,0,3)]
			elif command_id=="expand":
				stage = "逐拍扩圈 %d/4" % clampi(beat+1,0,4)
			else:
				stage = "执行" if beat==3 else "准备"
		caption = label+" · "+stage
		var effect: Dictionary = rhythm.get("last_effect_feedback",{})
		if beat==3 and command_id!="fever" and int(effect.get("command_serial",-1))==int(echo.get("command_serial",-2)):
			caption = str(effect.get("text",caption))
		color = ORANGE
		kind = "response"
	elif executed and str(event.get("stage",""))=="complete" and _fresh(_command_echo_end(event),COMPLETED_DISPLAY_TICKS) and not label.is_empty():
		caption = label+"已执行"
		var effect: Dictionary = rhythm.get("last_effect_feedback",{})
		if command_id!="fever" and int(effect.get("command_serial",-1))==int(event.get("command_serial",-2)):
			caption = str(effect.get("text",caption))
		color = SUCCESS
		kind = "complete"
	return {"id":command_id,"status":status,"executed":executed,"caption":caption,"color":color,"kind":kind}

func _command_echo_end(event: Dictionary) -> int:
	if event.has("echo_end_tick"): return int(event.echo_end_tick)
	if event.has("end_tick"): return int(event.end_tick)
	var serial := int(event.get("command_serial",event.get("serial",-1)))
	return _completed_echo_tick if serial==_completed_echo_serial else -1

func _cadence_caption() -> String:
	var phase := str(rhythm.get("phase","idle"))
	if phase=="input":
		# Main queues a press for the next simulation tick.
		var next_tick := int(rhythm.get("tick",-1))+1
		var minimum := int(rhythm.get("next_input_min_tick",-1))
		var cue := "现在接拍" if minimum>=0 and next_tick>=minimum else "等待接拍"
		return "%s · 下一拍剩余 %.2fs" % [cue,float(rhythm.get("remaining_ticks",0))/60.0]
	if phase=="respond":
		var echo: Dictionary = rhythm.get("active_echo",{})
		return "系统复述 %d / 4 · 120 BPM" % clampi(int(echo.get("beat",-1))+1,0,4)
	return "自由起手 · 120 BPM"

func _chain_feedback() -> String:
	var chain := maxi(0,int(rhythm.get("phrase_combo",0)))
	var threshold := maxi(1,int(rhythm.get("fever_threshold",Rules.FEVER_BASE_THRESHOLD)))
	var energy := maxi(0,int(rhythm.get("fever_energy",0)))
	var energy_max := maxi(1,int(rhythm.get("fever_energy_max",10)))
	var ready := bool(rhythm.get("fever_active",false))
	var status := "全屏就绪" if ready and energy>=energy_max else "满能待Combo" if energy>=energy_max else "圈内蓄能"
	return "Combo %d/%d · 能量 %d/%d · %s" % [chain,threshold,energy,energy_max,status]

func _slot_feedback() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots := _visible_slots()
	var phase := str(rhythm.get("phase","idle"))
	var echo: Dictionary = rhythm.get("active_echo",{})
	var current_beat := int(echo.get("beat",-1)) if phase=="respond" and bool(echo.get("started",false)) else -1
	var feedback := _command_feedback()
	var count: int = rhythm.get("buffer",[]).size()
	var can_input := int(rhythm.get("next_input_min_tick",-1))>=0 and int(rhythm.get("tick",-1))+1>=int(rhythm.get("next_input_min_tick",-1))
	for index in range(4):
		var strength := 0.0
		var source := "response" if index==current_beat else ""
		for entry: Dictionary in word_pulses:
			if int(entry.word_index)!=index or str(entry.key)!=slots[index]: continue
			var is_response := bool(entry.response)
			if is_response and (phase!="respond" or int(entry.get("command_serial",-1))!=int(echo.get("command_serial",-2)) or index!=current_beat): continue
			if not is_response and current_beat>=0: continue
			if _fresh(int(entry.tick),WORD_LIFETIME_TICKS):
				strength = 1.0-float(int(rhythm.get("tick",-1))-int(entry.tick))/WORD_LIFETIME_TICKS
				source = "response" if is_response else "input"
		var failed := str(feedback.kind) in ["miss","rejected"]
		result.append({"index":index,"word":slots[index],"source":source,"active":not source.is_empty(),"pulse_active":strength>0,
			"strength":1.0 if reduced and strength>0 else strength,"lift":0.0 if reduced else strength*4.0,
			"font_size":36 if reduced else 36+roundi(strength*4.0),"motion_enabled":not reduced,
			"next_slot":phase=="input" and index==count,"input_window":phase=="input" and index==count and can_input,"failed":failed})
	return result

func _text(value: String, point: Vector2, font_size: int=24, color: Color=CREAM, pixel: bool=true) -> void:
	var selected: Font = display_font if pixel else body_font
	if selected!=null: draw_string(selected,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _center(value: String, box: Rect2, font_size: int=24, color: Color=CREAM, pixel: bool=true) -> void:
	var selected: Font = display_font if pixel else body_font
	if selected==null: return
	var width_value := selected.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := box.get_center().y+(selected.get_ascent(font_size)-selected.get_descent(font_size))*.5
	_text(value,Vector2(box.get_center().x-width_value*.5,baseline),font_size,color,pixel)

func _guide_cards() -> Array[Dictionary]:
	var expand_step := roundi(float(rhythm.get("expand_step",Rules.EXPAND_STEP))*100.0)
	var expand_cap := int(rhythm.get("expand_max_stacks",Rules.EXPAND_MAX_STACKS))
	var recipes: Array[Dictionary] = [
		{"id":"gather","name":"聚拢","keys":["pata","pata","pata","pon"],"effect":"圈外随机%d包拉入圈内" % int(rhythm.get("gather_count",2))},
		{"id":"expand","name":"扩圈","keys":["pon","pon","pata","pon"],"effect":"每拍＋%d%% · %d/%d层 · 一句四拍" % [expand_step,int(rhythm.get("expand_stacks",0)),expand_cap]},
		{"id":"merge","name":"圈内开卡","keys":["chaka","chaka","pata","pon"],"effect":"圈内自动合成·开卡伤害%d" % int(rhythm.get("shot_damage",100))},
		{"id":"fever","name":"爆发","keys":["don","don","pata","pon"],"effect":_fever_guide_effect()},
	]
	var glyphs := {"pata":"←","pon":"→","don":"↓","chaka":"↑"} if input_device=="keyboard" else {"pata":"X","pon":"B","don":"A","chaka":"Y"}
	var buffer: Array = rhythm.get("buffer",[])
	var echo: Dictionary = rhythm.get("active_echo",{})
	var phase := str(rhythm.get("phase","idle"))
	var echo_started := phase=="respond" and bool(echo.get("started",false))
	var echo_waiting := phase=="respond" and not echo.is_empty() and not echo_started
	var response_beat := clampi(int(echo.get("beat",-1)),-1,3) if echo_started else -1
	for index in range(recipes.size()):
		var card: Dictionary = recipes[index]
		var echo_matches := phase=="respond" and not echo.is_empty() and str(echo.get("preset_id",""))==str(card.id)
		var prefix_matches := phase=="input" and not buffer.is_empty()
		if prefix_matches:
			for slot in range(mini(buffer.size(),4)):
				if str(buffer[slot])!=str(card.keys[slot]): prefix_matches = false
		var matched_count := mini(buffer.size(),4) if prefix_matches else (4 if echo_matches and echo_waiting else 0)
		var active := prefix_matches or echo_matches
		var arrows: Array[String] = []
		var words: Array[String] = []
		var buttons: Array[Dictionary] = []
		for slot in range(card.keys.size()):
			var key: String = card.keys[slot]
			arrows.append(str(glyphs[key]))
			words.append(str(WORDS[key]))
			var key_state := "idle"
			if prefix_matches and slot<matched_count: key_state = "input_matched"
			elif echo_matches and echo_waiting: key_state = "waiting_complete"
			elif echo_matches and echo_started and slot<=response_beat: key_state = "response_current" if slot==response_beat else "response_done"
			buttons.append({"key":key,"glyph":str(glyphs[key]),"shape":"square" if input_device=="keyboard" else "circle","color":CREAM if input_device=="keyboard" else XBOX_TONES[key],"feedback_state":key_state,"highlighted":key_state!="idle","current":key_state=="response_current","source":"response" if key_state.begins_with("response") else ("input" if key_state!="idle" else ""),"fill":"outline" if echo_matches and echo_started else "solid"})
		card["arrows"] = " ".join(arrows)
		card["words"] = " ".join(words)
		card["prompt_buttons"] = buttons
		card["active"] = active
		card["prefix_matches"] = prefix_matches
		card["matched_count"] = matched_count
		card["waiting_complete"] = echo_matches and echo_waiting
		card["response_beat"] = response_beat if echo_matches else -1
		card["feedback_phase"] = "waiting" if echo_matches and echo_waiting else ("response" if echo_matches and echo_started else ("input" if prefix_matches else "idle"))
		card["locked"] = card.id=="fever" and not bool(rhythm.get("fever_active",false))
		if card.locked:
			for button: Dictionary in buttons: button["color"] = Color("#72697f")
		card["lock_icon_visible"] = false
		card["border_motion"] = card.id=="fever" and not card.locked and not reduced
		card["full_energy_corners"] = card.id=="fever" and bool(rhythm.get("can_fever",false))
		card["corner_style"] = "steady_double_gold" if card.full_energy_corners else "none"
		card["corner_motion"] = false
		card["border_phase"] = float(posmod(int(rhythm.get("tick",0)),60))/60.0 if card.border_motion else 0.0
		if card.id=="fever":
			card["fever_ready"] = bool(rhythm.get("fever_active",false))
			card["global_ready"] = bool(rhythm.get("can_fever",false))
		card["rect"] = Rect2(28+index*360,946,348,92)
		card["unknown_feedback"] = _unknown_card_style(str(card.id))
		card["draw_offset"] = card.unknown_feedback.offset
		card["drawn_rect"] = Rect2(card.rect.position+Vector2(card.draw_offset),card.rect.size)
		card["name_rect"] = Rect2(card.rect.position+Vector2(14,0),Vector2(100,card.rect.size.y))
		card["visible_content"] = ["name","prompt_buttons"]
		for slot in range(buttons.size()):
			var center: Vector2 = card.rect.position+Vector2(GUIDE_KEY_START+slot*GUIDE_KEY_SPACING,card.rect.size.y*.5)
			buttons[slot]["center"] = center
			buttons[slot]["rect"] = Rect2(center-Vector2.ONE*GUIDE_KEY_SIZE*.5,Vector2.ONE*GUIDE_KEY_SIZE)
			buttons[slot]["drawn_rect"] = Rect2(buttons[slot].rect.position+Vector2(card.draw_offset),buttons[slot].rect.size)
			buttons[slot]["extent"] = GUIDE_KEY_SIZE
			buttons[slot]["spacing"] = GUIDE_KEY_SPACING
			buttons[slot]["glyph_font_size"] = 24
	return recipes

func _fever_guide_effect() -> String:
	var threshold := maxi(1,int(rhythm.get("fever_threshold",Rules.FEVER_BASE_THRESHOLD)))
	var energy := maxi(0,int(rhythm.get("fever_energy",0)))
	var energy_max := maxi(1,int(rhythm.get("fever_energy_max",10)))
	if bool(rhythm.get("fever_active",false)) and energy>=energy_max:
		return "聚拢→合成→蓄势→全屏重击"
	if energy>=energy_max:
		return "进入Fever后可用 · 需要Combo%d" % threshold
	return "圈内攻击 · 满能全屏" if bool(rhythm.get("fever_active",false)) else "进入Fever后可用 · 需要Combo%d" % threshold

func _draw() -> void:
	if rhythm.is_empty() or not bool(rhythm.get("enabled",false)): return
	for card in _guide_cards():
		draw_set_transform(Vector2(card.draw_offset))
		var box: Rect2 = card.rect
		var tone := ORANGE if str(card.id)=="fever" else SUCCESS
		var active := bool(card.active) and not bool(card.locked)
		draw_style_box(_guide_skin(active,bool(card.locked),tone),box)
		_center(str(card.name),card.name_rect,24,tone if active or not bool(card.locked) else Color("#72697f"))
		_draw_guide_buttons(card.prompt_buttons)
		if bool(card.border_motion): _draw_fever_card_border(box)
		if bool(card.full_energy_corners): _draw_full_energy_corners(box)
		if bool(card.unknown_feedback.border_visible):
			draw_rect(box.grow(-3),Color("#eed4ed"),false,2)
	draw_set_transform(Vector2.ZERO)

func _draw_fever_card_border(box: Rect2) -> void:
	var phase := float(posmod(int(rhythm.get("tick",0)),60))/60.0
	var pulse := pow(1.0-float(posmod(int(rhythm.get("tick",0)),30))/30.0,2.0)
	draw_rect(box.grow(-3),Color(CREAM,.3+.5*pulse),false,2.0+2.0*pulse)
	var length := box.size.x*.24
	var x := box.position.x+phase*(box.size.x-length)
	draw_line(Vector2(x,box.position.y+3),Vector2(x+length,box.position.y+3),Color("#ffd66b"),4,true)
	draw_line(Vector2(box.end.x-(x-box.position.x),box.end.y-3),Vector2(box.end.x-(x-box.position.x)-length,box.end.y-3),Color("#e8a0a6"),4,true)

func _draw_full_energy_corners(box: Rect2) -> void:
	# Availability still has its light flowing edge; full energy adds a separate,
	# steady shape, so the distinction survives reduced effects and every skin.
	for inset in [3.0,9.0]:
		var frame: Rect2 = box.grow(-inset)
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var at: Vector2 = frame.get_center()+frame.size*.5*corner
			var points := PackedVector2Array([at-Vector2(corner.x*24,0),at,at-Vector2(0,corner.y*18)])
			draw_polyline(points,Color("#17212c"),7,true)
			draw_polyline(points,Color("#ffe39a") if inset==3.0 else Color("#dca741"),3,true)

func _guide_skin(active: bool, locked: bool, tone: Color) -> StyleBoxTexture:
	var key := str(active)+str(locked)+tone.to_html(true)+theme_skin
	if not _guide_skins.has(key):
		var fill := Color("#3e2d50") if active else Color("#251d39")
		var edge := tone if active else Color("#8b7299")
		if theme_skin!="default":
			fill=Color("#101e32") if theme_skin=="board_neon" else Color("#28213e")
			edge=tone if active else Color("#51d8e5") if theme_skin=="board_neon" else Color("#cfba86")
		if locked and not active:
			fill=Color("#211a32")
			edge=Color("#665273")
		_guide_skins[key]=WorkshopSkin.plate(fill,edge,2 if active else 1)
	return _guide_skins[key]

func _draw_guide_buttons(buttons: Array) -> void:
	for index in range(buttons.size()):
		var button: Dictionary = buttons[index]
		var center: Vector2 = button.center
		var half := GUIDE_KEY_SIZE*.5
		var tone: Color = button.color
		var key_state := str(button.get("feedback_state","idle"))
		var highlighted := bool(button.get("highlighted",false))
		var response := str(button.get("fill","solid"))=="outline"
		var current := bool(button.get("current",false))
		var edge := Color("#fff5d4") if key_state in ["input_matched","waiting_complete"] or current else (tone if highlighted else tone.darkened(.15))
		var fill := tone if key_state in ["input_matched","waiting_complete"] else Color("#211a35")
		var glyph_tone := Color("#17212c") if key_state in ["input_matched","waiting_complete"] else tone
		if str(button.shape)=="circle":
			if not response: draw_circle(center,half,fill,true,-1.0,true)
			if highlighted: draw_circle(center,half+2,Color("#111923"),false,6,true)
			draw_circle(center,half,edge,false,3.5 if highlighted else 2.5,true)
			if current: draw_circle(center,half-4,Color("#fff5d4"),false,1.5,true)
		else:
			var box: Rect2 = button.rect
			if not response: draw_rect(box,fill)
			if highlighted: draw_rect(box.grow(2),Color("#111923"),false,6)
			draw_rect(box,edge,false,3.5 if highlighted else 2.5)
			if current: draw_rect(box.grow(-4),Color("#fff5d4"),false,1.5)
		_center(str(button.glyph),button.rect,24,glyph_tone,false)

func get_presentation_state() -> Dictionary:
	return {"clock":"simulation","layout":"footer_command_guide","guide_cards":_guide_cards(),"input_mode":"relative_four_beat","timing_rail":false,
		"tempo_reference_bpm":120,"reference_pulse_active":false,
		"phase":str(rhythm.get("phase","idle")),"cadence_caption":_cadence_caption(),"remaining_ticks":int(rhythm.get("remaining_ticks",0)),"last_response_token":last_response_token,
		"input_device":input_device,"input_legend":str(INPUT_LEGENDS[input_device]),"paused":is_paused,"count_in_frames":0,
		"display_slots":_visible_slots(),"slot_feedback":_slot_feedback(),"last_input_key":last_input_key,"word_pulses":word_pulses.duplicate(true),
		"command_feedback":_command_feedback(),"unknown_feedback":_unknown_state(),"accepted_prefix":_accepted_prefix.duplicate(),"phrase_combo":int(rhythm.get("phrase_combo",0)),"basic_chain":int(rhythm.get("basic_chain",0)),
		"fever_active":bool(rhythm.get("fever_active",false)),"fever_ready":{"active":_fever_ready(),"tick":fever_ready_tick,"transitions":fever_ready_count},
		"fever_energy":int(rhythm.get("fever_energy",0)),"fever_energy_max":int(rhythm.get("fever_energy_max",10)),"fever_threshold":int(rhythm.get("fever_threshold",Rules.FEVER_BASE_THRESHOLD)),
		"chain_caption":_chain_feedback(),"rhythm":rhythm.duplicate(true)}


func set_theme_skin(value: String) -> void:
	theme_skin=value
	_guide_skins.clear()
	queue_redraw()
