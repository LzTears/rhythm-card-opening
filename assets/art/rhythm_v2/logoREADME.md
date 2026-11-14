# 《节拍开卡》菜单字标

2026-11-12。`game-logo.png` 为本项目新游戏名透明字标，使用内置 `image_gen` 生成，未使用 CLI/API 或程序绘制汉字。

- 文案：节拍开卡。单行四字，无书名号、英文或副标题。
- 风格：粗笔手剪纸字形；暖米白、珊瑚玫瑰字面及偏移深紫纸片底层，与紫色剪影菜单背景配套。
- 成品：RGBA PNG，2144×671；按透明边缘裁切并保留 8px 透明留白，完整保留生成 alpha。约 3.20:1，等比适配菜单 726×220 容器。
- 来源：`C:/Users/Administrator/.codex/generated_images/01a1cf99-8df7-7352-81ba-622fd973c642/exec-03333c4e-d36d-4495-ad13-a09f131e5a20.png`。原始图 2172×724。
- 检查：目检四字、纸片风格和完整裁边；alpha 范围 0–255。无机械护角、螺钉。没有启动 Godot；运行布局由主线程集成验收。

## 生成提示词

```text
Use case: logo-brand.
Asset type: transparent PNG wordmark for Chinese rhythm card-opening game main menu, displayed in a 726x220 container on a muted deep purple paper silhouette background.
Primary request: Create an original, beautifully legible Chinese cut-paper title logo with EXACTLY these four Chinese characters in a SINGLE HORIZONTAL ROW: 节拍开卡
Text (verbatim): "节拍开卡"
Read left to right: first 节 (艹 over 卩), second 拍 (扌 beside 白), third 开, fourth 卡. All four complete and correct. Do not add any other text, quotation marks, book-title brackets, Latin letters, subtitles or numerals.
Style/medium: hand-cut thick paper lettering, confident chunky strokes, bold irregular hand-cut edges, slightly playful rhythmic offsets, clean sharp readable interior counters. Warm ivory main letter faces with restrained coral rose paper accents and slightly offset deep purple silhouette backing. Flat layered paper, subtle paper grain, no 3D metallic treatment.
Composition: wide compact title, approximately 3.3:1 visible artwork ratio, each of the four characters equally prominent. The characters occupy almost all of the width, with generous clear transparent padding so no strokes or backing are clipped. Horizontal single line. Thick strokes remain clear at small menu size.
Scene/backdrop: genuine transparent alpha background, NO colored rectangle, NO white field, NO checkerboard printed into the artwork.
Constraints: originality, wordmark only, minimal unobtrusive decoration, simple silhouettes; retain readable Chinese structure. Avoid mechanical corner guards, screws, rivets, metal borders, shiny bevels, cards or musical notes covering letters, icons, scenery, extra words, watermarks.
```
