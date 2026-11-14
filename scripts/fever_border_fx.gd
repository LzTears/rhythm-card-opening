extends Control
## Display-only Fever frame. board_rect is supplied in 1920x1080 design space.
## No hardware, random generator, combat effects, rewards or wall-clock time.
const DESIGN_SIZE := Vector2(1920,1080)
const BORDER_MARGIN := 12.0
const PARTICLE_LIMIT := 32
const BEAT_TICKS := 30
const ENTRY_TICKS := 18
const EXIT_TICKS := 10
const GOLD := Color("#ffd66b")
const ROSE := Color("#e8a0a6")
const CREAM := Color("#fff1c4")
var _initialized := false
var _active := false
var _paused := false
var _reduced := false
var _tick := -1
var _display_tick := -1
var _origin_tick := -1
var _entry_tick := -100000
var _exit_tick := -100000
var _entry_count := 0
var _run_id := ""
var _board := Rect2()
var _alpha := 0.0
var _phase := 0.0
var _pulse := 0.0
var _entry_strength := 0.0
var _particles: Array[Dictionary] = []
var _flows: Array[Dictionary] = []

func _ready() -> void:
	name = "FeverBorderFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	queue_redraw()

func set_state(state: Dictionary, paused: bool, reduced: bool, board_rect: Rect2) -> void:
	var now := int(state.get("tick",-1))
	var actual := bool(state.get("fever_active",false))
	var run_id := str(state.get("run_id",""))
	var restored := not _initialized or now<_tick or not run_id.is_empty() and not _run_id.is_empty() and run_id!=_run_id
	if restored:
		_initialized = true
		_active = actual
		_display_tick = now
		_origin_tick = now
		_entry_tick = -100000
		_exit_tick = -100000
		_entry_count = 0
	elif actual and not _active:
		_origin_tick = now
		_exit_tick = -100000
		if not paused and not reduced:
			_entry_tick = now
			_entry_count += 1
		else:
			_entry_tick = -100000
	elif not actual and _active:
		_exit_tick = now
		_entry_tick = -100000
	_active = actual
	_tick = now
	_run_id = run_id
	_paused = paused
	_reduced = reduced
	_board = board_rect
	if not paused: _display_tick = now
	if reduced: _entry_tick = -100000
	_rebuild()
	queue_redraw()

func clear_presentation() -> void:
	_initialized = false
	_active = false
	_paused = false
	_reduced = false
	_tick = -1
	_display_tick = -1
	_entry_tick = -100000
	_exit_tick = -100000
	_entry_count = 0
	_origin_tick = -1
	_run_id = ""
	_board = Rect2()
	_particles.clear()
	_flows.clear()
	_alpha = 0.0
	_phase = 0.0
	_pulse = 0.0
	_entry_strength = 0.0
	queue_redraw()

func _rebuild() -> void:
	var exit_age := maxi(0,_display_tick-_exit_tick)
	_alpha = 1.0 if _active else 1.0-smoothstep(0.0,float(EXIT_TICKS),float(exit_age)) if _exit_tick>-100000 and exit_age<EXIT_TICKS else 0.0
	if not _board.has_area(): _alpha = 0.0
	_phase = float(posmod(maxi(0,_display_tick-_origin_tick),240))/240.0 if not _reduced else 0.0
	_pulse = pow(1.0-float(posmod(maxi(0,_display_tick-_origin_tick),BEAT_TICKS))/BEAT_TICKS,2.0) if not _reduced else 0.0
	var entry_age := _display_tick-_entry_tick
	_entry_strength = 1.0-float(entry_age)/ENTRY_TICKS if not _reduced and entry_age>=0 and entry_age<ENTRY_TICKS else 0.0
	_particles.clear()
	_flows.clear()
	if _alpha<=0.0 or _reduced: return
	var perimeter := (_board.size.x+_board.size.y)*2.0
	var elapsed := maxi(0,_display_tick-_origin_tick)
	for index in range(8):
		var offset := float(index)/8.0*perimeter+elapsed*16.0
		var outward := 1.0+_pulse*.5+_entry_strength*.5
		var points := PackedVector2Array()
		for step in range(17):
			var point := _perimeter_point(offset+float(step)*9.0)
			points.append(Vector2(point.position)+Vector2(point.normal)*outward)
		_flows.append({"points":points,"color":"gold" if index%2==0 else "rose","offset":fposmod(offset,perimeter)})
	for index in range(PARTICLE_LIMIT):
		var travel := float(index)/PARTICLE_LIMIT*perimeter+elapsed*(1.7+float(index%4)*.45)
		var point := _perimeter_point(travel)
		var life := float(posmod(elapsed+index*7,96))/96.0
		var flutter := sin(life*TAU+index*.71)
		var outward := 3.0+flutter*2.0+_entry_strength*1.0
		var position := Vector2(point.position)+Vector2(point.normal)*outward
		_particles.append({"position":position,"radius":2.4+float(index%3)*.7,"alpha":_alpha*(.65+.35*sin(life*PI)),"kind":"paper" if index%3==0 else "spark","normal":point.normal})

func _perimeter_point(distance: float) -> Dictionary:
	var width := _board.size.x
	var height := _board.size.y
	var at := fposmod(distance,(width+height)*2.0)
	if at<width: return {"position":_board.position+Vector2(at,0),"normal":Vector2.UP}
	at -= width
	if at<height: return {"position":Vector2(_board.end.x,_board.position.y+at),"normal":Vector2.RIGHT}
	at -= height
	if at<width: return {"position":_board.end-Vector2(at,0),"normal":Vector2.DOWN}
	at -= width
	return {"position":Vector2(_board.position.x,_board.end.y-at),"normal":Vector2.LEFT}

func _draw() -> void:
	if _alpha<=0.0 or not _board.has_area(): return
	var canvas_scale := size/DESIGN_SIZE if size.x>0 and size.y>0 else Vector2.ONE
	draw_set_transform_matrix(Transform2D(0.0,canvas_scale,0.0,Vector2.ZERO))
	if _reduced:
		draw_rect(_board,Color(GOLD,_alpha*.42),false,1.5)
	else:
		draw_rect(_board,Color(ROSE,_alpha*(.22+.18*_pulse)),false,14.0)
		draw_rect(_board,Color(GOLD,_alpha*(.75+.25*_pulse)),false,4.0)
		draw_rect(_board.grow(-3.0),Color(GOLD,_alpha*(.5+.4*_pulse)),false,2.0)
		for flow: Dictionary in _flows:
			var tone := GOLD if str(flow.color)=="gold" else ROSE
			draw_polyline(flow.points,Color(tone,_alpha*.28),12.0,true)
			draw_polyline(flow.points,Color(CREAM,_alpha*(.85+.15*_pulse)),4.0+_pulse*2.0,true)
		for particle: Dictionary in _particles:
			var position: Vector2 = particle.position
			var radius := float(particle.radius)
			var tone := ROSE if str(particle.kind)=="paper" else CREAM
			if str(particle.kind)=="paper":
				var diamond := PackedVector2Array([position+Vector2(0,-radius),position+Vector2(radius,0),position+Vector2(0,radius),position+Vector2(-radius,0)])
				draw_colored_polygon(diamond,Color(tone,float(particle.alpha)))
			else:
				draw_circle(position,radius,Color(tone,float(particle.alpha)),true,-1.0,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func get_presentation_state() -> Dictionary:
	var samples: Array[Vector2] = []
	for flow: Dictionary in _flows:
		if not flow.points.is_empty(): samples.append(flow.points[0])
	return {"active":_active,"visible":_alpha>0.0,"tick":_tick,"display_tick":_display_tick,"paused":_paused,"reduced":_reduced,
		"board_rect":_board,"bounds":_board.grow(BORDER_MARGIN),"margin":BORDER_MARGIN,"alpha":_alpha,"phase":_phase,"pulse":_pulse,"beat_ticks":BEAT_TICKS,
		"entry_active":_entry_strength>0.0,"entry_strength":_entry_strength,"entry_tick":_entry_tick,"entry_count":_entry_count,
		"particles_count":_particles.size(),"particle_samples":_particles.duplicate(true),"flow_segments":_flows.size(),"flow_samples":samples,
		"clock":"simulation","uses_rng":false,"uses_energy":false,"canvas_scale":size/DESIGN_SIZE if size.x>0 and size.y>0 else Vector2.ONE}
