extends RefCounted
## Shared imported pixelfx sheets. Metadata is cached once; playback never owns rule timing.
const ROOT := "res://assets/fx/feedback10/"
const COMBAT_ROOT := "res://assets/fx/combat11/"
const TOPDOWN_ROOT := "res://assets/fx/topdown13/"
const FALLBACK_ROOT := "res://assets/fx/pixelfx09/"
static var _sheets: Dictionary = {}
static var _textures: Dictionary = {}
const NATIVE_KEYS := {"E01":"heavy","E02":"lightning","E05":"frost"}

static func element_keys(element: String) -> Array[String]:
	if not NATIVE_KEYS.has(element): return []
	# Both current and legacy contact plus generic auxiliaries are intentional warmup
	# entries. Aliased pulse/echo/bond sheets share the same texture and batching RID.
	var keys: Array[String] = [str(NATIVE_KEYS.get(element,"heavy"))]
	for family: String in ["pulse","echo","aftershock","chain","penetration","pull","contact","bond","coverage"]:
		keys.append(family+"_"+element)
	keys.append_array(["break","contact","trail"])
	return keys

static func sheet(key: String) -> Dictionary:
	if key in ["fire","shock","poison","vortex","beam"] or key.get_slice("_",1) in ["E03","E04","E06","E07","E08"]: return {}
	if _sheets.has(key):
		return _sheets[key]
	var path := ROOT+key
	if FileAccess.file_exists(COMBAT_ROOT+key+".json"):
		path = COMBAT_ROOT+key
	if FileAccess.file_exists(TOPDOWN_ROOT+key+".json"):
		path = TOPDOWN_ROOT+key
	if not FileAccess.file_exists(path+".json"):
		path = FALLBACK_ROOT+key
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path+".json")) if FileAccess.file_exists(path+".json") else null
	if not parsed is Dictionary:
		return {}
	var texture_file := str(parsed.get("meta",{}).get("image",key+".png"))
	var texture_path := texture_file if texture_file.begins_with("res://") else (path.get_base_dir()+"/"+texture_file).simplify_path()
	if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path): return {}
	var meta: Dictionary = parsed.get("meta",{}).get("pixelfx",{})
	var size_value: Array = meta.get("frameSize",[])
	var pivot_value: Array = meta.get("pivot",[])
	var count := int(meta.get("frames",0))
	var fps := float(meta.get("fps",0.0))
	var columns := int(meta.get("columns",0))
	if size_value.size()!=2 or pivot_value.size()!=2 or count<=0 or fps<=0 or columns<=0:
		return {}
	if not _textures.has(texture_path):
		var loaded: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
		if loaded==null and FileAccess.file_exists(texture_path):
			var pixels := Image.load_from_file(texture_path)
			if pixels!=null and not pixels.is_empty(): loaded = ImageTexture.create_from_image(pixels)
		if loaded==null: return {}
		_textures[texture_path] = loaded
	var texture: Texture2D = _textures[texture_path]
	var size_px := Vector2i(int(size_value[0]),int(size_value[1]))
	if texture==null or size_px.x<=0 or size_px.y<=0:
		return {}
	var result := {"key":key,"texture":texture,"size":size_px,"pivot":Vector2(float(pivot_value[0]),float(pivot_value[1])),"columns":columns,"rows":ceili(float(count)/columns),"frames":count,"fps":fps,"duration":float(count)/fps}
	result["topdown"] = bool(meta.get("topdown",false))
	result["visual_radius_px"] = float(meta.get("visual_radius_px",maxi(size_px.x,size_px.y)*.5))
	result["visual_gain"] = float(meta.get("visual_gain",1.0))
	result["source_duration"] = float(meta.get("source_duration",float(count)/fps))
	result["alias_of"] = str(meta.get("alias_of",""))
	_sheets[key] = result
	return result

static func frame_at(value: Dictionary, age: float) -> int:
	return clampi(floori(maxf(0.0,age)*float(value.fps)),0,int(value.frames)-1)

static func frame_rect(value: Dictionary, index: int) -> Rect2:
	var frame_size := Vector2(value.size)
	return Rect2(Vector2(index%int(value.columns),index/int(value.columns))*frame_size,frame_size)

static func configure_3d(sprite: Sprite3D, value: Dictionary) -> void:
	sprite.texture = value.texture
	sprite.hframes = int(value.columns)
	sprite.vframes = int(value.rows)
	# pixelfx's pivot uses image Y-down, whereas Sprite3D's offset uses local Y-up.
	# Verified against Sprite3D.generate_triangle_mesh(), not only the offset property.
	var half := Vector2(value.size)*.5
	sprite.offset = Vector2(half.x-float(value.pivot.x),float(value.pivot.y)-half.y)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 49

static func apply_3d(sprite: Sprite3D, value: Dictionary, age: float, enabled: bool, opacity: float = 1.0) -> void:
	sprite.frame = frame_at(value,age)
	sprite.visible = enabled and age<float(value.duration)
	sprite.modulate.a = opacity
