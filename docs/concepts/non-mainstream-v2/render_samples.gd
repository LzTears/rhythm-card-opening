extends SceneTree
## Approval-only concepts, rendered with the actual production frames and foil.
## Does not read/write a profile or register cards in the collection catalog.
const CardView = preload("res://scripts/collection_ui/collection_card_view.gd")
const Ui = preload("res://scripts/collection_ui/ui_kit.gd")
const ROOT := "res://docs/concepts/non-mainstream-v2"
const SAMPLES := [
 {"id":"meme-preview-01","name":"圆头耄耋","description":"脾气可以不大，哈气必须到位。","file":"maodie","grade":0,"caption":"哈！"},
 {"id":"meme-preview-02","name":"奶蛙","description":"表面一切正常，精神状态另算。","file":"naiwa","grade":2,"caption":"精神稳定"},
 {"id":"meme-preview-03","name":"高雅人士","description":"世界尽管发癫，领结必须端正。","file":"elegant-penguin","grade":4,"caption":"保持高雅"}
]
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var output := ROOT.path_join("renders" if "--with-captions" in OS.get_cmdline_user_args() else "renders-clean")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var face: Font=load("res://assets/fonts/NotoSansCJKsc-Medium.otf")
 var pixel: Font=load("res://assets/fonts/ark-pixel-12px-proportional-zh_hans.otf")
 var board := SubViewport.new()
 board.size=Vector2i(2560,1280);board.disable_3d=true
 board.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(board)
 var background := ColorRect.new();background.size=Vector2(2560,1280);background.color=Color("#21192f");board.add_child(background)
 Ui.label(background,"非主流  ·  梗图强化版",Rect2(48,22,1900,88),pixel,48,Color("#f4e0bc"))
 var cards: Array[Control]=[]
 var viewports: Array[SubViewport]=[]
 for i in range(SAMPLES.size()):
  var sample: Dictionary=SAMPLES[i].duplicate(true)
  var path := ROOT.path_join("art").path_join(sample.file+".png")
  if not FileAccess.file_exists(path): push_error("Missing sample art "+path);quit(1);return
  sample["art_path"]=path;sample["theme"]="meme";sample["hidden"]=false
  var viewport := SubViewport.new();viewport.size=Vector2i(768,1024)
  viewport.disable_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(viewport)
  var card := CardView.new();card.size=Vector2(768,1024);viewport.add_child(card)
  card.configure(sample,true,face,false);card.external_clock=true
  card._theme_label.text="非主流"
  if "--with-captions" in OS.get_cmdline_user_args():
   var caption := Ui.label(card._surface,str(sample.caption),Rect2(58,624,652,128),face,84,Color.WHITE,true)
   caption.add_theme_color_override("font_outline_color",Color("#120b18"))
   caption.add_theme_constant_override("outline_size",8)
   card._surface.move_child(caption,card._frame.get_index())
  cards.append(card);viewports.append(viewport)
  var display := TextureRect.new();display.position=Vector2(48+i*848,144);display.size=Vector2(768,1024)
  display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  background.add_child(display)
 Ui.label(background,"表情与构图强化 · 品阶仅为配色示例 · 红卡使用实机动态Holo",Rect2(48,1190,2464,64),pixel,24,Color("#bdaac9"))
 for i in range(8): await process_frame
 for card in cards: card.advance_time(.7)
 await RenderingServer.frame_post_draw
 for i in range(cards.size()):
  var path := output.path_join(SAMPLES[i].file+"-card.png")
  if viewports[i].get_texture().get_image().save_png(ProjectSettings.globalize_path(path))!=OK:push_error(path)
 board.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join("three-samples.png")))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("red-motion")))
 for i in range(18):
  cards[2].advance_time(.09)
  await process_frame;await RenderingServer.frame_post_draw
  var frame := viewports[2].get_texture().get_image()
  frame.resize(384,512,Image.INTERPOLATE_LANCZOS)
  frame.save_png(ProjectSettings.globalize_path(output.path_join("red-motion/%02d.png"%i)))
 print("MEME_SAMPLES_RENDERED "+ProjectSettings.globalize_path(output))
 for view in viewports:view.queue_free()
 board.queue_free();await process_frame;await create_timer(.1).timeout
 quit()
