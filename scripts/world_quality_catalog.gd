extends RefCounted
## Authored visual catalog. Reads committed geometry, never selects targets or owns logic.
## Each returned clip is one color/light record for WorldAtlasBatch, not a skill event.
const ROOT := "res://assets/fx/quality15/"
const ELEMENT_ROOT := "res://assets/fx/quality17/"
const SECONDARY_ROOT := "res://assets/fx/secondary_hierarchy/"
const WORKSHOP_ROOT := "res://assets/fx/workshop/"
const SUPPORTED_ELEMENTS := ["E01","E02","E05"]
const ELEMENT_ALIASES := {"heavy":"E01","lightning":"E02","frost":"E05","ice":"E05"}
const SHEET_KEYS := ["heavy","thrust_E01","wave_E01","contact_E01",
	"main_E02","wave_E02","thrust_E02","contact_E02",
	"main_E05","wave_E05","thrust_E05","contact_E05",
	"ripple_E01","echo_E01","ripple_E02","echo_E02","ripple_E05","echo_E05","crystals_E05"]
const SUPPORTED_KINDS := ["native","pulse","echo","aftershock","bond_wave","extra_wave","bond","chain","penetration","pull","contact_spark","contact","wrapper_burst","wrapper_fragment"]
const HEIGHT := .075
const MAIN_PRIORITY := 45
const CHAIN_PRIORITY := 41
const PATH_PRIORITY := 39
const WAVE_PRIORITY := 35
const CONTACT_PRIORITY := 30
const BURST_PRIORITY := 26
const FRAGMENT_PRIORITY := 24
# Exposure is art direction for the bright wooden surface, not an effect budget.
# Every source frame, color/light record and authored lifetime is retained.
# Heavy's approved output remains exactly at its original 1.0 exposure.
const LIGHT_EXPOSURE := {"E02":.30,"E05":.32}
static var _metadata: Dictionary = {}
static var _sheets: Dictionary = {}
static var _textures: Dictionary = {}
static var _warm: Dictionary = {}

static func element_id(value: Variant) -> String:
	var id_value := str(value)
	return str(ELEMENT_ALIASES.get(id_value,id_value))

static func handles(event: Dictionary) -> bool:
	return element_id(event.get("element","")) in SUPPORTED_ELEMENTS and str(event.get("kind","native")) in SUPPORTED_KINDS

static func point(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size()>=2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float):
		return Vector2(float(value[0]),float(value[1]))
	return fallback

static func sheet(key: String, channel: String = "color") -> Dictionary:
	if key not in SHEET_KEYS: return {}
	var cache_key := key+":"+channel
	if _sheets.has(cache_key): return _sheets[cache_key]
	if channel not in ["color","light"]: return {}
	var asset_root := ROOT
	var asset_key := key
	if key=="crystals_E05":
		asset_root = WORKSHOP_ROOT+"E05/"
		asset_key = "crystals"
	elif key.begins_with("ripple_") or key.begins_with("echo_"):
		asset_root = SECONDARY_ROOT+key.get_slice("_",1)+"/"
		asset_key = key.get_slice("_",0)
	elif key!="heavy" and key.get_slice("_",1)!="E01":
		asset_root = ELEMENT_ROOT+key.get_slice("_",1)+"/"
		asset_key = "path" if key.begins_with("thrust_") else key.get_slice("_",0)
	if not _metadata.has(key):
		if not FileAccess.file_exists(asset_root+asset_key+".json"): return {}
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(asset_root+asset_key+".json"))
		if not parsed is Dictionary: return {}
		_metadata[key]=parsed
	var meta: Dictionary=_metadata[key]
	var texture_path := asset_root+str(meta[channel])
	if not _textures.has(texture_path):
		var texture: Texture2D=load(texture_path) if ResourceLoader.exists(texture_path) else null
		if texture==null and FileAccess.file_exists(texture_path):
			var pixels := Image.load_from_file(texture_path)
			if pixels!=null and not pixels.is_empty(): texture=ImageTexture.create_from_image(pixels)
		if texture==null: return {}
		_textures[texture_path]=texture
	var value := {"key":key+"_"+channel,"texture":_textures[texture_path],"size":Vector2i(int(meta.size[0]),int(meta.size[1])),"pivot":point(meta.pivot),"columns":int(meta.columns),"rows":int(meta.rows),"frames":int(meta.frames),"fps":float(meta.fps),"duration":float(meta.frames)/float(meta.fps),"source_duration":float(meta.source_duration),"sample_end":float(meta.sample_end),"body_radius_px":float(meta.body_radius_px),"channel":StringName(channel),"topdown":true,"source_id":str(meta.source_id)}
	value.make_read_only()
	_sheets[cache_key]=value
	return value

static func clips(event: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not handles(event): return result
	var element := element_id(event.element)
	var kind := str(event.get("kind","native"))
	var pos := point(event.get("corrected_pos",event.get("pos")),Vector2.INF)
	if not pos.is_finite(): return result
	var u := point(event.get("direction",event.get("u",Vector2(0,1))),Vector2(0,1)).normalized()
	if not u.is_finite() or u.is_zero_approx(): u=Vector2(0,1)
	var radius := maxf(0.0,float(event.get("radius",float(event.get("width",0))*.5)))*.01
	var core_radius := minf(radius,maxf(0.0,float(event.get("primary_radius",radius*100))*.01)) if kind in ["native","pulse"] else radius
	var main_key := "heavy" if element=="E01" else "main_"+element
	var center := _world(pos)
	match kind:
		"native","pulse":
			var main_axes := _axes(u)
			var secondary_pulse := kind=="pulse" or int(event.get("pulse_index",0))>0
			var secondary_branch := bool(event.get("presentation_secondary",false))
			if secondary_pulse or secondary_branch:
				# World groups real root events; the catalog stays a stateless mapping.
				# Each real branch/pulse retains a complete contact and its own short ripple.
				_pair(result,"contact_"+element,center,main_axes[0],main_axes[1],.012,&"pulse" if secondary_pulse else &"branch_contact",CHAIN_PRIORITY)
				_radial(result,"ripple_"+element,center,u,radius,&"pulse_ripple" if secondary_pulse else &"branch_ripple",WAVE_PRIORITY)
			else:
				var scale_value := maxf(.0001,core_radius)/float(sheet(main_key).body_radius_px)
				_pair(result,main_key,center,main_axes[0],main_axes[1],scale_value,&"main",MAIN_PRIORITY)
				if element=="E05":
					# One baked six-chip/two-star accent on the existing root's primary only.
					# Original main/coverage and every source frame remain unchanged.
					_pair(result,"crystals_E05",center,main_axes[0],main_axes[1],maxf(.0001,core_radius)/float(sheet("crystals_E05").body_radius_px),&"workshop_crystals",MAIN_PRIORITY+2)
			if not secondary_pulse and not secondary_branch and radius>core_radius+.00001:
				_radial(result,"wave_"+element,center,u,radius,&"coverage",WAVE_PRIORITY)
		"echo":
			# Independent complete echo art: immediate contact glint, contraction,
			# then a hollow outward pulse. No primary blast and no delayed logic.
			_radial(result,"echo_"+element,center,u,radius,&"echo_ring",CHAIN_PRIORITY)
		"aftershock","bond_wave","extra_wave","bond":
			_radial(result,"wave_"+element,center,u,radius,&"wave",WAVE_PRIORITY)
		"chain":
			var start := point(event.get("from",event.get("pos")),pos)
			var finish := point(event.get("to",event.get("corrected_pos",event.get("pos"))),pos)
			_path(result,element,start,finish,&"chain_path",PATH_PRIORITY)
			var direction := (finish-start).normalized()
			if direction.is_zero_approx(): direction=u
			var endpoint_axes := _axes(direction)
			# Chain targeting already names the real endpoint. A dedicated complete
			# contact clip reads as a travelling hit instead of a duplicate area cast.
			_pair(result,"contact_"+element,_world(finish),endpoint_axes[0],endpoint_axes[1],.0105,&"chain_endpoint",CHAIN_PRIORITY)
		"penetration","pull":
			var start := point(event.get("from",event.get("pos")),pos)
			var finish := point(event.get("to",event.get("corrected_pos",event.get("pos"))),pos)
			if not _path(result,element,start,finish,StringName(kind),PATH_PRIORITY):
				# A zero-length real event still has a complete local authored response.
				_auxiliary(result,event,element,finish,"contact_spark")
		"contact_spark","contact","wrapper_burst","wrapper_fragment":
			_auxiliary(result,event,element,pos,kind)
	if event.get("extension") is Dictionary:
		var extension: Dictionary=event.extension
		var start := point(extension.get("from",pos),pos)
		var finish := point(extension.get("to",pos),pos)
		_path(result,element,start,finish,&"penetration",PATH_PRIORITY)
	for extension: Dictionary in event.get("extensions",[]):
		_path(result,element,point(extension.get("from",pos),pos),point(extension.get("to",pos),pos),&"penetration",PATH_PRIORITY)
	return result

static func _axes(u: Vector2) -> Array[Vector3]:
	return [Vector3(u.x,0,-u.y),Vector3(-u.y,0,-u.x)]

static func _world(p: Vector2) -> Vector3:
	return Vector3(p.x*.01,HEIGHT,-p.y*.01)

static func _pair(result: Array[Dictionary], key: String, center: Vector3, right: Vector3, up: Vector3, pixel_size: float, role: StringName, priority: int) -> void:
	var plane_role := "wave" if role in [&"wave",&"coverage",&"echo_wave",&"pulse_wave"] else ("path" if role in [&"chain_path",&"penetration",&"pull"] else str(role))
	if role in [&"branch_ripple",&"pulse_ripple"]: plane_role="secondary_wave"
	# Batch's old echo profile softens a filled primary core; this ring is authored hollow.
	if role==&"echo_ring": plane_role="echoring"
	for channel: String in ["color","light"]:
		var value := sheet(key,channel)
		if value.is_empty(): continue
		var element := "E01" if key=="heavy" else key.get_slice("_",1)
		var authored_secondary := key.begins_with("ripple_") or key.begins_with("echo_")
		var exposure := (.72 if authored_secondary else float(LIGHT_EXPOSURE.get(element,1.0))) if channel=="light" else 1.0
		if role==&"echo": exposure*=.62
		elif plane_role=="wave": exposure*=.42 if role in [&"echo_wave",&"pulse_wave"] else .58
		var ground_layer := plane_role in ["wave","secondary_wave","echoring"]
		result.append({"sheet":value,"center":center,"right":right,"up":up,"pixel_size":pixel_size,"frame":0,"opacity":exposure,"plane":StringName("quality18_"+plane_role+"_"+element),"no_depth_test":not ground_layer,"blend":&"add" if channel=="light" else &"mix","render_priority":priority+(1 if channel=="light" else 0),"role":role,"delay":0.0,"lifetime":float(value.duration)})

static func _radial(result: Array[Dictionary], key: String, center: Vector3, u: Vector2, radius: float, role: StringName, priority: int) -> void:
	var axes := _axes(u)
	_pair(result,key,center,axes[0],axes[1],maxf(.0001,radius)/float(sheet(key).body_radius_px),role,priority)

static func _path(result: Array[Dictionary], element: String, start: Vector2, finish: Vector2, role: StringName, priority: int) -> bool:
	if not start.is_finite() or not finish.is_finite(): return false
	var delta := finish-start
	var distance := delta.length()*.01
	if distance<.000001: return false
	var direction := delta.normalized()
	var axes := _axes(direction)
	# Pixel size remains transverse .012m; only source X scales to real66px segment.
	_pair(result,"thrust_"+element,_world(start),axes[0]*(distance/(66.0*.012)),axes[1],.012,role,priority)
	return true

static func _auxiliary(result: Array[Dictionary], event: Dictionary, element: String, pos: Vector2, kind: String) -> void:
	var seed_value := int(event.get("seed",int(event.get("target_id",event.get("event_id",0)))))
	var phase := fposmod(float(seed_value)*2.399963229728653,TAU)
	var scale_value := .007
	var priority := CONTACT_PRIORITY
	var role: StringName=&"contact"
	if kind=="wrapper_burst":
		phase+=2.1
		scale_value=.0105
		priority=BURST_PRIORITY
		role=&"wrapper_burst"
	elif kind=="wrapper_fragment":
		phase+=4.2
		scale_value=.0045
		priority=FRAGMENT_PRIORITY
		role=&"wrapper_fragment"
		# Pure local paper scattering, never a displaced target/trajectory/logic event.
		pos+=Vector2(cos(phase),sin(phase))*18.0
	var axes := _axes(Vector2(cos(phase),sin(phase)))
	_pair(result,"contact_"+element,_world(pos),axes[0],axes[1],scale_value,role,priority)

static func visual_lifetime(event: Dictionary) -> float:
	var maximum := 0.0
	for clip: Dictionary in clips(event): maximum=maxf(maximum,float(clip.get("delay",0.0))+float(clip.lifetime))
	return maximum

static func materials(element_value: String) -> Array[Dictionary]:
	var element := element_id(element_value)
	if element not in SUPPORTED_ELEMENTS: return []
	if _warm.has(element): return _warm[element]
	var result: Array[Dictionary]=[]
	var seen: Dictionary={}
	for kind: String in SUPPORTED_KINDS:
		var event := {"element":element,"kind":kind,"pos":Vector2.ZERO,"from":Vector2(-100,0),"to":Vector2.ZERO,"radius":200.0,"primary_radius":50.0,"extension":{"from":Vector2.ZERO,"to":Vector2(100,0)}}
		var variants: Array[Dictionary]=[event]
		if kind=="native":
			var secondary := event.duplicate()
			secondary["presentation_secondary"]=true
			variants.append(secondary)
		for variant: Dictionary in variants:
			for clip: Dictionary in clips(variant):
				var key := str(clip.sheet.key)+":"+str(clip.plane)+":"+str(clip.blend)+":"+str(clip.render_priority)+":"+str(clip.no_depth_test)
				if seen.has(key): continue
				seen[key]=true
				var warm_record := clip.duplicate()
				warm_record["opacity"]=0.0
				warm_record.make_read_only()
				result.append(warm_record)
	result.make_read_only()
	_warm[element]=result
	return result

