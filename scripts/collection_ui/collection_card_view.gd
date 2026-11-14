extends Control
## One 768x1024 design, fitted without distortion into every 3:4 card slot.
## Illustration, native frame, and runtime typesetting are independent layers.
## Foil uses planar UV parallax: it does not claim a 3D depth reconstruction.

const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const Catalog = preload("res://scripts/collection_catalog.gd")
const STANDARD_SIZE := Vector2(768, 1024)
const ART_WINDOW := Rect2(27,78,714,632)
const ART_INNER := Rect2(35,86,698,616)
const GRADE_RECT := Rect2(299,10,170,62)
const THEME_RECT := Rect2(299,733,170,43)
const NAME_RECT := Rect2(54,765,660,106)
const DESCRIPTION_RECT := Rect2(100,909,568,68)
const DIGIMON_REFERENCE_WINDOW := Rect2(29,80,710,644)
const TEXT_INK := Color("#392442")
const TEXT_SECONDARY := Color("#63485d")
const HOLO_STRENGTH := 0.65 # The approved preview app starts its slider at 65%.
const NAME_MAX_VISIBLE_CHARACTERS := 6
# Presentation aliases only. Definitions, stable IDs, drops and saves retain
# their complete canonical names; every card surface uses this one mapping.
const DISPLAY_NAMES := {
	"GAL-041":"武仙座星团",
	"DIG-038":"机械暴龙兽",
	"DIG-048":"帝皇圣骑士",
	"DIG-049":"奥米加X抗体",
	"MEM-002":"耄耋偷吃被抓",
	"MEM-007":"斜眼Doge",
	"MEM-008":"瘫坐柴犬",
	"MEM-015":"奶龙捧腹大笑",
	"MEM-017":"飞机耳警告",
	"MEM-019":"黄豆出来转圈",
	"MEM-021":"柴犬敲头警告",
	"MEM-024":"旋转猫",
	"MEM-025":"敲鼓猫",
	"MEM-027":"高雅通勤摇摆",
	"MEM-029":"水豚顶橘泡汤",
	"MEM-031":"奶蛙雨中狂笑",
	"MEM-032":"高雅上班视察",
	"MEM-033":"金馆长狂笑",
	"MEM-040":"奶蛙惊鸿一瞥",
	"MEM-041":"高雅举杯致意",
	"MEM-047":"耄耋三哈一普",
	"MEM-048":"奶蛙最后晚餐",
	"MEM-049":"滑稽会心一笑",
}
# The approved images are sampled only inside this word-free source band.
# Their baked header, theme, title and description never enter the texture.
const REFERENCE_SOURCE_SIZE := Vector2i(1086,1448)
const REFERENCE_SOURCE_REGION := Rect2i(0,100,1086,940)
const REFERENCE_ART := {
	"GAL-046":"res://assets/collection/reference_art/01-black-hole-red-holo.png",
	"DIG-046":"res://assets/collection/reference_art/02-omegamon-red-holo.png",
}
static var _reference_textures: Dictionary = {}
var definition: Dictionary = {}
var owned := false
var face_down := false
var compact := false
var selected := false
var reduced := false
var paused := false
var external_clock := false
var _font: Font
var _surface: Control
var _art_backing: TextureRect
var _art: TextureRect
var _frame: CardFrame
var _name: Label
var _description: Label
var _theme_label: Label
var _grade_label: Label
var _foil: ShaderMaterial
var _frame_foil: ShaderMaterial
var _back_alpha: ShaderMaterial
var _art_extension: ShaderMaterial
var _background_foreground_rect := Vector4(0,0,1,1)
var _background_source_valid_rect := Vector4(0,0,1,1)
var _reference_frame := false
var _reference_source_path := ""
var _art_window := ART_WINDOW
var _frame_asset_path := ""
var _reference_uniform_fit := false
var _reference_fit_scale := 1.0
var _reference_fit_offset := Vector2.ZERO
var _reference_visible_rect := Rect2()
var _clock := 0.0
var _tilt := Vector2.ZERO
var _target_tilt := Vector2.ZERO
var _texture_loaded := false
var _flip_scale := 1.0
var _motion_fit := 1.0
var _external_perspective := false
var _name_layout: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)
	mouse_exited.connect(func() -> void: _target_tilt = Vector2.ZERO)
	_ensure_visual()
	_refresh()

func configure(card: Dictionary, is_owned: bool, font: Font = null, is_compact: bool = false) -> void:
	definition = card.duplicate(true)
	owned = is_owned
	_font = font
	compact = is_compact
	_ensure_visual()
	_refresh()

func set_face_down(value: bool) -> void:
	if face_down == value: return
	face_down = value
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(_frame): _frame.selected = value; _frame.queue_redraw()

func set_flip(amount: float) -> void:
	_flip_scale = clampf(absf(amount),0.015,1.0)
	_layout()

func set_reduced(value: bool) -> void:
	reduced = value
	if _foil != null: _foil.set_shader_parameter("reduced", value)
	if _frame_foil != null: _frame_foil.set_shader_parameter("reduced", value)
	if value:
		_target_tilt = Vector2.ZERO
		_tilt = Vector2.ZERO
		if _foil != null: _foil.set_shader_parameter("tilt",Vector2.ZERO)
		if _frame_foil != null: _frame_foil.set_shader_parameter("tilt",Vector2.ZERO)
		if is_instance_valid(_surface): _surface.rotation = 0.0; _layout()

func set_paused(value: bool) -> void:
	paused = value

func set_tilt(value: Vector2) -> void:
	if not is_finite(value.x) or not is_finite(value.y): return
	_target_tilt = value.clamp(-Vector2.ONE,Vector2.ONE)

func set_projection_tilt(value: Vector2) -> void:
	# Inspector rotates the composited card on a real 3D mesh. Feed the same
	# angle to the illustration foil without adding a second 2D rotation.
	_external_perspective = true
	_tilt = value.clamp(-Vector2.ONE,Vector2.ONE)
	_target_tilt = _tilt
	if _foil!=null: _foil.set_shader_parameter("tilt",_tilt)
	if _frame_foil!=null: _frame_foil.set_shader_parameter("tilt",_tilt)
	if is_instance_valid(_surface): _surface.rotation = 0; _layout()

func _process(delta: float) -> void:
	if not external_clock and is_visible_in_tree() and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
		advance_time(delta)

func advance_time(delta: float) -> void:
	if paused or delta <= 0 or not is_finite(delta): return
	if not reduced: _clock += delta
	_tilt = _tilt.lerp(_target_tilt,1.0-exp(-delta*9.0))
	if _foil != null:
		_foil.set_shader_parameter("effect_time",_clock)
		_foil.set_shader_parameter("tilt",_tilt)
	if _frame_foil != null:
		_frame_foil.set_shader_parameter("effect_time",_clock)
		_frame_foil.set_shader_parameter("tilt",_tilt)
	if is_instance_valid(_surface):
		_surface.rotation = 0.0 if _external_perspective else deg_to_rad(_tilt.x * (0.9 if compact else 1.7))
		_layout()
	if int(definition.get("grade",0)) >= 3 and owned and not face_down:
		_frame.clock = _clock
		_frame.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not reduced:
		_target_tilt = ((event.position / size.max(Vector2.ONE))-Vector2(0.5,0.5))*2.0

func get_presentation_state() -> Dictionary:
	var exposed := owned and not face_down
	var art_bounds := _illustration_bounds()
	return {
		"id":str(definition.get("id","")) if exposed else "", "name":str(definition.get("name","")) if exposed else "？",
		"owned":owned,"face_down":face_down,"hidden_identity_exposed":exposed and bool(definition.get("hidden",false)),
		"art_loaded":_texture_loaded and exposed,"frame_loaded":_frame.frame_texture!=null if is_instance_valid(_frame) else false,
		"frame_source":"rgba_asset" if is_instance_valid(_frame) and _frame.frame_texture!=null else "native_fallback",
		"standard_size":[768,1024],"aspect":"3:4","holo":int(definition.get("grade",0))==4 and exposed,
		"effect_time":_clock,"parallax_mode":"planar_uv_approximation","runtime_typesetting":true,
		"text_ink":_name.get_theme_color("font_color").to_html(),"text_panel":"cream_paper",
		"art_fit_mode":("reference_uniform_fit" if _reference_uniform_fit else "approved_reference_region") if not _reference_source_path.is_empty() else "contain",
		"art_window":[_art_window.position.x,_art_window.position.y,_art_window.size.x,_art_window.size.y],
		"illustration_rect":[art_bounds.position.x,art_bounds.position.y,art_bounds.size.x,art_bounds.size.y],
		"motion_fit":_motion_fit,"backing_is_native_ui":false,"holo_on_backing":false,
		"background_mode":"same_source_edge_extension","background_source_matches_foreground":exposed and _texture_loaded and _art_backing.texture==_art.texture,
		"background_window":[_art_backing.position.x,_art_backing.position.y,_art_backing.size.x,_art_backing.size.y],
		"background_foreground_rect":[_background_foreground_rect.x,_background_foreground_rect.y,_background_foreground_rect.z,_background_foreground_rect.w],
		"background_source_valid_rect":[_background_source_valid_rect.x,_background_source_valid_rect.y,_background_source_valid_rect.z,_background_source_valid_rect.w],
		"unified_layout":true,"layout_template":"galaxy_red_reference","frame_asset_path":_frame_asset_path,
		"common_rect":[ART_WINDOW.position.x,ART_WINDOW.position.y,ART_WINDOW.size.x,ART_WINDOW.size.y],
		"reference_alignment":not _reference_source_path.is_empty(),"reference_source":_reference_source_path if exposed else "",
		"reference_source_size":[1086,1448] if not _reference_source_path.is_empty() else [],
		"source_region":[0,100,1086,940] if exposed and not _reference_source_path.is_empty() else [],
		"original_uv_mapping":not _reference_source_path.is_empty() and not _reference_uniform_fit,"foil_facets":118,
		"reference_uniform_fit":_reference_uniform_fit,"reference_fit_scale":_reference_fit_scale,
		"reference_fit_offset":[_reference_fit_offset.x,_reference_fit_offset.y],
		"reference_source_window":[29,80,710,644] if _reference_uniform_fit else [],
		"reference_visible_rect":[_reference_visible_rect.position.x,_reference_visible_rect.position.y,_reference_visible_rect.size.x,_reference_visible_rect.size.y] if _reference_uniform_fit else [],
		"source_texture_rect":[_art.position.x,_art.position.y,_art.size.x,_art.size.y],
		"foil_quality":"compact_same_source" if compact else "full_microfacets",
		"gold_emboss_mode":"color_threshold_texture_gradient" if int(definition.get("grade",0))>=3 else "none",
		"frame_metal_strength":float(_frame_foil.get_shader_parameter("strength")) if exposed else 0.0,
		"compact_separator_reflow":false,
		"separator_display_bounds":[158,888,454,38],
		"holo_strength":HOLO_STRENGTH if int(definition.get("grade",0))==4 and exposed else 0.0,
		"display_name":display_name(definition) if exposed else "？",
	}

func get_name_layout_state() -> Dictionary:
	if not is_instance_valid(_name): return {}
	var exposed := owned and not face_down
	var lengths: Array[int] = []
	for line: String in _name.text.split("\n"): lengths.append(visible_name_length(line))
	return {"compact":compact,"text":_name.text,"display_name":_name.text,"canonical_name":str(definition.get("name","")) if exposed else "","font_size":_name.get_theme_font_size("font_size"),"line_count":lengths.size(),"line_lengths":lengths,"max_visible_characters":NAME_MAX_VISIBLE_CHARACTERS,"line_spacing":_name.get_theme_constant("line_spacing"),"box":_name.get_rect(),"requested_box":_name_layout.get("box",_name.get_rect()),"minimum_size":_name.get_minimum_size(),"description_box":_description.get_rect()}

func _illustration_bounds() -> Rect2:
	if not is_instance_valid(_art) or _art.texture==null: return Rect2()
	if _reference_uniform_fit: return _reference_visible_rect
	var source := _art.texture.get_size()
	var ratio := minf(_art.size.x/maxf(1,source.x),_art.size.y/maxf(1,source.y))
	var fitted := source*ratio
	return Rect2(_art.position+(_art.size-fitted)*0.5,fitted)

func _ensure_visual() -> void:
	if is_instance_valid(_surface): return
	_surface = Control.new()
	_surface.name = "CardLayers768x1024"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.size = STANDARD_SIZE
	_surface.pivot_offset = STANDARD_SIZE * 0.5
	add_child(_surface)
	_art_backing = TextureRect.new()
	_art_backing.name = "SourceArtExtension"
	_art_backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_backing.stretch_mode = TextureRect.STRETCH_SCALE
	_art_backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art_backing.position = ART_WINDOW.position
	_art_backing.size = ART_WINDOW.size
	_art_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_extension = ShaderMaterial.new()
	_art_extension.shader = load("res://scripts/collection_ui/card_art_extension.gdshader")
	_art_backing.material = _art_extension
	_surface.add_child(_art_backing)
	_art = TextureRect.new()
	_art.name = "Illustration"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_art)
	_foil = ShaderMaterial.new()
	_foil.shader = load("res://scripts/collection_ui/card_foil.gdshader")
	_frame_foil = ShaderMaterial.new()
	_frame_foil.shader = load("res://scripts/collection_ui/card_reference_frame.gdshader")
	_back_alpha = ShaderMaterial.new()
	_back_alpha.shader = load("res://scripts/collection_ui/card_back_alpha.gdshader")
	_frame = CardFrame.new()
	_frame.size = STANDARD_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_frame)
	_name = Ui.label(_surface,"",NAME_RECT,_font,84,Ui.INK,true)
	_description = Ui.label(_surface,"",DESCRIPTION_RECT,_font,24,Ui.INK,true)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_constant_override("line_spacing",-4)
	_theme_label = Ui.label(_surface,"",THEME_RECT,_font,28,Ui.INK,true)
	_grade_label = Ui.label(_surface,"",GRADE_RECT,_font,48,Ui.GOLD,true)

func _refresh() -> void:
	_ensure_visual()
	var exposed := owned and not face_down
	var grade := clampi(int(definition.get("grade",0)),0,4)
	var red := grade == 4
	_frame.grade = grade
	_frame.back = not exposed
	_frame.hidden_identity = exposed and bool(definition.get("hidden",false))
	_frame.theme_id = str(definition.get("theme","galaxy"))
	_frame.selected = selected
	_frame.compact = compact
	_reference_frame = true
	_frame.reference_style = _reference_frame
	_frame_asset_path = unified_frame_path(grade,_frame.theme_id)
	_frame.frame_texture = Ui.texture(_frame_asset_path)
	if _frame.frame_texture==null:
		_frame_asset_path = "res://assets/collection/unified_frames/red_galaxy.png"
		_frame.frame_texture = Ui.texture(_frame_asset_path)
	if _frame.frame_texture==null:
		_frame_asset_path = "res://assets/collection/red-reference-alignment/frame_galaxy.png"
		_frame.frame_texture = Ui.texture(_frame_asset_path)
	_frame.material = _frame_foil if exposed else _back_alpha
	_frame_foil.set_shader_parameter("compact",compact)
	_frame_foil.set_shader_parameter("reduced",reduced)
	_frame_foil.set_shader_parameter("strength",HOLO_STRENGTH if red else (0.16 if grade==3 else 0.0))
	_frame_foil.set_shader_parameter("ruby_strength",HOLO_STRENGTH if red else 0.0)
	_frame.back_texture = Ui.texture("res://assets/collection/backs/%s_back_%d.png"%[_frame.theme_id,grade]) if _frame.theme_id!="galaxy" else null
	if _frame.back_texture==null: _frame.back_texture = Ui.texture("res://assets/collection/backs/back_%d.png"%grade)
	_art_window = ART_WINDOW
	_art.position = ART_INNER.position
	_art.size = ART_INNER.size
	_reference_uniform_fit = false
	_reference_fit_scale = 1.0
	_reference_fit_offset = Vector2.ZERO
	_reference_visible_rect = Rect2()
	_foil.set_shader_parameter("clip_uv_bounds",Vector4(0,0,1,1))
	_reference_source_path = str(REFERENCE_ART.get(str(definition.get("id","")),"")) if red and exposed else ""
	if not _reference_source_path.is_empty():
		_art.texture = _reference_art(_reference_source_path)
		var source_scale := STANDARD_SIZE/Vector2(REFERENCE_SOURCE_SIZE)
		_art.position = Vector2(REFERENCE_SOURCE_REGION.position)*source_scale
		_art.size = Vector2(REFERENCE_SOURCE_REGION.size)*source_scale
		if str(definition.get("id",""))=="DIG-046":
			_reference_uniform_fit = true
			_reference_fit_scale = minf(ART_INNER.size.x/DIGIMON_REFERENCE_WINDOW.size.x,ART_INNER.size.y/DIGIMON_REFERENCE_WINDOW.size.y)
			_reference_visible_rect = Rect2(ART_INNER.get_center()-DIGIMON_REFERENCE_WINDOW.size*_reference_fit_scale*0.5,DIGIMON_REFERENCE_WINDOW.size*_reference_fit_scale)
			_reference_fit_offset = _reference_visible_rect.position-DIGIMON_REFERENCE_WINDOW.position*_reference_fit_scale
			var clip_lo := (DIGIMON_REFERENCE_WINDOW.position-_art.position)/_art.size
			var clip_hi := (DIGIMON_REFERENCE_WINDOW.end-_art.position)/_art.size
			_foil.set_shader_parameter("clip_uv_bounds",Vector4(clip_lo.x,clip_lo.y,clip_hi.x,clip_hi.y))
			_art.position = _art.position*_reference_fit_scale+_reference_fit_offset
			_art.size *= _reference_fit_scale
	else:
		_art.texture = Ui.texture(str(definition.get("art_path",""))) if exposed else null
	_texture_loaded = _art.texture != null
	_art.visible = exposed and _texture_loaded
	_art_backing.position = _art_window.position
	_art_backing.size = _art_window.size
	_art_backing.visible = exposed and _texture_loaded
	_configure_art_extension()
	_art.material = _foil if red else null
	if not _reference_source_path.is_empty():
		_foil.set_shader_parameter("source_uv_rect",Vector4(0,100.0/1448.0,1,940.0/1448.0))
	else:
		_foil.set_shader_parameter("source_uv_rect",Vector4(_art.position.x/768.0,_art.position.y/1024.0,_art.size.x/768.0,_art.size.y/1024.0))
	_foil.set_shader_parameter("hidden_pattern",_frame.hidden_identity)
	_foil.set_shader_parameter("theme_kind",1 if _frame.theme_id == "digimon" else 0)
	_foil.set_shader_parameter("compact",compact)
	_foil.set_shader_parameter("reduced",reduced)
	_foil.set_shader_parameter("strength",HOLO_STRENGTH)
	_name.text = display_name(definition) if exposed else "？"
	_description.text = str(definition.get("description","")) if exposed else ""
	_description.visible = exposed and not compact
	_theme_label.text = Catalog.theme_name(_frame.theme_id) if exposed else ""
	_grade_label.text = ("隐藏款" if _frame.hidden_identity else ["普通","稀有","史诗","传说","绝版"][grade]) if exposed else ""
	_name.add_theme_color_override("font_color",TEXT_INK if exposed else Color("#b4a3c5"))
	_description.add_theme_color_override("font_color",TEXT_SECONDARY)
	_theme_label.add_theme_color_override("font_color",TEXT_SECONDARY)
	_grade_label.add_theme_color_override("font_color",Color("#913b58") if red else TEXT_INK)
	_layout_reference_labels(exposed)
	for item in [_name,_description,_theme_label,_grade_label]:
		if _font != null: item.add_theme_font_override("font",_font)
	_layout_name()
	_frame.art_missing = exposed and not _texture_loaded
	_frame.queue_redraw()
	_layout()

static func _reference_art(path: String) -> Texture2D:
	if _reference_textures.has(path): return _reference_textures[path]
	var texture := Ui.texture(path)
	if texture==null: return null
	var source := texture.get_image()
	if source==null or source.is_empty() or source.get_size()!=REFERENCE_SOURCE_SIZE: return null
	if source.is_compressed() and source.decompress()!=OK: return null
	var region := source.get_region(REFERENCE_SOURCE_REGION)
	region.generate_mipmaps()
	var result := ImageTexture.create_from_image(region)
	_reference_textures[path] = result
	return result

func _configure_art_extension() -> void:
	# The separate foreground, its texture and its contain/approved-region
	# geometry are never modified by the extension pass.
	_art_backing.texture = _art.texture
	_background_source_valid_rect = Vector4(0,0,1,1)
	var foreground := _illustration_bounds()
	if not _reference_source_path.is_empty():
		var original_scale := STANDARD_SIZE/Vector2(REFERENCE_SOURCE_SIZE)
		var original_band := Rect2(Vector2(REFERENCE_SOURCE_REGION.position)*original_scale,Vector2(REFERENCE_SOURCE_REGION.size)*original_scale)
		# Restrict reference sampling to art pixels: no baked header/text or rim.
		var safe_source := DIGIMON_REFERENCE_WINDOW.grow(-8) if _reference_uniform_fit else ART_INNER
		var valid_origin := (safe_source.position-original_band.position)/original_band.size
		var valid_size := safe_source.size/original_band.size
		_background_source_valid_rect = Vector4(valid_origin.x,valid_origin.y,valid_size.x,valid_size.y)
		foreground = Rect2(safe_source.position*_reference_fit_scale+_reference_fit_offset,safe_source.size*_reference_fit_scale) if _reference_uniform_fit else safe_source
	var origin := (foreground.position-ART_WINDOW.position)/ART_WINDOW.size
	var extent := foreground.size/ART_WINDOW.size
	_background_foreground_rect = Vector4(origin.x,origin.y,extent.x,extent.y)
	_art_extension.set_shader_parameter("foreground_rect",_background_foreground_rect)
	_art_extension.set_shader_parameter("source_valid_rect",_background_source_valid_rect)
	_art_extension.set_shader_parameter("window_pixels",ART_WINDOW.size)

static func unified_frame_path(grade: int,theme: String) -> String:
	if grade<4: return "res://assets/collection/unified_frames/grade_%d.png"%clampi(grade,0,3)
	return "res://assets/collection/unified_frames/red_%s.png"%(theme if theme in ["galaxy","digimon","meme"] else "galaxy")

func _layout_reference_labels(exposed: bool) -> void:
	# Every grade, theme and display mode consumes these same requested rects.
	_description.position = DESCRIPTION_RECT.position
	_description.size = DESCRIPTION_RECT.size
	_description.add_theme_font_size_override("font_size",24)
	_description.add_theme_constant_override("line_spacing",-4)
	_theme_label.position = THEME_RECT.position
	_theme_label.size = THEME_RECT.size
	_theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_label.add_theme_font_size_override("font_size",28)
	_grade_label.position = GRADE_RECT.position
	_grade_label.size = GRADE_RECT.size
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size",48)
	var grade := clampi(int(definition.get("grade",0)),0,4)
	var inks := [Color("#392442"),Color("#224737"),Color("#513263"),Color("#684018"),Color("#5b0902")]
	_name.add_theme_color_override("font_color",inks[grade] if exposed else Color("#b4a3c5"))
	_description.add_theme_color_override("font_color",Color("#47220e") if grade>=3 else TEXT_SECONDARY)
	_theme_label.add_theme_color_override("font_color",Color("#5b1806") if grade>=3 else TEXT_SECONDARY)
	_grade_label.add_theme_color_override("font_color",inks[grade])

static func display_name(card: Dictionary) -> String:
	return str(DISPLAY_NAMES.get(str(card.get("id","")),str(card.get("name",""))))

static func visible_name_length(value: String) -> int:
	var count := 0
	for character: String in value:
		if character not in [" ","\t","\r","\n"]: count+=1
	return count

func _layout_name() -> void:
	# One semantic alias, one font and one requested rect at every size/grade.
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.clip_text = false
	_name.remove_theme_constant_override("line_spacing")
	_name.add_theme_font_size_override("font_size",84)
	_name.position = NAME_RECT.position
	_name.size = NAME_RECT.size
	_name_layout = {"lines":1,"font_size":84,"box":NAME_RECT}

func get_card_layout_state() -> Dictionary:
	return {
		"art_window":ART_WINDOW,"art_inner":ART_INNER,
		"grade_position":_grade_label.position,"grade_requested":GRADE_RECT,"grade_font":_grade_label.get_theme_font_size("font_size"),
		"theme_position":_theme_label.position,"theme_requested":THEME_RECT,"theme_font":_theme_label.get_theme_font_size("font_size"),
		"name_position":_name.position,"name_requested":NAME_RECT,"name_font":_name.get_theme_font_size("font_size"),
		"description_position":_description.position,"description_requested":DESCRIPTION_RECT,"description_font":_description.get_theme_font_size("font_size"),
		"description_spacing":_description.get_theme_constant("line_spacing"),"description_lines":_description.get_line_count(),
		"description_minimum":_description.get_minimum_size(),"description_visible":_description.visible,
	}

func _layout() -> void:
	if not is_instance_valid(_surface): return
	var ratio := minf(size.x/STANDARD_SIZE.x,size.y/STANDARD_SIZE.y)
	# Inscribe the rotated AABB in the existing slot. Hover/auto tilt must not
	# push a frame corner across neighboring cards, labels or the detail bounds.
	var cosine := absf(cos(_surface.rotation))
	var sine := absf(sin(_surface.rotation))
	var rotated := Vector2(STANDARD_SIZE.x*_flip_scale*cosine+STANDARD_SIZE.y*sine,STANDARD_SIZE.x*_flip_scale*sine+STANDARD_SIZE.y*cosine)*ratio
	_motion_fit = minf(1.0,minf(size.x/maxf(rotated.x,0.0001),size.y/maxf(rotated.y,0.0001)))
	_surface.scale = Vector2(ratio*_motion_fit*_flip_scale,ratio*_motion_fit)
	# Control scaling occurs around pivot_offset; position anchors the unscaled
	# center. Reapplying the fit offset would shift small cards outside their slot.
	_surface.position = size*0.5-STANDARD_SIZE*0.5

class CardFrame extends Control:
	var grade := 0
	var back := true
	var selected := false
	var hidden_identity := false
	var art_missing := false
	var compact := false
	var theme_id := "galaxy"
	var clock := 0.0
	var reference_style := false
	var frame_texture: Texture2D
	var back_texture: Texture2D
	func _draw() -> void:
		var accent: Color = Ui.GRADES[grade]
		if back and back_texture != null:
			draw_texture_rect(back_texture,Rect2(Vector2.ZERO,Vector2(768,1024)),false)
			if selected: draw_style_box(Ui.plate(Color.TRANSPARENT,Color("#fff3bf"),6),Rect2(0,0,768,1024))
			return
		if not back and frame_texture != null:
			if art_missing:
				draw_rect(ART_WINDOW,Color("#251d38"))
				draw_arc(Vector2(384,400),138,0,TAU,60,Color("#524263"),5,true)
				draw_circle(Vector2(384,376),67,Color("#40354e"))
				draw_ellipse_placeholder()
			draw_texture_rect(frame_texture,Rect2(Vector2.ZERO,Vector2(768,1024)),false)
			if hidden_identity:
				draw_theme_mark(Vector2(665,706),Color("#ffe0a1"))
				draw_arc(Vector2(665,706),48,0,TAU,48,Color("#ffe0a1"),3,true)
			if grade>=3 and not compact and not reference_style:
				var y := 40.0+fposmod(clock*170.0,920.0)
				draw_line(Vector2(18,y),Vector2(18,minf(1000,y+62)),Color("#fff0b8"),5,true)
				draw_line(Vector2(750,1024-y),Vector2(750,maxf(24,962-y)),Color("#fff0b8"),5,true)
			if selected: draw_style_box(Ui.plate(Color.TRANSPARENT,Color("#fff3bf"),6),Rect2(0,0,768,1024))
			return
		if back:
			draw_style_box(Ui.plate(Color("#211c35"),accent.darkened(0.35),12),Rect2(9,9,750,1006))
			for line in range(10):
				var y := 90.0+float(line)*93.0
				draw_line(Vector2(35,y),Vector2(733,y-60),Color("#3c3153"),3,true)
			var c := Vector2(384,485)
			draw_arc(c,153,0,TAU,70,accent.darkened(0.35),7,true)
			draw_arc(c,120,0,TAU,64,Color("#6b536e"),3,true)
			var diamond := PackedVector2Array([c+Vector2(0,-88),c+Vector2(58,0),c+Vector2(0,88),c+Vector2(-58,0)])
			draw_colored_polygon(diamond,Color("#3e3253"))
		else:
			if art_missing:
				draw_style_box(Ui.plate(Color("#211b30"),accent.darkened(0.5),1),Rect2(25,25,718,974))
				draw_arc(Vector2(384,400),138,0,TAU,60,Color("#524263"),5,true)
				draw_circle(Vector2(384,376),67,Color("#40354e"))
				draw_ellipse_placeholder()
			draw_rect(Rect2(26,774,716,224),Color("#f3dfbc"))
			draw_rect(Rect2(28,25,712,57),Color("#f3dfbc"))
			draw_line(Vector2(43,774),Vector2(725,774),accent,4,true)
			draw_theme_mark(Vector2(385,115),accent)
			if hidden_identity:
				draw_theme_mark(Vector2(665,706),Color("#ffe0a1"))
				draw_arc(Vector2(665,706),48,0,TAU,48,Color("#ffe0a1"),3,true)
		# Draw the outer native rim after the illustration; its thickness is uniform.
		draw_style_box(Ui.plate(Color.TRANSPARENT,accent,14),Rect2(9,9,750,1006))
		draw_style_box(Ui.plate(Color.TRANSPARENT,Color("#281b31"),4),Rect2(26,26,716,972))
		if grade >= 3 and not back:
			var gold := Color("#eac576")
			draw_style_box(Ui.plate(Color.TRANSPARENT,gold,4),Rect2(29,29,710,966))
			for corner in [Vector2(36,36),Vector2(732,36),Vector2(36,988),Vector2(732,988)]:
				var direction := Vector2(1 if corner.x<384 else -1,1 if corner.y<512 else -1)
				var p := PackedVector2Array([corner,corner+Vector2(direction.x*82,0),corner+Vector2(direction.x*28,direction.y*26),corner+Vector2(0,direction.y*82)])
				draw_colored_polygon(p,Color("#62432e"))
				for index in range(p.size()): draw_line(p[index]-Vector2(1,2),p[(index+1)%p.size()]-Vector2(1,2),gold,3,true)
			if not compact:
				var y := 45.0+fposmod(clock*170.0,915.0)
				draw_line(Vector2(18,y),Vector2(18,minf(y+70,1000)),Color("#fff0b8"),7,true)
				draw_line(Vector2(750,1024-y),Vector2(750,maxf(24,954-y)),Color("#fff0b8"),7,true)
		if selected: draw_style_box(Ui.plate(Color.TRANSPARENT,Color("#fff3bf"),6),Rect2(0,0,768,1024))
	func draw_ellipse_placeholder() -> void:
		var p := PackedVector2Array()
		for index in range(30):
			var a := PI+float(index)/29.0*PI
			p.append(Vector2(384,565)+Vector2(cos(a)*144,sin(a)*119))
		draw_colored_polygon(p,Color("#40354e"))
	func draw_theme_mark(c: Vector2, color: Color) -> void:
		if theme_id == "digimon":
			for offset in [Vector2(-14,-14),Vector2(9,-14),Vector2(-14,9),Vector2(9,9)]: draw_rect(Rect2(c+offset,Vector2(14,14)),color)
		else:
			draw_arc(c,24,0.2,TAU-0.2,30,color,3,true)
			draw_arc(c,34,-0.45,PI+0.45,30,color,2,true)
			draw_circle(c,6,color)

