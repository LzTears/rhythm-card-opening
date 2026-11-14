# MEM-001～012：完整实际提示词

2026-11-13。最终分工001～012；013以后的生成交由其他媒体代理。001复用用户已确认v2图；002～012共11幅独立插画，每张1次内置`image_gen.imagegen`调用，均`transparent_background=false`，每次`referenced_image_paths`只有下列一个已查看的本地参考；未传`num_last_images_to_include`。实际输出均1254×1254 RGB PNG，原样复制，没有程序绘图、atlas或同图改名。prompt中的要求是生成约束，不意味着模型百分百遵循，边距实际检查见QA.md。

引用路径下列为项目相对路径，实际工具传入绝对前缀`C:/Users/Administrator/Desktop/代号1/圆卡旋风/`。

## MEM-001（复用）

未新增调用。直接复制`docs/concepts/non-mainstream-v2/art/maodie.png`，原调用完整prompt见[已确认v2记录](../../../docs/concepts/non-mainstream-v2/prompts.md)，来源与视检见该目录PROVENANCE。与原图哈希一致是有意复用经确认代表图，不是拿一张图冒充多个新卡。

## MEM-002

referenced_image_paths: `docs/concepts/non-mainstream-v2/art/maodie.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Square standalone collectible illustration, no text, no caption no watermark no card frame. Use attached confirmed round-headed orange tabby meme cat identity as reference: orange fur, very round face, flattened airplane ears, pale chin, narrowed silly furious eyes. NEW DISTINCT SCENE: this same cat has been caught secretly eating from a small metal kibble bowl on the floor beside a half-open kitchen door; squat body faces bowl while enormous round HEAD twists back over shoulder toward camera, lips curled showing little fangs, one guilty kibble crumb near mouth. Hilariously shameless angry expression, not a cute normal kitten. Real cheap phone PHOTO look, mild fisheye wide angle, crunchy compression, tiny motion blur on turning head, low-budget meme screenshot texture. Show entire cat including every visible paw, tail, both ears and bowl; all fit within central84 percent of square with8 percent clear background margins. Keep character orange not another cat, no costume no fantasy. Scene composition must be different from source paw-slapping close-up: side-back full body caught at bowl, dramatic over-shoulder glare. No people, no readable screen or labels. Background subdued indoor floor.
```

## MEM-003

referenced_image_paths: `assets/collection/meme-production-a/references/pandas-08.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Square single Chinese internet PANDA HEAD reaction-meme illustration. Use reference image's classic black-white round panda ears and flat black little body with PHOTOCOPIED HUMAN MEME FACE, not a real animal. New scene: sly eyes squinted to tiny slits and eyebrows crooked, BOTH BLACK HANDS cover the huge smirking mouth badly as if desperately suppressing laughter while eavesdropping; shoulders shake and body bends to one side. Unhinged smug group-chat energy, silly rough black-white low-resolution Photoshop collage, visibly mismatched pasted human face with crunchy halftone edges. Keep big head, complete ears, both hands and small whole body fully inside square with8 percent margin. Pale off-white background with faint gray motion jitters only. NO TEXT, NO captions, no question marks, no symbols pretending to be words, no watermark, no website logo, no card border. Do not copy the reference caption or watermark. Not anime, not cute plush, not glossy3D, not natural panda. Preserve recognizable Chinese biaoqing panda meme visual language.
```

## MEM-004

referenced_image_paths: `assets/collection/meme-production-a/references/pandas-02.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Single SQUARE Chinese biaoqing PANDA HEAD meme illustration. Reference is the classic black-and-white panda silhouette pasted with a grayscale HUMAN reaction face. New distinct scene: enormous round head and two complete black ears leaning slightly forward, tiny black body standing motionless with BOTH hands folded behind back, eyes dead-straight locked on viewer, mouth compressed into a thin knowing almost-smile, one eyebrow subtly raised. Extremely awkward silent judgment, funny intimidating stillness, not a cute natural panda. Preserve crude high-contrast Photoshop photocopy face texture and jagged low-res pasted edges, flat solid black limbs, white head area. Bare muted off-white background and a tiny gray oval floor shadow, no detailed scenery. Whole ears, head, hands/back contour and feet fully inside central80% of canvas,10% margins, unlike the hand-covering laugh version this is perfectly motionless judgment. NO TEXT NO symbols NO question marks NO watermark NO website logo NO card frame. Do not copy reference question marks or text. Not anime, not3D or fluffy plush.
```

## MEM-005

referenced_image_paths: `assets/collection/meme-production-a/references/sweat-emoji.jpg`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Single SQUARE Chinese reaction meme 流汗黄豆, use attached actual sweat-yellow-face emoji as visual reference for classic YELLOW ROUND FACE, brown facial features and enormous blue sweat droplet. A much more painfully awkward funny version: rigid forced wide grin with rectangular white teeth, one eyebrow slightly twitching, eyes half smiling but clearly dying inside, giant glossy BLUE SWEAT BEAD slipping down right temple, a second tiny wobble echo of the same droplet, no extra eyes. Keep simple original cheap digital emoji shading and slight pixelated/compressed edges, NOT a human head, NOT a photoreal bean, NOT anime or cute mascot body. Entire big round face floats tilted7degrees above a pale cream background with a tiny gray oval shadow, small jagged jitter marks outside imply nervous trembling. Full face and blue droplet completely within central78% of square,11% margin, no clipping. The enormous nervous grin and sweat are immediately recognizable at thumbnail size. No arms or legs needed. NO letters, NO captions, NO numbers, NO watermark, NO frame, no software UI. Do not put its name in image.
```

## MEM-006

referenced_image_paths: `assets/collection/meme-production-a/references/broken-02.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Square single reaction emoji collectible illustration for Chinese WeChat 裂开 / Broken yellow face. Reference image contains SIX small yellow emojis in a row; use ONLY THE RIGHTMOST sixth face, the iconic vertically CRACKED yellow face, not any other expressions and do not reproduce the row, interface or writing. Make one huge round yellow face with wide brown round eyes, tiny shocked oval mouth, a clean jagged zigzag CRACK splitting it from top to bottom, the two yellow halves slide slightly apart and one half sags lower so a cool pale blue gap is visible. The face is trying to stay composed but is literally falling apart, darkly funny cheap digital emoji shading with slight pixel/compression texture. No blood or skin gore, just cartoon yellow symbol. A few little yellow geometric fragments fall into empty space while both main halves remain whole and readable. All face pieces within central80% square,10% safety margins. Quiet pale cream-gray background, no text, no captions, no watermarks, no labels, no frame, no realistic bean, no anime. Only one split yellow face.
```

## MEM-007

referenced_image_paths: `assets/collection/meme-production-a/references/dogs-05.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
SQUARE standalone collectible image of the specific DOGE meme dog Kabosu from attached reference, not a generic Shiba Inu and not Cheems. Preserve iconic orange-tan fur, cream muzzle, black shiny nose, upright triangular ears, rounded face and unmistakable SIDELONG SKEPTICAL EYES looking at viewer while head stays tilted away, slight tight-lipped awkward amused mouth. Real photographic meme texture, mild JPEG crunch and inexpensive indoor light, NOT anime or3D cartoon. New full-body composition: dog perched sideways against an old beige sofa cushion, front paws crossed awkwardly, stocky body and curled tail visible, its side eye feels comically intense as though it heard a ridiculous group-chat comment. Slight low-angle wide camera makes face large but full head, both ears, paws and tail remain at least8 percent clear of every square edge. Simple faded room background, tiny hint of crooked phone-camera tilt, no polished pet advertising. No text, no letters, no watermark, no logo, no card frame, no other animals. Preserve real Doge facial identity from reference.
```

## MEM-008

referenced_image_paths: `assets/collection/meme-production-a/references/dogs-07.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
SQUARE independent collectible image of actual CHEEMS meme Balltze from attached photograph, the weak little Shiba with drooping ears, small half-shut eyes, long downturned tired mouth, tan fur and cream belly. Preserve his real face and famously awkward slumped sitting pose. Do NOT make Doge's alert side-eye or upright pointed ears. Subject sits completely collapsed on a bare dull kitchen floor in a corner, rear legs splayed, front paws limp, shoulders uneven and back curved like the weight of an entire work week, one eye barely open with a tiny resigned crooked smile. Funny painfully defeated body language, not animal injury or misery documentary. Cheap cellphone PHOTO plus crude low-res meme cutout edges, slight wrong-scale floor shadow enhances absurd Photoshop feel. Complete whole dog including ears, paws and tail within central78% square,11% background safety margin, plain subdued gray-beige room. No text, no symbols, no labels, no watermark, no card frame, no other animals, not anime or plush3D. Delete any original social-media UI or writing from reference.
```

## MEM-009

referenced_image_paths: `assets/collection/meme-production-a/references/cats-08.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
SQUARE independent illustration of specific HAPPY CAT meme from attached real reference: the gray-brown and white small cat standing behind a glass door, front paws raised in an ecstatic bouncy HAPPY dance. Preserve its actual gray tabby markings and white chest, round eager face and awkward upright body, NOT a generic fluffy kitten. Transform into the most exuberant funny mid-bounce freeze-frame: hind paws briefly lifted, front paws alternately clapping against glass, one paw high one low, head bobbing with mouth slightly open, body tilted in an ungainly shimmy, low-resolution motion ghost of paws only. Cheap actual PHONE VIDEO screenshot texture with subtle reflection streaks on glass and beige doorway, lightly crunchy cutout edge, not polished anime or3D. Entire cat head ears, all paws and tail fully within central78% square with at least10% margins; include glass frame sides as contextual background but no bars covering face. No person, no second cat, no writing, no captions, no music notation, no watermark, no card border. Recognizable happyhappyhappy cat meme joy, not normal pet portrait.
```

## MEM-010

referenced_image_paths: `assets/collection/meme-production-a/references/cats-12.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
SQUARE single image of POPCAT meme Oatmeal, the specific gray tabby and white domestic short-haired cat whose mouth becomes an absurd perfectly tall BLACK O shape. Attached meme scene reference includes the recognizable white-gray cat at right; use this face identity, not other cats or objects, remove every text overlay and all other subjects. Big greenish-yellow round staring eyes, gray tabby cap on top and ears, WHITE cheeks chest muzzle, pink nose. The famous surreal mouth is one huge smooth dark O oval pasted over its lower face, hilariously too large, as if one impossible pop note froze in time; slight offset ghost of closed-mouth chin behind hints two-state animation without adding another full cat. Retain real low-res cat PHOTO texture with intentionally crude Photoshop mouth, not anime and not cute3D. Full sitting cat with ears, front paws, tail visible and mouth unobstructed, framed central76% square leaving12% safe margins all around. Plain old pale room wall and table edge low in background, mildly crunchy screenshot grain. No readable text, no subtitles, no watermark, no borders, no logos, no humans or multiple cats. This must look unmistakably like classic wide-mouth POPCAT, not natural meowing or hissing.
```

## MEM-011

referenced_image_paths: `assets/collection/meme-production-a/references/cats-10.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
Single SQUARE production collectible illustration of actual HUH CAT from reference photo: chunky WHITE domestic cat with dark gray patches across crown and ears, very round body, little pink nose, blank wide green-yellow eyes, slightly hanging open small mouth, vacant dumbfounded gaze. Preserve this exact recognizable meme cat identity, not Popcat's enormous O mouth and not a generic kitten. New exaggerated comic confused freeze frame: the full squat cat sits tilted slightly backward on an old rug, head cocked only a little and chin tucked as if its brain froze, eyes staring in two subtly different directions, small open mouth midway through a silly puzzled chirp. Real low-res PHONE VIDEO screenshot photograph with mild motion wobble ghost near head, crunchy edges, dull room lighting, not anime not3D. Entire cat ears, round body, forepaws, hindquarters and tail safely inside central78% square with11% margins. Keep the rug and blurred furniture leg background subdued. NO text, NO question marks, NO letters, NO watermark, NO frame, no humans, only one cat. Humor is its clueless face and ridiculous round posture, not horror or injury.
```

## MEM-012

referenced_image_paths: `assets/collection/meme-production-a/references/cats-12.png`；原生输出1254×1254，来源/最终路径见manifest.json。

```text
SQUARE standalone collectible illustration of the exact SAD BANANA CAT Chinese catmeme, not an ordinary cat holding a banana. Reference scene includes the yellow banana-costumed cat at left; use that famous meme concept only, remove all other cats/table/labels. One ridiculous TINY CAT FACE pasted in the opening of a huge peeled YELLOW BANANA-SHAPED BODY, three curved banana peel flaps surrounding head, tiny spindly cat legs and paws sticking from the bottom. Real cat PHOTO face with huge wet glassy eyes and exaggerated shiny TEAR STREAMS pouring down both cheeks, trembling small open mouth, pathetically devastated expression. Body is an intentionally crude fruit-photo/cat-photo Photoshop collage, slightly mismatched scales and crunchy low-resolution edges, NOT smooth3D, NOT anime, NOT polished mascot, not actual injury. Whole banana cat awkwardly tilts sideways as though sobbing too hard to stand, tiny paws splayed on a dull empty tiled floor, a tiny puddle of cartoon tears. One complete character entirely inside central76% square leaving12% background safety margin, banana tips, face, all legs fully visible. Background neutral gray-beige with slight old screenshot noise; face and absurd banana silhouette immediately readable at thumbnail. No text, no captions, no sounds written out, no letters, no watermarks, no logo, no frame.
```

