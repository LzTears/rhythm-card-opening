# 白/绿统一卡框实际完整提示词

2026-11-13。最终分工grade_0及grade_1两张；red_meme已由主线程明确转交C，本代理没有调用。两次均使用内置`image_gen.imagegen`，`transparent_background=true`，`referenced_image_paths`仅一个：`C:/Users/Administrator/Desktop/代号1/圆卡旋风/assets/collection/red-reference-alignment/frame_galaxy.png`；未传num_last_images_to_include。调用前已view_image该唯一几何模板，另看旧grade4只是了解既有装饰，未把旧grade4传给工具。

原生两张均1086×1448 RGBA，独立调用非atlas；sprite-gen原生slice-sheet做1×1机械contain缩放至768×1024。不手绘、不Pillow改设计、不裁切拉伸牌匾、不换alpha窗形状。最终微小像素边界差见QA。

## grade_0

native: `sources/grade_0-native.png`，正式：`../grade_0.png`。

```text
EDIT THE ATTACHED EXACT CARD-FRAME TEMPLATE ONLY. This is a strict material/rarity variant, NOT a redesign. Preserve pixel-relative geometry of the supplied 768x1024 template: same rounded outer3:4 silhouette; same top centered EMPTY cream rarity plaque (approximately x260..510,y14..79); same huge EMPTY TRANSPARENT illustration opening (approximately x31..737,y85..705); same centered EMPTY smaller theme plaque just under window (approximately x299..470,y729..775); same broad cream paper name/description field below and same horizontal divider at y890. Preserve every panel boundary, plaque size, plaque position, window curve and dividing-line position exactly as reference. No top/bottom band relocation, no wider or taller illustration hole. Change ONLY colors, materials and richness to COMMON WHITE rarity: warm IVORY cream textured paper, elegant SILVER-WHITE fine embossed bevels and pale silver outer rim, restrained simple silver line accents at existing ornament locations, fewer tiny decorative dots, much calmer than red. Both cream plaques and entire lower paper text field remain light warm cream and blank. No text, no letters, no numbers, no logos, no artwork inside window. Native REAL transparent alpha throughout entire illustration window and outside card corners, absolutely no black/white/gray fill or checkerboard or fog inside opening. Keep same front orthographic template, full card bounds identical. Do not change source layout or add any new panels. Output single portrait card frame, not multiple cards.
```

## grade_1

native: `sources/grade_1-native.png`，正式：`../grade_1.png`。

```text
EDIT ATTACHED CARD FRAME TEMPLATE ONLY, strict geometry-locked rarity MATERIAL VARIANT, not a redesign. Preserve exactly same proportions and every structural boundary of supplied 768x1024 red GAL frame: 3:4 rounded outer silhouette; centered empty top CREAM rarity plaque at x260..510,y14..79; large true-alpha empty artwork window at x31..737,y85..705, with same curved upper corners and lower edge; centered small empty CREAM theme plaque at x299..470,y729..775 immediately beneath window; same broad lower cream name and description paper field and horizontal divider y890. DO NOT move, enlarge, shrink or replace any plaque or text region. Change ONLY surface colors/material and decoration richness to RARE GREEN: clearly EMERALD GREEN textured paper and lacquer-foil outer border, restrained thin GOLD beveled trim, elegant delicate gold linework at EXISTING ornament positions, modest layered highlights slightly richer than common white but less busy than red legendary. Keep both plaques and entire lower paper area light warm CREAM and completely blank. Same source front orthographic framing fills canvas, no perspective. All original layout geometry must match red template after proportional scaling. Real native transparent alpha inside ENTIRE artwork opening and outside rounded corners, NO opaque fill, NO checkerboard, no black painted center, no fog or haze in window. No text letters numbers logos or artwork. Single finished frame portrait, not multiple cards. Do not add extra panels or a different title strip.
```

