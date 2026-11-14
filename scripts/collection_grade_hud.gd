extends Control
## The battle view consumes only the public grade counts, never card identities.
const COLORS := [Color("#eee7dd"),Color("#73cd87"),Color("#b384ea"),Color("#f4cb61"),Color("#f36d75")]
var counts: Array = [0,0,0,0,0]
var backs: Array = []
var font: Font
var clock := 0
var gain_ticks: Array = [-1000,-1000,-1000,-1000,-1000]

func _ready() -> void:
	name="CollectionGradeHUD"
	custom_minimum_size=Vector2(400,70)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func configure(value: Font) -> void:
	font=value
	backs.clear()
	for grade in range(5):
		var path := "res://assets/collection/backs/back_%d.png" % grade
		var texture: Texture2D
		if ResourceLoader.exists(path,"Texture2D"):
			texture=load(path) as Texture2D
		elif FileAccess.file_exists(path):
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image!=null: texture=ImageTexture.create_from_image(image)
		backs.append(texture)

func set_counts(value: Array, at_tick: int, paused: bool) -> void:
	if not paused: clock=at_tick
	for grade in range(5):
		var amount := int(value[grade]) if value.size()>grade else 0
		if amount>int(counts[grade]): gain_ticks[grade]=clock
		counts[grade]=amount
	queue_redraw()

func _draw() -> void:
	if font==null: return
	for grade in range(5):
		var origin := Vector2(6+grade*80,(size.y-32)*.5)
		var strength := maxf(0.0,1.0-float(clock-int(gain_ticks[grade]))/20.0)
		var box := Rect2(origin-Vector2(0,strength*3),Vector2(24,32))
		if backs.size()>grade and backs[grade]!=null:
			draw_texture_rect(backs[grade],box,false)
		else:
			draw_rect(box,Color("#251b37"))
		draw_rect(box,COLORS[grade],false,2)
		draw_rect(box.grow(-5),Color(COLORS[grade],.5),false,1)
		var center := box.get_center()
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(6,0),center+Vector2(0,8),center+Vector2(-6,0)]),COLORS[grade])
		var number_size := 26
		while number_size>16 and font.get_string_size(str(counts[grade]),HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x>45: number_size-=1
		draw_string(font,origin+Vector2(31,25),str(counts[grade]),HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,COLORS[grade].lightened(strength*.2))

func get_presentation_state() -> Dictionary:
	return {"grade_counts":counts.duplicate(),"identities_visible":false,"hidden_separate":false,"layout":"after_coins_inline_grade_backs","rect":get_global_rect(),"tick":clock}
