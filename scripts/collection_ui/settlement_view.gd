extends Control
## Presentation of an already banked result. No award, RNG, store, or profile calls.
## Clock ownership is explicit; skip never alter the input result.
signal sound_requested(cue: String)
signal stage_changed(stage_name: String)
signal presentation_finished

const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const ControllerUi = preload("res://scripts/controller_ui.gd")
const CardView = preload("res://scripts/collection_ui/collection_card_view.gd")
const DESIGN := Vector2(1840,880)
const RED_STAGE_SECONDS := 4.0
const BATCH_STAGE_SECONDS := 2.6
const BATCH_COLLECTION_START := 1.0
const RED_COLLECTION_START := 2.65
const COLLECTION_SECONDS := 1.35
const BATCH_SIZE := 12
const BATCH_COLUMNS := 6
const DUPLICATE_TAG_PATH := "res://assets/ui/settlement/duplicate.png"
const SUMMARY_ANIMATION_SECONDS := 1.2
const CONVERSION_HOLD_START := 0.44
const CONVERSION_FLIGHT_START := 0.76
var stage := "summary"
var paused := false
var reduced := false
var _font: Font
var _card_font: Font
var _result: Dictionary = {}
var _rows: Array[Dictionary] = []
var _segments: Array[Dictionary] = []
var _segment_index := 0
var _elapsed := 0.0
var _total_elapsed := 0.0
var _catalog: Script
var _on_album := Callable()
var _on_replay := Callable()
var _canvas: Control
var _body: Control
var _decor: StageDecor
var _cards: Array[Control] = []
var _card_homes: Array[Vector2] = []
var _duplicate_cards: Array[Control] = []
var _retreat_cards: Array[Control] = []
var _retreat_homes: Array[Vector2] = []
var _row_labels: Array[Label] = []
var _coin_icons: Array[Control] = []
var _coin_labels: Array[Label] = []
var _coin_groups: Array[Control] = []
var _coin_group_homes: Array[Vector2] = []
var _new_icons: Array[Control] = []
var _duplicate_tags: Array[Control] = []
var _book: Control
var _coin_receiver: Control
var _stage_label: Label
var _skip_button: Button
var _red_revealed := false
var _red_reveal_emitted := false
var _flip_cue_emitted := false
var _coin_cue_emitted := false
var _new_cue_emitted := false
var _finished := false
var _summary_total: Label
var _summary_metrics: Dictionary = {}
var _summary_metric_labels: Array[Label] = []
var _summary_elapsed := 0.0
var _summary_animation_complete := false
var _summary_complete_immediately := false
var _input_device := "keyboard"
var _album_button: Button
var _replay_button: Button
var _summary_hints: Control
var _summary_action_taken := false

func _ready() -> void:
	if size == Vector2.ZERO: size = DESIGN
	resized.connect(_layout)
	_ensure_shell()
	_show_segment()

func configure(result: Dictionary, font: Font = null, on_album: Callable = Callable(), on_replay: Callable = Callable(), reduced_effects: bool = false, card_font: Font = null) -> void:
	_result = result.duplicate(true)
	_font = font
	_card_font = card_font if card_font != null else font
	_on_album = on_album
	_on_replay = on_replay
	reduced = reduced_effects
	if ResourceLoader.exists("res://scripts/collection_catalog.gd"): _catalog = load("res://scripts/collection_catalog.gd")
	_rows.clear()
	for row in _result.get("rows",[]):
		if row is Dictionary:
			var copied: Dictionary = row.duplicate(true)
			copied["grade"] = clampi(int(copied.get("grade",_definition(str(copied.get("id",""))).get("grade",0))),0,4)
			_rows.append(copied)
	_rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.get("grade",0)) != int(b.get("grade",0)): return int(a.get("grade",0)) < int(b.get("grade",0))
		return str(a.get("id","")) < str(b.get("id","")))
	_build_timeline()
	_segment_index = 0
	_elapsed = 0
	_total_elapsed = 0
	_finished = false
	_summary_action_taken = false
	_summary_complete_immediately = false
	paused = false
	_ensure_shell()
	_show_segment()

func _build_timeline() -> void:
	# Start with actual banked cards. With no card rows, summary is segment zero.
	_segments = []
	# Grade ordering may determine placement, but it never flushes a partial
	# batch. Each banked ledger row appears once, with its actual quantity.
	var batch: Array[Dictionary] = []
	for row in _rows:
		if int(row.get("grade",0)) == 4: continue
		batch.append(row)
		if batch.size() == BATCH_SIZE:
			_segments.append({"stage":"reveal","duration":BATCH_STAGE_SECONDS,"collection_start":BATCH_COLLECTION_START,"rows":batch.duplicate()})
			batch.clear()
	if not batch.is_empty():
		_segments.append({"stage":"reveal","duration":BATCH_STAGE_SECONDS,"collection_start":BATCH_COLLECTION_START,"rows":batch.duplicate()})
	for row in _rows:
		if int(row.get("grade",0)) == 4:
			_segments.append({"stage":"red","duration":RED_STAGE_SECONDS,"collection_start":RED_COLLECTION_START,"grade":4,"rows":[row]})
	_segments.append({"stage":"summary","duration":0.0,"rows":[]})

func set_paused(value: bool) -> void:
	paused = value
	for card in _cards: card.set_paused(value)
	for duplicate in _duplicate_cards:
		if is_instance_valid(duplicate): duplicate.set_paused(value)

func set_reduced(value: bool) -> void:
	reduced = value
	if is_instance_valid(_decor): _decor.reduced = value
	for card in _cards: card.set_reduced(value)
	for duplicate in _duplicate_cards:
		if is_instance_valid(duplicate): duplicate.set_reduced(value)
	if stage=="summary": _animate_summary()

func set_input_device(device: String) -> void:
	if device not in ["keyboard","joypad"]: return
	_input_device = device
	ControllerUi.set_device(self,device)

func handle_controller_event(event: InputEvent) -> bool:
	# Main is the single input router. A/Enter are deliberately left to native
	# GUI confirmation of the currently focused button.
	if not is_visible_in_tree() or paused or stage!="summary": return false
	var back := false
	var replay := false
	if event is InputEventJoypadButton:
		back = event.button_index==JOY_BUTTON_B
		replay = event.button_index==JOY_BUTTON_X
	elif event is InputEventKey:
		back = event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE
	if not back and not replay: return false
	if not event.is_pressed() or event.is_echo() or _summary_action_taken: return true
	if back: _return_album()
	elif replay: _replay()
	return true

func skip_to_summary() -> void:
	if _segments.is_empty(): return
	_summary_complete_immediately = true
	_segment_index = _segments.size()-1
	_elapsed = 0
	_show_segment()

func _process(delta: float) -> void:
	if is_visible_in_tree() and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
		advance_time(delta)

func advance_time(delta: float) -> void:
	if paused or delta <= 0 or not is_finite(delta) or _segments.is_empty(): return
	if stage == "summary":
		_advance_summary(delta)
		return
	var remaining := delta
	# Consume bounded segments exactly, including large deterministic test steps.
	while remaining > 0.000001 and stage != "summary":
		var duration := float(_segments[_segment_index].get("duration",0))
		var step := minf(remaining,maxf(0,duration-_elapsed))
		_elapsed += step
		_total_elapsed += step
		remaining -= step
		for card in _cards: card.advance_time(step)
		for duplicate in _duplicate_cards:
			if is_instance_valid(duplicate): duplicate.advance_time(step)
		_animate_segment()
		if _elapsed+0.000001 >= duration:
			_segment_index = mini(_segment_index+1,_segments.size()-1)
			_elapsed = 0
			_show_segment()
		elif step == 0: break
	if stage=="summary" and remaining>0.000001: _advance_summary(remaining)

func _advance_summary(delta: float) -> void:
	if _summary_animation_complete: return
	_summary_elapsed = minf(SUMMARY_ANIMATION_SECONDS,_summary_elapsed+delta)
	_animate_summary()

func get_stage_state() -> Dictionary:
	var current: Dictionary = _segments[_segment_index] if not _segments.is_empty() else {}
	var card_states: Array[Dictionary] = []
	for card in _cards: card_states.append(card.get_presentation_state())
	var duplicate_visual_count := 0
	for item in _duplicate_cards:
		if is_instance_valid(item): duplicate_visual_count += 1
	var row_ids: Array[String] = []
	var row_grades: Array[int] = []
	var duplicate_tag_counts: Array[int] = []
	var duplicate_coin_amounts: Array[int] = []
	for row: Dictionary in current.get("rows",[]):
		row_ids.append(str(row.get("id","")))
		row_grades.append(int(row.get("grade",0)))
		duplicate_tag_counts.append(int(row.get("duplicate_count",0)))
		duplicate_coin_amounts.append(int(row.get("duplicate_coins",0)))
	var visible_duplicate_tags := 0
	for tag in _duplicate_tags:
		if is_instance_valid(tag) and tag.visible and tag.modulate.a>0.01: visible_duplicate_tags += 1
	var collection_start := float(current.get("collection_start",-1.0))
	var collection_active := collection_start>=0 and _elapsed>=collection_start
	var collection_progress := clampf((_elapsed-collection_start)/COLLECTION_SECONDS,0,1) if collection_start>=0 else 0.0
	var displayed_metrics := {}
	var metric_ids := _summary_metrics.keys()
	for index in range(_summary_metric_labels.size()): displayed_metrics[metric_ids[index]] = _summary_metric_labels[index].text
	return {"stage":stage,"segment":_segment_index,"segment_count":_segments.size(),"elapsed":_elapsed,"total_elapsed":_total_elapsed,"duration":float(current.get("duration",0)),"paused":paused,"batch_columns":BATCH_COLUMNS,"batch_rows":2,"batch_capacity":BATCH_SIZE,"simultaneous_flip":true,"reduced":reduced,"red_stage_seconds":RED_STAGE_SECONDS,"red_revealed":_red_revealed,"rows_in_stage":row_ids.size(),"row_ids":row_ids,"row_grades":row_grades,"row_count":_rows.size(),"card_states":card_states,"retreat_card_count":_retreat_cards.size(),"duplicate_visual_count":duplicate_visual_count,"duplicate_tag_counts":duplicate_tag_counts,"duplicate_coin_amounts":duplicate_coin_amounts,"visible_duplicate_tags":visible_duplicate_tags,"per_card_collection_active":collection_active,"per_card_collection_start":collection_start,"per_card_collection_progress":collection_progress,"conversion_geometry":get_conversion_geometry(),"aggregate_flight_stage":false,"book_receiver_visible":_book.visible if is_instance_valid(_book) else false,"coin_receiver_visible":_coin_receiver.visible if is_instance_valid(_coin_receiver) else false,"summary_total":_summary_total.text if is_instance_valid(_summary_total) else "","summary_metrics":_summary_metrics.duplicate(),"summary_displayed_metrics":displayed_metrics,"summary_animation_elapsed":_summary_elapsed,"summary_animation_complete":_summary_animation_complete,"summary_buttons_enabled":stage=="summary","reward_mutations":0,"source_result_unchanged":true,"total_display_instances":1 if stage=="summary" else 0,"finished":_finished}

func get_conversion_geometry() -> Array[Dictionary]:
	var geometry: Array[Dictionary] = []
	var current: Dictionary = _segments[_segment_index] if not _segments.is_empty() else {}
	var start := float(current.get("collection_start",-1.0))
	var t := clampf((_elapsed-start)/COLLECTION_SECONDS,0,1) if start>=0 else 0.0
	var phase := "collect" if t>=CONVERSION_FLIGHT_START else ("hold" if t>=CONVERSION_HOLD_START else "forming")
	for index in range(_coin_groups.size()):
		var group: Control = _coin_groups[index]
		if not group.visible: continue
		var target := _body.get_global_transform()*(_card_homes[index]+_cards[index].size*0.5)
		var combined := _coin_icons[index].get_global_rect().merge(_coin_labels[index].get_global_rect())
		geometry.append({"row":index,"phase":phase,"progress":t,"flight_progress":smoothstep(CONVERSION_FLIGHT_START,1.0,t),"target_center":[target.x,target.y],"actual_center":[combined.get_center().x,combined.get_center().y],"center_error":combined.get_center().distance_to(target),"group_rect":_rect_values(group.get_global_rect()),"coin_rect":_rect_values(_coin_icons[index].get_global_rect()),"amount_rect":_rect_values(_coin_labels[index].get_global_rect()),"combined_rect":_rect_values(combined),"group_scale":[group.scale.x,group.scale.y]})
	return geometry

func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _ensure_shell() -> void:
	if is_instance_valid(_canvas):
		remove_child(_canvas)
		_canvas.queue_free()
	_body = null
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.name = "SettlementPresentation"
	add_child(_canvas)
	_decor = StageDecor.new()
	_decor.size = DESIGN
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_decor)
	_stage_label = Ui.label(_canvas,"",Rect2(54,20,1140,70),_font,32,Ui.INK)
	_skip_button = Ui.button(_canvas,"跳过",Rect2(1630,28,150,48),_font,skip_to_summary)
	_skip_button.name = "SettlementSkip"
	_book = Ui.icon(_canvas,"book",Rect2(857,744,90,90))
	_coin_receiver = Ui.icon(_canvas,"coin",Rect2(1684,115,70,70))
	_layout()

func _show_segment() -> void:
	if not is_instance_valid(_canvas) or _segments.is_empty(): return
	if is_instance_valid(_body): remove_child_from_canvas(_body)
	_body = Control.new()
	_body.name = "StageContent"
	_body.size = DESIGN
	_canvas.add_child(_body)
	_canvas.move_child(_body,1)
	_cards.clear()
	_card_homes.clear()
	_duplicate_cards.clear()
	_retreat_cards.clear()
	_retreat_homes.clear()
	_row_labels.clear()
	_coin_icons.clear()
	_coin_labels.clear()
	_coin_groups.clear()
	_coin_group_homes.clear()
	_new_icons.clear()
	_duplicate_tags.clear()
	_summary_total = null
	_summary_hints = null
	_summary_metrics.clear()
	_summary_metric_labels.clear()
	_summary_elapsed = 0.0
	_summary_animation_complete = false
	_red_revealed = false
	_red_reveal_emitted = false
	_flip_cue_emitted = false
	_coin_cue_emitted = false
	_new_cue_emitted = false
	var segment: Dictionary = _segments[_segment_index]
	stage = str(segment.get("stage","summary"))
	_decor.stage_name = stage
	_decor.clock = 0
	_decor.reduced = reduced
	_decor.queue_redraw()
	_book.visible = false
	_coin_receiver.visible = false
	_skip_button.visible = stage != "summary"
	_stage_label.text = {"reveal":"卡片揭晓","red":"","summary":"本局表现"}.get(stage,"")
	if stage == "reveal": _show_batch(segment.get("rows",[]))
	elif stage == "red":
		_show_red(segment.get("rows",[]))
		sound_requested.emit("red_charge")
	else: _show_summary()
	_animate_segment()
	stage_changed.emit(stage)

func remove_child_from_canvas(node: Node) -> void:
	var old_parent := node.get_parent()
	if old_parent != null: old_parent.remove_child(node)
	node.queue_free()

func _show_batch(rows: Array) -> void:
	var count := rows.size()
	var width := 180.0
	var gap := 48.0
	for index in range(count):
		var row: Dictionary = rows[index]
		var card: Control = CardView.new()
		var row_index := index/BATCH_COLUMNS
		var column := index%BATCH_COLUMNS
		var in_row := mini(BATCH_COLUMNS,count-row_index*BATCH_COLUMNS)
		var origin := (DESIGN.x-(width*in_row+gap*(in_row-1)))*0.5
		var home := Vector2(origin+column*(width+gap),128+row_index*292)
		card.position = home
		card.size = Vector2(width,width*4.0/3.0)
		_body.add_child(card)
		card.configure(_definition(str(row.get("id",""))),true,_card_font,false)
		card.external_clock = true
		card.set_reduced(reduced)
		card.set_face_down(true)
		_cards.append(card)
		_card_homes.append(home)
		var row_label := Ui.label(_body,"× %d" % int(row.get("count",1)),Rect2(home+Vector2(-5,248),Vector2(width+10,44)),_font,32,Ui.INK,true)
		_row_labels.append(row_label)
		_add_row_feedback(row,card,home,index)

func _add_row_feedback(row: Dictionary, card: Control, home: Vector2, index: int) -> void:
	var large := card.size.x>300
	var duplicate: Control = null
	if int(row.get("new_count",0))>0 and int(row.get("duplicate_count",0))>0:
		# One banked row may contain its first copy and several duplicates. Only
		# this extra presentation sheet converts while the first enters the book.
		duplicate = CardView.new()
		duplicate.name = "DuplicateSheet_%d"%index
		duplicate.position = home+Vector2(14,15)
		duplicate.size = card.size
		_body.add_child(duplicate)
		_body.move_child(duplicate,0)
		duplicate.configure(_definition(str(row.get("id",""))),true,_card_font,false)
		duplicate.external_clock = true
		duplicate.set_reduced(reduced)
		duplicate.visible = false
	_duplicate_cards.append(duplicate)
	# Measure the actual interface face, then center the icon and exact amount as
	# one horizontal unit on the original card. The row quantity stays below it.
	var diameter := 88.0 if large else 44.0
	var number_px := 48 if large else 24
	var gap := 12.0 if large else 8.0
	var amount := "× %s" % Ui.comma(int(row.get("duplicate_coins",0)))
	var face: Font = _font if _font!=null else ThemeDB.fallback_font
	var number_width := ceilf(face.get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,number_px).x)+4.0
	while diameter+gap+number_width>card.size.x-16.0 and number_px>12:
		number_px-=12
		number_width = ceilf(face.get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,number_px).x)+4.0
	var number_height := maxf(float(number_px)*1.35,face.get_height(number_px))
	var group_width := diameter+gap+number_width
	var center := home+card.size*0.5
	var group := Control.new()
	group.name = "DuplicateConversion_%d"%index
	group.size = Vector2(group_width,maxf(diameter,number_height))
	group.position = center-group.size*0.5
	group.pivot_offset = group.size*0.5
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.visible = false
	_body.add_child(group)
	_coin_groups.append(group)
	_coin_group_homes.append(group.position)
	var coins := Ui.icon(group,"coin",Rect2(Vector2(0,(group.size.y-diameter)*0.5),Vector2.ONE*diameter))
	coins.visible = false
	_coin_icons.append(coins)
	var number := Ui.label(group,amount,Rect2(Vector2(diameter+gap,(group.size.y-number_height)*0.5),Vector2(number_width,number_height)),_font,number_px,Ui.GOLD,true)
	number.visible = false
	_coin_labels.append(number)
	var star: Control = null
	if int(row.get("new_count",0))>0:
		star = Ui.icon(_body,"star",Rect2(home+Vector2(card.size.x+6,6),Vector2(40,40) if large else Vector2(30,30)),Ui.GOLD)
		star.visible = false
	_new_icons.append(star)
	var tag: Control = null
	if int(row.get("duplicate_count",0))>0:
		tag = Control.new()
		tag.name = "DuplicateTag_%d"%index
		tag.position = home+Vector2(-32,22) if large else home+Vector2(-22,8)
		tag.size = Vector2(150,114) if large else Vector2(96,80)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(tag)
		var image_height := 75.0 if large else 48.0
		var texture: Texture2D = Ui.texture(DUPLICATE_TAG_PATH)
		if texture != null:
			var artwork := TextureRect.new()
			artwork.name = "DuplicateArtwork"
			artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			artwork.texture = texture
			artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
			artwork.size = Vector2(tag.size.x,image_height)
			tag.add_child(artwork)
			# Reassert after parenting; a source texture must never become the
			# control's minimum layout size on this or a later frame.
			artwork.size = Vector2(tag.size.x,image_height)
		else:
			Ui.panel(tag,Rect2(0,0,tag.size.x,image_height),Color("#643549"),Ui.GOLD)
			Ui.label(tag,"重复",Rect2(0,0,tag.size.x,image_height),_font,36 if large else 24,Ui.GOLD,true)
		Ui.label(tag,"× %d"%int(row.get("duplicate_count",0)),Rect2(0,image_height-4,tag.size.x,42 if large else 36),_font,32 if large else 24,Ui.GOLD,true)
		tag.visible = false
	_duplicate_tags.append(tag)

func _reveal_row_badges(index: int, revealed: bool) -> void:
	if is_instance_valid(_new_icons[index]): _new_icons[index].visible = revealed
	if is_instance_valid(_duplicate_tags[index]): _duplicate_tags[index].visible = revealed

func _show_red(rows: Array) -> void:
	if rows.is_empty(): return
	var row: Dictionary = rows[0]
	var definition := _definition(str(row.get("id","")))
	_decor.hidden_identity = bool(row.get("hidden",false))
	_decor.theme_id = str(definition.get("theme","galaxy"))
	# These cards have already been revealed by earlier grade batches. They now
	# physically shrink and slide into the dark wings instead of disappearing.
	var previous: Array[Dictionary] = []
	for seen in _rows:
		if int(seen.get("grade",0))<4: previous.append(seen)
	for index in range(mini(4,previous.size())):
		var ghost: Control = CardView.new()
		var side := -1.0 if index<2 else 1.0
		var distance := 510.0+float(index%2)*210.0
		var home := Vector2(920+side*distance-72,270+float(index%2)*55)
		ghost.name = "RetreatingRevealedCard_%d"%index
		ghost.position = home
		ghost.size = Vector2(144,192)
		_body.add_child(ghost)
		ghost.configure(_definition(str(previous[index].get("id",""))),true,_card_font,true)
		ghost.external_clock = true
		ghost.set_reduced(true)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_retreat_cards.append(ghost)
		_retreat_homes.append(home)
	var card: Control = CardView.new()
	card.name = "RedCenterCard"
	card.position = Vector2(726,156)
	card.size = Vector2(388,517.333)
	_body.add_child(card)
	card.configure(definition,true,_card_font,false)
	card.external_clock = true
	card.set_reduced(reduced)
	card.set_face_down(true)
	_cards.append(card)
	_card_homes.append(card.position)
	var count_label := Ui.label(_body,"× %d" % int(row.get("count",1)),Rect2(770,715,300,64),_font,38,Ui.INK,true)
	_row_labels.append(count_label)
	_add_row_feedback(row,card,card.position,0)

func _show_summary() -> void:
	# The banked total is final immediately. Only the four local performance
	# counters animate; no number moves to another part of the interface.
	Ui.icon(_body,"coin",Rect2(610,145,145,145))
	_summary_total = Ui.label(_body,Ui.comma(int(_result.get("total_coins",_result.get("coins",0)))),Rect2(790,148,600,140),_font,84,Ui.GOLD)
	Ui.fit_number(_summary_total)
	var rhythm: Dictionary = _result.get("rhythm",{}) if _result.get("rhythm",{}) is Dictionary else {}
	_summary_metrics = {"destroyed_pack_count":int(_result.get("destroyed_pack_count",_result.get("card_count",0))),"max_phrase_combo":int(rhythm.get("max_phrase_combo",0)),"perfect_beats":int(rhythm.get("perfect_beats",0)),"new_collection":_result.get("new_ids",[]).size()}
	var titles := ["击破卡包","最高 Combo","Perfect指令","新增收藏"]
	for index in range(4):
		var home := Vector2(180+index*382,360)
		var panel := Ui.panel(_body,Rect2(home,Vector2(354,196)),Color("#33283e"),Color("#8b6b70"))
		panel.name = "PerformancePanel_%d"%index
		if index in [0,1]:
			var art := TextureRect.new()
			art.name = "PerformanceIcon_%d"%index
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.texture = Ui.texture("res://assets/art/crt/packs/pack-0.png" if index==0 else "res://assets/ui/rhythm_feedback/combo.png")
			art.position = home+(Vector2(18,22) if index==0 else Vector2(26,14))
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.size = Vector2(72,90) if index==0 else Vector2(106,40)
			_body.add_child(art)
			art.size = Vector2(72,90) if index==0 else Vector2(106,40)
		else:
			var icon := Ui.icon(_body,"star" if index==2 else "book",Rect2(home+Vector2(20,24),Vector2(68,68)))
			icon.name = "PerformanceIcon_%d"%index
		Ui.label(_body,titles[index],Rect2(home+Vector2(122,15),Vector2(214,54)),_font,24,Ui.INK,true)
		var number := Ui.label(_body,"0",Rect2(home+Vector2(108,76),Vector2(230,102)),_font,72,Ui.GOLD,true)
		number.pivot_offset = number.size*0.5
		_summary_metric_labels.append(number)
	_album_button = Ui.button(_body,"返回卡册",Rect2(510,650,370,92),_font,_return_album)
	_album_button.add_theme_font_size_override("font_size",36)
	_album_button.name = "SettlementAlbum"
	ControllerUi.decorate(_album_button,"B")
	_replay_button = Ui.button(_body,"再来一局",Rect2(960,650,370,92),_font,_replay,true)
	_replay_button.name = "SettlementReplay"
	_replay_button.add_theme_font_size_override("font_size",36)
	ControllerUi.decorate(_replay_button,"X")
	_summary_hints = ControllerUi.hints([
		{"binding":"A","label":"确认"},
		{"binding":"B","label":"返回"},
		{"binding":"X","label":"再来一局"},
	],_input_device)
	_summary_hints.name = "SettlementInputHints"
	_summary_hints.position = Vector2(170,788)
	_summary_hints.size = Vector2(1500,44)
	if _font!=null: _summary_hints.add_theme_font_override("font",_font)
	_body.add_child(_summary_hints)
	ControllerUi.set_device(self,_input_device)
	_focus_summary_album.call_deferred()
	_animate_summary()
	if not _finished:
		_finished = true
		presentation_finished.emit()

func _focus_summary_album() -> void:
	# configure may replace the body repeatedly before the deferred call runs;
	# page navigation can also remove the whole presenter in that same frame.
	# Resolve the current button here rather than queueing a call on an old one.
	if stage!="summary" or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree(): return
	if not is_instance_valid(_body) or not _body.is_inside_tree() or _body.is_queued_for_deletion(): return
	if not is_instance_valid(_album_button) or not _album_button.is_inside_tree() or _album_button.is_queued_for_deletion(): return
	if _album_button.get_parent()!=_body or _album_button.disabled or not _album_button.is_visible_in_tree(): return
	_album_button.grab_focus()

func _animate_summary() -> void:
	if stage!="summary" or _summary_metric_labels.is_empty(): return
	if reduced or _summary_complete_immediately: _summary_elapsed = SUMMARY_ANIMATION_SECONDS
	_summary_animation_complete = _summary_elapsed>=SUMMARY_ANIMATION_SECONDS
	var ids := _summary_metrics.keys()
	for index in range(_summary_metric_labels.size()):
		var progress := clampf((_summary_elapsed-index*0.1)/0.85,0,1)
		var eased := 1.0-pow(1.0-progress,3.0)
		var target := int(_summary_metrics[ids[index]])
		var number := _summary_metric_labels[index]
		number.text = Ui.comma(target if progress>=1 else floori(target*eased))
		Ui.fit_number(number,24)
		number.scale = Vector2.ONE if reduced or _summary_animation_complete else Vector2.ONE*(1.0+sin(progress*PI)*0.08)
		number.modulate = Color.WHITE
	if is_instance_valid(_decor):
		_decor.clock = _summary_elapsed
		_decor.queue_redraw()

func _return_album() -> void:
	if stage!="summary" or _summary_action_taken: return
	_summary_action_taken = true
	if _on_album.is_valid(): _on_album.call()

func _replay() -> void:
	if stage!="summary" or _summary_action_taken: return
	_summary_action_taken = true
	if _on_replay.is_valid(): _on_replay.call()

func _animate_segment() -> void:
	if not is_instance_valid(_decor): return
	if stage=="summary":
		_animate_summary()
		return
	_decor.clock = _elapsed
	_decor.queue_redraw()
	if stage == "red":
		if _cards.is_empty(): return
		var card: Control = _cards[0]
		var grow := smoothstep(0.0,0.95,_elapsed)
		for index in range(_retreat_cards.size()):
			var retreat := smoothstep(0.0,0.95,_elapsed)
			var side := -1.0 if index<2 else 1.0
			_retreat_cards[index].position = _retreat_homes[index]+Vector2(side*130.0*retreat,25.0*retreat)
			_retreat_cards[index].scale = Vector2.ONE*lerpf(1.0,0.55,retreat)
			_retreat_cards[index].modulate = Color(0.65,0.55,0.7,0.60*(1.0-retreat))
		card.scale = Vector2.ONE*lerpf(0.86,1.0,grow)
		card.position = _card_homes[0]+card.size*(Vector2.ONE-card.scale)*0.5
		var flip := clampf((_elapsed-1.15)/0.55,0,1)
		_red_revealed = flip>=0.5
		card.set_face_down(not _red_revealed)
		card.set_flip(absf(cos(flip*PI)))
		if _red_revealed and not _red_reveal_emitted:
			_red_reveal_emitted = true
			sound_requested.emit("red_reveal")
		if not reduced and _red_revealed:
			card.set_tilt(Vector2(sin((_elapsed-1.4)*1.7)*0.55,cos((_elapsed-1.4)*1.4)*0.30))
		_reveal_row_badges(0,_red_revealed)
		_animate_row_feedback()
		return
	if stage == "reveal":
		for index in range(_cards.size()):
			var flip := clampf((_elapsed-0.1)/0.55,0,1)
			_cards[index].set_face_down(flip<0.5)
			_cards[index].set_flip(absf(cos(flip*PI)))
			if flip>=0.5 and not _flip_cue_emitted:
				_flip_cue_emitted = true
				sound_requested.emit("flip")
			_reveal_row_badges(index,flip>=0.5)
		_animate_row_feedback()
		return

func _animate_row_feedback() -> void:
	var segment: Dictionary = _segments[_segment_index]
	var start := float(segment.get("collection_start",-1.0))
	if start<0 or _elapsed<start: return
	var t := clampf((_elapsed-start)/COLLECTION_SECONDS,0,1)
	var rows: Array = segment.get("rows",[])
	for index in range(_cards.size()):
		var row: Dictionary = rows[index]
		var has_new := int(row.get("new_count",0))>0
		var has_duplicate := int(row.get("duplicate_count",0))>0
		var card: Control = _cards[index]
		if has_new:
			_book.visible = true
			var fly := smoothstep(0.28,1.0,t)
			if fly>0 and not _new_cue_emitted:
				_new_cue_emitted = true
				sound_requested.emit("new_card")
			card.position = _card_homes[index].lerp(Vector2(885,766),fly)
			card.scale = Vector2.ONE*lerpf(1.0,0.10,fly)
			card.modulate.a = 1.0-smoothstep(0.83,1.0,t)
			if is_instance_valid(_new_icons[index]): _new_icons[index].modulate.a = 1.0-smoothstep(0.2,0.55,t)
		if has_duplicate:
			_coin_receiver.visible = true
			var sheet: Control = _duplicate_cards[index] if is_instance_valid(_duplicate_cards[index]) else card
			sheet.visible = true
			var flip := clampf((t-0.12)/0.40,0,1)
			sheet.set_flip(absf(cos(flip*PI)))
			sheet.set_face_down(flip>=0.5)
			sheet.modulate.a = 1.0-smoothstep(0.47,0.62,flip)
			var coin := _coin_icons[index]
			coin.visible = flip>=0.5
			if coin.visible and not _coin_cue_emitted:
				_coin_cue_emitted = true
				sound_requested.emit("coins")
			_coin_labels[index].visible = flip>=0.5
			var group: Control = _coin_groups[index]
			group.visible = coin.visible
			# The entire icon/amount pair forms and holds at the original center,
			# then travels as one per-card visual. It never separates into numbers
			# left behind and an independently shrinking coin.
			var fly := smoothstep(CONVERSION_FLIGHT_START,1.0,t)
			var emerge := smoothstep(0.31,CONVERSION_HOLD_START,t)
			var destination := Vector2(1719,150)-group.size*0.5
			group.position = _coin_group_homes[index].lerp(destination,fly)+Vector2(0,-sin(fly*PI)*90.0)
			group.scale = Vector2.ONE*lerpf(0.82,1.0,emerge)*lerpf(1.0,0.22,fly)
			group.modulate.a = emerge*(1.0-smoothstep(0.92,1.0,t))
			if is_instance_valid(_duplicate_tags[index]): _duplicate_tags[index].modulate.a = 1.0-smoothstep(0.2,0.55,t)
		_row_labels[index].modulate.a = 1.0-smoothstep(0.2,0.55,t)

func _definition(id: String) -> Dictionary:
	return _catalog.card_definition(id) if _catalog != null else {"id":id,"name":"","grade":0,"theme":"galaxy","description":""}

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var ratio := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	_canvas.scale = Vector2.ONE*ratio
	_canvas.position = (size-DESIGN*ratio)*0.5

class StageDecor extends Control:
	var stage_name := "summary"
	var clock := 0.0
	var reduced := false
	var hidden_identity := false
	var theme_id := "galaxy"
	func _draw() -> void:
		draw_style_box(Ui.plate(Color("#221d30"),Color("#8a6877"),2),Rect2(Vector2.ZERO,size))
		var c := Vector2(920,410)
		if stage_name == "red":
			draw_rect(Rect2(2,2,1836,876),Color("#0d071a"))
			var charge := smoothstep(0.0,1.15,clock)
			var reveal := smoothstep(1.4,1.8,clock)
			# Layered translucent discs form a soft spotlight without an image dependency.
			for layer in range(15,0,-1):
				var radius := 110.0+float(layer)*22.0
				draw_circle(c,radius,Color(0.38,0.08,0.16,0.027*charge))
			for index in range(24):
				var angle := TAU*float(index)/24.0 + (clock*0.06 if not reduced else 0.0)
				var direction := Vector2(cos(angle),sin(angle))
				var inside := 240.0+80.0*(1.0-charge)
				var outside := inside+70.0+reveal*90.0
				draw_line(c+direction*inside,c+direction*outside,Color(0.96,0.69,0.28,0.15+charge*0.34),1.5,true)
			var burst := clampf((clock-1.42)/0.7,0,1)
			if burst>0 and burst<1:
				draw_arc(c,120+burst*380,0,TAU,96,Color(1.0,0.77,0.33,(1.0-burst)*0.8),8*(1-burst)+1,true)
			if hidden_identity and clock>1.45:
				for index in range(8):
					var angle := float(index)*TAU/8.0
					var point := c+Vector2(cos(angle),sin(angle))*350
					if theme_id == "digimon": draw_rect(Rect2(point-Vector2(10,10),Vector2(20,20)),Color(0.8,0.62,0.32,0.45))
					else: draw_arc(point,13,0,TAU,20,Color(0.8,0.62,0.32,0.45),2,true)
		elif stage_name == "summary":
			draw_line(Vector2(250,315),Vector2(1590,315),Color("#70516b"),2,true)
			if not reduced and clock<1.2:
				for metric in range(4):
					var pulse := clampf((clock-float(metric)*0.1)/0.85,0,1)
					var origin := Vector2(357+metric*382,456)
					for particle in range(8):
						var angle := float(particle)*TAU/8.0
						var point := origin+Vector2(cos(angle),sin(angle))*lerpf(48,136,pulse)
						draw_circle(point,2.0+sin(pulse*PI)*2.0,Color(1.0,0.81,0.42,sin(pulse*PI)*0.68))
