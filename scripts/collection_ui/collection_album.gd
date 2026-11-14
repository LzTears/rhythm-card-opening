extends Control
## Read-only album. A page host may recreate this Control after profile changes.
const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const CardView = preload("res://scripts/collection_ui/collection_card_view.gd")
const Inspector = preload("res://scripts/collection_ui/card_inspector.gd")
const ControllerUi = preload("res://scripts/controller_ui.gd")
const DESIGN := Vector2(1780,880)
const GRID_COLUMNS := 6
const GRID_ROWS := 3
const PAGE_SIZE := GRID_COLUMNS*GRID_ROWS
const TRIGGER_PRESS_THRESHOLD := 0.6
const TRIGGER_RELEASE_THRESHOLD := 0.25
var _profile: Dictionary = {}
var _font: Font
var _card_font: Font
var _canvas: Control
var _catalog: Script
var _theme_id := "galaxy"
var _page := 0
var _owned_only := false
var _selected_id := ""
var _visible_ids: Array[String] = []
var _all_ids: Array[String] = []
var _themes: Array[Dictionary] = []
var _inspector: Control
var _reduced := false
var _input_device := "keyboard"
var _card_hits: Dictionary = {}
var _card_views: Dictionary = {}
var _view_states: Dictionary = {}
var _page_selections: Dictionary = {}
var _trigger_latches: Dictionary = {}

func set_input_device(value: String) -> void:
	if value not in ["keyboard","joypad"]: return
	_input_device = value
	ControllerUi.set_device(self,value)
	if is_instance_valid(_inspector) and _inspector.has_method("set_input_device"):
		_inspector.set_input_device(value)

func _ready() -> void:
	if size == Vector2.ZERO: size = DESIGN
	resized.connect(_layout)
	_rebuild()

func configure(profile: Dictionary, font: Font = null, card_font: Font = null) -> void:
	_profile = profile.duplicate(true)
	_font = font
	_card_font = card_font if card_font != null else font
	if ResourceLoader.exists("res://scripts/collection_catalog.gd"): _catalog = load("res://scripts/collection_catalog.gd")
	_all_ids.clear()
	_themes.clear()
	if _catalog != null:
		for id in _catalog.card_ids(): _all_ids.append(str(id))
		for theme: Dictionary in _catalog.themes(): _themes.append(theme.duplicate(true))
	if _theme_definition(_theme_id).is_empty(): _theme_id = str(_themes[0].id) if not _themes.is_empty() else ""
	_rebuild()

func set_reduced(value: bool) -> void:
	_reduced = value
	if is_instance_valid(_inspector): _inspector.set_reduced(value)
	if _canvas == null: return
	for item in _canvas.find_children("*","Control",true,false):
		if item.has_method("set_reduced"): item.set_reduced(value)

func select_theme(theme_id: String) -> void:
	if _theme_definition(theme_id).is_empty(): return
	close_inspector()
	_remember_navigation()
	_theme_id = theme_id
	_restore_view()
	_rebuild(true)

func set_owned_only(value: bool) -> void:
	close_inspector()
	_remember_navigation()
	_owned_only = value
	_restore_view()
	_rebuild(true)

func set_page(value: int) -> void:
	close_inspector()
	_remember_navigation()
	_page = clampi(value,0,maxi(0,ceili(float(_filtered_ids().size())/PAGE_SIZE)-1))
	_selected_id = str(_page_selections.get(_page_key(),""))
	_rebuild(true)

func select_card(id: String) -> void:
	if not _visible_ids.has(id): return
	open_card(id)

func highlight_card(id: String) -> void:
	var index := _filtered_ids().find(id)
	if index<0: return
	_selected_id = id
	_page = index/PAGE_SIZE
	_rebuild(true)

func open_card(id: String = "") -> void:
	var target := _selected_id if id.is_empty() else id
	var filtered := _filtered_ids()
	var index := filtered.find(target)
	if index<0: return
	_selected_id = target
	_page = index/PAGE_SIZE
	_rebuild()
	_trigger_latches.clear()
	if not is_instance_valid(_inspector):
		_inspector = Inspector.new()
		_inspector.name = "AlbumCardInspector"
		_inspector.position = Vector2.ZERO
		_inspector.size = Vector2(1920,1080)
		_inspector.z_index = 100
		get_parent().add_child(_inspector)
		_inspector.closed.connect(_on_inspector_closed)
		_inspector.card_changed.connect(_on_inspector_card_changed)
	_inspector.configure(_profile,filtered,target,_font,_card_font,_reduced)
	if _inspector.has_method("set_input_device"): _inspector.set_input_device(_input_device)

func close_inspector() -> void:
	if is_instance_valid(_inspector): _inspector.close()

func get_inspector() -> Control:
	return _inspector if is_instance_valid(_inspector) else null

func _on_inspector_closed() -> void:
	_inspector = null
	_trigger_latches.clear()
	ensure_controller_focus.call_deferred()

func _on_inspector_card_changed(id: String) -> void:
	var index := _filtered_ids().find(id)
	if index<0: return
	_selected_id = id
	_page = index/PAGE_SIZE
	_rebuild()
	_remember_navigation()

## Main calls this only for the collection hub without its generic overlay.
## Raw Dpad/arrow directions belong to the page layer, including releases and
## echoes: only left-right turn pages. Stick movement, Tab and A stay native
## GUI navigation/activation, and the inspector owns every event while open.
func handle_controller_event(event: InputEvent) -> bool:
	if is_instance_valid(_inspector) or not is_visible_in_tree(): return false
	if event is InputEventJoypadButton:
		if event.button_index not in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]: return false
		if event.pressed:
			set_input_device("joypad")
			if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
				set_page(_page+(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1))
		return true
	if event is InputEventKey:
		if event.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: return false
		if event.pressed and not event.echo and not (event.alt_pressed or event.ctrl_pressed or event.meta_pressed):
			set_input_device("keyboard")
			if event.keycode in [KEY_LEFT,KEY_RIGHT]:
				set_page(_page+(-1 if event.keycode==KEY_LEFT else 1))
		return true
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]: return false
		var key := "%d:%d" % [event.device,event.axis]
		if event.axis_value<=TRIGGER_RELEASE_THRESHOLD:
			_trigger_latches.erase(key)
		elif event.axis_value>TRIGGER_PRESS_THRESHOLD and not bool(_trigger_latches.get(key,false)):
			_trigger_latches[key] = true
			set_input_device("joypad")
			_cycle_theme(-1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1)
		return true
	return false

func _cycle_theme(direction: int) -> void:
	if _themes.is_empty(): return
	var current := 0
	for index in range(_themes.size()):
		if str(_themes[index].id)==_theme_id: current = index
	select_theme(str(_themes[posmod(current+direction,_themes.size())].id))

func _view_key() -> String:
	return _theme_id+(":owned" if _owned_only else ":all")

func _page_key() -> String:
	return _view_key()+":"+str(_page)

func _remember_navigation() -> void:
	_view_states[_view_key()] = {"page":_page,"selected_id":_selected_id}
	if not _selected_id.is_empty(): _page_selections[_page_key()] = _selected_id

func _restore_view() -> void:
	var state: Dictionary = _view_states.get(_view_key(),{})
	_page = int(state.get("page",0))
	_selected_id = str(state.get("selected_id",""))

## Persist this small UI state when Main recreates the hub page.
func get_navigation_state() -> Dictionary:
	_remember_navigation()
	return {"theme":_theme_id,"page":_page,"owned_only":_owned_only,"selected_id":_selected_id,"views":_view_states.duplicate(true),"page_selections":_page_selections.duplicate(true)}

func restore_navigation_state(state: Dictionary) -> void:
	if state.is_empty(): return
	var requested_theme := str(state.get("theme",_theme_id))
	if not _theme_definition(requested_theme).is_empty(): _theme_id = requested_theme
	_owned_only = bool(state.get("owned_only",_owned_only))
	_page = int(state.get("page",0))
	_selected_id = str(state.get("selected_id",""))
	if state.get("views",{}) is Dictionary: _view_states = state.get("views",{}).duplicate(true)
	if state.get("page_selections",{}) is Dictionary: _page_selections = state.get("page_selections",{}).duplicate(true)
	_rebuild(true)

## Keep the selected card as the preferred GUI target, including after an
## inspector moved across pages. Never steal focus from that modal.
func ensure_controller_focus() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or is_instance_valid(_inspector): return
	var target: Button = _card_hits.get(_selected_id)
	if is_instance_valid(target):
		target.grab_focus()
		return
	var fallback: Button = _canvas.get_node_or_null("AlbumOwnedFilter") if is_instance_valid(_canvas) else null
	if is_instance_valid(fallback): fallback.grab_focus()

func _on_card_focused(id: String) -> void:
	if not _visible_ids.has(id): return
	_selected_id = id
	for card_id in _card_views:
		var card: Control = _card_views[card_id]
		card.set_selected(str(card_id)==id)
	_remember_navigation()

func _focused_card_id() -> String:
	if not is_inside_tree(): return ""
	var focused := get_viewport().gui_get_focus_owner()
	for id in _card_hits:
		if focused==_card_hits[id]: return str(id)
	return ""

func _exit_tree() -> void:
	if is_instance_valid(_inspector) and not _inspector.is_queued_for_deletion(): _inspector.queue_free()

func get_page_state() -> Dictionary:
	var filtered := _filtered_ids()
	return {"theme":_theme_id,"themes":_themes.duplicate(true),"page":_page,"page_count":maxi(1,ceili(float(filtered.size())/PAGE_SIZE)),"owned_only":_owned_only,"visible_ids":_visible_ids.duplicate(),"selected_id":_selected_id,"focused_card_id":_focused_card_id(),"selected_owned":_is_owned(_selected_id),"progress":_theme_progress(_theme_id),"read_only":true,"layout":"grid_6x3","grid_columns":GRID_COLUMNS,"grid_rows":GRID_ROWS,"page_size":PAGE_SIZE,"scroll_enabled":false,"detail":{},"input_device":_input_device,"controller_trigger_latched":_trigger_latches.duplicate(),"inspector_open":is_instance_valid(_inspector),"inspector":_inspector.get_inspector_state() if is_instance_valid(_inspector) else {}}

func _rebuild(restore_focus: bool = false) -> void:
	var had_card_focus := not _focused_card_id().is_empty()
	if is_instance_valid(_canvas):
		remove_child(_canvas)
		_canvas.queue_free()
	_card_hits.clear()
	_card_views.clear()
	_canvas = Control.new()
	_canvas.name = "CollectionAlbum"
	_canvas.size = DESIGN
	add_child(_canvas)
	Ui.panel(_canvas,Rect2(50,0,1680,880),Color("#3d2a51"),Color("#a585ac"))
	var book := BookPaper.new()
	book.name = "NativePaperAlbum"
	book.size = DESIGN
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(book)
	_build_theme_tabs()
	var owned_filter := Ui.button(_canvas,"已拥有" if _owned_only else "全部卡位",Rect2(1394,14,280,52),_font,set_owned_only.bind(not _owned_only),_owned_only)
	owned_filter.name = "AlbumOwnedFilter"
	# The native paper leaves remain separate from card art and runtime labels.
	var filtered := _filtered_ids()
	_page = clampi(_page,0,maxi(0,ceili(float(filtered.size())/PAGE_SIZE)-1))
	_visible_ids.clear()
	for index in range(_page*PAGE_SIZE,mini(filtered.size(),(_page+1)*PAGE_SIZE)): _visible_ids.append(filtered[index])
	if not _visible_ids.has(_selected_id): _selected_id = _visible_ids[0] if not _visible_ids.is_empty() else ""
	for index in range(_visible_ids.size()):
		var id := _visible_ids[index]
		var column := index % GRID_COLUMNS
		var row := index / GRID_COLUMNS
		var x := 134.0+float(column)*267.0
		var y := 89.0+float(row)*244.0
		var card: Control = CardView.new()
		card.name = "Slot_%02d" % index
		card.position = Vector2(x,y)
		card.size = Vector2(177,236)
		_canvas.add_child(card)
		card.configure(_definition(id),_is_owned(id),_card_font,true)
		card.set_reduced(_reduced)
		card.set_selected(id==_selected_id)
		_card_views[id] = card
		var hit := Button.new()
		hit.name = "CardHit_"+id
		hit.position = Vector2(x-5,y-3)
		hit.size = Vector2(187,242)
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		var hover := Ui.plate(Color(1,0.9,0.8,0.06),Ui.GOLD,1)
		hover.shadow_size = 0
		hit.add_theme_stylebox_override("hover",hover)
		hit.add_theme_stylebox_override("focus",Ui.plate(Color.TRANSPARENT,Ui.GOLD,2))
		hit.pressed.connect(select_card.bind(id))
		hit.focus_entered.connect(_on_card_focused.bind(id))
		_canvas.add_child(hit)
		ControllerUi.decorate(hit,"")
		_card_hits[id] = hit
	_connect_card_focus()
	if _visible_ids.is_empty():
		Ui.icon(_canvas,"book",Rect2(820,300,140,140),Color("#ad98b9"))
		Ui.label(_canvas,"还没有收集到这个主题的卡片",Rect2(590,470,600,60),_font,26,Color("#e2d4e6"),true)
	var count := maxi(1,ceili(float(filtered.size())/PAGE_SIZE))
	var previous := Ui.button(_canvas,"←",Rect2(650,832,110,44),_font,set_page.bind(_page-1))
	previous.name = "AlbumPreviousPage"
	previous.disabled = _page <= 0
	ControllerUi.decorate(previous)
	Ui.label(_canvas,"%d / %d" % [_page+1,count],Rect2(780,832,220,44),_font,25,Ui.INK,true)
	var next := Ui.button(_canvas,"→",Rect2(1020,832,110,44),_font,set_page.bind(_page+1))
	next.name = "AlbumNextPage"
	next.disabled = _page >= count-1
	ControllerUi.decorate(next)
	ControllerUi.set_device(self,_input_device)
	_remember_navigation()
	_layout()
	if restore_focus or had_card_focus: ensure_controller_focus.call_deferred()

func _connect_card_focus() -> void:
	for index in range(_visible_ids.size()):
		var hit: Button = _card_hits[_visible_ids[index]]
		var column := index%GRID_COLUMNS
		var left := index-1 if column>0 else index
		var right := index+1 if column<GRID_COLUMNS-1 and index+1<_visible_ids.size() else index
		var up := index-GRID_COLUMNS if index>=GRID_COLUMNS else index
		var last_row := index/GRID_COLUMNS==(_visible_ids.size()-1)/GRID_COLUMNS
		var down := mini(index+GRID_COLUMNS,_visible_ids.size()-1) if not last_row else index
		hit.focus_neighbor_left = hit.get_path_to(_card_hits[_visible_ids[left]])
		hit.focus_neighbor_right = hit.get_path_to(_card_hits[_visible_ids[right]])
		# Outer vertical edges keep the GUI's geometric search, so the header,
		# filter, page controls and hub footer stay reachable by the left stick.
		hit.focus_neighbor_top = hit.get_path_to(_card_hits[_visible_ids[up]]) if index>=GRID_COLUMNS else NodePath("")
		hit.focus_neighbor_bottom = hit.get_path_to(_card_hits[_visible_ids[down]]) if not last_row else NodePath("")
		hit.focus_next = hit.get_path_to(_card_hits[_visible_ids[(index+1)%_visible_ids.size()]])
		hit.focus_previous = hit.get_path_to(_card_hits[_visible_ids[posmod(index-1,_visible_ids.size())]])

func _is_owned(id: String) -> bool:
	return bool(_profile.get("album",{}).get(id,false))

func _definition(id: String) -> Dictionary:
	return _catalog.card_definition(id) if _catalog != null else {}

func _theme_definition(theme_id: String) -> Dictionary:
	for theme: Dictionary in _themes:
		if str(theme.id) == theme_id: return theme
	return {}

func _build_theme_tabs() -> void:
	if _themes.is_empty(): return
	# Keep the existing two tabs in place. New themes occupy the remaining
	# header space; the owned-only filter keeps its own fixed region at x1394.
	var widths: Array[float] = []
	var total_width := 0.0
	for theme: Dictionary in _themes:
		var width := clampf(270.0+20.0*str(theme.name).length(),310.0,390.0)
		widths.append(width)
		total_width += width
	var gap := 14.0
	var available := 1284.0-gap*maxi(0,_themes.size()-1)
	var fit := minf(1.0,available/maxf(1.0,total_width))
	var x := 86.0
	for index in range(_themes.size()):
		var theme: Dictionary = _themes[index]
		var progress := _theme_progress(str(theme.id))
		var caption := "%s  %d / %d" % [str(theme.name),progress.x,progress.y]
		var width := widths[index]*fit
		var tab := Ui.button(_canvas,caption,Rect2(x,14,width,52),_font,select_theme.bind(str(theme.id)))
		tab.name = "ThemeTab_"+str(theme.id)
		ControllerUi.set_tab_selected(tab,_theme_id==str(theme.id))
		tab.clip_text = true
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.tooltip_text = caption
		ControllerUi.decorate(tab)
		x += width+gap

func _filtered_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _all_ids:
		if str(_definition(id).get("theme","")) != _theme_id: continue
		if _owned_only and not _is_owned(id): continue
		result.append(id)
	return result

func _theme_progress(theme_id: String) -> Vector2i:
	var owned := 0
	var total := 0
	for id in _all_ids:
		if str(_definition(id).get("theme","")) != theme_id: continue
		total += 1
		if _is_owned(id): owned += 1
	return Vector2i(owned,total)

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var ratio := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	_canvas.scale = Vector2.ONE*ratio
	_canvas.position = (size-DESIGN*ratio)*0.5

class BookPaper extends Control:
	func _draw() -> void:
		# Dark warm-violet paper lets the independent cream card faces lead.
		# Keep the cloth cover, leaf geometry and sewn gold rings unchanged.
		for layer in range(3,-1,-1):
			var offset := float(layer)*3.0
			for x in [72.0,900.0]:
				var rect := Rect2(x-offset*0.6,82+offset*0.6,808+offset,738+offset)
				draw_style_box(Ui.plate(Color("#473c53").lightened(float(3-layer)*0.025),Color("#6b5976"),1),rect)
		for x in [72.0,900.0]:
			draw_style_box(Ui.plate(Color("#594c63"),Color("#826d8b"),2),Rect2(x,82,808,738))
			draw_style_box(Ui.plate(Color.TRANSPARENT,Color("#73617b"),1),Rect2(x+10,92,788,718))
			# Sparse paper fibers are fixed geometry, with no animated texture noise.
			for line in range(18):
				var start := Vector2(x+18+float((line*73)%750),102+float((line*43)%680))
				draw_line(start,start+Vector2(14+float(line%5)*3,0.5),Color(0.65,0.56,0.69,0.08),1,true)
			for corner in [Vector2(x+19,99),Vector2(x+789,99),Vector2(x+19,803),Vector2(x+789,803)]:
				var dx := 1.0 if corner.x<x+404 else -1.0
				var dy := 1.0 if corner.y<450 else -1.0
				draw_line(corner,corner+Vector2(dx*28,0),Color("#8e7894"),1,true)
				draw_line(corner,corner+Vector2(0,dy*28),Color("#8e7894"),1,true)
		draw_rect(Rect2(881,89,18,725),Color("#3b3145"))
		draw_rect(Rect2(886,88,5,727),Color("#302738"))
		for y in [164.0,310.0,580.0,738.0]:
			draw_circle(Vector2(880,y+3),5,Color("#8b6656"))
			draw_circle(Vector2(900,y+3),5,Color("#8b6656"))
			draw_arc(Vector2(890,y+4),13,PI,TAU,18,Color("#8d6447"),6,true)
			draw_arc(Vector2(890,y+2),13,PI,TAU,18,Color("#e4c081"),4,true)
