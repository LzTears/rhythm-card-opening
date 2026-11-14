extends Control
## Decorative cabinet surface. The shader never samples the interactive world.

const BackdropShader = preload("res://assets/ui_arcade_backdrop.gdshader")
var _art: Texture2D
var _menu := false
var _reduced := false

func configure(art: Texture2D, menu: bool, reduced: bool) -> void:
	_art = art
	_menu = menu
	_reduced = reduced
	if is_node_ready():
		_sync_material()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BackdropShader
	material = shader_material
	resized.connect(_sync_material)
	_sync_material()

func set_reduced(value: bool) -> void:
	_reduced = value
	if is_node_ready():
		_sync_material()

func _sync_material() -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("has_art",_art!=null)
	if _art!=null:
		shader_material.set_shader_parameter("background_art",_art)
	shader_material.set_shader_parameter("art_strength",1.0)
	shader_material.set_shader_parameter("reduced",1.0 if _reduced else 0.0)
	shader_material.set_shader_parameter("surface_size",size)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
