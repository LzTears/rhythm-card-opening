extends Control
## All three categories preview before purchase. Only the host may buy/equip.
const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const ControllerUi = preload("res://scripts/controller_ui.gd")
const Geometry = preload("res://scripts/world_meshes.gd")
const DEFAULT_BOARD_PATH := "res://assets/art/rhythm_v2/battle-table.png"
const DESIGN := Vector2(1780,860)
const CATEGORIES := ["beat","board","pack"]
const TRIGGER_PRESS_THRESHOLD := 0.6
const TRIGGER_RELEASE_THRESHOLD := 0.25
var _profile: Dictionary = {}
var _font: Font
var _on_buy := Callable()
var _on_equip := Callable()
var _category := "beat"
var _selected := "default"
var _canvas: Control
var _catalog: Script
var _preview: SkinPreview
var _status: Label
var _configured_once := false
var _reduced := false
var _input_device := "keyboard"
var _focus_target_name := "SkinPreview_default"
var _category_states: Dictionary = {}
var _trigger_latches: Dictionary = {}
var _preview_buttons: Dictionary = {}
var _category_buttons: Dictionary = {}
var _action_button: Button

func _ready() -> void:
	if size == Vector2.ZERO: size = DESIGN
	resized.connect(_layout)
	_rebuild()

func configure(profile: Dictionary, font: Font = null, on_buy: Callable = Callable(), on_equip: Callable = Callable()) -> void:
	_profile = profile.duplicate(true)
	if not _configured_once:
		_selected = str(_profile.get("skin_equipped",{}).get(_category,"default"))
		_focus_target_name = "SkinPreview_"+_selected
		_configured_once = true
	_font = font
	_reduced = bool(_profile.get("settings",{}).get("reduce_effects",false))
	_on_buy = on_buy
	_on_equip = on_equip
	if ResourceLoader.exists("res://scripts/skin_catalog.gd"): _catalog = load("res://scripts/skin_catalog.gd")
	_rebuild()

func set_reduced(value: bool) -> void:
	_reduced = value
	if not is_instance_valid(_canvas): return
	for item in _canvas.get_children():
		if item is SkinPreview: item.set_reduced(value)

func select_category(category: String) -> void:
	if category not in CATEGORIES: return
	_remember_category()
	_category = category
	var saved: Dictionary = _category_states.get(category,{})
	_selected = str(saved.get("selected_id",_profile.get("skin_equipped",{}).get(category,"default")))
	_focus_target_name = str(saved.get("focused_control","SkinPreview_"+_selected))
	_rebuild(true)

func select_skin(id: String) -> void:
	if id != "default" and str(_definition(id).get("category","")) != _category: return
	_selected = id
	# Preview selection keeps native GUI focus here. The joypad A shortcut
	# acts on this selected skin independently of the focused control.
	_focus_target_name = "SkinPreview_"+id
	_rebuild(true)

func set_input_device(value: String) -> void:
	if value not in ["keyboard","joypad"]: return
	_input_device = value
	ControllerUi.set_device(self,value)

## Main owns the hub/modal gate. Raw Dpad/arrows are consumed by this layer;
## left-right select previews, A acts on the selection, and stick/Tab stay native GUI.
func handle_controller_event(event: InputEvent) -> bool:
	if not is_visible_in_tree(): return false
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			if event.pressed:
				set_input_device("joypad")
				request_selected_action()
			return true
		if event.button_index not in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]: return false
		if event.pressed:
			set_input_device("joypad")
			if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
				_cycle_skin(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1)
		return true
	if event is InputEventKey:
		if event.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: return false
		if event.pressed and not event.echo and not (event.alt_pressed or event.ctrl_pressed or event.meta_pressed):
			set_input_device("keyboard")
			if event.keycode in [KEY_LEFT,KEY_RIGHT]:
				_cycle_skin(-1 if event.keycode==KEY_LEFT else 1)
		return true
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]: return false
		var key := "%d:%d" % [event.device,event.axis]
		if event.axis_value<=TRIGGER_RELEASE_THRESHOLD:
			_trigger_latches.erase(key)
		elif event.axis_value>TRIGGER_PRESS_THRESHOLD and not bool(_trigger_latches.get(key,false)):
			_trigger_latches[key] = true
			set_input_device("joypad")
			select_category(CATEGORIES[posmod(CATEGORIES.find(_category)+(-1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1),CATEGORIES.size())])
		return true
	return false

func _cycle_skin(direction: int) -> void:
	var ids := _skin_ids()
	if ids.is_empty(): return
	select_skin(ids[posmod(ids.find(_selected)+direction,ids.size())])

func _skin_ids() -> Array[String]:
	var ids: Array[String] = ["default"]
	if _catalog != null:
		for id in _catalog.skin_ids():
			if str(_definition(id).get("category","")) == _category: ids.append(str(id))
	return ids

func _on_control_focused(control_name: String) -> void:
	_focus_target_name = control_name
	_remember_category()

func _focused_control_name() -> String:
	if not is_inside_tree() or not is_instance_valid(_canvas): return ""
	var focused := get_viewport().gui_get_focus_owner()
	return str(focused.name) if focused!=null and _canvas.is_ancestor_of(focused) else ""

func _remember_category() -> void:
	_category_states[_category] = {"selected_id":_selected,"focused_control":_focus_target_name}

func get_navigation_state() -> Dictionary:
	_remember_category()
	return {"category":_category,"selected_id":_selected,"focused_control":_focus_target_name,"category_states":_category_states.duplicate(true)}

func restore_navigation_state(state: Dictionary) -> void:
	if state.is_empty(): return
	var category := str(state.get("category",_category))
	if category in CATEGORIES: _category = category
	_selected = str(state.get("selected_id",_selected))
	_focus_target_name = str(state.get("focused_control","SkinPreview_"+_selected))
	if state.get("category_states",{}) is Dictionary: _category_states = state.get("category_states",{}).duplicate(true)
	_rebuild(true)

func ensure_controller_focus() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_canvas): return
	var target := _canvas.get_node_or_null(_focus_target_name) as Button
	if target==null or target.disabled: target = _preview_buttons.get(_selected)
	if target==null: target = _category_buttons.get(_category)
	if target!=null and not target.disabled: target.grab_focus()

func request_selected_action() -> void:
	if _selected == _equipped(): return
	if _is_owned(_selected):
		if _on_equip.is_valid(): _on_equip.call(_selected,_category)
		return
	var price := int(_definition(_selected).get("price",0))
	if int(_profile.get("points",0)) < price:
		if is_instance_valid(_status): _status.text = "金币不足"
		return
	if _on_buy.is_valid(): _on_buy.call(_selected)

func get_shop_state() -> Dictionary:
	var owned := _is_owned(_selected)
	return {"category":_category,"selected_id":_selected,"owned":owned,"equipped_id":_equipped(),"price":int(_definition(_selected).get("price",0)),"preview_before_purchase":true,"action":"equipped" if _selected==_equipped() else ("equip" if owned else "buy"),"mutates_profile":false,"local_balance_visible":false,"preview":_preview.get_preview_state() if is_instance_valid(_preview) else {},"preview_ids":_skin_ids(),"focused_control":_focused_control_name(),"focus_target":_focus_target_name,"input_device":_input_device,"controller_trigger_latched":_trigger_latches.duplicate(),"category_states":_category_states.duplicate(true)}

func _rebuild(restore_focus: bool = false) -> void:
	var had_focus := not _focused_control_name().is_empty()
	if is_instance_valid(_canvas): remove_child(_canvas); _canvas.queue_free()
	_preview_buttons.clear()
	_category_buttons.clear()
	_canvas = Control.new()
	_canvas.name = "SkinShop"
	_canvas.size = DESIGN
	add_child(_canvas)
	Ui.panel(_canvas,Rect2(Vector2.ZERO,DESIGN),Color("#252131"),Color("#806574"))
	var names := {"beat":"节拍","board":"战斗主题","pack":"卡包"}
	for index in range(3):
		var category: String = CATEGORIES[index]
		var category_button := Ui.button(_canvas,names[category],Rect2(24+index*242,18,224,54),_font,select_category.bind(category))
		category_button.name = "SkinCategory_"+category
		ControllerUi.set_tab_selected(category_button,_category==category)
		category_button.focus_entered.connect(_on_control_focused.bind(str(category_button.name)))
		_category_buttons[category] = category_button
	var ids := _skin_ids()
	if not ids.has(_selected): _selected = "default"
	for index in range(ids.size()):
		var id := ids[index]
		var definition := _definition(id)
		var x := 28.0+float(index)*292.0
		Ui.panel(_canvas,Rect2(x,98,270,584),Color("#33283c"),Ui.GOLD if _selected==id else Color("#67516b"))
		var preview := SkinPreview.new()
		preview.category = _category
		preview.style_id = str(definition.get("style","default"))
		preview.equipped = _preview_equipped(id)
		preview.font = _font
		preview.reduced = _reduced
		preview.position = Vector2(x+12,114)
		preview.size = Vector2(246,330)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(preview)
		Ui.label(_canvas,str(definition.get("name","默认外观")),Rect2(x+12,466,246,46),_font,26,Ui.INK,true)
		if id == _equipped():
			Ui.icon(_canvas,"check",Rect2(x+40,532,40,40),Color("#98ddb1"))
			Ui.label(_canvas,"使用中",Rect2(x+82,532,160,40),_font,23,Color("#98ddb1"))
		elif _is_owned(id): Ui.label(_canvas,"已拥有",Rect2(x+12,532,246,40),_font,23,Ui.MUTED,true)
		else:
			Ui.icon(_canvas,"coin",Rect2(x+42,532,40,40))
			Ui.label(_canvas,Ui.comma(int(definition.get("price",0))),Rect2(x+88,532,170,40),_font,24,Ui.GOLD)
		var preview_button := Ui.button(_canvas,"预览",Rect2(x+45,606,180,52),_font,select_skin.bind(id),_selected==id)
		preview_button.name = "SkinPreview_"+id
		preview_button.focus_entered.connect(_on_control_focused.bind(str(preview_button.name)))
		_preview_buttons[id] = preview_button
	Ui.panel(_canvas,Rect2(934,98,818,738),Color("#1c1929"),Color("#67516b"))
	_preview = SkinPreview.new()
	_preview.name = "SelectedSkinPreview"
	_preview.category = _category
	_preview.style_id = str(_definition(_selected).get("style","default"))
	_preview.equipped = _preview_equipped(_selected)
	_preview.font = _font
	_preview.reduced = _reduced
	_preview.position = Vector2(958,122)
	_preview.size = Vector2(770,520)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_preview)
	Ui.label(_canvas,str(_definition(_selected).get("name","默认外观")),Rect2(970,660,734,55),_font,32,Ui.INK,true)
	var action := "使用中" if _selected==_equipped() else ("使用" if _is_owned(_selected) else "解锁")
	_action_button = Ui.button(_canvas,action,Rect2(1235,752,220,60),_font,request_selected_action)
	_action_button.name = "SkinAction"
	_action_button.disabled = _selected==_equipped()
	_action_button.focus_entered.connect(_on_control_focused.bind("SkinAction"))
	ControllerUi.button_prompt(_action_button,"A",_input_device)
	if not _is_owned(_selected):
		Ui.icon(_canvas,"coin",Rect2(980,760,44,44))
		Ui.label(_canvas,Ui.comma(int(_definition(_selected).get("price",0))),Rect2(1034,760,195,44),_font,26,Ui.GOLD)
	_status = Ui.label(_canvas,"",Rect2(1480,752,245,60),_font,22,Color("#f0a793"),true)
	Ui.label(_canvas,"三类外观可自由混搭",Rect2(30,710,820,50),_font,25,Ui.MUTED,true)
	Ui.label(_canvas,"购买后永久拥有 · 切换免费",Rect2(30,786,820,48),_font,23,Ui.MUTED,true)
	_connect_focus(ids)
	ControllerUi.set_device(self,_input_device)
	_remember_category()
	_layout()
	if restore_focus or had_focus: ensure_controller_focus.call_deferred()

func _connect_focus(ids: Array[String]) -> void:
	var order: Array[Button] = []
	for index in range(CATEGORIES.size()):
		var tab: Button = _category_buttons[CATEGORIES[index]]
		var left: Button = _category_buttons[CATEGORIES[posmod(index-1,CATEGORIES.size())]]
		var right: Button = _category_buttons[CATEGORIES[(index+1)%CATEGORIES.size()]]
		tab.focus_neighbor_left = tab.get_path_to(left)
		tab.focus_neighbor_right = tab.get_path_to(right)
		tab.focus_neighbor_bottom = tab.get_path_to(_preview_buttons[_selected])
		order.append(tab)
	for index in range(ids.size()):
		var button: Button = _preview_buttons[ids[index]]
		button.focus_neighbor_left = button.get_path_to(_preview_buttons[ids[posmod(index-1,ids.size())]])
		button.focus_neighbor_right = button.get_path_to(_preview_buttons[ids[(index+1)%ids.size()]])
		button.focus_neighbor_top = button.get_path_to(_category_buttons[_category])
		if not _action_button.disabled: button.focus_neighbor_bottom = button.get_path_to(_action_button)
		order.append(button)
	if not _action_button.disabled:
		_action_button.focus_neighbor_top = _action_button.get_path_to(_preview_buttons[_selected])
		_action_button.focus_neighbor_left = _action_button.get_path_to(_preview_buttons[_selected])
		order.append(_action_button)
	for index in range(order.size()):
		order[index].focus_next = order[index].get_path_to(order[(index+1)%order.size()])
		order[index].focus_previous = order[index].get_path_to(order[posmod(index-1,order.size())])

func _equipped() -> String:
	return str(_profile.get("skin_equipped",{}).get(_category,"default"))

func _preview_equipped(id: String) -> Dictionary:
	var result := {"beat":"default", "board":"default", "pack":"default"}
	for category: String in result:
		result[category] = str(_profile.get("skin_equipped",{}).get(category,"default"))
	result[_category] = id
	return result

func _is_owned(id: String) -> bool:
	return id == "default" or bool(_profile.get("skin_owned",{}).get(id,false))

func _definition(id: String) -> Dictionary:
	if id == "default": return {"id":"default","name":"默认外观","category":_category,"style":"default","price":0}
	return _catalog.skin_definition(id) if _catalog != null else {}

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var ratio := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	_canvas.scale = Vector2.ONE*ratio
	_canvas.position = (size-DESIGN*ratio)*0.5

class SkinPreview extends Control:
	var category := "beat"
	var style_id := "default"
	var equipped := {"beat":"default", "board":"default", "pack":"default"}
	var font: Font
	var reduced := false
	var _time := 0.0
	var _geometry := Geometry.new()
	var _pack_art_cache: Dictionary = {}
	func _style_for(part: String) -> String:
		var id := str(equipped.get(part,"default"))
		return "default" if id == "default" else id.trim_prefix(part+"_")
	func _board_path() -> String:
		var style := _style_for("board")
		return DEFAULT_BOARD_PATH if style == "default" else "res://assets/skins/board_%s.png" % style
	func _pack_art(grade: int) -> Dictionary:
		var style := _style_for("pack")
		var key := "%s:%d" % [style,grade]
		if _pack_art_cache.has(key): return _pack_art_cache[key]
		var path := "res://assets/skins/pack_%s_%d.png" % [style,grade]
		var source := Rect2()
		if style == "default":
			# World selects the current formal-art priority and its registered 3:4
			# crop. Sampling only this region preserves the original printed pack.
			var layout: Dictionary = _geometry.pack_layout(grade)
			path = str(layout.path)
			source = Rect2(layout.crop)
		var art: Texture2D = Ui.texture(path)
		if art != null and not source.has_area(): source = Rect2(Vector2.ZERO,art.get_size())
		var result := {"path":path,"texture":art,"source":source}
		_pack_art_cache[key] = result
		return result
	func set_reduced(value: bool) -> void:
		reduced = value
		queue_redraw()
	func _process(delta: float) -> void:
		if is_visible_in_tree() and category == "beat" and not reduced and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
			_time += delta
			queue_redraw()
	func get_preview_state() -> Dictionary:
		var paths: Array[String] = []
		var regions: Array[Rect2] = []
		var packs_loaded := true
		for grade in range(5):
			var art := _pack_art(grade)
			paths.append(str(art.path))
			regions.append(art.source)
			packs_loaded = packs_loaded and art.texture != null
		return {"category":category,"style":style_id,"resolved_equipped":equipped.duplicate(true),
			"board_path":_board_path(),"board_loaded":Ui.texture(_board_path())!=null,"pack_paths":paths,
			"pack_source_regions":regions,"pack_loaded":packs_loaded,"beat_style":_style_for("beat"),
			"beat_native":category=="beat","pc_key_shape":"square","xbox_key_shape":"circle","xbox_order":["X","B","A","Y"],"effect_time":_time,"reduced":reduced}
	func _draw() -> void:
		draw_style_box(Ui.plate(Color("#17182a"),Color("#59516d"),1),Rect2(Vector2.ZERO,size))
		var beat_style := _style_for("beat")
		var neon := beat_style == "neon"
		var accent := Color("#7ae9fa") if neon else Color("#edc879")
		var board: Texture2D = Ui.texture(_board_path())
		if board != null: draw_texture_rect(board,Rect2(Vector2.ZERO,size),false,Color(0.65,0.65,0.65,1))
		else: draw_rect(Rect2(Vector2.ZERO,size),Color("#292b39"))
		var c := size*Vector2(0.5,0.5)
		var r := minf(size.y*0.30,size.x*0.28)
		if category in ["pack","board"]:
			draw_arc(c,r,0,TAU,60,Color(0.8,0.7,0.9,0.7),maxf(1,size.y*0.008),true)
			for index in range(5):
				var theta := -PI*0.5+TAU*float(index)/5.0
				var center := c+Vector2(cos(theta),sin(theta))*r*0.82
				var pack_art := _pack_art(index)
				var pack: Texture2D = pack_art.texture
				var dimensions := Vector2(size.y*0.125,size.y*0.1875)
				var source: Rect2 = pack_art.source
				if source.has_area(): dimensions.x = dimensions.y*source.size.x/source.size.y
				if category=="pack": dimensions *= 1.4
				if pack != null: draw_texture_rect_region(pack,Rect2(center-dimensions*0.5,dimensions),source)
				else:
					draw_style_box(Ui.plate(Color("#383245"),Ui.GRADES[index],2),Rect2(center-dimensions*0.5,dimensions))
					draw_line(center-Vector2(dimensions.x*0.3,0),center+Vector2(dimensions.x*0.3,0),Ui.GRADES[index],2,true)
		else:
			c.y = size.y*0.42
			r = minf(size.y*0.26,size.x*0.28)
			var directions := [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
			var colours := [Color("#70b5ff"),Color("#f37c81"),Color("#f1df79"),Color("#91deaa")]
			for index in range(4):
				var point: Vector2 = c+directions[index]*r
				var pulse := 0.5+0.5*sin(_time*4.0-float(index)*1.57)
				if neon:
					for square_ring in range(3):
						var d := size.y*(0.052+square_ring*0.035)
						draw_rect(Rect2(point-Vector2.ONE*d*0.5,Vector2.ONE*d),Color(colours[index],0.4-float(square_ring)*0.1),false,2)
				elif beat_style == "starlight":
					draw_arc(point,size.y*(0.055+pulse*0.025),0,TAU,30,Color(colours[index],0.6),2,true)
					for star in range(5):
						var a := float(star)*TAU/5.0+_time*0.2
						draw_circle(point+Vector2(cos(a),sin(a))*size.y*0.09,1.5+pulse*1.5,colours[index])
				var key_side := size.y*0.11
				var key_style := Ui.plate(Color("#242339"),colours[index],2)
				key_style.set_corner_radius_all(maxi(2,int(key_side*0.09)))
				key_style.shadow_size = 0
				draw_style_box(key_style,Rect2(point-Vector2.ONE*key_side*0.5,Vector2.ONE*key_side))
				if font != null:
					var px := maxi(12,int(size.y*0.060))
					var glyph: String = ["←","→","↑","↓"][index]
					var measured := font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
					draw_string(font,point+Vector2(-measured.x*0.5,measured.y*0.25),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,px,colours[index])
			draw_arc(c,r*0.56,0,TAU,60,accent.darkened(0.5),2,true)
			var xbox_letters := ["X","B","A","Y"]
			var xbox_colours := [Color("#70b5ff"),Color("#f37c81"),Color("#91deaa"),Color("#f1df79")]
			var xbox_radius := size.y*0.037
			var xbox_spacing := xbox_radius*3.05
			var xbox_y := size.y*0.865
			var xbox_start := size.x*0.5-xbox_spacing*1.5
			for index in range(4):
				var point := Vector2(xbox_start+float(index)*xbox_spacing,xbox_y)
				draw_circle(point,xbox_radius,xbox_colours[index].darkened(0.66))
				draw_arc(point,xbox_radius,0,TAU,26,xbox_colours[index],1.5,true)
				if font != null:
					var px := maxi(10,int(size.y*0.045))
					var measured := font.get_string_size(xbox_letters[index],HORIZONTAL_ALIGNMENT_LEFT,-1,px)
					draw_string(font,point+Vector2(-measured.x*0.5,measured.y*0.25),xbox_letters[index],HORIZONTAL_ALIGNMENT_LEFT,-1,px,xbox_colours[index])
			if font != null:
				var px := maxi(10,int(size.y*0.034))
				draw_string(font,Vector2(xbox_start-xbox_radius-size.y*0.14,xbox_y+float(px)*0.35),"Xbox",HORIZONTAL_ALIGNMENT_LEFT,-1,px,Ui.MUTED)
