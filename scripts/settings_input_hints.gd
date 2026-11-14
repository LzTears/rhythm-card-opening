extends Control
## Device-specific settings legends. Presentation only: no input or simulation.
const Guide = preload("res://scripts/rhythm_hud.gd")
const Prompts = preload("res://scripts/battle_rhythm_overlay.gd")
const DESIGN_WIDTH := 760.0
const DESIGN_HEIGHT := 112.0
const KEY_SIZE := 32.0
const FONT_SIZE := 24
const FILL := Color("#211a35")
const ORDER := ["pata","pon","don","chaka"]
const CADENCE_TEXT := "120 BPM · 自由起手，连续四拍"
var input_device := "keyboard"
var _pixel: Font
var _body: Font

func _init() -> void:
	name = "SettingsInputHints"
	custom_minimum_size = Vector2(0,DESIGN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_meta("rhythm_tutorial_graphics",true)

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()

func configure(pixel: Font, body: Font, device: String) -> void:
	_pixel = pixel
	_body = body
	set_input_device(device)
	queue_redraw()

func set_input_device(value: String) -> void:
	if value not in ["keyboard","joypad"]: return
	input_device = value
	queue_redraw()

func _text_font() -> Font:
	return _pixel if _pixel!=null else (_body if _body!=null else ThemeDB.fallback_font)

func _glyph_font() -> Font:
	return _body if _body!=null else _text_font()

func _measure(value: String) -> float:
	return _text_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x

func _layout_state() -> Dictionary:
	var xbox := input_device=="joypad"
	var family := "Xbox" if xbox else "键盘"
	var glyphs: Dictionary = Prompts.XBOX_GLYPHS if xbox else Prompts.KEYBOARD_GLYPHS
	var prefix := Rect2(0,4,_measure(family),40)
	var x := prefix.end.x+18.0
	var groups: Array[Dictionary] = []
	for key: String in ORDER:
		var word: String = Guide.WORDS[key]
		var key_rect := Rect2(x,8,KEY_SIZE,KEY_SIZE)
		var label_rect := Rect2(key_rect.end.x+10.0,4,_measure(word),40)
		groups.append({"key":key,"label":word,"glyph":str(glyphs[key]),"shape":"circle" if xbox else "square","color":Guide.XBOX_TONES[key] if xbox else Guide.CREAM,"rect":key_rect,"label_rect":label_rect,"device":input_device,"visible":true})
		x = label_rect.end.x+22.0
	var first_width := x-22.0
	var cadence_rect := Rect2(0,64,_measure(CADENCE_TEXT),40)
	var pause_rect := Rect2(cadence_rect.end.x+16.0,68,52 if xbox else 48,32)
	var pause_label := Rect2(pause_rect.end.x+10.0,64,_measure("暂停"),40)
	var natural_width := maxf(first_width,pause_label.end.x)
	var available := minf(size.x,DESIGN_WIDTH) if size.x>0.0 else DESIGN_WIDTH
	var scale_value := minf(1.0,available/maxf(1.0,natural_width))
	var pause := {"action":"pause","binding":"Start" if xbox else "Esc","glyph":"menu" if xbox else "Esc","shape":"capsule" if xbox else "square","color":Guide.CREAM,"rect":pause_rect,"label":"暂停","label_rect":pause_label,"device":input_device,"visible":true}
	return {"device":input_device,"family":family,"prefix_rect":prefix,"drums":groups,"cadence_text":CADENCE_TEXT,"cadence_rect":cadence_rect,"pause":pause,"natural_width":natural_width,"available_width":available,"scale":scale_value,"content_rect":Rect2(0,4,natural_width*scale_value,100.0*scale_value)}

func _center(value: String, rect: Rect2, color: Color, glyph: bool = false) -> void:
	var face := _glyph_font() if glyph else _text_font()
	var width := face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x
	var at := Vector2(rect.get_center().x-width*0.5,rect.get_center().y+(face.get_ascent(FONT_SIZE)-face.get_descent(FONT_SIZE))*0.5)
	draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE,color)

func _keycap(prompt: Dictionary) -> void:
	# Same dark keys, cream arrows and Xbox tones as the battle guide and
	# inspector. Arrows are geometry, so no font glyph can become a box.
	var rect: Rect2 = prompt.rect
	var center := rect.get_center()
	var tone: Color = prompt.color
	if str(prompt.shape)=="circle":
		draw_circle(center,14.5,FILL,true,-1.0,true)
		draw_circle(center,14.5,tone,false,2.5,true)
	elif str(prompt.shape)=="capsule":
		var capsule := StyleBoxFlat.new()
		capsule.bg_color = FILL
		capsule.border_color = tone
		capsule.set_border_width_all(2)
		capsule.set_corner_radius_all(16)
		draw_style_box(capsule,rect.grow(-1.5))
		for offset: float in [-5.0,0.0,5.0]:
			draw_line(center+Vector2(-8,offset),center+Vector2(8,offset),tone,2.5,true)
		return
	else:
		draw_rect(rect.grow(-1.5),FILL)
		draw_rect(rect.grow(-1.5),tone,false,2.0)
	var glyph := str(prompt.glyph)
	var directions := {"←":Vector2.LEFT,"→":Vector2.RIGHT,"↓":Vector2.DOWN,"↑":Vector2.UP}
	if directions.has(glyph):
		var direction: Vector2 = directions[glyph]
		var cross := Vector2(-direction.y,direction.x)
		draw_line(center-direction*7,center+direction*2,tone,3,true)
		draw_colored_polygon(PackedVector2Array([center+direction*8,center-direction+cross*6,center-direction-cross*6]),tone)
	else:
		_center(glyph,rect,tone,true)

func _draw() -> void:
	var state := _layout_state()
	var scale_value: float = state.scale
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*scale_value)
	_center(str(state.family),state.prefix_rect,Guide.MUTED)
	for prompt: Dictionary in state.drums:
		_keycap(prompt)
		_center(str(prompt.label),prompt.label_rect,Guide.MUTED)
	_center(CADENCE_TEXT,state.cadence_rect,Guide.MUTED)
	_keycap(state.pause)
	_center("暂停",state.pause.label_rect,Guide.MUTED)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func get_presentation_state() -> Dictionary:
	var state := _layout_state()
	state["layout"] = "settings_device_hints"
	state["input_device"] = input_device
	state["rows"] = 2
	state["drum_count"] = state.drums.size()
	state["pause_count"] = 1
	state["single_device_only"] = true
	state["draws_key_icons"] = true
	state["captures_input"] = false
	state["minimum_height"] = DESIGN_HEIGHT
	return state
