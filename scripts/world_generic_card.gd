extends RefCounted
## Shared workshop metal back; only its outer metal band carries the real reward grade.
static var _textures: Dictionary = {}
const RIMS: Array[Color] = [Color("#b8c0cf"),Color("#54b34c"),Color("#b27bdd"),Color("#f3b638"),Color("#e7553d")]

static func texture(back: Texture2D, grade: int) -> Texture2D:
	grade = clampi(grade,0,4)
	if _textures.has(grade):
		return _textures[grade]
	var image := back.get_image() if back!=null else Image.create(96,96,false,Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(96,96,Image.INTERPOLATE_NEAREST)
	var bounds := image.get_used_rect()
	var center := Vector2(bounds.position)+Vector2(bounds.size)*.5
	var radius := maxf(1.0,minf(bounds.size.x,bounds.size.y)*.5)
	for y in range(96):
		for x in range(96):
			var source := image.get_pixel(x,y)
			if source.a<.22:
				continue
			var radial := (Vector2(x+.5,y+.5)-center).length()/radius
			if radial<.81 or radial>.985:
				continue
			# Preserve the source's carved spiral, stepped shading, silhouette and ink.
			var value := source.r*.2126+source.g*.7152+source.b*.0722
			if value<.15:
				continue
			var metal := RIMS[grade].darkened(clampf((.55-value)*1.1,0.0,.65))
			if value>.65:
				metal = metal.lightened((value-.65)*1.8)
			var band := source.lerp(metal,.72 if grade>0 else .30)
			band.a = source.a
			image.set_pixel(x,y,band)
	var result := ImageTexture.create_from_image(image)
	result.resource_name = "WorkshopGrade%dMetalBack" % grade
	_textures[grade] = result
	return result
