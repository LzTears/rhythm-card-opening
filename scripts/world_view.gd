extends Node3D
## Rendering only: collision, target identities, rewards and timing belong to simulation.gd.

signal reward_collected
var _feedback_math: RefCounted
var _feedback_owned_records: Array = []
var _feedback_owned_clock := -INF
var _feedback_owned_valid := false
var _feedback_owned_viewport := Vector2.ZERO
var _feedback_owned_generation := 0

const Geometry = preload("res://scripts/world_meshes.gd")
const PackTrail = preload("res://scripts/pack_trail.gd")
const SkillEffect = preload("res://scripts/world_skill_effect.gd")
const QualityEffect = preload("res://scripts/world_quality_effect.gd")
const QualityCatalog = preload("res://scripts/world_quality_pairs.gd")
const AtlasBatch = preload("res://scripts/world_atlas_batch.gd")
const HarvestSparkle = preload("res://scripts/world_harvest_sparkle.gd")
const RewardFlyer = preload("res://scripts/world_reward_flyer.gd")
const GenericCard = preload("res://scripts/world_generic_card.gd")
const FeedbackStyles = preload("res://scripts/world_feedback_styles.gd")
const FeedbackLabelPool = preload("res://scripts/world_feedback_label_pool.gd")
const ClaimVisualPool = preload("res://scripts/world_claim_visual_pool.gd")
const Rules = preload("res://scripts/pack_rules.gd")
const CardCatalog = preload("res://scripts/attack_spec.gd")
const PreparationFeedback = preload("res://scripts/world_prepare_feedback.gd")
const WebFeedbackWarmup = preload("res://scripts/web_feedback_warmup.gd")
var _web_feedback_warmup: Dictionary = {}
var _web_feedback_warmup_materials: Array[Material] = []
# Radius of the guide band in vfx_charge.gdshader's normalized UV coordinates.
const GUIDE_UV_RADIUS := 0.433
const CHARGE_SHADER = preload("res://assets/workshop_charge.gdshader")
const AIM_SPARK_PATH := "res://assets/fx/aim_charge/charge_sparks.png"
const SOFT_SHADER = preload("res://assets/vfx_soft.gdshader")
const BACK_SHADER = preload("res://assets/vfx_pixel_card_back.gdshader")
const FRONT_PATH := "res://assets/art/a2/cards/%s-%d.png"
const BACK_PATH := "res://assets/art/a2/cards/card_back.png"
const WOOD_PATH := "res://assets/art/rhythm_v2/battle-table.png"
const PIXEL_HIT_PATH := "res://assets/fx/pixel/heavy_hit.png"
const BREAK_PATH := "res://assets/fx/combat06/crit-hit.png"
const MAX_VISUAL_SLOTS := 64
const SLOT_HEIGHT := 0.00075
const PACK_VIEW_DEPTH := 0.64
const GRADE_COLORS: Array[Color] = [Color("#f0efdf"),Color("#5ce69b"),Color("#c282ff"),Color("#ffce58"),Color("#ff637a")]
const FEEDBACK_OFFSETS := [Vector2.ZERO,Vector2(0,-52),Vector2(0,52),Vector2(-70,0),Vector2(70,0),Vector2(-48,-52),Vector2(48,-52),Vector2(-48,52),Vector2(48,52),Vector2(0,-78),Vector2(0,78)]
const FEEDBACK_SAMPLES := [0.0,.10,.20,.30,.40,.50]
const FEEDBACK_GRID_SIZE := Vector2(128.0,64.0)
const STATUS_FIELDS := ["mark","vulnerable","frost"]
const FX_FONT = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const FX_ARC_FONT = preload("res://assets/fonts/ark-pixel-12px-proportional-zh_hans.otf")
const FX_PRIMARY_FONT = preload("res://assets/fonts/NotoSansCJKsc-Medium.otf")
const DISPENSER_PATH := "res://assets/art/a2/dispensers/down.png"
const FEEDBACK_INK := Color("#fff0c5")
const FEEDBACK_PAPER := Color("#17242f")
const BD_ALPHABET := "扩散边缘破裂天幕展开无界爆发串联跃弧增幅链网溅射分叉连锁追猎回响余音击叠鸣复奏封太初三多重并耀共振星齐辉四极穿透损贯山双向精准核心疾速原终结蓄能满利释放急印快充群瞬息储备牵引力波动井压缩震荡纹崩碎标记烙同根焉转潮海啸寂灭再临寻卡额外高阶机遇远古招财整包加赏丰收倍定点势惯性首手·项"
const DAMAGE_NUMBER_DURATION := 0.48
const DAMAGE_NUMBER_FADE := 0.12
const DAMAGE_COLORS := {"direct":Color.WHITE,"burst":Color.WHITE,"chain":Color.WHITE,"dot":Color.WHITE,"wave":Color.WHITE}
var _preparation_feedback := PreparationFeedback.new()
# HF07: logical UI pixels; preserve font/quantity/lifetime, move only the local path.
const FEEDBACK_AVOID_GAP := 6.0
const FEEDBACK_AVOID_LEAD := 24.0
const FEEDBACK_AVOID_SPEED := 960.0
var _operation_keepout := Rect2()
# Only live during one synchronous aim-routing transaction.
var _aux_route_active := false
var _aux_route_peers: Array[Dictionary]=[]
var _aux_route_indices: Dictionary={}
var _aux_route_rects: Array[Rect2]=[]
var _aux_route_starts := PackedFloat64Array()
var _aux_route_ends := PackedFloat64Array()
var _aux_route_generic: Array[int]=[]
var _aux_route_order: Array[int]=[]
var _aux_waiters: Dictionary={}
var _aux_retry_clock := -INF
var _aux_wait_clock := -INF
var _aux_retry_queue: Array[Control]=[]
var _aux_external_rows: Array[Dictionary]=[]
var _aux_native_calls := 0
var _aux_fallback_calls := 0
var _aux_hold_count := 0
var _aux_resume_count := 0
var _aux_max_waiters := 0
var _aux_callback_active := false
var _aux_callback_clock := -INF
var _aux_callback_generation := -1
var _aux_callback_children := -1
var _aux_callback_viewport := Vector2.ZERO
var _aux_external_generation := 0
var _aux_callback_external := -1
var _aux_callback_builds := 0
var _aux_callback_reuses := 0
var _aux_birth_structure := 0
var _aux_birth_callback_structure := -1
var _aux_birth_view_owned := false
var _birth_fast_appends := 0
var _birth_rejections: Dictionary={}
var _aux_density_bd_rows: Dictionary={}
var _aux_density_reward_rows: Dictionary={}
var _aux_bd_folded_groups := 0
var _aux_bd_folded_sources := 0
var _aux_reward_folded_sources := 0
var _aux_reward_submissions := 0
var _aux_max_wait_age := 0.0

var _aux_damage_records: Array=[]
var _aux_damage_peers: Array[Dictionary]=[]
var _aux_damage_indices: Dictionary={}
var _safe_layout_math: RefCounted
var _safe_layout_checked := false
var _safe_layout_indexed := false
var _aux_native_records: Array=[]

var camera: Camera3D
var cards: Dictionary = {}
var dying: Dictionary = {}
var aim_ring: MeshInstance3D
var charge_ring: MeshInstance3D
# Public compatibility field: the selected presentation intentionally has no hammer model.
var hammer: Node3D
var base_y: float = 0.009
var reduce_effects: bool = false
var aim_point := Vector2(0,300)
var clock_time: float = 0.0

var _geo := Geometry.new()
var _effects: Node3D
var _decoration: Node3D
var _charge_material: ShaderMaterial
var _guide_material: ShaderMaterial
var _front_materials: Dictionary = {}
var _pack_materials: Dictionary = {}
var _default_desk_material: Material
var _equipped_board_skin := "default"
var _equipped_pack_skin := "default"
var _skin_texture_cache: Dictionary = {}
var _skin_mesh_cache: Dictionary = {}
var _alpha_rect_cache: Dictionary = {}
var _torn_materials: Dictionary = {}
var _gpu_warmed_elements: Dictionary = {}
var _gpu_warm_frames_left := 0
var _gpu_warming_element := ""
var _dispensers: Dictionary = {}
var _dispenser_tick := 0
var run_options: Dictionary = {}
var _back_material: Material
var _shadow_material: ShaderMaterial
var _tweens: Array[Tween] = []
var _world_paused_tweens: Array[Tween] = []
var _strike_tween: Tween
var _striking := false
var _battle := false
var _aim_valid := false
var _progress := 0.0
var _generation := 0
var _has_pause_property := false
var _paused_visuals := false
var _coin_sink := Vector3(0.20,0.20,-6.55)
var _pixel_viewport: SubViewport
var _stage: Node3D
var _pixel_display: TextureRect
var _pixel_hit: Texture2D
var _pixel_break: Texture2D
var _visual_slots: Dictionary = {}
var _hit_tweens: Dictionary = {}
var _claimed_visuals: Dictionary = {}
var _burst_feedback_attack: Dictionary = {}
var _burst_feedback_budget: Dictionary = {}
var _shake_left := 0.0
var _shake_cooldown := 0.0
var _shake_phase := 0.0
var _shake_started_frame := -1
var _shake_requests := 0
var _feedback_font: FontFile
var _damage_font: FontFile
var _arc_damage_font: FontFile
var _feedback_styles := FeedbackStyles.new()
var _feedback_label_pool := FeedbackLabelPool.new()
var _claim_visual_pool := ClaimVisualPool.new()
var _claim_visual_tweens: Dictionary = {}
var _feedback_batch_active := false
var _feedback_batch_has_keepout := false
var _feedback_batch_keepout := Rect2()
var _feedback_pending_init_label: Label
var _feedback_pending_init_generation := -1
var _feedback_initializing_label: Label
var _feedback_batch_initialized := false
var _pack_feedback_corners: Dictionary = {}
var _screen_effects: Control
var _feedback_waiting: Control
var _harvest_effects: Control
var _reward_effects: Control
var _reward_sinks: Array[Vector2] = []
var _presented_bd_triggers: Dictionary = {}
# Presentation-only queues: source ticks, roots and monetary values stay immutable.
var _pending_bd_groups: Dictionary = {}
var _presented_reward_groups: Dictionary = {}
var _presented_circle_bonuses: Dictionary = {}
var _feedback_bd_sources := 0
var _feedback_bd_shown_sources := 0
var _feedback_bd_groups := 0
var _feedback_bd_duplicates := 0
var _feedback_reward_coins := 0
var _feedback_reward_cards := 0
var _feedback_reward_groups := 0
var _feedback_reward_duplicates := 0
var _feedback_reward_invalid := 0
var _feedback_layer: CanvasLayer
var _coin_icon: Texture2D
var _skill_aim: Node3D
var _focus_aim: Node3D
var _presented_skill_events: Dictionary = {}
var _aim_spec: Dictionary = {}
var _status_meshes: Dictionary = {}
var _status_materials: Dictionary = {}
var _material_reduced: Variant = null
var _feedback_obstacle_records: Array = []
var _feedback_sampled_times: Dictionary = {}
var _feedback_cache_clock := -INF
var _feedback_cache_viewport := Vector2.ZERO
# Public observation-only capture predicates; updated from live visual nodes, never simulation.
var performance_trace_enabled := false
var performance_stage_usec: Dictionary = {}

var skill_active_count := 0
var skill_bright_count := 0
var skill_quad_count := 0
var skill_front_quads := 0
var skill_layer_count := 0
var skill_visual_peak := false
var skill_last_kind := ""
var skill_quad_high_water := 0
var skill_active_high_water := 0
var skill_layers_high_water := 0
var skill_batch_draw_calls := 0
const MAX_FULL_DETAIL_SKILLS := 12
const MAX_FOREGROUND_SKILLS := 16
var skill_foreground_count := 0
var skill_full_detail_count := 0
var skill_atlas_count := 0
var skill_atlas_instance_count := 0
var skill_atlas_draw_calls := 0
var skill_total_draw_calls := 0
var _skill_ground_batch: MeshInstance3D
var _skill_front_batch: MeshInstance3D
var _skill_atlas_batch: Node3D
var _skill_batch_revisions: Dictionary = {}
var _skill_batch_merger: RefCounted
var _skill_batch_merger_checked := false

func _ready() -> void:
	_aux_initialize_layout()
	_preparation_feedback.configure(self)
	if OS.has_feature("windows"):
		if not ClassDB.class_exists("RoundCardFeedbackMath"):
			GDExtensionManager.load_extension("res://native/feedback_math/feedback_math.gdextension")
		if ClassDB.class_exists("RoundCardFeedbackMath"):
			_feedback_math = ClassDB.instantiate("RoundCardFeedbackMath")
		if not ClassDB.class_exists("RoundCardGeometryMath"):
			GDExtensionManager.load_extension("res://native/geometry_math/geometry_math.gdextension")
	name = "World"
	_feedback_font = FX_PRIMARY_FONT.duplicate()
	_feedback_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_feedback_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_feedback_font.oversampling = 0.0
	_feedback_font.multichannel_signed_distance_field = true
	_feedback_font.msdf_pixel_range = 8
	_feedback_font.msdf_size = 64
	var fallback: FontFile = FX_FONT.duplicate()
	fallback.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fallback.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	fallback.oversampling = 1.0
	_feedback_font.fallbacks = [fallback]
	_damage_font = FX_FONT.duplicate()
	_arc_damage_font = FX_ARC_FONT.duplicate()
	for pixel_font: FontFile in [_damage_font,_arc_damage_font]:
		pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		pixel_font.oversampling = 1.0
		pixel_font.multichannel_signed_distance_field = false
	_feedback_styles.configure(_damage_font,_arc_damage_font,_feedback_font,DAMAGE_COLORS,FEEDBACK_INK,_geo.texture("res://assets/art/a2/ui/button-normal.png"))
	# Shape the finite combat alphabet before the first damage burst. Font/style/size stay identical.
	for font_size in [24,26,30,36]:
		_feedback_font.get_string_size("-+0123456789金币卡大丰收连破包 ·",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	for item in get_parent().get_property_list():
		if str(item["name"]) == "paused":
			_has_pause_property = true
	_setup_pixel_stage()
	_setup_feedback_canvas()
	_effects = Node3D.new()
	_effects.name = "TransientEffects"
	_stage.add_child(_effects)
	_setup_skill_batches()
	_skill_atlas_batch = AtlasBatch.new()
	_skill_atlas_batch.name = "ActualCombatAtlasBatches"
	_stage.add_child(_skill_atlas_batch)
	_setup_lighting()
	_setup_camera()
	_make_desk()
	_make_dispensers()
	_make_decorations()
	_shadow_material = _soft_material(Color(.149,.227,.192,.36))
	var back_print := ShaderMaterial.new()
	back_print.shader = BACK_SHADER
	back_print.set_shader_parameter("source_texture",_geo.texture(BACK_PATH))
	_back_material = back_print
	_pixel_hit = _geo.texture(PIXEL_HIT_PATH)
	_pixel_break = _geo.texture(BREAK_PATH)
	_guide_material = ShaderMaterial.new()
	_guide_material.shader = CHARGE_SHADER
	_guide_material.render_priority = 90
	_guide_material.set_shader_parameter("guide_only",true)
	_charge_material = ShaderMaterial.new()
	_charge_material.shader = CHARGE_SHADER
	_charge_material.render_priority = 91
	_charge_material.set_shader_parameter("guide_only",false)
	if FileAccess.file_exists(AIM_SPARK_PATH):
		var sparks := _geo.texture(AIM_SPARK_PATH)
		if sparks!=null:
			_charge_material.set_shader_parameter("spark_atlas",sparks)
			_charge_material.set_shader_parameter("use_spark_atlas",true)
			_charge_material.set_shader_parameter("spark_grid",Vector2(4,4))
			_charge_material.set_shader_parameter("spark_frames",16.0)
			_charge_material.set_shader_parameter("spark_fps",30.0)
			_charge_material.set_shader_parameter("spark_cell_px",48.0)
	var aim_size := Vector2.ONE*Rules.SHOT_RADIUS*0.01/GUIDE_UV_RADIUS
	aim_ring = _geo.plane(aim_size,_guide_material,Vector3.ZERO,_stage)
	aim_ring.name = "AimRadius50"
	charge_ring = _geo.plane(aim_size,_charge_material,Vector3.ZERO,_stage)
	charge_ring.name = "ChargeArc"
	aim_ring.visible = false
	charge_ring.visible = false
	_skill_aim = SkillEffect.new()
	_skill_aim.name = "CompiledAimGeometry"
	_stage.add_child(_skill_aim)
	_skill_aim.visible = false
	_focus_aim = SkillEffect.new()
	_focus_aim.name = "FocusCorrectedPoint"
	_stage.add_child(_focus_aim)
	_focus_aim.visible = false
	_prewarm_feedback_assets()

func _prewarm_feedback_assets() -> void:
	# Minimum-size queries shape text; explicitly rasterize MSDF glyphs before combat.
	var rendered: Dictionary = {}
	for character in "-+0123456789金币卡大丰收连破包 ·":
		var code := character.unicode_at(0)
		if not rendered.has(code):
			_feedback_font.render_range(0,Vector2i(64,0),code,code)
			rendered[code] = true
	for font_size in [24,26,30,36]:
		var label := Label.new()
		label.text = "-+0123456789金币卡大丰收连破包 ·"
		_style_feedback_label(label,font_size)
		label.get_minimum_size()
		label.free()
	# Integer multiples of the native 12px face. Rasterize every real cache size,
	# rather than relying on get_string_size() to warm a later combat draw.
	for pixel_font: FontFile in [_damage_font,_arc_damage_font]:
		for font_size in [24,36]:
			var warmed: Dictionary = {}
			for character in "+-0123456789"+BD_ALPHABET:
				var code := character.unicode_at(0)
				if warmed.has(code):
					continue
				warmed[code] = true
				for outline_size in [0,3,4]:
					pixel_font.render_range(0,Vector2i(font_size,outline_size),code,code)
	# Keep imported textures and shared meshes resident so first loot/element use does no disk work.
	for card_id in CardCatalog.card_ids():
		var path := _card_texture_path(str(card_id))
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_geo.texture(path)
	_geo.card_surface()
	for grade in range(5):
		generic_card_texture(grade)
		var torn_material := _geo.pack_material(grade)
		torn_material.set_shader_parameter("damage_level",3)
		_torn_materials[grade] = torn_material
		_geo.pack_surface(grade)
		_geo.pack_torn_half(grade,false)
		_geo.pack_torn_half(grade,true)
	for key in SkillEffect.ELEMENT_ATLASES.values()+["echo","aftershock","harvest_card","harvest_coin","contact","break"]:
		SkillEffect.Atlas.sheet(str(key))
	for element in range(1,9):
		for family in ["pulse","echo","aftershock","chain","penetration","pull"]:
			SkillEffect.Atlas.sheet("%s_E%02d" % [family,element])
	for key in ["chain","penetration","pull","trail"]:
		SkillEffect.Atlas.sheet(key)
	_prewarm_claim_visuals()

func prewarm_web_feedback() -> Dictionary:
	# Main awaits this once before enabling gameplay. No simulation events are used.
	if not OS.has_feature("web"):
		return {"enabled":false,"completed":false,"reason":"native_unchanged"}
	if bool(_web_feedback_warmup.get("completed",false)):
		return _web_feedback_warmup.duplicate(true)
	if _battle or not cards.is_empty():
		return {"enabled":true,"completed":false,"reason":"requires_prebattle_empty_world"}
	_web_feedback_warmup = await WebFeedbackWarmup.run(self)
	return _web_feedback_warmup.duplicate(true)

func web_feedback_warmup_state() -> Dictionary:
	return _web_feedback_warmup.duplicate(true)

func _setup_pixel_stage() -> void:
	_pixel_viewport = SubViewport.new()
	_pixel_viewport.name = "PixelWorld1920"
	_pixel_viewport.own_world_3d = true
	_pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pixel_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_pixel_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_pixel_viewport.gui_disable_input = true
	add_child(_pixel_viewport)
	_stage = Node3D.new()
	_stage.name = "TabletopStage"
	_pixel_viewport.add_child(_stage)
	var layer := CanvasLayer.new()
	layer.name = "PixelWorldPresentation"
	layer.layer = -10
	add_child(layer)
	_pixel_display = TextureRect.new()
	_pixel_display.name = "NearestPixelWorld"
	_pixel_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pixel_display.texture = _pixel_viewport.get_texture()
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_display.stretch_mode = TextureRect.STRETCH_SCALE
	_pixel_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pixel_display)
	_pixel_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resize_pixel_stage()
	get_viewport().size_changed.connect(_resize_pixel_stage)

func _resize_pixel_stage() -> void:
	var size_value := get_viewport().get_visible_rect().size
	if size_value.x<1 or size_value.y<1:
		return
	# Retain the original quantized aspect exactly; raise the raster threefold
	# so authored source pixels survive. Mouse/table projection keeps its frustum.
	_pixel_viewport.size = Vector2i(1920,maxi(1,roundi(640.0*size_value.y/size_value.x))*3)
	_route_operation_feedback(true)

func _setup_feedback_canvas() -> void:
	_feedback_layer = CanvasLayer.new()
	_feedback_layer.name = "LocalCombatFeedback"
	_feedback_layer.layer = -5
	add_child(_feedback_layer)
	_screen_effects = Control.new()
	_screen_effects.name = "FullResolutionFeedback"
	_screen_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(_screen_effects)
	_screen_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_waiting=Control.new()
	_feedback_waiting.name="UnlocatedFeedbackQueue"
	_feedback_waiting.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_feedback_waiting.visible=false
	_feedback_waiting.process_mode=Node.PROCESS_MODE_DISABLED
	_feedback_layer.add_child(_feedback_waiting)
	_feedback_waiting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harvest_effects = Control.new()
	_harvest_effects.name = "HarvestVisualAccents"
	_harvest_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(_harvest_effects)
	_harvest_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_effects = Control.new()
	_reward_effects.name = "GenericGradeRewardFlights"
	_reward_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(_reward_effects)
	_reward_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coin_icon = _geo.texture("res://assets/fx/combat06/coin-icon.png")

func generic_card_texture(grade: int) -> Texture2D:
	return GenericCard.texture(_geo.texture(BACK_PATH),grade)

func set_reward_sinks(sinks: Array[Vector2]) -> void:
	# Five HUD item centres in logical global viewport coordinates, 0..4 actual card grade.
	# A missing HUD has no fabricated 3D destination; the fallback is the departure point.
	_reward_sinks.clear()
	if sinks.size()==5:
		_reward_sinks.append_array(sinks)

func _screen_to_pixel(point: Vector2) -> Vector2:
	return point*Vector2(_pixel_viewport.size)/get_viewport().get_visible_rect().size

func _pixel_to_screen(point: Vector2) -> Vector2:
	return point*get_viewport().get_visible_rect().size/Vector2(_pixel_viewport.size)

func _setup_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#221b35")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d4dce4")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = env
	_stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-61,-31,-16)
	key.light_color = Color("#fff0d6")
	key.light_energy = 0.62
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 24.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 0.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-34,137,0)
	fill.light_color = Color("#d2dbe4")
	fill.light_energy = 0.21
	_stage.add_child(fill)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# A true overhead view needs room for the whole 6m playfield and the
	# dispenser housings, between the fixed top and bottom HUD bands.
	camera.size = 9.2
	camera.position = Vector3(0,12.0,-3.1)
	camera.near = 0.1
	camera.far = 40.0
	_stage.add_child(camera)
	camera.look_at(Vector3(0,0,-3.1),Vector3.FORWARD)
	camera.current = true

func _make_desk() -> void:
	var board_size := Vector2(Rules.TABLE_HALF_WIDTH*.02,Rules.TABLE_DEPTH*.01)
	var board_center := Vector3(0,0,-Rules.TABLE_DEPTH*.005)
	var support_material := StandardMaterial3D.new()
	support_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	support_material.albedo_color = Color("#21182f")
	_geo.box(Vector3(board_size.x+.40,.24,board_size.y+.40),board_center+Vector3(0,-.18,0),support_material,_stage)
	var border_material := StandardMaterial3D.new()
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_material.albedo_color = Color("#65507d")
	var border := _geo.box(Vector3(board_size.x+.24,.055,board_size.y+.24),board_center+Vector3(0,-.029,0),border_material,_stage)
	border.name = "FormalDeskBorder"
	var wood := _geo.print_material(WOOD_PATH,Color("#2c2445"))
	wood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Rhythm art is a complete 2.4:1 ground print; uniform UVs preserve its four-beat border.
	var surface := PlaneMesh.new()
	surface.size = board_size
	_default_desk_material=wood
	var top := _geo.instance(surface,wood,board_center+Vector3(0,.001,0),_stage)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.name = "SolidWoodTable" # Compatibility observation name; now a paper rhythm stage.
	# This whole-table illustration is mapped once, without tiling or the old rail nine-slice.

func _make_emitter() -> void:
	var station := Node3D.new()
	station.name = "HeavyEmitter"
	station.position = Vector3(0,0,-0.14)
	_stage.add_child(station)
	var enamel := _geo.material(Color("#31554e"),0.39,0.28)
	var dark := _geo.material(Color("#263532"),0.69,0.15)
	var brass := _geo.material(Color("#bd945b"),0.37,0.68)
	_geo.box(Vector3(0.72,0.07,0.42),Vector3(0,0.04,0),dark,station)
	_geo.box(Vector3(0.65,0.09,0.35),Vector3(0,0.10,0),enamel,station)
	_geo.box(Vector3(0.51,0.012,0.25),Vector3(0,0.152,0),brass,station)
	_geo.box(Vector3(0.41,0.014,0.17),Vector3(0,0.16,0),dark,station)
	for x in [-0.26,0.26]:
		for z in [-0.11,0.11]:
			_geo.cylinder(0.022,0.014,Vector3(x,0.154,z),brass,station,12)
	for x in [-0.20,0.20]:
		_geo.box(Vector3(0.035,0.055,0.29),Vector3(x,0.19,0),enamel,station)
	# Stationary launcher dock; the aiming/charge rings convey attacks without a hammer model.

func _make_decorations() -> void:
	_decoration = Node3D.new()
	_decoration.name = "IdleDeskAccessories"
	_stage.add_child(_decoration)
	var leather := _geo.material(Color("#424957"),0.88)
	_geo.box(Vector3(1.28,0.05,0.75),Vector3(-4.68,0.025,-5.55),leather,_decoration)
	var paper := _geo.material(Color("#bdc6d1"),0.98)
	_geo.box(Vector3(1.10,0.045,0.65),Vector3(-4.68,0.072,-5.55),paper,_decoration)
	var cover := _geo.box(Vector3(1.18,0.025,0.71),Vector3(-4.68,0.106,-5.55),leather,_decoration)
	cover.rotation_degrees.y = -3.0
	_geo.box(Vector3(0.035,0.007,0.72),Vector3(-4.32,0.125,-5.55),_geo.material(Color("#ef8d1c"),0.77),_decoration)
	var pencil := Node3D.new()
	pencil.position = Vector3(4.92,0.045,-5.70)
	pencil.rotation_degrees.y = -23
	_decoration.add_child(pencil)
	var barrel := _geo.cylinder(0.028,1.08,Vector3.ZERO,_geo.material(Color("#ef8d1c"),0.68),pencil,6)
	barrel.rotation_degrees.x = 90
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.028
	tip.height = 0.16
	tip.radial_segments = 6
	var nib := _geo.instance(tip,paper,Vector3(0,0,-0.62),pencil)
	nib.rotation_degrees.x = -90
	var graphite := _geo.cylinder(0.009,0.045,Vector3(0,0,-0.71),_geo.material(Color("#343a35"),0.78),pencil,6)
	graphite.rotation_degrees.x = 90

func _make_dispensers() -> void:
	for id_value in ["top","left","right"]:
		var station := Node3D.new()
		station.name = "PackDispenser_"+id_value
		station.position = table_to_world(Rules.dispenser_position(id_value,0))
		if id_value!="top":
			station.rotation.y = PI/2.0 if id_value=="left" else -PI/2.0
		_stage.add_child(station)
		var art_material := _geo.print_material(DISPENSER_PATH,Color("#637489"))
		art_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Read the new machine's alpha, but register its exit lip to the same rule edge.
		# Pixel-to-world scale is uniform: no change to top/left/right emission anchors.
		var canvas := Vector2i(384,320)
		var crop := Rect2i(0,60,384,220)
		var mouth_pixel := Vector2(192,272)
		var art_texture := _geo.texture(DISPENSER_PATH)
		if art_texture!=null:
			var pixels := art_texture.get_image()
			if pixels!=null and not pixels.is_empty():
				canvas = pixels.get_size()
				crop = pixels.get_used_rect()
				mouth_pixel = Vector2(canvas)*Vector2(.5,.85)
		var scale_value := .80/float(canvas.x)
		var center_pixel := Vector2(crop.position)+Vector2(crop.size)*.5
		var art_offset := (center_pixel-mouth_pixel)*scale_value
		var art := _geo.instance(_geo.cropped_surface(Vector2(crop.size)*scale_value,canvas,crop),art_material,Vector3(art_offset.x,.025,art_offset.y),station)
		art.name = "FormalDispenserArt"
		var mouth := Node3D.new()
		mouth.name = "EmissionMouth"
		mouth.position = Vector3.ZERO
		station.add_child(mouth)
		station.set_meta("mouth_anchor_px",mouth_pixel)
		station.set_meta("dark_slot_center_px",Vector2(canvas)*Vector2(.5,.7625))
		station.set_meta("art_canvas_px",Vector2(canvas))
		station.set_meta("art_crop_px",crop)
		var light := _geo.box(Vector3(.22,.004,.012),Vector3(0,.030,.003),_geo.material(Color("#ffc34b")),station)
		light.name = "OpenLight"
		_dispensers[id_value] = station
	set_run_options({})

func set_run_options(options: Dictionary) -> void:
	run_options = options.duplicate(true)
	_aim_spec = _presentation_spec(options)
	var element := SkillEffect.element_id(_aim_spec.get("element","E01"))
	if is_instance_valid(_skill_atlas_batch):
		var sheets: Array = []
		for key: String in SkillEffect.Atlas.element_keys(element):
			sheets.append(SkillEffect.Atlas.sheet(key))
		_skill_atlas_batch.prepare(sheets,&"impact",true,256)
		var quality_materials := QualityCatalog.materials(element)
		_skill_atlas_batch.prepare_records(quality_materials,256)
		if DisplayServer.get_name()!="headless" and not _gpu_warmed_elements.has(element) and _effects.get_child_count()==0:
			# An invisible loading draw compiles actual GL materials before the first
			# real burst. It creates no simulation event, reward, VFX node or HUD count.
			var warm_records: Array = []
			for sheet_value in sheets:
				if not sheet_value.is_empty():
					warm_records.append({"sheet":sheet_value,"frame":0,"center":Vector3(0,.08,-3),"right":camera.basis.x,"up":camera.basis.y,"pixel_size":.001,"opacity":0.0,"plane":&"impact","no_depth_test":true})
			for material: Dictionary in quality_materials:
				var warm := material.duplicate()
				warm.merge({"frame":0,"center":Vector3(0,.08,-3),"right":camera.basis.x,"up":camera.basis.y,"pixel_size":.001,"opacity":0.0},true)
				if warm.has("light_sheet"):
					warm["light_opacity"]=0.0
					var compiled := AtlasBatch.compile_quality_record(warm)
					if compiled!=null: warm_records.append(compiled)
				else:
					warm_records.append(warm)
			_skill_atlas_batch.submit(warm_records)
			_gpu_warm_frames_left = 2
			_gpu_warming_element = element
	if is_instance_valid(aim_ring):
		var radius := maxf(1.0,float(_aim_spec.get("radius",Rules.SHOT_RADIUS)))
		(aim_ring.mesh as PlaneMesh).size = Vector2.ONE*radius*.01/GUIDE_UV_RADIUS
		(charge_ring.mesh as PlaneMesh).size = (aim_ring.mesh as PlaneMesh).size
		var color: Color = SkillEffect.ELEMENT_COLORS.get(element,SkillEffect.ELEMENT_COLORS.E01)
		_guide_material.set_shader_parameter("guide_tone",color)
		_guide_material.set_shader_parameter("aim_style",clampi(int(element.substr(1))-1,0,7))
		_charge_material.set_shader_parameter("charge_tone",color)
		_charge_material.set_shader_parameter("aim_style",clampi(int(element.substr(1))-1,0,7))
		_charge_material.set_shader_parameter("ready_tone",color.lightened(.14))
	var ids: Array = options.get("dispenser_ids",["top"])
	for id_value in _dispensers:
		var station: Node3D = _dispensers[id_value]
		var unlocked := ids.has(id_value)
		station.set_meta("unlocked",unlocked)
		station.visible = unlocked
	_sync_dispensers(_dispenser_tick)
	if _torn_materials.size()==5: _prewarm_claim_visuals()

func _presentation_spec(options: Dictionary) -> Dictionary:
	# Read the frozen compiler result. The fallbacks exist only for the old empty-slot interface.
	var spec: Dictionary = options.get("attack_spec",{})
	var geometry: Dictionary = spec.get("presentation_geometry",spec.get("geometry",spec.get("base_geometry",{})))
	var result := geometry.duplicate(true)
	for field in ["shape","radius","width","length","focus_radius","spread_bonus"]:
		if spec.has(field):
			result[field] = spec[field]
	result["element"] = result.get("element",spec.get("element",spec.get("emitter_id",options.get("emitter_id","E01"))))
	if not result.has("radius") and not result.has("width"):
		result["radius"] = Rules.SHOT_RADIUS
	if spec.get("launcher",{}).has("radius"):
		result["radius"] = Rules.AttackSpec.primary_radius(spec)
		result["width"] = float(result.radius)*2.0
	return result

func _is_skill_effect(effect: Node) -> bool:
	return effect is SkillEffect or effect is QualityEffect

func _new_skill_effect(event: Dictionary):
	return QualityEffect.new() if QualityCatalog.handles(event) else SkillEffect.new()

func _skill_presentation_event(event: Dictionary) -> Dictionary:
	# Only committed native pulse zero owns a root's one complete primary blast.
	# Fixtures without a positive integer root keep the original standalone API.
	# Called after event dedup, so a rejected duplicate cannot reserve this slot.
	var root_value: Variant=event.get("root_id")
	if not root_value is int or root_value<=0 or str(event.get("kind","native"))!="native" or int(event.get("pulse_index",0))!=0:
		return event
	var key := "presentation_main/root/%s" % str(root_value)
	var presentation := event.duplicate()
	presentation["presentation_secondary"]=_presented_skill_events.has(key)
	_presented_skill_events[key]=true
	return presentation

func present_skill_event(event: Dictionary, defer_visual: bool = false) -> void:
	var trace_start := Time.get_ticks_usec() if performance_trace_enabled else 0
	# New preparation/burst events have no legacy attack atlas or fake hit.
	if _preparation_feedback.enabled and _preparation_feedback.handles(event):
		_preparation_feedback.present(event)
		return
	# Caller passes committed events. The renderer never schedules extra pulses or chooses targets.
	if not is_instance_valid(_effects):
		return
	if event.has("event_id"):
		var key := "%s/%s/%s" % [str(event.get("kind","native")),str(event.event_id),str(event.get("target_id",""))]
		if _presented_skill_events.has(key):
			return
		_presented_skill_events[key] = true
	var presentation := _skill_presentation_event(event)
	var effect = _new_skill_effect(event)
	effect.batched = true
	effect.external_atlas = true
	effect.name = "Skill_%s_%s" % [str(event.get("kind","native")),str(event.get("event_id","cue"))]
	_effects.add_child(effect)
	effect.view_right = camera.basis.x
	effect.view_up = camera.basis.y
	effect.view_forward = camera.basis.z
	effect.configure(presentation,reduce_effects,false,defer_visual)
	skill_last_kind = str(event.get("kind","native"))
	if performance_trace_enabled: _record_performance_stage("dispatch_skill",trace_start)

func set_combat_state(state: Dictionary) -> void:
	_preparation_feedback.sync_state(state)

func present_prepare_event(event: Dictionary) -> void:
	if _preparation_feedback.handles(event):
		_preparation_feedback.present(event)

func preparation_presentation_snapshot() -> Dictionary:
	return _preparation_feedback.snapshot()

func _present_preparation_wave(event: Dictionary) -> void:
	# The wave is a simultaneous-hit cue. Its outward travel never schedules damage.
	_begin_burst_feedback(event)
	var effect := SkillEffect.new()
	effect.batched = true
	effect.external_atlas = true
	effect.name = "CommittedWholeTableWave"
	_effects.add_child(effect)
	effect.view_right = camera.basis.x
	effect.view_up = camera.basis.y
	effect.view_forward = camera.basis.z
	effect.configure(event,reduce_effects)

func _begin_burst_feedback(event: Dictionary) -> void:
	# A budget belongs to one real attack, independent of live effect count or the
	# previous attack. Required per-pack numbers and wrapper halves never use it.
	var ids: Array = event.get("target_ids",event.get("targets",[])).duplicate()
	var dense := ids.size()>=24
	_burst_feedback_attack = {"root_id":int(event.get("root_id",0)),"source_tick":int(event.get("tick",-1)),"event_id":int(event.get("event_id",0)),"attack_level":SkillEffect.attack_level(event),"target_ids":ids,"hit_ids":[],"claim_ids":[]}
	_burst_feedback_budget = {"hit_sparks":8 if dense else 12,"claim_sparks":6 if dense else 12,"claim_glints":6 if dense else 12,"break_overlays":4 if dense else 8,"dense":dense,"used":{}}

func _burst_take_decor(kind: String, source_event: Dictionary) -> bool:
	if source_event.is_empty() or _burst_feedback_attack.is_empty(): return true
	if int(source_event.get("root_id",-1))!=int(_burst_feedback_attack.root_id) or int(source_event.get("tick",-1))!=int(_burst_feedback_attack.source_tick): return true
	var remaining := int(_burst_feedback_budget.get(kind,0))
	if remaining<=0: return false
	_burst_feedback_budget[kind] = remaining-1
	var used: Dictionary = _burst_feedback_budget.used
	used[kind] = int(used.get(kind,0))+1
	return true

func _burst_record_pack(source_event: Dictionary, id_value: int, kind: String) -> void:
	if source_event.is_empty() or _burst_feedback_attack.is_empty(): return
	if int(source_event.get("root_id",-1))!=int(_burst_feedback_attack.root_id) or int(source_event.get("tick",-1))!=int(_burst_feedback_attack.source_tick): return
	var ids: Array = _burst_feedback_attack[kind]
	if not ids.has(id_value): ids.append(id_value)

func burst_feedback_snapshot() -> Dictionary:
	# The observations below read real geometry, meshes and live pack transforms.
	var waves: Array[Dictionary] = []
	var halves: Array[Dictionary] = []
	for child in _effects.get_children():
		if child.is_queued_for_deletion(): continue
		if child is SkillEffect and str(child.data.get("kind",""))=="burst_wave":
			waves.append({"attack_level":child.burst_attack_level,"source_tick":int(child.data.get("tick",-1)),"root_id":int(child.data.get("root_id",0)),"age":child.age,"duration":child.duration,"reduced":child.reduced,"radii":child.burst_ring_radii.duplicate(),"ring_quads":child.burst_ring_quads.duplicate(),"edge_sweep_quads":child.burst_edge_sweep_quads,"edge_sweep_points":child.burst_edge_sweep_points.duplicate(),"ground_vertices":child.ground_vertices.size(),"tone":child._color})
		elif child is MeshInstance3D and str(child.name).begins_with("TornWrapper"):
			halves.append({"name":str(child.name),"visible":child.visible,"position":child.position,"basis":child.basis,"mesh_vertices":child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()})
	var pack_rows: Array[Dictionary] = []
	for id_value in cards:
		var node: Node3D = cards[id_value]
		pack_rows.append({"id":id_value,"scale":node.get_node("Print").scale,"damage_level":node.get_meta("damage_level"),"hit_flash":(node.get_meta("pack_material") as ShaderMaterial).get_shader_parameter("hit_flash")})
	return {"attack":_burst_feedback_attack.duplicate(true),"decor_budget":_burst_feedback_budget.duplicate(true),"waves":waves,"torn_halves":halves,"packs":pack_rows,"clock":clock_time,"claimed_count":_claimed_visuals.size()}

func present_harvest(position_value: Vector2, count: int) -> void:
	# position_value uses the same logical viewport coordinates as table_to_screen and the HUD.
	# This is an optional decoration around the caller's truthful harvest label, never a reward event.
	if count<2 or reduce_effects or not is_instance_valid(_harvest_effects):
		return
	var sparkle := HarvestSparkle.new()
	_harvest_effects.add_child(sparkle)
	var viewport_rect := get_viewport().get_visible_rect()
	sparkle.configure(Vector2(clampf(position_value.x,viewport_rect.position.x+90.0,viewport_rect.end.x-90.0),clampf(position_value.y,viewport_rect.position.y+36.0,viewport_rect.end.y-36.0)),count,reduce_effects)

func present_bd_trigger(event: Dictionary) -> void:
	var trace_start := Time.get_ticks_usec() if performance_trace_enabled else 0
	if not is_instance_valid(_screen_effects): return
	var text := str(event.get("text",""))
	var mechanic := str(event.get("mechanic",""))
	if text.is_empty() or mechanic.is_empty(): return
	var root_id := int(event.get("root_id",0))
	var unique_key := "%d/%s" % [root_id,mechanic]
	if _presented_bd_triggers.has(unique_key):
		_feedback_bd_duplicates += 1
		return
	_presented_bd_triggers[unique_key] = true
	_feedback_bd_sources += 1
	var source_tick := int(event.get("tick",floori(clock_time*60.0)))
	var family := mechanic.get_slice("_",0)
	if not family.begins_with("C") or family.length()!=3: family=mechanic
	var element := str(event.get("element","E01"))
	var key := "%d/%d/%s/%s" % [source_tick,root_id,family,element]
	if not _pending_bd_groups.has(key):
		_pending_bd_groups[key]={"root_id":root_id,"source_tick":source_tick,"family":family,"element":element,"positions":[],"mechanics":[],"texts":[],"source_ticks":[]}
	var group: Dictionary=_pending_bd_groups[key]
	group.positions.append(SkillEffect.point(event.get("pos",aim_point),aim_point))
	group.mechanics.append(mechanic)
	group.texts.append(text)
	group.source_ticks.append(source_tick)
	# Main's synchronous batch groups only the same committed tick/root/family.
	# Direct API users keep an immediate single-item response.
	if not _feedback_batch_active: _flush_bd_groups()
	if performance_trace_enabled: _record_performance_stage("dispatch_bd",trace_start)

func _flush_bd_groups() -> void:
	if _pending_bd_groups.is_empty(): return
	var pending := _pending_bd_groups.values()
	_pending_bd_groups.clear()
	var root_slots: Dictionary={}
	for group: Dictionary in pending:
		var root_key := "%d/%d" % [int(group.source_tick),int(group.root_id)]
		var slot := int(root_slots.get(root_key,0))
		root_slots[root_key]=slot+1
		_show_bd_group(group,.12+float(slot)*.12)

func _bd_group_text(group: Dictionary) -> String:
	var count: int=group.mechanics.size()
	if count==1:
		var short_names := {"C01_rim":"无界","C01_outer":"天幕","C01_echo":"天幕","C02_finish":"追猎","C03_hunt":"余音","C03_open":"复奏","C04_converge":"共振","C04_overlap":"齐辉","C06_execute":"终结","C11_transfer":"终焉","C12_core":"海啸","C12_extra":"寂灭"}
		return str(short_names.get(str(group.mechanics[0]),str(group.texts[0])))
	var family := str(group.family)
	var index := int(family.substr(1,2))-1 if family.begins_with("C") else -1
	var family_name := str(CardCatalog.FAMILY_NAMES[index]) if index>=0 and index<CardCatalog.FAMILY_NAMES.size() else str(group.texts[0])
	# N counts distinct committed mechanic notices, never chain hops or damage hits.
	return "%s·%d项" % [family_name,count]

func _show_bd_group(group: Dictionary, base_delay: float) -> void:
	if _aux_try_fold_bd(group): return
	var text := _bd_group_text(group)
	var element := str(group.element)
	var style := "chain"
	var lease := _feedback_label_pool.borrow("BDTrigger",style,text,element,_new_feedback_label)
	var label: Label=lease.label
	label.text=text
	label.name="BDTrigger"
	label.set_meta("root_id",int(group.root_id))
	label.set_meta("source_tick",int(group.source_tick))
	label.set_meta("source_ticks",group.source_ticks.duplicate())
	label.set_meta("element",element)
	label.set_meta("family",str(group.family))
	label.set_meta("mechanic",str(group.mechanics[0]))
	label.set_meta("mechanics",group.mechanics.duplicate())
	label.set_meta("source_texts",group.texts.duplicate())
	label.set_meta("source_count",group.mechanics.size())
	label.set_meta("bd_count",group.mechanics.size())
	label.set_meta("bd_trigger",true)
	label.tooltip_text="本时刻 %d 项真实构筑提示：%s" % [group.mechanics.size()," / ".join(group.texts)]
	label.z_index=4 # Independent damage numbers retain visual priority.
	var measured := Vector2(_damage_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+16.0,_damage_font.get_height(24)+8.0)
	var size_value: Vector2=(lease.cold_minimum+Vector2(16,8)).max(measured).ceil()
	label.size=size_value
	var at := Vector2.ZERO
	for position: Vector2 in group.positions: at+=position
	at/=group.positions.size()
	var home := _feedback_position(table_to_world(at),size_value,int(group.root_id),Vector2(0,-70))
	var keepout := _bd_aim_keepout()
	if keepout.has_area(): home=_bd_safe_home(home,size_value,keepout,FEEDBACK_AVOID_LEAD+6.0)
	# Keep the existing read-only scoring + exactly one final owned commit.
	var enqueue := not _aux_waiters.is_empty()
	var placement := {"position":home,"delay":base_delay} if enqueue else _reserve_feedback(label,home,size_value,.64,24.0,base_delay,0.0,false)
	var final := placement if enqueue else _aux_feedback_placement(label,placement.position,size_value,.64,24.0,float(placement.delay),keepout.grow(FEEDBACK_AVOID_LEAD) if keepout.has_area() else keepout)
	var chosen: Vector2=final.position
	placement.delay=final.delay
	label.set_meta("_feedback_immutable",true)
	_commit_feedback(label,home,chosen,size_value,size_value.x,.64,24.0,float(placement.delay))
	label.position=chosen.round()
	label.visible=float(placement.delay)<=0.0
	_screen_effects.add_child(label)
	if enqueue: _aux_hold(label)
	var tween := _tween(label)
	label.set_meta("_aux_tween",tween)
	tween.finished.connect(_aux_tween_finished.bind(label),CONNECT_ONE_SHOT)
	label.set_meta("_aux_tween_length",.64+float(placement.delay))
	if bool(label.get_meta("_aux_waiting",false)):
		tween.set_speed_scale(0.0)
		tween.pause()
		_forget_tween(tween)
	if float(placement.delay)>0.0:
		tween.tween_interval(float(placement.delay))
		tween.tween_callback(func() -> void: label.visible=true)
	_tween_feedback_position(tween,label,.64,24.0)
	tween.parallel().tween_property(label,"modulate:a",0.0,.20).set_delay(.44)
	tween.tween_callback(_retire_feedback_label.bind(label,_generation))
	_feedback_bd_shown_sources+=group.mechanics.size()
	_feedback_bd_groups+=1
	if int(group.root_id)>0: _aux_index_density_row(_aux_density_bd_rows,_aux_bd_key(group),label,"bd")

func _bd_element_color(element: String) -> Color:
	return _feedback_styles.bd_color(element)

func _tween_feedback_position(tween: Tween, label: Label, duration: float, rise: float) -> void:
	# Separate the original cubic trajectory from its operation-area displacement.
	# This hook also permits legacy-motion isolation in the pool regression fixture.
	var start := label.position
	var end := _feedback_float_end(start,rise)
	label.set_meta("_hf_home",start)
	label.set_meta("_hf_end",end)
	label.set_meta("_hf_nominal",start)
	label.set_meta("_hf_offset",Vector2.ZERO)
	label.set_meta("_hf_target",Vector2.ZERO)
	label.set_meta("_hf_side",-1)
	label.set_meta("_hf_clock",clock_time)
	var initialize_last := _begin_feedback_initialization(label)
	_set_feedback_offset(label,Vector2.ZERO,true)
	if initialize_last: _aux_birth_try_append(label)
	else: _aux_birth_reject("owned_init")
	_route_feedback_label(label,_bd_aim_keepout(),true)
	if initialize_last:
		# This newly appended row has not reached the next native score yet. Keep
		# earlier rows and generation, replacing only its final initial trajectory.
		_feedback_owned_records[-1] = label.get_meta("_feedback_record")
		_feedback_initializing_label = null
	tween.tween_method(_move_feedback_label.bind(label),start,end,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _begin_feedback_initialization(label: Label) -> bool:
	var fresh := label==_feedback_pending_init_label and _feedback_pending_init_generation==_feedback_owned_generation
	_feedback_pending_init_label = null
	if not fresh or not _feedback_batch_active or not _feedback_owned_valid or _feedback_owned_clock!=clock_time or _feedback_owned_viewport!=get_viewport().get_visible_rect().size:
		return false
	if _feedback_owned_records.is_empty() or _feedback_owned_records.size()!=_screen_effects.get_child_count() or _screen_effects.get_child(-1)!=label:
		return false
	var record: Array = _feedback_owned_records[-1]
	# Entry can clamp a cold Label to its actual font minimum. Such a row needs
	# the original later snapshot repair, including its metadata update timing.
	if float(record[7])!=label.size.x or (record[6] as Vector2).y!=label.size.y:
		return false
	_feedback_initializing_label = label
	_feedback_batch_initialized = true
	return true

func _feedback_remaining_sweep(label: Label, offset: Vector2) -> Rect2:
	var current: Vector2 = label.get_meta("_hf_nominal")
	var end: Vector2 = label.get_meta("_hf_end")
	return Rect2(current.min(end)+offset,(current-end).abs()+label.size).grow(4.0)

func _feedback_separation(label: Label, keepout: Rect2, offset: Vector2, remaining: bool = true) -> Dictionary:
	var sweep := _feedback_remaining_sweep(label,offset) if remaining else Rect2(Vector2(label.get_meta("_hf_nominal"))+offset,label.size).grow(4.0)
	if not sweep.intersects(keepout):
		return {"offset":offset,"side":int(label.get_meta("_hf_side"))}
	var view := get_viewport().get_visible_rect().size
	var top := maxf(112.0,view.y*.14)
	var bottom := view.y-maxf(112.0,view.y*.16)
	var translations := [Vector2(keepout.position.x-sweep.end.x-FEEDBACK_AVOID_GAP,0),Vector2(keepout.end.x-sweep.position.x+FEEDBACK_AVOID_GAP,0),Vector2(0,keepout.position.y-sweep.end.y-FEEDBACK_AVOID_GAP),Vector2(0,keepout.end.y-sweep.position.y+FEEDBACK_AVOID_GAP)]
	var preferred := int(label.get_meta("_hf_side"))
	var best := INF
	var selected := offset
	var selected_side := preferred
	for side in range(4):
		var candidate: Vector2 = offset+translations[side]
		var rect := _feedback_remaining_sweep(label,candidate)
		if rect.position.x<4 or rect.end.x>view.x-4 or rect.position.y<top-4 or rect.end.y>bottom+4:
			continue
		var score: float = translations[side].length()
		if preferred>=0 and side!=preferred:
			score += 64.0
		if score<best:
			best = score
			selected = candidate
			selected_side = side
	# Legal current circle/strip fits beside the local playfield. If a future
	# geometry fills the whole safe viewport, do not pretend an impossible fit exists.
	return {"offset":selected,"side":selected_side}

func _set_feedback_offset(label: Label, offset: Vector2, force: bool = false) -> void:
	if not force and offset==label.get_meta("_hf_offset"):
		return
	label.set_meta("_hf_offset",offset)
	var home: Vector2 = label.get_meta("_hf_home")
	home += offset
	label.set_meta("feedback_home",home)
	label.set_meta("feedback_offset",home-Vector2(label.get_meta("feedback_origin")))
	if label.has_meta("_feedback_record"):
		var record: Array = label.get_meta("_feedback_record").duplicate()
		record[2] = home
		record[3] = Vector2(label.get_meta("_hf_end"))+offset
		label.set_meta("_feedback_record",record)
	if label==_feedback_initializing_label:
		return
	_feedback_owned_valid = false
	_feedback_owned_clock = -INF
	_feedback_owned_generation += 1

func _route_feedback_label(label: Label, keepout: Rect2, immediate: bool = false) -> void:
	_aux_callback_guard()
	if bool(label.get_meta("_aux_waiting",false)): return
	if not label.has_meta("_hf_home"):
		_aux_callback_publish(label)
		return
	var offset: Vector2 = label.get_meta("_hf_offset")
	var sweep := _feedback_remaining_sweep(label,offset)
	var view := get_viewport().get_visible_rect().size
	var top := maxf(112.0,view.y*.14)-4.0
	var bottom := view.y-maxf(112.0,view.y*.16)+4.0
	var correction := Vector2.ZERO
	if sweep.position.x<4: correction.x = 4-sweep.position.x
	elif sweep.end.x>view.x-4: correction.x = view.x-4-sweep.end.x
	if sweep.position.y<top: correction.y = top-sweep.position.y
	elif sweep.end.y>bottom: correction.y = bottom-sweep.end.y
	offset += correction
	_set_feedback_offset(label,offset)
	if not keepout.has_area():
		label.set_meta("_hf_target",Vector2.ZERO)
		label.position = Vector2(label.get_meta("_hf_nominal"))+offset
		if bool(label.get_meta("bd_trigger",false)): _route_bd_text_overlap(label,keepout)
		elif label.has_meta("damage_value"): _route_damage_text_overlap(label,keepout)
		_aux_callback_publish(label)
		return
	var lead := keepout.grow(FEEDBACK_AVOID_LEAD)
	if not _feedback_remaining_sweep(label,Vector2.ZERO).intersects(lead):
		label.set_meta("_hf_target",Vector2.ZERO)
	else:
		var desired := _feedback_separation(label,lead,offset)
		label.set_meta("_hf_target",desired.offset)
		label.set_meta("_hf_side",desired.side)
	# Never fade/hide a number when a fast mouse movement catches it. Preserve
	# continuity normally; a true overlap requires the smallest safe hard correction.
	if immediate or Rect2(Vector2(label.get_meta("_hf_nominal"))+offset,label.size).grow(4.0).intersects(keepout):
		var safe := _feedback_separation(label,keepout,offset,immediate)
		_set_feedback_offset(label,safe.offset)
		label.set_meta("_hf_side",safe.side)
	label.position = Vector2(label.get_meta("_hf_nominal"))+Vector2(label.get_meta("_hf_offset"))
	if bool(label.get_meta("bd_trigger",false)): _route_bd_text_overlap(label,keepout)
	elif label.has_meta("damage_value"): _route_damage_text_overlap(label,keepout)
	_aux_callback_publish(label)

func _move_feedback_label(nominal: Vector2, label: Label) -> void:
	if not is_instance_valid(label) or label.is_queued_for_deletion():
		return
	label.set_meta("_hf_nominal",nominal)
	var elapsed := maxf(0.0,clock_time-float(label.get_meta("_hf_clock")))
	label.set_meta("_hf_clock",clock_time)
	var offset: Vector2 = label.get_meta("_hf_offset")
	var target: Vector2 = label.get_meta("_hf_target")
	_set_feedback_offset(label,offset.move_toward(target,FEEDBACK_AVOID_SPEED*elapsed))
	_route_feedback_label(label,_operation_keepout)
	label.position = nominal+Vector2(label.get_meta("_hf_offset"))

func _route_operation_feedback(force: bool = false) -> void:
	_aux_advance_waiters()
	if not is_instance_valid(_screen_effects): return
	var keepout := _bd_aim_keepout()
	if not force and keepout==_operation_keepout: return
	_operation_keepout=keepout
	_aux_begin_route()
	# Damage keeps its own values and clock. Establish all numeric reservations
	# first; auxiliary rows then consume the resulting free space.
	for child in _screen_effects.get_children():
		if child is Label and not child.is_queued_for_deletion() and child.has_meta("damage_value"):
			_route_feedback_label(child,keepout)
			_aux_refresh_route(child)
	for child in _screen_effects.get_children():
		if child is Label and not child.is_queued_for_deletion() and not child.has_meta("damage_value"):
			_route_feedback_label(child,keepout)
			_aux_refresh_route(child)
		elif child is Control and not child.is_queued_for_deletion() and child.has_meta("_reward_nominal"):
			_route_reward_popup(child,keepout)
			_aux_refresh_route(child)
	_aux_end_route()
	for child in _reward_effects.get_children():
		if child is RewardFlyer: child.set_operation_keepout(keepout,get_viewport().get_visible_rect().size)

func _aux_end_route() -> void:
	_aux_callback_active=false
	_aux_route_active=false
	_aux_route_peers.clear()
	_aux_route_indices.clear()
	_aux_route_rects.clear()
	_aux_route_starts.clear()
	_aux_route_ends.clear()
	_aux_route_generic.clear()
	_aux_route_order.clear()
	_aux_native_records.clear()
	_aux_damage_records.clear()
	_aux_damage_peers.clear()
	_aux_damage_indices.clear()

func _aux_callback_guard() -> void:
	if not _aux_callback_active: return
	if not is_instance_valid(_screen_effects) or _aux_callback_clock!=clock_time or _aux_callback_generation!=_feedback_owned_generation or _aux_callback_children!=_screen_effects.get_child_count() or _aux_callback_viewport!=get_viewport().get_visible_rect().size or _aux_callback_external!=_aux_external_generation:
		_aux_end_route()

func _aux_ensure_callback_view() -> void:
	if _aux_route_active and not _aux_callback_active: return
	_aux_callback_guard()
	if _aux_callback_active:
		_aux_callback_reuses+=1
		return
	_aux_begin_route()
	_aux_callback_active=true
	_aux_callback_clock=clock_time
	_aux_callback_generation=_feedback_owned_generation
	_aux_callback_children=_screen_effects.get_child_count()
	_aux_callback_viewport=get_viewport().get_visible_rect().size
	_aux_callback_external=_aux_external_generation
	_aux_callback_builds+=1

func _aux_callback_publish(node: Control) -> void:
	if not _aux_callback_active: return
	# Only this renderer's synchronous route wrappers acknowledge their own
	# controlled metadata writes. Unknown generation/lifecycle changes are checked
	# on entry, while home/end/target are published on EVERY exit (also damage).
	if _aux_callback_clock!=clock_time or _aux_callback_children!=_screen_effects.get_child_count() or _aux_callback_external!=_aux_external_generation or not _aux_route_indices.has(node):
		_aux_end_route()
		return
	_aux_refresh_route(node)
	_aux_callback_generation=_feedback_owned_generation

func _feedback_record_end(node: Control, home: Vector2, rise: float) -> Vector2:
	if node.has_meta("_reward_end"):
		return Vector2(node.get_meta("_reward_end"))+Vector2(node.get_meta("_reward_avoid_offset"))
	if node.has_meta("_hf_end"):
		return Vector2(node.get_meta("_hf_end"))+Vector2(node.get_meta("_hf_offset"))
	return _feedback_float_end(home,rise)

func _begin_feedback_batch() -> void:
	# Only Main's synchronous event loop uses this transaction: no await, input,
	# viewport, camera or aim updates occur inside it. Outside it, compute fresh.
	_feedback_batch_active = true
	_feedback_batch_has_keepout = false
	_feedback_batch_initialized = false

func _end_feedback_batch() -> void:
	_flush_bd_groups()
	_feedback_batch_active = false
	_feedback_batch_has_keepout = false
	_feedback_pending_init_label = null
	if _feedback_batch_initialized and _feedback_owned_valid:
		# Incremental ownership is confined to this synchronous event loop.
		# The next batch must still observe later resize/reorder/metadata changes.
		_feedback_owned_valid = false
		_feedback_owned_clock = -INF
		_feedback_owned_generation += 1

func aim_feedback_keepout() -> Rect2:
	# The HUD and local effects use the same complete operation footprint,
	# including emitters whose capsule guide replaces the visible circle.
	return _bd_aim_keepout()

func _bd_aim_keepout() -> Rect2:
	if _feedback_batch_active and _feedback_batch_has_keepout:
		return _feedback_batch_keepout
	var value := _compute_bd_aim_keepout()
	if _feedback_batch_active:
		_feedback_batch_keepout = value
		_feedback_batch_has_keepout = true
	return value

func _compute_bd_aim_keepout() -> Rect2:
	# The new light center circle is not an operation widget. Reserving its full
	# growing area would push real per-pack damage away from the whole table.
	if _preparation_feedback.enabled:
		return Rect2()
	if not _aim_valid or not _battle:
		return Rect2()
	var radius := maxf(1.0,float(_aim_spec.get("radius",Rules.SHOT_RADIUS)))
	var half_length := float(_aim_spec.get("length",0.0))*.5 if str(_aim_spec.get("shape","circle")) in ["capsule","line"] else 0.0
	var direction := (aim_point-Vector2(0,20)).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var rect := Rect2(table_to_screen(aim_point),Vector2.ZERO)
	for end in [-1.0,1.0]:
		for x in [-1.0,1.0]:
			for y in [-1.0,1.0]:
				rect = rect.expand(table_to_screen(aim_point+direction*half_length*end+Vector2(x,y)*radius))
	return rect.grow(12.0)

func _bd_sweep(home: Vector2, size_value: Vector2) -> Rect2:
	return Rect2(home-Vector2(0,24),size_value+Vector2(0,24)).grow(4.0)

func _bd_safe_home(home: Vector2, size_value: Vector2, keepout: Rect2, clearance: float) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var top := maxf(112.0,viewport_size.y*.14)
	var bottom := viewport_size.y-maxf(112.0,viewport_size.y*.16)-size_value.y
	var obstacle := keepout.grow(clearance+6.0)
	var candidates: Array[Vector2] = [home,Vector2(obstacle.position.x-size_value.x-6.0,home.y),Vector2(obstacle.end.x+6.0,home.y),Vector2(home.x,obstacle.position.y-size_value.y-6.0),Vector2(home.x,obstacle.end.y+30.0)]
	var chosen := home
	var closest := INF
	for candidate in candidates:
		candidate = Vector2(clampf(candidate.x,8,viewport_size.x-size_value.x-8),clampf(candidate.y,top,bottom))
		if _bd_sweep(candidate,size_value).intersects(obstacle):
			continue
		var distance := candidate.distance_squared_to(home)
		if distance<closest:
			chosen = candidate
			closest = distance
	# The optional wide safety corridor may not fit near a viewport edge.
	if closest==INF and clearance>0.0:
		return _bd_safe_home(home,size_value,keepout,0.0)
	return chosen

func _setup_skill_batches() -> void:
	for front in [false,true]:
		var body := MeshInstance3D.new()
		body.name = "SkillForegroundBatch" if front else "SkillGroundBatch"
		body.mesh = ArrayMesh.new()
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 48 if front else -58
		body.material_override = mat
		_stage.add_child(body)
		if front:
			_skill_front_batch = body
		else:
			_skill_ground_batch = body

func _refresh_skill_batches(supplied: Variant = null) -> void:
	var revisions: Dictionary = {}
	var active: Array = []
	var changed := false
	var nodes: Array=supplied if supplied is Array else _effect_frame_snapshot().all
	for item in nodes:
		var identity := (item as Node).get_instance_id()
		var value: int
		if item is QualityEffect:
			var effect: QualityEffect=item
			if not effect.batched: continue
			value=effect.revision
		else:
			var effect: SkillEffect=item
			if not effect.batched: continue
			value=effect.revision
		revisions[identity]=value
		active.append(item)
		changed=changed or _skill_batch_revisions.get(identity,-1)!=value
	if not changed and revisions.size()==_skill_batch_revisions.size():
		return
	_skill_batch_revisions = revisions
	var atlas_records: Array = []
	var geometry_active: Array=[]
	for item in active:
		if item is QualityEffect:
			var effect: QualityEffect=item
			atlas_records.append_array(effect.compiled_atlas_records)
			if effect.rendered_quads>0 or effect.front_quads>0: geometry_active.append(effect)
		else:
			var effect: SkillEffect=item
			atlas_records.append_array(effect.atlas_records)
			if effect.rendered_quads>0 or effect.front_quads>0: geometry_active.append(effect)
	var atlas_metrics: Dictionary=_skill_atlas_batch.submit(atlas_records)
	skill_atlas_instance_count=int(atlas_metrics.visible_instances)
	skill_atlas_draw_calls=int(atlas_metrics.draw_calls)
	var merged := _merge_skill_arrays(geometry_active)
	var ground_vertices: PackedVector3Array = merged[0]
	var ground_colors: PackedColorArray = merged[1]
	var front_vertices: PackedVector3Array = merged[2]
	var front_colors: PackedColorArray = merged[3]
	for item in [[_skill_ground_batch,ground_vertices,ground_colors],[_skill_front_batch,front_vertices,front_colors]]:
		var mesh: ArrayMesh = item[0].mesh
		mesh.clear_surfaces()
		if not item[1].is_empty():
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = item[1]
			arrays[Mesh.ARRAY_COLOR] = item[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	skill_batch_draw_calls = (1 if not ground_vertices.is_empty() else 0)+(1 if not front_vertices.is_empty() else 0)

func _merge_skill_arrays(active: Array) -> Array:
	if not _skill_batch_merger_checked:
		_skill_batch_merger_checked = true
		if ClassDB.class_exists("RoundCardGeometryMath"):
			var candidate: RefCounted = ClassDB.instantiate("RoundCardGeometryMath")
			if candidate.has_method("merge"):
				_skill_batch_merger = candidate
	if _skill_batch_merger!=null:
		var sources: Array = []
		for effect in active:
			sources.append([effect.ground_vertices,effect.ground_colors,effect.front_vertices,effect.front_colors])
		var merged: Array = _skill_batch_merger.merge(sources)
		if merged.size()==4:
			return merged
	# The original append path remains available without the native extension and
	# if the helper declines a malformed input. Effect and triangle order are shared.
	var ground_vertices := PackedVector3Array()
	var ground_colors := PackedColorArray()
	var front_vertices := PackedVector3Array()
	var front_colors := PackedColorArray()
	for effect in active:
		ground_vertices.append_array(effect.ground_vertices)
		ground_colors.append_array(effect.ground_colors)
		front_vertices.append_array(effect.front_vertices)
		front_colors.append_array(effect.front_colors)
	return [ground_vertices,ground_colors,front_vertices,front_colors]

func _sample_skill_metrics(supplied: Variant = null) -> void:
	skill_active_count = 0
	skill_bright_count = 0
	skill_quad_count = 0
	skill_front_quads = 0
	skill_layer_count = 0
	skill_foreground_count = 0
	skill_full_detail_count = 0
	skill_atlas_count = 0
	if not is_instance_valid(_effects):
		return
	var active: Array=supplied if supplied is Array else _effect_frame_snapshot().normal
	for item in active:
		if item is QualityEffect:
			var effect: QualityEffect=item
			skill_active_count += 1
			skill_bright_count += 1 if effect.bright_peak else 0
			skill_quad_count += effect.rendered_quads+effect.front_quads
			skill_front_quads += effect.front_quads
			skill_layer_count += effect.layer_count
			skill_foreground_count += 1 if effect.front_quads>0 else 0
			skill_full_detail_count += 1 if effect.visual_detail==2 else 0
			skill_atlas_count += 1 if effect.atlas_visible else 0
		else:
			var effect: SkillEffect=item
			skill_active_count += 1
			skill_bright_count += 1 if effect.bright_peak else 0
			skill_quad_count += effect.rendered_quads+effect.front_quads
			skill_front_quads += effect.front_quads
			skill_layer_count += effect.layer_count
			skill_foreground_count += 1 if effect.front_quads>0 else 0
			skill_full_detail_count += 1 if effect.visual_detail==2 else 0
			skill_atlas_count += 1 if effect.atlas_visible else 0
	skill_visual_peak = skill_bright_count>=3 and skill_active_count>=6 and not reduce_effects
	skill_quad_high_water = maxi(skill_quad_high_water,skill_quad_count)
	skill_active_high_water = maxi(skill_active_high_water,skill_active_count)
	skill_layers_high_water = maxi(skill_layers_high_water,skill_layer_count)
	skill_total_draw_calls = skill_batch_draw_calls+skill_atlas_draw_calls

func _apply_skill_visual_budget(defer_visual: bool = false, supplied: Variant = null) -> void:
	var active: Array=supplied if supplied is Array else _effect_frame_snapshot().normal
	for index in range(active.size()):
		var detail := 2 if index<MAX_FULL_DETAIL_SKILLS else 1 if index<24 else 0
		if active[index] is QualityEffect:
			var effect: QualityEffect=active[index]
			effect.set_visual_budget(detail,index<MAX_FOREGROUND_SKILLS,true,defer_visual)
			if not defer_visual: effect.flush_visual()
		else:
			var effect: SkillEffect=active[index]
			effect.set_visual_budget(detail,index<MAX_FOREGROUND_SKILLS,true,defer_visual)
			if not defer_visual: effect.flush_visual()
	if defer_visual:
		# Preserve all budget updates before the original noncosmetic flush order.
		for item in active:
			if item is QualityEffect:
				var effect: QualityEffect=item
				effect.flush_visual()
			else:
				var effect: SkillEffect=item
				effect.flush_visual()

func _make_status_markers(node: Node3D) -> void:
	var strip := Node3D.new()
	strip.name = "ActualStatusMarkers"
	strip.basis = _pack_face_basis(0.0)
	strip.position = camera.basis.z*(PACK_VIEW_DEPTH+.02)+camera.basis.y*.29
	node.add_child(strip)
	var markers: Array[MeshInstance3D] = []
	for index in range(3):
		if not _status_meshes.has(index):
			var mesh := ImmediateMesh.new()
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(4 if index<2 else 2):
				var at := Vector3.ZERO
				var half := Vector2(.0125,.0125)
				if index==0:
					at = Vector3(cos(float(i)*PI*.5)*.035,0,sin(float(i)*PI*.5)*.035)
				elif index==1:
					at = Vector3((float(i%2)-.5)*.045,0,(float(i)-1.5)*.023)
				else:
					half = Vector2(.010,.0475) if i%2 else Vector2(.0475,.010)
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					mesh.surface_add_vertex(at+Vector3(corner.x*half.x,0,corner.y*half.y))
			mesh.surface_end()
			_status_meshes[index] = mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = [Color("#a36d83"),Color("#c88227"),Color("#99b4b1")][index]
			_status_materials[index] = mat
		var marker := _geo.instance(_status_meshes[index],_status_materials[index],Vector3((float(index)-1.0)*.13,0,0),strip)
		marker.name = ["MarkStatus","ShockStatus","FrostStatus"][index]
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		marker.set_meta("actual_record",{})
		markers.append(marker)
	node.set_meta("status_markers",markers)

func _sync_status_markers(node: Node3D, target: Dictionary, tick: int) -> void:
	var markers: Array = node.get_meta("status_markers")
	var statuses: Dictionary = target.get("statuses",{})
	for index in range(STATUS_FIELDS.size()):
		var field: String = STATUS_FIELDS[index]
		var record: Variant = statuses.get(field,target.get(field,{}))
		var active: bool = record is Dictionary and not record.is_empty() and int(record.get("expires_tick",0))>tick
		var marker: MeshInstance3D = markers[index]
		marker.visible = active
		var actual: Dictionary = record if record is Dictionary else {}
		# The inspection record stays an independent snapshot, but unchanged ticks need no deep copy.
		if marker.get_meta("actual_record")!=actual:
			marker.set_meta("actual_record",actual.duplicate(true))

func _sync_dispensers(tick: int) -> void:
	# Render the same deterministic positions used to spawn packets. No frame-time motion.
	_dispenser_tick = maxi(0,tick)
	for id_value in _dispensers:
		var station: Node3D = _dispensers[id_value]
		station.position = table_to_world(Rules.dispenser_position(str(id_value),_dispenser_tick))

func _make_pack(target: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Pack_%s" % str(target["id"])
	_stage.add_child(node)
	var pack_scale := Rules.PACK_VISUAL_SIZE.x/24.0
	var shadow := _geo.plane(Vector2(.29,.37)*pack_scale,_shadow_material,Vector3(0,-.007,0),node)
	shadow.name = "ContactShadow"
	var visual := Node3D.new()
	visual.name = "Print"
	node.add_child(visual)
	_set_pack_screen_roll(node,fmod(float(target["id"])*2.39996,TAU))
	var grade := clampi(int(target.get("pack_grade",0)),0,4)
	node.set_meta("pack_grade",grade)
	if not _pack_materials.has(grade):
		_pack_materials[grade] = _geo.pack_material(grade,true)
		_apply_wrapper_skin(_pack_materials[grade],grade)
	# Per-instance flash/cracks and unique priority: shared print textures remain shared.
	var material: ShaderMaterial = _pack_materials[grade].duplicate()
	var slot := _allocate_visual_slot(int(target["id"]))
	node.set_meta("visual_slot",slot)
	material.render_priority = -32+slot
	material.set_shader_parameter("hit_flash",0.0)
	material.set_shader_parameter("damage_level",0)
	material.set_shader_parameter("reduced",reduce_effects)
	node.set_meta("pack_material",material)
	node.set_meta("damage_level",-1)
	_pack_materials[grade].set_shader_parameter("reduced",reduce_effects)
	var mesh: ArrayMesh=_skin_pack_mesh(_geo.pack_surface(grade),grade) if _equipped_pack_skin!="default" else _geo.pack_surface(grade)
	var wrapper := _geo.instance(mesh,material,Vector3.ZERO,visual)
	wrapper.name = "FormalPackPNG"
	var damage := Node3D.new()
	damage.name = "DamageMarks"
	damage.scale = Vector3(pack_scale,1,pack_scale)
	visual.add_child(damage)
	# Registered A2 damage textures own the visible folds/tears; no old black geometry crosses the logo.
	damage.visible = false
	if bool(target.get("is_fast",false)):
		var trail := PackTrail.new()
		trail.name = "FastTrail"
		node.add_child(trail)
		var marker := Node3D.new()
		marker.name = "FastMarker"
		marker.scale = Vector3(pack_scale,1,pack_scale)
		node.add_child(marker)
		for i in range(3):
			_geo.box(Vector3(.035,.004,.045),Vector3(.15-i*.025,.02,-.11+i*.04),_geo.material(Color("#ffd58a")),marker)
	_make_status_markers(node)
	_sync_pack_entry_mask(node,str(target.get("state","active")))
	return node

func _sync_pack_entry_mask(node: Node3D, state: String) -> void:
	# Entering prints emerge through the wood-surface clip. Their un-clipped
	# auxiliary shapes stay underneath the frame until the complete pack enters.
	var entered := state=="active"
	node.get_node("ContactShadow").visible = entered
	node.get_node("ActualStatusMarkers").visible = entered
	if node.has_node("FastMarker"):
		node.get_node("FastMarker").visible = entered

func _pack_face_basis(angle: float) -> Basis:
	# Local X/Z are the printed face. Rotate only in the camera plane; this basis has no shear.
	return Basis(camera.basis.x,camera.basis.z,-camera.basis.y).rotated(camera.basis.z,angle)

func _set_pack_screen_roll(node: Node3D, angle: float) -> void:
	node.set_meta("screen_roll",angle)
	var visual: Node3D = node.get_node("Print")
	visual.basis = _pack_face_basis(angle)
	# Orthographic depth shift leaves the projected center at the existing bounded visual-slot root.
	# It also keeps all 60x80du face corners above the desk at every roll and hit scale.
	visual.position = camera.basis.z*PACK_VIEW_DEPTH

func _allocate_visual_slot(id_value: int) -> int:
	if _visual_slots.has(id_value):
		return int(_visual_slots[id_value])
	var occupied := _visual_slots.values()
	for slot in range(MAX_VISUAL_SLOTS):
		if not occupied.has(slot):
			_visual_slots[id_value] = slot
			return slot
	push_error("Visible packet count exceeds the supported 64-slot presentation budget")
	return 0

func _release_card(id_value: int) -> void:
	if _hit_tweens.has(id_value):
		var tween: Tween = _hit_tweens[id_value]
		if tween.is_valid():
			tween.kill()
		_hit_tweens.erase(id_value)
	if cards.has(id_value):
		cards[id_value].queue_free()
		cards.erase(id_value)
	_visual_slots.erase(id_value)

func table_to_world(p: Vector2, layer: int = 0) -> Vector3:
	return Vector3(p.x*0.01,base_y+float(layer)*0.012,-p.y*0.01)

func screen_to_table(screen_position: Vector2) -> Dictionary:
	if camera == null:
		return {"valid":false,"pos":Vector2.ZERO}
	var pixel_position := _screen_to_pixel(screen_position)
	var origin := camera.project_ray_origin(pixel_position)
	var direction := camera.project_ray_normal(pixel_position)
	if absf(direction.y) < 0.001:
		return {"valid":false,"pos":Vector2.ZERO}
	var distance := (base_y-origin.y)/direction.y
	var hit := origin+direction*distance
	var p := Vector2(hit.x*100,-hit.z*100)
	return {"valid":distance>0 and p.x>=-Rules.TABLE_HALF_WIDTH and p.x<=Rules.TABLE_HALF_WIDTH and p.y>=0 and p.y<=Rules.TABLE_DEPTH,"pos":p}

func table_to_screen(p: Vector2) -> Vector2:
	return _pixel_to_screen(camera.unproject_position(table_to_world(p)))

func sync_targets(targets: Array, tick: int) -> void:
	_sync_dispensers(tick)
	var seen: Dictionary = {}
	for target in targets:
		seen[int(target["id"])] = true
	# Reclaim absent instances before allocating newcomers; long sessions never raise by ID.
	for id_value in cards.keys():
		if not seen.has(id_value):
			_release_card(id_value)
	for target in targets:
		var id_value: int = int(target["id"])
		if not cards.has(id_value):
			cards[id_value] = _make_pack(target)
		var node: Node3D = cards[id_value]
		# Spawn flight is the simulation's straight line; only committed gather
		# from/to snapshots receive a short visual interpolation.
		var actual_position := table_to_world(SkillEffect.point(target["pos"]))+Vector3(0,float(_visual_slots[id_value])*SLOT_HEIGHT,0)
		node.position = _preparation_feedback.pack_position(target,actual_position) if _preparation_feedback.enabled else actual_position
		node.visible = _preparation_feedback.pack_visible(id_value)
		var state := str(target["state"])
		if str(node.get_meta("state",""))!=state:
			_sync_pack_entry_mask(node,state)
		node.set_meta("state",state)
		node.set_meta("remaining",float(target["remaining"]))
		_sync_status_markers(node,target,tick)
		var ratio := clampf(float(target["remaining"])/maxf(.001,float(target["max_hp"])),0.0,1.0)
		var level := 0 if ratio>=1.0 else 1 if ratio>.60 else 2 if ratio>.30 else 3
		if int(node.get_meta("damage_level"))!=level:
			node.set_meta("damage_level",level)
			var damage: Node3D = node.get_node("Print/DamageMarks")
			damage.visible = level>0
			for mark in damage.get_children():
				mark.visible = int(mark.get_meta("level"))<=level
			var material: ShaderMaterial = node.get_meta("pack_material")
			material.set_shader_parameter("damage_level",level)
		if bool(target.get("is_fast",false)):
			var trail = node.get_node("FastTrail")
			var velocity: Vector2 = target["velocity"]
			trail.sample(table_to_world(target["pos"]),tick,velocity)

func hit(target: Dictionary, damage: int = 0, style: String = "direct", source_event: Dictionary = {}) -> void:
	var trace_start := Time.get_ticks_usec() if performance_trace_enabled else 0
	var id_value := int(target["id"])
	if not cards.has(id_value):
		return
	var node: Node3D = cards[id_value]
	var visual: Node3D = node.get_node("Print")
	var material: ShaderMaterial = visual.get_node("FormalPackPNG").material_override
	if _hit_tweens.has(id_value) and (_hit_tweens[id_value] as Tween).is_valid():
		(_hit_tweens[id_value] as Tween).kill()
	var level := SkillEffect.attack_level(source_event)
	var full := level=="fever_full"
	var fever_attack := level!="circle"
	var flash := .20 if reduce_effects else .68 if full else .52 if fever_attack else .40
	material.set_shader_parameter("hit_flash",flash)
	# Force travels across the wrapper face: compression, a short recoil, settle.
	# Damage texture remains owned by sync_targets' actual remaining/max_hp ratio.
	visual.scale = Vector3(1.012,1.0,.96) if reduce_effects else Vector3(1.10 if full else 1.065 if fever_attack else 1.035,1.0,.72 if full else .80 if fever_attack else .88)
	var tween := _tween(visual)
	_hit_tweens[id_value] = tween
	if reduce_effects:
		tween.tween_property(visual,"scale",Vector3.ONE,.18)
	else:
		tween.tween_property(visual,"scale",Vector3(.97,1.0,1.07),.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual,"scale",Vector3.ONE,.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(value: float) -> void: material.set_shader_parameter("hit_flash",value),flash,0.0,.18)
	_burst_record_pack(source_event,id_value,"hit_ids")
	if damage>0:
		var text := "-"+str(damage)
		_float_text(text,node.position,Color.WHITE,DAMAGE_NUMBER_DURATION,0.0,"DamageNumber",id_value,style)
	if not reduce_effects and _burst_take_decor("hit_sparks",source_event):
		_contact_sparks(node.position,id_value,2 if bool(_burst_feedback_budget.get("dense",false)) else 3)
	if performance_trace_enabled: _record_performance_stage("dispatch_hit",trace_start)

func claim(target: Dictionary, reward: Dictionary = {}, show_popup: bool = true, source_event: Dictionary = {}) -> void:
	var trace_start := Time.get_ticks_usec() if performance_trace_enabled else 0
	var id_value := int(target["id"])
	if _claimed_visuals.has(id_value):
		return
	_claimed_visuals[id_value] = true
	_burst_record_pack(source_event,id_value,"claim_ids")
	var start := table_to_world(target["pos"])
	var rotation_value := fmod(float(id_value)*2.39996,TAU)
	if cards.has(id_value):
		start = cards[id_value].position
		rotation_value = float(cards[id_value].get_meta("screen_roll",rotation_value))
	_release_card(id_value)
	var grade := clampi(int(target.get("pack_grade",0)),0,4)
	# Every real break keeps its grade-accurate two halves, including 48-pack and
	# reduced modes. Only supplementary light/sparks/overlay share the event budget.
	_torn_wrapper(start,grade,rotation_value,SkillEffect.attack_level(source_event),id_value)
	if _burst_take_decor("claim_glints",source_event):
		_glint(start,.68,Color(1.0,.85,.55,.20 if reduce_effects else .45),.16)
	if not reduce_effects:
		if _burst_take_decor("claim_sparks",source_event): _contact_sparks(start,id_value,4 if bool(_burst_feedback_budget.get("dense",false)) else 7)
		if _burst_take_decor("break_overlays",source_event): _break_burst(start,grade)
	if performance_trace_enabled: trace_start = _record_performance_stage("claim_break",trace_start)
	# Group actual card grades from this claim. Each nonzero grade is visible, including
	# a low-grade reward alongside a premium card; family identities remain in the ledger.
	var loot: Dictionary = reward.get("cards",{})
	var variants: Array = loot.keys().filter(func(variant: Variant) -> bool: return int(loot[variant])>0)
	variants.sort_custom(func(a: String,b: String) -> bool:
		var ga := int(a.get_slice("-",1))
		var gb := int(b.get_slice("-",1))
		return ga>gb if ga!=gb else a<b
	)
	var card_count := 0
	var by_grade: Array[int] = [0,0,0,0,0]
	for variant in variants:
		var amount := maxi(0,int(loot[variant]))
		card_count += amount
		by_grade[clampi(int(str(variant).get_slice("-",1)),0,4)] += amount
	var shown := 0
	for actual_grade in range(5):
		if by_grade[actual_grade]>0:
			_fly_reward_grade(actual_grade,by_grade[actual_grade],start,shown)
			shown += 1
	if int(reward.get("coins",0))>0:
		_fly_coin(start)
	if performance_trace_enabled: trace_start = _record_performance_stage("claim_flights",trace_start)
	if show_popup:
		_reward_popup(start,int(reward.get("coins",0)),card_count,str(variants[0]) if not variants.is_empty() else "",id_value)
	if performance_trace_enabled: _record_performance_stage("claim_popup",trace_start)

func present_circle_bonus(total: int, count: int, root_id: int) -> void:
	# Main sums only actual in-circle claims for this root. The amount is already
	# multiplied in the ledger; only its multiplier is shown, never a second sum.
	if total<=0 or count<=0 or root_id<=0 or _presented_circle_bonuses.has(root_id): return
	_presented_circle_bonuses[root_id] = true
	var circle_multiplier := float(run_options.get("circle_coin_percent",120))/100.0
	var multiplier_text := String.num(circle_multiplier,2)
	var text := "×"+multiplier_text
	var lease := _feedback_label_pool.borrow("CircleCoinBonus","direct",text,"",_new_feedback_label)
	var label: Label = lease.label
	label.name = "CircleCoinBonus"
	label.set_meta("root_id",root_id)
	label.set_meta("circle_coins",total)
	label.set_meta("circle_destroyed",count)
	label.set_meta("circle_bonus",true)
	label.set_meta("circle_multiplier",circle_multiplier)
	label.set_meta("_feedback_immutable",true)
	label.tooltip_text = "%d个圈内卡包，金额已含圈内×%s" % [count,multiplier_text]
	label.modulate = Color.WHITE
	label.scale = Vector2.ONE
	label.pivot_offset = Vector2.ZERO
	label.add_theme_color_override("font_color",Color("#f3cf79"))
	label.z_index = 4
	var measured := Vector2(_feedback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x+16.0,_feedback_font.get_height(26)+8.0)
	var size_value: Vector2 = (lease.cold_minimum+Vector2(16,8)).max(measured).ceil()
	label.size = size_value
	label.pivot_offset = size_value*.5
	if not reduce_effects: label.scale = Vector2.ONE*.86
	var rise := 0.0 if reduce_effects else 24.0
	var at: Vector2 = _preparation_feedback.center if _preparation_feedback.enabled else aim_point
	var home := _feedback_position(table_to_world(at),size_value,root_id,Vector2(0,-12))
	if _preparation_feedback.enabled:
		# Keep the short multiplier attached to the circle's lower rim, away
		# from the individual coin pickups and their paths toward the HUD.
		var circle_screen := table_to_screen(at)
		var lower_rim := circle_screen.y
		for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			lower_rim = maxf(lower_rim,table_to_screen(at+direction*_preparation_feedback.radius).y)
		home = _feedback_position_projected(Vector2(circle_screen.x,lower_rim+size_value.y*.5+8.0),size_value,root_id,Vector2.ZERO)
	var keepout := _bd_aim_keepout()
	if keepout.has_area(): home = _bd_safe_home(home,size_value,keepout,FEEDBACK_AVOID_LEAD+6.0)
	# Use the same safe auxiliary placement/queue as existing construction rows;
	# damage keeps every real per-pack number and its original priority/lifetime.
	var enqueue := not _aux_waiters.is_empty()
	var placement := {"position":home,"delay":0.0} if enqueue else _reserve_feedback(label,home,size_value,.64,rise,0.0,0.0,false)
	var final := placement if enqueue else _aux_feedback_placement(label,placement.position,size_value,.64,rise,float(placement.delay),keepout)
	var chosen: Vector2 = final.position
	placement.delay = final.delay
	_commit_feedback(label,home,chosen,size_value,size_value.x,.64,rise,float(placement.delay))
	label.position = chosen.round()
	label.visible = float(placement.delay)<=0.0
	_screen_effects.add_child(label)
	if enqueue: _aux_hold(label)
	var tween := _tween(label)
	label.set_meta("_aux_tween",tween)
	tween.finished.connect(_aux_tween_finished.bind(label),CONNECT_ONE_SHOT)
	label.set_meta("_aux_tween_length",.64+float(placement.delay))
	if bool(label.get_meta("_aux_waiting",false)):
		tween.set_speed_scale(0.0)
		tween.pause()
		_forget_tween(tween)
	if float(placement.delay)>0.0:
		tween.tween_interval(float(placement.delay))
		tween.tween_callback(func() -> void: label.visible = true)
	_tween_feedback_position(tween,label,.64,rise)
	tween.parallel().tween_property(label,"modulate:a",0.0,.20).set_delay(.44)
	if not reduce_effects:
		# The small settle stays within scale 1, so the existing reserved sweep
		# contains every animated frame and keeps real damage's higher priority.
		tween.parallel().tween_method(func(progress: float) -> void:
			var value: float
			if progress<.5: value = lerpf(.86,1.0,sin(progress*PI))
			elif progress<.75: value = lerpf(1.0,.97,(progress-.5)*4.0)
			else: value = lerpf(.97,1.0,(progress-.75)*4.0)
			label.scale = Vector2.ONE*value
		,0.0,1.0,.22)
	tween.tween_callback(_retire_feedback_label.bind(label,_generation))

func present_reward_group(summary: Dictionary, position_override: Variant = null) -> void:
	if not _feedback_amount_valid(summary.get("coins")) or not _feedback_amount_valid(summary.get("cards")) or not _feedback_amount_valid(summary.get("destroyed")):
		_feedback_reward_invalid+=1
		return
	var positions: Variant=summary.get("claim_positions",[])
	if int(summary.destroyed)<(1 if bool(summary.get("high_density_feedback",false)) else 2) or not positions is Array or positions.is_empty(): return
	var center := Vector2.ZERO
	for point_value: Variant in positions:
		var point := SkillEffect.point(point_value,Vector2.INF)
		if not point.is_finite():
			_feedback_reward_invalid+=1
			return
		center+=point
	center/=positions.size()
	var source_tick: Variant=summary.get("display_tick",summary.get("tick",summary.get("source_tick",null)))
	# Main supplies the original committed tick even when its truthful summary waits
	# in a UI queue. The fallback is only for direct legacy presentation callers.
	var tick_key := str(int(source_tick)) if source_tick is int or source_tick is float else "clock:"+String.num(clock_time,9)
	var key := "%d/%s" % [int(summary.get("root_id",0)),tick_key]
	if _presented_reward_groups.has(key):
		_feedback_reward_duplicates+=1
		return
	_presented_reward_groups[key]=true
	_reward_popup(table_to_world(center),int(summary.coins),int(summary.cards),"",int(summary.get("root_id",0)),summary,position_override)

func _feedback_amount_valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0.0 and float(value)==floorf(float(value))

func reward_group_popup_size(summary: Dictionary) -> Vector2:
	return _reward_row_size(int(summary.get("coins",0)),int(summary.get("cards",0)))

func _reward_row_size(coins: int, card_count: int) -> Vector2:
	var width := 14.0
	var items := 0
	for amount in [coins,card_count]:
		if amount<=0: continue
		var digits := _feedback_font.get_string_size("+%d" % amount,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x if _feedback_font!=null else float(str(amount).length()+1)*16.0
		width+=26.0+6.0+digits+4.0
		items+=1
	if items>1: width+=6.0
	return Vector2(maxf(84.0,ceilf(width)),44.0)

func _fly_reward_grade(grade: int, count: int, start: Vector3, index: int) -> void:
	var origin := _pixel_to_screen(camera.unproject_position(start))
	var sink := _reward_sinks[grade] if _reward_sinks.size()==5 else origin
	var node := RewardFlyer.new()
	_reward_effects.add_child(node)
	if _preparation_feedback.enabled: node.flight_duration = .52
	node.configure(generic_card_texture(grade),origin,sink,grade,count,index,_damage_font,reduce_effects)
	node.set_operation_keepout(_bd_aim_keepout(),get_viewport().get_visible_rect().size)
	node.arrived.connect(func() -> void: reward_collected.emit())

func _fly_coin(start: Vector3) -> void:
	var loan := _claim_visual_pool.borrow(["coin"],_new_claim_coin)
	var coin: MeshInstance3D = loan.node
	coin.name = "RewardCoins"
	coin.visible = true
	coin.transform = Transform3D(Basis.IDENTITY,start)
	_effects.add_child(coin)
	var tween := _tween(coin)
	_claim_visual_tweens[int(loan.token)] = tween
	tween.tween_method(func(value: float) -> void:
		# In an overhead view world-Y only changes depth. Keep the pickup arc
		# visible in the screen plane, while its departure and sink stay exact.
		coin.position = start.lerp(_coin_sink,smoothstep(0.0,1.0,value))+camera.basis.y*sin(value*PI)*.44
		coin.rotation.z = value*TAU
		coin.scale = Vector3.ONE*(1.0-value*.7)
	,0.0,1.0,.32)
	tween.tween_callback(_retire_claim_visual.bind(coin,_generation,int(loan.token)))

func _float_text(value: String, at: Vector3, color: Color, duration: float, delay: float, kind: String, id_value: int = 0, damage_style: String = "direct") -> void:
	var trace_start := Time.get_ticks_usec() if performance_trace_enabled else 0
	var normalized_style := damage_style if DAMAGE_COLORS.has(damage_style) else "direct"
	var lease := _feedback_label_pool.borrow(kind,normalized_style,value,"",_new_feedback_label)
	var label: Label = lease.label
	var cold_minimum: Vector2 = lease.cold_minimum
	label.set_meta("_feedback_immutable",true)
	label.name = kind
	var ink_width := cold_minimum.x+8.0
	var ink_height := cold_minimum.y
	if kind=="DamageNumber":
		label.set_meta("damage_value",absi(int(value)))
		# Resolve the immutable explicit Theme while detached. Detached Label cold
		# minimum uses the default font until tree entry, which is smaller than the
		# actual 24/36px damage glyphs. Do not force a theme notification/add early.
		var registration := _aux_damage_registration(value,normalized_style)
		ink_width=maxf(ink_width,float(registration.width))
		ink_height=maxf(ink_height,float(registration.height))
		label.set_meta("_aux_damage_ink_cache",registration.cache)
	var feedback_size := Vector2(maxf(180.0,cold_minimum.x+12.0),maxf(56.0,cold_minimum.y))
	if kind=="DamageNumber": feedback_size=feedback_size.max(Vector2(ink_width+12.0,ink_height))
	label.custom_minimum_size.y = feedback_size.y
	label.size = feedback_size
	label.modulate = color
	if kind=="DamageNumber": label.add_theme_color_override("font_color",Color.WHITE)
	label.z_index = 5
	var projected := _pixel_to_screen(camera.unproject_position(at))
	var offset := Vector2(0,-40)
	if kind=="DamageNumber" and cards.has(id_value):
		# Billboard faces are now tall at every angle: place damage above the actual projected edge.
		offset.y = _pack_screen_top(cards[id_value])-projected.y-26
	label.position = _feedback_position_projected(projected,feedback_size,id_value,offset)
	var placement := _reserve_feedback(label,label.position,feedback_size,duration,42.0,delay,ink_width)
	label.position = placement.position
	var actual_delay: float = placement.delay
	label.visible = actual_delay<=0.0
	_screen_effects.add_child(label)
	var tween := _tween(label)
	tween.tween_interval(actual_delay)
	if actual_delay>0:
		tween.tween_callback(func() -> void: label.visible = true)
	_tween_feedback_position(tween,label,duration,42.0)
	# Keep each damage value fully readable, then retire its opacity quickly.
	var fade_duration := minf(DAMAGE_NUMBER_FADE,duration) if kind=="DamageNumber" else duration*.45
	var fade_delay := duration-fade_duration if kind=="DamageNumber" else duration*.55
	tween.parallel().tween_property(label,"modulate:a",0.0,fade_duration).set_delay(fade_delay)
	tween.tween_callback(_retire_feedback_label.bind(label,_generation))
	if performance_trace_enabled: _record_performance_stage("float_text",trace_start)

func _new_feedback_label(kind: String, style: String, text: String, element: String) -> Label:
	var label := Label.new()
	label.name = kind
	label.text = text
	if kind=="BDTrigger":
		_style_pixel_damage(label,style)
		label.add_theme_font_override("font",_damage_font)
		label.add_theme_font_size_override("font_size",24)
		label.add_theme_color_override("font_color",_bd_element_color(element))
	elif kind=="DamageNumber":
		_style_pixel_damage(label,style)
	elif kind=="CircleCoinBonus":
		_style_feedback_label(label,26)
		label.add_theme_constant_override("outline_size",3)
	else:
		_style_feedback_label(label,36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _retire_feedback_label(label: Label, generation: int) -> void:
	# Let the completed node-bound Tween return before detaching/freeing its node.
	_return_feedback_label.call_deferred(label,generation)

func _return_feedback_label(label: Label, generation: int) -> void:
	if not is_instance_valid(label) or label.is_queued_for_deletion():
		return
	if generation!=_generation or not is_inside_tree():
		label.queue_free()
		return
	var parent := label.get_parent()
	if parent!=_screen_effects:
		return
	if label.has_meta("circle_bonus"):
		label.scale = Vector2.ONE
		label.pivot_offset = Vector2.ZERO
	parent.remove_child(label)
	_feedback_owned_valid = false
	_feedback_owned_clock = -INF
	_feedback_owned_generation += 1
	if not _feedback_label_pool.release_detached(label) and is_instance_valid(label):
		label.queue_free()

func _exit_tree() -> void:
	_feedback_label_pool.clear()
	_claim_visual_pool.clear()
	_claim_visual_tweens.clear()

func _style_pixel_damage(label: Label, style: String) -> void:
	style = style if DAMAGE_COLORS.has(style) else "direct"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.theme = _feedback_styles.damage_theme(style)
	label.set_meta("damage_style",style)
	label.set_meta("pixel_feedback",true)

func _style_feedback_label(label: Label, font_size: int = 30) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.theme = _feedback_styles.ordinary_theme(font_size)

func _pack_screen_top(node: Node3D) -> float:
	var body: MeshInstance3D = node.get_node("Print/FormalPackPNG")
	var box := body.mesh.get_aabb()
	# Cache only the original four local corners, keyed by the exact AABB value.
	# Live transforms/projection are still evaluated on every call, including hits.
	if not _pack_feedback_corners.has(box):
		if _pack_feedback_corners.size()>=64:
			_pack_feedback_corners.erase(_pack_feedback_corners.keys()[0])
		_pack_feedback_corners[box] = PackedVector3Array([
			Vector3(box.position.x,.005,box.position.z),Vector3(box.position.x,.005,box.end.z),
			Vector3(box.end.x,.005,box.position.z),Vector3(box.end.x,.005,box.end.z)])
	var corners: PackedVector3Array = _pack_feedback_corners[box]
	var screen_size := get_viewport().get_visible_rect().size
	var pixel_size := Vector2(_pixel_viewport.size)
	var top := INF
	for corner in corners:
		# Preserve multiply-then-divide and the original min/projection order.
		top = minf(top,(camera.unproject_position(body.to_global(corner))*screen_size/pixel_size).y)
	return top

func _card_texture_path(variant: String) -> String:
	var definition := CardCatalog.card_definition(variant)
	if definition.is_empty():
		return BACK_PATH
	# The directory id names an independent card; art_variant is its unique source
	# bitmap. Its source suffix does not change the real reward/foil grade.
	var art_variant := str(definition.get("art_variant",variant))
	return FRONT_PATH % [art_variant.get_slice("-",0),int(art_variant.get_slice("-",1))]

func _feedback_position(at: Vector3, size_value: Vector2, id_value: int, offset: Vector2) -> Vector2:
	return _feedback_position_projected(_pixel_to_screen(camera.unproject_position(at)),size_value,id_value,offset)

func _feedback_position_projected(projected: Vector2, size_value: Vector2, id_value: int, offset: Vector2) -> Vector2:
	var point := projected+offset
	point += Vector2((id_value%3-1)*16,-(id_value%2)*10)
	var rect := get_viewport().get_visible_rect().size
	var top_margin := maxf(112.0,rect.y*.14)
	var bottom_margin := maxf(112.0,rect.y*.16)
	return Vector2(clampf(point.x-size_value.x*.5,8,rect.x-size_value.x-8),clampf(point.y-size_value.y*.5,top_margin,rect.y-size_value.y-bottom_margin))

func _feedback_float_end(start: Vector2, rise: float) -> Vector2:
	return Vector2(start.x,maxf(maxf(112.0,get_viewport().get_visible_rect().size.y*.14),start.y-rise))

func _reserve_feedback(node: Control, home: Vector2, size_value: Vector2, duration: float, rise: float, base_delay: float = 0.0, ink_width: float = 0.0, commit: bool = true) -> Dictionary:
	# Freeze this synchronous placement's inputs once. Timing, candidate order, exact rectangles,
	# overlap summation order and the first zero-overlap exit stay identical to the original search.
	var viewport_size := get_viewport().get_visible_rect().size
	var top := maxf(112.0,viewport_size.y*.14)
	var bottom := viewport_size.y-maxf(112.0,viewport_size.y*.16)-size_value.y
	var width := size_value.x if ink_width<=0.0 else ink_width
	var chosen := home
	var chosen_delay := base_delay
	var best_score := INF
	var finished := false
	if _feedback_math!=null:
		var score_trace := Time.get_ticks_usec() if performance_trace_enabled else 0
		var records := _owned_feedback_snapshot()
		if performance_trace_enabled: score_trace = _record_performance_stage("feedback_snapshot",score_trace)
		var selected: Vector2i
		if _feedback_owned_valid:
			selected = _feedback_math.score_owned(records,home,size_value,viewport_size,clock_time,duration,rise,base_delay,ink_width,_feedback_owned_generation)
		else:
			selected = _feedback_math.score(records,home,size_value,viewport_size,clock_time,duration,rise,base_delay,ink_width)
		if performance_trace_enabled: _record_performance_stage("feedback_score",score_trace)
		if selected.x>=0 and selected.x<FEEDBACK_OFFSETS.size() and selected.y>=0 and selected.y<13:
			var pos: Vector2 = home+FEEDBACK_OFFSETS[selected.x]
			chosen = Vector2(clampf(pos.x,8.0,viewport_size.x-size_value.x-8),clampf(pos.y,top,bottom))
			chosen_delay = base_delay+float(selected.y)*.10
			return _commit_feedback(node,home,chosen,size_value,width,duration,rise,chosen_delay) if commit else {"position":chosen,"delay":chosen_delay}
	var records: Array = []
	var obstacles: Dictionary = {}
	for other in _screen_effects.get_children():
		if other is Control and other.has_meta("feedback_start") and not other.is_queued_for_deletion():
			var other_home: Vector2 = other.get_meta("feedback_home")
			var other_rise := float(other.get_meta("feedback_rise"))
			var other_width := float(other.get_meta("feedback_width"))
			var index := records.size()
			records.append([float(other.get_meta("feedback_start")),float(other.get_meta("feedback_end")),other_home,_feedback_record_end(other,other_home,other_rise),float(other.get_meta("feedback_duration")),Vector2((other.size.x-other_width)*.5,0),Vector2(other_width,other.size.y)])
			if absf(other_home.x-home.x)<maxf(size_value.x,other.size.x)+165 and absf(other_home.y-home.y)<220:
				obstacles[index] = true
	_feedback_update_cache(records,viewport_size)
	var candidates: Array = []
	for offset in FEEDBACK_OFFSETS:
		var pos: Vector2 = home+offset
		pos = Vector2(clampf(pos.x,8.0,viewport_size.x-size_value.x-8),clampf(pos.y,top,bottom))
		if pos.distance_to(home)>80.01:
			continue
		var rects: Array[Rect2] = []
		var cells: Array = []
		for sample in FEEDBACK_SAMPLES:
			var progress := clampf(float(sample)/duration,0,1)
			var projected := pos.lerp(_feedback_float_end(pos,rise),1-pow(1-progress,3))
			var rect := Rect2(projected+Vector2((size_value.x-width)*.5,0),Vector2(width,size_value.y)).grow(3)
			rects.append(rect)
			cells.append(_feedback_grid_cells(rect))
		candidates.append([pos,offset.length()*.02,rects,cells])
		if obstacles.is_empty():
			break
	for step in range(13):
		var delay_value := base_delay+float(step)*.10
		var slices: Array = []
		for sample in FEEDBACK_SAMPLES:
			var at_time: float = clock_time+delay_value+float(sample)
			# Float keys are the actual original sample times, with no rounding/quantization.
			if obstacles.is_empty():
				slices.append([{},{}])
			else:
				if not _feedback_sampled_times.has(at_time):
					_feedback_sampled_times[at_time] = _feedback_sample_grid(records,at_time)
				slices.append(_feedback_sampled_times[at_time])
		for candidate in candidates:
			var overlap := 0.0
			var pruned := false
			for sample_index in range(FEEDBACK_SAMPLES.size()):
				var slice: Array = slices[sample_index]
				var grid: Dictionary = slice[1]
				var possible: Dictionary = {}
				for cell in candidate[3][sample_index]:
					for index in grid.get(cell,[]):
						if obstacles.has(index):
							possible[index] = true
				var indices: Array = possible.keys()
				indices.sort()
				var rect: Rect2 = candidate[2][sample_index]
				for index in indices:
					var intersect := rect.intersection(slice[0][index])
					if intersect.has_area():
						overlap += intersect.get_area()
						# Positive remaining intersections can only increase this exact lower bound.
						# Do not prune zero overlap: the original search exits on that candidate.
						if overlap>.001 and overlap+float(candidate[1])+delay_value*.1>=best_score:
							pruned = true
							break
				if pruned:
					break
			if pruned:
				continue
			var score: float = overlap+float(candidate[1])+delay_value*.1
			if score<best_score:
				best_score = score
				chosen = candidate[0]
				chosen_delay = delay_value
			if overlap<=.001:
				finished = true
				break
		if finished:
			break
	return _commit_feedback(node,home,chosen,size_value,width,duration,rise,chosen_delay) if commit else {"position":chosen,"delay":chosen_delay}

func _owned_feedback_snapshot() -> Array:
	# Only renderer-owned rows have immutable metadata. Generic Controls retain the full
	# read path, including deliberate same-clock metadata/size/reorder mutation in tests.
	var viewport_size := get_viewport().get_visible_rect().size
	if _feedback_owned_valid and _feedback_owned_clock==clock_time and _feedback_owned_viewport==viewport_size and _feedback_owned_records.size()==_screen_effects.get_child_count():
		return _feedback_owned_records
	var records: Array = []
	var all_owned := true
	for other in _screen_effects.get_children():
		if not other is Control or not other.has_meta("feedback_start") or other.is_queued_for_deletion():
			all_owned = false
			continue
		if bool(other.get_meta("_feedback_immutable",false)) and other.has_meta("_feedback_record"):
			var record: Array = other.get_meta("_feedback_record")
			if _feedback_owned_viewport!=viewport_size or float(record[7])!=other.size.x or (record[6] as Vector2).y!=other.size.y:
				record = record.duplicate()
				record[3] = _feedback_record_end(other,record[2],float(other.get_meta("feedback_rise")))
				record[5] = Vector2((other.size.x-float(other.get_meta("feedback_width")))*.5,0)
				record[6] = Vector2(float(other.get_meta("feedback_width")),other.size.y)
				record[7] = other.size.x
				other.set_meta("_feedback_record",record)
			records.append(record)
		else:
			all_owned = false
			var home: Vector2 = other.get_meta("feedback_home")
			var rise := float(other.get_meta("feedback_rise"))
			var width := float(other.get_meta("feedback_width"))
			records.append([float(other.get_meta("feedback_start")),float(other.get_meta("feedback_end")),home,_feedback_record_end(other,home,rise),float(other.get_meta("feedback_duration")),Vector2((other.size.x-width)*.5,0),Vector2(width,other.size.y),float(other.size.x)])
	_feedback_owned_generation += 1
	_feedback_owned_viewport = viewport_size
	_feedback_owned_clock = clock_time
	_feedback_owned_valid = all_owned
	_feedback_owned_records = records
	return records

func _commit_feedback(node: Control, home: Vector2, chosen: Vector2, size_value: Vector2, width: float, duration: float, rise: float, chosen_delay: float) -> Dictionary:
	_feedback_pending_init_label = null
	node.set_meta("feedback_origin",home)
	node.set_meta("feedback_offset",chosen-home)
	node.set_meta("feedback_home",chosen)
	node.set_meta("feedback_width",width)
	node.set_meta("feedback_start",clock_time+chosen_delay)
	node.set_meta("feedback_end",clock_time+chosen_delay+duration)
	node.set_meta("feedback_duration",duration)
	node.set_meta("feedback_rise",rise)
	node.set_meta("feedback_delay",chosen_delay)
	if bool(node.get_meta("_feedback_immutable",false)):
		var record := [clock_time+chosen_delay,clock_time+chosen_delay+duration,chosen,_feedback_float_end(chosen,rise),duration,Vector2((size_value.x-width)*.5,0),Vector2(width,size_value.y),size_value.x]
		node.set_meta("_feedback_record",record)
		if _feedback_owned_valid and _feedback_owned_clock==clock_time:
			if _feedback_batch_active and node is Label and node.get_parent()==null and _feedback_owned_viewport==get_viewport().get_visible_rect().size and _feedback_owned_records.size()==_screen_effects.get_child_count():
				_feedback_pending_init_label = node
				_feedback_pending_init_generation = _feedback_owned_generation
			_feedback_owned_records.append(record)
	return {"position":chosen,"delay":chosen_delay}

func _feedback_grid_cells(rect: Rect2) -> Array[Vector2i]:
	var first := Vector2i((rect.position/FEEDBACK_GRID_SIZE).floor())
	var last := Vector2i((rect.end/FEEDBACK_GRID_SIZE).floor())
	var cells: Array[Vector2i] = []
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1):
			cells.append(Vector2i(x,y))
	return cells

func _feedback_update_cache(records: Array, viewport_size: Vector2) -> void:
	var rebuild := _feedback_cache_clock!=clock_time or _feedback_cache_viewport!=viewport_size or records.size()<_feedback_obstacle_records.size()
	if not rebuild:
		for index in range(_feedback_obstacle_records.size()):
			if records[index]!=_feedback_obstacle_records[index]:
				rebuild = true
				break
	if rebuild:
		_feedback_sampled_times.clear()
	else:
		# A burst reserves many rows before the visual clock advances. Existing immutable
		# trajectories reuse their grids; each newly appended row enters every grid once.
		for index in range(_feedback_obstacle_records.size(),records.size()):
			for at_time in _feedback_sampled_times:
				_feedback_append_sample(_feedback_sampled_times[at_time],records[index],index,at_time)
	_feedback_obstacle_records = records
	_feedback_cache_clock = clock_time
	_feedback_cache_viewport = viewport_size

func _feedback_sample_grid(records: Array, at_time: float) -> Array:
	var result := [{},{}]
	for index in range(records.size()):
		_feedback_append_sample(result,records[index],index,at_time)
	return result

func _feedback_append_sample(result: Array, record: Array, index: int, at_time: float) -> void:
	if at_time<float(record[0]) or at_time>=float(record[1]):
		return
	var progress := clampf((at_time-float(record[0]))/float(record[4]),0,1)
	var home: Vector2 = record[2]
	var at := home.lerp(record[3],1-pow(1-progress,3))
	var rect := Rect2(at+record[5],record[6]).grow(3)
	result[0][index] = rect
	var grid: Dictionary = result[1]
	for cell in _feedback_grid_cells(rect):
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(index)

func _feedback_rect_at(node: Control, at_time: float) -> Rect2:
	var home: Vector2 = node.get_meta("feedback_home")
	var duration := float(node.get_meta("feedback_duration"))
	var progress := clampf((at_time-float(node.get_meta("feedback_start")))/duration,0,1)
	var at := home.lerp(_feedback_record_end(node,home,float(node.get_meta("feedback_rise"))),1-pow(1-progress,3))
	var width := float(node.get_meta("feedback_width"))
	return Rect2(at+Vector2((node.size.x-width)*.5,0),Vector2(width,node.size.y)).grow(3)

func _reward_popup(at: Vector3, coins: int, card_count: int, variant: String, id_value: int, group: Dictionary = {}, position_override: Variant = null) -> void:
	if coins<=0 and card_count<=0: return
	var grouped := not group.is_empty()
	var root_id := id_value if grouped else int(group.get("root_id",0))
	var source_tick := int(group.get("display_tick",group.get("tick",floori(clock_time*60.0))))
	_aux_reward_submissions+=1
	if _aux_try_fold_reward(root_id,source_tick,coins,card_count,int(group.get("destroyed",1)),bool(group.get("high_density_feedback",false))): return
	var popup := PanelContainer.new()
	popup.set_meta("_feedback_immutable",true)
	popup.name="GroupedRewardPopup" if grouped else "PackRewardPopup"
	popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	popup.set_meta("coins",coins)
	popup.set_meta("card_count",card_count)
	popup.set_meta("variant",variant)
	popup.set_meta("root_id",id_value if grouped else int(group.get("root_id",0)))
	popup.set_meta("source_tick",source_tick)
	popup.set_meta("source_ticks",[source_tick])
	popup.set_meta("reward_sources",[{"root_id":root_id,"tick":source_tick,"coins":coins,"cards":card_count,"destroyed":int(group.get("destroyed",1))}])
	if grouped:
		popup.set_meta("grouped",true)
		popup.set_meta("destroyed",int(group.destroyed))
	# Both rows use the light one-line paper skin; no title or heavy harvest panel.
	popup.add_theme_stylebox_override("panel",_feedback_styles.popup_style(false))
	var row := HBoxContainer.new()
	row.name="Contents"
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",6)
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	popup.add_child(row)
	var card_icon: Texture2D=generic_card_texture(int(variant.get_slice("-",1))) if not variant.is_empty() else generic_card_texture(0)
	for item in [{"texture":_coin_icon,"number":coins,"kind":"CoinIcon"},{"texture":card_icon,"number":card_count,"kind":"ActualCardIcon"}]:
		if int(item.number)<=0: continue
		var icon := TextureRect.new()
		icon.name=str(item.kind)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.texture=item.texture
		icon.custom_minimum_size=Vector2(26,26)
		icon.size=Vector2(26,26)
		icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.name="CoinAmount" if str(item.kind)=="CoinIcon" else "CardAmount"
		label.text="+%d" % int(item.number)
		_style_feedback_label(label,24)
		if str(item.kind)=="CoinIcon": label.add_theme_color_override("font_color",Color("#ffd36c"))
		row.add_child(label)
	var popup_size := _reward_row_size(coins,card_count)
	popup.custom_minimum_size=popup_size
	popup.size=popup_size
	var home := _feedback_position(at,popup_size,id_value,Vector2(0,6))
	if grouped and position_override is Vector2 and position_override.is_finite(): home=position_override
	var duration := .8 if grouped else .65
	var rise := 0.0 if grouped else 38.0
	var keepout := _bd_aim_keepout()
	home=_reward_safe_home(home,popup_size,rise,keepout)
	var enqueue := not _aux_waiters.is_empty()
	var placement := {"position":home,"delay":0.0} if enqueue or (grouped and position_override is Vector2 and position_override.is_finite()) else _reserve_feedback(popup,home,popup_size,duration,rise,0.0,0.0,false)
	var final := placement if enqueue else _aux_feedback_placement(popup,placement.position,popup_size,duration,rise,float(placement.delay),keepout)
	var chosen: Vector2=final.position
	placement.delay=final.delay
	_commit_feedback(popup,home,chosen,popup_size,popup_size.x,duration,rise,float(placement.delay))
	popup.position=chosen
	popup.set_meta("_reward_start",chosen)
	popup.set_meta("_reward_nominal",chosen)
	popup.set_meta("_reward_end",_feedback_float_end(chosen,rise))
	popup.set_meta("_reward_avoid_offset",Vector2.ZERO)
	popup.visible=float(placement.delay)<=0.0
	popup.z_index=3 # Damage stays above any accidental transient intersection.
	_screen_effects.add_child(popup,grouped)
	if enqueue: _aux_hold(popup)
	var tween := _tween(popup)
	popup.set_meta("_aux_tween",tween)
	tween.finished.connect(_aux_tween_finished.bind(popup),CONNECT_ONE_SHOT)
	popup.set_meta("_aux_tween_length",duration+float(placement.delay))
	if bool(popup.get_meta("_aux_waiting",false)):
		tween.set_speed_scale(0.0)
		tween.pause()
		_forget_tween(tween)
	if float(placement.delay)>0.0:
		tween.tween_interval(float(placement.delay))
		tween.tween_callback(func() -> void: popup.visible=true)
	tween.tween_method(_move_reward_popup.bind(popup),chosen,_feedback_float_end(chosen,rise),duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup,"modulate:a",0.0,.22).set_delay(duration-.22)
	tween.tween_callback(_retire_reward_popup.bind(popup,_generation))
	_feedback_reward_coins+=coins
	_feedback_reward_cards+=card_count
	_feedback_reward_groups+=1
	if root_id>0: _aux_index_density_row(_aux_density_reward_rows,"reward:%d"%root_id,popup,"reward")

func _aux_feedback_bounds() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var top := maxf(112.0,view.y*.14)
	var bottom := view.y-maxf(112.0,view.y*.16)
	var safe := Rect2(Vector2(8,top),Vector2(view.x-16,maxf(1,bottom-top)))
	if is_instance_valid(camera):
		var a := table_to_screen(Vector2(-Rules.TABLE_HALF_WIDTH+Rules.DESK_BORDER,Rules.TABLE_DEPTH-Rules.DESK_BORDER))
		var b := table_to_screen(Vector2(Rules.TABLE_HALF_WIDTH-Rules.DESK_BORDER,Rules.DESK_BORDER))
		var wood := Rect2(a.min(b),(a-b).abs()).grow(-4)
		if safe.intersects(wood): safe=safe.intersection(wood)
	return safe

func _aux_control_sweep(other: Control) -> Rect2:
	if bool(other.get_meta("_aux_waiting",false)): return Rect2()
	var offset := Vector2.ZERO
	var size_value := other.size
	# Damage Controls contain centered transparent padding. Match the native
	# feedback_width registration, retaining its outline margin and whole path.
	if other.has_meta("damage_value"):
		var width := maxf(1.0,float(other.get_meta("feedback_width",size_value.x)))
		if other is Label: width=maxf(width,_aux_damage_ink_width(other))
		offset.x=(size_value.x-width)*.5
		size_value.x=width
	size_value=size_value.ceil()+Vector2(2,2)
	var sweep := Rect2(other.position+offset,size_value)
	var record: Variant=other.get_meta("_feedback_record") if other.has_meta("_feedback_record") else null
	if record is Array and record.size()>=4:
		sweep=sweep.merge(Rect2(Vector2(record[2])+offset,size_value)).merge(Rect2(Vector2(record[3])+offset,size_value))
	elif other.has_meta("feedback_home"):
		var home: Vector2=other.get_meta("feedback_home")
		sweep=sweep.merge(Rect2(home+offset,size_value)).merge(Rect2(_feedback_record_end(other,home,float(other.get_meta("feedback_rise",0.0)))+offset,size_value))
	if other.has_meta("_hf_target"):
		var target: Vector2=other.get_meta("_hf_target")
		sweep=sweep.merge(Rect2(Vector2(other.get_meta("_hf_home"))+target+offset,size_value)).merge(Rect2(Vector2(other.get_meta("_hf_end"))+target+offset,size_value))
	return sweep.grow(6.0)

func _aux_damage_registration(text: String, style: String) -> Dictionary:
	var theme := _feedback_styles.damage_theme(style)
	var font := theme.get_font("font","Label")
	var font_size := theme.get_font_size("font_size","Label")
	var outline := theme.get_constant("outline_size","Label")
	var shadow_x := absi(theme.get_constant("shadow_offset_x","Label")) if theme.has_constant("shadow_offset_x","Label") else 0
	var shadow_y := absi(theme.get_constant("shadow_offset_y","Label")) if theme.has_constant("shadow_offset_y","Label") else 0
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+2.0*outline+shadow_x+2.0
	var height := font.get_height(font_size)+2.0*outline+shadow_y+2.0
	return {"width":width,"height":height,"cache":[text,font.get_instance_id(),font_size,outline,shadow_x,width]}

func _aux_damage_ink_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var outline := label.get_theme_constant("outline_size")
	var shadow_x := absi(label.get_theme_constant("shadow_offset_x")) if label.get_theme_color("font_shadow_color").a>0.0 else 0
	var cache: Array=label.get_meta("_aux_damage_ink_cache",[])
	if cache.size()==6 and cache[0]==label.text and cache[1]==font.get_instance_id() and cache[2]==font_size and cache[3]==outline and cache[4]==shadow_x: return float(cache[5])
	var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+2.0*outline+shadow_x+2.0
	label.set_meta("_aux_damage_ink_cache",[label.text,font.get_instance_id(),font_size,outline,shadow_x,width])
	return width

func _aux_feedback_peers(exclude: Control, duration: float) -> Array[Dictionary]:
	_aux_callback_guard()
	var peers := _aux_collect_peers(exclude,duration)
	if _aux_route_active:
		for index: int in _aux_route_generic:
			_aux_route_ends[index]=_aux_route_peers[index].end
			_aux_native_records[index][2]=_aux_route_ends[index]
	return peers

func _aux_begin_route() -> void:
	if not _screen_effects.child_order_changed.is_connected(_aux_birth_children_changed):
		_screen_effects.child_order_changed.connect(_aux_birth_children_changed)
	# Explicit mouse/retry transactions never borrow a previous callback view.
	if _aux_route_active: _aux_end_route()
	_aux_route_peers=_aux_feedback_peers(null,0.0)
	_aux_route_indices.clear()
	for index in range(_aux_route_peers.size()): _aux_route_indices[_aux_route_peers[index].node]=index
	_aux_route_active=true
	_aux_route_rects.clear()
	_aux_route_starts.clear()
	_aux_route_ends.clear()
	_aux_route_generic.clear()
	_aux_route_order.clear()
	for index in range(_aux_route_peers.size()):
		var peer: Dictionary=_aux_route_peers[index]
		_aux_route_rects.append(peer.rect)
		_aux_route_starts.append(peer.start)
		_aux_route_ends.append(peer.end)
		if not bool(peer.fixed_end): _aux_route_generic.append(index)
		_aux_route_order.append(index)
	_aux_route_order.sort_custom(func(a: int,b: int) -> bool: return _aux_route_rects[a].position.x<_aux_route_rects[b].position.x)
	_aux_native_records.clear()
	for index in range(_aux_route_peers.size()): _aux_native_records.append([_aux_route_rects[index],_aux_route_starts[index],_aux_route_ends[index]])
	_aux_damage_records.clear()
	_aux_damage_peers.clear()
	_aux_damage_indices.clear()
	for index in range(_aux_route_peers.size()):
		var peer: Dictionary=_aux_route_peers[index]
		if peer.node.has_meta("damage_value") or bool(peer.get("external",false)):
			_aux_damage_indices[peer.node]=_aux_damage_records.size()
			_aux_damage_records.append(_aux_native_records[index])
			_aux_damage_peers.append(peer)
	_aux_birth_view_owned=_aux_route_generic.is_empty()
	for peer: Dictionary in _aux_route_peers:
		if not bool(peer.get("external",false)) and not bool(peer.node.get_meta("_feedback_immutable",false)): _aux_birth_view_owned=false
	_aux_birth_callback_structure=_aux_birth_structure

func _aux_refresh_route(node: Control) -> void:
	if not _aux_route_indices.has(node): return
	var peer: Dictionary=_aux_route_peers[int(_aux_route_indices[node])]
	# Includes current position, reserved home/end, and the prospective _hf_target.
	# Refresh even if the owned-generation or actual position did not change.
	peer.rect=_aux_control_sweep(node)
	peer.start=float(node.get_meta("feedback_start",clock_time))
	peer.fixed_end=node.has_meta("feedback_end")
	if bool(peer.fixed_end): peer.end=float(node.get_meta("feedback_end"))
	if not _aux_route_indices.has(node): return
	var index := int(_aux_route_indices[node])
	_aux_route_rects[index]=_aux_route_peers[index].rect
	_aux_route_starts[index]=_aux_route_peers[index].start
	_aux_route_ends[index]=_aux_route_peers[index].end
	var at := _aux_route_order.find(index)
	while at>0 and _aux_route_rects[index].position.x<_aux_route_rects[_aux_route_order[at-1]].position.x:
		_aux_route_order[at]=_aux_route_order[at-1]
		at-=1
	_aux_route_order[at]=index
	while at+1<_aux_route_order.size() and _aux_route_rects[index].position.x>_aux_route_rects[_aux_route_order[at+1]].position.x:
		_aux_route_order[at]=_aux_route_order[at+1]
		at+=1
	_aux_route_order[at]=index
	if not _aux_route_indices.has(node): return
	_aux_native_records[index][0]=_aux_route_rects[index]
	_aux_native_records[index][1]=_aux_route_starts[index]
	_aux_native_records[index][2]=_aux_route_ends[index]

func _aux_feedback_placement(node: Control, preferred: Vector2, size_value: Vector2, duration: float, rise: float, base_delay: float, keepout: Rect2, travel: Variant = null) -> Dictionary:
	return _aux_find_placement(node,preferred,size_value,duration,rise,base_delay,keepout,travel,false)

func _aux_find_placement(node: Control, preferred: Vector2, size_value: Vector2, duration: float, rise: float, base_delay: float, keepout: Rect2, travel: Variant, immediate_only: bool, supplied_peers: Variant = null) -> Dictionary:
	var peers: Array[Dictionary]=_aux_feedback_peers(node,duration) if supplied_peers==null else supplied_peers
	var movement: Vector2=Vector2(travel) if travel is Vector2 else _feedback_float_end(preferred,rise)-preferred
	var first_delay := maxf(0,base_delay)
	var first_finish := preferred+movement
	var first_sweep := Rect2(preferred.min(first_finish),size_value+movement.abs()).grow(4)
	if _aux_feedback_bounds().encloses(first_sweep) and (not keepout.has_area() or not first_sweep.intersects(keepout.grow(6))):
		if not _aux_sweep_occupied(first_sweep,clock_time+first_delay,clock_time+first_delay+duration,node,peers): return {"position":preferred,"delay":first_delay,"safe":true}
	var geometry := _aux_candidate_geometry(preferred,size_value,keepout,movement)
	var delays := PackedFloat64Array([maxf(0,base_delay)])
	if not immediate_only:
		for peer: Dictionary in peers:
			var delay := maxf(base_delay,float(peer.end)-clock_time+.06)
			if not delays.has(delay): delays.append(delay)
		delays.sort()
	var chosen := _aux_layout_first(geometry.sweeps,peers,delays,clock_time,duration,node)
	if chosen.x>=0: return {"position":geometry.positions[chosen.x],"delay":delays[chosen.y],"safe":true}
	return {"position":_reward_safe_home(preferred,size_value,rise,keepout),"delay":delays[-1],"safe":false}

func _route_bd_text_overlap(label: Label, keepout: Rect2) -> void:
	if bool(label.get_meta("_aux_waiting",false)): return
	_aux_ensure_callback_view()
	var offset: Vector2=label.get_meta("_hf_offset")
	var nominal: Vector2=label.get_meta("_hf_nominal")
	var end := float(label.get_meta("feedback_end"))
	var start := maxf(clock_time,float(label.get_meta("feedback_start")))
	var remaining := maxf(.001,end-clock_time)
	var current := nominal+offset
	var finish := Vector2(label.get_meta("_hf_end"))+offset
	var operation := keepout.grow(FEEDBACK_AVOID_LEAD) if keepout.has_area() else keepout
	var sweep := Rect2(current.min(finish),label.size+(current-finish).abs()).grow(4)
	var peers := _aux_feedback_peers(label,remaining)
	if (operation.has_area() and sweep.intersects(operation.grow(6))) or _aux_sweep_occupied(sweep,start,end,label,peers):
		var placement := _aux_fast_placement(label,current,label.size,operation,finish-current,start,end,peers)
		if bool(placement.safe):
			offset+=Vector2(placement.position)-current
			_set_feedback_offset(label,offset)
		else: _aux_hold(label)
	if offset!=Vector2.ZERO: label.set_meta("_hf_target",offset)
	label.position=nominal+offset

func _reward_safe_home(home: Vector2, size_value: Vector2, rise: float, keepout: Rect2) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var top := maxf(112.0,view.y*.14)
	var bottom := view.y-maxf(112.0,view.y*.16)-size_value.y
	var obstacle := keepout.grow(6.0)
	var candidates: Array[Vector2]=[home]
	if keepout.has_area(): candidates.append_array([Vector2(obstacle.position.x-size_value.x-6.0,home.y),Vector2(obstacle.end.x+6.0,home.y),Vector2(home.x,obstacle.position.y-size_value.y-6.0),Vector2(home.x,obstacle.end.y+rise+6.0)])
	var chosen := home
	var closest := INF
	for candidate: Vector2 in candidates:
		candidate=Vector2(clampf(candidate.x,8.0,maxf(8.0,view.x-size_value.x-8.0)),clampf(candidate.y,top,maxf(top,bottom)))
		var finish := _feedback_float_end(candidate,rise)
		var sweep := Rect2(candidate.min(finish),size_value+(candidate-finish).abs()).grow(4.0)
		if keepout.has_area() and sweep.intersects(obstacle): continue
		var score := candidate.distance_squared_to(home)
		if score<closest:
			chosen=candidate
			closest=score
	return chosen

func _move_reward_popup(nominal: Vector2, popup: Control) -> void:
	if not is_instance_valid(popup): return
	popup.set_meta("_reward_nominal",nominal)
	_route_reward_popup(popup,_bd_aim_keepout())

func _route_reward_popup(popup: Control, keepout: Rect2) -> void:
	_aux_callback_guard()
	if bool(popup.get_meta("_aux_waiting",false)): return
	_aux_ensure_callback_view()
	var nominal: Vector2=popup.get_meta("_reward_nominal")
	var finish: Vector2=popup.get_meta("_reward_end")
	var old_offset: Vector2=popup.get_meta("_reward_avoid_offset")
	var safe := _reward_safe_home(nominal+old_offset,popup.size,maxf(0.0,nominal.y-finish.y),keepout)
	var end := float(popup.get_meta("feedback_end"))
	var start := maxf(clock_time,float(popup.get_meta("feedback_start")))
	var remaining := maxf(.001,end-clock_time)
	var sweep := Rect2(safe.min(finish+old_offset),popup.size+(safe-finish-old_offset).abs()).grow(4)
	var peers := _aux_feedback_peers(popup,remaining)
	if _aux_sweep_occupied(sweep,start,end,popup,peers):
		var layout := _aux_fast_placement(popup,safe,popup.size,keepout,finish-nominal,start,end,peers)
		if bool(layout.safe): safe=layout.position
		else: _aux_hold(popup)
	var offset := safe-nominal
	if offset!=old_offset:
		popup.set_meta("_reward_avoid_offset",offset)
		var home: Vector2=popup.get_meta("_reward_start")
		popup.set_meta("feedback_home",home+offset)
		popup.set_meta("feedback_offset",home+offset-Vector2(popup.get_meta("feedback_origin")))
		if popup.has_meta("_feedback_record"):
			var record: Array=popup.get_meta("_feedback_record").duplicate()
			record[2]=home+offset
			record[3]=finish+offset
			popup.set_meta("_feedback_record",record)
		_feedback_owned_valid=false
		_feedback_owned_clock=-INF
		_feedback_owned_generation+=1
	popup.position=nominal+offset
	_aux_callback_publish(popup)

func _retire_reward_popup(popup: Control, generation: int) -> void:
	_finish_reward_popup.call_deferred(popup,generation)

func _finish_reward_popup(popup: Control, generation: int) -> void:
	if not is_instance_valid(popup) or popup.is_queued_for_deletion(): return
	if generation==_generation:
		_feedback_owned_valid=false
		_feedback_owned_clock=-INF
		_feedback_owned_generation+=1
	popup.queue_free()

func feedback_presentation_snapshot() -> Dictionary:
	# Explicit QA observation surface; never called by the render/score hot path.
	var rows: Array=[]
	if is_instance_valid(_screen_effects):
		for child in _screen_effects.get_children():
			if not child is Control or child.is_queued_for_deletion(): continue
			var row := {"name":str(child.name),"visible":child.visible,"position":child.position,"size":child.size}
			for key in ["root_id","source_tick","source_ticks","reward_sources","high_density_merged","family","mechanic","mechanics","source_texts","source_count","bd_count","damage_value","coins","card_count","grouped","destroyed","feedback_start","feedback_end","feedback_delay"]:
				if child.has_meta(key): row[key]=child.get_meta(key)
			if child is Label: row["text"]=child.text
			rows.append(row)
	var pending_sources := 0
	for group: Dictionary in _pending_bd_groups.values(): pending_sources+=group.mechanics.size()
	return {"rows":rows,"layout":feedback_layout_metrics(),"pending_bd_groups":_pending_bd_groups.size(),"pending_bd_sources":pending_sources,"bd_sources":_feedback_bd_sources,"bd_shown_sources":_feedback_bd_shown_sources,"bd_groups":_feedback_bd_groups,"bd_duplicates":_feedback_bd_duplicates,"reward_coins":_feedback_reward_coins,"reward_cards":_feedback_reward_cards,"reward_rows":_feedback_reward_groups,"reward_duplicates":_feedback_reward_duplicates,"reward_invalid":_feedback_reward_invalid,"pool_idle":_feedback_label_pool.idle_count(),"owned_records":_feedback_owned_records.size(),"screen_children":_screen_effects.get_child_count() if is_instance_valid(_screen_effects) else 0,"generation":_generation}

func feedback_layout_metrics() -> Dictionary:
	# O(1) observation surface for real-game probes; no Control/tree/row copies.
	return {"native_loaded":_safe_layout_math!=null,"class":"RoundCardSafeLayoutMath" if _safe_layout_math!=null else "","indexed_supported":_safe_layout_indexed,"native_calls":_aux_native_calls,"fallback_calls":_aux_fallback_calls,"waiters":_aux_waiters.size(),"max_waiters":_aux_max_waiters,"holds":_aux_hold_count,"resumes":_aux_resume_count,"retry_queue":_aux_retry_queue.size(),"external_reservations":_aux_external_rows.size(),"callback_builds":_aux_callback_builds,"callback_reuses":_aux_callback_reuses,"bd_folded_groups":_aux_bd_folded_groups,"bd_folded_sources":_aux_bd_folded_sources,"reward_folded_sources":_aux_reward_folded_sources,"reward_submissions":_aux_reward_submissions,"waiting_oldest_age":_aux_waiting_oldest_age(),"waiting_max_age":maxf(_aux_max_wait_age,_aux_waiting_oldest_age())}

func _torn_wrapper(start: Vector3, grade: int, angle: float, attack_level: String = "circle", target_id: int = 0) -> void:
	for side in range(2):
		var loan := _claim_visual_pool.borrow(["torn",grade,side],_new_claim_torn.bind(grade,side))
		var half: MeshInstance3D = loan.node
		half.mesh=_skin_pack_mesh(_geo.pack_torn_half(grade,side==1),grade) if _equipped_pack_skin!="default" else _geo.pack_torn_half(grade,side==1)
		half.material_override=_torn_materials[grade]
		half.visible = true
		half.transform = Transform3D(Basis.IDENTITY,start)
		_effects.add_child(half)
		half.name = ("TornWrapperRight_" if side==1 else "TornWrapperLeft_")+str(target_id)
		half.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var face_basis := _pack_face_basis(angle)
		half.basis = face_basis
		var origin := start+camera.basis.z*PACK_VIEW_DEPTH
		var direction := face_basis.x*(-1.0 if side==0 else 1.0)
		var tween := _tween(half)
		_claim_visual_tweens[int(loan.token)] = tween
		if reduce_effects:
			# Static separated jagged edges remain a break confirmation without motion.
			half.position = origin+direction*.085
			tween.tween_interval(.24)
		else:
			var full := attack_level=="fever_full"
			var extent := .42 if full else .34 if attack_level=="fever_low" else .28
			half.position = origin+direction*.025
			tween.tween_method(func(value: float) -> void:
				var spread := 1.0-pow(1.0-value,3.0)
				half.position = origin+direction*(.025+spread*extent)+camera.basis.y*sin(value*PI)*(.12 if full else .08)
				half.basis = face_basis.rotated(camera.basis.z,(-1.0 if side==0 else 1.0)*value*.48).scaled(Vector3.ONE*(1.0-smoothstep(.65,1.0,value)))
			,0.0,1.0,.36)
		tween.tween_callback(_retire_claim_visual.bind(half,_generation,int(loan.token)))

func _contact_sparks(start: Vector3, seed_value: int, count: int) -> void:
	var event := {"kind":"wrapper_fragment" if count>3 else "contact_spark","element":_aim_spec.get("element","E01"),"pos":Vector2(start.x*100,-start.z*100),"seed":seed_value,"mote_count":count,"cosmetic_fragment":true}
	var effect = _new_skill_effect(event)
	effect.batched = true
	effect.external_atlas = true
	effect.name = "WrapperFragment" if count>3 else "ContactSpark"
	_effects.add_child(effect)
	effect.view_right = camera.basis.x
	effect.view_up = camera.basis.y
	effect.view_forward = camera.basis.z
	effect.configure(event,reduce_effects)

func _break_burst(at: Vector3, grade: int = 0) -> void:
	var atlas := SkillEffect.Atlas.sheet("break")
	if atlas.is_empty(): return
	var event := {"kind":"wrapper_burst","element":_aim_spec.get("element","E01"),"grade":grade,"pos":Vector2(at.x*100,-at.z*100),"cosmetic_fragment":true}
	var effect = _new_skill_effect(event)
	effect.batched = true
	effect.external_atlas = true
	effect.name = "PixelfxWrapperBurst"
	_effects.add_child(effect)
	effect.view_right = camera.basis.x
	effect.view_up = camera.basis.y
	effect.view_forward = camera.basis.z
	var width := float(_pixel_break.get_width())/5.0*.012 if _pixel_break!=null else 1.12
	event.merge({"visual_center":at+Vector3(0,.06,0),"visual_pixel_size":width/float(atlas.size.x)},true)
	effect.configure(event,reduce_effects)


func _request_destroy_shake() -> void:
	var frame := Engine.get_process_frames()
	if _preparation_feedback.enabled or reduce_effects or frame==_shake_started_frame or _shake_cooldown>0.0:
		return
	_shake_started_frame = frame
	_shake_requests += 1
	_shake_left = .15
	_shake_cooldown = .12
	_shake_phase = 0.0

func _advance_shake(delta: float, paused: bool) -> void:
	if reduce_effects:
		_shake_left = 0.0
		_pixel_display.position = Vector2.ZERO
		return
	if paused:
		return
	_shake_left = maxf(0.0,_shake_left-delta)
	_shake_cooldown = maxf(0.0,_shake_cooldown-delta)
	_shake_phase += delta
	var amplitude := 2.5*(_shake_left/.15)
	# Presentation-only offset: camera projection and all simulation coordinates stay fixed.
	_pixel_display.position = Vector2(roundf(sin(_shake_phase*110.0)*amplitude),roundf(cos(_shake_phase*87.0)*amplitude*.6)) if _shake_left>0 else Vector2.ZERO

func shot(p: Vector2) -> void:
	_stop_strike()
	_striking = true
	var generation := _generation
	# Preserve the existing contact timing and screenshot window without a weapon animation.
	_strike_tween = _tween(self)
	_impact(p)
	_strike_tween.tween_interval(0.185)
	_strike_tween.tween_callback(func() -> void:
		if generation == _generation:
			_striking = false
	)

func set_aim(p: Vector2, progress: float, valid: bool, battle: bool, original_p: Variant = null) -> void:
	aim_point = p
	_progress = clampf(progress,0,1)
	_battle = battle
	_aim_valid = valid
	if _preparation_feedback.enabled:
		_aim_valid = battle
		if is_instance_valid(_decoration): _decoration.visible = not battle
		_preparation_feedback.set_battle(battle,_progress)
		if not battle: _stop_strike()
		return
	if is_instance_valid(_decoration):
		_decoration.visible = not battle
	var is_capsule := str(_aim_spec.get("shape","circle")) in ["capsule","line"]
	aim_ring.visible = battle and valid and not is_capsule
	charge_ring.visible = battle and valid and not is_capsule
	_skill_aim.visible = battle and valid
	_focus_aim.visible = battle and valid and original_p is Vector2 and p.distance_squared_to(original_p)>.01
	_route_operation_feedback()
	if not battle:
		_stop_strike()
		return
	if not valid:
		return
	var position_value := table_to_world(p)
	aim_ring.position = position_value+Vector3(0,0.012,0)
	charge_ring.position = position_value+Vector3(0,0.014,0)
	_charge_material.set_shader_parameter("progress",_progress)
	var preview := _aim_spec.duplicate(true)
	preview.merge({"kind":"aim","pos":p,"progress":_progress,"direction":(p-Vector2(0,20)).normalized()},true)
	# Existing circle shader owns its contour/progress; native preview adds only the exact focus core.
	if not is_capsule:
		preview["radius"] = 0.0
	_skill_aim.configure(preview,reduce_effects,true)
	if _focus_aim.visible:
		_focus_aim.configure({"kind":"focus_snap","pos":p,"from":original_p,"radius":_aim_spec.get("focus_radius",10.0),"element":_aim_spec.get("element","E01")},reduce_effects,true)

func _impact(p: Vector2) -> void:
	var position_value := table_to_world(p)+Vector3(0,0.013,0)
	var rim_material := _soft_material(Color(.7843,.5098,.1529,0.78 if not reduce_effects else 0.42))
	rim_material.set_shader_parameter("ring",1.0)
	# The soft ring's UV radius is 0.69 on a [-1,1] domain: its base radius is R50.
	var radius := float(_aim_spec.get("radius",Rules.SHOT_RADIUS))
	var rim := _geo.plane(Vector2.ONE*radius*0.02/0.69,rim_material,position_value,_effects)
	rim.name = "PixelImpactRadius50" if is_equal_approx(radius,50.0) else "PixelImpactRadius%s" % str(radius)
	rim.scale = Vector3.ONE*0.40
	var tween := _tween(rim).set_parallel(true)
	tween.tween_property(rim,"scale",Vector3.ONE*1.14,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade(tween,rim,0.24)
	tween.chain().tween_callback(rim.queue_free)
	if reduce_effects:
		return
	_pixel_spark(position_value)
	for index in range(4):
		var angle := float(index)*2.39996+0.72
		var direction := Vector3(cos(angle),0,sin(angle))
		var chip := _geo.box(Vector3(0.038,0.025,0.038),position_value,_geo.material(Color("#e8b36a")),_effects)
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var chip_tween := _tween(chip)
		chip_tween.tween_method(func(value: float) -> void:
			chip.position = position_value+direction*value*0.49+Vector3(0,sin(value*PI)*0.12,0)
			chip.rotation = Vector3(floor(value*4.0)*PI/2.0,angle,0)
			chip.scale = Vector3.ONE*(1.0-floor(smoothstep(0.5,1.0,value)*3.0)/3.0)
		,0.0,1.0,0.30)
		chip_tween.tween_callback(chip.queue_free)

func _pixel_spark(at: Vector3) -> void:
	var atlas := SkillEffect.Atlas.sheet("contact")
	if _pixel_hit == null and atlas.is_empty():
		return
	var sprite := Sprite3D.new()
	sprite.name = "PixelfxHeavyHit"
	var frame_count := 13
	if not atlas.is_empty():
		SkillEffect.Atlas.configure_3d(sprite,atlas)
		var width := float(_pixel_hit.get_width())/3.0*.029 if _pixel_hit!=null else .95
		sprite.pixel_size = width/float(atlas.size.x)
		frame_count = int(atlas.frames)
		sprite.set_meta("feedback_atlas","contact")
	else:
		sprite.texture = _pixel_hit
		sprite.hframes = 3
		sprite.vframes = 5
		sprite.pixel_size = .029
		sprite.offset = Vector2(24,-24)
	sprite.frame = 0
	sprite.render_priority = 49
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = at
	_effects.add_child(sprite)
	var tween := _tween(sprite)
	# Keep the existing 400ms beat, playing the complete imported sequence including its empty tail.
	tween.tween_method(func(value: float) -> void: sprite.frame = mini(frame_count-1,int(value)),0.0,float(frame_count),0.40)
	tween.tween_callback(sprite.queue_free)

func _soft_material(tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SOFT_SHADER
	mat.set_shader_parameter("tint",tint)
	return mat

func _glint(at: Vector3, diameter: float, color: Color, duration: float) -> void:
	var loan := _claim_visual_pool.borrow(["glint",diameter,color],_new_claim_glint.bind(diameter,color))
	var glow: MeshInstance3D = loan.node
	glow.visible = true
	glow.transform = Transform3D(Basis.IDENTITY,at+Vector3(0,0.006,0))
	# Remove the previous loan's fade override: the original cold material also
	# starts with the shader's opacity=1 default, rather than a stored override.
	(glow.material_override as ShaderMaterial).set_shader_parameter("opacity",null)
	_effects.add_child(glow)
	var tween := _tween(glow).set_parallel(true)
	_claim_visual_tweens[int(loan.token)] = tween
	tween.tween_property(glow,"scale",Vector3.ONE*1.38,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade(tween,glow,duration)
	tween.chain().tween_callback(_retire_claim_visual.bind(glow,_generation,int(loan.token)))

func _new_claim_glint(diameter: float, color: Color) -> MeshInstance3D:
	var mesh := _claim_visual_pool.mesh(["plane",diameter],func() -> PlaneMesh:
		var value := PlaneMesh.new()
		value.size = Vector2.ONE*diameter
		return value)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _soft_material(color)
	(node.material_override as ShaderMaterial).set_shader_parameter("cross_glint",true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _new_claim_coin() -> MeshInstance3D:
	var mesh := _claim_visual_pool.mesh(["coin"],func() -> CylinderMesh:
		var value := CylinderMesh.new()
		value.top_radius = .045
		value.bottom_radius = .045
		value.height = .012
		value.radial_segments = 8
		return value)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _geo.material(Color("#ffd58a"))
	return node

func _new_claim_torn(grade: int, side: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _geo.pack_torn_half(grade,side==1)
	node.material_override = _torn_materials[grade]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _prewarm_claim_visuals() -> void:
	_claim_visual_pool.prepare(["coin"],_new_claim_coin,16)
	for alpha in [.65,.20]:
		var color := Color(1.0,.85,.55,alpha)
		_claim_visual_pool.prepare(["glint",.68,color],_new_claim_glint.bind(.68,color),16)
	for grade in range(5):
		for side in range(2):
			_claim_visual_pool.prepare(["torn",grade,side],_new_claim_torn.bind(grade,side),8)

func _retire_claim_visual(node: MeshInstance3D, generation: int, token: int) -> void:
	# The node-bound Tween must finish before its node can be detached/reused.
	_return_claim_visual.call_deferred(node,generation,token)

func _return_claim_visual(node: MeshInstance3D, generation: int, token: int) -> void:
	# Finished Tweens otherwise remain valid when their bound pooled node survives.
	# Kill only after its callback has returned, exactly when the old node was freed.
	var finished: Tween = _claim_visual_tweens.get(token)
	if finished!=null:
		_forget_tween(finished)
		if finished.is_valid(): finished.kill()
	_claim_visual_tweens.erase(token)
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not _claim_visual_pool.owns(node,token): return
	if generation!=_generation or not is_inside_tree():
		node.queue_free()
		return
	if node.get_parent()!=_effects: return
	_effects.remove_child(node)
	_claim_visual_pool.release_detached(node,token)

func _tween(node: Node) -> Tween:
	var tween := node.create_tween()
	tween.set_meta("_world_finished",false)
	# A killed Tween does not emit finished. Bind a weak reference so its
	# signal cannot keep the Tween alive through a self-reference after kill.
	tween.finished.connect(_world_tween_finished.bind(weakref(tween)),CONNECT_ONE_SHOT)
	_tweens.append(tween)
	if _paused_visuals:
		_pause_world_tween(tween)
	return tween

func _forget_tween(tween: Tween) -> void:
	_tweens.erase(tween)
	_world_paused_tweens.erase(tween)

func _world_tween_finished(reference: WeakRef) -> void:
	var tween := reference.get_ref() as Tween
	if tween==null: return
	tween.set_meta("_world_finished",true)
	_forget_tween(tween)

func _pause_world_tween(tween: Tween) -> void:
	if not tween.is_valid() or not tween.is_running() or bool(tween.get_meta("_world_finished",false)): return
	tween.pause()
	if not _world_paused_tweens.has(tween): _world_paused_tweens.append(tween)

func _sync_tween_pause(paused: bool) -> void:
	if paused==_paused_visuals: return
	if paused:
		for tween in _tweens: _pause_world_tween(tween)
	else:
		for tween in _world_paused_tweens:
			if tween.is_valid() and _tweens.has(tween) and not bool(tween.get_meta("_world_finished",false)) and not tween.is_running(): tween.play()
		_world_paused_tweens.clear()
	_paused_visuals = paused

func _fade(tween: Tween, node: MeshInstance3D, duration: float) -> void:
	# Fade the material itself: GeometryInstance transparency is not supported by Compatibility.
	var mat: Material = node.material_override
	if mat is ShaderMaterial:
		tween.tween_method(func(value: float) -> void: mat.set_shader_parameter("opacity",value),1.0,0.0,duration)
	else:
		tween.tween_property(mat,"albedo_color:a",0.0,duration)

func _configure_foil(mat: Material, update_reduced: bool = true) -> void:
	if mat is ShaderMaterial and mat.shader==Geometry.CARD_FOIL:
		mat.set_shader_parameter("phase",0.0 if reduce_effects else clock_time)
		if update_reduced:
			mat.set_shader_parameter("reduced",reduce_effects)

func _record_performance_stage(stage: String, start: int) -> int:
	var now := Time.get_ticks_usec()
	var elapsed := now-start
	var sample: Dictionary = performance_stage_usec.get(stage,{"count":0,"total":0,"max":0,"last":0})
	sample.count = int(sample.count)+1
	sample.total = int(sample.total)+elapsed
	sample.max = maxi(int(sample.max),elapsed)
	sample.last = elapsed
	performance_stage_usec[stage] = sample
	return now

func _process(delta: float) -> void:
	var trace_time := Time.get_ticks_usec() if performance_trace_enabled else 0
	if _gpu_warm_frames_left>0:
		_gpu_warm_frames_left -= 1
		if _gpu_warm_frames_left==0:
			_gpu_warmed_elements[_gpu_warming_element] = true
			_gpu_warming_element = ""
			if skill_atlas_instance_count==0: _skill_atlas_batch.clear()
	var paused := _has_pause_property and bool(get_parent().get("paused"))
	for index in range(_tweens.size()-1,-1,-1):
		if not _tweens[index].is_valid():
			_world_paused_tweens.erase(_tweens[index])
			_tweens.remove_at(index)
	_sync_tween_pause(paused)
	_preparation_feedback.advance(delta,paused)
	if not paused:
		clock_time += delta
		_route_operation_feedback()
	_advance_shake(delta,paused)
	if performance_trace_enabled:
		trace_time = _record_performance_stage("tweens",trace_time)
	var update_reduced: bool = _material_reduced!=reduce_effects
	_material_reduced = reduce_effects
	for mat in _front_materials.values():
		_configure_foil(mat,update_reduced)
	for mat in _pack_materials.values():
		mat.set_shader_parameter("phase",0.0 if reduce_effects else clock_time)
		if update_reduced:
			mat.set_shader_parameter("reduced",reduce_effects)
	for node in cards.values():
		var mat: ShaderMaterial = node.get_meta("pack_material")
		mat.set_shader_parameter("phase",0.0 if reduce_effects else clock_time)
		if update_reduced:
			mat.set_shader_parameter("reduced",reduce_effects)
	if performance_trace_enabled:
		trace_time = _record_performance_stage("foil_packuniform",trace_time)
	for node in cards.values():
		var trail = node.get_node_or_null("FastTrail")
		if trail!=null:
			trail.advance(delta,paused,reduce_effects)
	if performance_trace_enabled:
		trace_time = _record_performance_stage("trails",trace_time)
	for child in _effects.get_children():
		if child is QualityEffect:
			var effect: QualityEffect=child
			effect.advance(delta,paused,reduce_effects,true)
		elif child is SkillEffect:
			var effect: SkillEffect=child
			effect.advance(delta,paused,reduce_effects,true)
		if child.name in ["PixelfxWrapperBurst","WrapperFragment","ContactSpark"]:
			child.visible = not reduce_effects
	for child in _harvest_effects.get_children():
		if child is HarvestSparkle:
			child.advance(delta,paused,reduce_effects)
	for child in _reward_effects.get_children():
		if child is RewardFlyer:
			child.advance(delta,paused,reduce_effects)
	if is_instance_valid(_skill_aim):
		_skill_aim.advance(0.0,true,reduce_effects)
		_focus_aim.advance(0.0,true,reduce_effects)
	var frame := _effect_frame_snapshot()
	_apply_skill_visual_budget(true,frame.normal)
	# Every noncosmetic was just flushed above; the second old call was a no-op.
	# Cosmetic fragments retain their original later flush phase and full order.
	for item in frame.cosmetic:
		if item is QualityEffect:
			var effect: QualityEffect=item
			effect.flush_visual()
		else:
			var effect: SkillEffect=item
			effect.flush_visual()
	if performance_trace_enabled:
		trace_time = _record_performance_stage("advance_budget_flush",trace_time)
	_sample_skill_metrics(frame.normal)
	if performance_trace_enabled:
		trace_time = _record_performance_stage("metrics",trace_time)
	_refresh_skill_batches(frame.all)
	if performance_trace_enabled:
		_record_performance_stage("batch_upload",trace_time)
	skill_total_draw_calls = skill_batch_draw_calls+skill_atlas_draw_calls
	if paused:
		return
	if is_instance_valid(_charge_material):
		_charge_material.set_shader_parameter("phase",clock_time)
		_charge_material.set_shader_parameter("reduced",reduce_effects)
		_guide_material.set_shader_parameter("phase",clock_time)
		_guide_material.set_shader_parameter("reduced",reduce_effects)

func _stop_strike() -> void:
	if is_instance_valid(_strike_tween):
		_strike_tween.kill()
	_striking = false

func clear_cards() -> void:
	_preparation_feedback.clear()
	_burst_feedback_attack.clear()
	_burst_feedback_budget.clear()
	_aux_end_route()
	_aux_density_bd_rows.clear()
	_aux_density_reward_rows.clear()
	_aux_bd_folded_groups=0
	_aux_bd_folded_sources=0
	_aux_reward_folded_sources=0
	_aux_reward_submissions=0
	_aux_max_wait_age=0.0
	if is_instance_valid(_feedback_waiting) and is_instance_valid(_screen_effects):
		for child in _feedback_waiting.get_children():
			if child.has_meta("_aux_tween"):
				var waiting_tween: Tween=child.get_meta("_aux_tween")
				if waiting_tween.is_valid(): waiting_tween.kill()
			child.reparent(_screen_effects)
	_aux_waiters.clear()
	_aux_retry_queue.clear()
	_aux_external_rows.clear()
	_aux_native_calls=0
	_aux_fallback_calls=0
	_aux_hold_count=0
	_aux_resume_count=0
	_aux_max_waiters=0
	_aux_callback_builds=0
	_aux_callback_reuses=0
	_aux_retry_clock=-INF
	_aux_wait_clock=-INF
	_end_feedback_batch()
	_operation_keepout = Rect2()
	_gpu_warm_frames_left = 0
	_gpu_warming_element = ""
	_feedback_owned_generation += 1
	_feedback_owned_records.clear()
	_feedback_owned_valid = false
	_feedback_owned_clock = -INF
	_feedback_owned_viewport = Vector2.ZERO
	_feedback_obstacle_records.clear()
	_feedback_sampled_times.clear()
	_feedback_cache_clock = -INF
	_feedback_cache_viewport = Vector2.ZERO
	# Cancel node-bound callbacks before a new run can reuse any target IDs.
	_generation += 1
	_battle = false
	_aim_valid = false
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_world_paused_tweens.clear()
	_feedback_label_pool.clear()
	_claim_visual_pool.clear()
	_claim_visual_tweens.clear()
	_stop_strike()
	for node in cards.values():
		if is_instance_valid(node):
			node.queue_free()
	cards.clear()
	_visual_slots.clear()
	_hit_tweens.clear()
	_claimed_visuals.clear()
	_presented_skill_events.clear()
	_presented_bd_triggers.clear()
	_pending_bd_groups.clear()
	_presented_reward_groups.clear()
	_presented_circle_bonuses.clear()
	_feedback_bd_sources=0
	_feedback_bd_shown_sources=0
	_feedback_bd_groups=0
	_feedback_bd_duplicates=0
	_feedback_reward_coins=0
	_feedback_reward_cards=0
	_feedback_reward_groups=0
	_feedback_reward_duplicates=0
	_feedback_reward_invalid=0
	skill_active_count = 0
	skill_bright_count = 0
	skill_quad_count = 0
	skill_front_quads = 0
	skill_layer_count = 0
	skill_visual_peak = false
	skill_last_kind = ""
	skill_quad_high_water = 0
	skill_active_high_water = 0
	skill_layers_high_water = 0
	skill_batch_draw_calls = 0
	skill_foreground_count = 0
	skill_full_detail_count = 0
	skill_atlas_count = 0
	skill_atlas_instance_count = 0
	skill_atlas_draw_calls = 0
	skill_total_draw_calls = 0
	_skill_batch_revisions.clear()
	if is_instance_valid(_skill_atlas_batch):
		_skill_atlas_batch.clear()
	if is_instance_valid(_skill_ground_batch):
		(_skill_ground_batch.mesh as ArrayMesh).clear_surfaces()
		(_skill_front_batch.mesh as ArrayMesh).clear_surfaces()
	_shake_left = 0.0
	_shake_cooldown = 0.0
	_shake_started_frame = -1
	if is_instance_valid(_pixel_display):
		_pixel_display.position = Vector2.ZERO
	dying.clear()
	if is_instance_valid(_effects):
		for child in _effects.get_children():
			child.queue_free()
	if is_instance_valid(_screen_effects):
		for child in _screen_effects.get_children():
			child.queue_free()
	if is_instance_valid(_harvest_effects):
		for child in _harvest_effects.get_children():
			child.queue_free()
	if is_instance_valid(_reward_effects):
		for child in _reward_effects.get_children():
			child.queue_free()
	if is_instance_valid(aim_ring):
		aim_ring.visible = false
		charge_ring.visible = false
	if is_instance_valid(_skill_aim):
		_skill_aim.visible = false
		_focus_aim.visible = false






func _aux_collect_peers(exclude: Control, duration: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if _aux_route_active:
		for peer: Dictionary in _aux_route_peers:
			if peer.node==exclude: continue
			if not bool(peer.fixed_end): peer.end=clock_time+duration+.1
			if float(peer.end)>=clock_time-.05: result.append(peer)
		return result
	for other in _screen_effects.get_children():
		var peer := _aux_birth_control_peer(other,exclude,duration)
		if not peer.is_empty(): result.append(peer)
	for row: Dictionary in _aux_external_rows:
		var value: Variant=row.node
		if not is_instance_valid(value): continue
		var other: Control=value
		if other==exclude or other.is_queued_for_deletion() or not other.visible: continue
		result.append({"node":other,"external":true,"fixed_end":true,"rect":row.rect,"start":minf(clock_time,float(row.start)),"end":maxf(clock_time+.05,float(row.end))})
	return result

func set_external_aux_reservations(rows: Array[Dictionary]) -> void:
	if _aux_callback_active: _aux_end_route()
	_aux_external_generation+=1
	_aux_external_rows.clear()
	for row: Dictionary in rows:
		if not row.get("node") is Control or not row.get("rect") is Rect2: continue
		var rect: Rect2=row.rect
		if not rect.has_area() or not rect.position.is_finite() or not rect.size.is_finite(): continue
		_aux_external_rows.append({"node":row.node,"rect":rect,"start":float(row.get("start",clock_time)),"end":float(row.get("end",clock_time+.1))})


func _aux_sweep_occupied(sweep: Rect2, start: float, end: float, exclude: Control, peers: Array[Dictionary]) -> bool:
	if _aux_route_active:
		var own := int(_aux_route_indices.get(exclude,-1))
		for index in range(_aux_route_rects.size()):
			if index==own or end+.05<_aux_route_starts[index] or start>_aux_route_ends[index]+.05: continue
			if sweep.intersects(_aux_route_rects[index]): return true
		return false
	for peer: Dictionary in peers:
		if end+.05<float(peer.start) or start>float(peer.end)+.05: continue
		if sweep.intersects(peer.rect): return true
	return false


func _aux_hold(node: Control) -> void:
	if bool(node.get_meta("_aux_waiting",false)): return
	var remaining := maxf(0.0,float(node.get_meta("feedback_end"))-clock_time)
	if node.has_meta("_aux_tween"):
		var original: Tween=node.get_meta("_aux_tween")
		if original.is_valid(): remaining=maxf(0.0,float(node.get_meta("_aux_tween_length"))-original.get_total_elapsed_time())
	if remaining<=.000001: return
	var correction := clock_time+remaining-float(node.get_meta("feedback_end"))
	if correction!=0.0:
		for key in ["feedback_start","feedback_end","feedback_delay"]: node.set_meta(key,float(node.get_meta(key))+correction)
		if node.has_meta("_feedback_record"):
			var record: Array=node.get_meta("_feedback_record").duplicate()
			record[0]=float(record[0])+correction
			record[1]=float(record[1])+correction
			node.set_meta("_feedback_record",record)
	var exiting := _aux_wait_node_exiting.bind(node)
	if not node.tree_exiting.is_connected(exiting): node.tree_exiting.connect(exiting)
	if not node.has_meta("_aux_wait_first"): node.set_meta("_aux_wait_first",clock_time)
	_aux_waiters[node]={"visible":node.visible,"last":clock_time,"remaining":remaining,"generation":_generation}
	_aux_retry_queue.append(node)
	_aux_hold_count+=1
	_aux_max_waiters=maxi(_aux_max_waiters,_aux_waiters.size())
	node.set_meta("_aux_waiting",true)
	node.visible=false
	if node.has_meta("_aux_tween"):
		var tween: Tween=node.get_meta("_aux_tween")
		if tween.is_valid():
			tween.set_speed_scale(0.0)
			tween.pause()
			_forget_tween(tween)
	# Keep the bound node/Tween alive in the SAME canvas/tree, outside active
	# feedback collection, native score, peer views and every-frame label routing.
	if node.get_parent()==_screen_effects: node.reparent(_feedback_waiting)
	_feedback_owned_valid=false
	_feedback_owned_clock=-INF
	_feedback_owned_generation+=1
	_aux_callback_publish(node)


func _aux_advance_waiters() -> void:
	if _aux_waiters.is_empty() or _paused_visuals or clock_time==_aux_wait_clock: return
	_aux_wait_clock=clock_time
	if clock_time<_aux_retry_clock+.05: return
	_aux_retry_clock=clock_time
	_aux_max_wait_age=maxf(_aux_max_wait_age,_aux_waiting_oldest_age())
	# Select a bounded FIFO batch; no per-clock walk/metadata writes over the
	# unbounded backlog. Elapsed time is materialized ONLY for attempted rows.
	var selected: Array[Control]=[]
	var states: Array[Dictionary]=[]
	var visits := _aux_retry_queue.size()
	while selected.size()<4 and visits>0 and not _aux_retry_queue.is_empty():
		visits-=1
		var value: Variant=_aux_retry_queue.pop_front()
		if not is_instance_valid(value):
			_aux_waiters.erase(value)
			continue
		var node: Control=value
		if not _aux_waiters.has(node): continue
		if node.is_queued_for_deletion():
			_aux_waiters.erase(node)
			continue
		var state: Dictionary=_aux_waiters[node]
		if int(state.generation)!=_generation:
			_aux_waiters.erase(node)
			continue
		var elapsed := maxf(0.0,clock_time-float(state.last))
		state.last=clock_time
		for key in ["feedback_start","feedback_end","feedback_delay"]: node.set_meta(key,float(node.get_meta(key))+elapsed)
		if node.has_meta("_feedback_record"):
			var record: Array=node.get_meta("_feedback_record").duplicate()
			record[0]=float(record[0])+elapsed
			record[1]=float(record[1])+elapsed
			node.set_meta("_feedback_record",record)
		# Rejoin hidden first: the following shared snapshot has a slot for every
		# attempted node, but no unlocated row reserves space until it succeeds.
		node.reparent(_screen_effects)
		selected.append(node)
		states.append(state)
	if selected.is_empty(): return
	_feedback_owned_valid=false
	_feedback_owned_clock=-INF
	_feedback_owned_generation+=1
	_aux_begin_route()
	for index in range(selected.size()):
		var node: Control=selected[index]
		var state: Dictionary=states[index]
		_aux_waiters.erase(node)
		node.set_meta("_aux_waiting",false)
		node.visible=bool(state.visible)
		if node is Label:
			node.set_meta("_hf_clock",clock_time)
			_route_feedback_label(node,_bd_aim_keepout())
		else: _route_reward_popup(node,_bd_aim_keepout())
		_aux_refresh_route(node)
		if bool(node.get_meta("_aux_waiting",false)):
			# Strict oldest-first: do not let newer/smaller rows consume the next
			# opening while this oldest row still has no safe readable location.
			_aux_retry_queue.erase(node)
			_aux_retry_queue.push_front(node)
			for pending in range(selected.size()-1,index,-1):
				var later: Control=selected[pending]
				later.reparent(_feedback_waiting)
				_aux_retry_queue.push_front(later)
			_aux_retry_queue.erase(node)
			_aux_retry_queue.push_front(node)
			break
		_aux_resume_count+=1
		_aux_max_wait_age=maxf(_aux_max_wait_age,clock_time-float(node.get_meta("_aux_wait_first",clock_time)))
		if node.has_meta("_aux_wait_first"): node.remove_meta("_aux_wait_first")
		if node.has_meta("_aux_tween"):
			var tween: Tween=node.get_meta("_aux_tween")
			if tween.is_valid() and not bool(tween.get_meta("_world_finished",false)):
				if not _tweens.has(tween): _tweens.append(tween)
				tween.set_speed_scale(1.0)
				tween.play()
	_aux_end_route()


func _aux_pack_placement(node: Control, preferred: Vector2, size_value: Vector2, keepout: Rect2, travel: Vector2, start: float, end: float, peers: Array[Dictionary]) -> Dictionary:
	var bounds := _aux_feedback_bounds()
	var offset := travel.min(Vector2.ZERO)-Vector2(4,4)
	var footprint := size_value+travel.abs()+Vector2(8,8)
	var wanted := preferred+offset
	var preferred_sweep := Rect2(wanted,footprint)
	if bounds.encloses(preferred_sweep) and (not keepout.has_area() or not preferred_sweep.intersects(keepout.grow(6))):
		if not _aux_sweep_occupied(preferred_sweep,start,end,node,peers): return {"position":preferred,"safe":true}
	# Axis-aligned rectangle packing: for each obstacle-bottom scanline, find
	# horizontal free intervals in x order. Complete peer sweeps/time windows
	# remain obstacles; there is no node/event cap and no distance-sort per row.
	var blockers: Array[Rect2]=[]
	if _aux_route_active:
		var own := int(_aux_route_indices.get(node,-1))
		for index: int in _aux_route_order:
			if index==own or end+.05<_aux_route_starts[index] or start>_aux_route_ends[index]+.05: continue
			if _aux_route_rects[index].has_area(): blockers.append(_aux_route_rects[index])
	else:
		for peer: Dictionary in peers:
			if end+.05<float(peer.start) or start>float(peer.end)+.05: continue
			if (peer.rect as Rect2).has_area(): blockers.append(peer.rect)
		blockers.sort_custom(func(a: Rect2,b: Rect2) -> bool: return a.position.x<b.position.x)
	if keepout.has_area():
		var obstacle := keepout.grow(6)
		var insert_at := 0
		while insert_at<blockers.size() and blockers[insert_at].position.x<obstacle.position.x: insert_at+=1
		blockers.insert(insert_at,obstacle)
	var rows: Array[float]=[clampf(wanted.y,bounds.position.y,bounds.end.y-footprint.y),bounds.position.y]
	for rect: Rect2 in blockers:
		if rect.end.y+.01>=bounds.position.y and rect.end.y+.01+footprint.y<=bounds.end.y: rows.append(rect.end.y+.01)
	for y: float in rows:
		var cursor := bounds.position.x
		var best := INF
		var best_x := cursor
		for rect: Rect2 in blockers:
			if y+footprint.y<=rect.position.y or y>=rect.end.y: continue
			var gap_end := minf(rect.position.x,bounds.end.x)-footprint.x
			if cursor<=gap_end:
				var x := clampf(wanted.x,cursor,gap_end)
				if absf(x-wanted.x)<best: best=absf(x-wanted.x);best_x=x
			cursor=maxf(cursor,rect.end.x+.01)
			if cursor+footprint.x>bounds.end.x: break
		if cursor+footprint.x<=bounds.end.x:
			var x := clampf(wanted.x,cursor,bounds.end.x-footprint.x)
			if absf(x-wanted.x)<best: best=absf(x-wanted.x);best_x=x
		if best<INF: return {"position":Vector2(best_x,y)-offset,"safe":true}
	return {"position":preferred,"safe":false}


func _aux_initialize_layout() -> void:
	if _safe_layout_checked: return
	_safe_layout_checked=true
	if not ClassDB.class_exists("RoundCardSafeLayoutMath") and OS.has_feature("windows"):
		GDExtensionManager.load_extension("res://native/safe_layout/safe_layout.gdextension")
	if ClassDB.class_exists("RoundCardSafeLayoutMath"): _safe_layout_math=ClassDB.instantiate("RoundCardSafeLayoutMath")
	if _safe_layout_math!=null: _safe_layout_indexed=_safe_layout_math.has_method("find_first_indexed")


func _aux_candidate_geometry(preferred: Vector2, size_value: Vector2, keepout: Rect2, travel: Vector2) -> Dictionary:
	var bounds := _aux_feedback_bounds()
	var obstacle := keepout.grow(6)
	var candidates: Array[Vector2]=[preferred]
	if keepout.has_area(): candidates.append_array([Vector2(obstacle.position.x-size_value.x-8,preferred.y),Vector2(obstacle.end.x+8,preferred.y),Vector2(preferred.x,obstacle.position.y-size_value.y-8),Vector2(preferred.x,obstacle.end.y-travel.y+8)])
	var step := size_value+travel.abs()+Vector2(18,18)
	for delta in [Vector2(0,-1),Vector2(-1,0),Vector2(1,0),Vector2(0,1),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]: candidates.append(preferred+delta*step)
	for x in [bounds.position.x+8,bounds.end.x-size_value.x-8]:
		for y in [preferred.y,bounds.position.y+absf(travel.y)+8,bounds.end.y-size_value.y-8]: candidates.append(Vector2(x,y))
	for row in range(8):
		for column in range(6): candidates.append(Vector2(lerpf(bounds.position.x+8,bounds.end.x-size_value.x-8,column/5.0),lerpf(bounds.position.y+absf(travel.y)+8,bounds.end.y-size_value.y-8,row/7.0)))
	var positions: Array[Vector2]=[]
	var sweeps: Array[Rect2]=[]
	for candidate: Vector2 in candidates:
		var finish := candidate+travel
		var sweep := Rect2(candidate.min(finish),size_value+travel.abs()).grow(4)
		if not bounds.encloses(sweep) or (keepout.has_area() and sweep.intersects(obstacle)): continue
		positions.append(candidate)
		sweeps.append(sweep)
	return {"positions":positions,"sweeps":sweeps}


func _aux_layout_first(sweeps: Array[Rect2], peers: Array[Dictionary], delays: PackedFloat64Array, start: float, duration: float, node: Control) -> Vector2i:
	var records: Array=[]
	var own := -1
	if _aux_route_active:
		records=_aux_native_records
		own=int(_aux_route_indices.get(node,-1))
	else:
		for peer: Dictionary in peers:
			if (peer.rect as Rect2).has_area(): records.append([peer.rect,float(peer.start),float(peer.end)])
	return _aux_query_records(sweeps,records,delays,start,duration,own)

func _aux_query_records(sweeps: Array[Rect2], records: Array, delays: PackedFloat64Array, start: float, duration: float, own: int) -> Vector2i:
	var result := Vector2i(-2,-2)
	if _safe_layout_math!=null:
		_aux_native_calls+=1
		if _safe_layout_indexed: result=_safe_layout_math.find_first_indexed(sweeps,records,delays,start,duration,own)
		else:
			var filtered: Array=[]
			for index in range(records.size()):
				if index!=own and (records[index][0] as Rect2).has_area(): filtered.append(records[index])
			result=_safe_layout_math.find_first(sweeps,filtered,delays,start,duration)
	if result==Vector2i(-2,-2):
		_aux_fallback_calls+=1
		result=Vector2i(-1,-1)
		for delay_index in range(delays.size()):
			for index in range(sweeps.size()):
				var occupied := false
				for peer_index in range(records.size()):
					if peer_index==own: continue
					var record: Array=records[peer_index]
					if not (record[0] as Rect2).has_area(): continue
					if start+delays[delay_index]+duration+.05<float(record[1]) or start+delays[delay_index]>float(record[2])+.05: continue
					if sweeps[index].intersects(record[0]): occupied=true;break
				if not occupied: result=Vector2i(index,delay_index);break
			if result.x>=0: break
	return result

func _route_damage_text_overlap(label: Label, keepout: Rect2) -> void:
	var offset: Vector2=label.get_meta("_hf_offset")
	# A peer-safe offset is a reserved numeric path. The old circle helper may
	# propose returning to the original stack; keep this path until the complete
	# circle/peer reflow below chooses another safe one instead.
	label.set_meta("_hf_target",offset)
	_aux_ensure_callback_view()
	var current := Vector2(label.get_meta("_hf_nominal"))+offset
	var finish := Vector2(label.get_meta("_hf_end"))+offset
	var width := maxf(float(label.get_meta("feedback_width",label.size.x)),_aux_damage_ink_width(label))
	var ink_offset := Vector2((label.size.x-width)*.5,0)
	var preferred := current+ink_offset
	var size_value := Vector2(width,label.size.y)
	var travel := finish-current
	var start := maxf(clock_time,float(label.get_meta("feedback_start")))
	var end := float(label.get_meta("feedback_end"))
	var own := int(_aux_damage_indices.get(label,-1))
	var sweep := Rect2(preferred.min(preferred+travel),size_value+travel.abs()).grow(4)
	var occupied := keepout.has_area() and sweep.intersects(keepout.grow(6))
	if not occupied:
		for index in range(_aux_damage_records.size()):
			if index==own: continue
			var record: Array=_aux_damage_records[index]
			if end+.05<float(record[1]) or start>float(record[2])+.05: continue
			if sweep.intersects(record[0]): occupied=true;break
	if not occupied:
		_aux_yield_to_damage(label,sweep,start,end)
		return
	var geometry := _aux_candidate_geometry(preferred,size_value,keepout,travel)
	var chosen := _aux_query_records(geometry.sweeps,_aux_damage_records,PackedFloat64Array([0.0]),start,maxf(.001,end-start),own)
	var placement := {"position":preferred,"safe":false}
	if chosen.x>=0: placement={"position":geometry.positions[chosen.x],"safe":true}
	else:
		var peers: Array[Dictionary]=[]
		for peer: Dictionary in _aux_damage_peers:
			if peer.node!=label: peers.append(peer)
		# Rare complete-field fallback, sharing the already collected damage peers.
		# No await/callback runs while this pure rectangle query is in progress.
		_aux_route_active=false
		placement=_aux_pack_placement(label,preferred,size_value,keepout,travel,start,end,peers)
		_aux_route_active=true
	if not bool(placement.safe):
		_aux_yield_to_damage(label,sweep,start,end)
		return
	var delta := Vector2(placement.position)-preferred
	if delta!=Vector2.ZERO:
		offset+=delta
		_set_feedback_offset(label,offset)
		label.set_meta("_hf_target",offset)
		label.position=Vector2(label.get_meta("_hf_nominal"))+offset
		_aux_refresh_route(label)
	var shifted := Rect2(Vector2(placement.position).min(Vector2(placement.position)+travel),size_value+travel.abs()).grow(4)
	_aux_yield_to_damage(label,shifted,start,end)

func _aux_yield_to_damage(label: Label, sweep: Rect2, start: float, end: float) -> void:
	# A new number can already occupy its correct unchanged position. It still
	# takes precedence over older auxiliaries. Reparenting a held peer invalidates
	# callback views, so iterate a local snapshot rather than clearing our iterator.
	var peers := _aux_route_peers.duplicate()
	for peer: Dictionary in peers:
		if end+.05<float(peer.start) or start>float(peer.end)+.05 or not sweep.intersects(peer.rect): continue
		var other: Control=peer.node
		if other==label or other.has_meta("damage_value") or bool(peer.get("external",false)): continue
		if other.has_meta("bd_trigger") or other.has_meta("coins"):
			_aux_hold(other)
			_aux_refresh_route(other)


func _aux_fast_placement(node: Control, preferred: Vector2, size_value: Vector2, keepout: Rect2, travel: Vector2, start: float, end: float, peers: Array[Dictionary]) -> Dictionary:
	var geometry := _aux_candidate_geometry(preferred,size_value,keepout,travel)
	var chosen := _aux_layout_first(geometry.sweeps,peers,PackedFloat64Array([0.0]),start,maxf(.001,end-start),node)
	if chosen.x>=0: return {"position":geometry.positions[chosen.x],"safe":true}
	# Exact whole-field gap packing distinguishes missing local candidates from
	# genuinely full space. Only the latter enters the readable-time queue.
	return _aux_pack_placement(node,preferred,size_value,keepout,travel,start,end,peers)


func feedback_waiting_snapshot() -> Array[Dictionary]:
	# Explicit QA only. Unlike the O(1) benchmark metrics this may inspect backlog.
	var rows: Array[Dictionary]=[]
	for value in _aux_waiters.keys():
		if not is_instance_valid(value): continue
		var node: Control=value
		var state: Dictionary=_aux_waiters[node]
		var row := {"instance_id":node.get_instance_id(),"name":node.name,"inside_tree":node.is_inside_tree(),"parent":node.get_parent().name,"visible":node.visible,"alpha":node.modulate.a,"remaining":float(state.remaining),"materialized_clock":float(state.last),"elapsed_unmaterialized":maxf(0.0,clock_time-float(state.last))}
		for key in ["root_id","source_tick","family","source_count","damage_value","coins","card_count","feedback_start","feedback_end","feedback_duration"]:
			if node.has_meta(key): row[key]=node.get_meta(key)
		rows.append(row)
	return rows


func _aux_wait_node_exiting(node: Control) -> void:
	if node.is_queued_for_deletion():
		_aux_waiters.erase(node)
		_aux_retry_queue.erase(node)


func _aux_tween_finished(node: Control) -> void:
	if not is_instance_valid(node): return
	_aux_unindex_density_row(node)
	if not bool(node.get_meta("_aux_waiting",false)): return
	# A hold requested inside the last method step cannot rewind that already
	# completed step. Retire through the original deferred callback/label pool,
	# rather than keeping a finished-but-valid Tween as an orphan queue entry.
	_aux_waiters.erase(node)
	_aux_retry_queue.erase(node)
	node.set_meta("_aux_waiting",false)
	if node.get_parent()==_feedback_waiting and not node.is_queued_for_deletion(): node.reparent(_screen_effects)
	_feedback_owned_valid=false
	_feedback_owned_clock=-INF
	_feedback_owned_generation+=1


func high_density_feedback() -> bool:
	return not _aux_waiters.is_empty() or (is_instance_valid(_screen_effects) and _screen_effects.get_child_count()>=40)

func _aux_readable_seconds(node: Control) -> float:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or node.modulate.a<.65: return 0.0
	var remaining := maxf(0.0,float(node.get_meta("feedback_end",clock_time))-clock_time)
	if _aux_waiters.has(node): remaining=float(_aux_waiters[node].remaining)
	elif node.has_meta("_aux_tween"):
		var tween: Tween=node.get_meta("_aux_tween")
		if not tween.is_valid(): return 0.0
		remaining=maxf(0.0,float(node.get_meta("_aux_tween_length",0.0))-tween.get_total_elapsed_time())
	return minf(float(node.get_meta("feedback_duration",0.0)),remaining)

func _aux_find_density_row(index: Dictionary, key: String) -> Control:
	var kept: Array=[]
	var chosen: Control
	for reference: WeakRef in index.get(key,[]):
		var value: Variant=reference.get_ref()
		if not is_instance_valid(value) or not value is Control: continue
		var node: Control=value
		if not node.is_inside_tree() or node.is_queued_for_deletion() or str(node.get_meta("_aux_density_key",""))!=key: continue
		kept.append(reference)
		if _aux_readable_seconds(node)>=.32: chosen=node
	if kept.is_empty(): index.erase(key)
	else: index[key]=kept
	return chosen

func _aux_index_density_row(index: Dictionary, key: String, node: Control, kind: String) -> void:
	if not index.has(key): index[key]=[]
	index[key].append(weakref(node))
	node.set_meta("_aux_density_key",key)
	node.set_meta("_aux_density_kind",kind)

func _aux_unindex_density_row(node: Control) -> void:
	var kind := str(node.get_meta("_aux_density_kind",""))
	if kind.is_empty(): return
	var index: Dictionary=_aux_density_bd_rows if kind=="bd" else _aux_density_reward_rows
	var key := str(node.get_meta("_aux_density_key",""))
	var kept: Array=[]
	for reference: WeakRef in index.get(key,[]):
		var other: Variant=reference.get_ref()
		if is_instance_valid(other) and other!=node: kept.append(reference)
	if kept.is_empty(): index.erase(key)
	else: index[key]=kept

func _aux_bd_key(group: Dictionary) -> String:
	return "bd:%d:%s:%s"%[int(group.root_id),str(group.family),str(group.element)]

func _aux_try_fold_bd(group: Dictionary) -> bool:
	if int(group.root_id)<=0 or not high_density_feedback(): return false
	var node: Control=_aux_find_density_row(_aux_density_bd_rows,_aux_bd_key(group))
	if not node is Label: return false
	var label: Label=node
	var mechanics: Array=label.get_meta("mechanics").duplicate()
	var texts: Array=label.get_meta("source_texts").duplicate()
	var ticks: Array=label.get_meta("source_ticks").duplicate()
	mechanics.append_array(group.mechanics)
	texts.append_array(group.texts)
	ticks.append_array(group.source_ticks)
	label.set_meta("mechanics",mechanics)
	label.set_meta("source_texts",texts)
	label.set_meta("source_ticks",ticks)
	label.set_meta("source_count",mechanics.size())
	label.set_meta("bd_count",mechanics.size())
	label.set_meta("high_density_merged",true)
	label.tooltip_text="本次攻击 %d 项真实构筑提示：%s"%[mechanics.size()," / ".join(texts)]
	var text := _bd_group_text({"family":group.family,"mechanics":mechanics,"texts":texts})
	var old_size := label.size
	label.text=text
	var size_value := Vector2(_damage_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+16.0,_damage_font.get_height(24)+8.0).ceil()
	label.size=size_value
	var record: Array=label.get_meta("_feedback_record").duplicate()
	record[5]=Vector2.ZERO
	record[6]=size_value
	record[7]=size_value.x
	label.set_meta("_feedback_record",record)
	label.set_meta("feedback_width",size_value.x)
	var offset: Vector2=label.get_meta("_hf_offset")
	offset.x+=(old_size.x-size_value.x)*.5
	_set_feedback_offset(label,offset,true)
	label.set_meta("_hf_target",offset)
	label.position=Vector2(label.get_meta("_hf_nominal"))+offset
	if not bool(label.get_meta("_aux_waiting",false)): _route_feedback_label(label,_bd_aim_keepout())
	_feedback_bd_shown_sources+=group.mechanics.size()
	_aux_bd_folded_groups+=1
	_aux_bd_folded_sources+=group.mechanics.size()
	return true

func _aux_append_reward_item(row: HBoxContainer, texture: Texture2D, amount: int, icon_name: String, label_name: String) -> void:
	var icon := TextureRect.new()
	icon.name=icon_name
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.texture=texture
	icon.custom_minimum_size=Vector2(26,26)
	icon.size=Vector2(26,26)
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name=label_name
	label.text="+%d"%amount
	_style_feedback_label(label,24)
	row.add_child(label)
	if icon_name=="CoinIcon":
		row.move_child(icon,0)
		row.move_child(label,1)

func _aux_try_fold_reward(root_id: int, source_tick: int, coins: int, cards_value: int, destroyed: int, forced: bool) -> bool:
	if root_id<=0 or (not forced and not high_density_feedback()): return false
	var key := "reward:%d"%root_id
	var popup: Control=_aux_find_density_row(_aux_density_reward_rows,key)
	if popup==null: return false
	var old_coins := int(popup.get_meta("coins"))
	var old_cards := int(popup.get_meta("card_count"))
	if old_coins>9223372036854775807-coins or old_cards>9223372036854775807-cards_value: return false
	var total_coins := old_coins+coins
	var total_cards := old_cards+cards_value
	var row: HBoxContainer=popup.get_node("Contents")
	var coin_label: Label=row.get_node_or_null("CoinAmount")
	var card_label: Label=row.get_node_or_null("CardAmount")
	if total_coins>0:
		if coin_label!=null: coin_label.text="+%d"%total_coins
		else: _aux_append_reward_item(row,_coin_icon,total_coins,"CoinIcon","CoinAmount")
	if total_cards>0:
		if card_label!=null: card_label.text="+%d"%total_cards
		else: _aux_append_reward_item(row,generic_card_texture(0),total_cards,"ActualCardIcon","CardAmount")
	popup.set_meta("coins",total_coins)
	popup.set_meta("card_count",total_cards)
	popup.set_meta("destroyed",int(popup.get_meta("destroyed",0))+destroyed)
	popup.set_meta("high_density_merged",true)
	var ticks: Array=popup.get_meta("source_ticks").duplicate()
	ticks.append(source_tick)
	popup.set_meta("source_ticks",ticks)
	var summaries: Array=popup.get_meta("reward_sources").duplicate(true)
	summaries.append({"root_id":root_id,"tick":source_tick,"coins":coins,"cards":cards_value,"destroyed":destroyed})
	popup.set_meta("reward_sources",summaries)
	var old_size := popup.size
	var size_value := _reward_row_size(total_coins,total_cards)
	popup.custom_minimum_size=size_value
	popup.size=size_value
	var offset: Vector2=popup.get_meta("_reward_avoid_offset")
	offset.x+=(old_size.x-size_value.x)*.5
	popup.set_meta("_reward_avoid_offset",offset)
	var home := Vector2(popup.get_meta("_reward_start"))+offset
	popup.set_meta("feedback_home",home)
	popup.set_meta("feedback_offset",home-Vector2(popup.get_meta("feedback_origin")))
	popup.set_meta("feedback_width",size_value.x)
	var record: Array=popup.get_meta("_feedback_record").duplicate()
	record[2]=home
	record[3]=Vector2(popup.get_meta("_reward_end"))+offset
	record[5]=Vector2.ZERO
	record[6]=size_value
	record[7]=size_value.x
	popup.set_meta("_feedback_record",record)
	popup.position=Vector2(popup.get_meta("_reward_nominal"))+offset
	_feedback_owned_valid=false
	_feedback_owned_clock=-INF
	_feedback_owned_generation+=1
	if not bool(popup.get_meta("_aux_waiting",false)): _route_reward_popup(popup,_bd_aim_keepout())
	_feedback_reward_coins+=coins
	_feedback_reward_cards+=cards_value
	_aux_reward_folded_sources+=1
	return true

func _aux_waiting_oldest_age() -> float:
	if _aux_retry_queue.is_empty(): return 0.0
	var value: Variant=_aux_retry_queue[0]
	if not is_instance_valid(value): return 0.0
	return maxf(0.0,clock_time-float(value.get_meta("_aux_wait_first",clock_time)))



func _effect_frame_snapshot() -> Dictionary:
	# Fresh every process AFTER advance: includes this tick's new nodes and skips
	# only nodes already queued by their unchanged original expiry method.
	var all: Array[Node3D]=[]
	var normal: Array[Node3D]=[]
	var cosmetic: Array[Node3D]=[]
	for child in _effects.get_children():
		if child.is_queued_for_deletion(): continue
		if child is QualityEffect:
			var effect: QualityEffect=child
			all.append(effect)
			if effect.cosmetic_fragment: cosmetic.append(effect)
			else: normal.append(effect)
		elif child is SkillEffect:
			var effect: SkillEffect=child
			all.append(effect)
			if bool(effect.data.get("cosmetic_fragment",false)): cosmetic.append(effect)
			else: normal.append(effect)
	return {"all":all,"normal":normal,"cosmetic":cosmetic}


func _aux_birth_reject(reason: String) -> bool:
	_birth_rejections[reason]=int(_birth_rejections.get(reason,0))+1
	return false

func _aux_birth_children_changed() -> void:
	_aux_birth_structure+=1

func _aux_birth_control_peer(other: Node, exclude: Control, duration: float) -> Dictionary:
	if not other is Control or other==exclude or other.is_queued_for_deletion(): return {}
	var control: Control=other
	if not control.visible and not control.has_meta("feedback_start"): return {}
	var end := float(control.get_meta("feedback_end",clock_time+duration+.1))
	if end<clock_time-.05: return {}
	return {"node":control,"fixed_end":control.has_meta("feedback_end"),"rect":_aux_control_sweep(control),"start":float(control.get_meta("feedback_start",clock_time)),"end":end}

func _aux_birth_try_append(label: Label) -> bool:
	# Accept exactly one known synchronous owned numeric insertion. The tree-order
	# signal rejects remove/reparent/reorder even when the net child count is +1.
	if not label.has_meta("damage_value") or not _feedback_batch_active or _feedback_initializing_label!=label or not _feedback_owned_valid: return _aux_birth_reject("birth_context")
	if not _aux_callback_active or not _aux_route_active or not _aux_birth_view_owned: return _aux_birth_reject("view_context")
	if _aux_callback_clock!=clock_time or _aux_callback_generation!=_feedback_owned_generation or _aux_callback_viewport!=get_viewport().get_visible_rect().size or _aux_callback_external!=_aux_external_generation: return _aux_birth_reject("clock_generation_view_external")
	if _aux_birth_structure!=_aux_birth_callback_structure+1 or _screen_effects.get_child_count()!=_aux_callback_children+1 or _screen_effects.get_child(-1)!=label or label.get_parent()!=_screen_effects or _aux_route_indices.has(label): return _aux_birth_reject("tree_single_birth")
	var peer := _aux_birth_control_peer(label,null,0.0)
	if peer.is_empty() or not bool(peer.fixed_end): return _aux_birth_reject("peer_invalid")
	# Fresh collector order is screen rows followed by <=2 external badge rows.
	var at := _aux_route_peers.size()
	while at>0 and bool(_aux_route_peers[at-1].get("external",false)): at-=1
	for index in range(at,_aux_route_peers.size()): _aux_route_indices[_aux_route_peers[index].node]=index+1
	_aux_route_peers.insert(at,peer)
	_aux_route_indices[label]=at
	_aux_route_rects.insert(at,peer.rect)
	_aux_route_starts.insert(at,peer.start)
	_aux_route_ends.insert(at,peer.end)
	_aux_native_records.insert(at,[peer.rect,peer.start,peer.end])
	# Rebuild only integer ordering with the identical comparator/tie input.
	_aux_route_order.clear()
	for index in range(_aux_route_peers.size()): _aux_route_order.append(index)
	_aux_route_order.sort_custom(func(a: int,b: int) -> bool: return _aux_route_rects[a].position.x<_aux_route_rects[b].position.x)
	var damage_at := _aux_damage_peers.size()
	while damage_at>0 and bool(_aux_damage_peers[damage_at-1].get("external",false)): damage_at-=1
	for index in range(damage_at,_aux_damage_peers.size()): _aux_damage_indices[_aux_damage_peers[index].node]=index+1
	_aux_damage_peers.insert(damage_at,peer)
	_aux_damage_records.insert(damage_at,_aux_native_records[at])
	_aux_damage_indices[label]=damage_at
	_aux_callback_children=_screen_effects.get_child_count()
	_aux_birth_callback_structure=_aux_birth_structure
	_birth_fast_appends+=1
	return true


func _skin_texture(path: String) -> Texture2D:
	if _skin_texture_cache.has(path): return _skin_texture_cache[path]
	var texture: Texture2D=_geo.texture(path)
	if texture!=null: _skin_texture_cache[path]=texture
	return texture

func set_skin_set(equipped: Dictionary) -> void:
	_skin_mesh_cache.clear()
	_equipped_board_skin=str(equipped.get("board","default"))
	_equipped_pack_skin=str(equipped.get("pack","default"))
	_pack_materials.clear()
	for grade in range(5):
		var torn: ShaderMaterial=_geo.pack_material(grade)
		torn.set_shader_parameter("damage_level",3)
		_apply_wrapper_skin(torn,grade)
		_torn_materials[grade]=torn
	var surface := _stage.find_child("SolidWoodTable",true,false) as MeshInstance3D
	if surface!=null:
		var path := WOOD_PATH
		if _equipped_board_skin!="default":
			path="res://assets/skins/board_%s.png" % ("neon" if _equipped_board_skin=="board_neon" else "starlight")
		if _equipped_board_skin=="default":
			surface.material_override=_default_desk_material
		else:
			var texture := _skin_texture(path)
			var material := _default_desk_material.duplicate() as StandardMaterial3D
			material.albedo_texture=texture
			surface.material_override=material

func get_skin_state() -> Dictionary:
	return {"board":_equipped_board_skin,"pack":_equipped_pack_skin,"material_grades":_pack_materials.keys(),"default_desk_material_restored":(_stage.find_child("SolidWoodTable",true,false) as MeshInstance3D).material_override==_default_desk_material,"textures_loaded":_skin_texture_cache.keys()}


func _apply_wrapper_skin(material: ShaderMaterial, grade: int) -> void:
	if _equipped_pack_skin=="default": return
	var family := "neon" if _equipped_pack_skin=="pack_neon" else "starlight"
	var texture := _skin_texture("res://assets/skins/pack_%s_%d.png" % [family,grade])
	if texture==null: return
	material.set_shader_parameter("print_texture",texture)
	material.set_shader_parameter("crop_rect",Vector4(0,0,1,1))
	material.set_shader_parameter("damage_target_rect",Vector4(.08,.08,.84,.84))
	material.set_shader_parameter("art_texel_size",Vector2.ONE/texture.get_size())
	material.set_shader_parameter("skin_wrapper",true)

func _skin_pack_mesh(original: ArrayMesh, grade: int) -> ArrayMesh:
	var key := str(original.get_instance_id())+":"+_equipped_pack_skin
	if _skin_mesh_cache.has(key): return _skin_mesh_cache[key]
	var arrays := original.surface_get_arrays(0)
	var coordinates: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var layout: Dictionary=_geo.pack_layout(grade)
	var crop: Rect2i=layout.crop
	var canvas: Vector2i=layout.canvas
	var offset := Vector2(crop.position)/Vector2(canvas)
	var extent := Vector2(crop.size)/Vector2(canvas)
	var original_texture: Texture2D=_geo.texture(str(layout.path))
	var original_pixels: Rect2i=_visible_alpha_rect(original_texture)
	var destination := Rect2((Vector2(original_pixels.position)-Vector2(crop.position))/Vector2(crop.size),Vector2(original_pixels.size)/Vector2(crop.size))
	var family := "neon" if _equipped_pack_skin=="pack_neon" else "starlight"
	var source: Texture2D=_skin_texture("res://assets/skins/pack_%s_%d.png" % [family,grade])
	var used: Rect2i=_visible_alpha_rect(source)
	var sampling := Rect2(Vector2(used.position)/source.get_size(),Vector2(used.size)/source.get_size())
	for i in range(coordinates.size()):
		var normalized := (coordinates[i]-offset)/extent
		coordinates[i]=sampling.position+(normalized-destination.position)/destination.size*sampling.size
	arrays[Mesh.ARRAY_TEX_UV]=coordinates
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_skin_mesh_cache[key]=mesh
	return mesh


func _visible_alpha_rect(texture: Texture2D) -> Rect2i:
	if texture==null: return Rect2i(0,0,1,1)
	var key := texture.get_instance_id()
	if _alpha_rect_cache.has(key): return _alpha_rect_cache[key]
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var left := width
	var top := height
	var right := -1
	var bottom := -1
	for y in range(height):
		for x in range(width):
			if data[(y*width+x)*4+3] < 57: continue
			left=mini(left,x); top=mini(top,y); right=maxi(right,x); bottom=maxi(bottom,y)
	var rect := Rect2i(left,top,right-left+1,bottom-top+1) if right>=left else Rect2i(0,0,width,height)
	_alpha_rect_cache[key]=rect
	return rect
