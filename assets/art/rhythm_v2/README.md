# 节奏剪影背景 v2

生成日期：2026-11-12。来源：OpenAI 内置 image_gen，原生 bitmap，无程序绘制替代。参考用户提供的 Patapon 紫色剪影截图，只借鉴纸片剪影、图腾与四拍图形语言，未复用角色或标识。

- ui-background.png：全屏局外背景，中央保持空旷供真实 UI 使用。
- battle-table.png：完整战斗桌面，单次 UV 映射到 14.4×6 平面，非平铺纹理。边缘四拍图形为装饰，不表示有效拍点或游戏判定。
- World 接入：scripts/world_view.gd 使用新路径，统一 PlaneMesh UV，背景环境和桌沿采用紫靛配色。镜头、碰撞、坐标和桌面尺寸保持现行规则。

已目视检查生成结果：没有文字、水印、角色或旧工坊蓝图网格；中央低对比。实际游戏渲染验收由主线程统一执行。

## UI 原始提示词

```text
Use case: stylized-concept
Asset type: production bitmap background for a 16:9 rhythm card game menu, 1920x1080 landscape.
Primary request: original playful purple silhouette rhythm world inspired by the attached reference's flat cut-paper visual grammar. This is ONLY the empty background layer beneath menu UI, not a screenshot or UI mockup.
Input images: viewed reference 303cd418 shows lavender sky, purple abstract totem silhouettes and round branching trees. Use its flat shapes and rhythm, do not copy its characters or logo.
Scene: midnight indigo paper stage with layered violet hills, abstract geometric drum-totem silhouettes and circular branching trees concentrated along the extreme left and right margins and bottom corners. Tiny sparse warm coral and cream diamond accents form a quiet syncopated rhythm at the outer perimeter.
Composition: widescreen 16:9. The entire central 74% width and 80% height must be exceptionally empty, a smooth muted deep purple field suitable for multiple opaque text panels. Decorative silhouette forms only in outer 12% left and right and lowest 10%, no central focal object. Quiet large forms, broad simple solid-color layers.
Style: crisp hard-edged cut paper illustration, limited 6-color palette, slightly irregular hand-cut contours, graphic and minimal, compatible with pixel art game objects laid on top. Lavender on upper edges, deep muted purple center, very dark indigo lower corners. Background-level low contrast.
Constraints: no text, no letters, no numerals, no logo, no watermark, no characters, no creatures, no cards, no UI controls, no frames, no metal, no industrial workshop, no blueprint grid. No border around image. No glow effects. This is new original scenery.
```

## 战斗桌面原始提示词

```text
Use case: stylized-concept
Asset type: production bitmap ground texture for a top-down rhythm game battle tabletop. Ultrawide 2400x1000, aspect ratio 2.4:1. Single complete unbroken ground image mapped once to a rectangular plane, not a menu.
Primary request: a quiet indigo-purple paper ritual stage, graphic rhythm language inspired by lavender silhouette totem scenery, with repeated syncopated geometric cut-paper motifs confined to outer perimeter.
Composition: strictly orthographic TOP-DOWN flat texture, no horizon or perspective. Central 88% width and 74% height an almost uniform very dark muted indigo-purple (#25203f to #30274d), absolutely empty and low contrast so bright silver pixel card packets and cream hit numbers remain legible anywhere. Outer perimeter a thin irregular layered paper strip, deep plum and lavender, with sparse tiny cream circles, coral diamonds, and triangular rhythm tick marks organized into groups of four. Upper/lower perimeter under 8% height, left/right under 5% width. No large corner decorations. No bright central shapes.
Style: hard edge paper silhouette, confident simple original shapes, subtle matte paper grain, limited flat color palette, hand-cut contour, no realism. Echo a playful rhythm game stage without copying any specific franchise artwork.
Constraints: no text, letters, digits, logo, watermark, UI, characters, cards, creatures, guns, objects, hardware screws, industrial rails, blueprint grid, ruled lines, tabletop wood, lens glow, rings, circles at center, target or diagram. The image is just ground and perimeter markings, complete canvas, no external shadow. Keep all playable central space quiet.
```
