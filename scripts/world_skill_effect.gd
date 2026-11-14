extends Node3D
## Presentation of committed geometry only. No target lookup, timing schedule, RNG or damage.
## Exact ground/path geometry + actual imported pixelfx sprites. No layer changes rule timing.
const Atlas = preload("res://scripts/world_fx_atlas.gd")
const Rules = preload("res://scripts/pack_rules.gd")
const TABLE_HALF_WIDTH_WORLD := Rules.TABLE_HALF_WIDTH*.01
const TABLE_DEPTH_WORLD := Rules.TABLE_DEPTH*.01
const QUAD_OFFSETS := [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
const CELL := 0.035
const HEIGHT := 0.075
const HERO_TIME := .095
const ELEMENT_ATLASES := {"E01":"heavy","E02":"lightning","E05":"frost"}
const ELEMENT_COLORS := {"E01":Color("#d69136"),"E02":Color("#32badc"),"E05":Color("#57b9d6")}
const ELEMENT_NAMES := {"heavy":"E01","lightning":"E02","ice":"E05","frost":"E05"}
const LEGACY_NATIVE_MIN_DURATION := {"E01":.46,"E02":.46,"E05":.60}
const TABLE_RIGHT := Vector3.RIGHT
const TABLE_UP := Vector3(0,0,-1)
var data: Dictionary = {}
var age := 0.0
var duration := 0.30
var reduced := false
var preview := false
var rendered_quads := 0
var accent_quads := 0
var front_quads := 0
var bright_peak := false
var layer_count := 0
var intensity := 1.0
var batched := false
var revision := 0
var ground_vertices := PackedVector3Array()
var ground_colors := PackedColorArray()
var front_vertices := PackedVector3Array()
var front_colors := PackedColorArray()
var visual_detail := 2
var allow_foreground := true
var allow_atlas := true
var external_atlas := false
var atlas_records: Array = []
var view_right := Vector3.RIGHT
var view_up := Vector3(0,.75,-.66).normalized()
var view_forward := Vector3(0,.66,.75).normalized()
var _mesh: ImmediateMesh
var _body: MeshInstance3D
var _front_mesh: ImmediateMesh
var _front_body: MeshInstance3D
var _burst: Sprite3D
var _atlas: Dictionary = {}
var atlas_key := ""
var atlas_visible := false
var _native_geo: RefCounted
var _last_visual_frame := -1
var _visual_dirty := false
var _visual_redraw_age := 0.0
var _p := Vector2.ZERO
var _u := Vector2.UP
var _radius := 0.0
var _primary_radius := 0.0
var _half_length := 0.0
var _color := Color.WHITE
var _alpha := 1.0
var _kind := "native"
var _element := "E01"
var _removed_element := false
# Actual burst geometry observations: populated only by _burst_wave drawing.
var burst_attack_level := ""
var burst_ring_radii: Array[float] = []
var burst_ring_quads: Array[int] = []
var burst_edge_sweep_quads := 0
var burst_edge_sweep_points := PackedVector2Array()

static func attack_level(event: Dictionary) -> String:
	# Fever availability/energy is never an attack. Only this committed attack's
	# kind and scope may promote its shape; an ordinary open stays ordinary.
	if str(event.get("attack_kind","circle_open"))!="fever": return "circle"
	var global_scope := bool(event.get("global",event.get("global_burst",event.get("fever_full_cast",false))))
	var full_cast := bool(event.get("global_burst",event.get("fever_full_cast",global_scope)))
	return "fever_full" if global_scope and full_cast else "fever_low"

static func point(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size()>=2:
		return Vector2(float(value[0]),float(value[1]))
	return fallback

static func element_id(value: Variant) -> String:
	var id_value := str(value)
	return str(ELEMENT_NAMES.get(id_value,id_value)) if not id_value.is_empty() else "E01"

func _ready() -> void:
	if batched:
		return
	# Batched effects export packed arrays and never use individual Mesh RIDs.
	_mesh = ImmediateMesh.new()
	_front_mesh = ImmediateMesh.new()
	_body = MeshInstance3D.new()
	_body.name = "NativePixelGeometry"
	_body.mesh = _mesh
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -58
	_body.material_override = mat
	add_child(_body)
	_front_body = MeshInstance3D.new()
	_front_body.name = "ElementHeroPixels"
	_front_body.mesh = _front_mesh
	_front_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var front_mat: StandardMaterial3D = mat.duplicate()
	front_mat.render_priority = 48
	_front_body.material_override = front_mat
	add_child(_front_body)

func configure(event: Dictionary, quiet: bool, is_preview: bool = false, defer_visual: bool = false) -> void:
	data = event.duplicate(true)
	reduced = quiet
	preview = is_preview
	if is_instance_valid(_body):
		var preview_material: StandardMaterial3D = _body.material_override
		preview_material.no_depth_test = preview
		preview_material.render_priority = 90 if preview else -58
	_kind = str(data.get("kind","native"))
	_element = element_id(data.get("element","E01"))
	_removed_element = not ELEMENT_ATLASES.has(_element)
	if _removed_element:
		visible = false
		age = 0.0
		duration = 0.0
		_atlas = {}
		atlas_key = ""
		atlas_visible = false
		atlas_records.clear()
		ground_vertices.clear()
		ground_colors.clear()
		front_vertices.clear()
		front_colors.clear()
		rendered_quads = 0
		front_quads = 0
		accent_quads = 0
		layer_count = 0
		bright_peak = false
		_visual_dirty = false
		revision += 1
		if not preview: queue_free()
		return
	_color = ELEMENT_COLORS.get(_element,ELEMENT_COLORS.E01)
	_p = point(data.get("corrected_pos",data.get("pos",Vector2.ZERO)))*.01
	_u = point(data.get("direction",data.get("u",Vector2.UP)),Vector2.UP).normalized()
	if _u.is_zero_approx():
		_u = Vector2.UP
	_radius = maxf(0.0,float(data.get("radius",float(data.get("width",0.0))*.5)))*.01
	_half_length = maxf(0.0,float(data.get("length",0.0)))*.005
	if str(data.get("shape","circle"))=="capsule" and data.has("width"):
		_radius = maxf(0.0,float(data.width))*.005
	_primary_radius = minf(_radius,maxf(0.0,float(data.get("primary_radius",_radius*100.0))*.01)) if _kind=="native" else _radius
	duration = .56 if _kind in ["echo","aftershock","bond_wave","extra_wave"] else .46
	if _kind=="native" and int(data.get("pulse_index",0))>0:
		duration = .36
	if _kind in ["contact_spark","wrapper_fragment"]:
		duration = .34
	if _kind=="wrapper_burst": duration = .42
	if _kind=="burst_wave":
		duration = .36
		burst_attack_level = attack_level(data)
		_color = Color("#d2dfca") if burst_attack_level=="circle" else Color("#ffd36c")
	intensity = 1.0+minf(.36,maxf(0.0,float(data.get("branch_count",1))-1.0)*.12)+minf(.20,float(data.get("spread_bonus",0))*.003)
	if _kind in ["chain","aftershock","bond_wave","extra_wave"]:
		intensity += .18
	if preview:
		age = 0.0
	_prepare_atlas()
	_request_visual_redraw(defer_visual)

func _prepare_atlas() -> void:
	_atlas = {}
	atlas_key = ""
	if preview:
		return
	match _kind:
		"echo": atlas_key = "echo_"+_element
		"aftershock", "bond_wave", "extra_wave": atlas_key = "aftershock_"+_element
		"native": atlas_key = "pulse_"+_element if int(data.get("pulse_index",0))>0 else str(ELEMENT_ATLASES.get(_element,"heavy"))
		"chain", "penetration", "pull": atlas_key = _kind+"_"+_element
		"contact_spark": atlas_key = "contact_"+_element
		"bond": atlas_key = "bond_"+_element
		"wrapper_burst": atlas_key = "break"
		_: return
	_atlas = Atlas.sheet(atlas_key)
	if not _atlas.is_empty() and _kind=="native" and int(data.get("pulse_index",0))==0:
		# Freeze the OLD final native lifetime, including frost's former eighteen-frame
		# minimum. A longer source sheet is visual data, never a new attack/event clock.
		duration = maxf(duration,float(LEGACY_NATIVE_MIN_DURATION.get(_element,duration)))

func _setup_burst() -> void:
	if external_atlas or _atlas.is_empty() or is_instance_valid(_burst) or reduced or not allow_atlas:
		return
	_burst = Sprite3D.new()
	_burst.name = "Pixelfx_"+atlas_key
	Atlas.configure_3d(_burst,_atlas)
	_burst.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var is_topdown := bool(_atlas.get("topdown",false))
	_burst.basis = Basis(TABLE_RIGHT,TABLE_UP,Vector3.UP) if is_topdown else Basis(view_right,view_up,view_forward)
	# Registered sheet pivots stay exactly on the committed impact, including directional beams.
	# The full source frame is intentionally kept: transparent margins do not shift the origin.
	var footprint := maxf(_radius*1.65,.82)*minf(intensity,1.35)
	var source_extent := maxf(32.0,float(maxi(_atlas.size.x,_atlas.size.y)))
	_burst.pixel_size = clampf(footprint/source_extent,.008,.024)
	if _kind=="chain":
		_burst.pixel_size *= .62
	_burst.position = Vector3(_p.x,HEIGHT,-_p.y)+(Vector3.ZERO if is_topdown else view_forward*.74)
	if is_topdown:
		_burst.pixel_size = _topdown_scale(_atlas,_primary_radius if _kind=="native" else _radius)
	add_child(_burst)

func advance(delta: float, frozen: bool, quiet: bool, defer_visual: bool = false) -> void:
	if _removed_element: return
	var changed := reduced!=quiet
	reduced = quiet
	if not frozen:
		age += delta
	if not preview and age>=duration:
		queue_free()
		return
	if (not frozen and int(age*30.0)!=_last_visual_frame) or changed:
		_request_visual_redraw(defer_visual)

func set_visual_budget(detail: int, foreground: bool, atlas: bool, defer_visual: bool = false) -> void:
	if visual_detail==detail and allow_foreground==foreground and allow_atlas==atlas:
		return
	visual_detail = detail
	allow_foreground = foreground
	allow_atlas = atlas
	_request_visual_redraw(defer_visual)

func _request_visual_redraw(deferred: bool) -> void:
	if _removed_element: return
	if not batched and not is_instance_valid(_body):
		_redraw()
		return
	_visual_dirty = true
	_visual_redraw_age = age
	# Atlas allocation retains the original request order even when geometry is delayed.
	_setup_burst()
	_last_visual_frame = int(age*30.0)
	# Budget sorting sees exactly the state the old immediate redraw would expose.
	bright_peak = not reduced and not preview and age<HERO_TIME and _kind not in ["pull","focus","mark_transfer","burst_wave"] and not (_kind=="native" and int(data.get("pulse_index",0))>0)
	if not deferred:
		_redraw()

func flush_visual() -> void:
	if not _visual_dirty or is_queued_for_deletion():
		return
	# A configure at age zero may retain that geometry on the first sub-30Hz frame.
	# Replay the last actual redraw request age, rather than advancing its appearance.
	var current_age := age
	age = _visual_redraw_age
	_redraw()
	age = current_age

func _redraw() -> void:
	_visual_dirty = false
	if not batched and not is_instance_valid(_body):
		return
	if not batched:
		_mesh.clear_surfaces()
		_front_mesh.clear_surfaces()
	revision += 1
	rendered_quads = 0
	accent_quads = 0
	front_quads = 0
	atlas_visible = false
	layer_count = 1
	bright_peak = not reduced and not preview and age<HERO_TIME and _kind not in ["pull","focus","mark_transfer","burst_wave"] and not (_kind=="native" and int(data.get("pulse_index",0))>0)
	_last_visual_frame = int(age*30.0)
	_alpha = .64 if preview else clampf((1.0-age/duration)*(.92 if age<.12 else .65),.0,1.0)
	if reduced:
		_alpha *= .65
	elif _kind=="native" and int(data.get("pulse_index",0))>0:
		_alpha *= .67
	var library_primary := not preview and not _atlas.is_empty() and not reduced
	if not library_primary and batched and _native_geo==null and ClassDB.class_exists("RoundCardGeometryMath"):
		_native_geo = ClassDB.instantiate("RoundCardGeometryMath")
	if not library_primary and batched and _native_geo!=null:
		_native_geo.reset(_alpha,preview,_p,view_right,view_up,view_forward)
	if library_primary:
		# Imported animation replaces the former procedural artwork for this event.
		# Every event remains live at its committed position and original lifetime.
		pass
	elif _kind=="burst_wave":
		_burst_wave()
	elif _kind in ["contact_spark","wrapper_fragment"]:
		if not reduced:
			_fragment_motes()
	elif _kind in ["focus","focus_snap"]:
		_focus()
	elif _kind in ["pull","mark_transfer","penetration"]:
		_path(_kind)
	elif _kind=="bond":
		_bond()
	else:
		_footprint()
		if _kind=="chain":
			_path("chain")
		if data.has("extension"):
			_penetration()
		if not reduced and not preview:
			_branch_trajectory()
		if int(data.get("branch_count",1))>1 and not preview:
			var angle := float(int(data.get("branch_id",0))%int(data.branch_count))*TAU/float(data.branch_count)
			var direction := Vector2.from_angle(angle)
			_segment(_p+direction*.065,_p+direction*.115,_color,false,.7)
		if not reduced and not preview and visual_detail>0:
			var before := rendered_quads
			if visual_detail>1:
				_accents()
			_power_layers()
			accent_quads = rendered_quads-before
		if not reduced and not preview and allow_foreground:
			_hero()
		if preview:
			_core()
	# Reuse prior PackedArray storage; each quad overwrites six slots, then trims only once.
	if not library_primary and batched and _native_geo!=null:
		# Release this effect's previous references before the native writable access.
		# Other consumers retaining a prior frame are protected by PackedArray COW.
		ground_vertices = PackedVector3Array()
		ground_colors = PackedColorArray()
		front_vertices = PackedVector3Array()
		front_colors = PackedColorArray()
		var arrays: Array = _native_geo.finish()
		ground_vertices = arrays[0]
		ground_colors = arrays[1]
		front_vertices = arrays[2]
		front_colors = arrays[3]
	elif batched:
		ground_vertices.resize(rendered_quads*6)
		ground_colors.resize(rendered_quads*6)
		front_vertices.resize(front_quads*6)
		front_colors.resize(front_quads*6)
	if rendered_quads>0 and not batched:
		_mesh.surface_end()
	if front_quads>0:
		if not batched:
			_front_mesh.surface_end()
		layer_count += 1
	_setup_burst()
	atlas_records.clear()
	if library_primary:
		_build_atlas_records()
		atlas_visible = not atlas_records.is_empty()
		if external_atlas:
			layer_count += atlas_records.size()
	if is_instance_valid(_burst):
		if bool(_atlas.get("topdown",false)):
			_burst.frame = clampi(floori(age/duration*float(_atlas.frames)),0,int(_atlas.frames)-1)
			_burst.visible = not reduced and allow_atlas and age<duration
		else:
			Atlas.apply_3d(_burst,_atlas,age,not reduced and allow_atlas,.90 if _kind!="echo" else .73)
		atlas_visible = _burst.visible
		if atlas_visible:
			layer_count += 1

func _burst_wave() -> void:
	# These are outlines, never filled discs. Full has two edges of ONE committed
	# hit and one bounded perimeter sweep; none of the travel schedules damage.
	burst_ring_radii.clear()
	burst_ring_quads.clear()
	burst_edge_sweep_quads = 0
	burst_edge_sweep_points.clear()
	var t := clampf(age/duration,0.0,1.0)
	var reach := maxf(.08,_radius*(.06+.94*(1.0-pow(1.0-t,2.0))))
	if reduced: reach = _radius*.88
	var full := burst_attack_level=="fever_full"
	var thickness := .016 if burst_attack_level=="circle" else .025
	_draw_burst_ring(reach,_color,thickness)
	if full:
		# A real gap survives at the first visible frame and in static reduced mode.
		var inner := reach*(.81 if reduced else .82)
		_draw_burst_ring(inner,Color("#fff1c4"),.018)
		layer_count += 1
		if not reduced: _burst_edge_sweep(t)

func _draw_burst_ring(reach: float, tone: Color, thickness: float) -> void:
	var before := rendered_quads
	var count := clampi(ceili(TAU*reach/.036),16,1400)
	for index in range(count):
		var direction := Vector2.from_angle(float(index)*TAU/float(count))
		_pixel(_p+direction*reach,tone,thickness)
	burst_ring_radii.append(reach)
	burst_ring_quads.append(rendered_quads-before)

func _burst_edge_sweep(t: float) -> void:
	# Sweep once clockwise around the tabletop, entirely inside its outer edge.
	# This is neither the persistent Fever frame nor the removed footer effect.
	var inset := .08
	var width := TABLE_HALF_WIDTH_WORLD*2.0-inset*2.0
	var depth := TABLE_DEPTH_WORLD-inset*2.0
	var perimeter := (width+depth)*2.0
	var head := t*perimeter
	var length_value := minf(2.6,perimeter*.10)
	var before := rendered_quads
	for index in range(65):
		var distance := head-float(index)/64.0*length_value
		if distance<0.0: continue
		var at := fposmod(distance,perimeter)
		var point_value := Vector2(-TABLE_HALF_WIDTH_WORLD+inset,inset)
		if at<width: point_value.x += at
		elif at<width+depth: point_value += Vector2(width,at-width)
		elif at<width*2.0+depth: point_value += Vector2(width-(at-width-depth),depth)
		else: point_value.y += depth-(at-width*2.0-depth)
		burst_edge_sweep_points.append(point_value)
		_pixel(point_value,Color("#fff1c4"),lerpf(.014,.036,1.0-float(index)/64.0))
	burst_edge_sweep_quads = rendered_quads-before

func _build_atlas_records() -> void:
	if age>=duration:
		return
	var is_topdown := bool(_atlas.get("topdown",false))
	var center := Vector3(_p.x,HEIGHT,-_p.y)+(Vector3.ZERO if is_topdown else view_forward*.74)
	var extent := maxf(_radius*1.9,.90)*minf(intensity,1.35)
	var scale_value := clampf(extent/float(maxi(_atlas.size.x,_atlas.size.y)),.008,.030)
	if is_topdown: scale_value = _topdown_scale(_atlas,_primary_radius if _kind=="native" else _radius)
	if _kind=="contact_spark": scale_value = .007 if is_topdown else .009
	if _kind=="wrapper_burst":
		center = data.get("visual_center",center)+(Vector3.ZERO if is_topdown else view_forward*.74)
		scale_value = float(data.visual_pixel_size)
	if _kind in ["chain","penetration","pull"]:
		_append_path_record(_atlas,point(data.get("from",data.get("pos",Vector2.ZERO)))*.01,point(data.get("to",data.get("corrected_pos",data.get("pos",Vector2.ZERO))))*.01)
		if _kind=="chain":
			# The authored propagation ribbon reaches the real target; elemental impact
			# keeps elemental chains distinct from an all-lightning build.
			var impact := Atlas.sheet(str(ELEMENT_ATLASES.get(_element,"heavy")))
			if not impact.is_empty():
				var impact_topdown := bool(impact.get("topdown",false))
				var impact_scale := _topdown_scale(impact,_radius)*.70 if impact_topdown else scale_value*.7
				_append_atlas_record(impact,center,TABLE_RIGHT if impact_topdown else view_right,TABLE_UP if impact_topdown else view_up,impact_scale)
	else:
		var across := TABLE_RIGHT if is_topdown else view_right
		var up := TABLE_UP if is_topdown else view_up
		if is_topdown and _half_length>0 and _radius>0:
			across = Vector3(_u.x,0,-_u.y)*(1.0+_half_length/maxf(_primary_radius if _kind=="native" else _radius,.001))
			up = Vector3(-_u.y,0,-_u.x)
		_append_atlas_record(_atlas,center,across,up,scale_value)
	if is_topdown and _kind=="native" and _radius>_primary_radius+.00001:
		var coverage := Atlas.sheet("coverage_"+_element)
		if not coverage.is_empty():
			var across := TABLE_RIGHT
			var up := TABLE_UP
			if _half_length>0 and _radius>0:
				across = Vector3(_u.x,0,-_u.y)*(1.0+_half_length/_radius)
				up = Vector3(-_u.y,0,-_u.x)
			_append_atlas_record(coverage,center,across,up,_topdown_scale(coverage,_radius),.55)
	if data.has("extension"):
		var extension: Dictionary = data.extension
		_append_path_record(Atlas.sheet("penetration_"+_element),point(extension.get("from",data.pos))*.01,point(extension.get("to",data.pos))*.01)

func _topdown_scale(sheet_value: Dictionary, radius_value: float) -> float:
	# Registration follows the committed radius; branch-count intensity must not
	# enlarge the new capped core or suggest a larger C01 damage-coverage boundary.
	return maxf(.04,radius_value)/maxf(1.0,float(sheet_value.get("visual_radius_px",76.0)))*float(sheet_value.get("visual_gain",1.0))

func _append_atlas_record(sheet_value: Dictionary, center: Vector3, across: Vector3, up: Vector3, scale_value: float, opacity: float = .96) -> void:
	var frame := clampi(floori(age/duration*float(sheet_value.frames)),0,int(sheet_value.frames)-1)
	atlas_records.append({"sheet":sheet_value,"frame":frame,"center":center,"right":across,"up":up,"pixel_size":scale_value,"opacity":opacity,"plane":&"impact","no_depth_test":true})

func _append_path_record(sheet_value: Dictionary, start: Vector2, finish: Vector2) -> void:
	if sheet_value.is_empty():
		return
	if start.distance_squared_to(finish)<.0001:
		if _kind=="pull":
			# A pack already at the convergence point still has a real pull event.
			# Show its local authored condensation, without inventing a long trajectory.
			var compact_scale := .0025
			var is_topdown := bool(sheet_value.get("topdown",false))
			var across := TABLE_RIGHT if is_topdown else view_right
			var up := TABLE_UP if is_topdown else view_up
			var anchor := Vector3(finish.x,HEIGHT,-finish.y)+(Vector3.ZERO if is_topdown else view_forward*.74)
			anchor -= across*(float(sheet_value.size.x)-float(sheet_value.pivot.x)*2.0)*compact_scale
			_append_atlas_record(sheet_value,anchor,across,up,compact_scale)
		return
	var delta := Vector3(finish.x-start.x,0,start.y-finish.y)
	if bool(sheet_value.get("topdown",false)):
		var length_value := delta.length()
		if length_value<.000001: return
		var across := delta/length_value
		var up := Vector3(across.z,0,-across.x)
		var width := maxf(1.0,float(sheet_value.size.x)-float(sheet_value.pivot.x)*2.0)
		var scale_value := .010
		_append_atlas_record(sheet_value,Vector3(start.x,HEIGHT,-start.y),across*(length_value/(width*scale_value)),up,scale_value)
		return
	var projected := Vector2(delta.dot(view_right),delta.dot(view_up))
	var distance := projected.length()
	if distance<.001: return
	var direction := projected/distance
	var across := view_right*direction.x+view_up*direction.y
	var up := -view_right*direction.y+view_up*direction.x
	var origin := Vector3(start.x,HEIGHT,-start.y)+view_forward*.74
	# Registered combat11 ribbons reserve the same 12px clear padding at both ends.
	var padding := float(sheet_value.pivot.x)
	var width := maxf(1.0,float(sheet_value.size.x)-padding*2.0)
	# X alone stretches to the committed segment. Y keeps an authored readable
	# thickness, so short chain hops cannot collapse into a one-pixel square.
	var scale_value := .010
	_append_atlas_record(sheet_value,origin,across*(distance/(width*scale_value)),up,scale_value)

func _power_layers() -> void:
	var t := clampf(age/duration,0,1)
	var blast := 1.0-pow(1.0-clampf(age/.25,0,1),3)
	var r := maxf(.14,_radius)
	layer_count += 1
	if float(data.get("spread_bonus",0))>0 and _radius>0:
		_element_crown(r*(.35+blast*.65),t,blast)
		_arc(_p,r*.93,age*4.0,PI*.72,_color.darkened(.12),false,.8)
	if _kind=="echo":
		for i in range(2):
			_arc(_p,r*(.72+float(i)*.14),float(i)*PI+age*2.0,PI*.8,Color("#91cdb8"),true,1.15)
		_star(_p,.16*(1-t),_color.lightened(.4),4)
	elif _kind in ["aftershock","bond_wave","extra_wave"]:
		_element_crown(r*blast,t,blast)
		_arc(_p,r*maxf(.15,blast-.19),0,TAU,_color.darkened(.14),true,.75)
		for i in range(14):
			var direction := Vector2.from_angle(float(i)*TAU/14.0+.2)
			_segment(_p+direction*r*(.38+blast*.3),_p+direction*r*(.52+blast*.48),_color.lightened(.18),false,1.0)
	elif _kind=="chain":
		_star(_p,minf(.28,.15*intensity)*(1-t*.7),_color.lightened(.6),6)
		_arc(_p,maxf(.10,r)*blast,0,TAU,_color,false,1.15)
	if _kind in ["native","echo"] and visual_detail>1:
		for i in range(10 if _element in ["E01","E05"] else 6):
			var angle := float(i)*2.39996+float(int(data.get("event_id",0))%7)*.22
			var direction := Vector2.from_angle(angle)
			var distance := r*(.22+blast*.72)
			var at := _p+direction*distance
			_segment(at-direction*.11*(1-t),at,_color.lightened(.38),false,.8)

func _element_crown(radius: float, t: float, blast: float) -> void:
	# Every committed wave still gets its own growing crown. Elemental silhouettes
	# replace the repeated white discs; coverage, event count and timing stay intact.
	var ink := _color.darkened(.28)
	for i in range(8):
		var angle := float(i)*TAU/8.0+float(int(data.get("event_id",0))%7)*.09
		var direction := Vector2.from_angle(angle)
		var side := Vector2(-direction.y,direction.x)
		var at := _p+direction*radius
		match _element:
			"E02":
				var elbow := at-direction*.09+side*.045*(1-t)
				_segment(at-direction*.18,elbow,ink,false,.9)
				_segment(elbow,at,_color,false,.75)
			"E05":
				_segment(at-direction*.12-side*.045,at+direction*.07,ink,false,.85)
				_segment(at+direction*.07,at-direction*.12+side*.045,_color,false,.75)
			_:
				_segment(at-direction*.11,at,ink,false,1.0)
				_segment(at,at+side*.065,_color,false,.85)

func _branch_trajectory() -> void:
	if _kind!="native" or int(data.get("branch_count",1))<=1 or int(data.get("pulse_index",0))>0:
		return
	var origin := Vector2(0,.2)
	var direction := (_p-origin).normalized()
	var side := Vector2(-direction.y,direction.x)
	_segment(origin,_p,_color,true,1.1)
	_segment(_p-direction*.5+side*.05,_p,_color.lightened(.4),false,.85)

func _star(center: Vector2, radius: float, color: Color, rays: int = 6) -> void:
	for i in range(rays):
		var direction := Vector2.from_angle(float(i)*TAU/float(rays)+.25)
		_segment(center+direction*radius*.25,center+direction*radius,color,false,1.05)

func _hero() -> void:
	var t := clampf(age/duration,0,1)
	var hot := pow(maxf(0.0,1.0-age/.22),.75)
	var r := clampf(_radius*.50,.15,.55)*minf(intensity,1.5)
	var white := Color("#d9fcff") if _element in ["E02","E05"] else Color("#fff6d8")
	var fade := _alpha
	if _kind in ["echo"]:
		_alpha *= .65
		for i in range(3):
			_front_arc(Vector2(0,float(i)*.045),r*(.4+float(i)*.2),age*3.0+float(i),PI*1.45,_color.lightened(.25),.022)
		_alpha = fade
		return
	if _kind in ["aftershock","bond_wave","extra_wave"]:
		_hero_star(r*.9*hot,white,8)
		_front_arc(Vector2.ZERO,r*(.4+clampf(age/.22,0,1)),0,TAU,_color.lightened(.3),.035*(1-t))
		return
	if _kind=="chain":
		_hero_star(.22*hot*intensity,white,6)
		return
	if _kind!="native":
		return
	if int(data.get("pulse_index",0))>0:
		return
	# The authored sheet owns the elemental silhouette. A very short contact core supports it;
	# duplicating it with procedural flames/tornadoes/beams would obscure the actual animation.
	if age<HERO_TIME:
		var contact := 1.0-age/HERO_TIME
		_hero_star(r*.64*contact,_color,4)
		_hero_star(r*.36*contact,white,4)

func _hero_star(radius: float, color: Color, rays: int) -> void:
	for i in range(rays):
		var direction := Vector2.from_angle(float(i)*TAU/float(rays)+.24)
		_front_segment(direction*radius*.1,direction*radius,color,.028 if i%2 else .042)

func _fragment_motes() -> void:
	var count := int(data.get("mote_count",3))
	var t := clampf(age/duration,0,1)
	var seed_value := float(data.get("seed",0))
	var colors: Array[Color] = [Color("#eee1ba"),Color("#62a38e"),Color("#a987d4"),Color("#ffd58a"),Color("#f38c73")]
	for i in range(count):
		var angle := float(i)*2.39996+seed_value*.47
		var direction := Vector2.from_angle(angle)
		var distance := (1.0-pow(1.0-t,2))*(.25+float(i%3)*.10)
		var at := direction*distance+Vector2(0,sin(t*PI)*(.12+float(i%3)*.05))
		var color := colors[i%5] if count>3 else Color("#fff2cf")
		var size_value := (.021+float(i%2)*.008)*(1.0-floorf(smoothstep(.4,1,t)*4.0)/4.0)
		if size_value>.002:
			_front_pixel(at,color,size_value)

func _front_arc(center: Vector2, radius: float, start: float, sweep: float, color: Color, thickness: float) -> void:
	if batched and _native_geo!=null:
		front_quads = _native_geo.front_arc(center,radius,start,sweep,color,thickness,_alpha)
		return
	if radius<.015 or thickness<.002:
		return
	var count := clampi(ceili(radius*sweep/.045),8,80)
	for i in range(count+1):
		_front_pixel(center+Vector2.from_angle(start+float(i)/count*sweep)*radius,color,thickness)

func _front_segment(start: Vector2, finish: Vector2, color: Color, thickness: float) -> void:
	if batched and _native_geo!=null:
		front_quads = _native_geo.front_segment(start,finish,color,thickness,_alpha)
		return
	if thickness<.002:
		return
	var count := clampi(ceili(start.distance_to(finish)/.035),1,80)
	for i in range(count+1):
		_front_pixel(start.lerp(finish,float(i)/count),color,thickness)

func _front_pixel(at: Vector2, color: Color, half_size: float) -> void:
	if batched and _native_geo!=null:
		front_quads = _native_geo.front_pixel(at,color,half_size,_alpha)
		return
	at = at.snapped(Vector2.ONE*.025)
	if _p.x< -TABLE_HALF_WIDTH_WORLD or _p.x>TABLE_HALF_WIDTH_WORLD or _p.y<0 or _p.y>TABLE_DEPTH_WORLD:
		return
	if front_quads==0 and not batched:
		_front_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	color.a = _alpha*minf(1.0,color.a)
	var center := Vector3(_p.x,HEIGHT,-_p.y)+view_forward*.76+view_right*at.x+view_up*at.y
	if batched:
		var first := front_quads*6
		if front_vertices.size()<first+6:
			var capacity := maxi(first+6,maxi(192,front_vertices.size()*2))
			front_vertices.resize(capacity)
			front_colors.resize(capacity)
		var across := view_right*half_size
		var up := view_up*half_size
		var a := center-across-up
		var b := center+across-up
		var c := center-across+up
		var d := center+across+up
		front_vertices[first] = a
		front_vertices[first+1] = b
		front_vertices[first+2] = c
		front_vertices[first+3] = b
		front_vertices[first+4] = d
		front_vertices[first+5] = c
		front_colors[first] = color
		front_colors[first+1] = color
		front_colors[first+2] = color
		front_colors[first+3] = color
		front_colors[first+4] = color
		front_colors[first+5] = color
	else:
		for offset in QUAD_OFFSETS:
			var vertex: Vector3 = center+view_right*offset.x*half_size+view_up*offset.y*half_size
			_front_mesh.surface_set_color(color)
			_front_mesh.surface_add_vertex(vertex)
	front_quads += 1

func _footprint() -> void:
	var shape := str(data.get("shape","circle"))
	var dashed := _kind=="echo"
	var footprint_color := _color if preview else _color.darkened(.24)
	if dashed:
		footprint_color = footprint_color.lerp(Color("#68a58e"),.45)
	if shape in ["capsule","line"]:
		var side := Vector2(-_u.y,_u.x)
		for sign_value in [-1.0,1.0]:
			_segment(_p-_u*_half_length+side*_radius*sign_value,_p+_u*_half_length+side*_radius*sign_value,footprint_color,dashed)
		for end in [-1.0,1.0]:
			var center: Vector2 = _p+_u*_half_length*float(end)
			var base_angle := _u.angle() if end>0 else _u.angle()+PI
			_arc(center,_radius,base_angle-PI*.5,PI,footprint_color,dashed)
	else:
		_arc(_p,_radius,0,TAU,footprint_color,dashed)
	if _kind in ["aftershock","bond_wave","extra_wave"] and not reduced:
		_arc(_p,_radius*clampf(age/duration,.15,.93),0,TAU,_color,true)
	if preview:
		var progress := clampf(float(data.get("progress",0.0)),0.0,1.0)
		if shape in ["capsule","line"]:
			_segment(_p-_u*_half_length,_p-_u*_half_length+_u*(_half_length*2.0*progress),_color,false,.65)
		elif progress>0.0:
			_arc(_p,_radius*.91,-PI*.5,TAU*progress,_color,false)

func _core() -> void:
	var r := maxf(.035,float(data.get("focus_radius",0.0))*.01)
	var ink := Color("#31554e")
	if data.get("focus_radius",0.0)>0.0:
		_arc(_p,r,0,TAU,ink,true)
	_pixel(_p,ink,CELL*.45)

func _focus() -> void:
	var source := point(data.get("from",data.get("original_pos",data.get("pos",Vector2.ZERO))))*.01
	_segment(source,_p,Color("#68a58e"),true,.45)
	var r := maxf(.06,_radius)
	for corner in range(4):
		var offset := Vector2(1 if corner%2 else -1,1 if corner>=2 else -1)
		var at := _p+offset*r
		_segment(at,at-Vector2(offset.x*.045,0),_color)
		_segment(at,at-Vector2(0,offset.y*.045),_color)

func _path(kind: String) -> void:
	var source := point(data.get("from",data.get("pos",Vector2.ZERO)))*.01
	var finish := point(data.get("to",data.get("pos",Vector2.ZERO)))*.01
	var delta := finish-source
	if delta.length()<.01:
		return
	var normal := Vector2(-delta.y,delta.x).normalized()
	if kind=="chain":
		if _element!="E02":
			# Elemental propagation is a dotted contact path. Only lightning uses electric zigzags.
			_segment(source,finish,_color,true,.78)
			return
		var count := maxi(3,ceili(delta.length()/.10))
		var previous := source
		for i in range(1,count+1):
			var at := source+delta*(float(i)/count)
			if i<count and not reduced:
				at += normal*(.035 if i%2 else -.035)
			_segment(previous,at,_color,false,1.65 if not reduced else .78)
			if not reduced:
				_segment(previous,at,Color("#fff2cf"),false,.65)
			previous = at
	elif kind=="penetration":
		_segment(source,finish,_color,true,.70)
		var direction := delta.normalized()
		_segment(finish,finish-direction*.10+normal*.06,_color)
		_segment(finish,finish-direction*.10-normal*.06,_color)
	else:
		_segment(source,finish,Color("#68a58e"),true,.65)
		if not reduced:
			for i in range(4):
				var slide := fmod(age/duration+float(i)*.23,1.0)
				var at := source.lerp(finish,slide)
				_segment(at-delta.normalized()*.07,at,_color.lightened(.35),false,1.0)

func _bond() -> void:
	# A small four-corner cue names a committed bond; it does not add another attack footprint.
	for i in range(4):
		var angle := PI*.25+i*PI*.5
		var direction := Vector2(cos(angle),sin(angle))
		_segment(_p+direction*.08,_p+direction*.16,_color,false,.75)

func _penetration() -> void:
	var extension: Dictionary = data.extension
	var start := point(extension.get("from",data.get("pos",Vector2.ZERO)))*.01
	var finish := point(extension.get("to",data.get("pos",Vector2.ZERO)))*.01
	var direction := (finish-start).normalized()
	var side := Vector2(-direction.y,direction.x)*float(extension.get("width",0.0))*.005
	_segment(start+side,finish+side,_color,true,.45)
	_segment(start-side,finish-side,_color,true,.45)
	for target in data.get("penetration_hits",[]):
		var at := point(target.get("pos",Vector2.ZERO))*.01
		_segment(at-side*.35,at+side*.35,_color,false,.8)

func _accents() -> void:
	var phase := floorf(age*16.0)/16.0
	var r := minf(_radius,.72)
	if _kind=="echo":
		for sign_value in [-1.0,1.0]:
			_segment(_p+Vector2(sign_value*r*.5,-.045),_p+Vector2(sign_value*r*.5,.045),_color)
		return
	if _kind in ["aftershock","bond_wave","extra_wave"]:
		return
	match _element:
		"E01":
			for i in range(6):
				var direction := Vector2.from_angle(float(i)*TAU/6.0)
				_pixel(_p+direction*(.10+phase*1.6),_color,CELL*(1.0-age/duration*.5))
		"E02":
			var previous := _p+Vector2(0,r*.75)
			for offset in [Vector2(-.07,.03),Vector2(.06,-.02),Vector2(0,-r*.75)]:
				_segment(previous,_p+offset,_color,false,1.0)
				previous = _p+offset
		"E05":
			for i in range(6):
				var direction := Vector2.from_angle(float(i)*TAU/6.0)
				var at := _p+direction*r*.5
				_segment(at-direction*.045,at+direction*.075,_color)
				_pixel(at,Color("#eee7c7"),CELL*.65)
func _arc(center: Vector2, radius: float, start: float, sweep: float, color: Color, dashed: bool = false, size_scale: float = .58) -> void:
	if batched and _native_geo!=null:
		rendered_quads = _native_geo.arc(center,radius,start,sweep,color,dashed,size_scale)
		return
	if radius<=.001 or sweep<=.001:
		return
	var count := clampi(ceili(sweep*radius/CELL),8,192)
	for i in range(count+1):
		if dashed and i%4>=2:
			continue
		var angle := start+sweep*float(i)/float(count)
		_pixel(center+Vector2.from_angle(angle)*radius,color,CELL*size_scale)

func _segment(start: Vector2, finish: Vector2, color: Color, dashed: bool = false, size_scale: float = .65) -> void:
	if batched and _native_geo!=null:
		rendered_quads = _native_geo.segment(start,finish,color,dashed,size_scale)
		return
	var count := clampi(ceili(start.distance_to(finish)/CELL),1,160)
	for i in range(count+1):
		if dashed and i%4>=2:
			continue
		_pixel(start.lerp(finish,float(i)/float(count)),color,CELL*size_scale)

func _pixel(at: Vector2, color: Color, half_size: float) -> void:
	if batched and _native_geo!=null:
		rendered_quads = _native_geo.pixel(at,color,half_size)
		return
	# Clip whole quads rather than moving geometry back inside the rule board.
	at = at.snapped(Vector2.ONE*CELL)
	if at.x-half_size< -TABLE_HALF_WIDTH_WORLD or at.x+half_size>TABLE_HALF_WIDTH_WORLD or at.y-half_size<0.0 or at.y+half_size>TABLE_DEPTH_WORLD:
		return
	color.a = _alpha*(.75 if preview else .9)
	var p := Vector3(at.x,HEIGHT,-at.y)
	if rendered_quads==0 and not batched:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if batched:
		var first := rendered_quads*6
		if ground_vertices.size()<first+6:
			var capacity := maxi(first+6,maxi(768,ground_vertices.size()*2))
			ground_vertices.resize(capacity)
			ground_colors.resize(capacity)
		var a := p+Vector3(-half_size,0,-half_size)
		var b := p+Vector3(half_size,0,-half_size)
		var c := p+Vector3(-half_size,0,half_size)
		var d := p+Vector3(half_size,0,half_size)
		ground_vertices[first] = a
		ground_vertices[first+1] = b
		ground_vertices[first+2] = c
		ground_vertices[first+3] = b
		ground_vertices[first+4] = d
		ground_vertices[first+5] = c
		ground_colors[first] = color
		ground_colors[first+1] = color
		ground_colors[first+2] = color
		ground_colors[first+3] = color
		ground_colors[first+4] = color
		ground_colors[first+5] = color
	else:
		for offset in QUAD_OFFSETS:
			var vertex: Vector3 = p+Vector3(offset.x*half_size,0,offset.y*half_size)
			_mesh.surface_set_color(color)
			_mesh.surface_add_vertex(vertex)
	rendered_quads += 1
