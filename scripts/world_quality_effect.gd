extends Node3D
## Authored source clips for committed events only. No hit/target/RNG/schedule changes.
## Pure batched descriptors: no Sprite, Mesh, material or Tween is created per clip.
const Catalog = preload("res://scripts/world_quality_pairs.gd")
const AtlasBatch = preload("res://scripts/world_atlas_batch.gd")
const QUIET_OPACITY := .65
var data: Dictionary = {}
var age := 0.0
var duration := 0.0
var reduced := false
var preview := false
var batched := true
var external_atlas := true
var revision := 0
## Read-only borrowed debug view of the last completed flush. World submits the
## compiled view, so dictionaries are refreshed only when this getter is read.
var atlas_records: Array:
	get:
		_refresh_debug_records()
		return _atlas_records
var _atlas_records: Array = []
var _debug_records_dirty := false
## Borrowed current render state, synchronously consumed by World/Batch. Callers
## retain neither list nor records as history; debug atlas_records stays compatible.
var compiled_atlas_records: Array = []
var atlas_visible := false
var atlas_key := ""
var rendered_quads := 0
var accent_quads := 0
var front_quads := 0
var bright_peak := false
var layer_count := 0
var intensity := 1.0
var visual_detail := 2
var allow_foreground := true
var allow_atlas := true
var ground_vertices := PackedVector3Array()
var ground_colors := PackedColorArray()
var front_vertices := PackedVector3Array()
var front_colors := PackedColorArray()
var view_right := Vector3.RIGHT
var view_up := Vector3.FORWARD
var view_forward := Vector3.UP
var _clips: Array[Dictionary] = []
var _fps := PackedFloat64Array()
var _delay := PackedFloat64Array()
var _lifetime := PackedFloat64Array()
var _frame_count := PackedInt32Array()
var _last_frames := PackedInt32Array()
var _current_frames := PackedInt32Array()
var _group_first := PackedInt32Array()
var _clock_first := PackedInt32Array()
var _sampled_age := NAN
var _current_records: Array[Dictionary] = []
var _compiled_records: Array = []
var _base_opacity := PackedFloat64Array()
var _base_light_opacity := PackedFloat64Array()
var _source_channel_counts := PackedInt32Array()
var _visual_dirty := false
var _expired := false
# configure transfers an immutable event description; never cache live age/reduced.
var peak_kind_eligible := true
var cosmetic_fragment := false

func _source_clips(event: Dictionary) -> Array:
	return Catalog.clips(event)

func configure(event: Dictionary, quiet: bool, is_preview: bool = false, defer_visual: bool = false) -> void:
	data = event.duplicate(true)
	var kind := str(data.get("kind","native"))
	peak_kind_eligible=kind not in ["pull","focus","mark_transfer","wrapper_fragment"] and not (kind=="native" and (int(data.get("pulse_index",0))>0 or bool(data.get("presentation_secondary",false))))
	cosmetic_fragment=bool(data.get("cosmetic_fragment",false))
	age = 0.0
	duration = 0.0
	reduced = quiet
	preview = is_preview
	_expired = false
	_clips.clear()
	_fps.clear()
	_delay.clear()
	_lifetime.clear()
	_frame_count.clear()
	_last_frames.clear()
	_current_frames.clear()
	_group_first.clear()
	_clock_first.clear()
	_sampled_age = NAN
	_current_records.clear()
	_compiled_records.clear()
	_base_opacity.clear()
	_base_light_opacity.clear()
	_source_channel_counts.clear()
	_atlas_records.clear()
	_debug_records_dirty = false
	compiled_atlas_records.clear()
	atlas_visible = false
	atlas_key = ""
	layer_count = 0
	for value: Variant in _source_clips(data):
		if not value is Dictionary or not value.get("sheet") is Dictionary:
			push_error("Quality clip requires a sheet descriptor.")
			continue
		var clip: Dictionary = value
		var sheet: Dictionary = clip.sheet
		var fps := float(sheet.get("fps",0.0))
		var frames := int(sheet.get("frames",0))
		var start := float(clip.get("delay",0.0))
		var life := float(clip.get("lifetime",sheet.get("duration",0.0)))
		if not is_finite(fps) or fps<=0.0 or frames<=0 or not is_finite(start) or start<0.0 or not is_finite(life) or life<=0.0:
			push_error("Quality clip requires finite authored FPS, lifetime and delay.")
			continue
		# _source_clips transfers fresh per-event descriptors; Catalog sheets and
		# resources remain shared/read-only. Keep the original event deep copy.
		_clips.append(clip)
		_fps.append(fps)
		_delay.append(start)
		_lifetime.append(life)
		_frame_count.append(frames)
		_last_frames.append(-2)
		_current_frames.append(-2)
		var first := _clips.size()-1
		for candidate in _group_first:
			if _fps[candidate]==fps and _frame_count[candidate]==frames and _delay[candidate]==start and _lifetime[candidate]==life:
				first = candidate
				break
		if first==_clips.size()-1: _group_first.append(first)
		_clock_first.append(first)
		var current := clip.duplicate()
		_current_records.append(current)
		_compiled_records.append(AtlasBatch.compile_quality_record(current))
		_base_opacity.append(float(clip.get("opacity",1.0)))
		_base_light_opacity.append(float(clip.get("light_opacity",0.0)))
		_source_channel_counts.append(2 if clip.has("light_sheet") else 1)
		duration = maxf(duration,start+life)
		if atlas_key.is_empty(): atlas_key = str(sheet.get("key","quality15"))
	_update_peak()
	_visual_dirty = true
	if not defer_visual: flush_visual()

func _clip_frame(index: int) -> int:
	var local_age := age-_delay[index]
	if local_age<0.0 or local_age>=_lifetime[index]:
		return -1
	return mini(floori(local_age*_fps[index]),_frame_count[index]-1)

func _frames_changed() -> bool:
	_sample_frames()
	for index in _group_first:
		if _current_frames[index]!=_last_frames[index]: return true
	return false

func _sample_frames() -> void:
	if _sampled_age==age: return
	for index in _group_first: _current_frames[index] = _clip_frame(index)
	_sampled_age = age

func advance(delta: float, frozen: bool, quiet: bool, defer_visual: bool = false) -> void:
	if _expired or not is_finite(delta) or delta<0.0:
		return
	var quiet_changed := reduced!=quiet
	reduced = quiet
	if not frozen: age += delta
	if age>=duration:
		_expired = true
		_atlas_records.clear()
		_debug_records_dirty = false
		compiled_atlas_records.clear()
		atlas_visible = false
		bright_peak = false
		layer_count = 0
		revision += 1
		queue_free()
		return
	if quiet_changed or _frames_changed(): _visual_dirty = true
	# Brightness is an observation for World sorting, never a clip budget/cap.
	_update_peak()
	if _visual_dirty and not defer_visual: flush_visual()

func _update_peak() -> void:
	bright_peak = not reduced and age<.095 and peak_kind_eligible

func flush_visual() -> void:
	if not _visual_dirty or _expired or is_queued_for_deletion():
		return
	_visual_dirty = false
	_atlas_records.clear()
	_debug_records_dirty = true
	compiled_atlas_records.clear()
	layer_count=0
	_sample_frames()
	for index in _clips.size():
		var frame := _current_frames[_clock_first[index]]
		_last_frames[index] = frame
		if frame<0: continue
		layer_count+=_source_channel_counts[index]
		var record: Dictionary = _current_records[index]
		var opacity := _base_opacity[index]*(QUIET_OPACITY if reduced else 1.0)
		var compiled: AtlasBatch.CompiledRecord = _compiled_records[index]
		if compiled!=null:
			compiled.frame = frame
			compiled.opacity = opacity
			compiled.light_opacity = _base_light_opacity[index]*(QUIET_OPACITY if reduced else 1.0)
			compiled_atlas_records.append(compiled)
		else:
			# Non-owned/mutable source fixtures retain the original generic path.
			record["frame"] = frame
			record["opacity"] = opacity
			compiled_atlas_records.append(record)
	atlas_visible = not compiled_atlas_records.is_empty()

	_update_peak()
	revision += 1

func _refresh_debug_records() -> void:
	if not _debug_records_dirty: return
	_debug_records_dirty=false
	for index in _clips.size():
		if _last_frames[index]<0: continue
		var record: Dictionary=_current_records[index]
		var compiled: AtlasBatch.CompiledRecord=_compiled_records[index]
		if record.has("light_sheet") and compiled!=null:
			var color: Dictionary=record.source_color_record
			var light: Dictionary=record.source_light_record
			color["frame"]=compiled.frame
			color["opacity"]=compiled.opacity
			light["frame"]=compiled.frame
			light["opacity"]=compiled.light_opacity
			_atlas_records.append(color)
			_atlas_records.append(light)
		else:
			if compiled!=null:
				record["frame"]=compiled.frame
				record["opacity"]=compiled.opacity
			_atlas_records.append(record)

func set_visual_budget(detail: int, foreground: bool, atlas: bool, defer_visual: bool = false) -> void:
	# Retain World's interface, but its legacy detail limits never remove a
	# quality clip, shorten authored playback or reduce an individual source FPS.
	visual_detail = detail
	allow_foreground = foreground
	allow_atlas = atlas
	if _visual_dirty and not defer_visual: flush_visual()

func clip_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for index in _clips.size():
		var pair: Dictionary=_clips[index]
		var channels: Array=[pair.source_color_record,pair.source_light_record] if pair.has("light_sheet") else [pair]
		for clip: Dictionary in channels:
			result.append({"key":clip.sheet.get("key",""),"channel":clip.sheet.get("channel",""),"role":clip.get("role",""),"fps":_fps[index],"delay":_delay[index],"lifetime":_lifetime[index],"local_age":age-_delay[index],"frame":_clip_frame(index)})
	return result

