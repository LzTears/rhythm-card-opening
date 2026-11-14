extends Node
## Pace presentation after variable simulation work, without changing physics or input.
## Waiting at the end of CPU preparation avoids a fixed frame-start limiter turning
## short/long work pairs into alternating delivery intervals.
var target_fps := 60
var enabled := false
var paced_frames := 0
var sleep_usec := 0
var missed_deadlines := 0
var _deadline := 0.0
var _draw_started := 0
var _render_estimate := 1000.0
var _previous_max_fps := 60

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		return
	enabled = true
	_previous_max_fps = Engine.max_fps
	Engine.max_fps = 0
	RenderingServer.frame_pre_draw.connect(_before_draw)
	RenderingServer.frame_post_draw.connect(_after_draw)

func _before_draw() -> void:
	if not enabled:
		return
	var now := Time.get_ticks_usec()
	var period := 1000000.0/maxi(1,target_fps)
	if _deadline==0.0:
		_deadline = float(now)+period
	# A dragged/minimized window may suspend the process. Do not run a burst of
	# catch-up presentations afterwards; actual missed intervals remain measurable.
	if float(now)>_deadline+period:
		missed_deadlines += 1
		_deadline = float(now)+_render_estimate
	var draw_deadline := floori(_deadline-_render_estimate)
	var remaining := draw_deadline-now
	if remaining>350:
		var before := Time.get_ticks_usec()
		OS.delay_usec(remaining-250)
		sleep_usec += Time.get_ticks_usec()-before
	# Bound the final precision wait to a fraction of a millisecond.
	while Time.get_ticks_usec()<draw_deadline:
		pass
	_draw_started = Time.get_ticks_usec()

func _after_draw() -> void:
	if not enabled or _draw_started==0:
		return
	var duration := float(Time.get_ticks_usec()-_draw_started)
	_render_estimate = clampf(lerpf(_render_estimate,duration,.12),100.0,12000.0)
	_deadline += 1000000.0/maxi(1,target_fps)
	paced_frames += 1

func _exit_tree() -> void:
	if enabled:
		Engine.max_fps = _previous_max_fps
	enabled = false
