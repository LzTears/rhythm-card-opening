extends Control
## Presentation only. Definitions/states are supplied by Rules/Progression;
## selecting a node never purchases it or changes the profile.

signal node_selected(node_id: String)
signal purchase_requested(node_id: String, expected_level: int)
signal view_state_changed(state: Dictionary)

const WorkshopSkin = preload("res://scripts/workshop_skin.gd")
const ControllerUI = preload("res://scripts/controller_ui.gd")
const Progression = preload("res://scripts/progression.gd")
const PackRules = preload("res://scripts/pack_rules.gd")
const INK := Color("#fff0cc")
const MUTED := Color("#b6a5c5")
const PAPER := Color("#29213f")
const GOLD := Color("#f1d7a4")
const TREE_SIZE := Vector2(1540,940)
const COLUMN_STEP := 220.0
const ROW_STEP := 176.0
const NODE_SIZE := Vector2(72,72)
const DETAIL_WIDTH := 540.0
const MIN_ZOOM := .65
const MAX_ZOOM := 1.6
const NODE_LAYOUT := {
	"TAL-P":{"position":Vector2(90,442),"branch":"combat","glyph":"power"},
	"TAL-GATHER":{"position":Vector2(290,90),"branch":"charge","glyph":"left"},
	"TAL-E":{"position":Vector2(510,90),"branch":"charge","glyph":"right"},
	"TAL-MERGE":{"position":Vector2(730,90),"branch":"charge","glyph":"gem"},
	"TAL-FEVER":{"position":Vector2(950,90),"branch":"combat","glyph":"speed"},
	"TAL-ENERGY":{"position":Vector2(1170,90),"branch":"combat","glyph":"charge"},
	"TAL-START-ENERGY":{"position":Vector2(1390,90),"branch":"combat","glyph":"first"},
	"TAL-ECHO":{"position":Vector2(290,266),"branch":"charge","glyph":"steady"},
	"TAL-START-CIRCLE":{"position":Vector2(510,266),"branch":"charge","glyph":"first"},
	"TAL-G1":{"position":Vector2(290,442),"branch":"harvest","glyph":"coin"},
	"TAL-PERFECT":{"position":Vector2(510,442),"branch":"harvest","glyph":"steady"},
	"TAL-COMBO":{"position":Vector2(730,442),"branch":"harvest","glyph":"clock"},
	"TAL-OUTSIDE":{"position":Vector2(950,442),"branch":"harvest","glyph":"crack"},
	"TAL-C":{"position":Vector2(290,618),"branch":"supply","glyph":"capacity"},
	"TAL-DIRECTED":{"position":Vector2(510,618),"branch":"supply","glyph":"box"},
	"TAL-BIAS":{"position":Vector2(730,618),"branch":"supply","glyph":"rarity"},
	"TAL-R":{"position":Vector2(290,794),"branch":"supply","glyph":"rarity"},
	"TAL-DISCOVERY":{"position":Vector2(510,794),"branch":"supply","glyph":"cards"},
	"TAL-DUPLICATE":{"position":Vector2(730,794),"branch":"harvest","glyph":"coin"},
	"TAL-IDENTIFY":{"position":Vector2(950,794),"branch":"supply","glyph":"rarity"},
}
# These are presentation waypoints only. Rules supply all actual edges and
# levels; removing a prerequisite removes its line without a UI code change.
const EDGE_ROUTES := {
	"TAL-P>TAL-GATHER":[Vector2(195,442),Vector2(195,90)],
	"TAL-P>TAL-ECHO":[Vector2(195,442),Vector2(195,266)],
	"TAL-P>TAL-C":[Vector2(195,442),Vector2(195,618)],
	"TAL-P>TAL-R":[Vector2(195,442),Vector2(195,794)],
}
const BRANCH_COLORS := {
	"supply":Color("#f5bc63"), "charge":Color("#60e4ef"),
	"combat":Color("#ff8e76"), "harvest":Color("#86e68b"), "root":Color("#ffd575"),
}
# Original small pixel glyphs, drawn as integer rectangles. No emoji/font icons.
const GLYPHS := {
	"root":[".....22.....","....2332....","...233332...","..23344332..",".2334444332.","233444444332","233444444332",".2334444332.","..23344332..","...233332...","....2332....",".....22....."],
	"power":[".....22.....","....2332....","...233332...","..23333332..",".2333333332.","....2332....","....2332....","....2332....","....2332....","....2332....","....2222....","............"],
	"box":["............","...222222...","..23333332..",".2334444332.","222222222222","233332233332","233332233332","233332233332","233332233332","233333333332","222222222222","............"],
	"capacity":["...222222...","...233332...","...233332...","...222222...",".2222222222.",".2333333332.",".2333333332.",".2222222222.","222222222222","233333333332","233333333332","222222222222"],
	"clock":["....2222....","..22333322..",".2334444332.",".2344244432.","233442444332","233442444332","233442224332","233444444332",".2344444432.",".2334444332.","..22333322..","....2222...."],
	"gem":["...222222...","..23344332..",".2334444332.","233444444332","233222222332",".2323333232.","..23233232..","...232232...","....2332....",".....22.....","............","............"],
	"left":["............","....22......","...2332.....","..23332.....",".2333322222.","233333333332","233333333332",".2333322222.","..23332.....","...2332.....","....22......","............"],
	"right":["............","......22....",".....2332...",".....23332..",".2222233332.","233333333332","233333333332",".2222233332.",".....23332..",".....2332...","......22....","............"],
	"boss":["..22....22..",".2332..2332.","233332233332","233333333332",".2333333332.",".2342332432.",".2342332432.",".2333333332.","..23222232..","..23333332..","...222222...","............"],
	"charge":["....2222....","..22333322..",".2334444332.",".2344224432.","233442444332","233422224332","233444244332","233442244332",".2344244432.",".2334444332.","..22333322..","....2222...."],
	"steady":[".....22.....",".....22.....","..22222222..","..23333332..","..23422432..","222342243222","222342243222","..23422432..","..23333332..","..22222222..",".....22.....",".....22....."],
	"move":[".........22.","........2332","2222...23332",".3332.233332","..3332333332","...33333222.","..2333332...",".233323332..","23332.23332.","2332...2222.",".22.........","............"],
	"first":["....22......","...2332.....","..233332....",".23333332...","2333333332..","222233332222","...233323332","..23332.2332",".23332...232",".2222.....22","............","............"],
	"crack":["222222222222","233332333332","233323333332","233323333332","233332333332","233332233332","233333233332","233332333332","233323333332","233233333332","233333333332","222222222222"],
	"speed":["............",".22222222...","..23333332..","...233332...","....2332....",".2222332222.","..23333332..","...233332...","....2332....",".....22.....","............","............"],
	"coin":["....2222....","..22333322..",".2334444332.",".2344224432.","233423444332","233442244332","233444244332","233442344332",".2344224432.",".2334444332.","..22333322..","....2222...."],
	"cards":["...22222222.","...23333332.",".2222222232.",".2333333232.",".2344443232.",".2342243232.",".2342243232.",".2344443232.",".2333333222.",".23333332...",".22222222...","............"],
	"rarity":[".....22.....","....2332....",".2222332222.",".2333333332.","..23344332..","...234432...","..23344332..",".2333333332.",".2222332222.","....2332....",".....22.....","............"],
}

class PixelGlyph extends Control:
	var pixels: Array = []
	var accent := Color.WHITE
	var muted := false
	var pixel_scale := 3
	func _draw() -> void:
		var palette: Dictionary = {"2":Color("#6f577e"),"3":accent,"4":Color("#fff4d7")}
		for y in pixels.size():
			var row: String = str(pixels[y])
			for x in row.length():
				var cell: String = row.substr(x,1)
				if not palette.has(cell): continue
				var color: Color = palette[cell]
				if muted: color=color.lerp(Color("#94839f"),.66)
				draw_rect(Rect2(x*pixel_scale,y*pixel_scale,pixel_scale,pixel_scale),color)

class TreeCanvas extends Control:
	var edges: Array[Dictionary] = []
	var selected := ""
	func _draw() -> void:
		# Leave the paper field quiet behind the prerequisite silhouettes.
		for edge in edges:
			var points: PackedVector2Array = edge.points
			var color := Color("#f3b54c") if bool(edge.met) else Color("#80688e")
			var emphasized: bool=str(edge.target)==selected or str(edge.source)==selected
			if emphasized: color=Color("#ffe4a8") if bool(edge.met) else Color("#c3accb")
			var width := 4.0 if emphasized else 3.0
			for index in range(points.size()-1):
				var start: Vector2=points[index]
				var finish: Vector2=points[index+1]
				draw_line(start,finish,Color("#1c142a"),width+4,false)
				if bool(edge.implemented):
					draw_line(start,finish,color,width,false)
				else:
					var direction: Vector2=(finish-start).normalized()
					var distance: float=start.distance_to(finish)
					var cursor := 0.0
					while cursor<distance:
						draw_line(start+direction*cursor,start+direction*minf(cursor+8,distance),color,width,false)
						cursor+=14.0

var _definitions: Dictionary = {}
var _positions: Dictionary = {}
var _states: Dictionary = {}
var _nodes: Dictionary = {}
var _buy_buttons: Dictionary = {}
var _button_factory: Callable
var _style_factory: Callable
var _selected_id := ""
var _scroll: ScrollContainer
var _canvas: TreeCanvas
var _surface: Control
var _reset_button: Button
var _zoom := 1.0
var _pan := Vector2.ZERO
var _pending_view: Dictionary = {}
var _view_ready := false
var _drag_button := MOUSE_BUTTON_NONE
var _drag_last := Vector2.ZERO
var _detail: Panel
var _detail_scroll: ScrollContainer
var _heading: Label
var _balance: Label
var _detail_name: Label
var _detail_status: Label
var _detail_effect: Label
var _detail_requirements: Label
var _detail_cost: Label
var _detail_note: Label
var _display_font: Font
var _purchase_feedback: Label
var _feedback_tween: Tween
var _feedback_error := ""
var _input_source := "keyboard"

func set_display_font(value: Font) -> void:
	_display_font=value

func set_input_source(value: String) -> void:
	_input_source=value

func configure(definitions: Array, states: Array, balance: int, selected_id: String, button_factory: Callable, style_factory: Callable, view_state: Dictionary = {}) -> void:
	_button_factory=button_factory
	_style_factory=style_factory
	_pending_view=view_state.duplicate()
	for definition: Dictionary in definitions: _definitions[str(definition.id)]=definition
	for state: Dictionary in states: _states[str(state.id)]=state
	_build_layout(definitions)
	custom_minimum_size=Vector2(0,582)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_heading=_text(self,"成长之路 · 天赋树",36,INK,Rect2(0,0,600,42),true)
	_balance=_text(self,"金币  %d" % balance,24,GOLD,Rect2(750,4,370,40),true)
	_balance.name="TalentBalance"
	_balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_scroll=ScrollContainer.new()
	_scroll.name="TalentScroll"
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus=false
	_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(_scroll)
	_surface=Control.new()
	_surface.name="TalentViewport"
	_surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_surface.mouse_filter=Control.MOUSE_FILTER_STOP
	_surface.focus_mode=Control.FOCUS_ALL
	_surface.clip_contents=true
	var plot_background := ColorRect.new()
	plot_background.color=Color("#251d36")
	plot_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plot_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_surface.add_child(plot_background)
	_scroll.add_child(_surface)
	_surface.gui_input.connect(_tree_gui_input.bind(_surface,true))
	_canvas=TreeCanvas.new()
	_canvas.name="TalentTreeCanvas"
	_canvas.custom_minimum_size=TREE_SIZE
	_canvas.size=TREE_SIZE
	_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_canvas)
	_reset_button=_button_factory.call(self,"复位","TalentResetView",reset_view,false)
	for button: Button in [_reset_button]:
		button.custom_minimum_size=Vector2(160,54)
		button.size=Vector2(160,54)
		button.add_theme_font_size_override("font_size",24)
	_reset_button.tooltip_text="回到起点，保持选中节点"
	_build_branches()
	_build_edges(definitions)
	for state: Dictionary in states: _build_node(state)
	_build_detail(states)
	_wire_focus_navigation()
	resized.connect(_layout)
	_layout()
	_select(selected_id if _states.has(selected_id) else ("TAL-P" if _states.has("TAL-P") else str(states[0].id)))
	set_meta("talent_node_count",_states.size())
	set_meta("talent_edges",_canvas.edges.duplicate(true))
	set_meta("presentation_only",true)
	set_meta("tree_layout","prerequisite_tree")

func _layout() -> void:
	if _scroll==null: return
	var extent := Vector2(maxf(size.x,1724.0),maxf(size.y,582.0))
	var tree_width: float=extent.x-DETAIL_WIDTH-20.0
	_scroll.position=Vector2(0,106)
	_scroll.size=Vector2(tree_width,extent.y-106)
	_surface.size=_scroll.size
	_reset_button.position=Vector2(tree_width-160,44)
	_balance.position.x=tree_width-350
	_balance.size.x=350
	_detail.position=Vector2(tree_width+20,0)
	_detail.size=Vector2(DETAIL_WIDTH,extent.y)
	_detail_scroll.size.y=maxf(266.0,extent.y-316.0)
	_detail_cost.position.y=extent.y-136.0
	for button in _buy_buttons.values(): button.position.y=extent.y-86.0
	if not _view_ready:
		_view_ready=true
		if _pending_view.get("pan") is Vector2 and _pending_view.get("zoom") is float and is_finite(float(_pending_view.zoom)) and _pending_view.pan.is_finite():
			_zoom=clampf(float(_pending_view.zoom),MIN_ZOOM,MAX_ZOOM)
			_pan=_pending_view.pan
			_apply_view()
		else:
			_initial_view()
	else:
		_apply_view()

func _build_branches() -> void:
	# Aligned rows and their real prerequisite lines define the branches.
	pass

func _build_layout(definitions: Array) -> void:
	_positions.clear()
	var extra := 0
	for definition: Dictionary in definitions:
		var node_id := str(definition.id)
		if definition.get("tree_position") is Vector2:
			_positions[node_id] = definition.tree_position
		elif NODE_LAYOUT.has(node_id):
			_positions[node_id] = NODE_LAYOUT[node_id].position
		else:
			# Additional definitions remain visible; a designer may provide a
			# tree_position and edge_waypoints without adding branching code.
			_positions[node_id] = Vector2(90+float(extra%5)*250,500+float(extra/5)*140)
			extra += 1

func _build_edges(definitions: Array) -> void:
	# Positions are presentation choices; every edge/required level comes from Rules.
	for definition: Dictionary in definitions:
		var target_id: String=str(definition.id)
		if not _positions.has(target_id): continue
		var grouped: Dictionary = {}
		var groups := Progression.talent_requirement_groups(definition)
		for group_index in groups.size():
			var requirements: Dictionary = groups[group_index]
			for key: Variant in requirements:
				var source_id := str(key)
				if not _positions.has(source_id): continue
				var token := source_id+">"+target_id
				if not grouped.has(token): grouped[token] = {"source":source_id,"required_level":int(requirements[key]),"groups":[]}
				grouped[token].required_level = mini(int(grouped[token].required_level),int(requirements[key]))
				grouped[token].groups.append(group_index)
		for token: String in grouped:
			var requirement: Dictionary = grouped[token]
			var level := int(_states.get(requirement.source,{}).get("level",0))
			_canvas.edges.append({"source":requirement.source,"target":target_id,"required_level":requirement.required_level,
				"groups":requirement.groups,"alternative":groups.size()>1,
				"met":level>=int(requirement.required_level),"implemented":bool(definition.get("implemented",false)),
				"points":_edge_points(str(requirement.source),target_id)})

func _edge_points(source_id: String, target_id: String) -> PackedVector2Array:
	var source: Vector2=_positions[source_id]
	var target: Vector2=_positions[target_id]
	var points := PackedVector2Array([source])
	var overrides: Dictionary = _definitions.get(target_id,{}).get("edge_waypoints",{})
	var waypoints: Array = overrides.get(source_id,EDGE_ROUTES.get(source_id+">"+target_id,[]))
	for point: Vector2 in waypoints: points.append(point)
	points.append(target)
	var source_radius: float=NODE_SIZE.x*.5
	var target_radius: float=NODE_SIZE.x*.5
	points[0]+=(points[1]-points[0]).normalized()*(source_radius+4.0)
	var last: int=points.size()-1
	points[last]-=(points[last]-points[last-1]).normalized()*(target_radius+4.0)
	return points

func _build_node(state: Dictionary) -> void:
	var node_id: String=str(state.id)
	if not _positions.has(node_id): return
	var center: Vector2=_positions[node_id]
	var accent: Color=BRANCH_COLORS[_branch(node_id)]
	var diameter: float=84.0 if node_id=="TAL-ROOT" else NODE_SIZE.x
	var node_size := Vector2(diameter,diameter)
	var button: Button=_button_factory.call(_canvas,"","TalentNode_"+node_id.replace("-","_"),func() -> void: _select(node_id),false)
	button.position=center-node_size*.5
	button.custom_minimum_size=node_size
	button.size=node_size
	button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.tooltip_text="%s · LV%d/%d" % [state.name,state.get("display_level",state.level),state.get("display_max_level",state.max_level)]
	if bool(state.can_buy): button.tooltip_text+=" · 可升级"
	button.set_meta("talent_id",node_id)
	button.set_meta("talent_state",state.duplicate(true))
	button.set_meta("node_shape","circle")
	button.gui_input.connect(_tree_gui_input.bind(button,false))
	button.focus_entered.connect(_focus_node.bind(node_id))
	var glyph := PixelGlyph.new()
	glyph.position=Vector2((diameter-36.0)*.5,(diameter-36.0)*.5-4.0)
	glyph.size=Vector2(36,36)
	glyph.pixels=GLYPHS[_glyph(node_id)]
	glyph.accent=accent.lightened(.2)
	glyph.muted=not bool(state.implemented) or (int(state.level)==0 and str(state.status)=="prerequisite")
	glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)
	var level_panel := Panel.new()
	level_panel.position=Vector2(diameter-26.0,diameter-26.0)
	level_panel.size=Vector2(34,34)
	level_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	level_panel.add_theme_stylebox_override("panel",_circle_frame(Color("#3a2c4b"),Color("#e3cce0"),2,34))
	button.add_child(level_panel)
	var level_label: Label=_text(level_panel,str(state.get("display_level",state.level)),26,Color("#fff6d7"),Rect2(0,-3,34,40))
	level_label.name="TalentLevel_"+node_id.replace("-","_")
	level_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var title_font := get_theme_font("font")
	var title_width := maxf(140.0,ceilf(title_font.get_string_size(str(state.name),HORIZONTAL_ALIGNMENT_LEFT,-1,26).x)+8.0)
	var name_rect := Rect2(center.x-title_width*.5,center.y+diameter*.5+12.0,title_width,34)
	var side_title := bool(NODE_LAYOUT.get(node_id,{}).get("side_title",false))
	if side_title: name_rect=Rect2(center+Vector2(50,-22),Vector2(180,34))
	var name_backing := ColorRect.new()
	name_backing.position=name_rect.position
	name_backing.size=name_rect.size
	name_backing.color=Color("#251d36")
	name_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(name_backing)
	var title: Label=_text(_canvas,str(state.name),26,INK,name_rect)
	title.name="TalentName_"+node_id.replace("-","_")
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color",PAPER)
	title.add_theme_constant_override("outline_size",1)
	var status_rect := Rect2(center.x-80,center.y+diameter*.5+48,160,32)
	if side_title: status_rect=Rect2(center+Vector2(50,12),Vector2(180,28))
	var status_label := _text(_canvas,_node_status_text(state),26,_status_color(state),status_rect)
	status_label.name="TalentStatus_"+node_id.replace("-","_")
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible=bool(state.can_buy)
	_nodes[node_id]={"button":button,"state":state,"accent":accent,"diameter":diameter,"title":title,"status_label":status_label}

func _build_detail(states: Array) -> void:
	_detail=Panel.new()
	_detail.name="TalentDetails"
	_detail.add_theme_stylebox_override("panel",_style_factory.call(PAPER,Color("#c3accb"),0,2))
	add_child(_detail)
	_detail_name=_text(_detail,"",36,INK,Rect2(24,24,492,48),true)
	_detail_status=_text(_detail,"",26,MUTED,Rect2(24,80,492,32))
	var rule := ColorRect.new()
	rule.color=Color("#947c9f")
	rule.position=Vector2(24,128)
	rule.size=Vector2(492,2)
	rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_detail.add_child(rule)
	# Core values and the one parent share a compact body. The real price and
	# purchase button remain fixed outside it.
	_detail_scroll=ScrollContainer.new()
	_detail_scroll.name="TalentDetailScroll"
	_detail_scroll.position=Vector2(24,148)
	_detail_scroll.size=Vector2(492,266)
	_detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(_detail_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	_detail_scroll.add_child(content)
	_detail_effect=_text(content,"",26,INK,Rect2())
	_detail_effect.name="TalentEffectComparison"
	_detail_effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_detail_requirements=_text(content,"",26,MUTED,Rect2())
	_detail_requirements.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_detail_note=_text(content,"",26,MUTED,Rect2())
	_detail_note.visible=false
	_detail_cost=_text(_detail,"",26,GOLD,Rect2(24,446,492,40))
	for state: Dictionary in states:
		var node_id: String=str(state.id)
		var expected_level: int=int(state.level)
		var button: Button=_button_factory.call(_detail,_buy_caption(state),"BuyTalent_"+node_id.replace("-","_"),func() -> void: purchase_requested.emit(node_id,expected_level),true)
		button.position=Vector2(24,496)
		button.size=Vector2(492,64)
		button.custom_minimum_size=Vector2(492,64)
		button.add_theme_font_size_override("font_size",24)
		# Prerequisite and balance failures are answered by the real transaction.
		# Keep these buttons clickable so Main can show its returned reason.
		button.disabled=not bool(state.implemented) or str(state.status) in ["maxed","in_run"]
		# Main propagates future device changes through ControllerUI.set_device;
		# initialize from the factory's current device without another input router.
		ControllerUI.button_prompt(button,"A",str(button.get_meta("controller_device","keyboard")))
		var prompt := button.get_node(ControllerUI.BUTTON_PROMPT_NAME) as Control
		prompt.visible=not button.disabled
		button.visible=false
		button.set_meta("talent_id",node_id)
		button.set_meta("expected_level",expected_level)
		button.set_meta("cost",int(state.cost))
		button.set_meta("status",str(state.status))
		_buy_buttons[node_id]=button

func _select(node_id: String) -> void:
	if not _states.has(node_id): return
	_selected_id=node_id
	_detail_scroll.scroll_vertical=0
	set_meta("selected_talent_id",node_id)
	var state: Dictionary=_states[node_id]
	_detail_name.text=str(state.name)
	_detail_status.text="可升级" if bool(state.can_buy) else ""
	_detail_status.visible=bool(state.can_buy)
	_detail_status.add_theme_color_override("font_color",_status_color(state))
	_detail_effect.text=_effect_comparison(state)
	var groups := Progression.talent_requirement_groups(state)
	var requirements: Array[String] = []
	for group: Dictionary in groups:
		for key: Variant in group:
			var parent_id := str(key)
			var parent_name := str(_definitions.get(parent_id,{}).get("name",parent_id))
			var required_level := int(group[key])
			requirements.append("%s LV.%d" % [parent_name,required_level])
	_detail_requirements.text="无" if requirements.is_empty() else requirements[0]
	_detail_cost.text="" if str(state.status)=="maxed" else "升级至 LV%d  ·  %d 金币" % [state.get("next_display_level",state.next_level),state.cost]
	_detail_note.text=""
	for key: Variant in _buy_buttons: _buy_buttons[key].visible=str(key)==node_id
	for key: Variant in _nodes:
		var entry: Dictionary=_nodes[key]
		var button: Button=entry.button
		var selected: bool=str(key)==node_id
		var owned: bool=int(entry.state.level)>0
		var fill := Color("#514054") if owned else Color("#332640")
		if bool(entry.state.can_buy): fill=Color("#554354")
		if not bool(entry.state.implemented): fill=Color("#332c3e")
		var border: Color=GOLD if owned else (entry.accent if bool(entry.state.can_buy) else Color("#9985a5"))
		if selected: border=GOLD
		button.add_theme_stylebox_override("normal",_circle_frame(fill,border,4 if selected else 2,float(entry.diameter)))
		button.add_theme_stylebox_override("hover",_circle_frame(fill.lightened(.08),entry.accent,4,float(entry.diameter)))
		button.add_theme_stylebox_override("pressed",_circle_frame(Color("#67495f"),GOLD,4,float(entry.diameter)))
		button.add_theme_stylebox_override("focus",_circle_frame(Color.TRANSPARENT,Color("#e8b4bd"),2,float(entry.diameter)))
		entry.title.add_theme_color_override("font_color",GOLD if selected else (INK if bool(entry.state.implemented) else MUTED))
		entry.title.add_theme_color_override("font_outline_color",PAPER)
	_canvas.selected=node_id
	_canvas.queue_redraw()
	node_selected.emit(node_id)

func select_node(node_id: String) -> void:
	_select(node_id)

func ensure_controller_focus() -> void:
	if not is_visible_in_tree() or _nodes.is_empty(): return
	var node_id := _selected_id
	if not _nodes.has(node_id): node_id="TAL-P" if _nodes.has("TAL-P") else str(_nodes.keys()[0])
	var button: Button=_nodes[node_id].button
	_ensure_node_visible(node_id)
	# Mouse panning and keyboard navigation may leave focus on the viewport,
	# reset button or detail. Resume at the actual selected talent each time.
	button.grab_focus()

func activate_selected() -> bool:
	if not is_visible_in_tree() or not _states.has(_selected_id): return false
	var purchase := _buy_buttons.get(_selected_id) as Button
	if purchase==null or purchase.disabled: return false
	# Reuse the GUI transaction contract, including expected-level protection.
	# Main/Progression alone owns upgrades and prerequisite/balance feedback.
	purchase_requested.emit(_selected_id,int(purchase.get_meta("expected_level",0)))
	return true

func get_controller_state() -> Dictionary:
	var focused := get_viewport().gui_get_focus_owner()
	var node_focused := false
	if _nodes.has(_selected_id): node_focused=focused==_nodes[_selected_id].button
	var purchase := _buy_buttons.get(_selected_id) as Button
	var prompt: Node=purchase.get_node_or_null(ControllerUI.BUTTON_PROMPT_NAME) if purchase!=null else null
	return {"selected":_selected_id,"focus_name":str(focused.name) if focused!=null else "",
		"focus_path":str(focused.get_path()) if focused!=null else "",
		"focus_talent_id":str(focused.get_meta("talent_id","")) if focused!=null else "",
		"node_focused":node_focused,"purchase_focused":purchase!=null and focused==purchase,
		"can_activate":is_visible_in_tree() and purchase!=null and not purchase.disabled,
		"purchase_caption":purchase.text if purchase!=null else "",
		"purchase_disabled":purchase==null or purchase.disabled,
		"purchase_prompt":prompt.call("get_presentation_state") if prompt!=null else {}}

func scroll_to_node(node_id: String) -> void:
	if _positions.has(node_id):
		_pan=_surface.size*.5-(_positions[node_id]+Vector2(0,20))*_zoom
		_apply_view()

func get_view_state() -> Dictionary:
	return {"zoom":_zoom,"pan":_pan}

func _initial_view() -> void:
	# Fit all five rows in the production viewport. At 1280px the 24px labels
	# stay at least 12 physical pixels, with all five routes initially visible.
	_zoom=clampf((_surface.size.y-16.0)/910.0,.75,.9)
	_pan=Vector2(12,8)
	_apply_view()

func fit_view() -> void:
	if _surface==null: return
	_zoom=clampf(minf((_surface.size.x-16.0)/TREE_SIZE.x,(_surface.size.y-16.0)/TREE_SIZE.y),MIN_ZOOM,MAX_ZOOM)
	_pan=(_surface.size-TREE_SIZE*_zoom)*.5
	_apply_view()

func reset_view() -> void:
	_initial_view()

func _apply_view() -> void:
	var scaled: Vector2=TREE_SIZE*_zoom
	for axis in 2:
		_pan[axis]=clampf(_pan[axis],80.0-scaled[axis],_surface.size[axis]-80.0)
	_canvas.scale=Vector2.ONE*_zoom
	_canvas.position=_pan
	var state: Dictionary=get_view_state()
	set_meta("view_state",state)
	view_state_changed.emit(state)

func _zoom_at(point: Vector2, amount: float) -> void:
	var next_zoom: float=clampf(_zoom*amount,MIN_ZOOM,MAX_ZOOM)
	var anchor: Vector2=(point-_pan)/_zoom
	_zoom=next_zoom
	_pan=point-anchor*_zoom
	_apply_view()

func _tree_gui_input(event: InputEvent, source: Control, allow_left: bool) -> void:
	if not event is InputEventMouseButton: return
	var mouse: InputEventMouseButton=event
	var point: Vector2=_surface.get_global_transform_with_canvas().affine_inverse()*(source.get_global_transform_with_canvas()*mouse.position)
	if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(point,1.12 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12)
		source.accept_event()
	elif mouse.pressed and (mouse.button_index==MOUSE_BUTTON_MIDDLE or (allow_left and mouse.button_index==MOUSE_BUTTON_LEFT)):
		_drag_button=mouse.button_index
		_drag_last=point
		_surface.grab_focus()
		source.accept_event()

func _input(event: InputEvent) -> void:
	if _drag_button==MOUSE_BUTTON_NONE: return
	if event is InputEventMouseMotion:
		var point: Vector2=_surface.get_global_transform_with_canvas().affine_inverse()*event.position
		_pan+=point-_drag_last
		_drag_last=point
		_apply_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==_drag_button and not event.pressed:
		_drag_button=MOUSE_BUTTON_NONE
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_drag_button=MOUSE_BUTTON_NONE

func _ensure_node_visible(node_id: String) -> void:
	if not _view_ready or not _positions.has(node_id): return
	var node_rect := Rect2((_positions[node_id]-Vector2(100,52))*_zoom+_pan,Vector2(200,168)*_zoom)
	if _nodes.has(node_id):
		var entry: Dictionary=_nodes[node_id]
		var bounds: Rect2=entry.button.get_rect().merge(entry.title.get_rect()).merge(entry.status_label.get_rect())
		node_rect=Rect2(bounds.position*_zoom+_pan,bounds.size*_zoom).grow(8)
	var available := Rect2(Vector2(8,8),_surface.size-Vector2(16,16))
	var adjustment := Vector2.ZERO
	for axis in 2:
		if node_rect.position[axis]<available.position[axis]: adjustment[axis]=available.position[axis]-node_rect.position[axis]
		elif node_rect.end[axis]>available.end[axis]: adjustment[axis]=available.end[axis]-node_rect.end[axis]
	if adjustment!=Vector2.ZERO:
		_pan+=adjustment
		_apply_view()

func _focus_node(node_id: String) -> void:
	# Pointer focus is only hover feedback; a completed click selects explicitly.
	if _input_source=="mouse": return
	_ensure_node_visible(node_id)
	_select(node_id)

func _wire_focus_navigation() -> void:
	var ids: Array = _nodes.keys()
	for index in range(ids.size()):
		var node_id := str(ids[index])
		var button: Button=_nodes[node_id].button
		button.focus_mode=Control.FOCUS_ALL
		var next_button: Button=_nodes[str(ids[(index+1)%ids.size()])].button
		var purchase: Button=_buy_buttons[node_id]
		button.focus_next=button.get_path_to(purchase if not purchase.disabled else next_button)
		button.focus_previous=button.get_path_to(_nodes[str(ids[posmod(index-1,ids.size())])].button)
		for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			var direction: Vector2={SIDE_LEFT:Vector2.LEFT,SIDE_TOP:Vector2.UP,SIDE_RIGHT:Vector2.RIGHT,SIDE_BOTTOM:Vector2.DOWN}[side]
			var best_id := ""
			var best_score := INF
			for other: String in _nodes:
				if other==node_id: continue
				var delta: Vector2=_positions[other]-_positions[node_id]
				var forward := delta.dot(direction)
				if forward<=0: continue
				var sideways := absf(delta.cross(direction))
				var score := delta.length()+sideways*2.0
				if score<best_score:
					best_score=score
					best_id=other
			if not best_id.is_empty(): button.set_focus_neighbor(side,button.get_path_to(_nodes[best_id].button))
			elif side==SIDE_RIGHT and not purchase.disabled: button.focus_neighbor_right=button.get_path_to(purchase)
			else: button.set_focus_neighbor(side,NodePath("."))
		var buy: Button=_buy_buttons[node_id]
		buy.focus_neighbor_left=buy.get_path_to(button)
		buy.focus_previous=buy.get_path_to(button)
		buy.focus_next=buy.get_path_to(next_button)
		buy.focus_neighbor_top=buy.get_path_to(button)
		buy.focus_neighbor_bottom=buy.get_path_to(button)
		buy.focus_neighbor_right=NodePath(".")

func _node_status_text(state: Dictionary) -> String:
	return "可升级" if bool(state.can_buy) else ""

func _effect_comparison(state: Dictionary) -> String:
	var level := int(state.level)
	var current := _effect_at_level(str(state.id),level)
	var heading := "当前 LV%d\n%s" % [int(state.get("display_level",level)),current]
	if level>=int(state.max_level): return heading+"\n\n下一级：已达到上限"
	return heading+"\n\n下一级 LV%d\n%s" % [int(state.get("next_display_level",level+1)),_effect_at_level(str(state.id),level+1)]

func _effect_at_level(node_id: String, level: int) -> String:
	# Compile the actual run options rather than repeating talent formulas here.
	var talents: Dictionary = {}
	for id: String in _states: talents[id]=int(_states[id].level)
	talents[node_id]=level
	var options := PackRules.build_run_options(talents)
	if options.is_empty(): return str(_definitions.get(node_id,{}).get("effect",""))
	match node_id:
		"TAL-P": return "伤害 %d" % int(options.shot_damage)
		"TAL-G1": return "包金币＋%d%%\n圈内×1.2" % int(options.coin_bonus_percent)
		"TAL-C": return "桌面容量 %d包" % int(options.capacity)
		"TAL-GATHER": return "圈外聚拢 %d包" % int(options.gather_count)
		"TAL-E": return "每拍扩圈＋%d%%\n最多12层" % roundi(float(options.expand_step)*100.0)
		"TAL-MERGE": return "%d合1" % int(options.merge_ratio)
		"TAL-R": return _spawn_distribution(options.spawn_weights)
		"TAL-FEVER": return "就绪门槛 Combo%d" % int(options.rhythm_fever_threshold)
		"TAL-PERFECT": return "Perfect击破金币＋%s%%" % _number(float(options.perfect_bonus_basis_points)/100.0)
		"TAL-COMBO": return "每5Combo金币＋%s%%\n最多＋%s%%（20Combo）" % [_number(float(options.combo_per_band_basis_points)/100.0),_number(float(options.combo_per_band_basis_points)*4.0/100.0)]
		"TAL-ECHO": return "断拍保留最多 %d层" % int(options.echo_retention_stacks)
		"TAL-ENERGY": return "满能 %d格" % int(options.rhythm_fever_energy_max)
		"TAL-BIAS": return "每高一阶，聚拢权重＋%s%%" % _number(float(options.gather_bias_level)*100.0/16.0)
		"TAL-START-CIRCLE": return "开局扩圈 %d层" % int(options.initial_expand_stacks)
		"TAL-START-ENERGY": return "开局能量 %d格" % int(options.initial_fever_energy)
		"TAL-DIRECTED": return "每轮圈内补给最多 %d包" % int(options.directed_refill_count)
		"TAL-OUTSIDE": return "圈外击破金币＋%s%%" % _number(float(options.outside_bonus_basis_points)/100.0)
		"TAL-DISCOVERY": return "未收录卡权重＋%d%%" % (20*int(options.discovery_level))
		"TAL-DUPLICATE": return "重复兑换金币＋%d%%" % int(options.duplicate_bonus_percent)
		"TAL-IDENTIFY": return "紫／金／红抽取权重＋%d%%" % (4*int(options.identify_level))
	return str(_definitions.get(node_id,{}).get("effect",""))

func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _spawn_distribution(weights: Array) -> String:
	var names := ["白","绿","紫","金","红"]
	var total := 0
	for weight: Variant in weights: total+=int(weight)
	var entries: Array[String] = []
	for index in mini(weights.size(),names.size()):
		var percent := ("%.2f" % (float(weights[index])*100.0/maxi(1,total))).trim_suffix("0").trim_suffix("0").trim_suffix(".")
		entries.append("%s%s%%" % [names[index],percent])
	return "  ".join(entries.slice(0,3))+"\n"+"  ".join(entries.slice(3,5))

func show_purchase_feedback(error: String) -> void:
	# Only reasons returned by Progression are presented. Full nodes never emit
	# a purchase request, and unrelated errors keep Main's existing error flow.
	if error not in ["prerequisite","insufficient_coins"]: return
	if _feedback_tween!=null and _feedback_tween.is_valid(): _feedback_tween.kill()
	if is_instance_valid(_purchase_feedback): _purchase_feedback.queue_free()
	_feedback_error=error
	_purchase_feedback=_text(_detail,"请先购买前置天赋" if error=="prerequisite" else "金币不足",26,Color("#ffe4a8"),Rect2(24,_detail.size.y-202,492,44))
	_purchase_feedback.name="TalentPurchaseFeedback"
	_purchase_feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_purchase_feedback.add_theme_color_override("font_outline_color",Color("#21172f"))
	_purchase_feedback.add_theme_constant_override("outline_size",8)
	_purchase_feedback.z_index=10
	_feedback_tween=create_tween()
	_feedback_tween.tween_property(_purchase_feedback,"position:y",_purchase_feedback.position.y-24.0,1.25)
	_feedback_tween.parallel().tween_property(_purchase_feedback,"modulate:a",0.0,.4).set_delay(.85)
	_feedback_tween.tween_callback(_purchase_feedback.queue_free)

func get_purchase_feedback_state() -> Dictionary:
	var visible := is_instance_valid(_purchase_feedback) and _purchase_feedback.is_visible_in_tree() and _purchase_feedback.modulate.a>0.01
	return {"error":_feedback_error,"text":_purchase_feedback.text if visible else "","visible":visible}

func _text(parent: Node, value: String, font_size: int, color: Color, rect: Rect2, display_text: bool = false) -> Label:
	var label := Label.new()
	label.text=value
	label.position=rect.position
	label.size=rect.size
	var pixel_text := _display_font!=null
	if pixel_text: label.add_theme_font_override("font",_display_font)
	label.add_theme_font_size_override("font_size",maxi(24,roundi(float(font_size)/12.0)*12) if pixel_text else maxi(26,font_size))
	label.set_meta("font_role","pixel" if pixel_text else "body")
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	label.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if pixel_text else CanvasItem.TEXTURE_FILTER_LINEAR
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _pixel_frame(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(width)
	style.set_content_margin_all(0)
	style.anti_aliasing=false
	return style

func _circle_frame(fill: Color, border: Color, width: int, diameter: float) -> StyleBoxTexture:
	return WorkshopSkin.circle(fill,border,width,diameter)

func _status_color(state: Dictionary) -> Color:
	if bool(state.can_buy): return Color("#86e68b")
	return MUTED

func _buy_caption(state: Dictionary) -> String:
	if not bool(state.implemented): return "暂未开放"
	if str(state.status)=="maxed": return "已满级"
	if str(state.status)=="in_run": return "战斗中不可升级"
	return "升级" if int(state.cost)==0 else "%d 金币 · 升级" % int(state.cost)

func _branch(node_id: String) -> String:
	return str(_definitions.get(node_id,{}).get("tree_branch",NODE_LAYOUT.get(node_id,{}).get("branch","supply")))

func _glyph(node_id: String) -> String:
	var value := str(_definitions.get(node_id,{}).get("tree_glyph",NODE_LAYOUT.get(node_id,{}).get("glyph","root")))
	return value if GLYPHS.has(value) else "root"

func get_layout_state() -> Dictionary:
	var nodes: Dictionary = {}
	for node_id: String in _nodes:
		var entry: Dictionary = _nodes[node_id]
		var button: Button=entry.button
		var neighbors: Dictionary={}
		for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			var target: Node=button.get_node_or_null(button.get_focus_neighbor(side))
			neighbors[str(side)]=str(target.get_meta("talent_id","")) if target!=null else ""
		nodes[node_id] = {"position":_positions[node_id],"rect":button.get_rect(),"title_rect":entry.title.get_rect(),"status_rect":entry.status_label.get_rect(),"status":entry.state.status,"status_text":entry.status_label.text,"status_visible":entry.status_label.visible,"can_buy":entry.state.can_buy,"selected":node_id==_selected_id,"focus_neighbors":neighbors,"focus_next":str(button.focus_next),"screen_rect":Rect2(button.position*_zoom+_pan,button.size*_zoom)}
	var sections: Array[Rect2] = []
	for child: Node in _canvas.get_children():
		if child is Label and child.get_meta("tree_section_title",false): sections.append(child.get_rect())
	var edges := _canvas.edges.duplicate(true)
	var route_count := 0
	for edge: Dictionary in edges:
		edge["highlighted"] = str(edge.source)==_selected_id or str(edge.target)==_selected_id
		if str(edge.source)=="TAL-P": route_count+=1
	return {"nodes":nodes,"edges":edges,"route_count":route_count,"section_rects":sections,"selected":_selected_id,"canvas_size":TREE_SIZE,"zoom":_zoom,"pan":_pan,"viewport_size":_surface.size,"detail_width":DETAIL_WIDTH}
