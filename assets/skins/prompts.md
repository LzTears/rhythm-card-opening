# 皮肤素材完整提示词记录

2026-11-12～13。下列代码块逐字记录本代理本次实际传入内置`image_gen.imagegen`的`prompt`字符串，区别于PROVENANCE中的摘要。所有调用均未传`referenced_image_paths`或`num_last_images_to_include`。正文写出的目标分辨率是提示要求，不代表实际返回；真实尺寸分别注明。

## board_starlight

正式文件`board_starlight.png`，真实1672×941；`transparent_background=false`。

```text
Game production texture, 16:9 landscape 1536x864 or larger. Full bleed top-down flat tabletop surface ONLY for celestial layered papercraft card game. Deep dark navy indigo violet textured fine paper. Low contrast tiny stars, restrained layered orbital paper ribbons with subtle cream gold edge highlights only along outer 5 percent perimeter and corners. Very calm empty dark central 90 percent with extremely faint star pattern, usable beneath scattered game objects. Match sophisticated handmade purple paper celestial aesthetic. Orthographic flat view. No cards, no packets, no circle, no ring in center, no HUD, no panels, no text, no numbers, no logo, no buttons. Finished clean game background.
```

## board_neon

正式文件`board_neon.png`，真实1672×941；`transparent_background=false`。

```text
Production game tabletop background texture, 16:9 1536x864 or larger full bleed. Flat orthographic top-down dark navy charcoal paper surface, subtle extremely faint digital square grid across calm empty central 90 percent. Thin restrained cyan and magenta luminous circuit trace accents confined to outer 4 percent perimeter corners, layered clean paper edges, tiny luminous pixel blocks at corners. Premium restrained neon digital collectible-card tabletop. No cards, no packs, no UI, no panels, no central circle or ring, no text, no logo, no numbers, no machinery. Center stays very dark low contrast for gameplay readability.
```

## pack_starlight v1（历史版本）

输出`sources/pack_starlight_atlas.png`，真实1774×887；`transparent_background=true`。初次导出288×384，旧图与报告现存`archive/pack-v1/`。当前正式贴图已被下面v2替代。

```text
Production sprite sheet on REAL TRANSPARENT BACKGROUND, wide landscape canvas. EXACTLY FIVE separate complete front-facing soft sealed trading-card foil packets in ONE horizontal row, equally spaced with ample clear transparent gutters, each fully inside canvas, same size and upright silhouette, no overlap, each tall 2:3 ratio. Reading order left to right WHITE silver pearlescent, EMERALD GREEN, PURPLE amethyst, GOLD yellow, RUBY RED. Luxury celestial star patterned holographic soft foil with visible crimped zigzag top and bottom seals and subtle folded side seams. Large original abstract star-swirl emblem embossed in center, tiny star shapes in foil, cream gold restrained glints. Beautiful tactile paper fantasy style, detailed material, flat orthographic front view. No typography no letters no numerals no logos no labels no shadows outside each packet. Keep all five complete packet boundaries visible, including entire top and bottom seal. Native transparent alpha, no checkerboard.
```

## pack_neon v1（历史版本）

输出`sources/pack_neon_atlas.png`，真实1774×887；`transparent_background=true`。初次导出288×384，旧图与报告现存`archive/pack-v1/`。当前正式贴图已被下面v2替代。

```text
Production transparent sprite sheet. EXACTLY FIVE complete separate upright sealed soft foil trading card packets in ONE horizontal row, same size, equally spaced in 5 equal invisible cells, ample transparent gutters. Full packages top and bottom sealed crimped edges visible, no cropping. Shape tall 2:3 ratio, flat front orthographic view. Five foil colors in reading order WHITE SILVER, EMERALD GREEN, PURPLE, YELLOW GOLD, RUBY RED. Neon digital skin: delicate angular circuitry etched on each foil wrapper, small square luminous pixel accents and an ORIGINAL abstract pixel spiral swirl embossed in center. Each stays clearly its rarity color. Premium anime-game foil packet rendering, soft material folds not rigid boxes, no typography letters numbers logos labels or panels. Native transparent alpha around all objects, no checkerboard, no external shadows.
```

## pack_starlight v2（当前正式版本）

输出`sources/pack_starlight_atlas_v2.png`，真实2172×724；`transparent_background=true`。sprite-gen提取正式`pack_starlight_0..4.png`各300×400；完整提取参数与alpha bbox见`pack-v2-manifest.json`、`pack-v2-qa.json`。

```text
Production game sprite atlas, exactly FIVE full SOFT FOIL CARD PACKETS in one horizontal row. CRITICAL SILHOUETTE: each complete packet is a BROAD SHORT RECTANGLE with WIDTH exactly THREE QUARTERS of HEIGHT (3:4 width:height, example 300 pixels wide by400 high), similar wide sealed trading card booster pouch. NOT narrow slim candy bags. Same front-on upright width and height for all five. Each whole packet, including its crimped top and bottom seals, is entirely visible. Equally spaced isolated packets, generous transparent gutters. Colors reading order WHITE SILVER, EMERALD GREEN, AMETHYST PURPLE, YELLOW GOLD, RUBY RED. Celestial star skin: holographic foil soft folded wrapper, embossed original star-and-spiral medallion in center, fine tiny star shapes and flowing curved star-trails in foil, restrained cream gold edging, luxury tactile paper fantasy game style. Wide body with gently rounded soft sides and clear zigzag sealed edges top and bottom. REAL TRANSPARENT ALPHA background only. Absolutely no fog or haze, no backdrop no table no cast shadows, no letters words numbers labels logos. Do not distort to tall thin rectangular packets. Width 0.75 times height for EACH of five packets; make each as wide as possible relative to height while maintaining 3:4.
```

## pack_neon v2（当前正式版本）

输出`sources/pack_neon_atlas_v2.png`，真实1402×1122；`transparent_background=true`。sprite-gen提取正式`pack_neon_0..4.png`各300×400；完整提取参数与alpha bbox见`pack-v2-manifest.json`、`pack-v2-qa.json`。

```text
Production game sprite atlas, exactly FIVE isolated complete SOFT FOIL CARD BOOSTER PACKETS in ONE horizontal row. CRITICAL each packet must be SHORT AND WIDE, exact 3:4 WIDTH TO HEIGHT silhouette (for example300px wide400px tall), NOT narrow skinny candy pouches. All five same upright front-facing shape, full sealed zigzag crimped top and bottom edges visible, no clipping, sufficient clear gutters. Reading order SILVER WHITE, EMERALD GREEN, AMETHYST PURPLE, YELLOW GOLD, RUBY RED. Neon digital skin: intricate delicate circuitry etched in foil, luminous angular pixel blocks and short circuit paths, ORIGINAL abstract pixel spiral emblem large in center, subtle raised foil seams, soft realistic folded wrapper. Each color remains obvious and dominant, not all cyan. Premium polished anime game material rendering, broad pouch with full wide printed face, no typography text letters numbers franchise logos. Orthographic flat front view, no perspective. NATIVE REAL TRANSPARENT ALPHA BACKGROUND, NO fog NO haze NO glow outside packet NO white background NO cast shadow. Exactly FIVE wide3:4 complete packets.
```
