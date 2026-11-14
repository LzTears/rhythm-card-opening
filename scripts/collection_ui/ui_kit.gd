extends RefCounted
## Shared display helpers. No profile mutation or persistence lives in this folder.

const ControllerUi = preload("res://scripts/controller_ui.gd")

const INK := Color("#f5eddd")
const MUTED := Color("#b5adbd")
const GOLD := Color("#f4cc76")
const PAPER := Color("#282333")
const GRADES := [Color("#e9e4dc"), Color("#80d7a0"), Color("#bd8ef1"), Color("#f1c765"), Color("#ef526c")]
static var _textures: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if _textures.has(path): return _textures[path]
	if ResourceLoader.exists(path,"Texture2D"):
		var imported := ResourceLoader.load(path,"Texture2D") as Texture2D
		if imported != null:
			_textures[path] = imported
			return imported
	if not FileAccess.file_exists(path): return null
	# Direct image loading also works before editor import, during first launch.
	var source := Image.new()
	if source.load(ProjectSettings.globalize_path(path)) != OK or source.is_empty(): return null
	if not source.has_mipmaps(): source.generate_mipmaps()
	var result := ImageTexture.create_from_image(source)
	_textures[path] = result
	return result

static func plate(color: Color = PAPER, border: Color = Color("#625168"), width: int = 2) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(12)
	result.shadow_color = Color(0.02, 0.01, 0.03, 0.3)
	# A transparent outline must not cast a filled rectangular shadow over the
	# paper/art beneath it (focus rings and frame layers use this same helper).
	result.shadow_size = 0 if color.a<=0.001 else 5
	return result

static func label(parent: Node, text: String, rect: Rect2, font: Font, px: int = 24, color: Color = INK, centered: bool = false) -> Label:
	var item := Label.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null: item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", maxi(12,roundi(float(px)/12.0)*12) if font!=null and font.get_meta("interface_pixel",false) else px)
	item.add_theme_color_override("font_color", color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(item)
	return item

static func fit_number(item: Label, min_px: int = 16) -> void:
	# Exact amount remains visible within its reserved HUD region.
	var px := item.get_theme_font_size("font_size")
	var face := item.get_theme_font("font")
	while px > min_px and face.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x > item.size.x:
		px -= 1
	item.add_theme_font_size_override("font_size",px)

static func button(parent: Node, text: String, rect: Rect2, font: Font, action: Callable, selected: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	if font != null: item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", 24)
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", GOLD)
	item.add_theme_color_override("font_disabled_color", MUTED)
	# Current category/preview is a quiet marker; the native focus skin owns red.
	item.add_theme_stylebox_override("normal", plate(PAPER, Color("#a18e72") if selected else Color("#65536c")))
	item.add_theme_stylebox_override("hover", plate(Color("#3b314b"), GOLD))
	item.add_theme_stylebox_override("pressed", plate(Color("#332a43"), GOLD))
	item.add_theme_stylebox_override("disabled", plate(Color("#24212c"), Color("#494150")))
	item.add_theme_stylebox_override("focus", plate(Color.TRANSPARENT, GOLD, 3))
	if action.is_valid(): item.pressed.connect(action)
	parent.add_child(item)
	ControllerUi.decorate(item)
	return item

static func panel(parent: Node, rect: Rect2, fill: Color = PAPER, border: Color = Color("#65536c")) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", plate(fill, border))
	parent.add_child(item)
	return item

static func icon(parent: Node, kind: String, rect: Rect2, color: Color = GOLD) -> Control:
	var item := DisplayIcon.new()
	item.kind = kind
	item.accent = color
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func comma(value: int) -> String:
	var source := str(value)
	var result := ""
	for index in range(source.length()):
		if index > 0 and (source.length() - index) % 3 == 0: result += ","
		result += source[index]
	return result

class DisplayIcon extends Control:
	var kind := "coin"
	var accent := GOLD
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.43
		if kind == "coin":
			var image: Texture2D = load("res://scripts/collection_ui/ui_kit.gd").texture("res://assets/fx/combat06/coin-icon.png")
			if image != null:
				draw_texture_rect(image, Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2.0), false)
			else:
				draw_circle(c, r, Color("#a76c32"))
				draw_circle(c - Vector2(0, r * 0.07), r * 0.86, accent)
				draw_arc(c, r * 0.62, 0, TAU, 32, Color("#9e6735"), maxf(1, r * 0.08), true)
				draw_line(c - Vector2(r * 0.2, r * 0.25), c + Vector2(r * 0.2, r * 0.25), Color("#9e6735"), maxf(2, r * 0.13))
		elif kind == "book":
			var left := PackedVector2Array([Vector2(0.1,0.22),Vector2(0.43,0.13),Vector2(0.5,0.22),Vector2(0.5,0.88),Vector2(0.42,0.79),Vector2(0.1,0.86)])
			var right := PackedVector2Array([Vector2(0.5,0.22),Vector2(0.57,0.13),Vector2(0.9,0.22),Vector2(0.9,0.86),Vector2(0.58,0.79),Vector2(0.5,0.88)])
			for index in range(left.size()): left[index] *= size; right[index] *= size
			draw_colored_polygon(left, accent.darkened(0.22))
			draw_colored_polygon(right, accent)
			draw_line(Vector2(size.x*0.5,size.y*0.22),Vector2(size.x*0.5,size.y*0.86),Color("#463049"),2)
			for y in [0.36,0.48,0.60]:
				draw_line(Vector2(size.x*0.62,size.y*y),Vector2(size.x*0.8,size.y*(y+0.04)),Color("#9b704f"),2)
		elif kind == "lock":
			draw_arc(c - Vector2(0,r*0.18),r*0.5,PI,TAU,20,accent,maxf(2,r*0.14),true)
			draw_style_box(load("res://scripts/collection_ui/ui_kit.gd").plate(accent,accent,0),Rect2(c-Vector2(r*0.68,0),Vector2(r*1.36,r*0.9)))
		elif kind == "star":
			var points := PackedVector2Array()
			for index in range(10):
				var angle := -PI*0.5+float(index)*PI/5.0
				var radius := r if index%2==0 else r*0.43
				points.append(c+Vector2(cos(angle),sin(angle))*radius)
			draw_colored_polygon(points,accent)
			for index in range(points.size()): draw_line(points[index],points[(index+1)%points.size()],Color("#fff1bf"),1.5,true)
		else:
			draw_line(c+Vector2(-r*0.65,0),c+Vector2(-r*0.1,r*0.45),accent,maxf(2,r*0.18),true)
			draw_line(c+Vector2(-r*0.1,r*0.45),c+Vector2(r*0.72,-r*0.5),accent,maxf(2,r*0.18),true)
