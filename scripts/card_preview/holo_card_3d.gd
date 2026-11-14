extends Node3D
## Standalone presentation component. The host calls advance(delta), so pausing
## never depends on the engine's shader TIME or a separate process callback.
## Parallax is an approximation sampled from one flat source image, not layers.

const SHADER_PATH := "res://shaders/card_preview_holo.gdshader"
const CARD_SIZE := Vector2(3.0, 4.0)
const STANDARD_ART_SIZE := Vector2i(768, 1024)
const ART_BOUNDS := Vector4(0.035, 0.083, 0.965, 0.700)
const TITLE_BOUNDS := Vector4(0.300, 0.000, 0.700, 0.090)
const MAX_PITCH_DEGREES := 10.0
const MAX_YAW_DEGREES := 14.0
const TILT_RESPONSE := 10.5

var _front: MeshInstance3D
var _material: ShaderMaterial
var _shader: Shader
var _texture: ImageTexture
var _source_size := Vector2i.ZERO
var _texture_path := ""
var _requested_theme := "black_hole"
var _theme := "black_hole"
var _load_error := ""
var _shader_loaded := false
var _target_tilt := Vector2.ZERO
var _tilt := Vector2.ZERO
var _effect_time := 0.0
var _paused := false
var _reduced := false
var _auto_rotate := false
var _holo_strength := 1.0


func _ready() -> void:
	_ensure_visual()


func load_card(path: String, theme: String) -> bool:
	_ensure_visual()
	_texture_path = path
	_requested_theme = theme
	_theme = _canonical_theme(theme)
	_texture = null
	_source_size = Vector2i.ZERO
	_load_error = ""
	var source := Image.new()
	var result := source.load(path)
	if result != OK or source.is_empty():
		_load_error = "Image.load failed (%s): %s" % [result, path]
		_apply_uniforms()
		return false
	_source_size = source.get_size()
	# Runtime loading is deliberate: these review images need no editor import.
	if not source.has_mipmaps():
		source.generate_mipmaps()
	_texture = ImageTexture.create_from_image(source)
	_apply_uniforms()
	return _texture != null and _shader_loaded


func set_tilt(value: Vector2) -> void:
	if not is_finite(value.x) or not is_finite(value.y):
		return
	_target_tilt = value.clamp(Vector2(-1.0, -1.0), Vector2.ONE)


func advance(delta: float) -> void:
	_ensure_visual()
	if _paused or not is_finite(delta) or delta <= 0.0:
		return
	if not _reduced:
		_effect_time += delta
	var desired := _target_tilt
	if _auto_rotate and not _reduced:
		desired = Vector2(sin(_effect_time * 0.53) * 0.70, cos(_effect_time * 0.41) * 0.60)
	_tilt = _tilt.lerp(desired, 1.0 - exp(-delta * TILT_RESPONSE))
	rotation_degrees = Vector3(-_tilt.y * MAX_PITCH_DEGREES, _tilt.x * MAX_YAW_DEGREES, 0.0)
	_apply_motion_uniforms()


func set_paused(value: bool) -> void:
	_paused = value


func set_reduced(value: bool) -> void:
	_reduced = value
	_ensure_visual()
	_material.set_shader_parameter("reduced_effects", _reduced)


func set_holo_strength(value: float) -> void:
	if not is_finite(value):
		return
	_holo_strength = clampf(value, 0.0, 1.5)
	_ensure_visual()
	_material.set_shader_parameter("holo_strength", _holo_strength)


func set_auto_rotate(value: bool) -> void:
	_auto_rotate = value


func get_presentation_state() -> Dictionary:
	_ensure_visual()
	return {
		"theme": _theme,
		"requested_theme": _requested_theme,
		"texture_path": _texture_path,
		"texture_loaded": _texture != null,
		"source_size": _source_size,
		"source_size_px": [_source_size.x, _source_size.y],
		"standard_art_size_px": [STANDARD_ART_SIZE.x, STANDARD_ART_SIZE.y],
		"card_aspect": "3:4",
		"mesh_size": CARD_SIZE,
		"tilt": _tilt,
		"target_tilt": _target_tilt,
		"tilt_xy": [_tilt.x, _tilt.y],
		"rotation": rotation_degrees,
		"rotation_degrees": [rotation_degrees.x, rotation_degrees.y, rotation_degrees.z],
		"effect_time": _effect_time,
		"paused": _paused,
		"reduced": _reduced,
		"auto_rotate": _auto_rotate,
		"holo_strength": _holo_strength,
		"shader_loaded": _shader_loaded,
		"shader_path": SHADER_PATH,
		"source_art_flat": true,
		"parallax_mode": "approximate_uv_from_flat_art",
		"depth_approximation": "基于平面原图与程序主体遮罩的浅层UV偏移；非拆层或真实深度资产",
		"parallax_active": not _reduced and _holo_strength > 0.0,
		"gold_emboss_mode": "color_threshold_and_texture_gradient_approximation",
		"time_source": "advance_delta_uniform_not_shader_TIME",
		"reduced_behavior": "freeze_clock_disable_auto_parallax_and_speckle_allow_manual_tilt",
		"material_masks": {
			"art_bounds_uv": [ART_BOUNDS.x, ART_BOUNDS.y, ART_BOUNDS.z, ART_BOUNDS.w],
			"title_protection_uv": [TITLE_BOUNDS.x, TITLE_BOUNDS.y, TITLE_BOUNDS.z, TITLE_BOUNDS.w],
			"text_protection_from_y": 0.700,
			"frame_inset_uv": 0.035,
			"subject_depth": "theme_specific_procedural_ellipses_and_rings",
		},
		"load_error": _load_error,
	}


func _canonical_theme(value: String) -> String:
	var key := value.strip_edges().to_lower().replace("-", "_")
	if key in ["omegamon", "digimon", "奥米加兽"]:
		return "omegamon"
	return "black_hole"


func _ensure_visual() -> void:
	if is_instance_valid(_front):
		return
	_shader = Shader.new()
	if FileAccess.file_exists(SHADER_PATH):
		var source := FileAccess.get_file_as_string(SHADER_PATH)
		_shader.code = source
		_shader_loaded = not source.is_empty()
	else:
		_load_error = "Missing shader: " + SHADER_PATH
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var quad := QuadMesh.new()
	quad.size = CARD_SIZE
	# QuadMesh's default XY orientation has its front normal along positive Z.
	_front = MeshInstance3D.new()
	_front.name = "CardFront"
	_front.mesh = quad
	_front.material_override = _material
	_front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_front)
	_apply_uniforms()


func _apply_uniforms() -> void:
	_material.set_shader_parameter("card_texture", _texture)
	_material.set_shader_parameter("texture_loaded", _texture != null)
	_material.set_shader_parameter("theme_kind", 1 if _theme == "omegamon" else 0)
	_material.set_shader_parameter("holo_strength", _holo_strength)
	_material.set_shader_parameter("reduced_effects", _reduced)
	_material.set_shader_parameter("art_bounds", ART_BOUNDS)
	_material.set_shader_parameter("title_bounds", TITLE_BOUNDS)
	if _source_size.x > 0 and _source_size.y > 0:
		_material.set_shader_parameter("texture_texel", Vector2(1.0 / _source_size.x, 1.0 / _source_size.y))
	_apply_motion_uniforms()


func _apply_motion_uniforms() -> void:
	_material.set_shader_parameter("effect_time", _effect_time)
	_material.set_shader_parameter("tilt", _tilt)
