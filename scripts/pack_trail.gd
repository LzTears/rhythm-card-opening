extends Node3D
## Actual pixelfx stamps follow each sampled segment through bounces.
const Atlas = preload("res://scripts/world_fx_atlas.gd")
const AtlasBatch = preload("res://scripts/world_atlas_batch.gd")
const KEEP_SECONDS := .62
const MAX_SAMPLES := 48
var samples: Array[Dictionary] = []
var phase := 0.0
var rendered_quads := 0
var _last_tick := -2147483648
var _last_frame := -1
var _batch
var _sheet: Dictionary = {}
var _records: Array = []

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_sheet = Atlas.sheet("trail")
	_batch = AtlasBatch.new()
	_batch.name = "PixelfxSpeedTrail"
	add_child(_batch)
	_batch.prepare([_sheet],&"speed_trail",false,MAX_SAMPLES)

func sample(at: Vector3, tick: int, velocity: Vector2) -> void:
	if tick==_last_tick: return
	if tick<_last_tick or (not samples.is_empty() and at.distance_to(samples.back().at)>1.5):
		samples.clear()
	_last_tick = tick
	samples.append({"at":at,"time":phase,"direction":Vector3(velocity.x,0,-velocity.y).normalized()})
	while samples.size()>MAX_SAMPLES: samples.pop_front()

func advance(delta: float, frozen: bool, reduced: bool) -> void:
	visible = not reduced
	if frozen: return
	phase += delta
	while not samples.is_empty() and phase-float(samples[0].time)>KEEP_SECONDS:
		samples.pop_front()
	var frame := floori(phase*30)
	if reduced or samples.size()<2 or _sheet.is_empty():
		_batch.clear()
		rendered_quads = 0
		_last_frame = -1
		return
	if frame==_last_frame: return
	_last_frame = frame
	_records.clear()
	for q in samples:
		var life := clampf(1.0-(phase-float(q.time))/KEEP_SECONDS,0,1)
		var forward: Vector3 = q.direction
		if forward.is_zero_approx(): continue
		var side := Vector3(-forward.z,0,forward.x)
		var at: Vector3 = q.at
		at.y = .018
		_records.append({"sheet":_sheet,"frame":(frame+int(float(q.time)*30))%int(_sheet.frames),"center":at,"right":forward,"up":side,"pixel_size":.0035*(.60+life*.40),"opacity":life*.88,"plane":&"speed_trail","no_depth_test":false})
	_batch.submit(_records)
	rendered_quads = _records.size()
