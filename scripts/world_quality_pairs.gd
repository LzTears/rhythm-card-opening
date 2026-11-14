extends RefCounted
## Strict source pairing for shared-buffer dual pass; original P/P+1 ordering remains.
const Source = preload("res://scripts/world_quality_catalog.gd")
const SUPPORTED_ELEMENTS = Source.SUPPORTED_ELEMENTS
const SUPPORTED_KINDS = Source.SUPPORTED_KINDS
const ROOT = Source.ROOT
const ELEMENT_ROOT = Source.ELEMENT_ROOT
const ELEMENT_ALIASES = Source.ELEMENT_ALIASES
const SHEET_KEYS = Source.SHEET_KEYS
const HEIGHT = Source.HEIGHT
const MAIN_PRIORITY = Source.MAIN_PRIORITY
const CHAIN_PRIORITY = Source.CHAIN_PRIORITY
const PATH_PRIORITY = Source.PATH_PRIORITY
const WAVE_PRIORITY = Source.WAVE_PRIORITY
const CONTACT_PRIORITY = Source.CONTACT_PRIORITY
const BURST_PRIORITY = Source.BURST_PRIORITY
const FRAGMENT_PRIORITY = Source.FRAGMENT_PRIORITY
const LIGHT_EXPOSURE = Source.LIGHT_EXPOSURE
static var _warm: Dictionary={}

static func element_id(value: Variant) -> String: return Source.element_id(value)
static func handles(event: Dictionary) -> bool: return Source.handles(event)
static func point(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2: return Source.point(value,fallback)
static func sheet(key: String, channel: String = "color") -> Dictionary: return Source.sheet(key,channel)

static func compatible(color: Dictionary, light: Dictionary) -> bool:
	if color.get("blend")!=&"mix" or light.get("blend")!=&"add": return false
	for value: Variant in [color.get("render_priority"),light.get("render_priority")]:
		if not value is int or value< -128 or value>127: return false
	if int(light.get("render_priority",-999))!=int(color.get("render_priority",999))+1: return false
	for field in ["center","right","up","pixel_size","frame","plane","no_depth_test","role","delay","lifetime"]:
		if color.get(field)!=light.get(field): return false
	var c: Dictionary=color.get("sheet",{})
	var l: Dictionary=light.get("sheet",{})
	if not c.is_read_only() or not l.is_read_only() or c.get("channel")!=&"color" or l.get("channel")!=&"light": return false
	for field in ["size","pivot","columns","rows","frames","fps","duration","source_duration","sample_end","body_radius_px","source_id"]:
		if c.get(field)!=l.get(field): return false
	for value: Dictionary in [c,l]:
		if not value.get("texture") is Texture2D: return false
		if value.texture.get_size()!=Vector2(value.size)*Vector2(value.columns,value.rows): return false
	return is_finite(float(color.get("opacity",1.0))) and is_finite(float(light.get("opacity",1.0)))

static func fuse(records: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var index:=0
	while index<records.size():
		var color: Dictionary=records[index]
		if index+1<records.size() and compatible(color,records[index+1]):
			var light: Dictionary=records[index+1]
			var pair:=color.duplicate()
			pair["light_sheet"]=light.sheet
			pair["light_opacity"]=float(light.get("opacity",1.0))
			pair["source_color_record"]=color
			pair["source_light_record"]=light
			pair["source_light_priority"]=int(light.render_priority)
			result.append(pair)
			index+=2
		else:
			result.append(color)
			index+=1
	return result

static func clips(event: Dictionary) -> Array[Dictionary]: return fuse(Source.clips(event))
static func visual_lifetime(event: Dictionary) -> float: return Source.visual_lifetime(event)
static func materials(element_value: String) -> Array[Dictionary]:
	var element:=element_id(element_value)
	if _warm.has(element): return _warm[element]
	var result:=fuse(Source.materials(element))
	for record: Dictionary in result: record.make_read_only()
	result.make_read_only()
	_warm[element]=result
	return result
