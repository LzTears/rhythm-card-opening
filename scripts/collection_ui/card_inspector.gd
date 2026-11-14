extends Control
## Full-screen inspection of an album card. The complete 2D card is rendered
## into a viewport texture on an actual 3D plane under a perspective camera.
## Illustration parallax remains a flat-art approximation; plane tilt is 3D.
signal closed
signal card_changed(id: String)

const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const CardView = preload("res://scripts/collection_ui/collection_card_view.gd")
const BattlePrompts = preload("res://scripts/battle_rhythm_overlay.gd")
const DESIGN := Vector2(1920,1080)
const MAX_PITCH := 10.0
const MAX_YAW := 14.0
const MANUAL_HOLD_SECONDS := 3.0
const JOY_DEADZONE := 0.18
const MOUSE_SWITCH_DISTANCE := 16.0
const MOUSE_SWITCH_WINDOW_MS := 250
var _profile: Dictionary = {}
var _ids: Array[String] = []
var _selected := 0
var _font: Font
var _card_font: Font
var _catalog: Script
var _canvas: Control
var _area: SubViewportContainer
var _world_view: SubViewport
var _card_view: SubViewport
var _front_card: Control
var _plane: MeshInstance3D
var _pivot: Node3D
var _camera: Camera3D
var _counter: Label
var _close_button: Button
var _flip_button: Button
var _pause_button: Button
var _hint_bar: Control
var _top_buttons: Dictionary = {}
var _button_hints: Dictionary = {}
var _input_device := "keyboard"
var _input_device_managed := false
var _active_joypad := -1
var _mouse_switch_motion := Vector2.ZERO
var _mouse_switch_started := 0
var _target := Vector2.ZERO
var _tilt := Vector2.ZERO
var _joy := Vector2.ZERO
var _paused := false
var _reduced := false
var _is_closing := false
var _show_back := false
var _display_time := 0.0
var _manual_hold := 0.0
var _pointer_inside := false
var _auto_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if size==Vector2.ZERO: size = get_viewport_rect().size
	resized.connect(_layout)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_ensure_visual()
	_refresh_card()
	_close_button.grab_focus()

func configure(profile: Dictionary, ids: Array[String], selected_id: String, font: Font = null, card_font: Font = null, reduced: bool = false) -> void:
	_profile = profile.duplicate(true)
	_ids = ids.duplicate()
	_selected = maxi(0,_ids.find(selected_id))
	_font = font
	_card_font = card_font if card_font!=null else font
	_reduced = reduced
	_show_back = false
	if ResourceLoader.exists("res://scripts/collection_catalog.gd"): _catalog = load("res://scripts/collection_catalog.gd")
	_ensure_visual()
	_refresh_card()

func select_offset(direction: int) -> void:
	if _ids.is_empty(): return
	_selected = posmod(_selected+direction,_ids.size())
	_show_back = false
	_target = Vector2.ZERO
	_tilt = Vector2.ZERO
	_manual_hold = 1.0
	_refresh_card()
	card_changed.emit(_ids[_selected])

func set_tilt(value: Vector2) -> void:
	if not is_finite(value.x) or not is_finite(value.y): return
	_target = value.clamp(-Vector2.ONE,Vector2.ONE)
	_manual_hold = MANUAL_HOLD_SECONDS

func recenter() -> void:
	_target = Vector2.ZERO
	_joy = Vector2.ZERO
	_manual_hold = 5.0

func turn_over() -> void:
	if _ids.is_empty() or not bool(_profile.get("album",{}).get(_ids[_selected],false)): return
	_show_back = not _show_back
	_front_card.set_face_down(_show_back)
	_flip_button.text = "正面" if _show_back else "翻面"

func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(_front_card): _front_card.set_paused(value)
	if is_instance_valid(_pause_button): _pause_button.text = "继续" if value else "暂停"

func toggle_pause() -> void:
	set_paused(not _paused)

func set_reduced(value: bool) -> void:
	_reduced = value
	if value and _auto_active: _target = Vector2.ZERO
	_auto_active = false
	if is_instance_valid(_front_card): _front_card.set_reduced(value)

## The owner can seed the device used to open this modal. Afterwards only
## supported, meaningful native input changes it; connecting alone does not.
## A host with an earlier input observer may instead own device selection.
func set_input_device_managed(value: bool) -> void:
	_input_device_managed = value
	if value and _input_device=="keyboard": _joy = Vector2.ZERO

func set_input_device(value: String) -> void:
	if value not in ["keyboard","joypad"]: return
	if value=="keyboard":
		_joy = Vector2.ZERO
		_active_joypad = -1
	else:
		_pointer_inside = false
		if _active_joypad<0:
			var connected := Input.get_connected_joypads()
			if not connected.is_empty(): _active_joypad = connected[0]
	_mouse_switch_motion = Vector2.ZERO
	_mouse_switch_started = 0
	if value==_input_device: return
	_input_device = value
	_refresh_input_hints()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if _input_device_managed: return
	if connected or _input_device!="joypad": return
	if device==_active_joypad or (_active_joypad<0 and Input.get_connected_joypads().is_empty()):
		set_input_device("keyboard")

func _consider_mouse_motion(event: InputEventMouseMotion) -> void:
	if _input_device!="joypad": return
	var now := Time.get_ticks_msec()
	if _mouse_switch_started==0 or now-_mouse_switch_started>MOUSE_SWITCH_WINDOW_MS:
		_mouse_switch_started = now
		_mouse_switch_motion = Vector2.ZERO
	# Measure in design pixels so both supported window sizes behave alike.
	_mouse_switch_motion += event.relative/maxf(_canvas.scale.x,0.01)
	if _mouse_switch_motion.length()>=MOUSE_SWITCH_DISTANCE:
		set_input_device("keyboard")

func close() -> void:
	if _is_closing: return
	_is_closing = true
	closed.emit()
	queue_free()

func _ensure_visual() -> void:
	if is_instance_valid(_canvas): return
	_canvas = Control.new()
	_canvas.name = "InspectorCanvas"
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.012,0.055,0.96)
	dim.size = DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(dim)
	_area = SubViewportContainer.new()
	_area.name = "PerspectiveCardViewport"
	_area.position = Vector2(420,76)
	_area.size = Vector2(1080,900)
	_area.stretch = true
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_area)
	_world_view = SubViewport.new()
	_world_view.size = Vector2i(1080,900)
	_world_view.own_world_3d = true
	_world_view.transparent_bg = true
	_world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_view.msaa_3d = Viewport.MSAA_4X
	_area.add_child(_world_view)
	var world := Node3D.new()
	_world_view.add_child(world)
	_camera = Camera3D.new()
	_camera.position = Vector3(0,0,6.6)
	_camera.fov = 39.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	world.add_child(_camera)
	_pivot = Node3D.new()
	_pivot.name = "RealPerspectivePivot"
	world.add_child(_pivot)
	_card_view = SubViewport.new()
	_card_view.name = "TypesetCard768x1024"
	_card_view.size = Vector2i(768,1024)
	_card_view.transparent_bg = true
	_card_view.disable_3d = true
	_card_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_card_view)
	_front_card = CardView.new()
	_front_card.size = Vector2(768,1024)
	_front_card.external_clock = true
	_card_view.add_child(_front_card)
	_front_card.set_projection_tilt(Vector2.ZERO)
	_plane = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3,4)
	_plane.mesh = quad
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.albedo_texture = _card_view.get_texture()
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_plane.material_override = surface
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_plane)
	_close_button = Ui.button(_canvas,"关闭",Rect2(1680,30,190,62),_font,close)
	_top_buttons["previous"] = Ui.button(_canvas,"←",Rect2(195,466,112,92),_font,select_offset.bind(-1))
	_top_buttons["next"] = Ui.button(_canvas,"→",Rect2(1613,466,112,92),_font,select_offset.bind(1))
	_top_buttons["recenter"] = Ui.button(_canvas,"回正",Rect2(52,30,150,62),_font,recenter)
	_flip_button = Ui.button(_canvas,"翻面",Rect2(220,30,150,62),_font,turn_over)
	_pause_button = Ui.button(_canvas,"暂停",Rect2(388,30,150,62),_font,toggle_pause)
	_top_buttons["flip"] = _flip_button
	_top_buttons["pause"] = _pause_button
	_top_buttons["close"] = _close_button
	_counter = Ui.label(_canvas,"",Rect2(760,25,400,56),_font,28,Ui.INK,true)
	_hint_bar = Control.new()
	_hint_bar.name = "CurrentDeviceHints"
	_hint_bar.position = Vector2(100,1009)
	_hint_bar.size = Vector2(1720,45)
	_hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_hint_bar)
	_refresh_input_hints()
	_layout()

func _prompt(glyph: String, shape: String = "square") -> Dictionary:
	var tones := {"A":BattlePrompts.XBOX_TONES.don,"B":BattlePrompts.XBOX_TONES.pon,"X":BattlePrompts.XBOX_TONES.pata,"Y":BattlePrompts.XBOX_TONES.chaka}
	return {"glyph":glyph,"shape":shape,"color":tones.get(glyph,Ui.INK) if shape=="circle" else Ui.INK,"device":_input_device,"family":"Xbox" if _input_device=="joypad" else "PC"}

func _input_prompt_groups() -> Array[Dictionary]:
	if _input_device=="joypad":
		return [
			{"action":"tilt","label":"转动","prefix":"","keys":[_prompt("L","stick")]},
			{"action":"navigate","label":"切卡","keys":[_prompt("LB","shoulder"),_prompt("RB","shoulder")]},
			{"action":"recenter","label":"回正","keys":[_prompt("A","circle")]},
			{"action":"flip","label":"翻面","keys":[_prompt("Y","circle")]},
			{"action":"pause","label":"暂停","keys":[_prompt("X","circle")]},
			{"action":"close","label":"关闭","keys":[_prompt("B","circle")]}
		]
	return [
		{"action":"tilt","label":"转动","prefix":"鼠标 / ","keys":[_prompt(BattlePrompts.KEYBOARD_GLYPHS.pata),_prompt(BattlePrompts.KEYBOARD_GLYPHS.chaka),_prompt(BattlePrompts.KEYBOARD_GLYPHS.don),_prompt(BattlePrompts.KEYBOARD_GLYPHS.pon)]},
		{"action":"navigate","label":"切卡","keys":[_prompt("A"),_prompt("D")]},
		{"action":"recenter","label":"回正","keys":[_prompt("Space")]},
		{"action":"flip","label":"翻面","keys":[_prompt("F")]},
		{"action":"pause","label":"暂停","keys":[_prompt("P")]},
		{"action":"close","label":"关闭","keys":[_prompt("Esc")]}
	]

func _prompt_width(prompt: Dictionary) -> float:
	if prompt.glyph=="Space": return 56.0
	if prompt.glyph=="Esc" or prompt.shape=="shoulder": return 48.0
	return 32.0

func _make_hint(parent: Control, prompt: Dictionary, rect: Rect2) -> Control:
	var hint := InputHintGlyph.new()
	hint.name = "InputKey_"+str(prompt.glyph)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = rect.position
	hint.size = rect.size
	hint.configure(prompt,_font)
	parent.add_child(hint)
	return hint

func _refresh_input_hints() -> void:
	if not is_instance_valid(_hint_bar): return
	var groups := _input_prompt_groups()
	var top := {}
	for group in groups:
		if group.action=="tilt": continue
		if group.action=="navigate":
			top["previous"] = group["keys"][0]
			top["next"] = group["keys"][1]
		else: top[group.action] = group["keys"][0]
	for action in top:
		var button: Button = _top_buttons[action]
		var prompt: Dictionary = top[action]
		var width := _prompt_width(prompt)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for style_name in ["normal","hover","pressed","disabled","focus"]:
			var style := button.get_theme_stylebox(style_name).duplicate() as StyleBox
			style.content_margin_left = 12
			style.content_margin_right = width+20
			button.add_theme_stylebox_override(style_name,style)
		if not _button_hints.has(action):
			_button_hints[action] = _make_hint(button,prompt,Rect2())
		var hint: Control = _button_hints[action]
		hint.position = Vector2(button.size.x-width-12,(button.size.y-32)*0.5)
		hint.size = Vector2(width,32)
		hint.configure(prompt,_font)
		hint.modulate.a = 0.42 if button.disabled else 1.0
		button.tooltip_text = str(prompt.family)+" · "+str(prompt.glyph)
	for child in _hint_bar.get_children():
		_hint_bar.remove_child(child)
		child.queue_free()
	var face := _font if _font!=null else ThemeDB.fallback_font
	var widths: Array[float] = []
	var total := 0.0
	for group in groups:
		var width := face.get_string_size(str(group.get("prefix","")),HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		for prompt in group["keys"]: width += _prompt_width(prompt)+6
		width += 6+face.get_string_size(str(group.label),HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		widths.append(width)
		total += width
	var gap := 38.0
	total += gap*float(groups.size()-1)
	var x := (_hint_bar.size.x-total)*0.5
	for index in range(groups.size()):
		var group: Dictionary = groups[index]
		var prefix := str(group.get("prefix",""))
		var prefix_width := face.get_string_size(prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		if not prefix.is_empty(): Ui.label(_hint_bar,prefix,Rect2(x,0,prefix_width,45),_font,24,Ui.MUTED)
		var key_x := x+prefix_width
		for prompt in group["keys"]:
			var width := _prompt_width(prompt)
			_make_hint(_hint_bar,prompt,Rect2(key_x,6.5,width,32))
			key_x += width+6
		Ui.label(_hint_bar,str(group.label),Rect2(key_x+6,0,widths[index]-(key_x-x)-6,45),_font,24,Ui.MUTED)
		x += widths[index]+gap

func _refresh_card() -> void:
	if not is_instance_valid(_front_card): return
	var definition: Dictionary = {}
	var owned := false
	if not _ids.is_empty():
		var id := _ids[_selected]
		if _catalog!=null: definition = _catalog.card_definition(id)
		owned = bool(_profile.get("album",{}).get(id,false))
	_front_card.configure(definition,owned,_card_font,false)
	_front_card.set_face_down(_show_back or not owned)
	_front_card.external_clock = true
	_front_card.set_reduced(_reduced)
	_front_card.set_projection_tilt(Vector2.ZERO)
	_front_card.set_paused(_paused)
	_pivot.rotation = Vector3.ZERO
	_camera.position.z = 6.6
	_flip_button.disabled = not owned
	_flip_button.text = "正面" if _show_back else "翻面"
	_counter.text = "%d / %d"%[_selected+1,_ids.size()] if not _ids.is_empty() else "0 / 0"
	for item in _canvas.find_children("*","Control",true,false):
		if _font!=null and (item is Label or item is Button):
			item.add_theme_font_override("font",_font)
			if _font.get_meta("interface_pixel",false):
				var px: int = item.get_theme_font_size("font_size")
				item.add_theme_font_size_override("font_size",maxi(12,roundi(float(px)/12.0)*12))
	_refresh_input_hints()

func advance_time(delta: float) -> void:
	if _paused or delta<=0 or not is_finite(delta) or not is_instance_valid(_pivot): return
	if not _reduced: _display_time += delta
	# A stationary pointer over the card keeps its manual pose. Once the
	# pointer leaves, the short hold lets the automatic display return gently.
	var desired := _target
	_auto_active = not _reduced and not _pointer_inside and _manual_hold<=0 and _joy.length()<=JOY_DEADZONE
	if _auto_active:
		desired = Vector2(sin(_display_time*0.53)*0.28,cos(_display_time*0.41)*0.20)
	if _joy.length()>JOY_DEADZONE:
		desired = _joy
		_manual_hold = MANUAL_HOLD_SECONDS
	_manual_hold = maxf(0.0,_manual_hold-delta)
	_tilt = _tilt.lerp(desired,1.0-exp(-delta*10.5))
	_pivot.rotation_degrees = Vector3(-_tilt.y*MAX_PITCH,_tilt.x*MAX_YAW,0)
	_fit_camera_to_card()
	_front_card.set_projection_tilt(_tilt)
	_front_card.advance_time(delta)

func _fit_camera_to_card() -> void:
	# Keep every corner inside the viewport at the full supported tilt, rather
	# than cropping the near upper/lower corner with a fixed close-up camera.
	var tangent_y := tan(deg_to_rad(_camera.fov)*0.5)
	var tangent_x := tangent_y*float(_world_view.size.x)/float(_world_view.size.y)
	var distance := 6.6
	for corner in [Vector3(-1.5,-2,0),Vector3(1.5,-2,0),Vector3(1.5,2,0),Vector3(-1.5,2,0)]:
		var point: Vector3 = _pivot.transform*corner
		var needed := maxf(absf(point.x)/(tangent_x*0.94),absf(point.y)/(tangent_y*0.94))+point.z
		distance = maxf(distance,needed)
	_camera.position.z = distance

func _process(delta: float) -> void:
	if is_visible_in_tree() and DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:
		advance_time(delta)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _is_closing: return
	if event is InputEventMouseMotion:
		if not _input_device_managed: _consider_mouse_motion(event)
		if _input_device=="joypad": return
		var pointer: Vector2 = event.position
		var was_inside := _pointer_inside
		_pointer_inside = _area.get_global_rect().has_point(pointer)
		if _pointer_inside:
			set_tilt((pointer-_area.global_position)/_area.get_global_rect().size*2.0-Vector2.ONE)
		elif was_inside:
			_manual_hold = MANUAL_HOLD_SECONDS
	if event is InputEventMouseButton and event.pressed:
		if not _input_device_managed: set_input_device("keyboard")
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]: return
		if _input_device_managed and _input_device!="joypad":
			_joy = Vector2.ZERO
			get_viewport().set_input_as_handled()
			return
		var value: float = float(event.axis_value) if absf(float(event.axis_value))>JOY_DEADZONE else 0.0
		if value!=0.0:
			if not _input_device_managed: set_input_device("joypad")
			_active_joypad = event.device
		if event.axis==JOY_AXIS_LEFT_X: _joy.x = value
		if event.axis==JOY_AXIS_LEFT_Y: _joy.y = value
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index not in [JOY_BUTTON_B,JOY_BUTTON_A,JOY_BUTTON_Y,JOY_BUTTON_X,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]: return
		if not _input_device_managed: set_input_device("joypad")
		_active_joypad = event.device
		match event.button_index:
			JOY_BUTTON_B: close()
			JOY_BUTTON_A: recenter()
			JOY_BUTTON_Y: turn_over()
			JOY_BUTTON_X: toggle_pause()
			JOY_BUTTON_LEFT_SHOULDER: select_offset(-1)
			JOY_BUTTON_RIGHT_SHOULDER: select_offset(1)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed:
		if event.keycode not in [KEY_ESCAPE,KEY_A,KEY_D,KEY_TAB,KEY_SPACE,KEY_F,KEY_P,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: return
		if not _input_device_managed: set_input_device("keyboard")
		match event.keycode:
			KEY_ESCAPE: close()
			KEY_A: select_offset(-1)
			KEY_D, KEY_TAB: select_offset(1)
			KEY_SPACE: recenter()
			KEY_F: turn_over()
			KEY_P: toggle_pause()
			KEY_LEFT: set_tilt(_target+Vector2.LEFT*0.20)
			KEY_RIGHT: set_tilt(_target+Vector2.RIGHT*0.20)
			KEY_UP: set_tilt(_target+Vector2.UP*0.20)
			KEY_DOWN: set_tilt(_target+Vector2.DOWN*0.20)
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not _area.get_global_rect().has_point(get_global_mouse_position()): close()

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var ratio := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	_canvas.scale = Vector2.ONE*ratio
	_canvas.position = (size-DESIGN*ratio)*0.5

func get_inspector_state() -> Dictionary:
	var selected_id := _ids[_selected] if not _ids.is_empty() else ""
	var exposed := bool(_profile.get("album",{}).get(selected_id,false))
	var button_prompts := {}
	for action in _button_hints:
		var hint: Control = _button_hints[action]
		button_prompts[action] = hint.prompt.duplicate(true)
	return {"selected_index":_selected,"selected_id":selected_id if exposed else "","count":_ids.size(),"projection":"perspective_camera_3d","mesh_size":[3,4],"rotation_degrees":[_pivot.rotation_degrees.x,_pivot.rotation_degrees.y,_pivot.rotation_degrees.z] if is_instance_valid(_pivot) else [0,0,0],"tilt":_tilt,"paused":_paused,"reduced":_reduced,"surface":_front_card.get_presentation_state() if is_instance_valid(_front_card) else {},"source_art_depth":"flat_uv_approximation","typeset_viewport":[768,1024],"visible":visible,"max_pitch":MAX_PITCH,"max_yaw":MAX_YAW,"idle_display":_auto_active,"display_time":_display_time,"manual_hold":_manual_hold,"pointer_priority":_pointer_inside,"input_device":_input_device,"active_joypad":_active_joypad,"input_prompts":_input_prompt_groups(),"button_prompts":button_prompts}

## Same PC square / Xbox colored-ring vocabulary as the battle HUD. Arrows
## are drawn geometrically, so the selected interface font cannot lose them.
class InputHintGlyph extends Control:
	var prompt: Dictionary = {}
	var face: Font
	func configure(value: Dictionary, font: Font) -> void:
		prompt = value.duplicate(true)
		face = font if font!=null else ThemeDB.fallback_font
		queue_redraw()
	func _draw() -> void:
		if prompt.is_empty() or face==null: return
		var tone: Color = prompt.color
		var center := size*0.5
		var box := Rect2(Vector2.ONE*1.5,size-Vector2.ONE*3)
		var glyph := str(prompt.glyph)
		if prompt.shape=="circle":
			draw_circle(center,14.5,Color("#211a35"),true,-1.0,true)
			draw_circle(center,14.5,tone,false,2.5,true)
		elif prompt.shape=="stick":
			draw_circle(center,14.5,Color("#211a35"),true,-1.0,true)
			draw_circle(center,14.5,tone,false,2.0,true)
			draw_line(center+Vector2(-8,8),center+Vector2(8,8),tone,2,true)
			draw_line(center+Vector2(0,7),center+Vector2(0,1),tone,2,true)
			draw_circle(center-Vector2(0,3),5,tone,false,2,true)
			return
		else:
			draw_rect(box,Color("#211a35"))
			draw_rect(box,tone,false,2.0)
		var directions := {"←":Vector2.LEFT,"→":Vector2.RIGHT,"↓":Vector2.DOWN,"↑":Vector2.UP}
		if directions.has(glyph):
			var direction: Vector2 = directions[glyph]
			var cross := Vector2(-direction.y,direction.x)
			draw_line(center-direction*7,center+direction*2,tone,3,true)
			draw_colored_polygon(PackedVector2Array([center+direction*8,center-direction+cross*6,center-direction-cross*6]),tone)
		else:
			var px := 12 if glyph=="Space" else 24
			var baseline := center+Vector2(-face.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x*0.5,(face.get_ascent(px)-face.get_descent(px))*0.5)
			draw_string(face,baseline,glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tone)
