# 多主题卡牌 V2 完整提示词

2026-11-12。内置 image_gen，两个新generate调用，每主题一张，各五张卡。没有使用CLI、代码绘图、修图或追加图。

## 参考与生成方式

沿用此前已目视检查的V1纸质框/宇宙配色，V2按文字重新指定简化通用框架；没有传入参考图参数，也没有编辑V1。第二板通过提示词明确复用第一板几何与文字层级，并独立生成。

## 1 星系主题

```text
Use case: product-mockup
Asset type: high resolution ultra-wide collectible card concept comparison board, exactly FIVE complete portrait cards side by side.
Primary request: A universal collectible card template that can support many unrelated themes. This first board is the 星系 theme. Five cards, identical size and identical 2:3 outer silhouette, aligned, fully visible with no clipping. Use one neutral deep purple background. No game UI, no scrapbook or album pages. Five cards fill most of a very wide large-resolution landscape canvas; prioritize complete readable cards and Chinese text.
UNIVERSAL TEMPLATE, preserve for a second Digimon-themed board: simple rounded rectangular cream paper card. Top narrow header with rarity Chinese label centered; thin outer rarity-colored frame; large illustration window occupying upper ~64% of card; bottom cream text block occupying ~28%, containing tiny theme identifier above bold centered name, then one short description. Exact same header height, art window shape, type scale, text block geometry, border proportions across every card. Restrained premium paper frame, substantially simpler than elaborate fantasy trading cards. This is a reusable template, theme ornament must stay inside the art or small replaceable corners.
Left to right rarity: white 普通, green 稀有, purple 史诗, gold 传说, red 绝版. Color only the outer frame and rarity badge, NEVER tint an entire illustration to match rarity. Frame complexity ascends subtly: white single flat paper rim; green double rim and two tiny corner notches; purple three paper layers with tiny foil accents; gold thin foil inlay and elegant corners; red rich red lacquer-paper rim and selective refined embossing. No hidden-card mark, no sixth rarity. No stats, no rules, no power numbers.
All five have theme identifier 星系 in the same position. Content left to right:
1 普通 / 星系 / 月球 / 银灰月面，静候星光。 Illustration: cream silver gray moon with paper-cut craters against navy, distinct round moon silhouette.
2 稀有 / 星系 / 地球 / 蔚蓝家园，孕育万物。 Illustration: clear blue and turquoise Earth globe, green continents, cream clouds, layered paper.
3 史诗 / 星系 / 猎户座 / 群星连缀，点亮长夜。 Illustration: artistic minimal constellation suggestion, a few bright paper stars and exactly a simple three-star straight belt; use an artful schematic, avoid complicated or falsely accurate constellation connections.
4 传说 / 星系 / 银河 / 万千星光，汇成天河。 Illustration: sweeping milky-way river of tiny layered paper stars in navy cyan violet, warm cream glow, not a spiral galaxy portrait.
5 绝版 / 星系 / 黑洞 / 光的尽头，深空之眼。 Illustration: distinct black circular void with luminous cyan violet cream accretion ring, layered paper vortex, not red-tinted.
Illustration style: premium layered paper-cut cosmic art, rich depth through paper layers, navy cyan-blue violet universe with cream light, adorable collectible charm without faces. Subject artwork uses its own colors independent of frame rarity. Theme-specific small star points and orbital arcs are restrained and replaceable, not structural frame geometry.
Put a small clean title 星系主题 above the five cards. Exact Chinese text, crisp and readable. No logo, watermark, borrowed game UI, heavy metallic frame, album, extra cards, invented economics or numbers. This is a visual rarity sample, not final character/content grading.
```

## 2 数码宝贝主题

```text
Use case: product-mockup
Asset type: high resolution wide collectible card concept comparison board, exactly FIVE complete portrait cards side by side.
Primary request: Second themed board in a universal expandable collectible card system. Theme is 数码宝贝 (Digimon). Produce authentic recognizable fan-art of these named Digimon characters, not generic substitutes. Five equal-size aligned cards, fully visible, white green purple gold red left to right. This is a visual template demonstration, not final character rarity assignment.
STRUCTURE TO MATCH THE PREVIOUS GALAXY BOARD: neutral dark purple background with title 数码宝贝主题 centered at top; five cream paper rounded portrait rectangles side by side below; identical header, art window, text block and border proportions on every card. Top small centered cream rarity banner; big art window begins immediately below it and fills upper ~64%; lower cream block contains tiny theme identifier, bold name, and one short description, all centered. Same type hierarchy, positions and card silhouette as the previous board. Keep the universal frame simple, no album pages or UI.
Rarity frames: white 普通 single paper rim; green 稀有 double paper rim; purple 史诗 multilayer paper with tiny foil; gold 传说 restrained foil inlay and light corners; red 绝版 lacquer-paper rim with refined fine embossing. Only outer borders and rarity badge accents follow rarity color. Do not tint character art to rarity. No sixth rarity and NO hidden marks. Theme-specific decoration limited to tiny replaceable digital pixels or subtle circuit marks within illustration corners, not heavy mechanical chassis.
Exactly these five authentic Digimon fan-art subjects left to right:
1 rarity 普通, theme 数码宝贝, name 滚球兽, description 小小身躯，满怀好奇。 Authentic Koromon: small round pink blob body, long thin pink rabbit-like ears, large red eyes, small fang mouth, no arms or legs; cute lively pose.
2 rarity 稀有, theme 数码宝贝, name 亚古兽, description 勇气萌芽，伙伴同行。 Authentic Agumon: small orange-yellow upright dinosaur, green eyes, broad reptile snout, three white claws on hands and feet, friendly confident pose.
3 rarity 史诗, theme 数码宝贝, name 暴龙兽, description 巨角烈焰，昂首迎战。 Authentic Greymon: orange muscular tyrannosaur with blue body stripes, distinctive brown bony skull helmet with three horns including prominent nose horn, sharp white teeth, roaring dynamic pose.
4 rarity 传说, theme 数码宝贝, name 战斗暴龙兽, description 黄金铠甲，迎向强敌。 Authentic WarGreymon: heroic humanoid orange dragon warrior, long red hair, silver and gold dragon armor, distinctive silver horned helmet, huge silver Dramon-killer claw gauntlets on both arms, split brave-shield pieces on back. Accurate recognizable original design, energetic pose.
5 rarity 绝版, theme 数码宝贝, name 奥米加兽, description 双臂合一，守护希望。 Authentic Omegamon/Omnimon: elegant white armored knight with flowing white cape and golden V-shaped horned helmet, blue eyes; anatomical LEFT arm is orange Greymon dragon head ending in a long sword, anatomical RIGHT arm is blue MetalGarurumon wolf head cannon. Front three-quarter heroic stance, show both recognizable weapon arms; cape must be white. Keep character entirely inside art window without covering name or description.
Illustration medium: high-quality clean Japanese cel-shaded anime fan-art, crisp linework, faithful character colors, dynamic but readable individual poses, subtle digital backdrop inside each window, no space motifs. Art may use a different medium from the paper-cut galaxy theme, but surrounding card layout and rarity logic remain universal and identical. All five characters must remain recognizable in their named franchise forms.
Exact Chinese labels and descriptions, readable text; long 战斗暴龙兽 fits same name area using slightly smaller type only if needed. A small clean title 数码宝贝主题 above cards. No franchise trademark logo, no watermark, no game rules, stats, battle values, invented numbers, hidden marks, extra cards, album or menu UI.
```
