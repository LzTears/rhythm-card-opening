extends Control
## Cast-metal workshop launcher badges. Display only; no game state.

class RarityRing extends Control:
	static var _textures: Dictionary = {}
	var accent := Color("#f4edd6")
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var diameter: float=minf(size.x,size.y)
		var center: Vector2=size*.5
		var key: String=accent.to_html(true)
		if not _textures.has(key):
			var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			for y in range(128):
				for x in range(128):
					var delta:=Vector2(float(x)-63.5,float(y)-63.5)
					var distance: float=delta.length()
					if distance>62.0 or distance<58.5: continue
					var color: Color=accent if y<64 else accent.darkened(.28)
					if distance<59.5: color=Color("#132331")
					image.set_pixel(x,y,color)
			for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var point: Vector2i=Vector2i(64,64)+direction*60
				image.fill_rect(Rect2i(point-Vector2i(3,3),Vector2i(6,6)),Color("#132331"))
				image.fill_rect(Rect2i(point-Vector2i(1,1),Vector2i(2,2)),accent.lightened(.32))
			_textures[key]=ImageTexture.create_from_image(image)
		draw_texture_rect(_textures[key],Rect2(center-Vector2.ONE*diameter*.5,Vector2.ONE*diameter),false)

var launcher_id := "E01"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
func _draw() -> void:
	var cell := maxi(1,int(minf(size.x,size.y)/40.0))
	var origin := ((size-Vector2.ONE*40*cell)*.5).floor()
	var accent := Color("#ffad22")
	if launcher_id=="E02": accent=Color("#ffe073")
	elif launcher_id=="E05": accent=Color("#87e9ff")
	for y in range(40):
		for x in range(40):
			var delta := Vector2(float(x)-19.5,float(y)-19.5)
			var radius := delta.length()
			if radius>19.5: continue
			var color := Color("#203746")
			if radius>18.5: color=Color("#07121d")
			elif radius>17.5: color=Color("#d5d9d4") if y<20 else Color("#5c6574")
			elif radius>15.5: color=Color("#8894a6") if y<20 else Color("#3d4b60")
			elif radius>14.5: color=Color("#101c28")
			elif radius>13.5: color=Color("#ff9b18")
			elif radius>12.5: color=Color("#0c1e2b")
			elif y<18: color=Color("#294557")
			var mark := false
			if launcher_id=="E02":
				mark=(y>=9 and y<=21 and x>=23-(y-9)/2 and x<=27-(y-9)/3) or (y>=19 and y<=31 and x>=17-(y-19)/3 and x<=23-(y-19)/2)
			elif launcher_id=="E05":
				mark=radius<11 and (absf(delta.x)<1.2 or absf(delta.x-delta.y*.58)<1.1 or absf(delta.x+delta.y*.58)<1.1)
				mark=mark or (radius>7.0 and radius<9.0 and (absf(delta.y)<1.0 or absf(absf(delta.x)-absf(delta.y))<1.0))
			else:
				mark=(y>=10 and y<=17 and x>=12 and x<=27) or (y>=17 and y<=29 and x>=18 and x<=21) or (y>=28 and y<=30 and x>=14 and x<=25)
			if mark and radius<12.5: color=accent.lightened(.15) if y<20 else accent
			# Steel fasteners on the orange cast rim.
			if (absi(x-20)<=1 and y in [3,4,35,36]) or (absi(y-20)<=1 and x in [3,4,35,36]): color=Color("#fff0bf")
			draw_rect(Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*cell),color)
