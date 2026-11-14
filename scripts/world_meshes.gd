extends RefCounted
## Authored tabletop geometry. Dimensions are in metres (100 game units = 1 m).

const PIXEL_SURFACE = preload("res://assets/vfx_pixel_surface.gdshader")
const PACK_PRINT = preload("res://assets/pack_print.gdshader")
const CARD_FOIL = preload("res://assets/card_foil_world.gdshader")
const Rules = preload("res://scripts/pack_rules.gd")
const PALETTE: Array[Color] = [Color("#101922"),Color("#1b2b38"),Color("#294656"),Color("#3e5d6d"),Color("#424957"),Color("#646c7b"),Color("#8993a3"),Color("#bdc6d1"),Color("#e5e6df"),Color("#fff0c5"),Color("#7c3c1f"),Color("#bd611e"),Color("#ef8d1c"),Color("#ffc34b"),Color("#638664"),Color("#a4c5cc")]

var _textures: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _pack_layouts: Dictionary = {}

func presentation_path(path: String) -> String:
	# Every presentation consumer shares the same priority; source art stays recoverable.
	for source_root in ["res://assets/art/a2/","res://assets/art/crt/","res://assets/art/workshop/"]:
		if not path.begins_with(source_root):
			continue
		var relative := path.trim_prefix(source_root)
		for target_root in ["res://assets/art/workshop/","res://assets/art/crt/","res://assets/art/a2/"]:
			var candidate: String = target_root+relative
			if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
				return candidate
		break
	return path

func texture(path: String) -> Texture2D:
	path = presentation_path(path)
	if _textures.has(path):
		return _textures[path]
	if ResourceLoader.exists(path):
		var resource := load(path) as Texture2D
		if resource != null:
			_textures[path] = resource
			return resource
	# Fresh authoring runs may precede the editor import pass; the exported game uses remaps above.
	if FileAccess.file_exists(path) and path.ends_with(".png"):
		var pixels := Image.load_from_file(path)
		if pixels != null and not pixels.is_empty():
			var resource := ImageTexture.create_from_image(pixels)
			_textures[path] = resource
			return resource
	if path.begins_with("res://assets/art/"):
		push_error("Missing required presentation texture: "+path)
	return null

func material(color: Color, roughness: float = 0.65, metallic: float = 0.0) -> ShaderMaterial:
	var key := "%s/%.3f/%.3f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL_SURFACE
	mat.set_shader_parameter("base_color",_nearest_color(color))
	mat.set_shader_parameter("shadow_color",_nearest_color(color.darkened(0.43).lerp(Color("#1b2b38"),0.35)))
	mat.set_shader_parameter("light_color",_nearest_color(color.lightened(0.22)))
	_materials[key] = mat
	return mat

func _nearest_color(color: Color) -> Color:
	var best := PALETTE[0]
	var distance := INF
	for candidate in PALETTE:
		var delta := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b)
		if delta.length_squared()<distance:
			distance = delta.length_squared()
			best = candidate
	return best

func print_material(path: String, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE if texture(path) != null else fallback
	mat.albedo_texture = texture(path)
	mat.roughness = 0.82
	mat.metallic_specular = 0.17
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.22
	return mat

func card_front_material(path: String, fallback: Color, grade: int) -> Material:
	if grade<3:
		return print_material(path,fallback)
	var print_texture := texture(path)
	if print_texture==null:
		return print_material(path,fallback)
	var mat := ShaderMaterial.new()
	mat.shader = CARD_FOIL
	mat.set_shader_parameter("print_texture",print_texture)
	mat.set_shader_parameter("foil_grade",clampi(grade,3,4))
	mat.set_shader_parameter("phase",0.0)
	mat.set_shader_parameter("reduced",false)
	mat.set_shader_parameter("gold_gain",0.12)
	mat.set_shader_parameter("rainbow_gain",0.10)
	mat.set_shader_parameter("reduced_gain",0.40)
	mat.set_shader_parameter("alpha_cutoff",0.22)
	return mat

func instance(mesh: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item

func box(size_value: Vector3, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	return instance(mesh, mat, at, parent)

func cylinder(radius: float, length: float, at: Vector3, mat: Material, parent: Node3D, sides: int = 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = sides
	return instance(mesh, mat, at, parent)

func plane(size_value: Vector2, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size_value
	var item := instance(mesh, mat, at, parent)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

func desk_surface(size_value: Vector2) -> ArrayMesh:
	# Source corner tiles are twice the straight rail thickness. Their 96px
	# squares map uniformly to 64du; the silver straight rail remains about 32du.
	var border := Rules.DESK_BORDER*.01
	var source_size := Vector2(1600,960)
	var corner_size := border
	var corner_pixels := Vector2(border/10.0,border/6.0)*source_size
	var source_path := presentation_path("res://assets/art/a2/ui/battle-table.png")
	if source_path.begins_with("res://assets/art/workshop/"):
		var art := texture(source_path)
		if art!=null:
			source_size = art.get_size()
		corner_size = border*2.0
		corner_pixels = Vector2.ONE*roundf(source_size.y*.10)
	var xs := [-size_value.x*.5,-size_value.x*.5+corner_size,size_value.x*.5-corner_size,size_value.x*.5]
	var zs := [-size_value.y*.5,-size_value.y*.5+corner_size,size_value.y*.5-corner_size,size_value.y*.5]
	var us := [0.0,corner_pixels.x/source_size.x,1.0-corner_pixels.x/source_size.x,1.0]
	var vs := [0.0,corner_pixels.y/source_size.y,1.0-corner_pixels.y/source_size.y,1.0]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in range(3):
		for column in range(3):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				vertices.append(Vector3(xs[column+corner.x],0,zs[row+corner.y]))
				normals.append(Vector3.UP)
				uvs.append(Vector2(us[column+corner.x],vs[row+corner.y]))
	return _array_mesh(vertices,normals,uvs)

func ring(radius: float, width: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius
	mesh.rings = 64
	mesh.ring_segments = 8
	var item := instance(mesh, mat, Vector3.ZERO, parent)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

func card_surface(back: bool = false) -> ArrayMesh:
	var key := "card_back" if back else "card_front"
	if _meshes.has(key):
		return _meshes[key]
	var outline := _card_outline()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var height := -0.0051 if back else 0.0051
	var normal := Vector3.DOWN if back else Vector3.UP
	# Triangulate the existing concave slot outline without changing any boundary coordinates.
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0,indices.size(),3):
		var triangle := PackedVector2Array([outline[indices[index]],outline[indices[index+1]],outline[indices[index+2]]])
		var a := Vector3(triangle[0].x,height,triangle[0].y)
		var b := Vector3(triangle[1].x,height,triangle[1].y)
		var c := Vector3(triangle[2].x,height,triangle[2].y)
		# Godot's clockwise front faces have cross products opposite their outward normals.
		if (b-a).cross(c-a).dot(normal)>0.0:
			var swap := triangle[1]
			triangle[1] = triangle[2]
			triangle[2] = swap
		for p in triangle:
			vertices.append(Vector3(p.x, height, p.y))
			normals.append(normal)
			uv.append(Vector2(0.5 + p.x / 0.384, 0.5 + p.y / 0.384))
	var mesh := _array_mesh(vertices, normals, uv)
	_meshes[key] = mesh
	return mesh

func card_edge() -> ArrayMesh:
	if _meshes.has("card_edge"):
		return _meshes["card_edge"]
	var outline := _card_outline()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	for index in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		var n := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		var points: Array[Vector3] = [Vector3(a.x,-0.005,a.y),Vector3(a.x,0.005,a.y),Vector3(b.x,0.005,b.y),Vector3(a.x,-0.005,a.y),Vector3(b.x,0.005,b.y),Vector3(b.x,-0.005,b.y)]
		points.reverse()
		for p in points:
			vertices.append(p)
			normals.append(n)
			uv.append(Vector2.ZERO)
	var mesh := _array_mesh(vertices, normals, uv)
	_meshes["card_edge"] = mesh
	return mesh

func _card_outline() -> PackedVector2Array:
	# The slot is a real 30 mm deep cut, so its silhouette also flips correctly.
	var points := PackedVector2Array()
	var edge_angle := asin(0.016 / 0.18)
	for index in range(97):
		var angle := lerpf(edge_angle, TAU - edge_angle, float(index) / 96.0)
		points.append(Vector2(cos(angle), sin(angle)) * 0.18)
	points.append(Vector2(0.15,-0.016))
	points.append(Vector2(0.15,0.016))
	return points

func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Packet alpha bounds from the five formal-art manifest entries, right/bottom exclusive.
const PACK_BOUNDS := [Rect2i(11,32,234,320),Rect2i(13,32,231,320),Rect2i(8,32,241,320),Rect2i(11,32,234,320),Rect2i(13,32,231,320)]
const PACK_CANVAS := Vector2i(256,384)
const PACK_PATH_PATTERN := "res://assets/art/a2/packs/pack-%d.png"
const DAMAGE_PATH_PATTERN := "res://assets/art/a2/pack_damage/damage-%d.png"

func pack_layout(grade: int) -> Dictionary:
	grade = clampi(grade,0,4)
	if _pack_layouts.has(grade):
		return _pack_layouts[grade]
	var path := presentation_path(PACK_PATH_PATTERN % grade)
	var canvas := PACK_CANVAS
	var crop: Rect2i = PACK_BOUNDS[grade]
	var body := crop
	if path.begins_with("res://assets/art/workshop/") or path.begins_with("res://assets/art/crt/"):
		var art := texture(path)
		if art != null:
			var pixels := art.get_image()
			if pixels != null and not pixels.is_empty():
				canvas = pixels.get_size()
				body = pixels.get_used_rect()
				crop = Rect2i(Vector2i.ZERO,canvas)
				if path.begins_with("res://assets/art/workshop/") and body.has_area():
					crop = _pack_crop(canvas,body)
	var result := {"canvas":canvas,"crop":crop,"body":body,"path":path}
	_pack_layouts[grade] = result
	return result

func _pack_crop(canvas: Vector2i, body: Rect2i) -> Rect2i:
	# Enclose the measured alpha in an exact 3:4 rectangle. Padding, rather than
	# independent X/Y scaling, keeps print pixels square and all five footprints equal.
	var units := ceili(maxf(float(body.size.x)/3.0,float(body.size.y)/4.0))
	if units*3>canvas.x or units*4>canvas.y:
		return Rect2i(Vector2i.ZERO,canvas)
	var size_value := Vector2i(units*3,units*4)
	var center := Vector2(body.position)+Vector2(body.size)*.5
	var at := Vector2i(roundi(center.x-size_value.x*.5),roundi(center.y-size_value.y*.5))
	at.x = clampi(at.x,0,canvas.x-size_value.x)
	at.y = clampi(at.y,0,canvas.y-size_value.y)
	return Rect2i(at,size_value)

func pack_art_size(grade: int) -> Vector2:
	# Fit the measured registered crop without stretching either axis: 60x80du.
	var crop: Rect2i = pack_layout(grade).crop
	var envelope := Rules.PACK_VISUAL_SIZE*.01
	var fit_scale := minf(envelope.x/float(crop.size.x),envelope.y/float(crop.size.y))
	return Vector2(crop.size)*fit_scale

func cropped_surface(size_value: Vector2, canvas: Vector2i, crop: Rect2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for normalized in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		var point: Vector2 = normalized*size_value
		vertices.append(Vector3(point.x,0,point.y))
		normals.append(Vector3.UP)
		uvs.append((Vector2(crop.position)+Vector2(crop.size)*(normalized+Vector2.ONE*.5))/Vector2(canvas))
	return _array_mesh(vertices,normals,uvs)

func pack_surface(grade: int) -> ArrayMesh:
	var key := "pack_%d" % grade
	if _meshes.has(key):
		return _meshes[key]
	var layout := pack_layout(grade)
	var crop: Rect2i = layout.crop
	var canvas: Vector2i = layout.canvas
	var uv_min := Vector2(crop.position)/Vector2(canvas)
	var uv_max := Vector2(crop.end)/Vector2(canvas)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var size_value := pack_art_size(grade)
	for normalized in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		var point: Vector2 = normalized*size_value
		vertices.append(Vector3(point.x,.005,point.y))
		normals.append(Vector3.UP)
		uvs.append(uv_min+(uv_max-uv_min)*(normalized+Vector2.ONE*.5))
	var mesh := _array_mesh(vertices,normals,uvs)
	_meshes[key] = mesh
	return mesh

func pack_material(grade: int, clip_to_table: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PACK_PRINT
	mat.set_shader_parameter("clip_to_table",clip_to_table)
	if clip_to_table:
		mat.set_shader_parameter("table_bounds_xz",Vector4((-Rules.TABLE_HALF_WIDTH+Rules.DESK_BORDER)*.01,(Rules.TABLE_HALF_WIDTH-Rules.DESK_BORDER)*.01,(-Rules.TABLE_DEPTH+Rules.DESK_BORDER)*.01,-Rules.DESK_BORDER*.01))
	mat.set_shader_parameter("print_texture",texture(PACK_PATH_PATTERN % grade))
	mat.set_shader_parameter("pack_grade",grade)
	var layout := pack_layout(grade)
	var crop: Rect2i = layout.crop
	var canvas: Vector2i = layout.canvas
	mat.set_shader_parameter("crop_rect",Vector4(float(crop.position.x)/canvas.x,float(crop.position.y)/canvas.y,float(crop.size.x)/canvas.x,float(crop.size.y)/canvas.y))
	var body: Rect2i = layout.body
	mat.set_shader_parameter("damage_target_rect",Vector4(float(body.position.x)/canvas.x,float(body.position.y)/canvas.y,float(body.size.x)/canvas.x,float(body.size.y)/canvas.y))
	var wear_crop: Rect2i = PACK_BOUNDS[clampi(grade,0,4)]
	mat.set_shader_parameter("damage_uv_rect",Vector4(float(wear_crop.position.x)/PACK_CANVAS.x,float(wear_crop.position.y)/PACK_CANVAS.y,float(wear_crop.size.x)/PACK_CANVAS.x,float(wear_crop.size.y)/PACK_CANVAS.y))
	mat.set_shader_parameter("art_texel_size",Vector2.ONE/Vector2(canvas))
	for level in range(1,4):
		mat.set_shader_parameter("damage_texture_%d" % level,texture(DAMAGE_PATH_PATTERN % level))
	return mat

func pack_torn_half(grade: int, right: bool) -> ArrayMesh:
	var key := "torn_%d_%s" % [grade,str(right)]
	if _meshes.has(key):
		return _meshes[key]
	var seam := [Vector2(.03,-.5),Vector2(-.04,-.2),Vector2(.05,.05),Vector2(-.03,.25),Vector2(.02,.5)]
	var points := PackedVector2Array()
	points.append(Vector2(.5,-.5) if right else Vector2(-.5,-.5))
	for p in seam:
		points.append(p)
	points.append(Vector2(.5,.5) if right else Vector2(-.5,.5))
	var indices := Geometry2D.triangulate_polygon(points)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var layout := pack_layout(grade)
	var crop: Rect2i = layout.crop
	var canvas: Vector2i = layout.canvas
	var size_value := pack_art_size(grade)
	for i in range(0,indices.size(),3):
		var tri := [points[indices[i]],points[indices[i+1]],points[indices[i+2]]]
		if (tri[1]-tri[0]).cross(tri[2]-tri[0])<0:
			var swap: Vector2 = tri[1]
			tri[1] = tri[2]
			tri[2] = swap
		for p in tri:
			vertices.append(Vector3(p.x*size_value.x,.005,p.y*size_value.y))
			normals.append(Vector3.UP)
			uvs.append((Vector2(crop.position)+Vector2(crop.size)*(p+Vector2.ONE*.5))/Vector2(canvas))
	var mesh := _array_mesh(vertices,normals,uvs)
	_meshes[key] = mesh
	return mesh
