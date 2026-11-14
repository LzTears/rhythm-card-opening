extends "res://scripts/rhythm_hud.gd"
## The lesson reuses the battle recipes and their exact PC/Xbox keycap renderer.
const LESSON_SIZE := Vector2(1184,560)
const COIN = preload("res://assets/fx/combat06/coin-icon.png")
const COMBO = preload("res://assets/ui/rhythm_feedback/combo.png")
const FEVER = preload("res://assets/ui/rhythm_feedback/fever.png")
const WHITE_PACK = preload("res://assets/art/a2/packs/pack-0.png")
const GREEN_PACK = preload("res://assets/art/a2/packs/pack-1.png")
var merge_count := 5
var _lesson_threshold := Rules.FEVER_BASE_THRESHOLD
var _lesson_energy_max := 10
var _lesson_retention := 0
var _lesson_plate: StyleBoxTexture = WorkshopSkin.plate(Color("#251d39"),Color("#917a9e"),1)

func _ready() -> void:
	name = "RhythmTutorialGraphics"
	set_meta("rhythm_tutorial_graphics",true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = LESSON_SIZE
	resized.connect(queue_redraw)
	set_process(false)

func configure(pixel: Font, glyph_font: Font, device: String, threshold: int, ratio: int, energy_max: int = 10, retention: int = 0) -> void:
	set_fonts(pixel,glyph_font)
	_lesson_threshold = threshold
	_lesson_energy_max = clampi(energy_max,7,10)
	_lesson_retention = clampi(retention,0,6)
	merge_count = ratio
	# Illustrative recipes only; this node never receives or submits drum input.
	rhythm = {"enabled":true,"fever_active":true,"fever_threshold":threshold}
	set_input_device(device)
	queue_redraw()

func _lesson_keys(buttons: Array, origin: Vector2, scale_factor: float = 1.35) -> void:
	var copied: Array = buttons.duplicate(true)
	for index in range(copied.size()):
		var center := Vector2(index*46.0,0)
		copied[index].center = center
		copied[index].rect = Rect2(center-Vector2(16,16),Vector2(32,32))
	draw_set_transform(origin,0,Vector2.ONE*scale_factor)
	_draw_guide_buttons(copied)
	draw_set_transform(Vector2.ZERO)

func _lesson_art(texture: Texture2D, area: Rect2) -> void:
	var fit := texture.get_size()*minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	draw_texture_rect(texture,Rect2(area.get_center()-fit*.5,fit),false)

func _draw() -> void:
	if display_font==null or body_font==null: return
	var cards := _guide_cards()
	var names := ["左鼓","右鼓","下鼓","上鼓"]
	var words := ["pata","pon","don","chaka"]
	for index in range(4):
		var key: String = words[index]
		var button: Dictionary = {}
		for card: Dictionary in cards:
			for candidate: Dictionary in card.prompt_buttons:
				if candidate.key==key: button=candidate
		_lesson_keys([button],Vector2(40+index*296,38),1.5)
		_center(names[index]+" · "+str(WORDS[key]),Rect2(84+index*296,16,206,44),24,CREAM)
	var descriptions := ["随机拉入圈外卡包","复述四拍，逐拍扩圈","攻击圈内卡包，击破产卡","Fever可用，满能全屏"]
	for index in range(cards.size()):
		var at := Vector2((index%2)*602,92+(index/2)*128)
		var box := Rect2(at,Vector2(582,116))
		draw_style_box(_lesson_plate,box)
		_center(str(cards[index].name),Rect2(at+Vector2(12,12),Vector2(136,44)),24,ORANGE if index==3 else SUCCESS)
		_lesson_keys(cards[index].prompt_buttons,at+Vector2(204,34))
		_center(descriptions[index],Rect2(at+Vector2(14,70),Vector2(554,34)),24,MUTED)
	var merge_box := Rect2(0,358,582,148)
	var fever_box := Rect2(602,358,582,148)
	draw_style_box(_lesson_plate,merge_box)
	draw_style_box(_lesson_plate,fever_box)
	_center("圈内自动合成",Rect2(14,368,554,34),24,SUCCESS)
	_lesson_art(WHITE_PACK,Rect2(60,408,48,64))
	_center("×"+str(merge_count),Rect2(122,420,90,40),36,CREAM)
	_center("→",Rect2(238,420,72,40),36,CREAM,false)
	_lesson_art(GREEN_PACK,Rect2(340,408,48,64))
	_center("自动进阶",Rect2(408,420,156,40),24,CREAM)
	_lesson_art(COMBO,Rect2(624,374,142,46))
	_center("×"+str(_lesson_threshold),Rect2(780,378,88,40),24,CREAM)
	_center("→",Rect2(866,378,56,40),36,CREAM,false)
	_lesson_art(FEVER,Rect2(936,370,188,54))
	for segment in range(_lesson_energy_max):
		var step := 500.0/float(_lesson_energy_max)
		draw_rect(Rect2(630+segment*step,440,step-7,16),Color("#e6c36d"))
	_center("%d句充能 · 爆发满能全屏" % _lesson_energy_max,Rect2(618,464,550,32),24,MUTED)
	_center("断拍清连击，扩圈最多留%d层，保留能量" % _lesson_retention,Rect2(0,520,850,34),24,MUTED)
	draw_texture_rect(COIN,Rect2(936,520,32,32),false)
	_center("圈内 ×1.2",Rect2(974,518,196,36),24,CREAM)

func get_presentation_state() -> Dictionary:
	return {"layout":"illustrated_first_battle","input_device":input_device,"recipes":_guide_cards(),
		"battle_keycap_renderer":true,"pack_assets":[WHITE_PACK.resource_path,GREEN_PACK.resource_path],
		"coin_asset":COIN.resource_path,"combo_asset":COMBO.resource_path,"fever_asset":FEVER.resource_path,
		"fever_threshold":_lesson_threshold,"merge_ratio":merge_count,"energy_max":_lesson_energy_max,"retention_stacks":_lesson_retention,"submits_input":false}
