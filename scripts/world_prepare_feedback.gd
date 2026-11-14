extends RefCounted
## Visual interpolation of committed preparation events. No targets, HP, rewards,
## random rolls or response timing are chosen here. World owns the pause clock.
const Rules = preload("res://scripts/pack_rules.gd")
const BurstVisual = preload("res://scripts/world_skill_effect.gd")
const GRADE_COLORS: Array[Color] = [Color("#f0efdf"),Color("#5ce69b"),Color("#c282ff"),Color("#ffce58"),Color("#ff637a")]
const NORMAL_TONE := Color("#9bc4ac")
const FEVER_TONE := Color("#ffd36c")
const WORD_TONES := {"pata":Color("#ff9757"),"pon":Color("#72d7f5"),"don":Color("#ffd44f"),"chaka":Color("#a9df70")}
const RING_CODE := """shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,depth_test_disabled,shadows_disabled;
uniform vec4 tone : source_color = vec4(.61,.77,.67,.68);
uniform float buildup = 0.0;
uniform vec4 beat_tone : source_color = vec4(.65,.85,.75,1.0);
uniform float input_stage = 0.0;
uniform float response_stage = 0.0;
uniform float rhythm_pulse = 0.0;
uniform float formation = 0.0;
uniform float formation_phase = 0.0;
uniform float ornament = 0.0;
uniform float ornament_phase = 0.0;
uniform float beat_breath = 0.0;
uniform float beat_phase = 0.0;
uniform bool reduced = false;
float stroke(float d,float width,float aa) {
 return 1.0-smoothstep(width-aa,width+aa,abs(d));
}
void fragment() {
 vec2 p=UV-vec2(.5);
 float radius=length(p);
 float aa=max(max(fwidth(p.x),fwidth(p.y))*.8,.0004);
 // The .433 main contour is always the authoritative boundary. Every moving
 // contour is thinner and separately inset/outset; the main mesh never breathes.
 float breath=reduced ? 0.0 : beat_breath;
 float edge=stroke(radius-.433,.0038+breath*.0022+rhythm_pulse*.0024,aa);
 float ink=stroke(radius-.433,.0050,aa);
 float turn=mod(atan(p.y,p.x)+1.57079632679+6.28318530718,6.28318530718)/6.28318530718;
 float sector=floor(turn*4.0);
 float local=fract(turn*4.0);
 float gap=smoothstep(.045,.075,local)*(1.0-smoothstep(.925,.955,local));
 float stage=response_stage>0.0 ? response_stage : input_stage;
 float lit=step(sector+.5,stage);
 float current=1.0-step(.5,abs(sector-max(0.0,stage-1.0)));
 float segments=stroke(radius-.405,.0040+current*rhythm_pulse*.0015,aa)*gap;
 float segment_alpha=segments*(stage>0.0 ? .12+lit*(.53+rhythm_pulse*.27) : 0.0);
 float breathe=reduced ? 0.0 : stroke(radius-(.451+rhythm_pulse*.028),.0020,aa)*rhythm_pulse*.65;
 float seal=reduced ? 0.0 : stroke(radius-mix(.485,.443,formation_phase),.0026,aa)*formation*.82;
 float ready=reduced ? 0.0 : stroke(radius-(.365+buildup*.025),.0018,aa)*buildup*(.14+rhythm_pulse*.24);
 float fever_rim=reduced ? 0.0 : stroke(radius-mix(.446,.486,ornament_phase),.0020,aa)*ornament*.75;
 // Like the energy indicator, the decorative rim breathes continuously. The
 // true .433 contour and gameplay radius never move with this ornament.
 float idle_halo=reduced ? 0.0 : stroke(radius-(.455+breath*.025),.0018+breath*.0015,aa)*(.18+breath*.44);
 float orbit=reduced ? 0.0 : stroke(radius-.413,.0035,aa)*pow(max(0.0,cos((turn-beat_phase)*25.1327412)),12.0)*(.26+breath*.56);
 vec3 accent=response_stage>0.0 ? mix(tone.rgb,vec3(1.0,.87,.51),.65) : beat_tone.rgb;
 float boundary=edge*min(1.0,tone.a+buildup*.14+rhythm_pulse*.16);
 float decoration=max(max(idle_halo,orbit),max(segment_alpha,max(breathe,max(seal,max(ready,fever_rim)))));
 ALBEDO=mix(mix(vec3(.10,.15,.15),accent,decoration),mix(tone.rgb,vec3(1.0,.99,.89),rhythm_pulse*.3),edge);
 ALPHA=max(boundary,max(ink*.18,decoration));
}"""

var world
var enabled := false
var center := Vector2(0,300)
var radius := 106.5
var actual_radius := 106.5
var base_radius := 106.5
var fever := false
var fever_mix := 0.0
var buildup := 0.0
var _ring_from := 106.5
var _ring_age := .2
var _ring_material: ShaderMaterial
var _ring_tick := -1
var _ring_input_stage := 0
var _ring_response_stage := 0
var _rhythm_pulse_tick := -100000
var _formation_tick := -100000
var _ornament_tick := -100000
var _input_pulse_count := 0
var _formation_count := 0
var _response_pulse_count := 0
var _beat_tone := NORMAL_TONE
var _rhythm_seen: Dictionary = {}
var _motions: Dictionary = {}
var _outlines: Dictionary = {}
var _hidden: Dictionary = {}
var _windup: Dictionary = {}
var _windup_level := ""
var _windup_source_tick := -1
var _merges: Array[Dictionary] = []
var _seen: Dictionary = {}
var _initialized := false

func configure(owner) -> void:
	world = owner
	var shader := Shader.new()
	shader.code = RING_CODE
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = shader
	_ring_material.render_priority = 90

func sync_state(state: Dictionary) -> void:
	if not state.has("circle_radius"):
		return
	var next_tick := int(state.get("tick",_ring_tick))
	if not _initialized or next_tick<_ring_tick:
		_reset_rhythm_feedback()
		var echo: Dictionary = state.get("active_echo",{})
		if bool(echo.get("started",false)):
			_ring_response_stage = clampi(int(echo.get("beat",-1))+1,0,4)
		elif not echo.is_empty():
			# Scheduled fast input still owns all four accepted words until the
			# first actual response, including a freshly restored presentation.
			for word in echo.get("sequence",[]):
				if WORD_TONES.has(str(word)): _ring_input_stage += 1
		elif str(state.get("phase",""))=="input":
			for word in state.get("buffer",[]):
				if WORD_TONES.has(str(word)): _ring_input_stage += 1
	_ring_tick = next_tick
	if state.has("phase") and str(state.phase)=="idle":
		_ring_input_stage = 0
		_ring_response_stage = 0
		buildup = 0.0
	enabled = true
	center = _point(state.get("circle_center",Vector2(0,300)))
	base_radius = float(state.get("base_radius",106.5))
	var new_radius := float(state.circle_radius)
	var new_fever := bool(state.get("fever_active",false))
	if not _initialized:
		radius = new_radius
		actual_radius = new_radius
		_ring_from = new_radius
		fever_mix = 1.0 if new_fever else 0.0
		_initialized = true
	elif not is_equal_approx(new_radius,actual_radius):
		_ring_from = radius
		_ring_age = 0.0
	actual_radius = new_radius
	fever = new_fever
	world.aim_ring.material_override = _ring_material
	_update_ring()

func set_battle(battle: bool, progress: float) -> void:
	world.aim_point = center
	world.aim_ring.visible = battle
	world.charge_ring.visible = false
	world._skill_aim.visible = false
	world._focus_aim.visible = false
	if progress<=0.0:
		buildup = 0.0
	_update_ring()

func handles(event: Dictionary) -> bool:
	return str(event.get("kind",event.get("type",""))) in ["pull","pull_preview","gather","circle_expand","expand","merge","burst_windup","burst","refill","fever_enter","preparation_reset","rhythm_response","rhythm_judgement"]

func present(event: Dictionary) -> void:
	if event.has("executed") and not bool(event.executed): return
	var kind := str(event.get("kind",event.get("type","")))
	if event.has("event_id") and int(event.event_id)>0:
		var key := "%s/%s" % [kind,str(event.event_id)]
		if _seen.has(key): return
		_seen[key] = true
	match kind:
		"rhythm_response":
			if not bool(event.get("executed",false)) or not _new_rhythm_event(event): return
			var preset := str(event.get("preset_id",event.get("command_id","")))
			var word := int(event.get("word_index",0))
			_ring_response_stage = clampi(word+1,0,4)
			_ring_input_stage = 0
			_response_pulse_count += 1
			_rhythm_pulse_tick = int(event.get("tick",_ring_tick))
			buildup = float(_ring_response_stage)/4.0
			if preset=="gather" and word<3:
				_mark_ids(event.get("selected_ids",[]),NORMAL_TONE,.62)
		"rhythm_judgement":
			if str(event.get("scope",""))=="phrase": return
			if not _new_rhythm_event(event): return
			if str(event.get("grade",event.get("judgement","")))=="miss" or str(event.get("reason","")) in ["too_fast","timeout","unknown"]:
				buildup = 0.0
				_clear_rhythm_stages()
				_clear_outlines()
			elif bool(event.get("accepted",false)):
				var word := int(event.get("word_index",event.get("beat",-1)))
				var key := str(event.get("key",""))
				if word<0 or word>3 or not WORD_TONES.has(key): return
				_ring_input_stage = word+1
				_ring_response_stage = 0
				_beat_tone = WORD_TONES[key]
				_rhythm_pulse_tick = int(event.get("tick",_ring_tick))
				_input_pulse_count += 1
				if word==3:
					_formation_tick = _rhythm_pulse_tick
					_formation_count += 1
		"pull_preview":
			_mark_ids(event.get("targets",event.get("selected_ids",[])),NORMAL_TONE,1.6)
		"pull", "gather":
			for move_value in event.get("moves",[]):
				var move: Dictionary = move_value
				var id_value := int(move.get("target_id",0))
				_motions[id_value] = {"from":_point(move.get("from",Vector2.ZERO)),"to":_point(move.get("to",Vector2.ZERO)),"age":0.0,"duration":.18,"paper_step":-1}
			_mark_ids(event.get("targets",[]),NORMAL_TONE,.32)
		"circle_expand", "expand":
			buildup = 0.0
			if bool(event.get("at_cap",false)):
				_ornament_tick = int(event.get("tick",_ring_tick))
			else:
				var next_radius := float(event.get("new_radius",event.get("radius",actual_radius)))
				_ring_from = radius
				actual_radius = next_radius
				_ring_age = 0.0
			_mark_ids(event.get("newly_inside",[]),FEVER_TONE if fever else NORMAL_TONE,.30)
		"merge":
			_merge(event.get("groups",[]))
		"burst_windup":
			_release_windup()
			_windup_level = BurstVisual.attack_level(event)
			_windup_source_tick = int(event.get("tick",_ring_tick))
			for id_value in event.get("target_ids",[]):
				_windup[int(id_value)] = 0.0
			var full := _windup_level=="fever_full"
			_mark_ids(event.get("target_ids",[]) if full else event.get("in_circle_ids",[]),Color("#fff1c4") if full else FEVER_TONE,.55,.014 if full else .009)
		"burst":
			_release_windup()
			var wave := event.duplicate(true)
			wave["kind"] = "burst_wave"
			wave["pos"] = center
			wave["attack_level"] = BurstVisual.attack_level(event)
			wave["radius"] = _board_radius() if wave.attack_level=="fever_full" else actual_radius
			world._present_preparation_wave(wave)
		"fever_enter":
			_ornament_tick = int(event.get("tick",_ring_tick))
			fever = true
		"preparation_reset":
			_release_windup()
			buildup = 0.0
			_clear_rhythm_stages()
			fever = false
			_ring_from = radius
			actual_radius = float(event.get("radius",base_radius))
			_ring_age = 0.0
			_clear_outlines()
	_update_ring()

func _new_rhythm_event(event: Dictionary) -> bool:
	var token := "%s/%s/%s/%s" % [str(event.get("type","")),str(event.get("tick",_ring_tick)),str(event.get("command_serial",event.get("input_index",0))),str(event.get("word_index",event.get("beat",-1)))]
	if _rhythm_seen.has(token): return false
	_rhythm_seen[token] = true
	return true

func _clear_rhythm_stages() -> void:
	_ring_input_stage = 0
	_ring_response_stage = 0
	_rhythm_pulse_tick = -100000
	_formation_tick = -100000
	_ornament_tick = -100000

func _reset_rhythm_feedback() -> void:
	_clear_rhythm_stages()
	_rhythm_seen.clear()
	_input_pulse_count = 0
	_formation_count = 0
	_response_pulse_count = 0
	_beat_tone = NORMAL_TONE

func _tick_strength(at: int, life: int) -> float:
	if at<=-100000: return 0.0
	return 1.0-smoothstep(0.0,float(life),float(maxi(0,_ring_tick-at)))

func pack_position(target: Dictionary, fallback: Vector3) -> Vector3:
	var id_value := int(target.id)
	if not _motions.has(id_value): return fallback
	var move: Dictionary = _motions[id_value]
	var t := clampf(float(move.age)/float(move.duration),0.0,1.0)
	return world.table_to_world((move.from as Vector2).lerp(move.to,t))+Vector3(0,float(world._visual_slots.get(id_value,0))*world.SLOT_HEIGHT,0)

func pack_visible(id_value: int) -> bool:
	return not _hidden.has(id_value)

func advance(delta: float, paused: bool) -> void:
	if not enabled or paused: return
	_ring_age = minf(.2,_ring_age+delta)
	radius = lerpf(_ring_from,actual_radius,smoothstep(0.0,.2,_ring_age))
	fever_mix = move_toward(fever_mix,1.0 if fever else 0.0,delta/.2)
	_update_ring()
	for id_value in _motions.keys():
		var move: Dictionary = _motions[id_value]
		move.age = float(move.age)+delta
		var paper_step := mini(2,floori(float(move.age)/.06))
		if not world.reduce_effects and paper_step>int(move.paper_step) and float(move.age)<=float(move.duration):
			move.paper_step = paper_step
			var paper_point: Vector2 = (move.from as Vector2).lerp(move.to,clampf(float(move.age)/float(move.duration),0.0,1.0))
			world._contact_sparks(world.table_to_world(paper_point),id_value+paper_step,2)
		if world.cards.has(id_value):
			var node: Node3D = world.cards[id_value]
			node.position = pack_position({"id":id_value},node.position)
			var print_node: Node3D = node.get_node("Print")
			if float(move.age)>=float(move.duration):
				var settle := clampf((float(move.age)-float(move.duration))/.12,0.0,1.0)
				var squeeze := (1.0-settle)*(.035 if world.reduce_effects else .09)
				print_node.scale = Vector3(1.0+squeeze,1.0,1.0-squeeze)
		if float(move.age)>=float(move.duration)+.12:
			_motions.erase(id_value)
	for id_value in _outlines.keys():
		var record: Dictionary = _outlines[id_value]
		record.age = float(record.age)+delta
		if not is_instance_valid(record.node) or float(record.age)>=float(record.duration):
			if is_instance_valid(record.node): record.node.queue_free()
			_outlines.erase(id_value)
		else:
			var mat: StandardMaterial3D = record.node.material_override
			var tone: Color = record.color
			tone.a *= minf(1.0,(float(record.duration)-float(record.age))/.12)
			mat.albedo_color = tone
	for id_value in _windup.keys():
		_windup[id_value] = minf(.5,float(_windup[id_value])+delta)
		if world.cards.has(id_value):
			var at := clampf(float(_windup[id_value])/.22,0.0,1.0)
			var full := _windup_level=="fever_full"
			var width := .012 if world.reduce_effects else .065 if full else .035
			var compression := (.045 if full else .025) if world.reduce_effects else (.22 if full else .12)
			world.cards[id_value].get_node("Print").scale = Vector3(1.0+at*width,1.0,1.0-at*compression)
	_advance_merges(delta)

func _update_ring() -> void:
	if not enabled or not is_instance_valid(world.aim_ring): return
	(world.aim_ring.mesh as PlaneMesh).size = Vector2.ONE*maxf(1.0,radius)*.01/.433
	world.aim_ring.position = world.table_to_world(center)+Vector3(0,.012,0)
	var tone := NORMAL_TONE.lerp(FEVER_TONE,fever_mix)
	tone.a = lerpf(.82,.94,fever_mix)
	_ring_material.set_shader_parameter("tone",tone)
	_ring_material.set_shader_parameter("buildup",buildup)
	_ring_material.set_shader_parameter("beat_tone",_beat_tone)
	_ring_material.set_shader_parameter("input_stage",float(_ring_input_stage))
	_ring_material.set_shader_parameter("response_stage",float(_ring_response_stage))
	_ring_material.set_shader_parameter("rhythm_pulse",_tick_strength(_rhythm_pulse_tick,16))
	_ring_material.set_shader_parameter("formation",_tick_strength(_formation_tick,24))
	_ring_material.set_shader_parameter("formation_phase",clampf(float(maxi(0,_ring_tick-_formation_tick))/18.0,0.0,1.0))
	_ring_material.set_shader_parameter("ornament",_tick_strength(_ornament_tick,20))
	_ring_material.set_shader_parameter("ornament_phase",clampf(float(maxi(0,_ring_tick-_ornament_tick))/20.0,0.0,1.0))
	_ring_material.set_shader_parameter("beat_breath",_continuous_ring_breath())
	_ring_material.set_shader_parameter("beat_phase",float(posmod(maxi(0,_ring_tick),120))/120.0)
	_ring_material.set_shader_parameter("reduced",world.reduce_effects)

func _continuous_ring_breath() -> float:
	if world.reduce_effects: return 0.0
	var origin := maxi(0,_rhythm_pulse_tick)
	var age := float(posmod(maxi(0,_ring_tick-origin),30))/30.0
	return pow(1.0-age,2.0)

func _mark_ids(ids: Array, color: Color, duration: float, thickness: float = .009) -> void:
	for raw_id in ids:
		var id_value := int(raw_id)
		if not world.cards.has(id_value): continue
		if _outlines.has(id_value) and is_instance_valid(_outlines[id_value].node): _outlines[id_value].node.queue_free()
		var parent: Node3D = world.cards[id_value].get_node("Print")
		var grade := int(world.cards[id_value].get_meta("pack_grade",0))
		var outline := _outline(parent,grade,color,thickness)
		_outlines[id_value] = {"node":outline,"age":0.0,"duration":duration,"color":color}

func _outline(parent: Node3D, grade: int, color: Color, thickness: float = .009) -> MeshInstance3D:
	var size_value: Vector2 = world._geo.pack_art_size(grade)+Vector2.ONE*.035
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size_value*.5
	for segment in [[Vector2(-half.x,-half.y),Vector2(half.x,-half.y)],[Vector2(half.x,-half.y),Vector2(half.x,half.y)],[Vector2(half.x,half.y),Vector2(-half.x,half.y)],[Vector2(-half.x,half.y),Vector2(-half.x,-half.y)]]:
		var start: Vector2 = segment[0]
		var finish: Vector2 = segment[1]
		var normal := (finish-start).orthogonal().normalized()*thickness
		for vertex: Vector2 in [start-normal,start+normal,finish-normal,start+normal,finish+normal,finish-normal]:
			mesh.surface_add_vertex(Vector3(vertex.x,.014,vertex.y))
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 94
	material.albedo_color = color
	var node: MeshInstance3D = world._geo.instance(mesh,material,Vector3.ZERO,parent)
	node.name = "CommittedPackOutline"
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _merge(groups: Array) -> void:
	if groups.is_empty(): return
	var grades: Array[int] = []
	for raw in groups:
		var grade := int(raw.get("from_grade",0))
		if not grades.has(grade): grades.append(grade)
	grades.sort()
	var step := .60/float(maxi(1,grades.size()))
	for raw in groups:
		var group: Dictionary = raw
		var result: Dictionary = group.get("result",{})
		if result.is_empty(): continue
		var stage := grades.find(int(group.get("from_grade",0)))
		var record := {"age":0.0,"start":stage*step,"duration":step,"result":result,"clones":[],"result_clone":null}
		_hidden[int(result.id)] = .60
		for material in group.get("materials",[]):
			var snapshot: Dictionary = material
			var clone := _clone_pack(snapshot)
			clone.visible = stage==0
			_outline(clone.get_node("Print"),int(snapshot.get("pack_grade",0)),GRADE_COLORS[clampi(int(snapshot.get("pack_grade",0)),0,4)])
			record.clones.append({"node":clone,"from":_point(snapshot.get("pos",center))})
			_hidden[int(snapshot.id)] = .60
			if world.cards.has(int(snapshot.id)): world.cards[int(snapshot.id)].visible = false
		var result_clone := _clone_pack(result)
		result_clone.visible = false
		_outline(result_clone.get_node("Print"),int(result.get("pack_grade",0)),GRADE_COLORS[clampi(int(result.get("pack_grade",0)),0,4)])
		record.result_clone = result_clone
		_merges.append(record)

func _clone_pack(snapshot: Dictionary) -> Node3D:
	var node := Node3D.new()
	world._effects.add_child(node)
	node.name = "CommittedMergeMaterial"
	node.position = world.table_to_world(_point(snapshot.get("pos",center)))
	var print_node := Node3D.new()
	print_node.name = "Print"
	node.add_child(print_node)
	print_node.basis = world._pack_face_basis(fmod(float(snapshot.id)*2.39996,TAU))
	print_node.position = world.camera.basis.z*world.PACK_VIEW_DEPTH
	var grade := clampi(int(snapshot.get("pack_grade",0)),0,4)
	var material: ShaderMaterial = world._geo.pack_material(grade,false)
	material.set_shader_parameter("reduced",world.reduce_effects)
	var ratio := float(snapshot.get("remaining",1.0))/maxf(.001,float(snapshot.get("max_hp",1.0)))
	material.set_shader_parameter("damage_level",0 if ratio>=1.0 else 1 if ratio>.6 else 2 if ratio>.3 else 3)
	material.render_priority = 50
	world._geo.instance(world._geo.pack_surface(grade),material,Vector3.ZERO,print_node)
	return node

func _advance_merges(delta: float) -> void:
	for index in range(_merges.size()-1,-1,-1):
		var record: Dictionary = _merges[index]
		record.age = float(record.age)+delta
		var t := clampf((float(record.age)-float(record.start))/float(record.duration),0.0,1.0)
		var started := float(record.age)>=float(record.start)
		var destination := _point(record.result.get("pos",center))
		for clone_record in record.clones:
			var clone: Node3D = clone_record.node
			if not is_instance_valid(clone): continue
			clone.visible = started and t<.78
			clone.position = world.table_to_world((clone_record.from as Vector2).lerp(destination,clampf(t/.78,0.0,1.0)))
			clone.get_node("Print").scale = Vector3.ONE*lerpf(1.0,.62,clampf(t/.78,0.0,1.0))
		var result_clone: Node3D = record.result_clone
		if is_instance_valid(result_clone):
			result_clone.visible = started and t>=.78
			var confirm := clampf((t-.78)/.22,0.0,1.0)
			result_clone.get_node("Print").scale = Vector3(lerpf(1.08,1.0,confirm),1.0,lerpf(.92,1.0,confirm))
		if float(record.age)>=float(record.start)+float(record.duration):
			for clone_record in record.clones:
				if is_instance_valid(clone_record.node): clone_record.node.queue_free()
			if is_instance_valid(result_clone): result_clone.queue_free()
			_merges.remove_at(index)
	for id_value in _hidden.keys():
		_hidden[id_value] = float(_hidden[id_value])-delta
		if float(_hidden[id_value])<=0.0:
			_hidden.erase(id_value)
			if world.cards.has(id_value): world.cards[id_value].visible = true

func _release_windup() -> void:
	for id_value in _windup:
		if world.cards.has(id_value): world.cards[id_value].get_node("Print").scale = Vector3.ONE
	_windup.clear()
	_windup_level = ""
	_windup_source_tick = -1

func _clear_outlines() -> void:
	for record in _outlines.values():
		if is_instance_valid(record.node): record.node.queue_free()
	_outlines.clear()

func clear() -> void:
	_release_windup()
	_clear_outlines()
	for record in _merges:
		for clone_record in record.clones:
			if is_instance_valid(clone_record.node): clone_record.node.queue_free()
		if is_instance_valid(record.result_clone): record.result_clone.queue_free()
	_merges.clear()
	_motions.clear()
	_hidden.clear()
	_seen.clear()
	_initialized = false
	enabled = false
	buildup = 0.0
	_ring_tick = -1
	_reset_rhythm_feedback()
	if is_instance_valid(world) and is_instance_valid(world.aim_ring): world.aim_ring.material_override = world._guide_material

func snapshot() -> Dictionary:
	var scales: Dictionary = {}
	for id_value in _windup:
		if world.cards.has(id_value): scales[id_value] = world.cards[id_value].get_node("Print").scale
	return {"enabled":enabled,"center":center,"radius":radius,"actual_radius":actual_radius,"fever":fever,"fever_mix":fever_mix,"motions":_motions.size(),"merge_groups":_merges.size(),"hidden_results":_hidden.size(),"windup_targets":_windup.size(),"windup_level":_windup_level,"windup_source_tick":_windup_source_tick,"windup_scales":scales,"outlines":_outlines.size(),"ring_tick":_ring_tick,"input_stage":_ring_input_stage,"response_stage":_ring_response_stage,"input_pulse_count":_input_pulse_count,"formation_count":_formation_count,"response_pulse_count":_response_pulse_count,"ring_pulse_strength":_tick_strength(_rhythm_pulse_tick,16),"formation_strength":_tick_strength(_formation_tick,24),"outer_breath":0.0 if world.reduce_effects else _tick_strength(_rhythm_pulse_tick,16),"decorative_only":true,"continuous_breath":_continuous_ring_breath(),"continuous_period_ticks":30}

func _board_radius() -> float:
	var maximum := 0.0
	for x in [-Rules.TABLE_HALF_WIDTH,Rules.TABLE_HALF_WIDTH]:
		for y in [0.0,Rules.TABLE_DEPTH]:
			maximum = maxf(maximum,center.distance_to(Vector2(x,y)))
	return maximum

func _point(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	return center
