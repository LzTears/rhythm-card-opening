extends RefCounted
## WebGL first-use work belongs under a loading cover, before any real run.
## Use production factories and the production atlas/geometry batches; never
## submit fake simulation events, rewards, audio requests, targets or ticks.
const SkillEffect = preload("res://scripts/world_skill_effect.gd")
const RewardFlyer = preload("res://scripts/world_reward_flyer.gd")

static func run(world) -> Dictionary:
	if not OS.has_feature("web"):
		return {"enabled":false,"completed":false,"reason":"native_unchanged"}
	var started := Time.get_ticks_usec()
	var start_frame := Engine.get_process_frames()
	var was_processing: bool = world.is_processing()
	var display_visible: bool = world._pixel_display.visible
	var update_mode: int = world._pixel_viewport.render_target_update_mode
	world.set_process(false)
	world._pixel_display.visible = true
	world._pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cover_layer := CanvasLayer.new()
	cover_layer.name = "WebFeedbackWarmupCover"
	cover_layer.layer = 120
	world.add_child(cover_layer)
	var cover := ColorRect.new()
	cover.name = "OpaqueLoadingCover"
	cover.color = Color("#101719")
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover_layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.size = world.get_viewport().get_visible_rect().size
	var caption := Label.new()
	caption.text = "正在准备画面…"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color",Color("#f8e8c6"))
	cover.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var warm_root := Node3D.new()
	warm_root.name = "WebFeedbackWarmupGeometry"
	world._stage.add_child(warm_root)
	var canvas := CanvasLayer.new()
	canvas.name = "WebFeedbackWarmupCanvas"
	canvas.layer = 119
	world.add_child(canvas)
	var screen: Vector2 = world.get_viewport().get_visible_rect().size
	var mesh_count := 0
	for grade in range(5):
		var at := Vector3(float(grade-2)*.8,.14,-3.0)
		var outline_parent := Node3D.new()
		warm_root.add_child(outline_parent)
		outline_parent.position = at+world.camera.basis.z*world.PACK_VIEW_DEPTH
		outline_parent.basis = world._pack_face_basis(0.0)
		var outline: MeshInstance3D = world._preparation_feedback._outline(outline_parent,grade,Color("#9bc4ac"))
		# Keep generated StandardMaterial shaders referenced after the fixture
		# nodes are freed; otherwise their last owner can release the warm RID.
		world._web_feedback_warmup_materials.append(outline.material_override)
		mesh_count += 1
		for side in range(2):
			var half: MeshInstance3D = world._new_claim_torn(grade,side)
			warm_root.add_child(half)
			half.position = at+Vector3(0,0,-.9)+world.camera.basis.z*world.PACK_VIEW_DEPTH
			half.basis = world._pack_face_basis(0.0)
			mesh_count += 1
		var flyer := RewardFlyer.new()
		canvas.add_child(flyer)
		var origin := screen*Vector2(.3+float(grade)*.1,.48)
		flyer.configure(world.generic_card_texture(grade),origin,origin+Vector2(0,-40),grade,3,0,world._damage_font,false)
		flyer.advance(.08,false,false)
	var coin: MeshInstance3D = world._new_claim_coin()
	warm_root.add_child(coin)
	coin.position = Vector3(-.8,.2,-2.0)
	world._web_feedback_warmup_materials.append(coin.material_override)
	mesh_count += 1
	for index in range(2):
		var tint := Color(1.0,.85,.55,.65 if index==0 else .20)
		var glint: MeshInstance3D = world._new_claim_glint(.68,tint)
		warm_root.add_child(glint)
		glint.position = Vector3(float(index)*.8,.2,-2.0)
		world._web_feedback_warmup_materials.append(glint.material_override)
		mesh_count += 1
	# These use the actual production shaders/RIDs and retained GPU batches.
	# Geometry source nodes live in the isolated warm root and never enter the
	# World's live event/effect registry, feedback deduplication or reward pools.
	var effects: Array = []
	for element: String in ["E01","E02","E05"]:
		for kind: String in ["contact_spark","wrapper_fragment","wrapper_burst"]:
			var effect := SkillEffect.new()
			effect.batched = true
			effect.external_atlas = true
			warm_root.add_child(effect)
			effect.view_right = world.camera.basis.x
			effect.view_up = world.camera.basis.y
			effect.view_forward = world.camera.basis.z
			effect.configure({"kind":kind,"element":element,"pos":Vector2(0,300),"seed":1,"mote_count":7,"cosmetic_fragment":true},false)
			effect.advance(.04,false,false)
			effects.append(effect)
	world._refresh_skill_batches(effects)
	var batch_state: Dictionary = world._skill_atlas_batch.metrics()
	# Await real rendering, not only process frames or resource loading. The
	# opaque CanvasLayer masks already submitted geometry from the player.
	var rendered_frames := 0
	for index in range(2):
		await world.get_tree().process_frame
		await RenderingServer.frame_post_draw
		rendered_frames += 1
	world._refresh_skill_batches([])
	warm_root.free()
	canvas.free()
	world._pixel_display.visible = display_visible
	world._pixel_viewport.render_target_update_mode = update_mode
	world.set_process(was_processing)
	cover_layer.free()
	return {"enabled":true,"completed":rendered_frames==2,"rendered_frames":rendered_frames,
		"process_frames":Engine.get_process_frames()-start_frame,
		"elapsed_msec":float(Time.get_ticks_usec()-started)/1000.0,
		"mesh_instances":mesh_count,"reward_flyers":5,"effect_sources":effects.size(),
		"atlas_draw_calls":int(batch_state.get("draw_calls",0)),
		"atlas_instances":int(batch_state.get("visible_instances",0)),
		"retained_materials":world._web_feedback_warmup_materials.size(),
		"scopes":["gather_outline","five_grade_torn_halves","coin_glint","reward_flyer","contact_break_atlas_and_geometry"],
		"simulation_events_submitted":0,"audio_requests_submitted":0}
