extends Node

const Sim = preload("res://scripts/simulation.gd")
const Storage = preload("res://scripts/save_store.gd")
const BattleSaveJournal = preload("res://scripts/battle_save_journal.gd")
const RenderFramePacer = preload("res://scripts/render_frame_pacer.gd")
const Rules = preload("res://scripts/pack_rules.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const Progression = preload("res://scripts/progression.gd")
const TalentTreeView = preload("res://scripts/talent_tree_view.gd")
const CardGrowth = preload("res://scripts/card_growth.gd")
const CardCatalog = preload("res://scripts/attack_spec.gd")
const CollectionCatalog = preload("res://scripts/collection_catalog.gd")
const CollectionAlbum = preload("res://scripts/collection_ui/collection_album.gd")
const SkinShop = preload("res://scripts/collection_ui/skin_shop.gd")
const SettlementView = preload("res://scripts/collection_ui/settlement_view.gd")
const CollectionGradeHUD = preload("res://scripts/collection_grade_hud.gd")
const BattleSkinLayer = preload("res://scripts/battle_skin_layer.gd")
const GROUPED_REWARD_MIN_PACKS := 6
const PREMIUM_READ_TICKS := 36 # 600ms @60Hz; name changes never restart the entry.
const PREMIUM_LIFETIME_TICKS := 84
const PREMIUM_SESSION_MAX_TICKS := 180
const PREMIUM_FADE_TICKS := 12
const PREMIUM_BANNER_SIZE := Vector2(680,64)
const HARVEST_BADGE_SIZE := Vector2(340,48)
const HARVEST_LIFETIME_TICKS := 24
const WorldView = preload("res://scripts/world_view.gd")
const AudioRouter = preload("res://scripts/audio_router.gd")
const RhythmHUD = preload("res://scripts/rhythm_hud.gd")
const RhythmTutorialView = preload("res://scripts/rhythm_tutorial_view.gd")
const SettingsInputHints = preload("res://scripts/settings_input_hints.gd")
const ControllerUI = preload("res://scripts/controller_ui.gd")
const InputDeviceRouter = preload("res://scripts/input_device_router.gd")
const BattleRhythmOverlay = preload("res://scripts/battle_rhythm_overlay.gd")
const BattleCoinHUD = preload("res://scripts/battle_coin_hud.gd")
const FeverBorderFX = preload("res://scripts/fever_border_fx.gd")
const EmitterEmblem = preload("res://scripts/ui_emblem.gd")
const ArcadeBackdrop = preload("res://scripts/ui_arcade_backdrop.gd")
const WorkshopSkin = preload("res://scripts/workshop_skin.gd")
const ArcadeFont = preload("res://assets/fonts/NotoSansCJKsc-Medium.otf")
const WorkshopPixelFont = preload("res://assets/fonts/ark-pixel-12px-proportional-zh_hans.otf")
const ArcadeFallback = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const CardFoilShader = preload("res://assets/card_foil_ui.gdshader")
const GDA_CALLABLE = ["get_debug_state", "get_target_screen_points"]
const DRUM_KEYS := ["pata","pon","don","chaka"]
const DRUM_DEVICE_HINTS := {"keyboard":"键盘：←PATA →PON ↓DON ↑CHAKA","joypad":"Xbox：X PATA · B PON · A DON · Y CHAKA"}
const FAMILY_NAMES = CardCatalog.FAMILY_NAMES
const GRADE_NAMES = ["白包","绿包","紫包","金包","红包"]
const GRADE_COLORS = [Color("#f4edd6"),Color("#6ee990"),Color("#cd8dff"),Color("#ffd15e"),Color("#ff737d")]
const INK = Color("#fff0cc")
const PAPER = Color("#29213f")
const MUTED = Color("#b6a5c5")
const GOLD = Color("#f1d7a4")
const CYAN = Color("#e8b4bd")

var world: Node3D
var ui: Control
var overlay: Control
var font: FontFile
var pixel_font: FontFile
var theme: Theme
var storage
var progression
var sim
var profile: Dictionary = {}
var slot: int = 1
var has_profile: bool = false
var screen: String = "menu"
var paused: bool = false
var prelude_frames: int = 0
var save_error: String = ""
var current_tab: String = "deck"
var last_mouse: Vector2 = Vector2(960,540)
var hud_time: Label
var hud_score: Label
var collection_grade_hud: Control
var battle_skin_layer: Control
var settlement_view: Control
var hud_coins: Control
var hud_loot: Label
var audio: Node
var screen_tween: Tween
var hover_tweens: Dictionary = {}
var card_textures: Dictionary = {}
var result_new_variants: Dictionary = {}
var result_new_run_id: String = ""
var settings_dirty: bool = false
var initialization_ok: bool = false
var _web_focus_callback: JavaScriptObject
var combat_feedback: Control
var feedback_entries: Array[Dictionary] = []
var _premium_tail: Dictionary = {}
var _premium_tail_seen: Dictionary = {}
var _harvest_queue: Array[Dictionary] = []
var _harvest_seen: Dictionary = {}
var _harvest_root_totals: Dictionary = {}
var last_combat_feedback: Dictionary = {}
var feedback_pulse_until: int = -1
var skin_paths_used: Array[String] = []
var _formal_style_cache: Dictionary = {}
var collection_grade_filter: int = -1
var collection_owned_only: bool = false
var collection_family_filter: int = -1
var hub_scroll_positions: Dictionary = {}
var talent_selected_id: String = "TAL-P"
var talent_view_state: Dictionary = {}
var hud_loadout_labels: Array[Label] = []
var hud_grade_counts: Array[Label] = []
var hud_grade_icons: Array[TextureRect] = []
var _battle_journal
var _journal_sim
var _journal_storage
var _journal_slot := 0
var _journal_run_id := ""
var performance_trace_enabled := false
var performance_stage_usec: Dictionary = {}
var frame_pacer: Node
var fever_border: Control
var rhythm_overlay: Control
var rhythm_hud: Control
var rhythm_input_queue: Array[Dictionary] = []
var rhythm_tutorial_seen := false
var prelude_total := 0
var last_rhythm_result: Dictionary = {}
var _rhythm_world_spec_key := ""
var drum_input_device := "keyboard"
var input_source := "keyboard"
var _active_joypad_device := -1
var _mouse_switch_distance := 0.0
var _mouse_switch_stamp := -1
var _mouse_focus_pending := false
var _pointer_position := Vector2(INF,INF)
var _dialog_return_focus: WeakRef
var _hub_album_navigation: Dictionary = {}
var _hub_skin_navigation: Dictionary = {}
var _hub_focus_names: Dictionary = {}
var _pause_return_button := "PauseResume"

func _ready() -> void:
	# Godot's default ui_accept contains keyboard keys only.
	var accept_pad := InputEventJoypadButton.new()
	accept_pad.device = -1
	accept_pad.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept",accept_pad):
		InputMap.action_add_event("ui_accept",accept_pad)
	Engine.max_fps = 60
	get_tree().auto_accept_quit = false
	font = ArcadeFont.duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.hinting = TextServer.HINTING_LIGHT
	font.oversampling = 0.0
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = 8
	font.msdf_size = 64
	var fallback_font: FontFile = ArcadeFallback.duplicate()
	fallback_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fallback_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	fallback_font.hinting = TextServer.HINTING_NONE
	fallback_font.oversampling = 1.0
	var fallback_chain: Array[Font] = [fallback_font]
	font.fallbacks = fallback_chain
	pixel_font = WorkshopPixelFont.duplicate()
	pixel_font.set_meta("interface_pixel",true)
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel_font.hinting = TextServer.HINTING_NONE
	pixel_font.oversampling = 1.0
	pixel_font.multichannel_signed_distance_field = false
	pixel_font.fallbacks = fallback_chain
	theme = Theme.new()
	theme.default_font = pixel_font
	theme.default_font_size = 32
	for control_type in ["Button","OptionButton","CheckButton","PopupMenu"]:
		theme.set_font("font",control_type,pixel_font)
		theme.set_font_size("font_size",control_type,36 if control_type=="Button" else 24)
	theme.set_font("font","TooltipLabel",pixel_font)
	var normal := _style(Color("#403354"),Color("#c3accb"),0,2)
	var hover := _style(Color("#584063"),CYAN,0,2)
	var pressed := _style(Color("#30233f"),GOLD,0,2)
	for key in ["normal","disabled"]:
		theme.set_stylebox(key,"Button",normal)
	theme.set_stylebox("disabled","Button",_style(Color("#302b3c"),Color("#776783"),0,1))
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("pressed","Button",pressed)
	theme.set_stylebox("focus","Button",_style(Color(0,0,0,0),CYAN,0,1))
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",INK)
	theme.set_color("font_pressed_color","Button",INK)
	theme.set_color("font_disabled_color","Button",Color("#a18eac"))
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","CheckButton",INK)
	theme.set_color("font_hover_color","CheckButton",CYAN)
	theme.set_stylebox("normal","CheckButton",_style(Color("#352944"),Color("#aa93b5"),0,1))
	theme.set_stylebox("hover","CheckButton",_style(Color("#4e3a5e"),CYAN,0,1))
	theme.set_stylebox("focus","CheckButton",_style(Color(0,0,0,0),GOLD,0,1))
	for state in ["checked","checked_disabled","unchecked","unchecked_disabled"]:
		theme.set_icon(state,"CheckButton",_toggle_icon(state.begins_with("checked"),state.ends_with("disabled")))
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		theme.set_icon(state,"HSlider",_slider_icon(state=="grabber_highlight",state=="grabber_disabled"))
	theme.set_stylebox("panel","TooltipPanel",_style(Color("#21192f"),CYAN,0,1))
	theme.set_color("font_color","TooltipLabel",INK)
	theme.set_font_size("font_size","TooltipLabel",24)
	for state in ["normal","hover","pressed","disabled","focus"]:
		theme.set_stylebox(state,"OptionButton",theme.get_stylebox(state,"Button"))
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		theme.set_color(state,"OptionButton",theme.get_color(state,"Button"))
	theme.set_stylebox("panel","PopupMenu",_style(PAPER,CYAN,0,2))
	theme.set_stylebox("hover","PopupMenu",_style(Color("#584063"),CYAN,0,1))
	theme.set_color("font_color","PopupMenu",INK)
	theme.set_color("font_hover_color","PopupMenu",GOLD)
	for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var scrollbar_style := _pixel_style(Color("#21192f") if state=="scroll" else Color("#947c9f"),Color("#5f4973") if state=="scroll" else CYAN,0,1)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			scrollbar_style.set_content_margin(side,0)
			scrollbar_style.set_texture_margin(side,8)
		theme.set_stylebox(state,"VScrollBar",scrollbar_style)
	world = WorldView.new()
	world.name = "World"
	add_child(world)
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	ui = Control.new()
	ui.name = "Screen"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(ui)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = theme
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(overlay)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void:
		if input_source=="mouse": _queue_mouse_focus()
		elif overlay.get_child_count()>0: _ensure_ui_focus()
	)
	audio = AudioRouter.new()
	audio.name = "Audio"
	add_child(audio)
	var save_base: String = "user://rhythm-workshop-v15"
	var harness := get_node_or_null("/root/GdaHarness")
	if harness!=null and harness.has_method("is_daemon_launched") and harness.is_daemon_launched():
		save_base = "user://gda-rhythm-workshop-v15"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_base = argument.trim_prefix("--save-dir=")
	storage = Storage.new(save_base)
	progression = Progression.new(storage)
	var loaded: Dictionary = storage.load_slot(slot)
	if bool(loaded.get("ok",false)):
		profile = loaded["profile"]
		has_profile = bool(loaded.get("exists",false))
	else:
		profile = storage.default_profile()
		save_error = str(loaded.get("error","无法读取存档"))
	_apply_settings()
	_prewarm_battle_ui()
	frame_pacer = RenderFramePacer.new()
	frame_pacer.name = "RenderFramePacer"
	add_child(frame_pacer)
	# This last sibling observes events before nested UI handlers consume them.
	var input_router := InputDeviceRouter.new()
	input_router.name = "InputDeviceRouter"
	add_child(input_router)
	Input.joy_connection_changed.connect(_on_input_device_connection_changed)
	if OS.has_feature("web"):
		await world.prewarm_web_feedback()
	_show_menu()
	initialization_ok = true
	if OS.has_feature("web"):
		var boot_json := JSON.stringify({"ready":true,"warmup":world.web_feedback_warmup_state()})
		JavaScriptBridge.eval("window.__RHYTHM_WEB_BOOT = JSON.parse(" + JSON.stringify(boot_json) + ");",true)
		_setup_web_focus_pause()
	if not save_error.is_empty():
		_show_error("存档读取失败",save_error)

func _setup_web_focus_pause() -> void:
	# Web does not deliver the native window focus notification on tab switches.
	_web_focus_callback = JavaScriptBridge.create_callback(_on_web_focus_lost)
	JavaScriptBridge.get_interface("window").__RHYTHM_WEB_FOCUS_LOST = _web_focus_callback
	JavaScriptBridge.eval("""(function () {
		if (window.__rhythmFocusListener) return;
		window.__rhythmFocusListener = function () {
			if ((document.hidden || !document.hasFocus()) && window.__RHYTHM_WEB_BOOT?.ready && window.__RHYTHM_WEB_FOCUS_LOST)
				window.__RHYTHM_WEB_FOCUS_LOST();
		};
		window.addEventListener('blur', window.__rhythmFocusListener);
		document.addEventListener('visibilitychange', window.__rhythmFocusListener);
	})()""",true)

func _on_web_focus_lost(_arguments: Array) -> void:
	if not initialization_ok or screen!="battle" or paused:
		return
	# Freeze immediately, before the next simulation frame; build UI deferred.
	paused = true
	rhythm_input_queue.clear()
	audio.set_ducked(true)
	audio.set_rhythm_paused(true)
	_show_pause.call_deferred()

func _style(bg: Color, border: Color, _radius: int = 0, width: int = 1) -> StyleBoxTexture:
	var skin := str(profile.get("skin_equipped",{}).get("board","default"))
	if screen=="battle" and skin!="default":
		bg=Color("#151e35") if skin=="board_neon" else Color("#272447")
		border=Color("#42dfed") if skin=="board_neon" else Color("#e9cb84")
	var formal := _formal_style(bg,border,width)
	if formal!=null:
		return formal
	return _pixel_style(bg,border,_radius,width)

func _pixel_style(bg: Color, border: Color, _radius: int = 0, width: int = 1) -> StyleBoxTexture:
	return WorkshopSkin.plate(bg,border,width)

func _formal_style(bg: Color, border: Color, width_value: int) -> StyleBoxTexture:
	# Shared cut-paper layers preserve rarity and interactive states.
	var cache_key := "paper:"+bg.to_html(true)+":"+border.to_html(true)+":"+str(width_value)
	if _formal_style_cache.has(cache_key):
		return _formal_style_cache[cache_key]
	var style := _pixel_style(bg,border,0,width_value)
	_formal_style_cache[cache_key] = style
	return style

func _prewarm_battle_ui() -> void:
	# Shape the real dynamic battle strings on this UI font before combat, not on
	# the first appearance of a new premium card name during a burst.
	var sample := "-+0123456789× ·剩余时间本局金币收获张大丰收连破包合计获得普通稀有史诗传说远古卡高阶连获另有种段实际展示不额外增加奖励"
	for family in FAMILY_NAMES:
		sample += str(family)
	for variant in CardCatalog.card_ids():
		sample += _card_name(variant)
	for font_size in [26,28,30,32,33,36]:
		var label := Label.new()
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",font_size)
		label.text = sample
		label.get_minimum_size()
		label.free()
	# Shaping alone does not rasterize MSDF glyphs. Force the exact shared atlas
	# bitmaps now, so a first-seen premium card name cannot stall a combat frame.
	var warmed: Dictionary = {}
	for index in range(sample.length()):
		var code := sample.unicode_at(index)
		if not warmed.has(code):
			font.render_range(0,Vector2i(font.msdf_size,0),code,code)
			warmed[code] = true
	# Pixel display roles use their native 12px multiples; keep their actual
	# glyph atlases warm without changing the Noto measurement/feedback font.
	for display_size in [24,36,48]:
		for code: int in warmed:
			pixel_font.render_range(0,Vector2i(display_size,0),code,code)
	for variant in CardCatalog.card_ids():
		_texture(_card_art_path(variant))

func _clear_ui() -> void:
	collection_grade_hud = null
	battle_skin_layer = null
	settlement_view = null
	rhythm_hud = null
	fever_border = null
	rhythm_overlay = null
	rhythm_input_queue.clear()
	hud_loadout_labels.clear()
	if screen_tween!=null and screen_tween.is_valid():
		screen_tween.kill()
	ui.modulate = Color.WHITE
	feedback_entries.clear()
	_publish_harvest_reservations()
	_premium_tail.clear()
	_premium_tail_seen.clear()
	_harvest_queue.clear()
	_harvest_seen.clear()
	_harvest_root_totals.clear()
	combat_feedback = null
	feedback_pulse_until = -1
	hover_tweens.clear()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hud_time = null
	hud_score = null
	hud_coins = null
	hud_loot = null
	hud_grade_counts.clear()
	hud_grade_icons.clear()

func _clear_overlay() -> void:
	if is_instance_valid(settlement_view): settlement_view.set_paused(false)
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_dialog_focus.call_deferred()

func _restore_dialog_focus() -> void:
	if overlay.get_child_count()>0: return
	if _dialog_return_focus!=null:
		_apply_deferred_control_focus(_dialog_return_focus)
		_dialog_return_focus = null
	_ensure_ui_focus()

func _queue_control_focus(target: Control) -> void:
	# The screen/dialog may be replaced before idle. Queue on Main, never on
	# the old Control, and resolve its weak reference only when applying focus.
	if is_instance_valid(target):
		_apply_deferred_control_focus.call_deferred(weakref(target))

func _apply_deferred_control_focus(reference: WeakRef) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(ui) or not is_instance_valid(overlay): return
	var target := reference.get_ref() as Control
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return
	if not target.is_visible_in_tree() or target.focus_mode!=Control.FOCUS_ALL: return
	if target is BaseButton and target.disabled: return
	var scope := _input_focus_scope()
	if not is_instance_valid(scope) or not (target==scope or scope.is_ancestor_of(target)): return
	# An explicit default remains useful for keyboard/pad, including cold
	# MenuPlay and safe CancelEnd. Active mouse input keeps its actual hit.
	if input_source=="mouse":
		_queue_mouse_focus()
		return
	target.grab_focus()

func _first_focusable(node: Node) -> Control:
	if node is Control:
		if not node.is_visible_in_tree(): return null
		if node.focus_mode==Control.FOCUS_ALL and not (node is BaseButton and node.disabled):
			return node
	for child in node.get_children():
		var candidate := _first_focusable(child)
		if candidate!=null: return candidate
	return null

func _ensure_ui_focus() -> void:
	if not is_instance_valid(ui) or not is_instance_valid(overlay): return
	if screen=="battle" and not paused: return
	if input_source=="mouse":
		_queue_mouse_focus()
		return
	var scope := _input_focus_scope()
	var current := get_viewport().gui_get_focus_owner()
	if current!=null and scope.is_ancestor_of(current) and current.is_visible_in_tree() and not (current is BaseButton and current.disabled):
		return
	if scope==ui and screen=="hub":
		var album := _collection_album()
		if album!=null:
			album.ensure_controller_focus()
			return
		var shop := _skin_shop()
		if shop!=null:
			shop.ensure_controller_focus()
			return
	var target := _first_focusable(scope)
	if target!=null: target.grab_focus()

func _input_focus_scope() -> Control:
	if overlay.get_child_count()>0: return overlay
	var album := _collection_album()
	if album!=null and album.get_inspector()!=null: return album.get_inspector()
	return ui

func _queue_mouse_focus() -> void:
	if _mouse_focus_pending: return
	_mouse_focus_pending = true
	_sync_mouse_focus.call_deferred()

func _sync_mouse_focus() -> void:
	_mouse_focus_pending = false
	if input_source!="mouse" or not initialization_ok: return
	if screen=="battle" and not paused: return
	var scope := _input_focus_scope()
	var hovered := get_viewport().gui_get_hovered_control()
	var target: Control = hovered
	while target!=null and not target is BaseButton:
		target = target.get_parent() as Control
	if target==null or not target.get_global_rect().has_point(_pointer_position):
		target = _button_at_pointer(scope,_pointer_position)
	if target is BaseButton and (target==scope or scope.is_ancestor_of(target)) and target.is_visible_in_tree() and target.focus_mode==Control.FOCUS_ALL and not target.disabled:
		target.grab_focus()
	else:
		var current := get_viewport().gui_get_focus_owner()
		# Keep native click focus on sliders and other non-button editors.
		# Moving across empty space still clears an old controller selection.
		if current!=null and not current is BaseButton and scope.is_ancestor_of(current) and current.get_global_rect().has_point(_pointer_position): return
		if current!=null: current.release_focus()

func _button_at_pointer(node: Node, point: Vector2) -> Control:
	if node is Control:
		if not node.is_visible_in_tree(): return null
		if node.clip_contents and not node.get_global_rect().has_point(point): return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		var hit := _button_at_pointer(child,point)
		if hit!=null: return hit
	if node is BaseButton and node.focus_mode==Control.FOCUS_ALL and not node.disabled and node.get_global_rect().has_point(point): return node
	return null

func _panel(parent: Control, rect: Rect2, dark: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var frame := _style(Color("#1e1833") if dark else PAPER,CYAN if dark else Color("#bda4c6"),0,2).duplicate() as StyleBoxTexture
	frame.content_margin_left = 28
	frame.content_margin_right = 28
	frame.content_margin_top = 18
	frame.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",frame)
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, gap: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box

func _hbox(parent: Node, gap: int = 16) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box

func _pixel_size(requested: int) -> int:
	return maxi(24,roundi(float(requested)/12.0)*12)

func _pixel_text_width(text_value: String, requested: int) -> float:
	return ceilf(pixel_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,_pixel_size(requested)).x)

func _label(parent: Node, text_value: String, size_value: int = 26, color: Color = INK, role: String = "auto") -> Label:
	var node := Label.new()
	var display_text := true # Interface typography is unified; card interiors receive font separately.
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if display_text else CanvasItem.TEXTURE_FILTER_LINEAR
	node.text = text_value
	node.add_theme_font_override("font",pixel_font if display_text else font)
	node.add_theme_font_size_override("font_size",_pixel_size(size_value) if display_text else maxi(26,size_value))
	node.set_meta("font_role","pixel" if display_text else "body")
	node.add_theme_color_override("font_color",color)
	if display_text and _pixel_size(size_value)>=36:
		node.add_theme_color_override("font_outline_color",color)
		node.add_theme_constant_override("outline_size",1)
	node.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	node.add_theme_constant_override("shadow_offset_x",0)
	node.add_theme_constant_override("shadow_offset_y",0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(parent: Node, text_value: String, id_value: String, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.name = id_value
	node.text = text_value
	# All interface actions share the original pixel face.
	var display_text := true
	node.add_theme_font_override("font",pixel_font if display_text else font)
	node.add_theme_font_size_override("font_size",36 if display_text else 28)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if display_text else CanvasItem.TEXTURE_FILTER_LINEAR
	if display_text:
		node.draw.connect(_sync_button_pixel_weight.bind(node))
	node.custom_minimum_size = Vector2(0,64)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Primary describes the action, not its selection state. Red is reserved
	# for the actual GUI focus skin shared by every ordinary text button.
	node.set_meta("primary_action",primary)
	node.pressed.connect(func() -> void:
		audio.play("ui_click",.6,30)
		callback.call()
	)
	node.mouse_entered.connect(func() -> void:
		_hover_button(node,true)
	)
	node.mouse_exited.connect(func() -> void: _hover_button(node,false))
	parent.add_child(node)
	ControllerUI.decorate(node,"B" if id_value in ["MetaBackMenu","CloseSettings","CancelEnd","CancelError"] else "A")
	ControllerUI.set_device(node,drum_input_device)
	_ensure_ui_focus.call_deferred()
	return node

func _compact_meta_button(button: Button) -> Button:
	# The inherited button skin has 12px content margins. Compact navigation
	# keeps the same lettering while fitting a true 64px slot with outer padding.
	for state in ["normal","hover","pressed","disabled","focus"]:
		var source := button.get_theme_stylebox(state)
		if source is StyleBoxTexture:
			var compact := source.duplicate() as StyleBoxTexture
			compact.content_margin_top=4
			compact.content_margin_bottom=4
			button.add_theme_stylebox_override(state,compact)
	button.custom_minimum_size.y=64
	return button

func _sync_button_pixel_weight(node: Button) -> void:
	# Read the final role/size: Tree's compact buttons override to 24px after
	# factory creation. Match the actual ink in every visual button state.
	var stroke := 1 if node.get_theme_font("font")==pixel_font and node.get_theme_font_size("font_size")>=36 else 0
	var color_key := "font_color"
	match node.get_draw_mode():
		BaseButton.DRAW_DISABLED: color_key="font_disabled_color"
		BaseButton.DRAW_PRESSED: color_key="font_pressed_color"
		BaseButton.DRAW_HOVER: color_key="font_hover_color"
		BaseButton.DRAW_HOVER_PRESSED: color_key="font_hover_pressed_color"
		_:
			if node.has_focus(): color_key="font_focus_color"
	var ink := node.get_theme_color(color_key)
	if node.get_theme_constant("outline_size")!=stroke:
		node.add_theme_constant_override("outline_size",stroke)
	if node.get_theme_color("font_outline_color")!=ink:
		node.add_theme_color_override("font_outline_color",ink)

func _hover_button(node: Control, entered: bool) -> void:
	# Immediate colour steps feel like an arcade selection, without shrinking hitboxes.
	node.set_meta("pointer_hover_modulate",true)
	node.modulate = Color(1.05,1.05,1.05) if entered and input_source=="mouse" else Color.WHITE
	if entered and input_source=="mouse": _queue_mouse_focus()

func _animate_screen() -> void:
	if DisplayServer.get_name()=="headless" or bool(profile.get("settings",{}).get("reduce_effects",false)):
		return
	ui.modulate.a = .25
	screen_tween = create_tween()
	for opacity in [.5,.75,1.0]:
		screen_tween.tween_interval(.045)
		screen_tween.tween_property(ui,"modulate:a",opacity,.001)

func _texture(path: String) -> Texture2D:
	if card_textures.has(path):
		return card_textures[path]
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture!=null:
		card_textures[path] = texture
	return texture

func _presentation_asset(relative_path: String) -> String:
	# Per-file fallback preserves the catalogue's exact art_variant mapping.
	var workshop_path := "res://assets/art/workshop/"+relative_path
	if ResourceLoader.exists(workshop_path): return workshop_path
	var crt_path := "res://assets/art/crt/"+relative_path
	return crt_path if ResourceLoader.exists(crt_path) else "res://assets/art/a2/"+relative_path

func _art(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = _texture(path)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _apply_card_foil(image: TextureRect, family: int, grade: int) -> void:
	var variant := "C%02d-%d" % [family+1,grade]
	# New fronts already contain their actual rarity's authored metal frame.
	# The reused A2 filename suffix is not a rarity instruction for these images.
	var art_path := _card_art_path(variant)
	var native_frame := art_path.begins_with("res://assets/art/workshop/cards/") or art_path.begins_with("res://assets/art/crt/cards/")
	var ring = image.get_node_or_null("CardRarityRing")
	if native_frame and ring!=null:
		image.remove_child(ring)
		ring.queue_free()
		ring = null
	if not native_frame and ring==null:
		ring = EmitterEmblem.RarityRing.new()
		ring.name = "CardRarityRing"
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.add_child(ring)
	if ring!=null:
		ring.accent = GRADE_COLORS[grade]
		ring.queue_redraw()
	if grade<3 or grade>4:
		return
	var material := ShaderMaterial.new()
	material.shader = CardFoilShader
	material.set_shader_parameter("foil_grade",grade)
	var definition := CardCatalog.card_definition(variant)
	var art_variant := str(definition.get("art_variant",variant))
	material.set_shader_parameter("rarity_reframe",not native_frame and int(art_variant.get_slice("-",1))!=grade)
	material.set_shader_parameter("phase_offset",float(family)*.173)
	material.set_shader_parameter("reduced",bool(profile.get("settings",{}).get("reduce_effects",false)))
	image.material = material

func _refresh_foil_settings(parent: Node) -> void:
	if parent is ArcadeBackdrop:
		parent.set_reduced(bool(profile.get("settings",{}).get("reduce_effects",false)))
	if parent is TextureRect and parent.material is ShaderMaterial:
		var material: ShaderMaterial = parent.material
		if material.shader==CardFoilShader:
			material.set_shader_parameter("reduced",bool(profile.get("settings",{}).get("reduce_effects",false)))
	for child in parent.get_children():
		_refresh_foil_settings(child)

func _gear_icon() -> Texture2D:
	var pixels := ["00111100","01100110","11011011","10100101","10100101","11011011","01100110","00111100"]
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(8):
		for x in range(8):
			if pixels[y][x]=="1":
				image.set_pixel(x,y,INK)
	return ImageTexture.create_from_image(image)

func _toggle_icon(checked_value: bool, disabled_value: bool) -> Texture2D:
	var image := Image.create(48,24,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var edge := Color("#8c7799") if disabled_value else CYAN
	image.fill_rect(Rect2i(0,4,48,16),edge)
	image.fill_rect(Rect2i(4,0,40,24),edge)
	image.fill_rect(Rect2i(4,4,40,16),Color("#251b35"))
	var position_x := 28 if checked_value else 4
	var color := Color("#a58ead") if disabled_value else (GOLD if checked_value else INK)
	image.fill_rect(Rect2i(position_x,4,16,16),color)
	image.fill_rect(Rect2i(position_x+4,8,8,4),color.lightened(.25))
	return ImageTexture.create_from_image(image)

func _slider_icon(highlighted: bool, disabled_value: bool) -> Texture2D:
	var image := Image.create(20,28,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var edge := Color("#8c7799") if disabled_value else CYAN
	image.fill_rect(Rect2i(4,0,12,28),edge)
	image.fill_rect(Rect2i(0,4,20,20),edge)
	image.fill_rect(Rect2i(4,4,12,20),INK if highlighted else GOLD)
	image.fill_rect(Rect2i(8,8,4,12),Color("#7d5f8c"))
	return ImageTexture.create_from_image(image)

func _card(parent: Node, family: int, grade: int, amount: int, collected: bool = false, fresh: bool = false, width_value: float = 198, height_value: float = 238) -> Button:
	var variant := "C%02d-%d" % [family+1,grade]
	var button := _button(parent,"","Card_"+variant,func() -> void: _show_card_detail(family,grade))
	button.custom_minimum_size = Vector2(width_value,height_value)
	button.add_theme_stylebox_override("normal",_style(Color("#3b2c4c") if amount>0 else Color("#251d33"),GRADE_COLORS[grade].darkened(.42) if amount>0 else Color("#8c7799"),0,1))
	button.add_theme_stylebox_override("hover",_style(Color("#594266"),CYAN,0,2))
	var image_height := height_value-100
	var art := _art(button,_card_art_path(variant),Rect2(14,4,width_value-28,image_height))
	_apply_card_foil(art,family,grade)
	if amount<=0:
		art.modulate = Color(.75,.77,.72,.8)
	var title := _label(button,_card_name(variant),36,INK,"pixel")
	title.position = Vector2(4,image_height+2)
	title.size = Vector2(width_value-8,48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var card_level := CardGrowth.level_for_count(int(profile.get("inventory",{}).get(variant,0)))
	var status_text: String = "+%d · LV%d" % [amount,card_level] if collected else ("%s · LV%d" % [GRADE_NAMES[grade],card_level] if amount>0 else GRADE_NAMES[grade]+" · 未拥有")
	var status := _label(button,status_text,26,MUTED,"body")
	status.position = Vector2(3,image_height+50)
	status.size = Vector2(width_value-6,40)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.set_deferred("size",Vector2(width_value-6,40))
	if amount>0:
		_growth_track(button,variant,Rect2(20,height_value-7,width_value-40,4))
	if fresh:
		var badge := PanelContainer.new()
		badge.position = Vector2(10,10)
		var badge_style := _style(Color("#44314f"),GOLD,0,1).duplicate() as StyleBoxTexture
		badge_style.content_margin_left = 9
		badge_style.content_margin_right = 9
		badge_style.content_margin_top = 3
		badge_style.content_margin_bottom = 3
		badge.add_theme_stylebox_override("panel",badge_style)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
		_label(badge,"新卡",24,GOLD,"pixel")
	button.tooltip_text = "%s · %s · LV%d\n%s\n%s" % [_card_name(variant),GRADE_NAMES[grade],card_level,_growth_caption(variant),_card_description(variant)]
	return button

func _growth_track(parent: Node, variant: String, rect: Rect2) -> void:
	var growth: Dictionary = CardGrowth.state(int(profile.get("inventory",{}).get(variant,0)))
	var track := ColorRect.new()
	track.position = rect.position
	track.size = rect.size
	track.color = Color("#5f4b70")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	var ratio := 1.0 if bool(growth.full) else float(growth.progress)/float(maxi(1,int(growth.next_required)))
	fill.size = Vector2(rect.size.x*ratio,rect.size.y)
	fill.color = CYAN
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

func _spacer(parent: Node, height_value: float = 12) -> Control:
	var item := Control.new()
	item.custom_minimum_size.y = height_value
	parent.add_child(item)
	return item

func _shade(parent: Control, alpha: float) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(.015,.035,.06,alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	return shade

func _backdrop() -> void:
	var cabinet := ArcadeBackdrop.new()
	cabinet.name = "ArcadeBackdrop"
	cabinet.size = Vector2(1920,1080)
	cabinet.configure(_texture("res://assets/art/rhythm_v2/ui-background.png"),screen=="menu",bool(profile.get("settings",{}).get("reduce_effects",false)))
	ui.add_child(cabinet)
	if screen=="hub": return
	var badge := _label(ui,"节拍开卡  /  四拍发令 · 连击爆发",24,MUTED)
	badge.position = Vector2(56,1030)

func _show_menu() -> void:
	_capture_hub_navigation()
	screen = "menu"
	paused = false
	_clear_overlay()
	_clear_ui()
	world.clear_cards()
	world.set_aim(Vector2.ZERO,0,false,false)
	audio.set_rhythm_paused(false)
	audio.set_ducked(false)
	audio.music("menu")
	_backdrop()
	var box := VBoxContainer.new()
	box.position = Vector2(126,210)
	box.size = Vector2(726,640)
	box.add_theme_constant_override("separation",28)
	ui.add_child(box)
	var logo := _art(box,"res://assets/art/rhythm_v2/game-logo.png",Rect2(0,0,726,220))
	logo.name = "MenuLogo"
	logo.custom_minimum_size = Vector2(0,220)
	var play := _button(box,"开始游戏","MenuPlay",_continue_selected,true)
	play.custom_minimum_size.y=96
	play.add_theme_font_size_override("font_size",36)
	_queue_control_focus(play)
	var settings := _button(box,"设置","MenuSettings",_show_settings)
	settings.custom_minimum_size.y=86
	var menu_hints := ControllerUI.hints([{"binding":"Stick","label":"选择"},{"binding":"A","label":"确认"}],drum_input_device)
	menu_hints.name = "MenuInputHints"
	menu_hints.position = Vector2(126,928)
	menu_hints.size = Vector2(726,48)
	ui.add_child(menu_hints)
	_animate_screen()

func _play_rhythm_selected() -> void:
	_continue_selected()

func _continue_selected() -> void:
	if not save_error.is_empty():
		_show_error("无法读取默认存档",save_error)
		return
	_show_hub("collection")

func _show_hub(tab: String = "collection") -> void:
	_capture_hub_navigation()
	var from_result := screen=="result"
	if tab=="deck": tab="collection"
	screen = "hub"
	current_tab = tab
	paused = false
	_clear_overlay()
	_clear_ui()
	world.clear_cards()
	world.set_aim(Vector2.ZERO,0,false,false)
	audio.set_rhythm_paused(false)
	audio.set_ducked(false)
	audio.music("menu")
	_backdrop()
	var header := _panel(ui,Rect2(70,16,1780,96))
	header.name="MetaTopBar"
	var compact_style := header.get_theme_stylebox("panel").duplicate() as StyleBoxTexture
	compact_style.content_margin_top=16
	compact_style.content_margin_bottom=16
	header.add_theme_stylebox_override("panel",compact_style)
	var row := _hbox(header,24)
	_label(row,"节拍开卡",40)
	var gap := Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var coin := _art(row,"res://assets/fx/combat06/coin-icon.png",Rect2())
	coin.custom_minimum_size=Vector2(42,42)
	var balance := _label(row,str(int(profile.get("points",0))),32,GOLD)
	balance.name="MetaCoinBalance"
	var gear := _button(row,"","MetaSettings",_show_settings)
	gear.icon=_gear_icon(); gear.expand_icon=true
	gear.add_theme_constant_override("icon_max_width",36)
	gear.custom_minimum_size.x=82
	gear.tooltip_text="设置 · Esc / 手柄菜单键"
	gear.size_flags_horizontal=Control.SIZE_SHRINK_END
	var tabs := HBoxContainer.new()
	tabs.name="MetaNavigation"
	tabs.position=Vector2(340,32); tabs.size=Vector2(840,64)
	tabs.add_theme_constant_override("separation",16)
	ui.add_child(tabs)
	_compact_meta_button(_button(tabs,"收藏卡册","MetaCollectionTab",func() -> void: _show_hub("collection"),tab=="collection"))
	_compact_meta_button(_button(tabs,"天赋","MetaTalentTab",func() -> void: _show_hub("talents"),tab=="talents"))
	_compact_meta_button(_button(tabs,"皮肤","MetaSkinsTab",func() -> void: _show_hub("skins"),tab=="skins"))
	var selected_tab_name: String = {"collection":"MetaCollectionTab","talents":"MetaTalentTab","skins":"MetaSkinsTab"}.get(tab,"MetaCollectionTab")
	for tab_button: Button in tabs.get_children():
		tab_button.set_meta("controller_page_selected",str(tab_button.name)==selected_tab_name)
		ControllerUI.set_tab_selected(tab_button,str(tab_button.name)==selected_tab_name)
	if tab=="talents":
		_build_talent_panel()
	elif tab=="skins":
		var shop := SkinShop.new()
		shop.position=Vector2(70,124); shop.size=Vector2(1780,808)
		ui.add_child(shop)
		shop.configure(profile,pixel_font,_buy_skin,_equip_skin)
		shop.set_input_device(drum_input_device)
		if not _hub_skin_navigation.is_empty(): shop.restore_navigation_state(_hub_skin_navigation)
	else:
		var album := CollectionAlbum.new()
		album.position=Vector2(70,124); album.size=Vector2(1780,808)
		ui.add_child(album)
		album.configure(profile,pixel_font,font)
		album.set_input_device(drum_input_device)
		album.set_reduced(bool(profile.settings.get("reduce_effects",false)))
		if not _hub_album_navigation.is_empty():
			album.restore_navigation_state(_hub_album_navigation)
		elif from_result and not profile.get("last_result",{}).get("new_ids",[]).is_empty():
			var recent_id: String=str(profile.last_result.new_ids[0])
			var recent: Dictionary=CollectionCatalog.card_definition(recent_id)
			album.select_theme(str(recent.theme))
			var theme_ids: Array[String]=[]
			for id: String in CollectionCatalog.card_ids():
				if CollectionCatalog.card_definition(id).theme==recent.theme: theme_ids.append(id)
			album.set_page(theme_ids.find(recent_id)/CollectionAlbum.PAGE_SIZE)
			album.highlight_card(recent_id)
	var footer := HBoxContainer.new()
	footer.position=Vector2(70,1000); footer.size=Vector2(1780,64)
	footer.add_theme_constant_override("separation",24)
	ui.add_child(footer)
	var back := _compact_meta_button(_button(footer,"返回主菜单","MetaBackMenu",_show_menu))
	ControllerUI.decorate(back,"B")
	back.set_meta("controller_keyboard_binding","Backspace")
	ControllerUI.button_prompt(back,"B",drum_input_device)
	var begin := _button(footer,"开始开卡  ·  %s" % GameConfig.duration_caption(),"BeginBattle",_start_run,true)
	_compact_meta_button(begin)
	begin.custom_minimum_size.x=680
	ControllerUI.decorate(begin,"Y")
	ControllerUI.button_prompt(begin,"Y",drum_input_device)
	_add_hub_hints()
	ControllerUI.set_device(ui,drum_input_device)
	_restore_hub_navigation.call_deferred()
	_animate_screen()

func _collection_album() -> Control:
	for child in ui.get_children():
		if child.has_method("get_page_state") and child.has_method("get_inspector"): return child
	return null

func _skin_shop() -> Control:
	for child in ui.get_children():
		if child.has_method("get_shop_state"): return child
	return null

func _talent_tree() -> Control:
	return ui.find_child("TalentTree",true,false) as Control

func _restore_controller_content_focus() -> void:
	var tree := _talent_tree()
	if tree!=null:
		tree.ensure_controller_focus()
		return
	var shop := _skin_shop()
	if shop!=null:
		shop.ensure_controller_focus()
		return
	var album := _collection_album()
	if album!=null: album.ensure_controller_focus()

func _add_hub_hints() -> void:
	var items: Array = [{"binding":"LB/RB","label":"页签"}]
	if current_tab in ["collection","skins"]:
		items.append({"binding":"LT/RT","label":"主题" if current_tab=="collection" else "类别"})
		items.append({"binding":"Left/Right","label":"翻页" if current_tab=="collection" else "切换皮肤"})
	items.append({"binding":"Stick","label":"选卡" if current_tab=="collection" else "选择"})
	items.append({"binding":"A","label":"确认"})
	items.append({"binding":"Start","label":"设置"})
	var hints := ControllerUI.hints(items,drum_input_device)
	hints.name = "HubInputHints"
	hints.position = Vector2(70,944)
	hints.size = Vector2(1780,44)
	ui.add_child(hints)

func _capture_hub_navigation() -> void:
	if screen!="hub" or not is_instance_valid(ui): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and ui.is_ancestor_of(focused):
		_hub_focus_names[current_tab] = str(focused.name)
	var album := _collection_album()
	if album!=null: _hub_album_navigation = album.get_navigation_state()
	var shop := _skin_shop()
	if shop!=null: _hub_skin_navigation = shop.get_navigation_state()

func _restore_hub_navigation() -> void:
	if screen!="hub" or overlay.get_child_count()>0: return
	if input_source=="mouse":
		_queue_mouse_focus()
		return
	if input_source=="joypad" and current_tab=="talents":
		_restore_controller_content_focus()
		return
	var saved := str(_hub_focus_names.get(current_tab,""))
	var target := ui.find_child(saved,true,false) as Control if not saved.is_empty() else null
	if target!=null and target.is_visible_in_tree() and not (target is BaseButton and target.disabled):
		target.grab_focus()
	else:
		var album := _collection_album()
		if album!=null: album.ensure_controller_focus()
		else:
			var shop := _skin_shop()
			if shop!=null: shop.ensure_controller_focus()
			else:
				var tab_button := ui.find_child("MetaTalentTab",true,false) as Control
				if tab_button!=null: tab_button.grab_focus()

func _cycle_hub_tab(direction: int) -> void:
	var tabs := ["collection","talents","skins"]
	_show_hub(tabs[posmod(tabs.find(current_tab)+direction,tabs.size())])

func _buy_skin(id: String) -> void:
	var changed: Dictionary=progression.buy_skin(profile,id)
	if not changed.ok:
		_show_error("皮肤未解锁",str(changed.error),func() -> void: _show_hub("skins"))
		return
	profile=changed.profile
	audio.play("upgrade",.6,0)
	_refresh_skin_shop()

func _equip_skin(id: String, category: String="") -> void:
	var changed: Dictionary=progression.equip_skin(profile,id,category)
	if not changed.ok: return
	profile=changed.profile
	audio.play("ui_click",.5,0)
	_refresh_skin_shop()

func _refresh_skin_shop() -> void:
	var balance := ui.find_child("MetaCoinBalance",true,false) as Label
	if balance!=null: balance.text=str(int(profile.get("points",0)))
	for child in ui.get_children():
		if child.has_method("get_shop_state"):
			child.configure(profile,pixel_font,_buy_skin,_equip_skin)
			return
	_show_hub("skins")

func _build_talent_panel() -> void:
	var panel := _panel(ui,Rect2(70,124,1780,808))
	panel.name = "TalentPanel"
	var tree_view := TalentTreeView.new()
	tree_view.name = "TalentTree"
	tree_view.set_display_font(pixel_font)
	panel.add_child(tree_view)
	tree_view.node_selected.connect(func(node_id: String) -> void: talent_selected_id=node_id)
	tree_view.purchase_requested.connect(_buy_talent)
	tree_view.view_state_changed.connect(func(state: Dictionary) -> void: talent_view_state=state.duplicate())
	tree_view.configure(Rules.talent_definitions(),progression.talent_states(profile),int(profile.get("points",0)),
		talent_selected_id,Callable(self,"_button"),Callable(self,"_style"),talent_view_state)

func _buy_talent(node_id: String, expected_level: int) -> void:
	var purchased: Dictionary = progression.buy_talent(slot,profile,node_id,expected_level)
	if not bool(purchased.get("ok",false)):
		var purchase_error := str(purchased.get("error","无法购买"))
		if purchase_error in ["prerequisite","insufficient_coins"]:
			var tree := ui.find_child("TalentTree",true,false)
			if tree!=null and tree.has_method("show_purchase_feedback"):
				tree.show_purchase_feedback(purchase_error)
			return
		if purchase_error=="maxed": return
		_show_error("天赋购买失败",str(purchased.get("error","无法购买")),func() -> void:
			_clear_overlay()
			_show_hub("talents")
		)
		return
	profile = purchased.profile
	audio.play("upgrade",.8,0)
	has_profile = true
	save_error = ""
	_show_hub("talents")

func _run_options() -> Dictionary:
	return Rules.build_run_options(profile.get("talents",{}),profile.get("selected_loadout",{}),CardGrowth.level_map(profile.get("inventory",{})),profile.get("album",{}))

func _card_name(variant: String) -> String:
	return str(CardCatalog.card_definition(variant).get("name",variant))

func _card_art_path(variant: String) -> String:
	var art_variant := str(CardCatalog.card_definition(variant).get("art_variant",variant))
	return _presentation_asset("cards/%s.png" % art_variant)

func _growth_caption(variant: String) -> String:
	var state: Dictionary = CardGrowth.state(int(profile.get("inventory",{}).get(variant,0)))
	if int(state.level)==0:
		return "首次获得解锁LV1 · 重复卡在结算时自动升级"
	if bool(state.full):
		return "LV30 已满级 · 后续重复卡结算时自动换金币"
	return "LV%d → LV%d  ·  %d / %d 张" % [int(state.level),int(state.level)+1,int(state.progress),int(state.next_required)]

func _card_description(variant: String) -> String:
	var level := maxi(1,CardGrowth.level_for_count(int(profile.get("inventory",{}).get(variant,0))))
	return str(CardCatalog.card_description(variant,level)).replace("全根","单次攻击").replace("每根","每次攻击").replace("同根","同次攻击").replace("下个不同根","下一次攻击").replace("原生模板","原始攻击").replace("整套模板","整套攻击").replace("攻击几何","攻击范围").replace("几何外目标","范围外目标").replace("终端波不再派生","后续波不再触发其他效果")

func _launcher_name(launcher_id: String) -> String:
	return "节拍开卡"

func _build_deck_panel() -> void:
	var panel := _panel(ui,Rect2(70,282,1780,618))
	panel.name = "CollectionPanel"
	var content := _vbox(panel,24)
	_label(content,"节拍开卡 · 成长工坊",40,GOLD,"pixel")
	var options := Rules.build_run_options(profile.get("talents",{}))
	_label(content,"四拍扩圈、聚拢与圈内开卡；连续%d Combo使Fever就绪。" % int(options.get("rhythm_fever_threshold",Rules.FEVER_BASE_THRESHOLD)),30,INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(content,"拆包赚取金币，购买天赋，逐步提升整理和开包效率。",27,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spacer(content,16)
	_label(content,"十条正确指令充满能量；Fever就绪且满能时打出爆发，消耗能量全屏开包。",27,INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(content,"圈内击破金币 ×1.2；卡包合成保留已有损伤。",28,GOLD,"pixel")
	_button(content,"前往天赋","CollectionGoTalents",func() -> void: _show_hub("talents"),true)

func _loadout_preview(options: Dictionary) -> String:
	var radius := CardCatalog.primary_radius(options.attack_spec)
	return "核心半径 %d\n自由起手，连续四拍\n系统复述同句并出招" % int(radius)

func _synergy_text(slots: Array) -> String:
	var equipped := 0
	for variant in slots:
		if variant!=null:
			equipped += 1
	return "已装 %d/4 · 节拍构筑试制版" % equipped

func _show_loadout_slot(index: int) -> void:
	var variant = profile.selected_loadout.slots[index]
	var box := _dialog("卡槽 %d" % (index+1),560)
	if variant==null:
		_label(box,"从收藏中选择已拥有的卡片装备。",26,MUTED)
	else:
		_label(box,_card_description(str(variant)),26,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var revision := int(profile.revision)
		_button(box,"卸下卡片","UnequipSlot%d" % index,func() -> void:
			_apply_growth(progression.unequip_card(slot,profile,index,revision))
		,true)
	_button(box,"返回","CloseSlot",_clear_overlay)

func _show_launchers() -> void:
	var box := _dialog("节拍开卡 · 四拍指令",460)
	_label(box,"120 BPM · 自由起手，连续四拍后系统复述",26,MUTED)
	_button(box,"返回","CloseLaunchers",_clear_overlay)

func _apply_growth(result: Dictionary) -> bool:
	if not bool(result.get("ok",false)):
		_show_error("操作未完成",_growth_error(str(result.get("error","unknown"))))
		return false
	profile = result.profile
	has_profile = true
	save_error = ""
	if bool(result.get("changed",false)):
		audio.play("upgrade",.65,0)
	_show_hub("deck")
	return true

func _growth_error(reason: String) -> String:
	return {"active_run":"请先完成当前对局。","not_owned":"尚未拥有这张卡。","slots_full":"四个卡槽已满，请选择替换位置。","revision_conflict":"存档已更新，请重试。","launcher_locked":"该节拍器尚未解锁。","invalid_card_slot":"请选择有效的卡槽。","inventory_regression":"卡片成长不能被扣减，请重新读取存档。","frozen_inventory_mismatch":"当前对局的卡片成长已锁定，请先完成本局。"}.get(reason,"操作失败（%s），当前进度未改变。" % reason)

func _show_card_detail_by_id(variant: String) -> void:
	_show_card_detail(int(variant.get_slice("-",0).substr(1))-1,int(variant.get_slice("-",1)))

func _show_card_detail(family: int, grade: int = 0) -> void:
	var variant := "C%02d-%d" % [family+1,grade]
	if CardCatalog.card_definition(variant).is_empty():
		return
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade(overlay,.74)
	var panel := _panel(overlay,Rect2(196,104,1528,872))
	var content := Control.new()
	panel.add_child(content)
	var amount := int(profile.get("inventory",{}).get(variant,0))
	var art_panel := _panel(content,Rect2(10,12,600,670),true)
	var image_holder := Control.new()
	art_panel.add_child(image_holder)
	var detail_art := _art(image_holder,_card_art_path(variant),Rect2(0,0,556,600))
	detail_art.name = "CardDetailArt"
	_apply_card_foil(detail_art,family,grade)
	var title := _label(content,_card_name(variant),46)
	title.position = Vector2(654,30)
	var definition := CardCatalog.card_definition(variant)
	var rarity := _label(content,"%s · %s" % [GRADE_NAMES[grade],str(definition.get("role",""))],30,GRADE_COLORS[grade])
	rarity.position = Vector2(654,106)
	var amount_label := _label(content,_growth_caption(variant),29,MUTED)
	amount_label.name = "CardLevelProgress"
	amount_label.position = Vector2(654,168)
	var description := _label(content,_card_description(variant),27,MUTED)
	description.name = "CardEffectDescription"
	description.position = Vector2(654,230)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size = Vector2(790,205)
	description.set_deferred("size",Vector2(790,205))
	description.add_theme_constant_override("line_spacing",6)
	var growth: Dictionary = CardGrowth.state(amount)
	var progress_bar := ProgressBar.new()
	progress_bar.name = "CardUpgradeProgress"
	progress_bar.position = Vector2(654,468)
	progress_bar.size = Vector2(770,26)
	progress_bar.show_percentage = false
	progress_bar.max_value = maxi(1,int(growth.next_required))
	progress_bar.value = progress_bar.max_value if bool(growth.full) else int(growth.progress)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#5f4b70")
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	progress_bar.add_theme_stylebox_override("background",track)
	progress_bar.add_theme_stylebox_override("fill",fill)
	content.add_child(progress_bar)
	var growth_hint := _label(content,"等级效果 +%d%% · 各张卡独立成长" % maxi(0,int(growth.level)-1),27,CYAN)
	growth_hint.position = Vector2(654,510)
	var target_card := str(definition.get("upgrade_target",""))
	var note_text := "终局可替换为：%s · 获得后手动调整构筑" % _card_name(target_card) if not target_card.is_empty() else "每张卡独立成长 · 相同卡最多一张 · 结算自动升级"
	var note := _label(content,note_text,24,MUTED)
	note.position = Vector2(654,558)
	var actions := HBoxContainer.new()
	actions.position = Vector2(654,622)
	actions.size = Vector2(790,70)
	actions.add_theme_constant_override("separation",14)
	content.add_child(actions)
	var equipped: bool = profile.selected_loadout.slots.has(variant)
	var equip := _button(actions,"已装备" if equipped else "装备卡片","EquipCard",func() -> void: _equip_from_detail(variant),true)
	equip.disabled = amount<=0 or equipped or not profile.active_run.is_empty()
	var level_note := _label(actions,"最高LV30 · 升级不花金币",25,MUTED)
	level_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := _button(content,"返回收藏","CloseCardDetail",_clear_overlay,true)
	close.position = Vector2(930,730)
	close.size = Vector2(500,70)

func _equip_from_detail(variant: String) -> void:
	var slots: Array = profile.selected_loadout.slots
	for index in range(4):
		if slots[index]==null or slots[index]==variant:
			_apply_growth(progression.equip_card(slot,profile,variant,-1,int(profile.revision)))
			return
	var box := _dialog("选择要替换的卡槽",650)
	_label(box,"只替换装备，不消耗任何卡片。",26,MUTED)
	var revision := int(profile.revision)
	for index in range(4):
		var old := str(slots[index])
		_button(box,"卡槽 %d · %s · %s" % [index+1,_card_name(old),GRADE_NAMES[int(old.get_slice("-",1))]],"ReplaceSlot%d" % index,func() -> void:
			_apply_growth(progression.equip_card(slot,profile,variant,index,revision))
		)
	_button(box,"取消","CancelEquip",func() -> void: _show_card_detail(int(variant.substr(1,2))-1,int(variant.get_slice("-",1))))

func _start_run() -> void:
	_capture_hub_navigation()
	profile["active_run"]={}
	sim=Sim.new()
	var identifier := "%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	if not sim.start(int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system()),identifier,_run_options()):
		_show_error("无法开始本局","本局规则配置无效。")
		return
	_enter_battle()

func _resume_run() -> void:
	# This release intentionally has no battle checkpoints or resume entry.
	_start_run()

func _enter_battle() -> void:
	screen = "battle"
	paused = false
	if sim.closed:
		_bank_run("completed")
		return
	prelude_frames = 0
	prelude_total = 0
	_clear_overlay()
	_clear_ui()
	world.clear_cards()
	_rhythm_world_spec_key = ""
	world.set_run_options(sim.run_options)
	world.set_skin_set(profile.get("skin_equipped",{}))
	world.sync_targets(sim.targets,sim.tick)
	audio.stop_sfx() # Retire result/menu tails before this battle.
	audio.reset_rhythm()
	audio.set_ducked(false)
	audio.music("battle")
	audio.prime_rhythm(_rhythm_state(),int(sim.tick))
	var top := _panel(ui,Rect2(738,14,1164,114))
	top.name = "BattleTopHUD"
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := _hbox(top,20)
	var timer_plate := PanelContainer.new()
	timer_plate.name = "BattleTimePlate"
	timer_plate.custom_minimum_size.x = maxf(300.0,_pixel_text_width("剩余时间  "+GameConfig.clock_caption(),36)+36.0)
	var timer_skin := _style(Color("#f2dfbc"),Color("#ab8baf"),0,1).duplicate() as StyleBoxTexture
	timer_skin.content_margin_left = 18
	timer_skin.content_margin_right = 18
	timer_skin.content_margin_top = 4
	timer_skin.content_margin_bottom = 4
	timer_plate.add_theme_stylebox_override("panel",timer_skin)
	row.add_child(timer_plate)
	hud_time = _label(timer_plate,"剩余时间  "+GameConfig.clock_caption(),36,Color("#201c19"),"pixel")
	if str(profile.get("skin_equipped",{}).get("board","default"))!="default":
		hud_time.add_theme_color_override("font_color",Color("#fff0cd"))
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_coins = BattleCoinHUD.new()
	hud_coins.name = "BattleCoinHUD"
	hud_coins.configure(pixel_font)
	row.add_child(hud_coins)
	hud_coins.custom_minimum_size.x=190
	collection_grade_hud=CollectionGradeHUD.new()
	collection_grade_hud.configure(pixel_font)
	row.add_child(collection_grade_hud)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(top_spacer)
	var pause_button := _button(row,"Ⅱ","BattlePause",_show_pause,true)
	ControllerUI.decorate(pause_button,"Start")
	pause_button.custom_minimum_size.x = 68
	pause_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	pause_button.tooltip_text="暂停（Esc / Start）"
	pause_button.add_theme_font_size_override("font_size",24)
	var bottom := _panel(ui,Rect2(18,920,1884,144))
	bottom.name = "BattleLoadout"
	fever_border = FeverBorderFX.new()
	ui.add_child(fever_border)
	combat_feedback = Control.new()
	combat_feedback.name = "CombatFeedback"
	combat_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(combat_feedback)
	combat_feedback.set_meta("premium_info_band",_premium_hud_band_rect())
	rhythm_hud = RhythmHUD.new()
	rhythm_hud.set_fonts(pixel_font,pixel_font)
	rhythm_hud.set_theme_skin(str(profile.get("skin_equipped",{}).get("board","default")))
	rhythm_hud.reduced = bool(profile.get("settings",{}).get("reduce_effects",false))
	ui.add_child(rhythm_hud)
	rhythm_overlay = BattleRhythmOverlay.new()
	rhythm_overlay.set_fonts(pixel_font,pixel_font)
	rhythm_overlay.set_input_device(drum_input_device)
	ui.add_child(rhythm_overlay)
	battle_skin_layer=BattleSkinLayer.new()
	ui.add_child(battle_skin_layer)
	rhythm_overlay.set_skin(str(profile.get("skin_equipped",{}).get("beat","default")))
	last_combat_feedback.clear()
	_update_hud()
	_update_rhythm_presentation()
	_sync_reward_sinks.call_deferred()
	_animate_screen()
	if not rhythm_tutorial_seen:
		_show_rhythm_tutorial()

func _show_rhythm_tutorial() -> void:
	paused = true
	audio.set_rhythm_paused(true)
	_update_rhythm_presentation()
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade(overlay,.65)
	var panel := _panel(overlay,Rect2(320,75,1280,930))
	panel.name = "RhythmTutorialPanel"
	var box := _vbox(panel,14)
	_label(box,"四拍，开卡！",44,INK)
	_label(box,"自由起手，每0.5秒一拍；整句对准获Perfect，再听复述执行。",24,MUTED)
	var threshold := int(sim.run_options.get("rhythm_fever_threshold",Rules.FEVER_BASE_THRESHOLD))
	var lesson := RhythmTutorialView.new()
	box.add_child(lesson)
	lesson.configure(pixel_font,font,drum_input_device,threshold,int(sim.run_options.get("merge_ratio",5)),int(sim.run_options.get("rhythm_fever_energy_max",10)),int(sim.run_options.get("echo_retention_stacks",0)))
	_label(box,"复述后%d秒内敲下一句；未满能爆发攻圈内，满能攻全场。" % Rules.RhythmConductor.COMBO_HANDOFF_SECONDS,24,MUTED)
	_button(box,"开始开卡！","RhythmTutorialStart",func() -> void:
		rhythm_tutorial_seen = true
		_resume_rhythm()
	,true)

func _add_rhythm_command_table(parent: Node) -> void:
	var table := _label(parent,"PATA PATA PATA PON  ·  聚拢圈外卡包\nPON PON PATA PON  ·  四拍扩圈\nCHAKA CHAKA PATA PON  ·  圈内开卡\nDON DON PATA PON  ·  Fever时可用，满能全屏\n圈内同品质卡包自动连锁合成",26,INK,"body")
	table.name = "RhythmCommandTable"
	table.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_rhythm_input_hint(parent: Node, size_value: int = 26) -> Label:
	var hint := _label(parent,str(DRUM_DEVICE_HINTS[drum_input_device]),size_value,MUTED,"body")
	hint.name = "RhythmInputHint"
	hint.set_meta("rhythm_input_hint",true)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return hint

func _refresh_rhythm_input_hints(node: Node) -> void:
	if bool(node.get_meta("rhythm_tutorial_graphics",false)) and node.has_method("set_input_device"):
		node.set_input_device(drum_input_device)
	if node.has_method("get_inspector") and node.has_method("set_input_device"):
		node.set_input_device(drum_input_device)
	if node is Label and bool(node.get_meta("rhythm_input_hint",false)):
		node.text = str(DRUM_DEVICE_HINTS[drum_input_device])
	for child in node.get_children():
		_refresh_rhythm_input_hints(child)

func _set_drum_input_device(value: String) -> void:
	if not DRUM_DEVICE_HINTS.has(value) or drum_input_device==value:
		return
	drum_input_device = value
	ControllerUI.set_device(ui,value)
	ControllerUI.set_device(overlay,value)
	if is_instance_valid(settlement_view): settlement_view.set_input_device(value)
	_refresh_rhythm_input_hints(ui)
	_refresh_rhythm_input_hints(overlay)
	if is_instance_valid(rhythm_hud):
		rhythm_hud.set_input_device(value)
	if is_instance_valid(rhythm_overlay):
		rhythm_overlay.set_input_device(value)
	var shop := _skin_shop()
	if shop!=null: shop.set_input_device(value)

func _observe_input_device(event: InputEvent) -> void:
	if not initialization_ok: return
	var album := _collection_album()
	var inspector: Control = album.get_inspector() if album!=null else null
	if inspector!=null: inspector.set_input_device_managed(true)
	var source := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if inspector==null or event.keycode in [KEY_ESCAPE,KEY_A,KEY_D,KEY_TAB,KEY_SPACE,KEY_F,KEY_P,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: source="keyboard"
	elif event is InputEventMouseButton and event.pressed:
		_pointer_position=event.position
		source="mouse"
	elif event is InputEventMouseMotion and event.relative.length_squared()>0.0:
		_pointer_position=event.position
		var now := Time.get_ticks_msec()
		if _mouse_switch_stamp<0 or now-_mouse_switch_stamp>250:
			_mouse_switch_distance=0.0
			_mouse_switch_stamp=now
		_mouse_switch_distance+=event.relative.length()
		if _mouse_switch_distance>=16.0: source="mouse"
		if input_source=="mouse": _queue_mouse_focus()
	elif event is InputEventJoypadButton and event.pressed:
		if inspector==null or event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]: source="joypad"
	elif event is InputEventJoypadMotion:
		var threshold := 0.18 if inspector!=null else 0.5
		if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] and absf(event.axis_value)>threshold: source="joypad"
		elif inspector==null and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT] and event.axis_value>0.6: source="joypad"
	if not source.is_empty():
		var changed := input_source!=source
		input_source=source
		if source=="joypad": _active_joypad_device=event.device
		if source!="mouse":
			_mouse_switch_distance=0.0
			_mouse_switch_stamp=-1
		_set_drum_input_device("joypad" if source=="joypad" else "keyboard")
		if changed:
			ControllerUI.set_pointer_active(ui,source=="mouse")
			ControllerUI.set_pointer_active(overlay,source=="mouse")
		if changed and source!="mouse":
			for button in ui.find_children("*","Button",true,false)+overlay.find_children("*","Button",true,false):
				if button.has_meta("pointer_hover_modulate"): button.modulate=Color.WHITE
		if source=="mouse": _queue_mouse_focus()
		elif source=="joypad":
			var tree := _talent_tree()
			var focused := get_viewport().gui_get_focus_owner()
			if changed and screen=="hub" and overlay.get_child_count()==0 and tree!=null and (focused==null or (tree.is_ancestor_of(focused) and str(focused.name)!="TalentResetView")):
				tree.ensure_controller_focus()
			else: _ensure_ui_focus()
	if inspector!=null: inspector.set_input_device(drum_input_device)

func _on_input_device_connection_changed(device: int, connected: bool) -> void:
	if connected or device!=_active_joypad_device or input_source!="joypad": return
	_active_joypad_device=-1
	input_source="keyboard"
	_set_drum_input_device("keyboard")
	ControllerUI.set_pointer_active(ui,false)
	ControllerUI.set_pointer_active(overlay,false)

func _resume_rhythm() -> void:
	_clear_overlay()
	rhythm_input_queue.clear()
	paused = false
	prelude_frames = 0
	prelude_total = 0
	audio.set_ducked(false)
	audio.set_rhythm_paused(false)
	_update_rhythm_presentation()

func _rhythm_state() -> Dictionary:
	return sim.get_rhythm_state() if sim!=null and sim.has_method("get_rhythm_state") else {}

func _rhythm_response_progress(state: Dictionary) -> float:
	var echo: Dictionary = state.get("active_echo",{})
	if str(state.get("phase","idle"))!="respond" or not bool(echo.get("started",false)):
		return 0.0
	return clampf(float(int(state.get("tick",-1))-int(echo.get("start_tick",0))+30)/120.0,0.0,1.0)

func _update_rhythm_presentation() -> void:
	if sim==null or screen!="battle":
		return
	var state := _rhythm_state()
	if state.is_empty():
		return
	if is_instance_valid(hud_coins):
		hud_coins.set_state(int(sim.score),int(sim.tick),paused,bool(profile.get("settings",{}).get("reduce_effects",false)))
	_sync_rhythm_world_spec(state)
	var aim_values: Array = state.get("aim",[0,300])
	var aim := Vector2(float(aim_values[0]),float(aim_values[1]))
	last_mouse = world.table_to_screen(aim)
	world.set_combat_state(state)
	if is_instance_valid(collection_grade_hud):
		collection_grade_hud.set_counts(state.get("card_grade_counts",[0,0,0,0,0]),int(sim.tick),paused)
	if is_instance_valid(battle_skin_layer):
		battle_skin_layer.set_state(profile.get("skin_equipped",{}),state,paused,bool(profile.settings.get("reduce_effects",false)))
	if is_instance_valid(fever_border):
		var a: Vector2 = world.table_to_screen(Vector2(-Rules.TABLE_HALF_WIDTH,Rules.TABLE_DEPTH))
		var b: Vector2 = world.table_to_screen(Vector2(Rules.TABLE_HALF_WIDTH,0))
		var board := Rect2(a,b-a).abs()
		fever_border.set_state(state,paused,bool(profile.get("settings",{}).get("reduce_effects",false)),board)
	world.set_aim(aim,_rhythm_response_progress(state),true,true,aim)
	if is_instance_valid(rhythm_hud):
		rhythm_hud.set_input_device(drum_input_device)
		rhythm_hud.set_state(state,prelude_frames,prelude_total,paused)
	if is_instance_valid(rhythm_overlay):
		rhythm_overlay.set_input_device(drum_input_device)
		rhythm_overlay.set_circle_screen_anchor(last_mouse)
		rhythm_overlay.set_state(state,paused,bool(profile.get("settings",{}).get("reduce_effects",false)))

func _sync_rhythm_world_spec(state: Dictionary) -> void:
	if not sim.has_method("get_command_spec"):
		return
	# The public World API runs only when this sentence's actual geometry changes.
	var key := "%s:%.4f" % [str(state.get("preset_id","")),float(state.get("command_radius",50.0))]
	if key==_rhythm_world_spec_key:
		return
	var command_options: Dictionary = sim.run_options.duplicate(true)
	command_options["attack_spec"] = sim.get_command_spec()
	world.set_run_options(command_options)
	_rhythm_world_spec_key = key

func _sync_reward_sinks() -> void:
	if screen!="battle" or hud_grade_icons.is_empty():
		return
	var sinks: Array[Vector2] = []
	for icon in hud_grade_icons:
		if not is_instance_valid(icon):
			return
		sinks.append(icon.get_global_rect().get_center())
	while sinks.size()<5:
		sinks.append(sinks[0])
	world.set_reward_sinks(sinks)


func _physics_process(_delta: float) -> void:
	var poll_trace := Time.get_ticks_usec() if performance_trace_enabled else 0
	var poll_ok := _poll_battle_save()
	if performance_trace_enabled:
		_trace_stage("save_poll",poll_trace)
	if not poll_ok:
		return
	if not initialization_ok or screen!="battle" or paused or sim==null:
		return
	if sim.closed:
		_bank_run("completed")
		return
	var state := _rhythm_state()
	var aim_values: Array = state.get("aim",[0,300])
	var valid := true
	var aim := Vector2(float(aim_values[0]),float(aim_values[1]))
	var pending_inputs: Array[Dictionary] = rhythm_input_queue.duplicate(true)
	rhythm_input_queue.clear()
	var trace_stamp := Time.get_ticks_usec() if performance_trace_enabled else 0
	var next_tick: int = sim.tick+1
	trace_stamp = _trace_stage("input_persistence",trace_stamp)
	for rhythm_input: Dictionary in pending_inputs:
		var judgement: Dictionary = sim.submit_rhythm_key(str(rhythm_input.key))
		if bool(judgement.get("accepted",false)):
			audio.rhythm_input(str(rhythm_input.key),judgement)
			if is_instance_valid(rhythm_hud):
				rhythm_hud.pulse_word(str(rhythm_input.key),false,next_tick)
	var events: Array = sim.step(aim,valid)
	audio.sync_rhythm(_rhythm_state(),int(sim.tick))
	audio.play_redesign_events(events,int(sim.tick))
	audio.play_judgement_events(events,int(sim.tick))
	trace_stamp = _trace_stage("simulation",trace_stamp)
	if not str(sim.fault).is_empty():
		paused = true
		audio.set_rhythm_paused(true)
		audio.set_ducked(true)
		save_error = str(sim.fault)
		_show_error("战斗已暂停","攻击规则发生异常，当前存档未被覆盖。重试将重新开始新一局，本局未结算收获不会保留。",_resume_run)
		return
	var did_shoot := false
	var hit_count := 0
	var summary := _empty_combat_summary(sim.shots)
	var root_rewards := _collect_root_rewards(events,sim.shots)
	var grouped_roots := _grouped_reward_roots(root_rewards)
	for root_id in grouped_roots:
		root_rewards[root_id]["reward_grouped"] = true
	var visual_hits: Dictionary = {}
	for event in events:
		if str(event.get("type",""))=="hit":
			var hit_key := "%d:%s" % [int(event.target.id),str(event.get("damage_style","direct"))]
			if not visual_hits.has(hit_key):
				visual_hits[hit_key] = {"damage":0,"target":event.target,"shown":false,"style":str(event.get("damage_style","direct")),"source_event":event}
			visual_hits[hit_key].damage += int(event.get("damage",0))
			visual_hits[hit_key].target = event.target
	world._begin_feedback_batch()
	for event in events:
		if is_instance_valid(rhythm_overlay): rhythm_overlay.present_event(event)
		match str(event.get("type","")):
			"rhythm_response":
				world.present_prepare_event(event)
				if is_instance_valid(rhythm_hud):
					rhythm_hud.pulse_response(event)
			"rhythm_judgement":
				world.present_prepare_event(event)
				if is_instance_valid(rhythm_hud):
					rhythm_hud.pulse_judgement(event)
			"rhythm_command":
				if is_instance_valid(rhythm_hud):
					rhythm_hud.pulse_command(event)
			"fever_enter", "preparation_reset":
				world.present_prepare_event(event)
			"shot":
				did_shoot = true
			"skill_event":
				world.present_skill_event(event,true)
			"bd_trigger":
				world.present_bd_trigger(event)
			"hit":
				var hit_key := "%d:%s" % [int(event.target.id),str(event.get("damage_style","direct"))]
				if not bool(visual_hits[hit_key].shown):
					world.hit(visual_hits[hit_key].target,int(visual_hits[hit_key].damage),str(visual_hits[hit_key].style),visual_hits[hit_key].source_event)
					visual_hits[hit_key].shown = true
				hit_count += 1
				summary.hits += 1
				summary.damage += int(event.get("damage",0))
			"claim":
				var reward: Dictionary = event.get("reward",{})
				var source_root := int(event.get("root_id",sim.shots))
				world.claim(event["target"],reward,not grouped_roots.has(source_root),event)
				_add_reward_summary(summary,event)
	world._end_feedback_batch()
	for root_id in root_rewards:
		var root_summary: Dictionary = root_rewards[root_id]
		if int(root_summary.get("circle_coins",0))>0:
			world.present_circle_bonus(int(root_summary.circle_coins),int(root_summary.circle_destroyed),int(root_id))
	trace_stamp = _trace_stage("event_presentation",trace_stamp)
	var reward_audio_stamp := trace_stamp
	if hit_count>0:
		last_combat_feedback = summary.duplicate(true)
		var feedback_stamp := _trace_stage("audio_submission",reward_audio_stamp)
		for source_root in root_rewards:
			_show_combat_feedback(root_rewards[source_root])
		_trace_stage("local_feedback_and_banner",feedback_stamp)
	trace_stamp = _trace_stage("reward_hud_audio",trace_stamp)
	world.sync_targets(sim.targets,sim.tick)
	trace_stamp = _trace_stage("target_sync",trace_stamp)
	if sim.closed:
		_bank_run("completed")
		return
	trace_stamp = _trace_stage("snapshot_enqueue",trace_stamp)
	_update_hud()
	_advance_combat_feedback()
	_update_rhythm_presentation()
	_trace_stage("hud_and_aim",trace_stamp)

func _trace_stage(stage: String, started: int) -> int:
	if not performance_trace_enabled:
		return 0
	var now := Time.get_ticks_usec()
	var elapsed := now-started
	var record: Dictionary = performance_stage_usec.get(stage,{"count":0,"total":0,"max":0,"last":0,"over_4ms":0,"over_8ms":0,"over_16ms":0})
	record.count += 1
	record.total += elapsed
	record.max = maxi(int(record.max),elapsed)
	record.last = elapsed
	record.over_4ms += 1 if elapsed>4000 else 0
	record.over_8ms += 1 if elapsed>8000 else 0
	record.over_16ms += 1 if elapsed>16000 else 0
	performance_stage_usec[stage] = record
	return now

func _empty_combat_summary(root_id: int) -> Dictionary:
	return {"root_id":root_id,"hits":0,"damage":0,"destroyed":0,"coins":0,"circle_coins":0,"circle_destroyed":0,"cards":0,"pack_grade":-1,"card_grade":-1,"variant":"","claim_positions":[],"variants":{}}

func _collect_root_rewards(events: Array, fallback_root: int) -> Dictionary:
	# Presentation-only summaries of committed claims. Never merge separate attacks.
	var roots: Dictionary = {}
	for event in events:
		if str(event.get("type",""))!="claim":
			continue
		var root_id := int(event.get("root_id",fallback_root))
		if not roots.has(root_id):
			roots[root_id] = _empty_combat_summary(root_id)
		_add_reward_summary(roots[root_id],event)
	return roots

func _grouped_reward_roots(roots: Dictionary) -> Dictionary:
	var grouped: Dictionary = {}
	var high_density := is_instance_valid(world) and world.has_method("high_density_feedback") and bool(world.high_density_feedback())
	for root_id in roots:
		var root_total: Dictionary = _harvest_root_totals.get(int(root_id),{})
		var dense_root := high_density or bool(root_total.get("high_density_feedback",false))
		var destroyed := int(roots[root_id].get("destroyed",0))
		if destroyed>=GROUPED_REWARD_MIN_PACKS or (dense_root and destroyed>0):
			grouped[root_id] = true
			if dense_root: roots[root_id]["high_density_feedback"] = true
	return grouped

func _add_reward_summary(summary: Dictionary, event: Dictionary) -> void:
	var reward: Dictionary = event.get("reward",{})
	summary.claim_positions.append([float(event.target.pos.x),float(event.target.pos.y)])
	summary.destroyed += 1
	summary.coins += int(reward.get("coins",0))
	if bool(reward.get("in_circle",false)):
		summary.circle_coins += int(reward.get("coins",0))
		summary.circle_destroyed += 1
	summary.pack_grade = maxi(int(summary.pack_grade),int(event.target.pack_grade))
	for variant: String in reward.get("cards",{}):
		if int(reward.cards[variant])<=0:
			continue
		summary.cards += int(reward.cards[variant])
		summary.variants[variant] = int(summary.variants.get(variant,0))+int(reward.cards[variant])
		var grade := int(variant.get_slice("-",1))
		if grade>int(summary.card_grade):
			summary.card_grade = grade
			summary.variant = variant

func _show_combat_feedback(summary: Dictionary) -> void:
	if int(summary.destroyed)<=0 or not is_instance_valid(combat_feedback):
		return
	feedback_pulse_until = sim.tick+18
	if int(summary.card_grade)>=3 and not str(summary.variant).is_empty():
		_show_special_banner(summary)
	# The world owns local icon+amount rewards and the actual high-grade card reveal.
	# This is only a short local multi-pack accent, never a top-of-screen reward banner.
	var positions: Array = summary.get("claim_positions",[])
	if positions.is_empty(): return
	var batch_key := "%d/%s" % [int(sim.tick),str(summary.get("root_id",-1))]
	if _harvest_seen.has(batch_key): return
	_harvest_seen[batch_key] = true
	var display_summary := summary.duplicate(true)
	display_summary["display_tick"] = int(sim.tick)
	var root_total := _record_harvest_root_summary(display_summary)
	var center := Vector2.ZERO
	for position: Array in positions:
		center += Vector2(float(position[0]),float(position[1]))
	center /= positions.size()
	var point: Vector2 = world.table_to_screen(center)
	var request := {"summary":display_summary,"point":point,"batch_key":batch_key}
	if bool(display_summary.get("reward_grouped",false)):
		# Currency/card feedback is submitted immediately. Only this auxiliary
		# pack-count tag may wait, never the committed reward or its ordinary popup.
		if bool(display_summary.get("high_density_feedback",false)):
			# Send only this tick's committed delta. The World owns its same-root
			# amount merge; only the separate pack-count tag uses cumulative totals.
			world.present_reward_group(display_summary)
		else:
			var popup_size: Vector2 = world.reward_group_popup_size(display_summary)
			var block_size := Vector2(maxf(HARVEST_BADGE_SIZE.x,popup_size.x),HARVEST_BADGE_SIZE.y+10.0+popup_size.y)
			var placement := _harvest_placement(point,block_size,true)
			if bool(placement.safe):
				var origin: Vector2 = placement.position
				request["badge_origin"] = origin+Vector2((block_size.x-HARVEST_BADGE_SIZE.x)*.5,0)
				world.present_reward_group(display_summary,origin+Vector2((block_size.x-popup_size.x)*.5,HARVEST_BADGE_SIZE.y+10.0))
			else:
				world.present_reward_group(display_summary)
	if bool(display_summary.get("high_density_feedback",false)) and _coalesce_harvest_root(request,root_total): return
	_harvest_queue.append(request)
	_try_harvest_queue()

func _record_harvest_root_summary(summary: Dictionary) -> Dictionary:
	var root_id := int(summary.get("root_id",-1))
	if not _harvest_root_totals.has(root_id):
		_harvest_root_totals[root_id] = {"destroyed":0,"coins":0,"cards":0,"first_tick":int(summary.display_tick),"last_tick":int(summary.display_tick),"source_ticks":[],"high_density_feedback":false}
	var total: Dictionary = _harvest_root_totals[root_id]
	for amount in ["destroyed","coins","cards"]: total[amount] = int(total[amount])+int(summary.get(amount,0))
	total.last_tick = int(summary.display_tick)
	total.source_ticks.append(int(summary.display_tick))
	total.high_density_feedback = bool(total.high_density_feedback) or bool(summary.get("high_density_feedback",false))
	return total

func _refresh_harvest_badge_totals(badge: Control, summary: Dictionary) -> void:
	for amount in ["destroyed","coins","cards"]: badge.set_meta(amount,int(summary.get(amount,0)))
	badge.set_meta("display_tick",int(summary.display_tick))
	badge.set_meta("last_display_tick",int(summary.get("last_display_tick",summary.display_tick)))
	badge.set_meta("source_ticks",summary.get("source_ticks",[int(summary.display_tick)]).duplicate())
	badge.set_meta("high_density_feedback",true)
	var title := badge.get_node_or_null("LocalHarvest") as Label
	if title!=null: title.text = "＋%d 金币 · %d包" % [int(summary.coins),int(summary.destroyed)]
	badge.tooltip_text = "本次攻击累计收获：%d 金币、%d 张圆卡；没有额外奖励。" % [int(summary.coins),int(summary.cards)]

func _coalesce_harvest_root(request: Dictionary, total: Dictionary) -> bool:
	var summary: Dictionary = request.summary.duplicate(true)
	var root_id := int(summary.get("root_id",-1))
	for amount in ["destroyed","coins","cards"]: summary[amount] = int(total[amount])
	summary["display_tick"] = int(total.first_tick)
	summary["last_display_tick"] = int(total.last_tick)
	summary["source_ticks"] = total.source_ticks.duplicate()
	request.summary = summary
	var live_badge: Control = null
	for index in range(feedback_entries.size()-1,-1,-1):
		var entry: Dictionary = feedback_entries[index]
		if entry.get("kind","")!="harvest" or not is_instance_valid(entry.node) or int(entry.node.get_meta("root_id",-1))!=root_id: continue
		if live_badge==null:
			live_badge = entry.node
			_refresh_harvest_badge_totals(live_badge,summary)
		else:
			var retired: Control = entry.node
			if retired.get_parent()!=null: retired.get_parent().remove_child(retired)
			retired.queue_free()
			feedback_entries.remove_at(index)
	var queued := false
	var index := 0
	while index<_harvest_queue.size():
		var pending: Dictionary = _harvest_queue[index]
		if int(pending.summary.get("root_id",-1))!=root_id:
			index+=1
			continue
		if live_badge!=null or queued:
			_harvest_queue.remove_at(index)
			continue
		pending.summary = summary
		pending.point = request.point
		queued = true
		index+=1
	if live_badge!=null: _publish_harvest_reservations()
	return live_badge!=null or queued

func _harvest_position(point: Vector2, badge_size: Vector2, avoid_grouped: bool = false) -> Vector2:
	return _harvest_placement(point,badge_size,avoid_grouped).position

func _world_feedback_sweeps() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for other in world._screen_effects.get_children():
		if other is Control and not other.is_queued_for_deletion() and other.size.x>0.0 and other.size.y>0.0:
			# World includes real _hf_target corrections, queued homes and endpoints.
			# Its six-pixel margin plus this six keeps the Main twelve-pixel gap.
			var sweep: Rect2 = world._aux_control_sweep(other)
			if sweep.has_area(): result.append(sweep.grow(6))
	return result

func _harvest_placement(point: Vector2, badge_size: Vector2, _avoid_grouped: bool = false, preferred: Variant = null, ignore_node: Control = null, world_sweeps: Variant = null) -> Dictionary:
	var best := Vector2.ZERO
	var best_score := INF
	var aim_rect := _harvest_aim_rect()
	var obstacles: Array[Rect2] = [_premium_hud_band_rect(),Rect2(18,14,1884,114),Rect2(18,920,1884,144)]
	# Creation takes a fresh snapshot because more World rows can be born in the
	# same tick. Display updates share one snapshot across both existing badges.
	obstacles.append_array(world_sweeps if world_sweeps is Array else _world_feedback_sweeps())
	for entry in feedback_entries:
		if entry.get("kind","")=="harvest" and is_instance_valid(entry.node) and entry.node!=ignore_node and entry.node.visible and not entry.node.is_queued_for_deletion():
			obstacles.append(Rect2(entry.origin,entry.node.size).grow(6))
	# Work in the same projected UI space as every feedback Control. Keep both
	# rows on the wood and clear of every visible dispenser, not only the top one.
	var table_rect := Rect2()
	for x in [-Rules.TABLE_HALF_WIDTH+Rules.DESK_BORDER,Rules.TABLE_HALF_WIDTH-Rules.DESK_BORDER]:
		for y in [Rules.DESK_BORDER,Rules.TABLE_DEPTH-Rules.DESK_BORDER]:
			var corner: Vector2 = world.table_to_screen(Vector2(x,y))
			table_rect = Rect2(corner,Vector2.ZERO) if table_rect==Rect2() else table_rect.expand(corner)
	var bounds := table_rect.intersection(Rect2(56,218,1808,682))
	if badge_size.x+12.0>bounds.size.x or badge_size.y+12.0>bounds.size.y: return {"position":best,"safe":false}
	for station: Node3D in world._dispensers.values():
		if not is_instance_valid(station) or not station.visible: continue
		var art := station.get_node_or_null("FormalDispenserArt") as MeshInstance3D
		if art==null: continue
		var art_rect := Rect2()
		var art_bounds := art.get_aabb()
		for index in 8:
			var corner: Vector2 = world._pixel_to_screen(world.camera.unproject_position(art.global_transform*art_bounds.get_endpoint(index)))
			art_rect = Rect2(corner,Vector2.ZERO) if index==0 else art_rect.expand(corner)
		obstacles.append(art_rect.grow(14))
	var candidates: Array[Vector2] = []
	if preferred is Vector2: candidates.append(preferred)
	for gap in [24.0,108.0]:
		var span: Vector2 = aim_rect.size*.5+badge_size*.5+Vector2.ONE*gap
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			candidates.append(point+Vector2(direction.x*span.x,direction.y*span.y)-badge_size*.5)
	for side in [bounds.position.x+12.0,bounds.end.x-badge_size.x-12.0]:
		for y in [point.y-badge_size.y*.5,point.y-badge_size.y-32.0,point.y+32.0,bounds.position.y+12.0,bounds.position.y+bounds.size.y*.25,bounds.position.y+bounds.size.y*.5,bounds.position.y+bounds.size.y*.75,bounds.end.y-badge_size.y-12.0]:
			candidates.append(Vector2(side,y))
	var visited: Dictionary = {}
	for candidate in candidates:
		candidate.x = clampf(candidate.x,bounds.position.x+6.0,bounds.end.x-badge_size.x-6.0)
		candidate.y = clampf(candidate.y,bounds.position.y+6.0,bounds.end.y-badge_size.y-6.0)
		if visited.has(candidate): continue
		visited[candidate] = true
		var rect := Rect2(candidate,badge_size)
		var score := -1.0 if preferred is Vector2 and candidate==preferred else rect.get_center().distance_squared_to(point)
		if score>=best_score: continue
		var badge_sweep := rect.grow(6)
		if badge_sweep.intersects(aim_rect): continue
		var occupied := false
		for obstacle in obstacles:
			if badge_sweep.intersects(obstacle):
				occupied = true
				break
		if occupied: continue
		if score<best_score:
			best = candidate
			best_score = score
	return {"position":best,"safe":best_score<INF}

func _harvest_aim_rect() -> Rect2:
	var rect := Rect2(last_mouse-Vector2(76,76),Vector2(152,152))
	var operation: Rect2 = world.aim_feedback_keepout()
	return rect if operation.size==Vector2.ZERO else rect.merge(operation.grow(18))

func _try_harvest_queue(world_sweeps: Variant = null) -> void:
	if _harvest_queue.is_empty() or not is_instance_valid(combat_feedback): return
	var active := 0
	for entry in feedback_entries:
		if entry.get("kind","")=="harvest" and is_instance_valid(entry.node): active+=1
	while active<2 and not _harvest_queue.is_empty():
		var request: Dictionary = _harvest_queue[0]
		var placement := _harvest_placement(request.point,HARVEST_BADGE_SIZE,true,request.get("badge_origin"),null,world_sweeps)
		if not bool(placement.safe): return
		_harvest_queue.pop_front()
		_show_harvest_badge(request.summary,request.point,placement.position)
		active+=1

func _show_harvest_badge(summary: Dictionary, point: Vector2, position_override: Variant = null) -> void:
	var badge := Panel.new()
	badge.name = "HarvestBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = HARVEST_BADGE_SIZE
	badge.position = position_override if position_override is Vector2 else _harvest_position(point,badge.size,true)
	badge.pivot_offset = badge.size*.5
	badge.set_meta("destroyed",int(summary.destroyed))
	badge.set_meta("coins",int(summary.coins))
	badge.set_meta("cards",int(summary.cards))
	badge.set_meta("root_id",int(summary.get("root_id",-1)))
	badge.set_meta("display_tick",int(summary.get("display_tick",sim.tick)))
	if not _formal_style_cache.has("harvest-compact"): _formal_style_cache["harvest-compact"] = _pixel_style(PAPER,GOLD,0,1)
	badge.add_theme_stylebox_override("panel",_formal_style_cache["harvest-compact"])
	combat_feedback.add_child(badge)
	var title := _label(badge,"连破 %d 包" % int(summary.destroyed),24,INK,"pixel")
	title.name = "LocalHarvest"
	title.add_theme_font_size_override("font_size",24)
	title.position = Vector2(8,2)
	title.size = HARVEST_BADGE_SIZE-Vector2(16,4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.tooltip_text = "本批实际收获：%d 金币、%d 张圆卡；没有额外奖励。" % [int(summary.coins),int(summary.cards)]
	if bool(summary.get("high_density_feedback",false)): _refresh_harvest_badge_totals(badge,summary)
	feedback_entries.append({"node":badge,"start":sim.tick,"duration":HARVEST_LIFETIME_TICKS,"origin":badge.position,"kind":"harvest","point":point,"last_tick":int(sim.tick)})
	_publish_harvest_reservations()

func _premium_counts(summary: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for raw in summary.get("variants",{}):
		var variant := str(raw)
		var grade := int(variant.get_slice("-",1))
		var amount := int(summary.variants[raw])
		if grade>=3 and grade<=4 and amount>0 and CardCatalog.CATALOG.has(variant):
			counts[variant] = amount
	return counts

func _merge_premium_counts(destination: Dictionary, incoming: Dictionary) -> void:
	for variant in incoming:
		destination[variant] = int(destination.get(variant,0))+int(incoming[variant])

func _premium_representative(variants: Dictionary, minimum_grade: int = 3) -> String:
	var selected := ""
	var highest := minimum_grade-1
	for variant in variants:
		var grade := int(str(variant).get_slice("-",1))
		if grade>highest:
			highest = grade
			selected = str(variant)
	return selected

func _show_special_banner(summary: Dictionary) -> void:
	if sim==null or not is_instance_valid(combat_feedback):
		return
	var incoming := _premium_counts(summary)
	if incoming.is_empty():
		return
	var batch_key := "%d/%s" % [int(sim.tick),str(summary.root_id)] if summary.has("root_id") else ""
	for entry in feedback_entries:
		if entry.get("kind","")!="premium" or not is_instance_valid(entry.node):
			continue
		if not batch_key.is_empty() and (entry.seen.has(batch_key) or _premium_tail_seen.has(batch_key)):
			return
		var age := int(sim.tick)-int(entry.start)
		if age>=int(entry.duration)-PREMIUM_FADE_TICKS:
			# A fading banner never flashes back to full alpha. One bounded aggregate
			# tail replaces an unbounded per-card queue; awards already belong to Sim.
			_merge_premium_counts(_premium_tail,incoming)
			if not batch_key.is_empty(): _premium_tail_seen[batch_key] = true
			return
		_merge_premium_counts(entry.variants,incoming)
		for variant in incoming:
			if str(variant)!=str(entry.representative): entry.pending[variant] = true
		if not batch_key.is_empty(): entry.seen[batch_key] = true
		entry.duration = mini(PREMIUM_SESSION_MAX_TICKS,maxi(int(entry.duration),age+PREMIUM_LIFETIME_TICKS))
		_refresh_premium_banner(entry,false)
		return
	var seen: Dictionary = {}
	if not batch_key.is_empty(): seen[batch_key] = true
	_create_premium_banner(incoming,seen)

func _premium_hud_band_rect() -> Rect2:
	return Rect2(440,330,1040,PREMIUM_BANNER_SIZE.y)

func _premium_dispenser_keepout() -> Rect2:
	if not is_instance_valid(world) or not world._dispensers.has("top"): return Rect2()
	var station: Node3D = world._dispensers.top
	if not is_instance_valid(station) or not station.visible: return Rect2()
	var art := station.get_node_or_null("FormalDispenserArt") as MeshInstance3D
	if art==null or not is_instance_valid(world.camera): return Rect2()
	var bounds := art.get_aabb()
	var result := Rect2()
	for index in 8:
		var point: Vector2 = world._pixel_to_screen(world.camera.unproject_position(art.global_transform*bounds.get_endpoint(index)))
		result = Rect2(point,Vector2.ZERO) if index==0 else result.expand(point)
	return result.grow(14)

func _premium_banner_placement(preferred: Vector2 = Vector2(INF,INF)) -> Dictionary:
	var band := _premium_hud_band_rect()
	var center := band.position+Vector2((band.size.x-PREMIUM_BANNER_SIZE.x)*.5,0)
	var candidates: Array[Vector2] = []
	if preferred.is_finite(): candidates.append(preferred)
	candidates.append_array([center,band.position,Vector2(band.end.x-PREMIUM_BANNER_SIZE.x,band.position.y)])
	var aim_rect := _harvest_aim_rect()
	var dispenser := _premium_dispenser_keepout()
	for position_value in candidates:
		var rect := Rect2(position_value,PREMIUM_BANNER_SIZE)
		if not band.encloses(rect): continue
		if rect.grow(4).intersects(aim_rect): continue
		if dispenser.has_area() and rect.grow(4).intersects(dispenser): continue
		return {"position":position_value,"safe":true}
	return {"position":center,"safe":false}

func _feedback_visibility_clock(entry: Dictionary, safe: bool) -> void:
	var now := int(sim.tick)
	var elapsed := maxi(0,now-int(entry.get("last_tick",now)))
	entry.last_tick = now
	if not safe:
		entry.start = int(entry.start)+elapsed
		if entry.get("kind","")=="premium": entry.represented_since = int(entry.represented_since)+elapsed
	var node: Control = entry.node
	node.visible = safe
	node.set_meta("blocked_by_aim",not safe)
	node.set_meta("display_ticks",maxi(0,now-int(entry.start)))

func _place_combat_feedback(entry: Dictionary, world_sweeps: Variant = null) -> bool:
	var node: Control = entry.node
	var safe := true
	if entry.get("kind","")=="premium":
		var placement := _premium_banner_placement(entry.origin)
		safe = bool(placement.safe)
		if safe: entry.origin = placement.position
	elif entry.get("kind","")=="harvest":
		var sweep := Rect2(entry.origin,node.size).grow(6)
		var peers: Array = world_sweeps if world_sweeps is Array else _world_feedback_sweeps()
		safe = not sweep.intersects(_harvest_aim_rect())
		if safe:
			for peer: Rect2 in peers:
				if sweep.intersects(peer):
					safe = false
					break
		if not safe:
			var placement := _harvest_placement(entry.point,node.size,true,null,node,peers)
			safe = bool(placement.safe)
			if safe: entry.origin = placement.position
	_feedback_visibility_clock(entry,safe)
	return safe

func _create_premium_banner(variants: Dictionary, seen: Dictionary = {}) -> void:
	var variant := _premium_representative(variants)
	if variant.is_empty(): return
	var grade := int(variant.get_slice("-",1))
	var banner := Panel.new()
	banner.name = "SpecialRewardBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.clip_contents = true
	var placement := _premium_banner_placement()
	banner.position = placement.position
	banner.size = PREMIUM_BANNER_SIZE
	banner.visible = bool(placement.safe)
	banner.set_meta("info_band",_premium_hud_band_rect())
	banner.set_meta("blocked_by_aim",not bool(placement.safe))
	banner.set_meta("display_ticks",0)
	banner.z_index = 10
	combat_feedback.add_child(banner)
	var portrait := _art(banner,_card_art_path(variant),Rect2(12,8,48,48))
	portrait.name = "BannerActualCard"
	var title := _label(banner,"",30,GRADE_COLORS[grade],"body")
	title.name = "BannerTitle"
	title.add_theme_font_size_override("font_size",18)
	title.position = Vector2(76,1)
	title.size = Vector2(590,27)
	var subtitle := _label(banner,"",28,INK,"body")
	subtitle.name = "BannerCardName"
	subtitle.add_theme_font_size_override("font_size",22)
	subtitle.position = Vector2(76,30)
	subtitle.size = Vector2(590,33)
	subtitle.clip_text = true
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var shine := ColorRect.new()
	shine.name = "BannerShine"
	shine.color = Color(1,.94,.65,.15)
	shine.size = Vector2(20,PREMIUM_BANNER_SIZE.y)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(shine)
	var entry := {"node":banner,"start":int(sim.tick),"duration":PREMIUM_LIFETIME_TICKS,"origin":banner.position,"kind":"premium","shine":shine,"variants":variants.duplicate(),"pending":{},"representative":variant,"represented_since":int(sim.tick),"seen":seen.duplicate(),"last_tick":int(sim.tick)}
	for other in variants:
		if str(other)!=variant: entry.pending[other] = true
	feedback_entries.append(entry)
	_refresh_premium_banner(entry,true)
	banner.modulate.a = 0.0

func _refresh_premium_banner(entry: Dictionary, portrait_changed: bool) -> void:
	var banner: Control = entry.node
	var variant := str(entry.representative)
	var grade := int(variant.get_slice("-",1))
	var gold := 0
	var red := 0
	var details: Array[String] = []
	for card in entry.variants:
		var amount := int(entry.variants[card])
		if int(str(card).get_slice("-",1))==4: red += amount
		else: gold += amount
		details.append("%s ×%d" % [_card_name(str(card)),amount])
	var title: Label = banner.get_node("BannerTitle")
	var gains: Array[String] = []
	if red>0: gains.append("远古 ×%d" % red)
	if gold>0: gains.append("传说 ×%d" % gold)
	title.text = "高阶连获 · "+"  /  ".join(gains)
	var subtitle: Label = banner.get_node("BannerCardName")
	subtitle.text = "%s  ×%d%s" % [_card_name(variant),int(entry.variants[variant])," · 另有%d种" % (entry.variants.size()-1) if entry.variants.size()>1 else ""]
	banner.set_meta("variants",entry.variants.duplicate())
	banner.set_meta("grade_counts",[0,0,0,gold,red])
	banner.set_meta("representative",variant)
	banner.set_meta("read_since",int(entry.represented_since))
	banner.tooltip_text = "本段实际获得："+"、".join(details)+"；展示不额外增加奖励。"
	if portrait_changed:
		banner.add_theme_stylebox_override("panel",_style(Color("#332540"),GRADE_COLORS[grade],0,2))
		var portrait: TextureRect = banner.get_node("BannerActualCard")
		portrait.texture = _texture(_card_art_path(variant))
		_apply_card_foil(portrait,int(variant.get_slice("-",0).substr(1))-1,grade)
		title.add_theme_color_override("font_color",GRADE_COLORS[grade])

func _publish_harvest_reservations() -> void:
	if not is_instance_valid(world) or not world.has_method("set_external_aux_reservations"): return
	var rows: Array[Dictionary] = []
	if sim!=null:
		var now: float = world.clock_time
		for entry in feedback_entries:
			if entry.get("kind","")!="harvest": continue
			var node: Control = entry.node
			if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_visible_in_tree(): continue
			var remaining := maxi(0,int(entry.duration)-(int(sim.tick)-int(entry.start)))
			if remaining<=0: continue
			var row := {"node":node,"rect":Rect2(node.position,node.size).grow(6),"start":now,"end":now+float(remaining)/60.0,"fixed_end":true}
			row.make_read_only()
			rows.append(row)
	rows.make_read_only()
	world.set_external_aux_reservations(rows)

func _advance_combat_feedback() -> void:
	if sim==null:
		_publish_harvest_reservations()
		return
	var needs_sweeps := not _harvest_queue.is_empty()
	for entry in feedback_entries:
		if entry.get("kind","")=="harvest":
			needs_sweeps = true
			break
	var world_sweeps: Array[Rect2] = []
	if needs_sweeps: world_sweeps = _world_feedback_sweeps()
	for index in range(feedback_entries.size()-1,-1,-1):
		var entry: Dictionary = feedback_entries[index]
		var label: Control = entry.node
		if not is_instance_valid(label):
			feedback_entries.remove_at(index)
			continue
		if entry.get("kind","") in ["premium","harvest"] and not _place_combat_feedback(entry,world_sweeps): continue
		var age: int = int(sim.tick)-int(entry.start)
		if entry.get("kind","")=="premium" and age<=int(entry.duration)-PREMIUM_FADE_TICKS-PREMIUM_READ_TICKS and int(sim.tick)-int(entry.represented_since)>=PREMIUM_READ_TICKS:
			var next := _premium_representative(entry.pending,int(str(entry.representative).get_slice("-",1)))
			if not next.is_empty():
				entry.representative = next
				entry.represented_since = int(sim.tick)
				entry.pending.erase(next)
				_refresh_premium_banner(entry,true)
		if age>=int(entry.duration):
			if label.get_parent()!=null:
				label.get_parent().remove_child(label)
			label.queue_free()
			feedback_entries.remove_at(index)
			continue
		var reduced := bool(profile.get("settings",{}).get("reduce_effects",false))
		if entry.get("kind","")=="harvest":
			label.scale = Vector2.ONE
			label.position = entry.origin
			label.modulate.a = minf(1.0,float(int(entry.duration)-age)/6.0)
			continue
		if entry.get("kind","")=="premium":
			var appear := clampf(float(age)/8.0,0,1)
			var fade := clampf(float(int(entry.duration)-age)/12.0,0,1)
			label.position = entry.origin
			label.modulate.a = minf(appear,fade)
			var shine: ColorRect = entry.shine
			shine.visible = not reduced
			shine.position.x = -20+float(age)*14
			continue
		label.position = entry.origin+Vector2(0,0 if reduced else -minf(float(age),12.0)*.5)
		label.modulate.a = minf(1.0,float(int(entry.duration)-age)/12.0)
	var has_premium := false
	for entry in feedback_entries:
		if entry.get("kind","")=="premium": has_premium = true
	if not has_premium and not _premium_tail.is_empty():
		var pending := _premium_tail.duplicate()
		var pending_seen := _premium_tail_seen.duplicate()
		_premium_tail.clear()
		_premium_tail_seen.clear()
		_create_premium_banner(pending,pending_seen)
	_try_harvest_queue(world_sweeps)
	for label: Label in [hud_score,hud_loot]:
		if is_instance_valid(label):
			var pulse := clampf(float(feedback_pulse_until-sim.tick)/18.0,0,1)
			label.modulate = Color.WHITE.lerp(GOLD,pulse*.65)
	_publish_harvest_reservations()

func _update_hud() -> void:
	if sim==null:
		return
	var counts := [0,0,0,0,0]
	for variant in sim.loot:
		var grade := int(str(variant).get_slice("-",1))
		if grade>=0 and grade<5:
			counts[grade] += int(sim.loot[variant])
	for grade in range(hud_grade_counts.size()):
		if is_instance_valid(hud_grade_counts[grade]):
			hud_grade_counts[grade].text = "%d/%d" % [sim.targets.size(),int(sim.run_options.get("capacity",24))]
	if is_instance_valid(hud_time):
		hud_time.text = "剩余时间  "+GameConfig.clock_caption(Rules.RUN_TICKS-maxi(0,sim.tick))
	if is_instance_valid(hud_score):
		hud_score.text = "本局金币  %d" % int(sim.score)
	if is_instance_valid(hud_loot):
		var amount: int = 0
		for value in sim.loot.values():
			amount += int(value)
		hud_loot.text = "本局收获  %d" % amount

func _bank_run(reason_value: String) -> void:
	if sim==null: return
	paused=true
	audio.set_rhythm_paused(true)
	profile["active_run"]={}
	var result := {"run_id":sim.run_id,"loot":sim.loot.duplicate(true),"score":int(sim.score),
		"pack_coins":int(sim.score),"shots":int(sim.shots),"elapsed_ticks":clampi(sim.tick,0,Rules.RUN_TICKS),
		"reason":reason_value,"destroyed_pack_count":sim.destroyed_pack_count,"rhythm":sim.get_summary().get("rhythm",{}).duplicate(true)}
	var banked: Dictionary=storage.bank_collection(slot,profile,result)
	if not banked.ok:
		save_error=str(banked.error)
		_show_error("结算尚未保存",save_error,func() -> void: _bank_run(reason_value))
		return
	profile=banked.profile
	has_profile=true
	settings_dirty=false
	save_error=""
	_show_result()

func _show_result() -> void:
	screen="result"
	paused=false
	_clear_overlay()
	_clear_ui()
	world.clear_cards()
	world.set_aim(Vector2.ZERO,0,false,false)
	audio.set_rhythm_paused(false)
	audio.set_ducked(false)
	audio.music("menu")
	_backdrop()
	settlement_view=SettlementView.new()
	settlement_view.position=Vector2(40,125)
	settlement_view.size=Vector2(1840,880)
	ui.add_child(settlement_view)
	settlement_view.configure(profile.get("last_result",{}),pixel_font,func() -> void: _show_hub("collection"),_start_run,bool(profile.settings.get("reduce_effects",false)),font)
	settlement_view.set_input_device(drum_input_device)
	settlement_view.sound_requested.connect(_settlement_sound)

func _settlement_sound(key: String) -> void:
	match key:
		"red_charge": audio.play("charge",.65,0)
		"red_reveal": audio.play("ancient",.85,0)
		"flip": audio.play("flip",.35,0)
		"coins": audio.play("collect",.45,0)
		"new_card": audio.play("rare",.5,0)

func _discard_run() -> void:
	# Discarding a battle does not write the profile or grant its pending drops.
	sim=null
	profile["active_run"]={}
	rhythm_input_queue.clear()
	audio.reset_rhythm()
	_show_hub("collection")

func _result_grade_summary(parent: Node, loot: Dictionary) -> void:
	# Display the exact committed loot ledger, including full-level conversions.
	var totals: Array[int] = [0,0,0,0,0]
	for variant in loot:
		var definition := CardCatalog.card_definition(str(variant))
		if not definition.is_empty():
			totals[int(definition.grade)] += int(loot[variant])
	var row := _hbox(parent,14)
	row.name = "ResultGradeSummary"
	for grade in range(1):
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := _style(Color("#403354"),GRADE_COLORS[grade].darkened(.35),0,1).duplicate() as StyleBoxTexture
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel",style)
		row.add_child(chip)
		var content := _hbox(chip,10)
		var icon := _art(content,_presentation_asset("packs/pack-%d.png" % grade),Rect2())
		icon.custom_minimum_size = Vector2(34,44)
		var amount := _label(content,"收藏经营系统待开放 · 本轮金币已结算",24,GRADE_COLORS[grade],"pixel")
		amount.name = "ResultGradeCount%d" % grade
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.set_meta("grade_total",totals[grade])

func _begin_battle_journal() -> bool:
	return true

func _absorb_battle_save(result: Dictionary) -> void:
	if bool(result.get("completed",false)) and result.has("revision") and storage==_journal_storage and slot==_journal_slot:
		# The worker owns an older immutable snapshot; only its committed revision returns.
		profile.revision = int(result.revision)

func _poll_battle_save() -> bool:
	if _battle_journal==null:
		return true
	var result: Dictionary = _battle_journal.poll()
	if not bool(result.ok):
		if save_error!=str(result.error):
			_battle_save_failed(str(result.error))
		return false
	_absorb_battle_save(result)
	return true

func _finish_battle_save() -> bool:
	if _battle_journal==null:
		return true
	var result: Dictionary = _battle_journal.finish_checkpoint()
	if not bool(result.ok):
		_battle_save_failed(str(result.error))
		return false
	_absorb_battle_save(result)
	return true

func _checkpoint_battle() -> bool:
	if not _poll_battle_save():
		return false
	profile["active_run"] = sim.snapshot()
	var result: Dictionary = _battle_journal.checkpoint(profile)
	if not bool(result.ok):
		_battle_save_failed(str(result.error))
		return false
	return true

func _stop_battle_journal(report_error: bool = true) -> bool:
	if _battle_journal==null:
		return true
	var result: Dictionary = _battle_journal.end()
	_absorb_battle_save(result)
	_battle_journal = null
	_journal_sim = null
	_journal_storage = null
	if not bool(result.ok) and report_error:
		_battle_save_failed(str(result.error))
		return false
	return true

func _battle_save_failed(reason: String) -> void:
	save_error = reason
	paused = screen=="battle"
	audio.set_ducked(paused)
	audio.set_rhythm_paused(paused)
	rhythm_input_queue.clear()
	_update_rhythm_presentation()
	_show_error("保存未完成，战斗已暂停",reason,_retry_battle_save)

func _retry_battle_save() -> void:
	var settings: Dictionary = profile.get("settings",{}).duplicate(true)
	var dirty := settings_dirty
	_stop_battle_journal(false)
	var loaded: Dictionary = storage.load_slot(slot)
	if not bool(loaded.ok):
		_battle_save_failed(str(loaded.error))
		return
	profile = loaded.profile
	if dirty:
		profile.settings = settings
	save_error = ""
	_resume_run()

func _save_profile() -> bool:
	profile["active_run"]={}
	if not _finish_battle_save():
		return false
	var saved: Dictionary = storage.save_slot(slot,profile)
	if not bool(saved.get("ok",false)):
		save_error = str(saved.get("error","无法保存"))
		paused = screen=="battle"
		audio.set_ducked(paused)
		audio.set_rhythm_paused(paused)
		_show_error("保存失败，进度已暂停",save_error)
		return false
	profile = saved["profile"]
	has_profile = true
	save_error = ""
	return true

func _show_pause() -> void:
	if screen!="battle": return
	paused=true
	rhythm_input_queue.clear()
	audio.set_ducked(true)
	audio.set_rhythm_paused(true)
	_update_rhythm_presentation()
	var box := _dialog("已暂停",520)
	var resume := _button(box,"继续","PauseResume",_resume_rhythm,true)
	ControllerUI.decorate(resume,"B")
	_button(box,"设置","PauseSettings",_show_settings)
	_button(box,"提前结束并结算","PauseEnd",_confirm_end)
	var hints := ControllerUI.hints([{"binding":"Stick","label":"选择"},{"binding":"A","label":"确认"},{"binding":"B","label":"继续游戏"}],drum_input_device)
	hints.name = "PauseInputHints"
	hints.custom_minimum_size = Vector2(0,44)
	box.add_child(hints)
	var return_button := overlay.find_child(_pause_return_button,true,false) as Control
	_pause_return_button = "PauseResume"
	_queue_control_focus(return_button)

func _confirm_end() -> void:
	var box := _dialog("提前收手？")
	_label(box,"当前获得的圆卡与金币都会带回。",26,MUTED)
	_button(box,"继续本局","CancelEnd",_show_pause)
	_button(box,"结束并结算","ConfirmEnd",func() -> void: _bank_run("early_settlement"),true)
	var confirm_hints := ControllerUI.hints([{"binding":"A","label":"确认所选"},{"binding":"B","label":"取消"}],drum_input_device)
	confirm_hints.name = "EndConfirmationInputHints"
	confirm_hints.custom_minimum_size = Vector2(0,44)
	box.add_child(confirm_hints)
	var cancel := overlay.find_child("CancelEnd",true,false) as Control
	_queue_control_focus(cancel)

func _dialog(title_value: String, height_value: float = 600) -> VBoxContainer:
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and ui.is_ancestor_of(focused):
		_dialog_return_focus = weakref(focused)
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade(overlay,.65)
	var panel := _panel(overlay,Rect2(550,(1080-height_value)*.5,820,height_value))
	var box := _vbox(panel,18)
	_label(box,title_value,44)
	return box

func _show_error(title_value: String, message: String, retry: Callable = Callable()) -> void:
	var box := _dialog(title_value)
	if message=="revision_conflict":
		var conflict := _label(box,"磁盘中已有较新进度，已阻止旧数据覆盖。\n读取最新存档会保留已保存收获；\n当前未保存的设置和战斗进度不会合并。",26,MUTED)
		conflict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(box,"读取最新存档","ReloadLatestSave",func() -> void: _choose_slot(slot),true)
		_button(box,"暂不读取","KeepCurrentSaveState",_clear_overlay)
		return
	var readable: String = {"save_busy":"这个档位正在被另一次保存占用，请稍后重试。","write_failed":"未能写入存档，原有进度已保留，请重试。","verify_failed":"存档写入校验未通过，原有进度已保留，请重试。","backup_failed":"备份未能完成，原有进度已保留，请重试。","replace_failed":"未能更新存档文件，原有进度已保留，请重试。","integer_overflow":"收获数量已超过可保存范围，当前进度未被覆盖。"}.get(message,message)
	if message.begins_with("journal_"):
		readable = {"journal_write_failed":"未能记录本局进度，战斗已暂停。请检查磁盘空间后重试。","journal_worker_failed":"后台保存未能完成，已暂停。重试将恢复已记录的本局进度。","journal_session_changed":"本局保存对象已变化，请重新读取档位。"}.get(message,"无法校验本局进度，已暂停并保留原存档和记录。")
	var text := _label(box,readable,26,GRADE_COLORS[4])
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box,"重试","RetrySave",func() -> void:
		if retry.is_valid():
			retry.call()
		elif _save_profile():
			if screen=="battle":
				_resume_rhythm()
			else:
				_clear_overlay()
	,true)
	_button(box,"返回主菜单","ErrorMenu",_show_menu)

func _mark_settings_dirty() -> void:
	settings_dirty = true
	if is_instance_valid(overlay):
		var save_button := overlay.find_child("ManualSave",true,false) as Button
		if save_button != null: save_button.text = "保存"

func _show_settings() -> void:
	if screen=="battle":
		var pause_focus := get_viewport().gui_get_focus_owner()
		if pause_focus!=null and str(pause_focus.name).begins_with("Pause"):
			_pause_return_button = str(pause_focus.name)
		paused = true
		audio.set_ducked(true)
		audio.set_rhythm_paused(true)
		rhythm_input_queue.clear()
		_update_rhythm_presentation()
	var box := _dialog("设置",890)
	if is_instance_valid(settlement_view): settlement_view.set_paused(true)
	_volume_row(box,"背景音乐","music_volume","music_muted","MusicVolumeSlider")
	_volume_row(box,"游戏音效","sfx_volume","sfx_muted","VolumeSlider")
	var effects := CheckButton.new()
	effects.name = "ReduceEffectsToggle"
	effects.text = "减少特效"
	effects.button_pressed = bool(profile.get("settings",{}).get("reduce_effects",false))
	effects.custom_minimum_size.y = 58
	effects.toggled.connect(func(value: bool) -> void:
		profile["settings"]["reduce_effects"] = value
		world.reduce_effects = value
		if is_instance_valid(settlement_view): settlement_view.set_reduced(value)
		if is_instance_valid(rhythm_hud):
			rhythm_hud.reduced = value
		_refresh_foil_settings(ui)
		_refresh_foil_settings(overlay)
		_mark_settings_dirty()
	)
	box.add_child(effects)
	var fullscreen := CheckButton.new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.text = "全屏"
	fullscreen.button_pressed = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.custom_minimum_size.y = 58
	fullscreen.toggled.connect(func(value: bool) -> void:
		profile["settings"]["fullscreen"] = value
		_mark_settings_dirty()
		_apply_settings()
	)
	box.add_child(fullscreen)
	var input_hints := SettingsInputHints.new()
	box.add_child(input_hints)
	input_hints.configure(pixel_font,font,drum_input_device)
	_button(box,"音源署名","AudioCredits",_show_audio_credits)
	_spacer(box,12)
	_button(box,"保存","ManualSave",func() -> void:
		if _save_profile():
			settings_dirty=false
			var saved := overlay.find_child("ManualSave",true,false) as Button
			if saved!=null: saved.text="已保存"
	,true)
	_button(box,"返回","CloseSettings",func() -> void:
		if screen=="battle": _show_pause()
		else: _clear_overlay())

func _show_audio_credits() -> void:
	var box := _dialog("音源署名",850)
	_label(box,"纸张撕裂：Joseph SARDIN & Axeline T. · CC0",26,INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box,"Coins_Few_05：Little Robot Sound Factory · CC-BY 3.0\n仅进行PCM16格式适配",26,INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box,"BGM、四鼓、合唱与庆祝：Patapon社区原音档案 · TheSandKid",26,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box,"金币音效来源","CoinSource",func() -> void: OS.shell_open("https://opengameart.org/content/coins-sound-effects-library"))
	_button(box,"CC-BY 3.0","CoinLicense",func() -> void: OS.shell_open("https://creativecommons.org/licenses/by/3.0/"))
	_button(box,"返回设置","CreditsBack",_show_settings,true)

func _volume_row(parent: Node, title: String, volume_key: String, mute_key: String, slider_name: String) -> void:
	var row := _hbox(parent,16)
	row.custom_minimum_size.y = 64
	var label := _label(row,title,26)
	label.custom_minimum_size.x = 126
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = float(profile.get("settings",{}).get(volume_key,GameConfig.DEFAULT_MUSIC_VOLUME if volume_key=="music_volume" else GameConfig.DEFAULT_SFX_VOLUME))
	slider.custom_minimum_size = Vector2(360,48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_stylebox_override("slider",_pixel_style(Color("#251b35"),Color("#aa93b5"),5,1))
	slider.add_theme_stylebox_override("grabber_area",_pixel_style(Color("#ac708e"),GOLD,5,0))
	slider.add_theme_stylebox_override("grabber_area_highlight",_pixel_style(Color("#d9a2ba"),GOLD,5,0))
	slider.value_changed.connect(func(value: float) -> void:
		profile["settings"][volume_key] = value
		_mark_settings_dirty()
		_apply_settings()
		if volume_key=="sfx_volume":
			audio.play("ui_click",.45,160)
	)
	row.add_child(slider)
	var mute := CheckButton.new()
	mute.name = "MusicMuteToggle" if volume_key=="music_volume" else "SfxMuteToggle"
	mute.text = "静音"
	mute.button_pressed = bool(profile.get("settings",{}).get(mute_key,false))
	mute.custom_minimum_size.x = 140
	mute.toggled.connect(func(value: bool) -> void:
		profile["settings"][mute_key] = value
		_mark_settings_dirty()
		_apply_settings()
	)
	row.add_child(mute)

func _apply_settings() -> void:
	var settings: Dictionary = profile.get("settings",{})
	world.reduce_effects = bool(settings.get("reduce_effects",false))
	_refresh_foil_settings(ui)
	_refresh_foil_settings(overlay)
	if is_instance_valid(audio):
		audio.apply_settings(settings)
	if settings.has("fullscreen") and DisplayServer.get_name()!="headless":
		var desired_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode()!=desired_mode:
			DisplayServer.window_set_mode(desired_mode)

func _show_saves() -> void:
	var box := _dialog("存档")
	for number in range(1,4):
		var loaded: Dictionary = storage.load_slot(number)
		var title_value := "档位 %d  ·  空档" % number
		if bool(loaded.get("ok",false)) and bool(loaded.get("exists",false)):
			var item: Dictionary = loaded["profile"]
			title_value = "档位 %d  ·  %d 金币 / 累计%d张" % [number,int(item.get("points",0)),int(item.get("total_banked_cards",0))]
			if bool(loaded.get("recovered",false)):
				title_value += "  [备份]"
		elif not bool(loaded.get("ok",false)):
			title_value = "档位 %d  ·  存档损坏" % number
		var choose := _button(box,title_value,"SelectSlot%d" % number,func() -> void: _choose_slot(number),number==slot)
		choose.clip_text = true
		choose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choose.tooltip_text = title_value
	_label(box,"各档位独立自动保存，不会合并收获。",23,MUTED)
	_button(box,"返回","CloseSaves",_clear_overlay)

func _choose_slot(number: int) -> void:
	if not _stop_battle_journal():
		return
	var loaded: Dictionary = storage.load_slot(number)
	if not bool(loaded.get("ok",false)):
		_show_error("无法读取档位",str(loaded.get("error","存档损坏")))
		return
	slot = number
	profile = loaded["profile"]
	has_profile = bool(loaded.get("exists",false))
	save_error = ""
	settings_dirty = false
	_apply_settings()
	_show_menu()
	if bool(loaded.get("recovered",false)):
		var box := _dialog("已读取有效备份")
		_label(box,"主档损坏，已保留原文件并读取上一份有效进度。",23,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(box,"继续","AcceptBackup",_clear_overlay,true)

func _queue_drum_key(key: String) -> bool:
	if not key in DRUM_KEYS:
		return false
	if screen!="battle" or paused or sim==null or sim.closed or rhythm_input_queue.size()>=6:
		return false
	var state := _rhythm_state()
	var next_tick: int = sim.tick+1
	var echo: Dictionary = state.get("active_echo",{})
	if str(state.get("phase","idle"))=="respond" and next_tick<int(echo.get("end_tick",next_tick+1)):
		return false
	rhythm_input_queue.append({"key":key,"tick":next_tick,"phase":str(state.get("phase","idle")),
		"beat":int(state.get("beat",0)),"cycle":int(state.get("cycle",0)),
		"phrase_length":int(state.get("phrase_length",state.get("sequence",[]).size())),"cycle_start":int(state.get("cycle_start",0))})
	return true

func _input(event: InputEvent) -> void:
	var settings_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE
	var settings_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START
	if screen in ["menu","hub"] and (settings_key or settings_pad):
		var album := _collection_album()
		if album==null or album.get_inspector()==null:
			if overlay.get_child_count()==0: _show_settings()
			elif overlay.find_child("CloseSettings",true,false)!=null: _clear_overlay()
			else: return
			get_viewport().set_input_as_handled()
			return
	if _route_controller_navigation(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START and screen=="battle":
		if not save_error.is_empty(): return
		if paused:
			rhythm_tutorial_seen = true
			_resume_rhythm()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()
		return
	if screen=="battle" and paused and not rhythm_tutorial_seen:
		var confirm_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]
		var confirm_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A
		if confirm_key or confirm_pad:
			rhythm_tutorial_seen = true
			_resume_rhythm()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and screen!="battle":
		last_mouse = event.position
	if event is InputEventKey and screen=="battle" and not paused:
		var key := ""
		match event.keycode:
			KEY_LEFT: key = "pata"
			KEY_RIGHT: key = "pon"
			KEY_DOWN: key = "don"
			KEY_UP: key = "chaka"
		if not key.is_empty():
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:
				_set_drum_input_device("keyboard")
				_queue_drum_key(key)
			return
	if event is InputEventJoypadButton and screen=="battle" and not paused:
		var key := ""
		match event.button_index:
			JOY_BUTTON_X: key = "pata"
			JOY_BUTTON_B: key = "pon"
			JOY_BUTTON_A: key = "don"
			JOY_BUTTON_Y: key = "chaka"
		if not key.is_empty():
			get_viewport().set_input_as_handled()
			if event.pressed:
				_set_drum_input_device("joypad")
				_queue_drum_key(key)
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if screen=="battle":
			if not save_error.is_empty():
				return
			if paused:
				if not rhythm_tutorial_seen:
					rhythm_tutorial_seen = true
					_resume_rhythm()
				else:
					_resume_rhythm()
			else:
				_show_pause()
			get_viewport().set_input_as_handled()
		elif overlay.get_child_count()>0:
			_clear_overlay()
			get_viewport().set_input_as_handled()

func _route_controller_navigation(event: InputEvent) -> bool:
	if overlay.get_child_count()>0: return false
	if screen=="result" and is_instance_valid(settlement_view):
		return settlement_view.handle_controller_event(event)
	if screen!="hub": return false
	var album := _collection_album()
	if album!=null and album.get_inspector()!=null:
		return false
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_Y]:
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_LEFT_SHOULDER: _cycle_hub_tab(-1)
				JOY_BUTTON_RIGHT_SHOULDER: _cycle_hub_tab(1)
				JOY_BUTTON_Y: _start_run()
		return true
	if album!=null: return album.handle_controller_event(event)
	var owner := get_viewport().gui_get_focus_owner()
	var tree := _talent_tree()
	if tree!=null and event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A:
		if owner!=null and tree.is_ancestor_of(owner) and (owner.has_meta("talent_id") or str(owner.name).begins_with("BuyTalent_")):
			if event.pressed: tree.activate_selected()
			return true
	var shop := _skin_shop()
	if shop!=null:
		if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A and (owner==null or not shop.is_ancestor_of(owner) or bool(owner.get_meta("controller_tab",false))): return false
		return shop.handle_controller_event(event)
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Inspectors consume B first; generic back only handles the remaining event.
	var back_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B
	var back_key: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or (screen=="hub" and overlay.get_child_count()==0 and event.keycode==KEY_BACKSPACE))
	if not back_pad and not back_key: return
	if screen=="battle":
		if paused and save_error.is_empty():
			if overlay.find_child("CloseSettings",true,false)!=null or overlay.find_child("CancelEnd",true,false)!=null:
				_show_pause()
			else:
				rhythm_tutorial_seen = true
				_resume_rhythm()
		else: return
	elif overlay.get_child_count()>0:
		_clear_overlay()
	elif screen=="hub":
		_show_menu()
	else: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if not initialization_ok: return
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen=="battle" and not paused:
		_show_pause()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		# Only explicit manual save and completed/early settlement may write.
		get_tree().quit()

func _exit_tree() -> void:
	_stop_battle_journal(false)
	card_textures.clear()
	hover_tweens.clear()

func get_debug_state() -> Dictionary:
	var state := {
		"screen":screen,"paused":paused,"slot":slot,"has_profile":has_profile,
		"coins":int(profile.get("points",0)),"talents":profile.get("talents",{}).duplicate(true),
		"selected_loadout":profile.get("selected_loadout",{}).duplicate(true),
		"collection":progression.collection_state(profile),"launchers":progression.launcher_states(profile),
		"rules_version":Rules.RULES_VERSION,"build_id":Rules.BUILD_ID,
		"next_run_options":_run_options(),
		"points":int(profile.get("points",0)),"inventory":profile.get("inventory",{}).duplicate(true),
		"settings":profile.get("settings",{}).duplicate(true),
		"banked_cards":int(profile.get("total_banked_cards",0)),"save_error":save_error,
		"save_dir":storage._base_dir,"initialization_ok":initialization_ok,"last_result":profile.get("last_result",{}).duplicate(true),
		"combat_feedback":last_combat_feedback.duplicate(true),"feedback_labels":feedback_entries.size(),"ui_skin_paths":skin_paths_used.duplicate()
	}
	state["prelude_frames"] = prelude_frames
	state["drum_input_device"] = drum_input_device
	state["input_source"] = input_source
	state["rhythm_input_queue"] = rhythm_input_queue.duplicate(true)
	if sim!=null and sim.has_method("get_rhythm_state"):
		state["rhythm"] = sim.get_rhythm_state()
	if is_instance_valid(rhythm_hud):
		state["rhythm_hud"] = rhythm_hud.get_presentation_state()
	if is_instance_valid(rhythm_overlay):
		state["rhythm_overlay"] = rhythm_overlay.get_presentation_state()
	if is_instance_valid(hud_coins):
		state["coin_hud"] = hud_coins.get_presentation_state()
	state["collection_album"] = CollectionCatalog.collection_counts(profile)
	if is_instance_valid(collection_grade_hud): state["card_grade_hud"] = collection_grade_hud.get_presentation_state()
	if is_instance_valid(battle_skin_layer): state["battle_skin"] = battle_skin_layer.get_presentation_state()
	if is_instance_valid(settlement_view): state["settlement"] = settlement_view.get_stage_state()
	if is_instance_valid(fever_border):
		state["fever_border"] = fever_border.get_presentation_state()
	if is_instance_valid(audio):
		state["audio"] = audio.get_status()
	if sim!=null:
		state["simulation"] = sim.get_summary()
		state["world_dispensers"] = {}
		for id_value in world._dispensers:
			var station: Node3D = world._dispensers[id_value]
			var expected: Vector2 = Rules.dispenser_position(str(id_value),maxi(0,sim.tick))
			state.world_dispensers[id_value] = {"visible":station.visible,"table_pos":[station.position.x*100,-station.position.z*100],"expected":[expected.x,expected.y]}
	return state

func get_target_screen_points() -> Array:
	var points: Array = []
	if sim==null or screen!="battle":
		return points
	for target in sim.get_exposed_targets():
		var p: Vector2 = world.table_to_screen(target["pos"])
		var prediction: Dictionary = Sim.reflected_motion(target.pos,target.velocity,.40)
		var lead: Vector2 = world.table_to_screen(prediction.pos)
		points.append({"id":target["id"],"x":p.x,"y":p.y,"table_x":target["pos"].x,"table_y":target["pos"].y,
			"lead_x":lead.x,"lead_y":lead.y,
			"pack_grade":target["pack_grade"],"is_fast":target["is_fast"],"remaining":target["remaining"],
			"velocity":[target["velocity"].x,target["velocity"].y]})
	return points


