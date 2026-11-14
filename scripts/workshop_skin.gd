extends RefCounted
## Native cut-paper skins. Flat faces retain the caller's semantic colors.

const PAPER_SHADOW := Color("#171126")
const WARM_EDGE := Color("#f2dfbc")
static var _circles: Dictionary = {}

static func plate(fill: Color, accent: Color, width: int = 1) -> StyleBoxTexture:
	var image := Image.create(96,96,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var border := clampi(width,0,4)
	var face := _plate_points(0.0)
	var inset := _plate_points(float(border))
	var backing := _plate_points(0.0,Vector2(1,3))
	var outline_only := fill.a==0.0
	var rim := accent if outline_only else _rim_color(accent)
	for y in range(96):
		for x in range(96):
			var point := Vector2(float(x)+.5,float(y)+.5)
			var on_face := Geometry2D.is_point_in_polygon(point,face)
			var color := Color.TRANSPARENT
			if outline_only:
				if border>0 and on_face and not Geometry2D.is_point_in_polygon(point,inset): color=accent
			else:
				# A single offset sheet, rather than beveled light and dark rings.
				if border>0 and Geometry2D.is_point_in_polygon(point,backing):
					color=PAPER_SHADOW
					color.a=fill.a
				if on_face:
					color=fill
					if border>0 and not Geometry2D.is_point_in_polygon(point,inset):
						color=rim
						color.a*=fill.a
			image.set_pixel(x,y,color)
	var style := StyleBoxTexture.new()
	style.texture=ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,28)
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

static func circle(fill: Color, accent: Color, width: int, diameter: float) -> StyleBoxTexture:
	var key := fill.to_html(true)+accent.to_html(true)+str(width)+str(diameter)
	if _circles.has(key): return _circles[key]
	var image := Image.create(96,96,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var border := clampi(width,0,4)
	var face := _circle_points(0.0)
	var inset := _circle_points(float(border))
	var backing := _circle_points(0.0,Vector2(1,3))
	var outline_only := fill.a==0.0
	var rim := accent if outline_only else _rim_color(accent)
	for y in range(96):
		for x in range(96):
			var point := Vector2(float(x)+.5,float(y)+.5)
			var on_face := Geometry2D.is_point_in_polygon(point,face)
			var color := Color.TRANSPARENT
			if outline_only:
				if border>0 and on_face and not Geometry2D.is_point_in_polygon(point,inset): color=accent
			else:
				if border>0 and Geometry2D.is_point_in_polygon(point,backing):
					color=PAPER_SHADOW
					color.a=fill.a
				if on_face:
					color=fill
					if border>0 and not Geometry2D.is_point_in_polygon(point,inset):
						color=rim
						color.a*=fill.a
			image.set_pixel(x,y,color)
	var style := StyleBoxTexture.new()
	style.texture=ImageTexture.create_from_image(image)
	style.set_content_margin_all(0)
	_circles[key]=style
	return style

static func _rim_color(accent: Color) -> Color:
	# A small warm-paper tint keeps grade/selected/focus accents distinguishable.
	var color := accent.lerp(WARM_EDGE,.24)
	color.a=accent.a
	return color

static func _plate_points(inset: float, offset: Vector2=Vector2.ZERO) -> PackedVector2Array:
	# Unequal cuts read as hand-cut paper while the stretched middle stays flat.
	var points := PackedVector2Array([
		Vector2(15+inset*.4,3+inset),Vector2(80-inset*.3,3+inset),
		Vector2(92-inset,14+inset*.3),Vector2(92-inset,79-inset*.4),
		Vector2(81-inset*.3,90-inset),Vector2(14+inset*.4,90-inset),
		Vector2(3+inset,81-inset*.3),Vector2(3+inset,15+inset*.4),
	])
	for index in range(points.size()): points[index]+=offset
	return points

static func _circle_points(inset: float, offset: Vector2=Vector2.ZERO) -> PackedVector2Array:
	# Slightly uneven facets give the talent medallions a paper-cut perimeter.
	var radii: Array[float] = [44.5,45.0,44.0,45.5,45.0,44.5,45.5,44.0,45.5,44.0,45.0,44.5,45.5,44.5,45.0,44.5]
	var points := PackedVector2Array()
	for index in range(radii.size()):
		var angle := TAU*float(index)/float(radii.size())
		points.append(Vector2(47,46.5)+Vector2(cos(angle),sin(angle))*(radii[index]-inset)+offset)
	return points
