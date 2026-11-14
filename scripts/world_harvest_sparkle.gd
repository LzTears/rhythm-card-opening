extends Control
## A short, decorative HUD accent. Counts affect only density; this node never awards loot.
const Atlas = preload("res://scripts/world_fx_atlas.gd")
var age := 0.0
var duration := .60
var count := 2
var reduced := false
var _sheet: Dictionary = {}
var _coin_sheet: Dictionary = {}
var _badge_size := Vector2(400,108)
var _frame := -1

func configure(at: Vector2, amount: int, quiet: bool, badge_size: Vector2 = Vector2(400,108)) -> void:
	name = "HarvestPixelSparkle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = at
	count = clampi(amount,2,6)
	reduced = quiet
	_sheet = Atlas.sheet("harvest_card")
	_coin_sheet = Atlas.sheet("harvest_coin")
	_badge_size = badge_size.max(Vector2.ONE)
	duration = maxf(.30,maxf(float(_sheet.get("duration",.60)),float(_coin_sheet.get("duration",.60))))
	queue_redraw()

func advance(delta: float, frozen: bool, quiet: bool) -> void:
	var changed := reduced!=quiet
	reduced = quiet
	if not frozen:
		age += delta
	if age>=duration:
		queue_free()
		return
	var next := floori(age*30.0)
	if next!=_frame or changed:
		_frame = next
		queue_redraw()

func _draw() -> void:
	if _sheet.is_empty() or _coin_sheet.is_empty() or reduced:
		return
	var step := clampf(age/duration,0,1)
	for i in range(count):
		var selected := _coin_sheet if i%2==0 else _sheet
		var angle := TAU*float(i)/float(count)+.35
		var direction := Vector2.from_angle(angle)
		var edge_distance := minf(_badge_size.x*.5/maxf(.0001,absf(direction.x)),_badge_size.y*.5/maxf(.0001,absf(direction.y)))
		var at := direction*(edge_distance+28.0+step*16.0)
		var scale_value := .80 if i%2==0 else .36
		var size_value := Vector2(selected.size)*scale_value
		var pivot := Vector2(selected.pivot)*scale_value
		draw_texture_rect_region(selected.texture,Rect2(at-pivot,size_value),Atlas.frame_rect(selected,Atlas.frame_at(selected,age)),Color(1,1,1,.72 if i%2==0 else .68))
