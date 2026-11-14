extends Control
## Score presentation only; authoritative coins always come from Simulation.
const ICON = preload("res://assets/fx/combat06/coin-icon.png")
var font: Font
var _coins := 0
var _tick := -1
var _gain_tick := -100000
var _gain_count := 0
var _initialized := false
var _paused := false
var _reduced := false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text="本局金币"
	custom_minimum_size=Vector2(330,70)
func configure(value: Font) -> void:
	font=value
func set_state(coins: int, tick: int, paused: bool, reduced: bool) -> void:
	var fresh := not _initialized or tick<_tick
	if fresh:
		_coins=maxi(0,coins)
		_gain_tick=-100000
		_gain_count=0
		_initialized=true
	elif coins>_coins:
		_gain_tick=tick
		_gain_count+=1
	_coins=maxi(0,coins)
	if fresh or not paused: _tick=tick
	_paused=paused
	_reduced=reduced
	queue_redraw()
func _motion() -> Dictionary:
	var age := _tick-_gain_tick
	var pop := pow(1.0-clampf(float(age)/30.0,0.0,1.0),1.4) if age>=0 and age<30 and not _reduced else 0.0
	var phase := float(posmod(maxi(0,_tick),60))/60.0*TAU
	return {"pop":pop,"number_scale":1.0+pop*.23,"number_lift":-pop*9.0,"icon_scale":1.0+pop*.18+(sin(phase)*.035 if not _reduced else 0.0),"icon_rotation":sin(phase)*.07 if not _reduced else 0.0,"icon_bob":sin(phase)*2.0 if not _reduced else 0.0}
func get_presentation_state() -> Dictionary:
	return {"coins":_coins,"text":str(_coins),"tick":_tick,"gain_count":_gain_count,"gain_tick":_gain_tick,"paused":_paused,"reduced":_reduced,"icon_loaded":ICON!=null,"motion":_motion(),"caption_visible":false}
func _draw() -> void:
	if font==null: return
	var motion := _motion()
	var middle := size.y*.5
	var center := Vector2(35,middle+float(motion.icon_bob))
	draw_set_transform(center,float(motion.icon_rotation),Vector2.ONE*float(motion.icon_scale))
	draw_texture_rect(ICON,Rect2(-22,-22,44,44),false)
	if not _reduced:
		var sparkle := maxf(0.0,sin(float(maxi(0,_tick))/60.0*TAU*2.0))*.4+float(motion.pop)*.6
		if sparkle>.25:
			draw_line(Vector2(14,-22),Vector2(14,-12),Color("#fff2be",sparkle),2.0)
			draw_line(Vector2(9,-17),Vector2(19,-17),Color("#fff2be",sparkle),2.0)
	draw_set_transform(Vector2.ZERO)
	var text := str(_coins)
	var text_width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,36).x
	var fit := minf(1.0,maxf(1.0,size.x-83.0)/maxf(1.0,(text_width+12)*float(motion.number_scale)))
	var number_center := Vector2(74+text_width*fit*float(motion.number_scale)*.5,middle+float(motion.number_lift))
	draw_set_transform(number_center,0.0,Vector2.ONE*fit*float(motion.number_scale))
	var baseline := Vector2(-text_width*.5,(font.get_ascent(36)-font.get_descent(36))*.5)
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,36,4,Color("#24172f"))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("#f2d083").lerp(Color("#fff4c8"),float(motion.pop)*.5))
	draw_set_transform(Vector2.ZERO)
