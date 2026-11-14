extends RefCounted
## Display-only focus and independent input hints. Native GUI owns all input.

const WorkshopSkin = preload("res://scripts/workshop_skin.gd")
const DECORATION_NAME := "ControllerDecoration"
const BUTTON_PROMPT_NAME := "ControllerButtonPrompt"
const FOCUS_COLOR := Color("#fff0bc")
const FOCUS_FILL := Color("#a45879")
const INK := Color("#fff3de")
const FACE_TONES := {"A":"#6ee39a","B":"#ff7886","X":"#82bfff","Y":"#ffe18a"}
const ICON_HEIGHT := 32.0
static var _device := "keyboard"
static var _pointer_active := false
static var _icons: Dictionary = {}

static func decorate(button: Button, binding: String = "") -> void:
	if button == null: return
	var decoration := button.get_node_or_null(DECORATION_NAME) as ButtonDecoration
	if decoration == null:
		decoration = ButtonDecoration.new()
		decoration.name = DECORATION_NAME
		button.add_child(decoration)
		decoration.configure(button)
	decoration.binding = binding
	button.set_meta("controller_binding",binding)
	decoration.set_input_device(_device)
	decoration.set_pointer_active(_pointer_active)

static func set_tab_selected(button: Button, selected: bool) -> void:
	if button == null: return
	button.set_meta("controller_tab",true)
	button.set_meta("controller_tab_selected",selected)
	var decoration := button.get_node_or_null(DECORATION_NAME) as ButtonDecoration
	if decoration == null:
		decorate(button)
		decoration = button.get_node_or_null(DECORATION_NAME) as ButtonDecoration
	decoration.set_tab_selected(selected)

static func button_prompt(button: Button, binding: String, device: String) -> void:
	if button == null: return
	var prompt := button.get_node_or_null(BUTTON_PROMPT_NAME) as ButtonPrompt
	if prompt == null:
		prompt = ButtonPrompt.new()
		prompt.name = BUTTON_PROMPT_NAME
		button.add_child(prompt)
		prompt.configure(button)
	prompt.binding = binding
	prompt.set_input_device(device)

static func hints(items: Array, device: String = "keyboard") -> Control:
	var item := HintBar.new()
	item.name = "ControllerHints"
	item.set_items(items)
	item.set_input_device(device)
	return item

static func legend(binding: String, label: String) -> Control:
	var item := hints([{"binding":binding,"label":label}],_device)
	item.name = "ControllerLegend_"+binding.replace("/","_")
	return item

static func _normalize_device(device: String) -> String:
	return "joypad" if device.to_lower() in ["joypad","xbox","controller"] else "keyboard"

static func set_device(root: Node, device: String) -> void:
	if root == null: return
	_device = _normalize_device(device)
	root.set_meta("controller_device",_device)
	if root is ButtonDecoration or root is ButtonPrompt or root is HintBar: root.set_input_device(_device)
	for child in root.get_children(): set_device(child,_device)

static func set_pointer_active(root: Node, active: bool) -> void:
	if root == null: return
	_pointer_active = active
	if root is ButtonDecoration: root.set_pointer_active(active)
	for child in root.get_children(): set_pointer_active(child,active)

static func _display_binding(item: Dictionary, device: String) -> String:
	var binding := str(item.get("binding",""))
	if device=="joypad": return str(item.get("joypad_binding",binding))
	if item.has("keyboard_binding"): return str(item.keyboard_binding)
	match binding:
		"A": return "Enter"
		"B","Start": return "Esc"
		"Stick","Dpad","DPad": return "Tab"
		"Left/Right","Up/Down","Enter","Esc","Tab","Space": return binding
	# A controller shortcut with no PC route must not advertise a fictitious key.
	return ""

static func _glyph_width(binding: String) -> int:
	return 48 if binding in ["LB","RB","LT","RT","Start","Enter","Esc","Tab","Space","Backspace","Dpad","DPad","DpadHorizontal"] else 32

static func _icon_texture(binding: String, device: String, _focused: bool = false, _generic: bool = false) -> Texture2D:
	if binding.is_empty(): return null
	var key := device+":"+binding
	if _icons.has(key): return _icons[key]
	var width := 0
	var shapes := ""
	var tokens := PackedStringArray(["DpadHorizontal"]) if device=="joypad" and binding=="Left/Right" else binding.split("/",false)
	for token: String in tokens:
		if width>0: width += 6
		var shape := _glyph_svg(token,device,width)
		if shape.is_empty(): continue
		shapes += shape
		width += _glyph_width(token)
	if shapes.is_empty(): return null
	var source := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='32' viewBox='0 0 %d 32'>%s</svg>"%[width,width,shapes]
	var picture := Image.new()
	if picture.load_svg_from_string(source)!=OK: return null
	var result := ImageTexture.create_from_image(picture)
	_icons[key] = result
	return result

static func _glyph_svg(binding: String, device: String, x: int) -> String:
	var body := ""
	var cap := "<path d='M4 2H%dL%d 5V27L%d 30H4L1 27V5Z' fill='#211b31' stroke='#fff3de' stroke-width='2'/>"
	if device=="keyboard":
		var width := _glyph_width(binding)
		body = cap%[width-4,width-1,width-4]
		var strokes := {
			"Enter":"M35 9V17H12M18 11L12 17L18 23",
			"Esc":"M15 11H9V21H15M9 16H14M26 11H20V16H26V21H20M38 11H32V21H38",
			"Tab":"M10 11H35M29 6L35 11L29 16M37 6V16M37 22H12M18 17L12 22L18 27M10 17V27",
			"Space":"M9 12V21H39V12",
			"Backspace":"M19 9H39V23H19L11 16ZM25 12L33 20M33 12L25 20",
			"Left":"M22 16H10M16 10L10 16L16 22",
			"Right":"M10 16H22M16 10L22 16L16 22",
			"Up":"M16 22V10M10 16L16 10L22 16",
			"Down":"M16 10V22M10 16L16 22L22 16",
			"Q":"M9 8H22V22H9ZM17 18L24 25",
			"E":"M23 8H10V24H23M10 16H21",
		}
		if not strokes.has(binding): return ""
		body += "<path d='%s' fill='none' stroke='#fff3de' stroke-width='2' stroke-linecap='square' stroke-linejoin='miter'/>"%strokes[binding]
	elif FACE_TONES.has(binding):
		var tone: String = FACE_TONES[binding]
		body = "<circle cx='16' cy='16' r='13.5' fill='%s' fill-opacity='.20' stroke='%s' stroke-width='2.5'/>"%[tone,tone]
		var strokes := {"A":"M10 22L16 10L22 22M12 18H20","B":"M11 9H17Q23 9 23 12.5Q23 16 17 16H11M17 16Q23 16 23 19.5Q23 23 17 23H11V9","X":"M10 10L22 22M22 10L10 22","Y":"M10 10L16 16L22 10M16 16V23"}
		body += "<path d='%s' fill='none' stroke='%s' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'/>"%[strokes[binding],tone]
	elif binding in ["LB","RB","LT","RT","Start"]:
		body = "<path d='M7 3H41L47 9V25L42 29H6L1 25V9Z' fill='#211b31' stroke='#fff3de' stroke-width='2'/>"
		if binding=="Start":
			body += "<path d='M16 11H32M16 16H32M16 21H32' fill='none' stroke='#fff3de' stroke-width='2.2'/>"
		else:
			var first := "M11 10V22H19" if binding.begins_with("L") else "M11 22V10H17Q22 10 22 13.5Q22 17 17 17H11M17 17L23 22"
			var second := "M28 10H33Q39 10 39 13Q39 16 33 16H28M33 16Q39 16 39 19Q39 22 33 22H28V10" if binding.ends_with("B") else "M27 10H40M33.5 10V22"
			body += "<path d='%s %s' fill='none' stroke='#fff3de' stroke-width='1.8' stroke-linecap='square'/>"%[first,second]
	elif binding=="Stick":
		body = "<circle cx='16' cy='21' r='9' fill='#211b31' stroke='#fff3de' stroke-width='2'/><circle cx='16' cy='21' r='5' fill='none' stroke='#776780' stroke-width='1.5'/><path d='M16 21L12 9' stroke='#fff3de' stroke-width='3.5'/><circle cx='12' cy='7' r='5' fill='#54445f' stroke='#fff3de' stroke-width='2'/>"
	elif binding=="DpadHorizontal":
		body = "<path d='M19 3H29V11H37V21H29V29H19V21H11V11H19Z' fill='#211b31' stroke='#776780' stroke-width='1.5'/><path d='M19 11H11V21H19M29 11H37V21H29' fill='none' stroke='#fff3de' stroke-width='2'/><path d='M17 12L13 16L17 20M31 12L35 16L31 20' fill='none' stroke='#fff3de' stroke-width='2'/><circle cx='24' cy='16' r='2' fill='#b5a5bc'/>"
	elif binding in ["Dpad","DPad"]:
		body = "<path d='M19 3H29V11H37V21H29V29H19V21H11V11H19Z' fill='#211b31' stroke='#fff3de' stroke-width='2'/>"
	elif binding in ["Left","Right","Up","Down"]:
		# Geometric direction badges work without relying on a font's arrows.
		var strokes := {"Left":"M23 16H9M16 9L9 16L16 23","Right":"M9 16H23M16 9L23 16L16 23","Up":"M16 23V9M9 16L16 9L23 16","Down":"M16 9V23M9 16L16 23L23 16"}
		body = "<path d='M4 2H28L31 5V27L28 30H4L1 27V5Z' fill='#211b31' stroke='#fff3de' stroke-width='2'/><path d='%s' fill='none' stroke='#fff3de' stroke-width='2.4'/>"%strokes[binding]
	return "<g transform='translate(%d 0)'>%s</g>"%[x,body] if not body.is_empty() else ""

class ButtonDecoration extends Control:
	var binding := ""
	var input_device := "keyboard"
	var pointer_active := false
	var _button: Button
	var _focus_fill := Color.TRANSPARENT
	var _pointer_styles_ready := false
	var _pointer_sync_pending := false
	var _hover_suppressed := false
	var _hover_styles: Dictionary = {}
	var _hover_colors: Dictionary = {}
	var _tab_styles: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		set_meta("controller_display_only",true)

	func _ready() -> void:
		# Defining _process enables it when entering the tree; only its native
		# focus owner needs to watch a possible disabled/text change.
		set_process(is_instance_valid(_button) and _button.has_focus())

	func configure(button: Button) -> void:
		_button = button
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The native focus skin changes independently of the pointer hover gate.
		# Icon, text, separation, padding and button geometry remain caller-owned.
		# Card hit targets and talent medallions keep their artwork visible.
		# Tabs own a separate persistent selection skin; their GUI focus is an outline.
		_set_focus_fill(FOCUS_FILL if _focus_fill_eligible() else Color.TRANSPARENT)
		button.focus_entered.connect(_on_focus_entered)
		button.focus_exited.connect(_on_focus_exited)
		button.resized.connect(queue_redraw)
		button.visibility_changed.connect(queue_redraw)
		button.draw.connect(queue_redraw)
		if button.has_focus(): _on_focus_entered()

	func _set_focus_fill(fill: Color) -> void:
		var skin := WorkshopSkin.plate(fill,FOCUS_COLOR,3)
		var original := _button.get_theme_stylebox("focus")
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			# -1 is automatic, whose resolved value depends on the style type.
			# Copy the actual margin before a flat skin becomes a texture skin.
			skin.set_content_margin(side,original.get_margin(side))
		_focus_fill = fill
		_button.add_theme_stylebox_override("focus",skin)
		queue_redraw()

	func _sync_focus_fill() -> void:
		var fill := FOCUS_FILL if not _button.disabled and _focus_fill_eligible() else Color.TRANSPARENT
		if fill!=_focus_fill: _set_focus_fill(fill)

	func _is_tab() -> bool:
		return is_instance_valid(_button) and bool(_button.get_meta("controller_tab",false))

	func _focus_fill_eligible() -> bool:
		return is_instance_valid(_button) and not _is_tab() and not _button.text.strip_edges().is_empty()

	func set_tab_selected(selected: bool) -> void:
		if not is_instance_valid(_button): return
		_button.set_meta("controller_tab",true)
		_button.set_meta("controller_tab_selected",selected)
		# Restore real hover skins before reading or replacing them. Otherwise a
		# keyboard/pad gate could become the next mouse-mode cache permanently.
		_restore_pointer_presentation()
		if _tab_styles.is_empty():
			for key: String in ["normal","hover","pressed","hover_pressed"]:
				_tab_styles[key] = _button.get_theme_stylebox(key).duplicate()
		var idle: StyleBox = _tab_styles["normal"]
		var idle_fill := _style_fill(idle)
		for key: String in _tab_styles:
			var original: StyleBox = _tab_styles[key]
			var skin: StyleBox
			if original is StyleBoxFlat and (selected or key in ["hover","hover_pressed"]):
				# Flat category tabs fill their original rect. Recolor their own
				# shape so selection cannot introduce a paper texture's inset.
				var flat := original.duplicate() as StyleBoxFlat
				flat.bg_color = FOCUS_FILL if selected else idle_fill
				flat.border_color = FOCUS_COLOR
				skin = flat
			elif selected:
				skin = WorkshopSkin.plate(FOCUS_FILL,FOCUS_COLOR,3)
			elif key in ["hover","hover_pressed"]:
				# Hover changes the edge, not the category's unselected face color.
				skin = WorkshopSkin.plate(idle_fill,FOCUS_COLOR,3)
			else:
				skin = original.duplicate() as StyleBox
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
				skin.set_content_margin(side,original.get_margin(side))
			_button.add_theme_stylebox_override(key,skin)
		_sync_focus_fill()
		_sync_pointer_presentation()
		_button.queue_redraw()
		queue_redraw()

	func _style_fill(style: StyleBox) -> Color:
		if style is StyleBoxFlat: return style.bg_color
		if style is StyleBoxTexture and style.texture!=null:
			var picture: Image = style.texture.get_image()
			if picture!=null and not picture.is_empty():
				if picture.is_compressed(): picture.decompress()
				return picture.get_pixel(floori(picture.get_width()*0.5),floori(picture.get_height()*0.5))
		return Color("#403354")

	func _on_focus_entered() -> void:
		set_process(true)
		_sync_focus_fill()
		queue_redraw()

	func _on_focus_exited() -> void:
		set_process(false)
		# The idle skin can retain its usual fill; native GUI no longer draws it.
		# This also restores it if focus leaves directly after re-enabling.
		var fill := FOCUS_FILL if _focus_fill_eligible() else Color.TRANSPARENT
		if fill!=_focus_fill: _set_focus_fill(fill)
		queue_redraw()

	func _process(_delta: float) -> void:
		if not is_instance_valid(_button) or not _button.has_focus():
			set_process(false)
			return
		_sync_focus_fill()

	func set_input_device(device: String) -> void:
		input_device = "joypad" if device.to_lower() in ["joypad","xbox","controller"] else "keyboard"
		queue_redraw()

	func set_pointer_active(active: bool) -> void:
		pointer_active = active
		if _pointer_styles_ready:
			_sync_pointer_presentation()
		elif not _pointer_sync_pending:
			# Factories may compact the caller's skins after decorate(). Capture
			# only after construction so their final content margins are retained.
			_pointer_sync_pending = true
			_sync_pointer_presentation.call_deferred()

	func _sync_pointer_presentation() -> void:
		_pointer_sync_pending = false
		if not is_instance_valid(_button): return
		_pointer_styles_ready = true
		if pointer_active:
			if not _hover_suppressed: return
			_restore_pointer_presentation()
		else:
			# Repeated keyboard/pad events must not cache the suppressed skins.
			if _hover_suppressed: return
			var replacements := {"hover":"normal","hover_pressed":"pressed"}
			for key: String in replacements:
				var original := _button.get_theme_stylebox(key)
				_hover_styles[key] = {"overridden":_button.has_theme_stylebox_override(key),"style":original.duplicate()}
				var replacement := _button.get_theme_stylebox(replacements[key]).duplicate() as StyleBox
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
					replacement.set_content_margin(side,original.get_margin(side))
				_button.add_theme_stylebox_override(key,replacement)
			for key: String in ["font_hover_color","font_hover_pressed_color"]:
				_hover_colors[key] = {"overridden":_button.has_theme_color_override(key),"color":_button.get_theme_color(key)}
				_button.add_theme_color_override(key,_button.get_theme_color("font_color"))
			_hover_suppressed = true
		_button.queue_redraw()
		queue_redraw()

	func _restore_pointer_presentation() -> void:
		if not _hover_suppressed: return
		for key: String in _hover_styles:
			var saved: Dictionary = _hover_styles[key]
			if bool(saved.overridden): _button.add_theme_stylebox_override(key,saved.style)
			else: _button.remove_theme_stylebox_override(key)
		for key: String in _hover_colors:
			var saved: Dictionary = _hover_colors[key]
			if bool(saved.overridden): _button.add_theme_color_override(key,saved.color)
			else: _button.remove_theme_color_override(key)
		_hover_styles.clear()
		_hover_colors.clear()
		_hover_suppressed = false

	func _draw() -> void:
		if not is_instance_valid(_button) or not _button.has_focus() or _button.disabled: return
		if _is_tab() and pointer_active: return
		var center := Vector2(12,size.y*0.5)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-3,-6),center+Vector2(4,0),center+Vector2(-3,6)]),FOCUS_COLOR)

	func get_presentation_state() -> Dictionary:
		var focused := is_instance_valid(_button) and _button.has_focus() and not _button.disabled
		var tab := _is_tab()
		var tab_selected := tab and bool(_button.get_meta("controller_tab_selected",false))
		var selection_visible := tab_selected and not _button.disabled and _button.is_visible_in_tree()
		var arrow_visible := focused and (not tab or not pointer_active)
		var text_rect := Rect2()
		var content := Rect2(Vector2.ZERO,size)
		var custom_prompts := false
		var external_icon := false
		if is_instance_valid(_button):
			var skin := _button.get_theme_stylebox("normal")
			content = Rect2(Vector2(skin.get_margin(SIDE_LEFT),skin.get_margin(SIDE_TOP)),_button.size-Vector2(skin.get_margin(SIDE_LEFT)+skin.get_margin(SIDE_RIGHT),skin.get_margin(SIDE_TOP)+skin.get_margin(SIDE_BOTTOM)))
			var px := _button.get_theme_font_size("font_size")
			var face := _button.get_theme_font("font")
			var text_size := face.get_string_size(_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
			text_rect = Rect2(Vector2((_button.size.x-text_size.x)*0.5,(_button.size.y-text_size.y)*0.5),text_size)
			external_icon = _button.icon!=null
			for child in _button.get_children():
				if str(child.name).begins_with("InputKey_"): custom_prompts = true
		return {"device":input_device,"pointer_active":pointer_active,"binding":binding,"icon_visible":false,"icon_rect":Rect2(),"text_rect":text_rect,"content_rect":content,"tab":tab,"tab_selected":tab_selected,"selection_visible":selection_visible,"selection_fill":FOCUS_FILL if tab_selected else Color.TRANSPARENT,"red_selection_visible":selection_visible,"focus_visible":focused,"arrow_visible":arrow_visible,"focus_color":FOCUS_COLOR,"focus_fill":_focus_fill if focused else Color.TRANSPARENT,"focus_fill_eligible":_focus_fill_eligible(),"red_focus_visible":focused and _focus_fill.a>0.0,"focus_watch_active":is_processing(),"focus_shape":"paper_cut","focus_layers":1,"confirm_visible":false,"custom_prompts_preserved":custom_prompts,"external_icon_preserved":external_icon,"captures_input":false,"uses_native_button_icon":false}

class ButtonPrompt extends Control:
	var binding := ""
	var input_device := "keyboard"
	var text_gap := 12.0
	var _button: Button

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process_input(false)
		set_process_unhandled_input(false)
		set_meta("controller_display_only",true)
		set_meta("controller_button_prompt",true)

	func configure(button: Button) -> void:
		_button = button
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.resized.connect(queue_redraw)
		button.visibility_changed.connect(queue_redraw)
		button.draw.connect(queue_redraw)

	func set_input_device(device: String) -> void:
		input_device = "joypad" if device.to_lower() in ["joypad","xbox","controller"] else "keyboard"
		queue_redraw()

	func get_presentation_state() -> Dictionary:
		var helper: Script = load("res://scripts/controller_ui.gd")
		var item := {"binding":binding}
		if is_instance_valid(_button) and _button.has_meta("controller_keyboard_binding"):
			item["keyboard_binding"] = str(_button.get_meta("controller_keyboard_binding"))
		var token: String = helper._display_binding(item,input_device)
		var texture: Texture2D = helper._icon_texture(token,input_device)
		var text_rect := Rect2()
		var icon_rect := Rect2()
		var content := Rect2(Vector2.ZERO,size)
		if is_instance_valid(_button):
			# The two explicit footer prompts follow the existing centered text.
			# No icon reservation, padding or native button content is changed.
			var skin := _button.get_theme_stylebox("normal")
			var left := skin.get_margin(SIDE_LEFT)
			var top := skin.get_margin(SIDE_TOP)
			content = Rect2(Vector2(left,top),_button.size-Vector2(left+skin.get_margin(SIDE_RIGHT),top+skin.get_margin(SIDE_BOTTOM)))
			var face := _button.get_theme_font("font")
			var px := _button.get_theme_font_size("font_size")
			var text_size := face.get_string_size(_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
			text_rect = Rect2(content.position+(content.size-text_size)*0.5,text_size)
			if texture!=null:
				var icon_size := Vector2(texture.get_width(),ICON_HEIGHT)
				icon_rect = Rect2(Vector2(text_rect.position.x-text_gap-icon_size.x,text_rect.get_center().y-ICON_HEIGHT*0.5),icon_size)
		return {"device":input_device,"binding":binding,"display_binding":token,"icon_visible":texture!=null and is_visible_in_tree(),"icon_rect":icon_rect,"text_rect":text_rect,"content_rect":content,"text_gap":text_gap,"placement":"before_text","captures_input":false,"focusable":false,"uses_native_button_icon":false}

	func _draw() -> void:
		var state := get_presentation_state()
		if not bool(state.icon_visible): return
		var helper: Script = load("res://scripts/controller_ui.gd")
		var texture: Texture2D = helper._icon_texture(str(state.display_binding),input_device)
		if texture!=null: draw_texture_rect(texture,state.icon_rect,false)

class HintBar extends Control:
	var input_device := "keyboard"
	var item_gap := 24.0
	var icon_gap := 10.0
	var row_gap := 12.0
	var _items: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process_input(false)
		set_process_unhandled_input(false)
		set_meta("controller_display_only",true)
		set_meta("controller_hint_bar",true)
		resized.connect(queue_redraw)

	func set_items(items: Array) -> void:
		_items.clear()
		for item in items:
			if item is Dictionary: _items.append(item.duplicate(true))
		queue_redraw()

	func set_input_device(device: String) -> void:
		input_device = "joypad" if device.to_lower() in ["joypad","xbox","controller"] else "keyboard"
		queue_redraw()

	func _presentation_items() -> Array[Dictionary]:
		var helper: Script = load("res://scripts/controller_ui.gd")
		var face := get_theme_font("font")
		var px := get_theme_font_size("font_size")
		if not has_theme_font_size_override("font_size"): px = 24
		var rows: Array[Array] = [[]]
		var widths: Array[float] = [0.0]
		var height := maxf(ICON_HEIGHT,face.get_height(px))
		var available := size.x if size.x>0 else INF
		for item in _items:
			var token: String = helper._display_binding(item,input_device)
			var texture: Texture2D = helper._icon_texture(token,input_device)
			if texture==null: continue
			var caption := str(item.get("label",""))
			var text_size := face.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
			var width := float(texture.get_width())+(icon_gap if not caption.is_empty() else 0.0)+text_size.x
			var row := rows.size()-1
			if widths[row]>0 and widths[row]+item_gap+width>available:
				rows.append([])
				widths.append(0.0)
				row += 1
			if widths[row]>0: widths[row] += item_gap
			rows[row].append({"binding":str(item.get("binding","")),"display_binding":token,"label":caption,"texture":texture,"width":width,"text_size":text_size,"font_size":px,"offset":widths[row]})
			widths[row] += width
		var output: Array[Dictionary] = []
		var full_height := rows.size()*height+maxi(0,rows.size()-1)*row_gap
		var top := maxf(0.0,(size.y-full_height)*0.5)
		for row in range(rows.size()):
			var left := maxf(0.0,(size.x-widths[row])*0.5)
			for item: Dictionary in rows[row]:
				var texture: Texture2D = item.texture
				var origin := Vector2(left+float(item.offset),top+row*(height+row_gap))
				item["group_rect"] = Rect2(origin,Vector2(item.width,height))
				item["icon_rect"] = Rect2(origin+Vector2(0,(height-ICON_HEIGHT)*0.5),Vector2(texture.get_width(),ICON_HEIGHT))
				item["text_rect"] = Rect2(origin+Vector2(texture.get_width()+(icon_gap if not str(item.label).is_empty() else 0.0),(height-item.text_size.y)*0.5),item.text_size)
				item["icon_visible"] = true
				output.append(item)
		return output

	func _draw() -> void:
		var face := get_theme_font("font")
		for item in _presentation_items():
			var icon_rect: Rect2 = item.icon_rect
			var text_rect: Rect2 = item.text_rect
			var px := int(item.font_size)
			draw_texture_rect(item.texture,icon_rect,false)
			draw_string(face,Vector2(text_rect.position.x,text_rect.position.y+face.get_ascent(px)),item.label,HORIZONTAL_ALIGNMENT_LEFT,-1,px,INK)

	func get_presentation_state() -> Dictionary:
		var items: Array[Dictionary] = []
		for item in _presentation_items():
			var state := item.duplicate()
			state.erase("texture")
			state.erase("offset")
			state.erase("width")
			items.append(state)
		return {"device":input_device,"items":items,"content_rect":Rect2(Vector2.ZERO,size),"icon_visible":not items.is_empty() and visible,"captures_input":false,"focusable":false,"independent":true}
