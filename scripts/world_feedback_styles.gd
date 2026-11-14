extends RefCounted
## One cache per World. Configure once with the existing Font objects, then treat
## all returned Themes/StyleBoxes as read-only. Node state/lifetime stays in World.
## Assign Theme before entering the tree, as World already does with overrides.
## Do not force a theme notification: that changes the legacy detached layout cache.
## get_theme_* queries resolve the shared Theme once the Label enters its canvas.
const BD_ELEMENT_COLORS := {"E01":Color("#ffe6a0"),"E02":Color("#79e3ec"),"E05":Color("#addef6")}
const DAMAGE_STYLES := ["direct","burst","chain","dot","wave"]
var _damage: Dictionary = {}
var _ordinary: Dictionary = {}
var _ordinary_font: FontFile
var _feedback_ink := Color.WHITE
var _plain_popup: StyleBoxFlat
var _grouped_popup: StyleBoxFlat
var _configured := false

func configure(pixel_fusion: FontFile, pixel_ark: FontFile, ordinary_noto: FontFile, damage_colors: Dictionary, feedback_ink: Color, _button_texture: Texture2D) -> void:
	assert(not _configured,"Create a new feedback-style cache for each World; do not reconfigure shared resources.")
	_configured = true
	_ordinary_font = ordinary_noto
	_feedback_ink = feedback_ink
	for style: String in DAMAGE_STYLES:
		var value := Theme.new()
		value.set_font("font","Label",pixel_ark if style in ["burst","chain","wave"] else pixel_fusion)
		value.set_font_size("font_size","Label",24 if style=="dot" else 36)
		value.set_constant("outline_size","Label",4 if style=="burst" else 3)
		value.set_color("font_outline_color","Label",Color("#10171e"))
		value.set_color("font_color","Label",damage_colors[style])
		if style in ["burst","wave"]:
			value.set_constant("shadow_offset_x","Label",3 if style=="burst" else 2)
			value.set_constant("shadow_offset_y","Label",3 if style=="burst" else 2)
			value.set_color("font_shadow_color","Label",Color("#805330") if style=="burst" else Color("#66517d"))
		_damage[style] = value
	for font_size in [26,30,36]:
		ordinary_theme(font_size)
	_plain_popup = StyleBoxFlat.new()
	_plain_popup.bg_color = Color("#29213f")
	_plain_popup.border_color = Color("#cdb5cf")
	_plain_popup.set_border_width_all(1)
	_plain_popup.set_corner_radius_all(0)
	_plain_popup.shadow_color = Color(0.025,0.035,0.045,.80)
	_plain_popup.shadow_size = 2
	_plain_popup.shadow_offset = Vector2(2,2)
	_plain_popup.content_margin_left = 7
	_plain_popup.content_margin_right = 7
	_plain_popup.content_margin_top = 2
	_plain_popup.content_margin_bottom = 2
	_grouped_popup = StyleBoxFlat.new()
	_grouped_popup.bg_color = Color("#29213f")
	_grouped_popup.border_color = Color("#f1d7a4")
	_grouped_popup.set_border_width_all(2)
	_grouped_popup.set_corner_radius_all(0)
	_grouped_popup.shadow_color = Color(0.01,0.03,0.05,.75)
	_grouped_popup.shadow_size = 4
	_grouped_popup.shadow_offset = Vector2(2,3)
	_grouped_popup.content_margin_left = 16
	_grouped_popup.content_margin_right = 16
	_grouped_popup.content_margin_top = 8
	_grouped_popup.content_margin_bottom = 8

func damage_theme(style: String) -> Theme:
	return _damage.get(style,_damage["direct"])

func ordinary_theme(font_size: int) -> Theme:
	if not _ordinary.has(font_size):
		var value := Theme.new()
		value.set_font("font","Label",_ordinary_font)
		value.set_font_size("font_size","Label",font_size)
		value.set_constant("outline_size","Label",2)
		value.set_color("font_outline_color","Label",Color("#10171e"))
		value.set_color("font_color","Label",_feedback_ink)
		_ordinary[font_size] = value
	return _ordinary[font_size]

func popup_style(grouped: bool) -> StyleBox:
	return _grouped_popup if grouped else _plain_popup

func bd_color(element: String) -> Color:
	return BD_ELEMENT_COLORS.get(element,Color("#fff2cf"))
