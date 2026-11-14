# 正式皮肤媒体记录

完整实际生图提示词见`prompts.md`，含两底图、两套卡包v1与v2的逐字原串、工具参数及真实输出尺寸。下文提示规格摘要不替代该完整记录。

## 2026-11-13 卡包宽身修订 v2（当前正式版本）

用户实机反馈旧包体过瘦、透明边过大，因此用内置image_gen重新绘制两套五色atlas，不对旧素材做非等比拉伸。当前十个`pack_{style}_0..4.png`已更新为300×400。原十贴图与原提取报告保存在`archive/pack-v1/`，旧atlas仍在sources；新atlas为`sources/pack_starlight_atlas_v2.png`与`pack_neon_atlas_v2.png`。

明确提示每个完整软包为宽身短袋、可见宽高比3:4，保留五色顺序、星旋纹/像素旋纹、上下完整锯齿封边、真实透明底；禁止细长糖果袋、烟雾或外部阴影。sprite-gen原生slice-sheet仍以5×1、真实alpha、floor64、sheet scale、contain fit提取，但目标画布改300×400，目标主体高392、底线396。所有十包报告`clipped_px=0`。

`pack-v2-manifest.json`记录原始尺寸、提取命令及路径；`pack-v2-qa.json`逐图记录alpha≥64可见bbox。十包实测宽占画布93.0%～96.7%、高96.5%～97.3%，可见宽高比0.723～0.746，均达到宽≥90%和高≥92%的要求。已查看两张源atlas及两套导出白包，封边完整；实机映射由主线程验收。

以下为v1历史记录，当前卡包尺寸与当前提取参数以v2记录为准。

2026-11-12～13，内置image_gen实际绘画。没有API后端切换或代码绘画。

- `board_starlight.png`：1672×941不透明，深紫纸艺星桌，极低对比星纹，外围细金纸层，无HUD/字/包/中心圈。
- `board_neon.png`：1672×941不透明，深蓝低对比数字格，外围青粉电路线，无HUD/字/包/中心圈。
- `pack_starlight_0..4.png`与`pack_neon_0..4.png`：288×384 RGBA，阅读顺序白、绿、紫、金、红。前者星纹箔面＋原创星旋纹，后者电路箔面＋原创像素旋纹；完整软包装封边，无字。

两包atlas原始尺寸1774×887，保存在`sources/`。提取使用sprite-gen `slice-sheet --grid 5x1 --chroma-key none --alpha-floor 64 --scale sheet --fit contain`，真实alpha保留，目标主体高366px，底线375。提取/alpha报告同目录，五包各自`clipped_px=0`。

提示规格摘要（非逐字转录）：board为full bleed top-down orthographic tabletop texture，仅外围4～5%装饰，central90% calm dark empty playfield，no UI/cards/packets/text/circle。星款为tactile navy indigo violet paper with cream gold orbital edge，数字款为charcoal navy faint grid with cyan magenta pixel circuit corners。卡包为exactly five complete upright soft foil packets in one horizontal row, equal spacing, transparent gutters, visible crimped top/bottom seals, native alpha, no typography；五色固定不被主题色覆盖。

参考风格来自已确认`docs/concepts/skins-v1/`两张效果板。board保持生成原始近16:9比例，由现有桌面材质映射到14.4×6平面；没有伪报2.4:1原生尺寸。节拍皮肤图标由代码绘制，本目录不冒称另有节拍位图。
