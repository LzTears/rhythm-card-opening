# 收藏素材完整提示词记录

## 三张插画安全边修复（2026-11-13追加）

实际调用内置`image_gen.imagegen`编辑，`transparent_background=false`，每次使用`referenced_image_paths`包含下面一个本地文件，未传`num_last_images_to_include`。全部实际输出1086×1448；以下为实际prompt原串。原版三张与旧manifest可从`archive/edge-repair-v1/`恢复。引用图为相对路径时，实际传入前缀为`C:/Users/Administrator/Desktop/代号1/圆卡旋风/assets/collection/`。

### DIG-033 首次补全（中间稿）

reference: `archive/edge-repair-v1/DIG-033.png`；output: `sources/DIG-033-edge-repair-pass1.png`。

```text
Edit this existing illustration, preserving exactly its blue-purple beetle Digimon character identity and design: curved rhino horn helmet, four segmented arms and claws, four translucent white insect wings, blue armored torso, legs and clawed feet, pink mouth, cel-shaded anime outlines and navy cyan digital circuit environment. Repair the cut-off left and right wing tips by OUTPAINTING and recomposing the character SMALLER inside a taller portrait 3:4 canvas. Show the ENTIRE character, including complete tips of ALL FOUR WINGS, highest horn, all four hands and every claw, both feet, nothing touches canvas edges. Reserve at least TEN PERCENT clean digital background margin on ALL FOUR SIDES around the complete silhouette, ideally 12 percent. Wings must taper naturally to complete pointed tips visible within the image, never terminate at a straight canvas edge. Full body central upright composition, match original cel shading and existing color palette, retain subtle cyan circuit grid and pixel motes background. Do not add text, card frames, extra characters, new weapons or change the original creature's anatomy. This is a framing and missing-wing-tip repair of the attached character, not a redesign.
```

### DIG-033 最终安全边修订

reference: `C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c/exec-25012594-2010-4d8a-9573-ae9a772916bc.png`；output: `sources/DIG-033-edge-repair.png`。

```text
Use this already repaired blue-purple four-armed insect Digimon illustration as the exact source. Preserve its design, pose, all four complete white insect wings, horn helmet, four arms and claws, feet, blue anime cel-shading and cyan navy circuit-grid background. Only zoom the ENTIRE CHARACTER out by about 18 percent relative to this source, keeping it centered, so ALL wing tips, horn tips, hands and feet have AT LEAST 15 PERCENT background clearance from each canvas edge. Keep canvas portrait3:4. The lower left wing tip currently sits too near the left boundary; that tip must move inward with the whole character while remaining complete. Every wing and foot must retain its existing shape with no clipping, no stretching, no anatomy change. Fill expanded surrounding space with matching existing digital background, no text no frames no new elements. All silhouette extrema fit inside the central70% of image width and central70% of image height.
```

### DIG-036 翼尖补全

reference: `archive/edge-repair-v1/DIG-036.png`；output: `sources/DIG-036-edge-repair.png`。

```text
Edit the attached existing winged angel Digimon illustration ONLY to repair its upper clipped wing tips and improve framing. Preserve the exact same character design, silver winged eye-covering helmet, orange long hair, white fitted costume, blue-purple cloth ribbons, gold staff, white feather wings, colors, anime cel-shading and navy cyan digital circuit background. Reconstruct complete natural pointed feather tips on the top wings, and recompose the ENTIRE existing full-body silhouette SMALLER and centered inside a 3:4 portrait image. CRITICAL SAFE MARGIN: every wing tip, helmet ornament, staff tip, ribbon, hand and boot must remain within central 68% of canvas width and central 72% of canvas height, leaving at least 14-16 percent clean background on ALL FOUR SIDES. All wings fully visible, absolutely no part touches any image edge. Keep the original wing arrangement, staff and anatomy without adding new characters or extra limbs. Retain subtle cyan digital circuit environment and cel-shaded outlines. No text, no card frame, no redesign. Finish with complete feathers, not straight clipped feather ends.
```

### DIG-041 翼尖补全

reference: `archive/edge-repair-v1/DIG-041.png`；output: `sources/DIG-041-edge-repair.png`。

```text
Edit the attached existing blue-silver mechanical WOLF Digimon illustration, preserving its exact quadruped robotic wolf design, long metal muzzle, red eyes, silver-blue armored limbs and red claw tips, shoulder missile ports, golden angular blade wings, original dynamic flying pose and anime cel-shaded colors. Do NOT replace it with a dinosaur or another Digimon. Repair the upper-right golden blade wing that is near/clipped by the top-right edge, reconstruct its full naturally pointed tip, and reframe the WHOLE existing creature smaller, centered in a clean 3:4 portrait canvas. Keep every wing tip, muzzle, spikes, all four feet/claws and tail entirely within central 68% width and central72% height, leaving at least 14 percent clean navy cyan digital-background margin on all four sides. No part may touch any canvas edge. Preserve both complete golden wings and full body anatomy. Retain subtle glowing blue circuit-grid digital space and pixel data background matching original. No added text, no card frame, no extra characters, no redesign. This is outpainting/recomposition for complete full-body safe framing, not a character change.
```


## 数码宝贝独立五色卡背

2026-11-13追加。内置`image_gen.imagegen`，`transparent_background=true`，未传引用图参数。输出`sources/digimon-backs-atlas.png`真实1983×793；sprite-gen提取`backs/digimon_back_0.png`～`digimon_back_4.png`各288×384 RGBA。以下是实际传入prompt的完整原串：

```text
Production game asset sprite atlas: EXACTLY FIVE complete upright COLLECTIBLE CARD BACKS in ONE horizontal row, equal spacing, all same rounded 3:4 width-to-height rectangular silhouette, all fully visible within canvas, generous transparent gutters, flat orthographic frontal view with absolutely NO perspective. Reading order WHITE SILVER, EMERALD GREEN, AMETHYST PURPLE, YELLOW GOLD, RUBY RED. A new DIGIMON DIGITAL WORLD theme, visibly different from celestial spiral cards: delicate embossed angular CIRCUIT TRACES and tiny square data nodes across each closed foil back, a large centered DIGITAL EGG medallion, a clean upright ivory egg silhouette marked with small abstract digital geometric spots, set in a raised metallic hexagonal circuit cradle. Egg emblem is the primary unmistakable symbol on every card; NO spiral, NO galaxy, NO stars. Premium tactile collectible paper and foil material, sculpted raised metallic engraving, strong tier colors. White common is elegant pearl-silver paper with restrained fine silver circuits; green adds layered emerald foil and restrained gold circuitry; purple has richer amethyst and silver-gold circuit filigree; gold is ornate luxurious golden raised circuit embossing; red is deep ruby lacquer foil with exquisite rich gold circuit lattice and tiny ruby gem corners. Maintain consistent family and same egg emblem geometry across five grades, increasing ornament richness left to right. Closed COMPLETE BACK FACE, no transparent holes within cards, no top label strip no bottom text panel. NO text NO letters NO numbers NO logos NO characters. REAL native transparent alpha outside all five cards only, no backdrop, NO fog NO haze NO smoky vignette, no external shadow, no white background, no checkerboard. Wide high resolution canvas, all five card edges intact.
```

2026-11-12～13。下列代码块逐字记录本代理本次实际传入内置`image_gen.imagegen`的`prompt`字符串；不是PROVENANCE中的规格摘要。所有调用均未传`referenced_image_paths`或`num_last_images_to_include`。正文提及的目标尺寸是提示要求，真实返回尺寸以每节记录为准；导出裁切与九宫格重采样记录见manifest及build脚本。

## GAL-001～008

输出`sources/galaxy-001-008.png`，真实1448×1086；`transparent_background=false`。

```text
Create a production illustration atlas of EXACTLY EIGHT distinct celestial papercraft artworks, strict 4 columns by 2 rows, edge-to-edge equal rectangular cells, 2048x1536 if possible, every cell independent no artwork crossing cell borders. Each cell 3:4 portrait-ish, no visible frames borders captions labels text or typography. Consistent layered paper-cut universe style: deep indigo purple star background, tactile cut paper celestial subject, dimensional stacked layers, soft shadows, restrained glows. Distinct subjects in reading order: 1 silver gray full Moon with paper craters. 2 Mercury gray brown rocky round planet with narrow dawn rim. 3 Venus creamy gold round planet covered in broad cloud layers. 4 Mars rusty red planet with dark terrain shapes. 5 Ceres small gray round dwarf planet with two tiny bright spots. 6 Pluto icy tan brown dwarf planet with large pale heart-shaped surface region. 7 Phobos distinctly irregular angular dark asteroid-like moon with prominent large crater and red distant glow. 8 Deimos small smooth irregular pale brown rocky moon, sparse delicate debris. Exactly 8, each centered with generous breathing space, unique clear astronomy identity, not generic copies. No UI or card borders.
```

## GAL-009～016

输出`sources/galaxy-009-016.png`，真实1448×1086；`transparent_background=false`。

```text
Production collectible illustration atlas, EXACTLY EIGHT independent artworks in strict 4 columns x 2 rows equal rectangular grid, edge-to-edge cells NO frames NO labels NO text. High resolution 2048x1536. Layered papercraft celestial illustration style, deep violet midnight star backgrounds, tactile cut paper subjects and soft dimensional shadows, restrained glows. Reading order: 1 Io golden yellow orange volcanic round moon with dark spots and tiny lava vents; 2 Callisto deep brown sphere densely covered pale impact craters; 3 Charon gray round moon dark polar cap and long diagonal canyon; 4 Triton pale pink gray icy round moon with delicate frozen streaks; 5 Ursa Minor small translucent paper BEAR silhouette carrying the LITTLE DIPPER 7 connected bright stars with long curved tail, constellation; 6 Cassiopeia thin translucent crown silhouette with FIVE BRIGHT STARS in clear W shape; 7 Lyra thin small HARP silhouette and connected bright stars in compact parallelogram; 8 Cygnus spread-wing SWAN thin paper silhouette with CROSS-shaped linked stars. All 8 unique compositions, complete within their own cells, no bleed between cells. No typography or UI.
```

## GAL-017～022

输出`sources/galaxy-017-022.png`，真实1254×1254；`transparent_background=false`。

```text
Exactly SIX independent production celestial illustrations in a strict 3 columns x 2 rows uniform grid, 1536x1536 or larger square canvas. No frames, no labels, no text. Each independent cell full bleed with dark purple star field, centered complete subject safely inside cell. Luxurious dimensional layered cut-paper art with tactile paper edges and soft shadows. Reading order 1 Earth blue oceans green brown continents layered white clouds; 2 Jupiter giant sphere tan cream brown parallel cloud bands and Great Red Spot; 3 Saturn pale gold sphere with spectacular complete diagonal ring system front/back interleaving paper layers; 4 Uranus cyan turquoise planet with very thin steeply tilted rings; 5 Neptune rich deep blue sphere white cloud streaks and dark blue storm spot; 6 Europa ivory cream icy moon with many fine red brown crosshatched crack lines. Six CLEARLY DIFFERENT celestial identities, no UI card outlines.
```

## GAL-023～029

输出`sources/galaxy-023-029.png`，真实1448×1086；`transparent_background=false`。第八格仅背景，不另占卡ID。

```text
EXACTLY SEVEN independent celestial artworks, strict 4 columns by 2 rows grid, last bottom-right eighth cell empty dark star texture. Each uniform cell 3:4 portrait. High resolution. No text labels borders frames. Layered papercraft universe style, purple midnight star field, tactile cut paper depth, dimensional shadows, subtle magical glow. Reading order: 1 Ganymede moon with clearly divided dark brown ancient terrain and light gray grooved terrain, sphere; 2 Titan hazy orange gold sphere with translucent amber atmospheric paper layers; 3 Sun warm golden disk with layered flame corona and paper fire prominences; 4 Ursa Major large translucent bear silhouette with major constellation connected stars along back and tail; 5 Scorpius scorpion silhouette with long J-shaped hooked connected star chain and bright red heart star; 6 Leo lion silhouette with curved sickle constellation linked stars over mane; 7 Taurus bull head silhouette, wide horns and V-shaped bright linked stars with one red eye star. Distinct separate compositions, full subjects inside cells, no crossing borders. Empty cell 8 is texture only.
```

## GAL-030～035

输出`sources/galaxy-030-035.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY SIX independent celestial papercraft illustrations in strict equal 3 columns by 2 rows grid, square high resolution 1536 or larger. No labels text borders UI. Each complete composition in own cell, purple midnight background, elaborate layered cut paper depth, luminous highlights, soft shadows. Reading order: 1 ORION constellation translucent full body hunter silhouette with three bright aligned belt stars and linked shoulder/foot stars; 2 ANDROMEDA galaxy M31 inclined long elliptical bright star disk with bright core dark dust lane; 3 TRIANGULUM galaxy M33 face-on loose open spiral arms blue pink star knots; 4 WHIRLPOOL galaxy M51 face-on grand two-arm spiral with smaller companion galaxy attached by a thin luminous bridge; 5 SOMBRERO galaxy M104 distinctive edge-on hat-shaped white bulge and thin wide disk divided by prominent horizontal dark dust band; 6 PLEIADES M45 a cluster of seven prominent blue white luminous stars wrapped in delicate wispy blue translucent paper veil. Different identities, beautiful detailed layered paper space art. No words.
```

## GAL-036～039

输出`sources/galaxy-036-039.png`，真实1254×1254；`transparent_background=false`。

```text
Production art atlas EXACTLY FOUR celestial illustrations in strict 2x2 equal grid, square high resolution 1536. No text labels frames borders. Dimensional layered cut-paper astronomy art, deep purple universe, rich vibrant paper glow and intricate stacked paper layers. Reading order 1 Orion Nebula M42 a magnificent fan shaped pink violet emission cloud with luminous central Trapezium stars and one deep dark notch; 2 Lagoon Nebula M8 rich rose red clouds divided by a dark winding lagoon channel, clusters bright young stars; 3 Ring Nebula M57 oval rainbow cyan orange luminous ring surrounding deep dark hollow center and one tiny central star, complete ring; 4 Crab Nebula M1 an oval cocoon of detailed tangled orange red filament paper threads with luminous blue inner core and fragmented asymmetric edges. Dramatically different silhouettes, independent complete compositions, edge-to-edge cells. No UI.
```

## GAL-040～045

输出`sources/galaxy-040-045.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY SIX individual high quality celestial art illustrations in strict 3 columns 2 rows equal grid, high resolution square 1536. No text labels frames borders. Elaborate luminous layered cut paper art, tactile visible edges and dimensional shadows, deep purple midnight universe. Reading order: 1 Milky Way from inside galaxy, luminous SILVER WHITE STAR BAND sweeping diagonally across purple night, dark interstellar dust clouds and thousands star glints; 2 Hercules globular cluster M13 spherical dense golden white star ball, bright concentrated nucleus becoming sparse toward edges; 3 Dumbbell Nebula M27 two clearly opposed apple-core lobes of turquoise red gas with transparent outer shell and tiny central star; 4 Trifid Nebula M20 vivid red and blue cloud divided into three lobes by three-branch dark dust silhouette; 5 Black Eye galaxy M64 bright white central nucleus with striking curved dark eye-shadow dust crescent surrounded warm pale gold spiral disk; 6 Cigar galaxy M82 slender edge-on warm star disk with spectacular red outflow paper plumes above and below its center. Unique complete compositions all inside cells, not duplicate galaxies, no UI.
```

## GAL-046～049

输出`sources/galaxy-046-049.png`，真实1254×1254；`transparent_background=false`。

```text
Premium final production celestial art atlas, EXACTLY FOUR independent masterpiece illustrations strict 2x2 equal grid, square high resolution 2048x2048. No typography labels text frames card borders UI. Style intricate dramatic layered papercraft cosmos, sculpted paper edges with glowing thin rims, cinematic deep purple black space. Reading order: 1 BLACK HOLE concept with perfectly black circular void, brilliant curved golden orange accretion disk passing in front and gravitational lensing arc above, magenta red cosmic paper layers, no star inside black hole. 2 SUPERNOVA EXPLOSION EVENT instantaneous brilliant white gold star detonation at center surrounded numerous concentric expanding jagged red gold pink paper light shells, energetic radial starburst, not filament nebula. 3 PULSAR ROTATING NEUTRON STAR tiny brilliant blue white core and TWO OPPOSING long focused cyan beams emerging diagonally from magnetic poles, sweeping purple magnetic field arcs and glowing disk, clearly distinct from black hole. 4 PILLARS OF CREATION three majestic towering uneven dark dust gas columns, tallest on left middle smaller right, golden red glowing scalloped cloud edges with turquoise violet star field behind, monumental deep detail and tiny newborn stars. All four fully contained own cells, beautiful premium highly layered illustration.
```

## DIG-001～008

输出`sources/digimon-001-008.png`，真实1774×887；`transparent_background=false`。

```text
Production illustration atlas with EXACTLY EIGHT DIFFERENT authentic Digimon characters, strict 4 columns x 2 rows equal cells, each character completely inside own cell. High resolution 2048. Accurate official anime cel-shaded Digimon design, crisp dark outlines and rich cel shadows, cute dimensional character on subtle dark navy cyan digital-space background, tiny pixel motes no text no frames no UI. Reading order 1 KOROMON pink round ball, two long thin ear antennae, big red eyes and small toothy smiling mouth; 2 TSUNOMON orange shaggy ball, beige face and one long central horn; 3 YOKOMON/PYOCOMON pink round plant baby, blue-tipped pink flower atop leafy stem, six short root tentacles; 4 MOTIMON/MOCHIMON pale pink soft droplet blob with simple black dot eyes two short arms and little feet, no flower; 5 TANEMON pale beige spherical plant baby with green top and TWO fresh green leaves sprouting above head, tiny root feet; 6 BUKAMON/PUKAMON small beige-gray aquatic baby with orange tuft hair, large dark eyes and little flipper paws; 7 TOKOMON white soft round quadruped baby with tiny four legs and long ear stubs, innocent round face; 8 NYAROMON pale yellow round cat-like ball, two triangular ears and long yellow tail with purple stripes. Distinct accurate IP identities, not generic monsters, all full body. Each centered, no clipping.
```

## DIG-009～016

输出`sources/digimon-009-016.png`，真实1774×887；`transparent_background=false`。

```text
EXACTLY EIGHT independent authentic Digimon character illustrations, strict 4 columns 2 rows equal grid 2048x1024. Each character fully inside its cell, crisp accurate official anime cel-shaded style on quiet navy cyan digital space background, no labels text typography borders or UI. Reading order 1 DEMIVEEMON/CHIBIMON blue and white baby dragon, small blue head and blue limbs, white muzzle belly and cheeks, small pointed ears, standing happy with arms open; 2 MINOMON brown face peeking from leafy green hanging bagworm cocoon suspended tiny twig; 3 GIGIMON red orange quadruped baby with small dark red ears and black triangle markings, rounded puppy-like body; 4 GUMMYMON cream beige round baby with VERY long rounded horizontal green-tipped ears, tiny green central forehead horn, no humanoid body; 5 KOKOMON/CHOCOMON brown round blob baby, two long upright ear antennas and dark brown face mask, no humanoid body; 6 DORIMON purple fluffy round baby dinosaur, small triangular ears, tiny metal red jewel forehead and short little feet; 7 WANYAMON small round light blue furry cat-dog ball with dark blue stripe on forehead, cream muzzle and small triangular ears, no large body; 8 CUPIMON tiny white round cherub baby with tiny yellow central horn, small feather wings and gold ring halo. Clearly preserve distinct known IP designs, complete body, safe margins.
```

## DIG-017～022

输出`sources/digimon-017-022.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY SIX authentic Digimon character production illustrations in strict 3 columns x 2 rows equal grid, high resolution square. Crisp faithful official anime cel shade rendering dark outlines, dynamic friendly full body poses, subtle navy cyan digital space backgrounds. No text no labels no frames no UI. Reading order 1 AGUMON orange biped little dinosaur large green eyes pale claws white teeth, no armor; 2 GABUMON yellow reptile wearing blue white striped wolf fur pelt, single horn striped purple, pink nose, full body; 3 BIYOMON pink bird with blue feather tips and curled head plume, feather wings, yellow claws and leg ring; 4 TENTOMON red spotted ladybug beetle with green round eyes, segmented insect feet and pale wing membranes; 5 PALMON green plant child with large pink tropical flower atop head, leafy pointed hands, purple claws; 6 GOMAMON white furry seal-like quadruped, orange mohawk tuft, purple jagged marks and claws, smiling. Exactly the known Digimon, no generic substitutes, all appendages inside own cells safe margins.
```

## DIG-023～029

输出`sources/digimon-023-029.png`，真实1774×887；`transparent_background=false`。

```text
Production anime art atlas EXACTLY SEVEN authentic Digimon characters in strict 4 columns 2 rows grid, final bottom-right cell empty digital texture. High resolution wide 2048. Each complete subject contained own cell and dark navy cyan digital-space background, crisp faithful official anime cel shaded character art. No text labels UI frames. Reading order 1 PATAMON little orange white rounded mammal with enormous orange batlike ear wings extended, tiny blue eyes and four feet; 2 GATOMON/TAILMON white biped cat Digimon wearing large yellow striped fighting gloves with purple claws, long purple tipped tail with golden tail ring, blue eyes; 3 VEEMON/V-MON blue biped small dragon white muzzle belly, yellow V mark forehead and horned ears, confident dynamic running pose; 4 WORMMON green segmented plump caterpillar with pink antennae and MANY little legs, black markings, dark eyes; 5 GUILMON red biped dinosaur with black markings and black digital hazard emblem on white chest, long red tail, white claws; 6 TERRIERMON cream and pale green rabbit-dog biped Digimon with exceptionally long drooping ears, little forehead horn and green feet, smiling seated; 7 RENAMON tall slim golden yellow anthropomorphic fox Digimon, white chest fur, purple gloves with yin-yang symbols, poised elegant upright posture. Preserve official character identities and forms, not generic monsters, all limbs and ears inside cells.
```

## DIG-030～035

输出`sources/digimon-030-035.png`，真实1254×1254；`transparent_background=false`。

```text
Exactly SIX authentic DIGIMON Champions full-body portraits in strict 3 columns x 2 rows equal grid high res square. Precise recognizable official anime cel shaded character illustration, rich detailed dark outlines. Quiet navy cyan digital space behind each. No labels text borders frames. Reading order: 1 GREYMON CLASSIC original 1999 orange dinosaur with BLUE TIGER STRIPES, BROWN SKULL HELMET with THREE HORNS, NOT 2010 greymon, full muscular dinosaur body and tail; 2 GARURUMON blue white striped giant quadruped wolf, long purple tufts and spiky fur, fierce leap; 3 BIRDRAMON giant orange fire bird with ragged fiery orange wings, two blue eyes and huge long silver talons, full wings fit cell; 4 KABUTERIMON muscular BLUE insect humanoid Digimon with huge upward sweeping rhino beetle horn, FOUR ARMS and white wings, dark face no visible eyes, pink mouth; 5 TOGEMON big green cactus humanoid with RED BOXING GLOVES, three black oval face holes and orange crown needles, not flower girl; 6 IKKAKUMON white furry huge walrus seal beast with single long BLACK forehead horn, purple nose and long white tusks, large clawed paws. ALL appendages fit inside each independent cell with margins. Exact classic forms.
```

## DIG-036～039

输出`sources/digimon-036-039.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY FOUR authentic Digimon full-body illustrations in strict 2x2 equal grid high resolution square. Accurate classic official anime character cel-shaded art, detailed faithful armor designs, subtle navy cyan digital space background. No text labels card frames typography. Reading order 1 ANGEMON muscular masculine angel six white feather wings, blue silver winged HELMET concealing eyes, orange hair white fitted clothing and blue ribbons, long golden staff, entire body; 2 ANGEWOMON feminine angel eight white feather wings, silver winged helmet covering eyes, long blonde hair, white fitted leotard and white boot, pink ribbons, graceful bow-drawing pose; 3 METALGREYMON VACCINE original orange dinosaur classic form, blue stripes, metal skull helmet, enormous cyborg METAL LEFT ARM claws, chest missile ports, tattered PURPLE wings, long tail, NOT blue virus not 2010 design; 4 KYUBIMON golden yellow FOUR-LEGGED FOX with exactly NINE fluffy golden tails fanned behind, mystical BLUE FLAMES on tail tips and paws, red-white sacred rope collar and forehead markings, no humanoid body. Full subjects inside own cells safe margins, exact IP identity and shape.
```

## DIG-040～045

输出`sources/digimon-040-045.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY SIX authentic Digimon Mega full-body illustrations, strict equal 3 columns 2 rows grid, high res square. Faithful classic official anime cel shade art, detailed armor. Navy blue cyan digital space background, no text labels frames UI. Each full subject with safe margins inside own cell. Reading order 1 WARGREYMON gold orange humanoid dragon warrior with silver Dramon Killer huge three-claw gauntlets, gold helmet red hair plume, round two-piece Brave Shield on back with courage crest; 2 METALGARURUMON silver blue mechanical quadruped wolf with metal muzzle, yellow wing blades, icy blue armor and missile ports, flying; 3 SERAPHIMON silver blue armored angel, gold faceless visor and TEN huge white feather wings, blue gold accents, full body hovering; 4 MAGNADRAMON/HOLYDRAMON long pink furry serpentine holy dragon with long ears, short clawed paws and ten feathery pink wings, curling through sky, not humanoid; 5 GALLANTMON/DUKEMON silver white armored knight with red horned dragon helmet, red cape, long lance right hand and huge circular white gold red shield left arm, classic form; 6 BEELZEMON/BEELZEBUMON classic dark leather biker demon, three red eyes, white spiky hair, black leather suit, yellow feathered leg armor, holding twin pistols down at sides. Distinct exact classic Digimon character identities, polished collectible art.
```

## DIG-046～049

输出`sources/digimon-046-049.png`，真实1254×1254；`transparent_background=false`。

```text
EXACTLY FOUR authentic red rarity Digimon illustrations in strict 2x2 grid, square high resolution. Faithful recognizable official anime cel-shade armor art, heroic full-body with safe margins, dark navy digital-space background with luminous crimson gold cyan accents. No typography no text labels no frames. Reading order 1 OMNIMON OMEGAMON classic white armored knight and white flowing cape, shoulder blue gems, LEFT ARM orange WARGREYMON HEAD sword arm and RIGHT ARM blue METALGARURUMON HEAD cannon arm, one horned white helmet. 2 ALPHAMON regular form: BLACK armored knight with intricate GOLD trims, green chest gem and white cape, gold angular horned helmet and winged shoulder plates, NOT Ouryuken form, upright poised. 3 IMPERIALDRAMON PALADIN MODE: entirely SILVER WHITE armored dragon knight with huge WHITE FEATHER WINGS, royal blue details, long dragon helmet horns, BOTH HANDS holding enormous long white silver OMEGA SWORD in front, NOT black fighter mode not dragon form. 4 OMNIMON X ANTIBODY/OMEGAMON X: angular sharp WHITE armor with GOLD accents, red blue jewel details, dramatically sharpened Greymon sword head LEFT ARM and Garurumon cannon head RIGHT ARM, long RED inside/white outside cape, blade thrust diagonally into foreground, visually clearly different sharper X design from classic first cell. Exact specific IP forms, elaborate armor, whole subjects contained own cells.
```

## 通用卡框 grade_0（白）

输出`sources/frame-grade-0.png`，真实1086×1448；`transparent_background=true`。正式导出`frames/grade_0.png`为768×1024。

```text
Single final production game collectible CARD FRAME asset, portrait 3:4, 768x1024 or 1024x1365 native resolution. NO TEXT NO LETTERS NO NUMERALS NO ILLUSTRATION. Transparent background and a large genuinely TRANSPARENT rectangular illustration opening. Layout fixed: outer rounded rectangular card fills almost canvas with 9px margins on 768 width; top narrow CREAM PAPER label strip from y25 to80; huge transparent illustration WINDOW x36 y86 width696 height674; bottom warm CREAM PAPER text panel from y774 to998, entirely blank for title and description, no lines. White/common rarity: warm ivory heavy layered paper card, delicately embossed bevel border and fine silver-white foil edge, understated luxurious collectible aesthetic, visible tactile paper grain and inset shadows, few restrained abstract corner flourishes, wide elegant intact border. Transparent ONLY outside rounded card and entire big illustration window; cream top and bottom remain OPAQUE. Orthographic front view, no perspective no cast shadow. Important window is empty clear alpha hole, not white fill not gray not checkerboard.
```

## 通用卡框 grade_1（绿）

输出`sources/frame-grade-1.png`，真实1086×1448；`transparent_background=true`。正式导出768×1024。

```text
Single game card FRAME asset ONLY, full portrait 3:4 1024x1365, FRONT ORTHOGRAPHIC. NO TEXT LETTERS NUMBERS LOGOS ARTWORK. REAL TRANSPARENT BACKGROUND outside card and in large EMPTY transparent illustration window. Entire silhouette occupies canvas with tiny margin. Rare GREEN grade: heavy warm CREAM IVORY tactile layered paper card face with luxurious EMERALD GREEN thin foil double bevel border, embossed botanical-neutral abstract corner curls and delicate gold inlay. Large rectangular transparent illustration hole from 4.7% to95.3% width, 8.4% to74.2% height. Top narrow cream paper label band from 2.4% to7.8% height. Bottom large blank CREAM paper title/description panel from75.6% to97.5% height, no lines. Emerald foil is distinctly green trim around opaque cream paper, not entire green face. Beautiful dimensional layered paper bevels and restrained embossed abstract ornament, compatible both space and anime character cards. No stars dominating. Keep window empty alpha, not white not black fill not checkerboard. No cast shadow.
```

## 通用卡框 grade_2（紫，最终采用的第二次）

输出`sources/frame-grade-2.png`，真实1086×1448；`transparent_background=true`。正式导出768×1024。

```text
REPLACEMENT production card FRAME, portrait 3:4, authentic TRANSPARENT cut-out center. Purple EPIC grade, violet outer layered paper rim, intricately embossed SILVER thin filigree and amethyst corner diamonds. Warm CREAM solid top narrow label and solid broad bottom text panel, no text. This is an EMPTY FRAME: the entire rectangular central area must be fully transparent, no paper, no haze, no mist no gradient, no white fog, no glowing vignette. Precise opening from x5% to95% and y9% to74%. Top cream strip y2%-8%, bottom cream panel y76%-98%. Only ornate outer frame and these two cream strips exist. No artwork no logos letters numbers or symbols. Front orthographic, full card visible, crisp premium bevel detail. Native alpha background outside and inside window.
```

## 通用卡框 grade_3（金）

输出`sources/frame-grade-3.png`，真实1086×1448；`transparent_background=true`。正式导出768×1024。

```text
Single finished collectible CARD FRAME production asset, portrait 3:4 high resolution. No illustration no words no text numbers letters logos. Genuine transparent background outside rounded card and LARGE EMPTY FULLY TRANSPARENT rectangular artwork WINDOW (no haze, no white fog, no gradients within opening). Legendary GOLD rarity: exquisite thick raised embossed gold foil sculpted frame with refined abstract star diamonds and ornate curling filigree, tactile warm cream ivory paper. Entire card seen orthographic from front. Narrow blank CREAM title strip at top 2%-8% height. Large completely open clear alpha window x4.7%-95.3% width, y8.4%-74.2% height. Wide blank opaque CREAM paper title and description area bottom y75.6%-97.5% height. Gold ornaments stay on border outside window and leave text fields blank. Strong golden rare collector look, premium layered papercraft with embossed metallic bevels, compatible any character or galaxy theme. No picture in the window. Transparent center must be entirely clear alpha, no soft white glow. Flat asset no cast shadow.
```

## 通用卡框 grade_4（红）

输出`sources/frame-grade-4.png`，真实1086×1448；`transparent_background=true`。正式导出768×1024。

```text
Single final production collectible card FRAME ONLY, portrait 3:4. Front orthographic high resolution. NO text words letters numerals logos illustration. RED ultimate rarity. Deep ruby red lacquer foil raised wide borders, lavish metallic GOLD embossed filigree and tiny ruby gemstones at corners, warm CREAM IVORY tactile paper narrow top label and broad bottom description plaque. Big clear empty genuine TRANSPARENT alpha rectangular illustration opening x4.7%-95.3% width, y8.4%-74.2% height; absolutely NO fog haze white vignette within window. Opaque CREAM top text strip y2.4%-7.8%, bottom opaque CREAM paper plaque y75.6%-97.5%, blank for future title and paragraph. Elaborate luxury sculpted paper layers and ornate gold bevels, generic abstract swirling diamonds compatible celestial and digital monster collections. Visible RED rarity identity around frame but text plaque always light cream. Keep all edges within canvas; transparent only window and outside rounded card. No cast shadow.
```

## 五色卡背（最终采用的第二次）

输出`sources/backs-atlas.png`，真实1774×887；`transparent_background=true`。提取正式背面各288×384。

```text
Transparent isolated game asset sheet. Exactly FIVE upright card backs in one horizontal row, same full rounded rectangle 3:4 shape, equal spacing, fully inside canvas. Reading order silver white, green, purple, gold, red. Closed opaque foil card backs with intricate gold embossed ornamental rim and large original purple gold spiral medallion centered, symmetrical fine foil engraving. NO text no labels no windows no panels. Native REAL TRANSPARENT BACKGROUND everywhere between cards and outside cards. Absolutely no white background, NO fog NO mist NO smoky vignette, NO drop shadows, NO glow around cards, NO white gradient. Only the five sharply edged self-contained cards exist on alpha. Front orthographic view, premium tactile paper foil, rich five rarity colors. Wide high resolution 2048x1024.
```

## 未采用尝试：紫框第一次

`transparent_background=true`。生成原图`C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c/exec-f4c92559-ddd5-41c2-8f42-d7071fbba398.png`，本次读取原文件核验1086×1448；白雾窗问题，未发布。

```text
Single production reusable collectible CARD FRAME only, vertical 3:4. Full high resolution orthographic frontal view, no perspective no text no labels numbers letters logos characters or illustration. REAL alpha transparent big rectangular center window and outside rounded card. EPIC PURPLE rarity. Premium tactile warm CREAM IVORY paper blank top label strip and large blank bottom title-description panel, lavish layered violet amethyst paper edges and SILVER embossed foil filigree, abstract elegant geometric curling ornaments at corners, distinctly purple outer rim. Fixed geometry: illustration empty alpha window spans x4.7% to95.3%, y8.4% to74.2%. Narrow cream top strip y2.4%-7.8%. Broad opaque CREAM bottom panel y75.6%-97.5%, kept empty for later type. Intricate sculpted layered paper depth, pearl silver engraved bevel, embossed metallic highlights. Universal card frame compatible celestial and anime monster themes, no dominant stars no franchise symbols. Empty transparent window not black fill not gray checkerboard. Keep all frame edges inside canvas.
```

## 未采用尝试：卡背第一次

`transparent_background=true`。生成原图`C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c/exec-de28cdc7-bcc6-457c-9fc6-ea5ba691a9ed.png`，本次读取原文件核验1774×887；雾底问题，未发布。

```text
Production asset atlas exactly FIVE complete collectible CARD BACKS in a SINGLE HORIZONTAL ROW, equally spaced in five invisible equal cells, wide 2048x1024. All five same upright 3:4 rounded rectangle card silhouette, fully visible not cropped, generous transparent gutters and outside real alpha. Full CLOSED back surfaces, NO windows, NO title panels, NO bottom text box, NO text letters numbers logos. Rarity reading order WHITE SILVER, EMERALD GREEN, AMETHYST PURPLE, YELLOW GOLD, RUBY RED. Each premium embossed paper and holographic foil collectible back, ornate symmetrical metallic fine border, centered ORIGINAL abstract golden purple spiral swirl medallion, subtle geometric diamond and star filigree covering entire closed back. Consistent luxury tactile paper game aesthetics, rich obvious five grade colors, gleaming gold raised line engraving. Flat orthographic front-facing backs, no perspective no stacked cards. No packaging crimps, these are rigid card backs with softly rounded corners. Exactly five, keep entire edges inside image. Transparent alpha background.
```
