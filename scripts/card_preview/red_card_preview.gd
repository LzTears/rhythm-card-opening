extends Control
## Independent visual review. No main scene, progression or SaveStore dependency.
const Card = preload("res://scripts/card_preview/holo_card_3d.gd")
const FONT = preload("res://assets/fonts/NotoSansCJKsc-Medium.otf")
const CARDS := [
	{"theme":"galaxy","name":"星系 · 黑洞","path":"res://docs/concepts/red-holo-v3/01-black-hole-red-holo.png"},
	{"theme":"digimon","name":"数码宝贝 · 奥米加兽","path":"res://docs/concepts/red-holo-v3/02-omegamon-red-holo.png"},
]
var card: Node3D
var view: SubViewport
var card_area: SubViewportContainer
var selected := 0
var auto_enabled := true
var paused := false
var reduced := false
var joy_axis := Vector2.ZERO
var title: Label
var pause_button: Button
var auto_check: CheckBox
var reduction_check: CheckBox
var strength_slider: HSlider
var status: Label
var manual_target := Vector2.ZERO

func _ready() -> void:
	get_window().title = "节拍开卡 · 红卡动态样卡"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1e1730")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label("红卡动态样卡",Rect2(48,26,1200,64),42,Color("#fff0cd"))
	_label("鼠标移入卡片查看反光与纵深 · 方向键／手柄左摇杆倾斜 · LB/RB 切卡",Rect2(48,96,1300,45),23,Color("#bfaecb"))
	var left := _panel(Rect2(48,180,330,530))
	_label("主题样卡",Rect2(24,22,280,48),27,Color("#fff0cd"),left)
	for index in range(CARDS.size()):
		var button := _button(str(CARDS[index].name),Rect2(22,94+index*90,286,66),left)
		button.pressed.connect(select_card.bind(index))
	_label("绝版 · 红\n3:4 收藏卡\n\n大面积全息镭射\n烫金浮雕反光\n插画纵深视差",Rect2(26,290,280,220),25,Color("#d8bfd0"),left)
	card_area = SubViewportContainer.new()
	card_area.position = Vector2(396,154)
	card_area.size = Vector2(1080,866)
	card_area.stretch = true
	card_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_area)
	view = SubViewport.new()
	view.size = Vector2i(1080,866)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	card_area.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0,0,7.0)
	camera.fov = 39.0
	camera.current = true
	world.add_child(camera)
	card = Card.new()
	world.add_child(card)
	var right := _panel(Rect2(1502,180,370,600))
	title = _label("",Rect2(24,18,322,84),27,Color("#fff0cd"),right)
	_label("镭射动态强度",Rect2(24,126,320,36),25,Color("#d8bfd0"),right)
	strength_slider = HSlider.new()
	strength_slider.position = Vector2(24,178)
	strength_slider.size = Vector2(322,38)
	strength_slider.min_value = 0
	strength_slider.max_value = 100
	strength_slider.value = 65
	right.add_child(strength_slider)
	strength_slider.value_changed.connect(func(value: float) -> void: card.set_holo_strength(value/100.0))
	auto_check = _check("自动展示",Vector2(20,244),right)
	auto_check.button_pressed = true
	auto_check.toggled.connect(func(value: bool) -> void: auto_enabled=value)
	reduction_check = _check("减少动态效果",Vector2(20,306),right)
	reduction_check.toggled.connect(func(value: bool) -> void: reduced=value; card.set_reduced(value))
	pause_button = _button("暂停动态",Rect2(22,394,326,60),right)
	pause_button.pressed.connect(toggle_pause)
	var reset := _button("回正卡片",Rect2(22,480,326,60),right)
	reset.pressed.connect(func() -> void:
		auto_check.button_pressed=false
		manual_target=Vector2.ZERO
		joy_axis=Vector2.ZERO
		card.set_tilt(Vector2.ZERO))
	status = _label("",Rect2(48,1014,1400,40),21,Color("#bfaecb"))
	select_card(0)

func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position=rect.position; panel.size=rect.size
	var skin := StyleBoxFlat.new()
	skin.bg_color=Color("#2c223e"); skin.border_color=Color("#8e719c")
	skin.set_border_width_all(2); skin.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",skin)
	add_child(panel)
	return panel

func _label(text: String, rect: Rect2, font_size: int, color: Color, parent: Node=null) -> Label:
	var label := Label.new()
	label.text=text; label.position=rect.position; label.size=rect.size
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	(parent if parent!=null else self).add_child(label)
	return label

func _button(text: String, rect: Rect2, parent: Node) -> Button:
	var button := Button.new()
	button.text=text; button.position=rect.position; button.size=rect.size
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",23)
	parent.add_child(button)
	return button

func _check(text: String, at: Vector2, parent: Node) -> CheckBox:
	var check := CheckBox.new()
	check.text=text; check.position=at; check.size=Vector2(330,48)
	check.add_theme_font_override("font",FONT)
	check.add_theme_font_size_override("font_size",24)
	parent.add_child(check)
	return check

func select_card(index: int) -> void:
	selected=posmod(index,CARDS.size())
	var row: Dictionary=CARDS[selected]
	var loaded: bool=card.load_card(row.path,row.theme)
	card.set_holo_strength(strength_slider.value/100.0)
	card.set_paused(paused)
	card.set_reduced(reduced)
	title.text=str(row.name)
	status.text="移动鼠标或摇杆，观察不同角度的反光。" if loaded else "样卡图片读取失败。"

func toggle_pause() -> void:
	paused=not paused
	card.set_paused(paused)
	pause_button.text="继续动态" if paused else "暂停动态"

func _input(event: InputEvent) -> void:
	if card==null: return
	if event is InputEventMouseMotion and card_area.get_global_rect().has_point(event.position):
		manual_target=((event.position-card_area.global_position)/card_area.size-Vector2.ONE*.5)*2.0
		card.set_auto_rotate(false)
		card.set_tilt(manual_target)
	if event is InputEventJoypadMotion:
		if event.axis==JOY_AXIS_LEFT_X: joy_axis.x=event.axis_value
		if event.axis==JOY_AXIS_LEFT_Y: joy_axis.y=event.axis_value
		if joy_axis.length()>.12:
			auto_check.button_pressed=false
			manual_target=joy_axis
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_RIGHT_SHOULDER: select_card(selected+1)
		if event.button_index==JOY_BUTTON_LEFT_SHOULDER: select_card(selected-1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: toggle_pause()
		if event.keycode==KEY_TAB: select_card(selected+1); get_viewport().set_input_as_handled()
		var direction: Vector2={KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}.get(event.keycode,Vector2.ZERO)
		if direction!=Vector2.ZERO:
			auto_check.button_pressed=false
			manual_target=(manual_target+direction*.25).clamp(-Vector2.ONE,Vector2.ONE)

func _process(delta: float) -> void:
	if card==null: return
	var mouse_in_card := card_area.get_global_rect().has_point(get_global_mouse_position())
	card.set_auto_rotate(auto_enabled and not mouse_in_card)
	if not auto_enabled or mouse_in_card: card.set_tilt(manual_target)
	card.advance(delta)

func get_debug_state() -> Dictionary:
	return {"selected":selected,"title":title.text,"auto":auto_enabled,"paused":paused,"reduced":reduced,"card":card.get_presentation_state(),"independent_preview":true,"card_area":card_area.get_global_rect()}
