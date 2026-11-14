extends Control
## One truthful grade group from one claim. Arrival is an audio cue, never a ledger update.
signal arrived
const Atlas = preload("res://scripts/world_fx_atlas.gd")
var origin := Vector2.ZERO
var sink := Vector2.ZERO
var amount := 1
var grade := 0
var age := 0.0
var delay := 0.0
var flight_duration := .36
var reduced := false
var _arrived := false
var _texture: Texture2D
var _font: Font
var _sparkle: Dictionary = {}
var _duration := .90
var _keepout := Rect2()
var _route: Array[Vector2] = []
var _route_start := 0.0
var _route_length := 0.0
var _route_side := -1
var _exit_length := 0.0
var _exit_travel := 0.0
var _footprint := Rect2(-28,-28,66,68)
const ROUTE_GAP := 4.0
const SOURCE_EXIT_MAX_FRACTION := .16

func configure(card_texture: Texture2D, from: Vector2, to: Vector2, actual_grade: int, count: int, order: int, font: Font, quiet: bool) -> void:
	name = "RewardGrade%d" % actual_grade
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	origin = from
	sink = to
	position = from
	grade = actual_grade
	amount = count
	delay = float(order)*.025
	_font = font
	_texture = card_texture
	reduced = quiet
	_sparkle = Atlas.sheet("harvest_card")
	_duration = delay+flight_duration+float(_sparkle.get("duration",.533))
	set_meta("grade",grade)
	set_meta("card_count",amount)
	set_meta("source",origin)
	set_meta("sink",sink)
	set_meta("generic",true)
	if count>1:
		var text_width := font.get_string_size("+%d" % count,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		_footprint.size.x = maxf(_footprint.size.x,18+text_width+4-_footprint.position.x)
	queue_redraw()

func sample_position(progress: float) -> Vector2:
	if progress<=0.0: return origin
	if progress>=1.0: return sink
	var travel := smoothstep(0.0,1.0,clampf(progress,0,1))
	if not _route.is_empty():
		var fraction := clampf((travel-_route_start)/maxf(.000001,1.0-_route_start),0,1)
		var remaining := fraction*_route_length
		if _exit_length>0.0 and _exit_travel>0.0:
			remaining = fraction/_exit_travel*_exit_length if fraction<=_exit_travel else _exit_length+(fraction-_exit_travel)/maxf(.000001,1.0-_exit_travel)*(_route_length-_exit_length)
		for index in range(1,_route.size()):
			var length := _route[index-1].distance_to(_route[index])
			if remaining<=length:
				return _route[index-1].lerp(_route[index],remaining/maxf(.000001,length))
			remaining -= length
		return sink
	return origin.lerp(sink,travel)+Vector2(float(grade-2)*12.0,-60.0)*sin(travel*PI)

func set_operation_keepout(keepout: Rect2, viewport_size: Vector2) -> void:
	if keepout==_keepout or _arrived:
		return
	_keepout = keepout
	var progress := clampf((age-delay)/flight_duration,0,1)
	var from := position if progress>0 else origin
	_route_start = smoothstep(0.0,1.0,progress)
	var obstacle := Rect2()
	if keepout.has_area():
		# Minkowski expansion covers the complete stack and visible +quantity.
		obstacle = Rect2(keepout.position-_footprint.end,keepout.size+_footprint.size).grow(ROUTE_GAP)
	var departure := _nearest_exit(from,obstacle,viewport_size) if obstacle.has_point(from) else from
	var entry := _nearest_exit(sink,obstacle,viewport_size) if obstacle.has_point(sink) else sink
	var middle := _outside_route(departure,entry,obstacle,viewport_size)
	_route.clear()
	_route.append(from)
	if departure!=from: _route.append(departure)
	for point in middle:
		if point!=_route[-1]: _route.append(point)
	if _route[-1]!=sink: _route.append(sink)
	_route_length = 0.0
	for index in range(1,_route.size()):
		_route_length += _route[index-1].distance_to(_route[index])
	_exit_length = from.distance_to(departure)
	_exit_travel = 0.0
	if _exit_length>0.0:
		var exit_progress := progress+(1.0-progress)*SOURCE_EXIT_MAX_FRACTION
		_exit_travel = clampf((smoothstep(0.0,1.0,exit_progress)-_route_start)/maxf(.000001,1.0-_route_start),.000001,.999999)
	set_meta("operation_source_inside",obstacle.has_point(from))
	set_meta("operation_sink_inside",obstacle.has_point(sink))
	set_meta("operation_route",_route.duplicate())

func _nearest_exit(point: Vector2, obstacle: Rect2, viewport_size: Vector2) -> Vector2:
	if not obstacle.has_area(): return point
	var candidates := [Vector2(obstacle.position.x-2,point.y),Vector2(obstacle.end.x+2,point.y),Vector2(point.x,obstacle.position.y-2),Vector2(point.x,obstacle.end.y+2)]
	var best := INF
	var result := point
	for candidate: Vector2 in candidates:
		if candidate.x<0 or candidate.x>viewport_size.x or candidate.y<0 or candidate.y>viewport_size.y:
			continue
		var score := point.distance_squared_to(candidate)
		if score<best:
			best = score
			result = candidate
	return result

func _segment_hits(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if not rect.has_area(): return false
	var low := 0.0
	var high := 1.0
	var delta := b-a
	for axis in range(2):
		if absf(delta[axis])<.000001:
			if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]: return false
		else:
			var first := (rect.position[axis]-a[axis])/delta[axis]
			var second := (rect.end[axis]-a[axis])/delta[axis]
			low = maxf(low,minf(first,second))
			high = minf(high,maxf(first,second))
			if high<low: return false
	return true

func _outside_route(from: Vector2, to: Vector2, obstacle: Rect2, viewport_size: Vector2) -> Array[Vector2]:
	if not _segment_hits(from,to,obstacle): return [to]
	var box := obstacle.grow(3.0)
	var corners: Array[Vector2] = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
	var best := INF
	var selected: Array[Vector2] = [to]
	var preferred := _route_side
	var selected_side := _route_side
	for first in range(4):
		for second in range(4):
			var a := corners[first]
			var b := corners[second]
			if a.x<0 or a.x>viewport_size.x or a.y<0 or a.y>viewport_size.y or b.x<0 or b.x>viewport_size.x or b.y<0 or b.y>viewport_size.y:
				continue
			if _segment_hits(from,a,obstacle) or _segment_hits(a,b,obstacle) or _segment_hits(b,to,obstacle):
				continue
			var score := from.distance_to(a)+a.distance_to(b)+b.distance_to(to)
			if preferred>=0 and first!=preferred: score += 96.0
			if score<best:
				best = score
				selected = [a,b,to]
				selected_side = first
	_route_side = selected_side
	return selected

func advance(delta: float, frozen: bool, quiet: bool) -> void:
	var changed := reduced!=quiet
	reduced = quiet
	if frozen:
		if changed:
			queue_redraw()
		return
	age += delta
	var progress := clampf((age-delay)/flight_duration,0,1)
	position = sample_position(progress).round()
	if not _arrived and age>=delay+flight_duration:
		_arrived = true
		arrived.emit()
	if age>=_duration:
		queue_free()
		return
	queue_redraw()

func _sparkle_at(point: Vector2, local_age: float, scale_value: float) -> void:
	if reduced or _sparkle.is_empty() or local_age<0.0 or local_age>=float(_sparkle.duration):
		return
	var size_value := Vector2(_sparkle.size)*scale_value
	var pivot := Vector2(_sparkle.pivot)*scale_value
	draw_texture_rect_region(_sparkle.texture,Rect2((point-position-pivot).round(),size_value),Atlas.frame_rect(_sparkle,Atlas.frame_at(_sparkle,local_age)))

func _draw() -> void:
	_sparkle_at(origin,age-delay,.70)
	_sparkle_at(sink,age-delay-flight_duration,.52)
	if age<delay or _arrived or _texture==null:
		return
	var progress := clampf((age-delay)/flight_duration,0,1)
	var diameter := float(roundi(lerpf(48.0,24.0,smoothstep(.55,1.0,progress))))
	var layers := mini(3,amount)
	for index in range(layers):
		var offset := Vector2(float(index-layers+1)*-5.0,float(index-layers+1)*-4.0)
		draw_texture_rect(_texture,Rect2((offset-Vector2.ONE*diameter*.5).round(),Vector2.ONE*diameter),false)
	if amount>1 and progress<.88:
		var text := "+%d" % amount
		var text_position := Vector2(18,26)
		draw_string_outline(_font,text_position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,4,Color("#263a31"))
		draw_string(_font,text_position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#fff3d3"))
