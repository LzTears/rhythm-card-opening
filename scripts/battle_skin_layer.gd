extends Control
## Decorative frame skin. It never changes geometry or timing authority.
var skin := "default"
var tick := 0
var paused := false
var reduced := false

func _ready() -> void:
	name="BattleSkinLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func set_state(equipped: Dictionary, state: Dictionary, stopped: bool, low_effects: bool=false) -> void:
	skin=str(equipped.get("board","default"))
	paused=stopped
	reduced=low_effects
	if not stopped: tick=int(state.get("tick",0))
	queue_redraw()

func _draw() -> void:
	if skin=="default": return
	var tone := Color("#5ce6ef") if skin=="board_neon" else Color("#ecd58c")
	var second := Color("#e975c7") if skin=="board_neon" else Color("#aba1e8")
	var pulse := .45 if reduced else .45+.25*sin(float(tick)*TAU/60.0)
	for box: Rect2 in [Rect2(738,14,1164,114),Rect2(18,920,1884,144)]:
		draw_rect(box.grow(-4),Color(tone,pulse),false,2)
		for corner: Vector2 in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
			if skin=="board_neon":
				draw_rect(Rect2(corner+Vector2(6,6),Vector2(5,5)),second)
			else:
				var star := PackedVector2Array()
				for i in range(8):
					star.append(corner+Vector2.from_angle(float(i)*PI/4.0)*(6.0 if i%2==0 else 1.8))
				draw_colored_polygon(star,tone)

func get_presentation_state() -> Dictionary:
	return {"skin":skin,"tick":tick,"paused":paused,"decorative_only":true}
