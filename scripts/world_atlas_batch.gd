extends Node3D
## Presentation-only imported-atlas renderer. submit() replaces the complete live list.
## Records contain sheet metadata, never an effect/event/target reference:
## {sheet: Dictionary, center: Vector3, right: Vector3, up: Vector3, pixel_size: float,
##  frame: int OR normalized_age: float, opacity: float = 1,
##  plane: StringName = &"world", no_depth_test: bool = false,
##  blend: StringName = &"mix", render_priority: int = 49}.
## center is the WORLD-SPACE source-image pivot; right/up are world image axes and may
## include nonuniform scale. The node is top-level/identity, including under a transformed parent.
## frame is clamped to actual authored frames (never an unused final-row cell).
## normalized_age maps the caller's complete lifetime onto the complete authored sequence.
## Texture + blend + priority + plane + depth mode form a batch. Grid safely supports alternate
## views of a texture. No instance limit, target selection, rule timing or detail budget exists here.

const RENDER_PRIORITY := 49
const MIN_CAPACITY := 16
const Rules = preload("res://scripts/pack_rules.gd")
const BUFFER_STRIDE := 16 # 12 row-major Transform3D floats, then four INSTANCE_CUSTOM floats.
const SHADER_SOURCE := """shader_type spatial;
render_mode unshaded, cull_disabled, blend_%s, depth_draw_never, fog_disabled, shadows_disabled%s;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 frame_grid;
uniform bool clip_to_table = false;
uniform vec4 table_bounds_xz = vec4(-1.0,1.0,-1.0,1.0);
uniform bool soften_core = false;
uniform float core_radius_px = 40.0;
uniform float core_min_opacity = 0.2;
uniform vec2 source_frame_size = vec2(224.0);
uniform int wave_style = 0;
varying flat float atlas_opacity;
varying flat float source_frame_index;
varying vec2 frame_uv;
varying vec2 table_position_xz;
void vertex() {
    // Compatibility stores INSTANCE_CUSTOM in half precision. Recover the integer cell
    // before constructing UVs, so a rounded 1/3 or 1/5 never shifts an atlas frame edge.
    vec2 cell = round(INSTANCE_CUSTOM.xy * frame_grid);
    frame_uv = UV;
    source_frame_index = cell.y * frame_grid.x + cell.x;
    UV = (UV + cell) / frame_grid;
    atlas_opacity = INSTANCE_CUSTOM.z;
    table_position_xz = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}
void fragment() {
    if (clip_to_table && (table_position_xz.x<table_bounds_xz.x || table_position_xz.x>table_bounds_xz.y || table_position_xz.y<table_bounds_xz.z || table_position_xz.y>table_bounds_xz.w)) discard;
    vec4 texel = texture(atlas_texture, UV);
    if (texel.a == 0.0 || atlas_opacity == 0.0) discard;
    float readability = 1.0;
    vec2 local = (frame_uv - vec2(0.5)) * source_frame_size;
    if (soften_core) {
        // Two hot source frames establish contact, then reveal the target again.
        // UV time, source life, event geometry and particle detail are unchanged.
        float reveal = smoothstep(1.0, 4.0, source_frame_index);
        float edge = smoothstep(0.20, 0.92, length(local) / max(1.0,core_radius_px));
        readability *= mix(1.0, mix(core_min_opacity,1.0,edge),reveal);
    }
    if (wave_style > 0) {
        float turn = atan(local.y,local.x+0.00001) / 6.28318530718 + 0.5;
        float sector_count = wave_style==1 ? 7.0 : wave_style==3 ? 12.0 : 4.0;
        float sector = fract(turn * sector_count);
        float arc = smoothstep(0.08,0.15,sector) * (1.0-smoothstep(0.73,0.82,sector));
        if (wave_style==3) arc = smoothstep(0.20,0.30,sector) * (1.0-smoothstep(0.61,0.70,sector));
        readability *= arc;
    }
    ALBEDO = texel.rgb;
    ALPHA = texel.a * atlas_opacity * readability;
}
"""

const SHARED_LIGHT_SHADER_SOURCE := """shader_type spatial;
render_mode unshaded, cull_disabled, blend_%s, depth_draw_never, fog_disabled, shadows_disabled%s;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 frame_grid;
uniform bool clip_to_table = false;
uniform vec4 table_bounds_xz = vec4(-1.0,1.0,-1.0,1.0);
uniform bool soften_core = false;
uniform float core_radius_px = 40.0;
uniform float core_min_opacity = 0.2;
uniform vec2 source_frame_size = vec2(224.0);
uniform int wave_style = 0;
varying flat float atlas_opacity;
varying flat float source_frame_index;
varying vec2 frame_uv;
varying vec2 table_position_xz;
void vertex() {
    // Compatibility stores INSTANCE_CUSTOM in half precision. Recover the integer cell
    // before constructing UVs, so a rounded 1/3 or 1/5 never shifts an atlas frame edge.
    vec2 cell = round(INSTANCE_CUSTOM.xy * frame_grid);
    frame_uv = UV;
    source_frame_index = cell.y * frame_grid.x + cell.x;
    UV = (UV + cell) / frame_grid;
    atlas_opacity = INSTANCE_CUSTOM.w;
    table_position_xz = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}
void fragment() {
    if (clip_to_table && (table_position_xz.x<table_bounds_xz.x || table_position_xz.x>table_bounds_xz.y || table_position_xz.y<table_bounds_xz.z || table_position_xz.y>table_bounds_xz.w)) discard;
    vec4 texel = texture(atlas_texture, UV);
    if (texel.a == 0.0 || atlas_opacity == 0.0) discard;
    float readability = 1.0;
    vec2 local = (frame_uv - vec2(0.5)) * source_frame_size;
    if (soften_core) {
        // Two hot source frames establish contact, then reveal the target again.
        // UV time, source life, event geometry and particle detail are unchanged.
        float reveal = smoothstep(1.0, 4.0, source_frame_index);
        float edge = smoothstep(0.20, 0.92, length(local) / max(1.0,core_radius_px));
        readability *= mix(1.0, mix(core_min_opacity,1.0,edge),reveal);
    }
    if (wave_style > 0) {
        float turn = atan(local.y,local.x+0.00001) / 6.28318530718 + 0.5;
        float sector_count = wave_style==1 ? 7.0 : wave_style==3 ? 12.0 : 4.0;
        float sector = fract(turn * sector_count);
        float arc = smoothstep(0.08,0.15,sector) * (1.0-smoothstep(0.73,0.82,sector));
        if (wave_style==3) arc = smoothstep(0.20,0.30,sector) * (1.0-smoothstep(0.61,0.70,sector));
        readability *= arc;
    }
    ALBEDO = texel.rgb;
    ALPHA = texel.a * atlas_opacity * readability;
}
"""

class BatchData extends RefCounted:
	var key := ""
	var plane: StringName
	var texture_id := 0
	var light_texture_id := 0
	var texture_resource_id := 0
	var grid := Vector2i.ONE
	var no_depth_test := false
	var blend: StringName = &"mix"
	var render_priority := RENDER_PRIORITY
	var node: MultiMeshInstance3D
	var light_node: MultiMeshInstance3D
	var light_material: ShaderMaterial
	var multimesh: MultiMesh
	var material: ShaderMaterial
	var buffer := PackedFloat32Array()
	var capacity := 0
	var count := 0
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	var compiled_rows: Array = []
	var compiled_slots := PackedInt32Array()
	var compiled_frames := PackedInt64Array()
	var compiled_opacities := PackedFloat64Array()
	var compiled_records: Array = []

	func push_native(record: CompiledRecord, authored_frames: int) -> void:
		# Operate on this batch's own staging members; preserve every row/slot and
		# the original record required for an exact native-rejection fallback.
		compiled_rows.append(record._transform_row)
		compiled_slots.append(count)
		compiled_frames.append(clampi(record.frame,0,authored_frames-1))
		compiled_opacities.append(clampf(record.opacity,0.0,1.0))
		compiled_records.append(record)
		if count==0:
			minimum=record._minimum
			maximum=record._maximum
		else:
			minimum=minimum.min(record._minimum)
			maximum=maximum.max(record._maximum)
		count+=1

	func write_light_opacities() -> void:
		# Self-owned PackedArray write; no cross-object property assignment per row.
		for index in compiled_records.size():
			var record: CompiledRecord=compiled_records[index]
			buffer[compiled_slots[index]*BUFFER_STRIDE+15]=clampf(record.light_opacity,0.0,1.0) if record._paired else 0.0

class SourceData extends RefCounted:
	var sheet: Dictionary
	var texture: Texture2D
	var size: Vector2
	var pivot: Vector2
	var columns: int
	var rows: int
	var frames: int
	var checked_submission := -1
	var registered := false
	var batches: Array[BatchData] = []

class CompiledRecord extends RefCounted:
	## Explicit owned-geometry API. Static values are immutable after compilation;
	## only frame/opacity are advanced by their owning QualityEffect. No event ref.
	var static_data: Dictionary:
		get: return _static_data
	var frame := 0
	var opacity := 1.0
	var light_opacity := 0.0
	var paired: bool:
		get: return _paired
	var _paired := false
	var _fallback_color: CompiledRecord
	var _fallback_light: CompiledRecord
	var _light_source: SourceData
	var _static_data: Dictionary = {}
	var _valid := false
	var _x_axis: Vector3
	var _y_axis: Vector3
	var _normal: Vector3
	var _origin: Vector3
	var _minimum: Vector3
	var _maximum: Vector3
	var _transform_row := PackedFloat32Array()
	var _owner_id := 0
	var _source: SourceData
	var _batch: BatchData

static func compile_quality_record(record: Dictionary) -> CompiledRecord:
	var result := _compile_single_quality_record(record)
	if result==null or not record.has("light_sheet"): return result
	if record.get("blend",&"mix")!=&"mix" or not record.light_sheet is Dictionary or int(record.get("render_priority",RENDER_PRIORITY))>=127: return null
	var light: Dictionary=record.light_sheet
	if not light.is_read_only() or not _sheet_is_valid(light) or not _finite_number(record.get("light_opacity")): return null
	for field in ["size","pivot","columns","rows","frames"]:
		if light.get(field)!=record.sheet.get(field): return null
	var descriptor:=result._static_data.duplicate()
	descriptor["light_sheet"]=light
	descriptor.make_read_only()
	result._static_data=descriptor
	result._paired=true
	result.light_opacity=float(record.light_opacity)
	return result

static func _compile_single_quality_record(record: Dictionary) -> CompiledRecord:
	# This explicit API transfers fixed geometry/style, not an arbitrary mutable
	# Dictionary fast-path. Generic submit records retain their full validation.
	var sheet_value: Variant = record.get("sheet")
	if not sheet_value is Dictionary or not sheet_value.is_read_only() or not _sheet_is_valid(sheet_value): return null
	var center_value: Variant = record.get("center")
	var right_value: Variant = record.get("right")
	var up_value: Variant = record.get("up")
	var pixel_size_value: Variant = record.get("pixel_size")
	var plane_value: Variant = record.get("plane",&"world")
	var depth_value: Variant = record.get("no_depth_test",false)
	var blend_value: Variant = record.get("blend",&"mix")
	var priority_value: Variant = record.get("render_priority",RENDER_PRIORITY)
	if not center_value is Vector3 or not right_value is Vector3 or not up_value is Vector3: return null
	if not _finite_number(pixel_size_value) or not (plane_value is String or plane_value is StringName) or not depth_value is bool: return null
	if not (blend_value is String or blend_value is StringName) or not priority_value is int or priority_value< -128 or priority_value>127: return null
	var blend := StringName(blend_value)
	if blend!=&"mix" and blend!=&"add": return null
	var center: Vector3 = center_value
	var right: Vector3 = right_value
	var up: Vector3 = up_value
	var pixel_size := float(pixel_size_value)
	if not center.is_finite() or not right.is_finite() or not up.is_finite() or pixel_size<=0: return null
	var cross_value := right.cross(up)
	var cross_length_squared := cross_value.length_squared()
	if not cross_value.is_finite() or not is_finite(cross_length_squared) or cross_length_squared<.000000000001: return null
	var sheet: Dictionary = sheet_value
	var size_px := Vector2(sheet.size)
	var pivot := Vector2(sheet.pivot)
	var result := CompiledRecord.new()
	result._x_axis = right*(size_px.x*pixel_size)
	result._y_axis = up*(size_px.y*pixel_size)
	result._normal = cross_value.normalized()
	result._origin = center+right*((size_px.x*.5-pivot.x)*pixel_size)+up*((pivot.y-size_px.y*.5)*pixel_size)
	if not result._x_axis.is_finite() or not result._y_axis.is_finite() or not result._origin.is_finite(): return null
	var extent := (result._x_axis.abs()+result._y_axis.abs())*.5
	result._minimum = result._origin-extent
	result._maximum = result._origin+extent
	result._static_data = {"sheet":sheet,"plane":StringName(plane_value),"no_depth_test":depth_value,"blend":blend,"render_priority":priority_value,
		"x_axis":result._x_axis,"y_axis":result._y_axis,"normal":result._normal,"origin":result._origin,"minimum":result._minimum,"maximum":result._maximum}
	result._static_data.make_read_only()
	result._transform_row = PackedFloat32Array([
		result._x_axis.x,result._y_axis.x,result._normal.x,result._origin.x,
		result._x_axis.y,result._y_axis.y,result._normal.y,result._origin.y,
		result._x_axis.z,result._y_axis.z,result._normal.z,result._origin.z,
		0.0,0.0,0.0,0.0])
	result._valid = true
	return result

var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _quad: QuadMesh
var _submitted_instances := 0
var _rejected_instances := 0
var _visible_instances := 0
var _draw_calls := 0
var _growth_count := 0
var _upload_count := 0
var _submission_serial := 0
var _trusted_sources: Dictionary = {}
var _atlas_math: RefCounted
var _atlas_math_checked := false
var _native_bulk_enabled := true
var _bulk_collecting := false
var _renderer_owner_id: int

func _init() -> void:
	_renderer_owner_id = get_instance_id()
	top_level = true

func _ready() -> void:
	global_transform = Transform3D.IDENTITY

func prepare(sheets: Array, plane: StringName = &"impact", no_depth_test: bool = true, capacity: int = MIN_CAPACITY) -> Dictionary:
	# Allocate only requested resources/capacity. This submits no event and draws no warmup quad.
	# Actual shader/GPU warmup must be measured separately by the caller's rendered prelude.
	var prepared := 0
	var rejected := 0
	for sheet_value: Variant in sheets:
		if capacity <= 0 or not sheet_value is Dictionary or not _sheet_is_valid(sheet_value):
			rejected += 1
			continue
		var sheet: Dictionary = sheet_value
		var batch := _get_batch(sheet.texture,Vector2i(sheet.columns,sheet.rows),plane,no_depth_test)
		var old_capacity := batch.capacity
		_ensure_capacity(batch,capacity)
		if batch.count > 0 and batch.capacity != old_capacity:
			batch.multimesh.buffer = batch.buffer
			_upload_count += 1
		batch.multimesh.visible_instance_count = batch.count
		prepared += 1
	var result := metrics()
	result["prepared_batches"] = prepared
	result["rejected_sheets"] = rejected
	return result

func prepare_records(records: Array, capacity: int = MIN_CAPACITY) -> Dictionary:
	# Material/source warmup accepts the same sheet/style descriptors as submit,
	# without requiring geometry or advancing any effect clock. No fake instances.
	var prepared := 0
	var rejected := 0
	for value: Variant in records:
		if capacity<=0 or not value is Dictionary:
			rejected += 1
			continue
		var record: Dictionary = value
		var sheet_value: Variant = record.get("sheet")
		var plane_value: Variant = record.get("plane",&"world")
		var depth_value: Variant = record.get("no_depth_test",false)
		var blend_value: Variant = record.get("blend",&"mix")
		var priority_value: Variant = record.get("render_priority",RENDER_PRIORITY)
		if not sheet_value is Dictionary or not _sheet_is_valid(sheet_value) or not (plane_value is String or plane_value is StringName) or not depth_value is bool or not (blend_value is String or blend_value is StringName) or not str(blend_value) in ["mix","add"] or not priority_value is int or priority_value< -128 or priority_value>127:
			rejected += 1
			continue
		var sheet: Dictionary = sheet_value
		var light_sheet: Dictionary=record.get("light_sheet",{})
		if not light_sheet.is_empty() and not _sheet_is_valid(light_sheet):
			rejected+=1
			continue
		var batch := _get_batch(sheet.texture,Vector2i(sheet.columns,sheet.rows),StringName(plane_value),depth_value,StringName(blend_value),priority_value,light_sheet.get("texture"))
		var old_capacity := batch.capacity
		_ensure_capacity(batch,capacity)
		if batch.count>0 and batch.capacity!=old_capacity:
			batch.multimesh.buffer = batch.buffer
			_upload_count += 1
		batch.multimesh.visible_instance_count = batch.count
		prepared += 1
	var result := metrics()
	result["prepared_batches"] = prepared
	result["rejected_records"] = rejected
	return result

func prepare_source(records: Array, capacity: int = MIN_CAPACITY) -> Dictionary:
	return prepare_records(records,capacity)

func submit(records: Array) -> Dictionary:
	_submission_serial += 1
	_submitted_instances = records.size()
	_rejected_instances = 0
	_visible_instances = 0
	_draw_calls = 0
	_bulk_collecting = _native_bulk_enabled and _native_atlas_math()!=null
	for batch: BatchData in _batches.values():
		batch.count = 0
	for record: Variant in records:
		var accepted := _append_compiled(record) if record is CompiledRecord else (record is Dictionary and _append_record(record))
		if not accepted:
			_rejected_instances += 1
	for batch: BatchData in _batches.values():
		if batch.count > 0:
			if not batch.compiled_rows.is_empty(): _fill_compiled_rows(batch)
			# One bulk upload per active texture/plane, with retained geometric capacity.
			batch.multimesh.buffer = batch.buffer
			batch.multimesh.custom_aabb = AABB(batch.minimum, (batch.maximum-batch.minimum).max(Vector3.ONE*.0001))
			_upload_count += 1
			_visible_instances += batch.count*(2 if batch.light_node!=null else 1)
			_draw_calls += 2 if batch.light_node!=null else 1
		batch.multimesh.visible_instance_count = batch.count
	_bulk_collecting = false
	return metrics()

func _native_atlas_math() -> RefCounted:
	if not _atlas_math_checked:
		_atlas_math_checked = true
		if ClassDB.class_exists("RoundCardGeometryMath"):
			var candidate: RefCounted = ClassDB.instantiate("RoundCardGeometryMath")
			if candidate.has_method("fill_atlas_rows"): _atlas_math = candidate
	return _atlas_math

func _fill_compiled_rows(batch: BatchData) -> void:
	var filled: PackedFloat32Array = _atlas_math.fill_atlas_rows(batch.buffer,batch.compiled_rows,batch.compiled_slots,batch.compiled_frames,batch.compiled_opacities,batch.grid.x,batch.grid.y)
	if filled.size()==batch.buffer.size():
		batch.buffer = filled
		filled = PackedFloat32Array() # Release second COW owner before touching W.
		batch.write_light_opacities()
	else:
		# The native transaction never partially mutates input. Preserve the
		# complete original packing path on unsupported/malformed native inputs.
		for index in batch.compiled_records.size():
			_write_compiled_row(batch,batch.compiled_records[index],batch.compiled_slots[index]*BUFFER_STRIDE)
	batch.compiled_rows.clear()
	batch.compiled_slots.clear()
	batch.compiled_frames.clear()
	batch.compiled_opacities.clear()
	batch.compiled_records.clear()

func clear() -> void:
	# Reuse nodes, mesh, shaders, materials, GPU capacity and CPU buffers next submit.
	_submitted_instances = 0
	_rejected_instances = 0
	_visible_instances = 0
	_draw_calls = 0
	for batch: BatchData in _batches.values():
		batch.count = 0
		batch.multimesh.visible_instance_count = 0

func metrics() -> Dictionary:
	var capacity := 0
	for batch: BatchData in _batches.values():
		capacity += batch.capacity
	return {"draw_calls":_draw_calls,"visible_instances":_visible_instances,
		"submitted_instances":_submitted_instances,"rejected_instances":_rejected_instances,
		"batch_count":_batches.size(),"material_count":_materials.size(),"shader_count":_shaders.size(),
		"capacity":capacity,"growth_count":_growth_count,"upload_count":_upload_count,"cpu_packed_records":_submitted_instances,"compositing_mode":"shared_dual_pass"}

func snapshot() -> Array[Dictionary]:
	# Explicit debug surface: scalar IDs let tests prove reuse without retaining nodes/resources.
	var result: Array[Dictionary] = []
	for batch: BatchData in _batches.values():
		result.append({"key":batch.key,"plane":batch.plane,"texture_id":batch.texture_id,"texture_resource_id":batch.texture_resource_id,
			"grid":batch.grid,"no_depth_test":batch.no_depth_test,"blend":batch.blend,"capacity":batch.capacity,
			"visible_instances":batch.count,"instance_count":batch.multimesh.instance_count,
			"buffer_size":batch.buffer.size(),"aabb":batch.multimesh.custom_aabb,
			"node_id":batch.node.get_instance_id(),"multimesh_id":batch.multimesh.get_instance_id(),
			"material_id":batch.material.get_instance_id(),"render_priority":batch.material.render_priority})
	return result

func instance_snapshot(batch_key: String, index: int) -> Dictionary:
	if not _batches.has(batch_key):
		return {}
	var batch: BatchData = _batches[batch_key]
	if index < 0 or index >= batch.count:
		return {}
	var offset := index*BUFFER_STRIDE
	var transform_value := Transform3D(Basis(
		Vector3(batch.buffer[offset],batch.buffer[offset+4],batch.buffer[offset+8]),
		Vector3(batch.buffer[offset+1],batch.buffer[offset+5],batch.buffer[offset+9]),
		Vector3(batch.buffer[offset+2],batch.buffer[offset+6],batch.buffer[offset+10])),
		Vector3(batch.buffer[offset+3],batch.buffer[offset+7],batch.buffer[offset+11]))
	return {"transform":transform_value,"custom":Color(batch.buffer[offset+12],batch.buffer[offset+13],batch.buffer[offset+14],batch.buffer[offset+15])}

func _append_record(record: Dictionary) -> bool:
	var sheet_value: Variant = record.get("sheet")
	if not sheet_value is Dictionary:
		return false
	var sheet: Dictionary = sheet_value
	var source: SourceData
	if sheet.is_read_only():
		source = _trusted_source(sheet)
		if source==null: return false
	elif not _sheet_is_valid(sheet):
		return false
	var texture: Texture2D = source.texture if source!=null else sheet.texture
	var size_px := source.size if source!=null else Vector2(sheet.size)
	var pivot := source.pivot if source!=null else Vector2(sheet.pivot)
	var columns: int = source.columns if source!=null else sheet.columns
	var rows: int = source.rows if source!=null else sheet.rows
	var frames: int = source.frames if source!=null else sheet.frames
	var center_value: Variant = record.get("center")
	var right_value: Variant = record.get("right")
	var up_value: Variant = record.get("up")
	var pixel_size_value: Variant = record.get("pixel_size")
	var opacity_value: Variant = record.get("opacity",1.0)
	var plane_value: Variant = record.get("plane",&"world")
	var depth_value: Variant = record.get("no_depth_test",false)
	var blend_value: Variant = record.get("blend",&"mix")
	var priority_value: Variant = record.get("render_priority",RENDER_PRIORITY)
	if not center_value is Vector3 or not right_value is Vector3 or not up_value is Vector3:
		return false
	if not _finite_number(pixel_size_value) or not _finite_number(opacity_value):
		return false
	if not (plane_value is String or plane_value is StringName) or not depth_value is bool:
		return false
	if not (blend_value is String or blend_value is StringName) or not priority_value is int or priority_value< -128 or priority_value>127:
		return false
	var blend := StringName(blend_value)
	if blend!=&"mix" and blend!=&"add": return false
	var center: Vector3 = center_value
	var right: Vector3 = right_value
	var up: Vector3 = up_value
	var pixel_size := float(pixel_size_value)
	if not center.is_finite() or not right.is_finite() or not up.is_finite() or pixel_size <= 0:
		return false
	var cross_value := right.cross(up)
	var cross_length_squared := cross_value.length_squared()
	if not cross_value.is_finite() or not is_finite(cross_length_squared) or cross_length_squared < .000000000001:
		return false
	var frame := 0
	if record.has("frame"):
		if not record.frame is int:
			return false
		frame = clampi(record.frame,0,frames-1)
	elif record.has("normalized_age"):
		if not _finite_number(record.normalized_age):
			return false
		frame = mini(floori(clampf(float(record.normalized_age),0.0,1.0)*frames),frames-1)
	else:
		return false
	var x_axis := right*(size_px.x*pixel_size)
	var y_axis := up*(size_px.y*pixel_size)
	var normal := cross_value.normalized()
	var origin := center+right*((size_px.x*.5-pivot.x)*pixel_size)+up*((pivot.y-size_px.y*.5)*pixel_size)
	if not x_axis.is_finite() or not y_axis.is_finite() or not origin.is_finite():
		return false
	var batch := _source_batch(source,StringName(plane_value),depth_value,blend,priority_value) if source!=null else _get_batch(texture,Vector2i(columns,rows),StringName(plane_value),depth_value,blend,priority_value)
	_ensure_capacity(batch,batch.count+1)
	var offset := batch.count*BUFFER_STRIDE
	batch.buffer[offset] = x_axis.x
	batch.buffer[offset+1] = y_axis.x
	batch.buffer[offset+2] = normal.x
	batch.buffer[offset+3] = origin.x
	batch.buffer[offset+4] = x_axis.y
	batch.buffer[offset+5] = y_axis.y
	batch.buffer[offset+6] = normal.y
	batch.buffer[offset+7] = origin.y
	batch.buffer[offset+8] = x_axis.z
	batch.buffer[offset+9] = y_axis.z
	batch.buffer[offset+10] = normal.z
	batch.buffer[offset+11] = origin.z
	batch.buffer[offset+12] = float(frame%columns)/columns
	batch.buffer[offset+13] = float(frame/columns)/rows
	batch.buffer[offset+14] = clampf(float(opacity_value),0.0,1.0)
	batch.buffer[offset+15] = 0.0
	var extent := (x_axis.abs()+y_axis.abs())*.5
	if batch.count == 0:
		batch.minimum = origin-extent
		batch.maximum = origin+extent
	else:
		batch.minimum = batch.minimum.min(origin-extent)
		batch.maximum = batch.maximum.max(origin+extent)
	batch.count += 1
	return true

func _append_compiled(record: CompiledRecord) -> bool:
	if not record._valid: return false
	var paired:=record._paired
	var color_valid:=is_finite(record.opacity)
	var light_valid:=not paired or is_finite(record.light_opacity)
	if not paired and not color_valid: return false
	var source: SourceData=record._source
	var light: SourceData=record._light_source
	if record._owner_id!=_renderer_owner_id:
		source=_trusted_source(record._static_data.sheet)
		light=_trusted_source(record._static_data.light_sheet) if paired else null
		record._source=source
		record._light_source=light
		record._batch=null
		record._owner_id=_renderer_owner_id
	else:
		if source==null:
			source=_trusted_source(record._static_data.sheet)
			record._source=source
		elif source.checked_submission!=_submission_serial:
			if _sheet_is_valid(source.sheet): source.checked_submission=_submission_serial
			else: color_valid=false
		if paired:
			if light==null:
				light=_trusted_source(record._static_data.light_sheet)
				record._light_source=light
			elif light.checked_submission!=_submission_serial:
				if _sheet_is_valid(light.sheet): light.checked_submission=_submission_serial
				else: light_valid=false
	color_valid=color_valid and source!=null
	light_valid=light_valid and (not paired or light!=null)
	if paired and (not color_valid or not light_valid):
		return _append_partial_channels(record,color_valid,light_valid)
	if not color_valid: return false
	if record._batch==null:
		if paired and not light.registered:
			var identity:=light.texture.get_instance_id()
			var views: Array=_trusted_sources.get(identity,[])
			if not _trusted_sources.has(identity): _trusted_sources[identity]=views
			views.append(light)
			light.registered=true
		record._batch=_source_batch(source,record._static_data.plane,record._static_data.no_depth_test,&"mix",record._static_data.render_priority,light.texture) if paired else _source_batch(source,record._static_data.plane,record._static_data.no_depth_test,record._static_data.blend,record._static_data.render_priority)
	var batch: BatchData=record._batch
	if batch.count>=batch.capacity: _ensure_capacity(batch,batch.count+1)
	if _bulk_collecting:
		batch.push_native(record,source.frames)
		return true
	_write_compiled_row(batch,record,batch.count*BUFFER_STRIDE)
	if batch.count==0:
		batch.minimum=record._minimum
		batch.maximum=record._maximum
	else:
		batch.minimum=batch.minimum.min(record._minimum)
		batch.maximum=batch.maximum.max(record._maximum)
	batch.count+=1
	return true

func _append_partial_channels(record: CompiledRecord, color_valid: bool, light_valid: bool) -> bool:
	# A fixed pair is an upload optimization, not permission to lose its valid
	# channel if the other ImageTexture/opacity becomes invalid at runtime.
	var accepted:=false
	if color_valid:
		if record._fallback_color==null: record._fallback_color=_single_channel_shadow(record,false)
		record._fallback_color.frame=record.frame
		record._fallback_color.opacity=record.opacity
		accepted=_append_compiled(record._fallback_color)
	if light_valid:
		if record._fallback_light==null: record._fallback_light=_single_channel_shadow(record,true)
		record._fallback_light.frame=record.frame
		record._fallback_light.opacity=record.light_opacity
		var light_accepted:=_append_compiled(record._fallback_light)
		accepted=accepted or light_accepted
	return accepted

static func _single_channel_shadow(record: CompiledRecord, light: bool) -> CompiledRecord:
	# Exception-only allocation. Copy cached geometry bit-for-bit, not mutable
	# event/debug dictionaries or newly computed axes. Native rows remain COW.
	var result:=CompiledRecord.new()
	result._valid=record._valid
	result._x_axis=record._x_axis
	result._y_axis=record._y_axis
	result._normal=record._normal
	result._origin=record._origin
	result._minimum=record._minimum
	result._maximum=record._maximum
	result._transform_row=record._transform_row
	var descriptor:=record._static_data.duplicate()
	if light:
		descriptor["sheet"]=descriptor.light_sheet
		descriptor["blend"]=&"add"
		descriptor["render_priority"]=int(descriptor.render_priority)+1
	descriptor.erase("light_sheet")
	descriptor.make_read_only()
	result._static_data=descriptor
	return result

func _write_compiled_row(batch: BatchData, record: CompiledRecord, offset: int) -> void:
	var source: SourceData = record._source
	batch.buffer[offset] = record._x_axis.x
	batch.buffer[offset+1] = record._y_axis.x
	batch.buffer[offset+2] = record._normal.x
	batch.buffer[offset+3] = record._origin.x
	batch.buffer[offset+4] = record._x_axis.y
	batch.buffer[offset+5] = record._y_axis.y
	batch.buffer[offset+6] = record._normal.y
	batch.buffer[offset+7] = record._origin.y
	batch.buffer[offset+8] = record._x_axis.z
	batch.buffer[offset+9] = record._y_axis.z
	batch.buffer[offset+10] = record._normal.z
	batch.buffer[offset+11] = record._origin.z
	var frame := clampi(record.frame,0,source.frames-1)
	batch.buffer[offset+12] = float(frame%source.columns)/source.columns
	batch.buffer[offset+13] = float(frame/source.columns)/source.rows
	batch.buffer[offset+14] = clampf(record.opacity,0.0,1.0)
	batch.buffer[offset+15] = clampf(record.light_opacity,0.0,1.0) if record._paired else 0.0

static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _trusted_source(sheet: Dictionary) -> SourceData:
	var texture_value: Variant = sheet.get("texture")
	if not texture_value is Texture2D or not is_instance_valid(texture_value): return null
	var identity: int = texture_value.get_instance_id()
	var views: Variant = _trusted_sources.get(identity)
	if views!=null:
		for source: SourceData in views:
			if is_same(source.sheet,sheet):
				# Texture resources can change even when their descriptor is read-only.
				# Validate once per synchronous submit, never across a frame boundary.
				if source.checked_submission!=_submission_serial:
					if not _sheet_is_valid(sheet): return null
					source.checked_submission = _submission_serial
				return source
	if not _sheet_is_valid(sheet): return null
	var source := SourceData.new()
	source.sheet = sheet
	source.texture = texture_value
	source.size = Vector2(sheet.size)
	source.pivot = Vector2(sheet.pivot)
	source.columns = sheet.columns
	source.rows = sheet.rows
	source.frames = sheet.frames
	source.checked_submission = _submission_serial
	return source

func _source_batch(source: SourceData, plane: StringName, depth: bool, blend: StringName, priority: int, light_texture: Texture2D = null) -> BatchData:
	# Do not retain descriptors/resources for rejected geometry/style records.
	if not source.registered:
		var identity := source.texture.get_instance_id()
		var views: Variant = _trusted_sources.get(identity)
		if views==null:
			views = []
			_trusted_sources[identity] = views
		views.append(source)
		source.registered = true
	for batch: BatchData in source.batches:
		if batch.plane==plane and batch.no_depth_test==depth and batch.blend==blend and batch.render_priority==priority and batch.light_texture_id==(light_texture.get_instance_id() if light_texture!=null else 0):
			return batch
	var batch := _get_batch(source.texture,Vector2i(source.columns,source.rows),plane,depth,blend,priority,light_texture)
	source.batches.append(batch)
	return batch

static func _sheet_is_valid(sheet: Dictionary) -> bool:
	var texture_value: Variant = sheet.get("texture")
	var size_value: Variant = sheet.get("size")
	var pivot_value: Variant = sheet.get("pivot")
	var columns_value: Variant = sheet.get("columns")
	var rows_value: Variant = sheet.get("rows")
	var frames_value: Variant = sheet.get("frames")
	if not texture_value is Texture2D or not is_instance_valid(texture_value):
		return false
	if not (size_value is Vector2 or size_value is Vector2i) or not (pivot_value is Vector2 or pivot_value is Vector2i):
		return false
	if not columns_value is int or not rows_value is int or not frames_value is int:
		return false
	var size_px := Vector2(size_value)
	var pivot := Vector2(pivot_value)
	var columns: int = columns_value
	var rows: int = rows_value
	var frames: int = frames_value
	if not size_px.is_finite() or not pivot.is_finite() or size_px.x <= 0 or size_px.y <= 0 or columns <= 0 or rows <= 0 or frames <= 0 or frames > columns*rows:
		return false
	var texture: Texture2D = texture_value
	return texture.get_size().is_equal_approx(size_px*Vector2(columns,rows))

func _get_batch(texture: Texture2D, grid: Vector2i, plane: StringName, no_depth_test: bool, blend: StringName = &"mix", priority: int = RENDER_PRIORITY, light_texture: Texture2D = null) -> BatchData:
	var texture_id := texture.get_rid().get_id()
	# Dummy rendering backends may not allocate texture RIDs; retain texture grouping there too.
	var texture_key := ("rid"+str(texture_id)) if texture_id != 0 else ("resource"+str(texture.get_instance_id()))
	# Keep the trail's world-space desk clipping isolated even if another plane
	# later uses the same texture/grid/depth. Event records/capacity are untouched.
	var readability_profile := str(plane) if str(plane).begins_with("quality18_") else ""
	var clip_to_table := plane==&"speed_trail" or not readability_profile.is_empty()
	var material_key := "%s:%d:%d:%d:%d:%s:%d" % [texture_key,grid.x,grid.y,int(no_depth_test),int(clip_to_table),str(blend),priority]
	if not readability_profile.is_empty(): material_key+=":"+readability_profile
	if light_texture!=null: material_key+=":fused_light:"+str(light_texture.get_instance_id())
	var key := material_key+":"+str(plane)
	if _batches.has(key):
		return _batches[key]
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	if not _materials.has(material_key):
		var shader_key := "%s:%d" % [str(blend),int(no_depth_test)]
		if not _shaders.has(shader_key):
			var shader := Shader.new()
			shader.code = SHADER_SOURCE % [str(blend),", depth_test_disabled" if no_depth_test else ""]
			_shaders[shader_key] = shader
		var material := ShaderMaterial.new()
		material.shader = _shaders[shader_key]
		material.render_priority = priority
		material.set_shader_parameter("atlas_texture",texture)
		material.set_shader_parameter("frame_grid",Vector2(grid))
		material.set_shader_parameter("clip_to_table",clip_to_table)
		if not readability_profile.is_empty():
			var parts := readability_profile.split("_")
			var role := str(parts[1])
			var element := str(parts[parts.size()-1])
			material.set_shader_parameter("source_frame_size",texture.get_size()/Vector2(grid))
			material.set_shader_parameter("soften_core",role in ["main","echo"] and element!="E01")
			material.set_shader_parameter("core_radius_px",float({"E02":35.0,"E05":40.0}.get(element,40.0)))
			material.set_shader_parameter("core_min_opacity",.12)
			material.set_shader_parameter("wave_style",int({"E01":2,"E02":1,"E05":3}.get(element,0)) if role=="wave" else 0)
		if clip_to_table:
			material.set_shader_parameter("table_bounds_xz",Vector4((-Rules.TABLE_HALF_WIDTH+Rules.DESK_BORDER)*.01,(Rules.TABLE_HALF_WIDTH-Rules.DESK_BORDER)*.01,(-Rules.TABLE_DEPTH+Rules.DESK_BORDER)*.01,-Rules.DESK_BORDER*.01))
		_materials[material_key] = material
	var batch := BatchData.new()
	batch.key = key
	batch.plane = plane
	batch.texture_id = texture_id
	batch.light_texture_id = light_texture.get_instance_id() if light_texture!=null else 0
	batch.texture_resource_id = texture.get_instance_id()
	batch.grid = grid
	batch.no_depth_test = no_depth_test
	batch.blend = blend
	batch.render_priority = priority
	batch.material = _materials[material_key]
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_custom_data = true
	batch.multimesh.mesh = _quad
	batch.node = MultiMeshInstance3D.new()
	batch.node.name = "Atlas_"+str(_batches.size())
	batch.node.multimesh = batch.multimesh
	batch.node.material_override = batch.material
	batch.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(batch.node)
	if light_texture!=null:
		var light_shader_key:="shared_add:"+str(int(no_depth_test))
		if not _shaders.has(light_shader_key):
			var light_shader:=Shader.new()
			light_shader.code=SHARED_LIGHT_SHADER_SOURCE % ["add",", depth_test_disabled" if no_depth_test else ""]
			_shaders[light_shader_key]=light_shader
		batch.light_material=batch.material.duplicate()
		batch.light_material.shader=_shaders[light_shader_key]
		batch.light_material.render_priority=priority+1
		batch.light_material.set_shader_parameter("atlas_texture",light_texture)
		_materials[material_key+":shared_add"]=batch.light_material
		batch.light_node=MultiMeshInstance3D.new()
		batch.light_node.name=batch.node.name+"_LightShared"
		batch.light_node.multimesh=batch.multimesh
		batch.light_node.material_override=batch.light_material
		batch.light_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.light_node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(batch.light_node)
	_batches[key] = batch
	return batch

func _ensure_capacity(batch: BatchData, required: int) -> void:
	if required <= batch.capacity:
		return
	var next_capacity := maxi(MIN_CAPACITY,batch.capacity*2)
	while next_capacity < required:
		next_capacity *= 2
	batch.buffer.resize(next_capacity*BUFFER_STRIDE)
	batch.multimesh.instance_count = next_capacity
	batch.multimesh.visible_instance_count = 0
	batch.capacity = next_capacity
	_growth_count += 1
