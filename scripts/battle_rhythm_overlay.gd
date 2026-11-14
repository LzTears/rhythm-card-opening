extends Control
## Directional input and response feedback. Its only clock is simulation tick.
## This Control never reads hardware, submits keys, changes combat or grants rewards.
const Rules = preload("res://scripts/pack_rules.gd")
const DESIGN_SIZE := Vector2(1920,1080)
const WORDS := {"pata":"PATA","pon":"PON","don":"DON","chaka":"CHAKA"}
const ANCHORS := {"pata":Vector2(195,510),"pon":Vector2(1725,510),"don":Vector2(960,790),"chaka":Vector2(960,255)}
const TONES := {"pata":Color("#ff9757"),"pon":Color("#72d7f5"),"don":Color("#ffd44f"),"chaka":Color("#a9df70")}
const FEVER_PATH := "res://assets/ui/rhythm_feedback/fever.png"
const COMBO_PATH := "res://assets/ui/rhythm_feedback/combo.png"
const COMBO_DIGIT_DIR := "res://assets/ui/rhythm_feedback/combo_digits/"
const JUDGEMENT_PATHS := {"perfect":"res://assets/ui/rhythm_feedback/judgement/perfect.png","miss":"res://assets/ui/rhythm_feedback/judgement/miss.png"}
const COMMAND_ORDER := ["gather","expand","merge","fever"]
const COMMAND_RECIPES := {"gather":["pata","pata","pata","pon"],"expand":["pon","pon","pata","pon"],"merge":["chaka","chaka","pata","pon"],"fever":["don","don","pata","pon"]}
const RESPONSE_WORD_SIZE := 60
const JUDGEMENT_SIZE := Vector2(168,56)
const JUDGEMENT_DESKTOP_BOUNDS := Rect2(18,134,1884,786)
const COMBO_DISPLAY_MAX := 99
const FEVER_BOUNDS := Rect2(426,18,240,100)
const FEVER_WORDMARK_BOUNDS := Rect2(426,18,240,100)
const FEVER_WORDMARK_ENABLED := true # Fever follows the complete Combo group.
const FEVER_ENERGY_BOUNDS := Rect2(1490,940,380,110)
const ENERGY_BAR_BOUNDS := Rect2(1506,970,348,18)
const ENERGY_HINT_BOUNDS := Rect2(1506,1006,348,34)
const FOOTER_FULL_FX_BOUNDS := Rect2(18,920,1884,144)
const FOOTER_FULL_FX_ENABLED := false # Removed by user; keep the energy bar's own feedback.
const ENERGY_FULL_BURST_TICKS := 72
const COMBO_BOUNDS := Rect2(28,18,376,100)
const COMBO_NUMBER_BOUNDS := Rect2(270,18,134,100)
const COMBO_WORDMARK_BOUNDS := Rect2(28,18,240,100)
const INPUT_LIFE := 27 # 15tick pop + 12tick fade, approximately .25s + .2s.
const RESPONSE_LIFE := 22
const INVALID_FADE := 12
const ERROR_LIFE := 36 # .6 seconds on the simulation clock, including reduced effects.
const PERFECT_LIFE := 18
const INK := Color("#111923")
const KEYBOARD_GLYPHS := {"pata":"←","pon":"→","don":"↓","chaka":"↑"}
const XBOX_GLYPHS := {"pata":"X","pon":"B","don":"A","chaka":"Y"}
const XBOX_TONES := {"pata":Color("#439bf6"),"pon":Color("#f06461"),"don":Color("#79d261"),"chaka":Color("#ffdc51")}
const FEVER_BEAT_TICKS := 30
const COMBO_BEAT_TICKS := 30
const COMBO_POP_TICKS := 32
const SWEEP_SHADER := "shader_type canvas_item;\nuniform float sweep = -1.0;\nuniform float strength = 0.0;\nvoid fragment() {\n vec4 original = texture(TEXTURE, UV) * COLOR;\n float band = max(0.0, 1.0 - abs(UV.x + UV.y * 0.18 - sweep) / 0.16);\n original.rgb = mix(original.rgb, vec3(1.0, 0.98, 0.70), band * strength);\n COLOR = original;\n}"

var beat_skin := "default"
var display_font: Font
var body_font: Font
var _state: Dictionary = {}
var _state_tick := -1
var _display_tick := -1
var _baseline_tick := -1
var _initialized := false
var _paused := false
var _reduced := false
var _seen: Dictionary = {}
var _pulses: Dictionary = {}
var _input_count := 0
var _response_count := 0
var _combo := 0
var _combo_display := 0
var _combo_tick := -100000
var _combo_exit_tick := -100000
var _combo_count := 0
var _fever := false
var _fever_tick := -100000
var _fever_exit_tick := -100000
var _fever_count := 0
var _burst_tick := -100000
var _burst_count := 0
var _last_burst_serial := -1
var _fever_alpha := 0.0
var _combo_alpha := 0.0
var _fever_stamp: TextureRect
var _combo_stamp: TextureRect
var _fever_texture: Texture2D
var _combo_texture: Texture2D
var _fever_rect := Rect2()
var _combo_rect := Rect2()
var _number_rect := Rect2()
var _asset_retry_tick := -100000
var _input_device := "keyboard"
var _fever_beat_origin := -100000
var _combo_beat_origin := -100000
var _fever_motion: Dictionary = {}
var _combo_motion: Dictionary = {}
var _fever_material: ShaderMaterial
var _combo_material: ShaderMaterial
var _fever_energy := 0
var _fever_energy_max := 10
var _fever_threshold := Rules.FEVER_BASE_THRESHOLD
var _energy_visible := false
var _energy_beat_origin := -100000
var _energy_motion: Dictionary = {}
var _energy_track_rect := Rect2()
var _energy_fill_rect := Rect2()
var _energy_gain_tick := -100000
var _energy_gain_from := 0
var _energy_gain_to := 0
var _energy_gain_count := 0
var _energy_full_tick := -100000
var _energy_full_count := 0
var _combo_digit_textures: Dictionary = {}
var _combo_digit_nodes: Array[TextureRect] = []
var _combo_digit_layout: Array[Dictionary] = []
var _footer_full_particles: Array[Dictionary] = []
var _footer_full_flows: Array[Dictionary] = []
var _circle_screen_anchor := Vector2(960,540)
var _error_feedback: Dictionary = {} # Compatibility summary; never a drawn text panel.
var _input_prefix: Array[String] = []
var _last_matching_prefix: Array[String] = []
var _judgement_records: Dictionary = {}
var _judgement_nodes: Dictionary = {}
var _judgement_textures: Dictionary = {}
var _judgement_source_alpha: Dictionary = {}
var _judgement_trigger_count := 0

func _ready() -> void:
	name = "BattleRhythmOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_nodes()
	_refresh()

func set_fonts(pixel: Font, body: Font) -> void:
	display_font = pixel
	body_font = body
	_refresh()

func set_input_device(value: String) -> void:
	if value not in ["keyboard","joypad"] or value==_input_device: return
	_input_device = value
	_refresh()

func set_circle_screen_anchor(design_anchor: Vector2) -> void:
	if not design_anchor.is_finite(): return
	_circle_screen_anchor = design_anchor
	_refresh()

func set_state(value: Dictionary, paused: bool, reduced: bool = false) -> void:
	if value.has("drum_input_device"): set_input_device(str(value.drum_input_device))
	var now := int(value.get("tick",-1))
	var new_run := not _initialized or now<_state_tick
	if not _state.is_empty() and value.has("run_id") and _state.has("run_id") and str(value.run_id)!=str(_state.run_id): new_run = true
	if new_run:
		clear_presentation()
		_initialized = true
		_baseline_tick = now
		_display_tick = now
		_combo = maxi(0,int(value.get("phrase_combo",0)))
		_combo_display = mini(_combo,COMBO_DISPLAY_MAX)
		if _combo>0: _combo_beat_origin = now
		_fever = bool(value.get("fever_active",false))
		if _fever: _fever_beat_origin = now
		_energy_beat_origin = now
	_state_tick = now
	_paused = paused
	_reduced = reduced
	if not paused: _display_tick = now
	_state = value.duplicate(true)
	# These values come only from the current simulation snapshot. A restored
	# or broken chain must never reconstruct energy from Combo or old events.
	var previous_energy := _fever_energy
	var was_full := _fever_energy>=_fever_energy_max
	_fever_energy_max = maxi(1,int(value.get("fever_energy_max",10)))
	_fever_energy = clampi(int(value.get("fever_energy",0)),0,_fever_energy_max)
	_fever_threshold = maxi(1,int(value.get("fever_threshold",Rules.FEVER_BASE_THRESHOLD)))
	_energy_visible = bool(value.get("enabled",true))
	if not new_run and not was_full and _fever_energy>=_fever_energy_max and not paused and not reduced:
		_energy_full_tick = now
		_energy_full_count += 1
	if not new_run and _fever_energy>previous_energy and not paused and not reduced:
		_energy_gain_tick = now
		_energy_gain_from = previous_energy
		_energy_gain_to = _fever_energy
		_energy_gain_count += 1
	if _fever_energy<previous_energy or reduced: _energy_gain_tick = -100000
	if reduced: _energy_full_tick = -100000
	if not new_run:
		var actual_combo := maxi(0,int(value.get("phrase_combo",0)))
		if actual_combo>_combo:
			_combo_tick = now
			_combo_beat_origin = now
			_combo_count += 1
			_combo_display = mini(actual_combo,COMBO_DISPLAY_MAX)
		elif actual_combo==0 and _combo>0:
			_combo_exit_tick = now
		elif actual_combo>0:
			_combo_display = mini(actual_combo,COMBO_DISPLAY_MAX)
		_combo = actual_combo
		var actual_fever := bool(value.get("fever_active",false))
		if actual_fever and not _fever: _enter_fever(now)
		elif not actual_fever and _fever: _leave_fever(now)
		# These are committed event snapshots, not another input detector. The
		# initial/restored state intentionally never replays its historical events.
		if not paused:
			present_event(value.get("last_judgement",{}))
			present_event(value.get("response_event",{}))
			present_event(value.get("command_event",value.get("last_command",{})))
	_prune()
	_refresh()

func present_event(event: Dictionary) -> void:
	if event.is_empty() or not _initialized or _paused: return
	var at := int(event.get("tick",-100000))
	if at<=_baseline_tick or at<_state_tick or at>_state_tick+1: return
	var type := str(event.get("type",""))
	var token := _token(event)
	if _seen.has(token): return
	match type:
		"rhythm_judgement":
			_seen[token] = true
			if str(event.get("grade",""))=="miss":
				_show_error(str(event.get("reason","")),at)
				_input_prefix.clear()
				_invalidate(at)
			elif str(event.get("scope",""))=="phrase":
				if bool(event.get("accepted",false)) and str(event.get("grade",""))=="perfect":
					_show_judgement("perfect","perfect",at,_input_prefix)
			elif bool(event.get("accepted",false)):
				var key := str(event.get("key",""))
				var index := int(event.get("word_index",event.get("beat",-1)))
				if not WORDS.has(key) or index<0 or index>3: return
				if index==0:
					_error_feedback.clear()
					_input_prefix.clear()
					_last_matching_prefix.clear()
					_judgement_records.clear()
				# Accepted indexed events survive the Conductor buffer clear.
				if index==_input_prefix.size(): _input_prefix.append(key)
				if not _matching_commands(_input_prefix).is_empty(): _last_matching_prefix.assign(_input_prefix)
				if str(event.get("grade",""))=="perfect":
					_show_judgement("perfect","perfect",at,_input_prefix)
				_pulses["input/"+key] = {"key":key,"tick":at,"response":false,"word_index":index,"invalid_tick":-100000,"grade":str(event.get("grade","input"))}
				_input_count += 1
				if _fever: _fever_beat_origin = at
				if _combo>0: _combo_beat_origin = at
				_energy_beat_origin = at
		"rhythm_response":
			if not bool(event.get("executed",false)): return
			var key := str(event.get("key",""))
			var serial := int(event.get("command_serial",event.get("serial",0)))
			var index := int(event.get("word_index",event.get("beat",-1)))
			if not WORDS.has(key) or serial<=0 or index<0 or index>3: return
			_seen[token] = true
			_pulses["response/"+key] = {"key":key,"tick":at,"response":true,"word_index":index,"invalid_tick":-100000}
			_response_count += 1
			if _fever: _fever_beat_origin = at
			if _combo>0: _combo_beat_origin = at
			_energy_beat_origin = at
			if str(event.get("preset_id",""))=="fever" and index==3 and bool(event.get("global_burst",event.get("fever_global",false))) and serial!=_last_burst_serial:
				_last_burst_serial = serial
				_burst_tick = at
				_burst_count += 1
		"fever_enter":
			_seen[token] = true
			if bool(event.get("active",false)) and not _fever: _enter_fever(at)
		"preparation_reset":
			_seen[token] = true
			_show_error(str(event.get("reason","")),at)
			_input_prefix.clear()
			_invalidate(at)
		"rhythm_command":
			_seen[token] = true
			if str(event.get("status",""))=="unknown":
				# HUD owns the card-only unknown gesture, with no Miss or text.
				_judgement_records.clear()
				_error_feedback.clear()
				_input_prefix.clear()
				_invalidate(at)
	_refresh()

func clear_presentation() -> void:
	_state.clear()
	_seen.clear()
	_pulses.clear()
	_state_tick = -1
	_display_tick = -1
	_baseline_tick = -1
	_initialized = false
	_paused = false
	_input_count = 0
	_response_count = 0
	_combo = 0
	_combo_display = 0
	_combo_tick = -100000
	_combo_exit_tick = -100000
	_combo_count = 0
	_fever = false
	_fever_tick = -100000
	_fever_exit_tick = -100000
	_fever_count = 0
	_burst_tick = -100000
	_burst_count = 0
	_last_burst_serial = -1
	_asset_retry_tick = -100000
	_fever_beat_origin = -100000
	_combo_beat_origin = -100000
	_fever_energy = 0
	_fever_energy_max = 10
	_fever_threshold = Rules.FEVER_BASE_THRESHOLD
	_energy_visible = false
	_energy_beat_origin = -100000
	_energy_full_tick = -100000
	_energy_full_count = 0
	_energy_gain_tick = -100000
	_energy_gain_from = 0
	_energy_gain_to = 0
	_energy_gain_count = 0
	_footer_full_particles.clear()
	_footer_full_flows.clear()
	_error_feedback.clear()
	_input_prefix.clear()
	_last_matching_prefix.clear()
	_judgement_records.clear()
	_judgement_trigger_count = 0
	_refresh()

func get_presentation_state() -> Dictionary:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _pulses.values():
		var style := _pulse_style(record)
		var response := bool(record.response)
		var prompt := _input_prompt(str(record.key))
		prompt["fill"] = "outline" if response else "solid"
		var word_geometry := _word_geometry(record,_canvas_scale())
		rows.append({"word_geometry":word_geometry,"word_font_size":word_geometry.font_size,"word_motion_enabled":not _reduced,"word_texture_filter":texture_filter,"key":record.key,"word":WORDS[record.key],"source":"response" if response else "input","anchor":ANCHORS[record.key],"tick":record.tick,"age_ticks":maxi(0,_display_tick-int(record.tick)),"word_index":record.word_index,"alpha":style.alpha,"scale":style.scale,"lift":style.lift,"prompt":prompt,"prompt_tick":record.tick,"prompt_alpha":style.alpha,"prompt_scale":style.scale,"word_fill":"solid_echo" if response else "solid","grade":str(record.get("grade","response")),"perfect_marker":_perfect_marker_state(record)})
	var number := _combo_number_layout()
	return {"tick":_state_tick,"display_tick":_display_tick,"paused":_paused,"reduced":_reduced,"input_device":_input_device,"beat_skin":beat_skin,"pulses":rows,"input_feedback_count":_input_count,"response_feedback_count":_response_count,"phrase_combo":_combo,"combo_actual":_combo,"combo_display":_combo_display,"combo_display_cap":COMBO_DISPLAY_MAX,"combo_pop_count":_combo_count,"combo_alpha":_combo_alpha,"combo_number_text":"×"+str(_combo_display),"combo_number_font":"art_glyphs" if _digit_assets_loaded() else "body_vector_fallback","combo_number_font_path":COMBO_DIGIT_DIR if _digit_assets_loaded() else _body_font().resource_path,"combo_number_font_size":64,"combo_number_fit_scale":number.scale,"digit_assets_loaded":_digit_assets_loaded(),"combo_digit_assets_loaded":_digit_assets_loaded(),"combo_digit_glyphs":_combo_digit_layout.duplicate(true),"fever_active":_fever,"fever_entry_count":_fever_count,"fever_burst_count":_burst_count,"fever_alpha":_fever_alpha,"fever_wordmark_enabled":FEVER_WORDMARK_ENABLED,"fever_asset":FEVER_PATH,"combo_asset":COMBO_PATH,"fever_texture_loaded":_fever_texture!=null,"combo_texture_loaded":_combo_texture!=null,"fever_rect":_fever_rect,"combo_rect":_combo_rect,"combo_number_rect":_number_rect,"fever_motion":_fever_motion.duplicate(true),"combo_motion":_combo_motion.duplicate(true),"fever_max_bounds":FEVER_BOUNDS,"fever_wordmark_bounds":FEVER_WORDMARK_BOUNDS,"fever_energy_bar":_energy_bar_state(),"footer_full_fx":_footer_full_fx_state(),"combo_max_bounds":COMBO_BOUNDS,"error_feedback":_error_state(),"judgement_feedback":_judgement_state(),"accepted_prefix":_input_prefix.duplicate(),"circle_screen_anchor":_circle_screen_anchor,"has_wall_clock":false}

func _matching_commands(prefix: Array) -> Array[String]:
	var result: Array[String] = []
	if prefix.is_empty() or prefix.size()>4: return result
	for id: String in COMMAND_ORDER:
		var recipe: Array = COMMAND_RECIPES[id]
		var matches := true
		for slot in range(prefix.size()):
			if str(prefix[slot])!=str(recipe[slot]): matches = false
		if matches: result.append(id)
	return result

func _show_judgement(kind: String, reason: String, at: int, prefix: Array, target_prefix: Array = []) -> void:
	var matched_prefix := prefix if target_prefix.is_empty() else target_prefix
	var targets := _matching_commands(matched_prefix)
	if targets.is_empty(): return # Never guess a recipe for an unmatched prefix.
	_judgement_trigger_count += 1
	# One shared circle wordmark for every recipe. The candidate list is kept
	# as metadata; it does not create or position additional visible stamps.
	_judgement_records.clear()
	var id: String = targets[0]
	_judgement_records[id] = {"id":id,"target_ids":targets.duplicate(),"kind":kind,"reason":reason,"tick":at,"prefix":prefix.duplicate(),"matched_prefix":matched_prefix.duplicate(),"trigger":_judgement_trigger_count}

func _show_error(reason: String, at: int) -> void:
	if reason not in ["too_fast","timeout","handoff_timeout"]: return
	# Simulation emits preparation_reset before the same cadence judgement.
	# Keep the first captured prefix and never clear its stamp on that duplicate.
	if int(_error_feedback.get("tick",-100000))==at and str(_error_feedback.get("reason",""))==reason: return
	# Cadence failures share Miss art; their raw reason remains observable.
	_judgement_records.clear()
	_show_judgement("miss",reason,at,_input_prefix,_last_matching_prefix if _matching_commands(_input_prefix).is_empty() else [])
	_error_feedback = {"reason":reason,"tick":at}

func _judgement_bounds() -> Rect2:
	var position := _circle_screen_anchor+Vector2(0,70)-JUDGEMENT_SIZE*.5
	# Keep the base 168x56 envelope within the desk even if the projected circle
	# moves. The normal anchor+(0,70) position is unaffected by these guards.
	position.x = clampf(position.x,JUDGEMENT_DESKTOP_BOUNDS.position.x+2,JUDGEMENT_DESKTOP_BOUNDS.end.x-JUDGEMENT_SIZE.x-2)
	position.y = clampf(position.y,JUDGEMENT_DESKTOP_BOUNDS.position.y+2,JUDGEMENT_DESKTOP_BOUNDS.end.y-JUDGEMENT_SIZE.y-2)
	return Rect2(position,JUDGEMENT_SIZE)

func _primary_judgement_record() -> Dictionary:
	for record: Dictionary in _judgement_records.values(): return record
	return {}

func _judgement_style(record: Dictionary) -> Dictionary:
	var age := _display_tick-int(record.get("tick",-100000))
	var life := PERFECT_LIFE if str(record.get("kind",""))=="perfect" else ERROR_LIFE
	var active := age>=0 and age<life
	var alpha := 1.0 if _reduced else 1.0-smoothstep(float(life)*.55,float(life),float(age))
	var motion_age := clampf(float(age),0.0,15.0)
	var pop := 1.0
	var lift := 0.0
	var angle := 0.0
	if not _reduced and active:
		pop = lerpf(.62,1.12,_out_cubic(motion_age/5.0)) if motion_age<5.0 else lerpf(1.12,1.0,smoothstep(5.0,15.0,motion_age))
		lift = -sin(motion_age/15.0*PI)*12.0
		angle = (-.10 if str(record.get("kind",""))=="perfect" else .10)*(1.0-smoothstep(0.0,15.0,motion_age))
	return {"active":active,"age_ticks":age,"lifetime_ticks":life,"alpha":alpha if active else 0.0,"scale":pop,"lift":lift,"rotation":angle}

func _judgement_state() -> Dictionary:
	var cards: Array[Dictionary] = []
	var primary: Dictionary = {}
	if _judgement_nodes.has("primary"):
		var stamp: TextureRect = _judgement_nodes["primary"]
		var record := _primary_judgement_record()
		var style := _judgement_style(record)
		var kind := str(record.get("kind",""))
		var local_rect := Rect2(stamp.position,stamp.size)
		var canvas_scale := _canvas_scale()
		primary = {"id":str(record.get("id","")),"target_ids":record.get("target_ids",[]).duplicate(),"kind":kind,"reason":str(record.get("reason","")),"tick":int(record.get("tick",-100000)),"prefix":record.get("prefix",[]).duplicate(),"matched_prefix":record.get("matched_prefix",[]).duplicate(),"trigger":int(record.get("trigger",0)),"visible":stamp.visible,"alpha":stamp.modulate.a,"rect":Rect2(local_rect.position/canvas_scale,local_rect.size/canvas_scale),"node_rect":local_rect,"bounds":_judgement_bounds(),"anchor":_judgement_bounds().get_center(),"texture_path":str(JUDGEMENT_PATHS.get(kind,"")),"texture_loaded":stamp.texture!=null,"source_size":stamp.texture.get_size() if stamp.texture!=null else Vector2.ZERO,"source_has_alpha":bool(_judgement_source_alpha.get(kind,false)),"texture_filter":stamp.texture_filter,"age_ticks":style.age_ticks,"lifetime_ticks":style.lifetime_ticks,"scale":stamp.scale,"rotation":stamp.rotation,"lift":style.lift,"motion_enabled":not _reduced,"visual_rect":Rect2((stamp.get_transform()*Rect2(Vector2.ZERO,stamp.size)).position/canvas_scale,(stamp.get_transform()*Rect2(Vector2.ZERO,stamp.size)).size/canvas_scale)}
		# Compatibility metadata for consumers that still enumerate four recipes.
		# Only the primary row can be visible, and all geometry is read from the
		# same single TextureRect at the circle rather than from any card rect.
		for id: String in COMMAND_ORDER:
			var row := primary.duplicate(true)
			row["id"] = id
			row["visible"] = bool(primary.visible) and id==str(primary.id)
			cards.append(row)
	return {"clock":"simulation","placement":"near_main_circle","primary":primary,"cards":cards,"trigger_count":_judgement_trigger_count,"node_count":_judgement_nodes.size(),"perfect_loaded":_judgement_textures.has("perfect"),"miss_loaded":_judgement_textures.has("miss"),"text_fallback":false,"direction_marker":false,"main_circle_panel":false,"main_circle_wordmark":true,"footer_wordmark":false}

func _error_state() -> Dictionary:
	var visible := false
	var rect := Rect2()
	for card: Dictionary in _judgement_state().cards:
		if str(card.kind)=="miss" and bool(card.visible):
			visible = true
			rect = card.rect if not rect.has_area() else rect.merge(card.rect)
	return {"visible":visible,"caption":"Miss" if visible else "","reason":str(_error_feedback.get("reason","")) if visible else "","tick":int(_error_feedback.get("tick",-100000)),"lifetime_ticks":ERROR_LIFE,"rect":rect,"clock":"simulation","presentation":"circle_texture"}

func _perfect_marker_state(_record: Dictionary) -> Dictionary:
	# Explicit compatibility observation: no direction-star is drawn.
	return {"visible":false,"lifetime_ticks":PERFECT_LIFE,"shape":"none","alpha":0.0,"motion_enabled":false,"moved_to":"circle_judgement"}

func _input_prompt(key: String) -> Dictionary:
	var joypad := _input_device=="joypad"
	return {"device":_input_device,"shape":"circle" if joypad else "square","glyph":XBOX_GLYPHS[key] if joypad else KEYBOARD_GLYPHS[key],"color":XBOX_TONES[key] if joypad else TONES[key],"family":"Xbox" if joypad else "PC"}

func _token(event: Dictionary) -> String:
	var type := str(event.get("type",""))
	if type=="rhythm_judgement":
		return "%s/%s/%s/%s/%s/%s" % [type,str(event.get("tick",-1)),str(event.get("input_index",-1)),str(event.get("word_index",event.get("beat",-1))),str(event.get("key","")),str(event.get("grade",""))]
	if type=="rhythm_response":
		return "%s/%s/%s" % [type,str(event.get("command_serial",event.get("serial",0))),str(event.get("word_index",event.get("beat",-1)))]
	return "%s/%s/%s" % [type,str(event.get("event_id",event.get("tick",-1))),str(event.get("command_serial",0))]

func _enter_fever(at: int) -> void:
	_fever = true
	_fever_tick = at
	_fever_beat_origin = at
	_fever_exit_tick = -100000
	_fever_count += 1

func _leave_fever(at: int) -> void:
	_fever = false
	_fever_exit_tick = at

func _invalidate(at: int) -> void:
	for record: Dictionary in _pulses.values(): record.invalid_tick = at
	if _fever: _leave_fever(at)
	if _combo>0:
		_combo_exit_tick = at
		_combo = 0

func _prune() -> void:
	for key in _pulses.keys():
		var record: Dictionary = _pulses[key]
		var life := RESPONSE_LIFE if bool(record.response) else INPUT_LIFE
		if _display_tick-int(record.tick)>=life or int(record.invalid_tick)>-100000 and _display_tick-int(record.invalid_tick)>=INVALID_FADE:
			_pulses.erase(key)

func _ensure_nodes() -> void:
	if is_instance_valid(_fever_stamp): return
	_fever_stamp = TextureRect.new()
	_fever_stamp.name = "OriginalFeverWordmark"
	_combo_stamp = TextureRect.new()
	_combo_stamp.name = "OriginalComboWordmark"
	for stamp: TextureRect in [_fever_stamp,_combo_stamp]:
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(stamp)
	var judgement := TextureRect.new()
	judgement.name = "JudgementPrimary"
	judgement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	judgement.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	judgement.stretch_mode = TextureRect.STRETCH_SCALE
	judgement.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	judgement.visible = false
	add_child(judgement)
	_judgement_nodes["primary"] = judgement
	var shader := Shader.new()
	shader.code = SWEEP_SHADER
	_fever_material = ShaderMaterial.new()
	_fever_material.shader = shader
	_combo_material = ShaderMaterial.new()
	_combo_material.shader = shader
	_fever_stamp.material = _fever_material
	_combo_stamp.material = _combo_material
	for index in range(3):
		var glyph := TextureRect.new()
		glyph.name = "ComboArtGlyph%d" % index
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glyph.material = _combo_material
		add_child(glyph)
		_combo_digit_nodes.append(glyph)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path) as Texture2D
		if resource!=null: return resource
	if FileAccess.file_exists(path):
		var source := Image.load_from_file(path)
		if source!=null and not source.is_empty(): return ImageTexture.create_from_image(source)
	return null

func _digit_assets_loaded() -> bool:
	return _combo_digit_textures.size()==11

func _ensure_assets() -> void:
	if _fever_texture!=null and _combo_texture!=null and _digit_assets_loaded() and _judgement_textures.size()==2: return
	if _display_tick<_asset_retry_tick+30 and _asset_retry_tick>-100000: return
	_asset_retry_tick = _display_tick
	if _fever_texture==null: _fever_texture = _load_texture(FEVER_PATH)
	if _combo_texture==null: _combo_texture = _load_texture(COMBO_PATH)
	for kind: String in JUDGEMENT_PATHS:
		if _judgement_textures.has(kind): continue
		var texture := _load_texture(str(JUDGEMENT_PATHS[kind]))
		if texture!=null:
			_judgement_textures[kind] = texture
			var source := texture.get_image()
			_judgement_source_alpha[kind] = source!=null and source.detect_alpha()!=Image.ALPHA_NONE
	for key: String in ["x","0","1","2","3","4","5","6","7","8","9"]:
		if _combo_digit_textures.has(key): continue
		var texture := _load_texture(COMBO_DIGIT_DIR+key+".png")
		if texture!=null: _combo_digit_textures[key] = texture

func _refresh() -> void:
	if not is_inside_tree(): return
	_ensure_nodes()
	_ensure_assets()
	_fever_alpha = (1.0 if _fever else _fade_since(_fever_exit_tick,INVALID_FADE)) if FEVER_WORDMARK_ENABLED else 0.0
	_combo_alpha = 1.0 if _combo>0 else _fade_since(_combo_exit_tick,INVALID_FADE)
	_fever_motion = _fever_motion_style()
	_combo_motion = _combo_motion_style()
	_energy_motion = _energy_motion_style()
	_fever_rect = _scaled_rect(FEVER_WORDMARK_BOUNDS,float(_fever_motion.scale))
	_fever_rect.position.y += float(_fever_motion.lift)
	var energy_width := ENERGY_BAR_BOUNDS.size.x*float(_energy_motion.scale)
	var energy_height := float(_energy_motion.height)
	_energy_track_rect = Rect2(ENERGY_BAR_BOUNDS.get_center()-Vector2(energy_width,energy_height)*.5,Vector2(energy_width,energy_height))
	_energy_fill_rect = _energy_track_rect.grow(-3.0)
	_energy_fill_rect.size.x *= float(_fever_energy)/_fever_energy_max
	_refresh_footer_full_fx()
	# One group transform keeps the real number attached to its wordmark through
	# both the persistent beat and each stronger committed-phrase pop.
	_combo_rect = _combo_group_rect(COMBO_WORDMARK_BOUNDS)
	_number_rect = _combo_group_rect(COMBO_NUMBER_BOUNDS)
	_fever_material.set_shader_parameter("sweep",float(_fever_motion.sweep))
	_fever_material.set_shader_parameter("strength",float(_fever_motion.sweep_strength))
	_combo_material.set_shader_parameter("sweep",float(_combo_motion.sweep))
	_combo_material.set_shader_parameter("strength",float(_combo_motion.sweep_strength))
	var canvas_scale := _canvas_scale()
	_fever_stamp.texture = _fever_texture
	_fever_stamp.position = _fever_rect.position*canvas_scale
	_fever_stamp.size = _fever_rect.size*canvas_scale
	_fever_stamp.modulate = Color(1,1,1,_fever_alpha)
	_fever_stamp.visible = _fever_alpha>0.0 and _fever_texture!=null
	_combo_stamp.texture = _combo_texture
	_combo_stamp.position = _combo_rect.position*canvas_scale
	_combo_stamp.size = _combo_rect.size*canvas_scale
	_combo_stamp.modulate = Color(1,1,1,_combo_alpha)
	_combo_stamp.visible = _combo_alpha>0.0 and _combo_texture!=null
	_refresh_combo_digits(canvas_scale)
	_refresh_judgements(canvas_scale)
	queue_redraw()

func _refresh_judgements(canvas_scale: Vector2) -> void:
	var stamp: TextureRect = _judgement_nodes["primary"]
	var record := _primary_judgement_record()
	var kind := str(record.get("kind",""))
	var style := _judgement_style(record)
	var texture: Texture2D = _judgement_textures.get(kind)
	var bounds := _judgement_bounds()
	var rect := bounds
	if texture!=null:
		var source := texture.get_size()
		var fit := minf(bounds.size.x/maxf(1.0,source.x),bounds.size.y/maxf(1.0,source.y))
		var extent := source*fit
		rect = Rect2(bounds.get_center()-extent*.5,extent)
	stamp.texture = texture
	stamp.position = (rect.position+Vector2(0,float(style.lift)))*canvas_scale
	stamp.size = rect.size*canvas_scale
	stamp.pivot_offset = stamp.size*.5
	stamp.scale = Vector2.ONE*float(style.scale)
	stamp.rotation = float(style.rotation)
	stamp.modulate = Color(1,1,1,float(style.alpha))
	stamp.visible = bool(style.active) and texture!=null

func _fever_motion_style() -> Dictionary:
	var beat_age := posmod(_display_tick-_fever_beat_origin,FEVER_BEAT_TICKS) if _fever_beat_origin>-100000 else 0
	var burst_age := _display_tick-_burst_tick
	var entry_age := _display_tick-_fever_tick
	var bursting := _fever and burst_age>=0 and burst_age<26
	var strength := 0.0
	var scale_value := .86
	var lift := 0.0
	var sweep := -1.0
	if _fever and not _reduced:
		# A visible jump returns every half-second for the WHOLE Fever state.
		# Real accepted/response beats re-anchor it; no hardware or wall clock.
		strength = pow(1.0-float(beat_age)/FEVER_BEAT_TICKS,2.0)
		scale_value = .79+.17*strength
		lift = -sin(float(beat_age)/FEVER_BEAT_TICKS*PI)*8.0
		sweep = lerpf(-.2,1.4,float(beat_age)/FEVER_BEAT_TICKS)
		if entry_age>=0 and entry_age<7:
			scale_value = lerpf(.50,.98,_out_cubic(float(entry_age)/6.0))
			lift = 0.0
		if bursting:
			strength = maxf(strength,1.0-float(burst_age)/26.0)
			scale_value = maxf(scale_value,.80+.18*pow(1.0-float(burst_age)/26.0,.55))
			lift = 0.0
		# The upward hop may only spend the margin created by this scale.
		lift = maxf(lift,-FEVER_WORDMARK_BOUNDS.size.y*(1.0-scale_value)*.5)
	return {"active":_fever and not _reduced,"beat_ticks":FEVER_BEAT_TICKS,"beat_age":beat_age,"scale":scale_value,"lift":lift,"strength":strength,"sweep":sweep,"sweep_strength":.90 if _fever and not _reduced else 0.0,"burst_active":bursting,"burst_emphasis":1.0+minf(4.0,float(_burst_count))*.2 if bursting and not _reduced else 1.0}

func _energy_motion_style() -> Dictionary:
	var beat_age := posmod(maxi(0,_display_tick-_energy_beat_origin),FEVER_BEAT_TICKS) if _energy_beat_origin>-100000 else 0
	var active := _energy_visible and not _reduced
	var phase := float(beat_age)/FEVER_BEAT_TICKS
	var strength := pow(1.0-phase,2.0) if active else 0.0
	var full := _fever_energy>=_fever_energy_max
	var burst_age := _display_tick-_energy_full_tick
	var charging_burst := FOOTER_FULL_FX_ENABLED and full and active and burst_age>=0 and burst_age<ENERGY_FULL_BURST_TICKS
	return {"active":active,"beat_ticks":FEVER_BEAT_TICKS,"beat_age":beat_age,"strength":strength,
		"scale":1.0,"height":14.0+4.0*strength if active else 18.0,
		"edge_strength":.42+.58*strength if active else .55,"edge_width":1.0+1.2*strength if active else 1.5,
		"sweep":lerpf(-.15,1.15,phase) if active else -1.0,"sweep_strength":(.95 if full else .65) if active else 0.0,
		"gold_pulse":full and active,"fill_ratio":float(_fever_energy)/_fever_energy_max,
		"full_burst_active":charging_burst,"full_burst_age":burst_age if charging_burst else -1,"full_burst_ticks":ENERGY_FULL_BURST_TICKS,
		"full_aura_active":false,"particle_count":32 if charging_burst else 0,"footer_marquee_active":charging_burst}

func _energy_bar_state() -> Dictionary:
	var full := _fever_energy>=_fever_energy_max
	var status := "全屏就绪" if full and _fever else "满能待Combo" if full else "圈内蓄能"
	var caption := "%s %d/%d · %s %d/%d" % ["满能" if full else "能量",_fever_energy,_fever_energy_max,"待Combo" if full and not _fever else "Combo",_combo,_fever_threshold]
	return {"visible":_energy_visible,"energy":_fever_energy,"max":_fever_energy_max,"combo":_combo,"threshold":_fever_threshold,
		"full":full,"ready":_fever,"global_ready":full and _fever,"status":status,"caption":caption,"rect":FEVER_ENERGY_BOUNDS,
		"caption_visible":false,"layout":"horizontal_footer_right","bar_bounds":ENERGY_BAR_BOUNDS,"hint":"敲击指令攒能量","hint_visible":_energy_visible,"hint_rect":ENERGY_HINT_BOUNDS,
		"track_rect":_energy_track_rect,"fill_rect":_energy_fill_rect,"fill_ratio":float(_fever_energy)/_fever_energy_max,"filled_segments":_fever_energy,"segment_count":_fever_energy_max,
		"full_burst_tick":_energy_full_tick,"full_burst_count":_energy_full_count,"footer_fx":_footer_full_fx_state(),
		"motion":_energy_motion.duplicate(true),"gain_flash":_energy_gain_state(),"separators_visible":true,"clock":"simulation","source":"fever_energy"}

func _energy_gain_state() -> Dictionary:
	var age := _display_tick-_energy_gain_tick
	var active := _energy_visible and not _reduced and age>=0 and age<24 and _energy_gain_to<=_fever_energy
	var strength := pow(1.0-float(age)/24.0,1.4) if active else 0.0
	var scale_value := 1.0+.28*strength
	var inner := _energy_track_rect.grow(-3.0)
	var cell_width := inner.size.x/_fever_energy_max
	var rect := Rect2(inner.position+Vector2(cell_width*_energy_gain_from,0),Vector2(cell_width*(_energy_gain_to-_energy_gain_from),inner.size.y))
	rect = Rect2(rect.get_center()-rect.size*scale_value*.5,rect.size*scale_value).intersection(FEVER_ENERGY_BOUNDS.grow(-4.0))
	return {"active":active,"tick":_energy_gain_tick,"from":_energy_gain_from,"to":_energy_gain_to,"count":_energy_gain_count,"strength":strength,"scale":scale_value,"rect":rect,"duration_ticks":24}

func _refresh_footer_full_fx() -> void:
	_footer_full_particles.clear()
	_footer_full_flows.clear()
	if not bool(_energy_motion.get("full_burst_active",false)): return
	var age := int(_energy_motion.full_burst_age)
	var phase := float(age)/ENERGY_FULL_BURST_TICKS
	var path := FOOTER_FULL_FX_BOUNDS.grow(-8.0)
	var perimeter := (path.size.x+path.size.y)*2.0
	var fade := minf(1.0,float(age+1)/6.0)*(1.0-smoothstep(.72,1.0,phase))
	for index in range(8):
		var points := PackedVector2Array()
		var offset := (phase+float(index)/8.0)*perimeter
		for step in range(17):
			points.append(_footer_path_point(path,offset+float(step)*11.0))
		_footer_full_flows.append({"points":points,"tone_index":index%4,"alpha":fade})
	for index in range(32):
		var offset := (phase+float(index)/32.0)*perimeter
		var position := _footer_path_point(path,offset)
		_footer_full_particles.append({"position":position,"radius":3.0+float(index%4)*.9,"alpha":fade*(.65+.35*sin(phase*PI+index*.6)),"tone_index":index%4,"kind":"paper" if index%3==0 else "spark"})

func _footer_path_point(path: Rect2, distance: float) -> Vector2:
	var at := fposmod(distance,(path.size.x+path.size.y)*2.0)
	if at<path.size.x: return path.position+Vector2(at,0)
	at -= path.size.x
	if at<path.size.y: return Vector2(path.end.x,path.position.y+at)
	at -= path.size.y
	if at<path.size.x: return path.end-Vector2(at,0)
	return Vector2(path.position.x,path.end.y-(at-path.size.x))

func _footer_full_fx_state() -> Dictionary:
	var active := bool(_energy_motion.get("full_burst_active",false))
	var age := int(_energy_motion.get("full_burst_age",-1))
	var samples: Array[Vector2] = []
	for flow: Dictionary in _footer_full_flows:
		if not flow.points.is_empty(): samples.append(flow.points[0])
	return {"enabled":FOOTER_FULL_FX_ENABLED,"active":active,"bounds":FOOTER_FULL_FX_BOUNDS,"tick":_energy_full_tick,"count":_energy_full_count,"duration_ticks":ENERGY_FULL_BURST_TICKS,
		"elapsed_ticks":age,"phase":float(age)/ENERGY_FULL_BURST_TICKS if active else 0.0,"particles_count":_footer_full_particles.size(),"particle_samples":_footer_full_particles.duplicate(true),"flow_samples":samples,
		"one_shot":true,"clock":"simulation","source":"actual_energy_became_full"}

func _combo_motion_style() -> Dictionary:
	var age := _display_tick-_combo_tick
	var active := _combo>0 and not _reduced
	var popping := active and age>=0 and age<COMBO_POP_TICKS
	var beat_age := posmod(maxi(0,_display_tick-_combo_beat_origin),COMBO_BEAT_TICKS) if _combo_beat_origin>-100000 else 0
	var phase := float(beat_age)/COMBO_BEAT_TICKS
	var beat_strength := pow(1.0-phase,2.0) if active else 0.0
	var pop_strength := pow(1.0-float(age)/COMBO_POP_TICKS,.65) if popping else 0.0
	var scale_value := .82
	var lift := 0.0
	var strength := 0.0
	var sweep := -1.0
	if active:
		# Combo remains alive for the ENTIRE chain, including the long gap between
		# successful phrases and snapshots restored with an already-positive count.
		# Accepted/response beats anchor this 120BPM rhythm; no synthetic input.
		scale_value = .73+.22*beat_strength
		lift = -sin(phase*PI)*6.0
		strength = .18+.82*beat_strength
		sweep = lerpf(-.2,1.4,phase)
		if popping:
			# A new real count compresses, then jumps to twice its entrance size.
			# It blends back into the ongoing beat, never into a static hold.
			scale_value = lerpf(.46,.99,_out_cubic(float(age)/5.0)) if age<5 else lerpf(scale_value,.99,1.0-smoothstep(5.0,float(COMBO_POP_TICKS),float(age)))
			lift = -sin(float(age)/COMBO_POP_TICKS*PI)*8.0
			strength = maxf(strength,pop_strength)
		# Even the .99 pop and its outline stay inside the reserved title slot.
		lift = maxf(lift,-COMBO_BOUNDS.size.y*(1.0-scale_value)*.5)
	return {"active":active,"continuous_active":active,"pop_active":popping,"age_ticks":age,"duration_ticks":COMBO_POP_TICKS,"beat_ticks":COMBO_BEAT_TICKS,"beat_age":beat_age,"beat_strength":beat_strength,"pop_strength":pop_strength,"scale":scale_value,"lift":lift,"strength":strength,"sweep":sweep,"sweep_strength":.72+.23*beat_strength if active else 0.0,"number_outline_size":2+roundi(strength*3.0),"number_highlight":strength*.32}

func _combo_group_rect(rect: Rect2) -> Rect2:
	var scale_value := float(_combo_motion.scale)
	var center := COMBO_BOUNDS.get_center()
	return Rect2(center+(rect.position-center)*scale_value+Vector2(0,float(_combo_motion.lift)),rect.size*scale_value)

func _canvas_scale() -> Vector2:
	return size/DESIGN_SIZE if size.x>0 and size.y>0 else Vector2.ONE

func _scaled_rect(rect: Rect2, value: float) -> Rect2:
	var scaled := rect.size*value
	return Rect2(rect.get_center()-scaled*.5,scaled)

func _fade_since(at: int, duration: int) -> float:
	var age := _display_tick-at
	return 1.0-smoothstep(0.0,float(duration),float(maxi(0,age))) if at>-100000 and age<duration else 0.0

func _out_cubic(value: float) -> float:
	return 1.0-pow(1.0-clampf(value,0.0,1.0),3.0)

func _pulse_style(record: Dictionary) -> Dictionary:
	var age := maxi(0,_display_tick-int(record.tick))
	var response := bool(record.response)
	var life := RESPONSE_LIFE if response else INPUT_LIFE
	var hold := 12 if response else 15
	var alpha := 1.0-smoothstep(float(hold),float(life),float(age))
	var invalid_age := _display_tick-int(record.invalid_tick)
	if int(record.invalid_tick)>-100000 and invalid_age>=0: alpha *= 1.0-smoothstep(0.0,float(INVALID_FADE),float(invalid_age))
	var pop := 1.0
	var lift := 0.0
	if not _reduced:
		pop = lerpf(.62,1.12,_out_cubic(float(age)/5.0)) if age<5 else lerpf(1.12,1.0,smoothstep(5.0,15.0,float(age)))
		lift = -sin(clampf(float(age)/15.0,0.0,1.0)*PI)*12.0-maxf(0.0,float(age-hold))*.8
	return {"alpha":alpha,"scale":pop,"lift":lift,"age":age,"invalid":int(record.invalid_tick)>-100000}

func _draw() -> void:
	var canvas_scale := _canvas_scale()
	for record: Dictionary in _pulses.values(): _draw_pulse(record,canvas_scale)
	draw_set_transform_matrix(Transform2D(0.0,canvas_scale,0.0,Vector2.ZERO))
	if _fever_alpha>0.0 and not _reduced: _draw_fever_rays()
	if _energy_visible: _draw_fever_energy_bar()
	if _combo_alpha>0.0 and not _reduced: _draw_combo_impact()
	if _fever_alpha>0.0 and _fever_texture==null: _draw_fallback_stamp("FEVER!!",_fever_rect,Color("#ffcd54"),_fever_alpha)
	if _combo_alpha>0.0:
		if _combo_texture==null: _draw_fallback_stamp("COMBO!",_combo_rect,Color("#ffce64"),_combo_alpha)
		_draw_combo_number()
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_pulse(record: Dictionary, canvas_scale: Vector2) -> void:
	var style := _pulse_style(record)
	var alpha := float(style.alpha)
	if alpha<=0.0: return
	var key := str(record.key)
	var response := bool(record.response)
	var anchor: Vector2 = ANCHORS[key]
	var tone: Color = TONES[key]
	if bool(style.invalid): tone = tone.lerp(Color("#9ca5a9"),.8)
	if not _reduced:
		draw_set_transform_matrix(Transform2D(0.0,canvas_scale,0.0,anchor*canvas_scale))
		var age := float(style.age)
		var reach := lerpf(30.0,100.0,clampf(age/float(RESPONSE_LIFE if response else INPUT_LIFE),0.0,1.0))
		var ripple := PackedVector2Array()
		for index in range(49):
			var angle := float(index)*TAU/48.0
			ripple.append(Vector2(cos(angle)*reach,sin(angle)*reach*.48))
		draw_polyline(ripple,Color(INK,alpha*.65),7.0 if not response else 5.0,true)
		draw_polyline(ripple,Color(tone,alpha*.7),3.0 if not response else 2.0,true)
		for index in range(4 if not response else 2):
			var angle := float(index)*TAU/(4.0 if not response else 2.0)+.3
			var ray := Vector2.from_angle(angle)
			draw_line(ray*(reach+7.0),ray*(reach+17.0),Color(INK,alpha*.8),7.0,true)
			draw_line(ray*(reach+7.0),ray*(reach+17.0),Color(tone,alpha),3.0,true)
	var geometry := _word_geometry(record,canvas_scale)
	var font := _pixel_font()
	var font_size := int(geometry.font_size)
	var word := str(geometry.word)
	var baseline: Vector2 = geometry.baseline
	draw_set_transform_matrix(geometry.transform)
	# Echo words use a fixed font size without rotation/skew/pop; keycaps
	# retain the hollow echo syntax while the drum word has a readable fill.
	_draw_input_prompt(key,Vector2(0,82 if not response else 78),62 if not response else 46,alpha,response)
	draw_string_outline(font,baseline+Vector2(3,5),word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,15 if not response else 12,Color(INK,alpha))
	draw_string_outline(font,baseline,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,10,Color(INK,alpha))
	draw_string(font,baseline,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tone,alpha))
	if response:
		var caption_font := _body_font()
		var caption := "系统复述"
		var caption_width := caption_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		var caption_position := Vector2(-caption_width*.5,baseline.y+23).round()
		draw_string_outline(caption_font,caption_position,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,Color(INK,alpha))
		draw_string(caption_font,caption_position,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(Color("#f8e3b4"),alpha))

func _word_geometry(record: Dictionary, canvas_scale: Vector2) -> Dictionary:
	var response := bool(record.response)
	var key := str(record.key)
	var font := _pixel_font()
	var font_size := RESPONSE_WORD_SIZE if response else 68
	var word := str(WORDS[key])+"!"
	var width := font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := Vector2(-width*.5,font.get_ascent(font_size)*.42)
	var style := _pulse_style(record)
	var angle := 0.0 if _reduced else (-.075 if key in ["pata","chaka"] else .055)
	if response and not _reduced:
		# Restore the echo's lively entrance while keeping the larger solid glyph.
		# A small rock settles into its authored tilt with the same beat pop.
		angle *= lerpf(1.55,1.0,smoothstep(0.0,15.0,float(style.age)))
	var skew := 0.0 if _reduced else -.10
	var scale_value := float(style.scale)
	var origin: Vector2 = ANCHORS[key]+Vector2(0,float(style.lift))
	var transform := Transform2D(0.0,canvas_scale,0.0,Vector2.ZERO)*Transform2D(angle,Vector2.ONE*scale_value,skew,origin)
	if response:
		baseline = baseline.round()
		transform.origin = transform.origin.round()
	var glyph_rect := Rect2(baseline-Vector2(0,font.get_ascent(font_size)),Vector2(width,font.get_height(font_size))).grow(12 if response else 15)
	return {"word":word,"font_size":font_size,"font_path":font.resource_path,"baseline":baseline,"transform":transform,"rect":transform*glyph_rect,"rotation":angle,"skew":skew,"scale":scale_value,"lift":float(style.lift),"fill":"solid_echo" if response else "solid","outline_size":10,"pixel_snapped":response,"texture_filter":texture_filter}

func _draw_input_prompt(key: String, center: Vector2, extent: float, alpha: float, response: bool=false) -> void:
	if beat_skin!="default":
		var phase := 0.0 if _reduced else float(posmod(_display_tick,30))/30.0
		for index in range(4):
			var angle := float(index)*TAU/4.0+phase*.5
			var at := center+Vector2.from_angle(angle)*extent*.78
			if beat_skin=="beat_neon":
				draw_rect(Rect2(at-Vector2(4,4),Vector2(8,8)),Color(Color("#73e9ed"),alpha))
			else:
				draw_line(at-Vector2(6,0),at+Vector2(6,0),Color(Color("#ffe7a5"),alpha),2,true)
				draw_line(at-Vector2(0,6),at+Vector2(0,6),Color(Color("#ffe7a5"),alpha),2,true)
	var prompt := _input_prompt(key)
	var tone: Color = prompt.color
	var radius := extent*.5
	if str(prompt.shape)=="circle":
		if not response:
			draw_circle(center+Vector2(2,4),radius+4,Color(INK,alpha),true,-1.0,true)
			draw_circle(center,radius,Color(tone,alpha),true,-1.0,true)
		else: draw_circle(center,radius+1,Color(INK,alpha),false,8.0,true)
		draw_circle(center,radius,Color(tone,alpha),false,4.0,true)
		var font := _body_font()
		var font_size := roundi(extent*.64)
		var text := str(prompt.glyph)
		var baseline := center+Vector2(-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,(font.get_ascent(font_size)-font.get_descent(font_size))*.5)
		if response: draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(tone,alpha))
		else: draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(INK,alpha))
	else:
		var box := Rect2(center-Vector2.ONE*radius,Vector2.ONE*extent)
		if not response:
			draw_rect(Rect2(box.position+Vector2(2,4),box.size).grow(3),Color(INK,alpha))
			draw_rect(box,Color(tone,alpha))
		else: draw_rect(box.grow(1),Color(INK,alpha),false,8.0)
		draw_rect(box,Color(tone,alpha),false,4.0)
		if not response: draw_line(box.position+Vector2(5,6),box.position+Vector2(extent-5,6),Color(Color("#fff3d4"),alpha*.7),2.0,true)
		var direction: Vector2 = {"pata":Vector2.LEFT,"pon":Vector2.RIGHT,"don":Vector2.DOWN,"chaka":Vector2.UP}[key]
		var cross := Vector2(-direction.y,direction.x)
		var head := center+direction*extent*.24
		var glyph_tone := tone if response else INK
		draw_line(center-direction*extent*.23,center+direction*extent*.08,Color(glyph_tone,alpha),extent*.095,true)
		var arrow := PackedVector2Array([head,center-direction*extent*.025+cross*extent*.19,center-direction*extent*.025-cross*extent*.19,head])
		if response: draw_polyline(arrow,Color(glyph_tone,alpha),2.0,true)
		else: draw_colored_polygon(arrow.slice(0,3),Color(glyph_tone,alpha))

func _draw_fever_rays() -> void:
	var strength := float(_fever_motion.get("strength",0.0))
	var emphasis := float(_fever_motion.get("burst_emphasis",1.0))
	var tone := Color("#ffda55")
	# Rays and stepping bars remain inside the reserved title rectangle.
	var center := FEVER_WORDMARK_BOUNDS.get_center()
	for index in range(8):
		var angle := float(index)*TAU/8.0
		var direction := Vector2.from_angle(angle)
		var start := center+direction*Vector2(88,25)
		var end := center+direction*Vector2(115,37)
		end = start.lerp(end,clampf(.35+strength*.65,0.0,1.0))
		draw_line(start,end,Color(INK,_fever_alpha*.8),8.0,true)
		draw_line(start,end,Color(tone,_fever_alpha*(.45+strength*.55)),3.0+minf(2.0,emphasis-1.0),true)

func _draw_fever_energy_bar() -> void:
	var bar := _energy_bar_state()
	var full := bool(bar.full)
	var tone := Color("#ffda55") if full else Color("#e8a0a6")
	if bool(_energy_motion.full_burst_active): _draw_footer_full_charge()
	draw_rect(_energy_track_rect.grow(1.0),INK)
	draw_rect(_energy_track_rect,Color("#281e39"))
	if not _reduced:
		draw_rect(_energy_track_rect.grow(2),Color(tone,float(_energy_motion.edge_strength)*.24),false,4.0)
	draw_rect(_energy_track_rect,Color(tone,float(_energy_motion.edge_strength)),false,float(_energy_motion.edge_width))
	if _fever_energy>0:
		draw_rect(_energy_fill_rect,tone)
		if not _reduced:
			var sweep_x := _energy_fill_rect.position.x+float(_energy_motion.sweep)*_energy_fill_rect.size.x
			var sweep := Rect2(sweep_x-20.0,_energy_fill_rect.position.y,40.0,_energy_fill_rect.size.y).intersection(_energy_fill_rect)
			if sweep.has_area(): draw_rect(sweep,Color(Color("#fff6cb"),float(_energy_motion.sweep_strength)))
	var gain := _energy_gain_state()
	if gain.active:
		draw_rect(gain.rect,Color(Color("#fff6cb"),float(gain.strength)*.88))
		draw_rect(gain.rect.grow(2),Color(Color("#ffd66b"),float(gain.strength)*.65),false,2.0)
	var inner := _energy_track_rect.grow(-3.0)
	for index in range(1,_fever_energy_max):
		var x := inner.position.x+inner.size.x*float(index)/_fever_energy_max
		draw_line(Vector2(x,inner.position.y),Vector2(x,inner.end.y),Color("#281e39") if index<=_fever_energy else Color(tone,.55),1.5,true)
	if full and not _reduced:
		draw_rect(_energy_track_rect.grow(2.0),Color(tone,.25+.55*float(_energy_motion.strength)),false,1.0)
	var font := _body_font()
	var hint := "敲击指令攒能量"
	var font_size := 22
	var text_width := font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := ENERGY_HINT_BOUNDS.get_center()+Vector2(-text_width*.5,(font.get_ascent(font_size)-font.get_descent(font_size))*.5)
	draw_string_outline(font,baseline,hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,INK)
	draw_string(font,baseline,hint,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#f2dfbc"))

func _draw_footer_full_charge() -> void:
	var tones: Array[Color] = [Color("#ffd66b"),Color("#f39dbc"),Color("#9fe4e8"),Color("#fff1c4")]
	# The whole-footer marquee has one finite lap per actual fill transition.
	# It never loops while the player holds full energy or depicts an attack.
	for flow: Dictionary in _footer_full_flows:
		var tone: Color = tones[int(flow.tone_index)]
		var alpha := float(flow.alpha)
		draw_polyline(flow.points,Color(tone,alpha*.18),8.0,true)
		draw_polyline(flow.points,Color(tone,alpha*.85),3.0,true)
	for particle: Dictionary in _footer_full_particles:
		var position: Vector2 = particle.position
		var radius := float(particle.radius)
		var tone: Color = tones[int(particle.tone_index)]
		var alpha := float(particle.alpha)
		draw_circle(position,radius,Color(tone,alpha*.25),true,-1.0,true)
		if str(particle.kind)=="paper":
			var small := radius*.55
			draw_colored_polygon(PackedVector2Array([position+Vector2(0,-small),position+Vector2(small,0),position+Vector2(0,small),position+Vector2(-small,0)]),Color(tone,alpha))
		else:
			draw_circle(position,radius*.5,Color(tone,alpha),true,-1.0,true)

func _draw_combo_impact() -> void:
	if not bool(_combo_motion.get("active",false)): return
	var strength := float(_combo_motion.get("strength",0.0))
	var tone := Color("#ffe293")
	var middle := COMBO_BOUNDS.get_center().x
	for index in range(5):
		var x := middle+(index-2)*37.0
		var reach := 3.0+strength*(8.0 if index%2==0 else 5.0)
		draw_line(Vector2(x,COMBO_BOUNDS.position.y+2),Vector2(x,COMBO_BOUNDS.position.y+reach),Color(tone,_combo_alpha*strength),3.0,true)
		draw_line(Vector2(x,COMBO_BOUNDS.end.y-2),Vector2(x,COMBO_BOUNDS.end.y-reach),Color(tone,_combo_alpha*strength),3.0,true)

func _draw_fallback_stamp(text: String, rect: Rect2, tone: Color, alpha: float) -> void:
	var font := _pixel_font()
	var font_size := 42
	while font_size>12 and (font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x-12.0 or font.get_height(font_size)>rect.size.y-10.0): font_size -= 1
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := Vector2(rect.get_center().x-width*.5,rect.get_center().y+(font.get_ascent(font_size)-font.get_descent(font_size))*.5)
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,6,Color(INK,alpha))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tone,alpha))

func _draw_combo_number() -> void:
	if _digit_assets_loaded(): return
	# Keep a single vector-font cache size through the entire pop. Fitting by
	# transform avoids switching pixel-font glyph sizes at an animation peak.
	var font := _body_font()
	var text := "×"+str(_combo_display)
	var layout := _combo_number_layout()
	var canvas_scale := _canvas_scale()
	draw_set_transform_matrix(Transform2D(0.0,canvas_scale*float(layout.scale),0.0,_number_rect.get_center()*canvas_scale))
	var baseline := Vector2(-float(layout.width)*.5,(font.get_ascent(64)-font.get_descent(64))*.5)
	var tone := Color("#b9ec9b") if _combo_display==1 else Color("#ffe4a0") if _combo_display==2 else Color("#ffd052")
	if _combo==0: tone = Color("#a4acae")
	tone = tone.lerp(Color("#fff5ce"),float(_combo_motion.get("number_highlight",0.0)))
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,64,10,Color(INK,_combo_alpha))
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,64,int(_combo_motion.get("number_outline_size",2)),Color(tone,_combo_alpha))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,64,Color(tone,_combo_alpha))

func _combo_number_layout() -> Dictionary:
	if _digit_assets_loaded():
		var native_width := 0.0
		for key: String in _combo_digit_keys():
			var texture: Texture2D = _combo_digit_textures[key]
			var height := 50.0 if key=="x" else 64.0
			native_width += texture.get_size().x/maxf(1.0,texture.get_size().y)*height
		var keys := _combo_digit_keys()
		native_width += maxi(0,keys.size()-1)*2.0
		# Fit once in the unscaled number slot, then apply the SAME group scale
		# as the wordmark. A short x1 must not stop growing at its native height.
		var fit := minf(1.0,minf((COMBO_NUMBER_BOUNDS.size.x-4.0)/maxf(1.0,native_width),(COMBO_NUMBER_BOUNDS.size.y-4.0)/64.0))*float(_combo_motion.get("scale",.82))
		return {"width":native_width,"scale":fit}
	var font := _body_font()
	var width := font.get_string_size("×"+str(_combo_display),HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
	var scale_value := minf(1.0,minf(maxf(1.0,_number_rect.size.x-4.0)/maxf(1.0,width+20.0),maxf(1.0,_number_rect.size.y-4.0)/maxf(1.0,font.get_height(64)+20.0)))
	return {"width":width,"scale":scale_value}

func _combo_digit_keys() -> Array[String]:
	var result: Array[String] = ["x"]
	for digit in str(_combo_display): result.append(digit)
	return result

func _refresh_combo_digits(canvas_scale: Vector2) -> void:
	_combo_digit_layout.clear()
	for node: TextureRect in _combo_digit_nodes: node.visible = false
	if not _digit_assets_loaded(): return
	var layout := _combo_number_layout()
	var fit := float(layout.scale)
	var x := _number_rect.get_center().x-float(layout.width)*fit*.5
	var keys := _combo_digit_keys()
	for index in range(keys.size()):
		var key := keys[index]
		var texture: Texture2D = _combo_digit_textures[key]
		var height := (50.0 if key=="x" else 64.0)*fit
		var width := texture.get_size().x/maxf(1.0,texture.get_size().y)*height
		var rect := Rect2(x,_number_rect.get_center().y-height*.5,width,height)
		var node: TextureRect = _combo_digit_nodes[index]
		node.texture = texture
		node.position = rect.position*canvas_scale
		node.size = rect.size*canvas_scale
		node.modulate = Color(1,1,1,_combo_alpha)
		node.visible = _combo_alpha>0.0
		_combo_digit_layout.append({"key":key,"path":COMBO_DIGIT_DIR+key+".png","rect":rect,"texture_loaded":node.texture!=null,"visible":node.visible,"node":str(node.name),"group_clock":"combo_motion"})
		x += width+2.0*fit

func _pixel_font() -> Font:
	return display_font if display_font!=null else ThemeDB.fallback_font

func _body_font() -> Font:
	return body_font if body_font!=null else _pixel_font()


func set_skin(value: String) -> void:
	beat_skin=value
	queue_redraw()
