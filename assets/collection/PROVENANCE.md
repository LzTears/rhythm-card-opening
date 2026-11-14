# 收藏正式素材来源与制作记录

完整实际生图提示词现见`prompts.md`，含每个atlas、五框、卡背及未采用两次尝试的逐字原串与真实尺寸。下文“生图提示规格记录”仍明确为摘要，不替代完整记录。

制作日期：2026-11-12～13。所有实际绘画由本次内置 `image_gen` 产生，未切换收费 API 后端。代码只负责裁切、重采样、sprite-gen 提取与核验，没有代码绘画替代插画。

## 文件与分辨率

- `backs/digimon_back_0.png`～`digimon_back_4.png`：2026-11-13追加数码主题独立五色卡背，内置image_gen真实生成`sources/digimon-backs-atlas.png`（1983×793），数码电路＋像素斑点数码蛋徽记，无字、无星系旋纹；白银、绿、紫、金、红依序增加金属浮雕装饰。sprite-gen原生`slice-sheet --grid 5x1 --chroma-key none --alpha-floor 64 --cell-width 288 --cell-height 384 --baseline-y 379 --target-height 374 --scale sheet --fit contain`导出，各288×384 RGBA。五图均`clipped_px=0`、alpha0～255、封闭中央alpha252～253；已视检整张atlas及导出白/红两张，正视完整，无邻格残片。来源、尺寸、bbox、独立哈希见`backs/digimon-backs-manifest.json`，alpha与提取报告为`backs/digimon_back_alpha-cleanup.json`和`backs/digimon_back_slice-sheet.json`。完整实际提示词见`prompts.md`数码独立卡背段。

- `cards/GAL-001.png`～`GAL-049.png`：49幅独立星系画面；`galaxy-manifest.json`逐幅记录真实原图尺寸、导出尺寸与裁切框。
- `cards/DIG-001.png`～`DIG-049.png`：49幅对应固定角色/形态的独立 AI 绘画；`digimon-manifest.json`记录身份、图鉴参考链接、来源与尺寸。
- `frames/grade_0.png`～`grade_4.png`：五幅独立生成1086×1448；导出768×1024 RGBA。`build_frames.py`以九宫格重采样适配统一插画窗；使用sprite-gen现有`clear_haze`清除alpha雾，报告在`frames/*alpha-cleanup.json`。
- `backs/back_0.png`～`back_4.png`：五色封闭卡背288×384 RGBA，从`sources/backs-atlas.png`用sprite-gen原生slice-sheet提取；完整提取报告同目录。

原图均保存在`sources/`。插画不是768×1024整卡，不能把代码模板尺寸当作每幅插画的原生尺寸。插画为扁平绘画，未冒称真实分离的主体、背景、前景图层；边框、文字、Holo由代码另外合成。

## 数码宝贝署名与实际来源

角色身份参考项目`docs/concepts/catalogs-v1/digimon-49.md`及官方Digimon Encyclopedia。角色版权属于原权利人：© Akiyoshi Hongo / Toei Animation / BANDAI。此批是AI生成的角色演绎，不是官方原图，不声称原创角色或已获商业授权。

本机urllib、带Mozilla请求头的urllib及curl下载官方`https://digimon.net/cimages/digimon/koromon.jpg`均HTTP403。网页浏览工具能读取官方图鉴及确认该JPG链接，但未获得可落盘原始图片；因此按已授权备用路径使用内置生图。特别在提示词明确经典`greymon-first`、橙色疫苗种`metalgreymon-v`、Paladin Mode、Omegamon X，未改用2010同名角色或通用怪兽。

AI绘画能保留角色的大轮廓、配色与指定形态，细小装饰、翅膀数量及幼年角色的局部比例仍有演绎，并非逐笔还原官方设定。需要严格官方设定一致时，应使用未来能够取得并获授权的原图替换相应固定ID，不改收藏身份。

## 视觉核验

2026-11-13追加修复`DIG-033`、`DIG-036`、`DIG-041`三张原图边缘截断。逐张先读取原图，再使用内置image_gen的`referenced_image_paths`真实编辑：保留现有角色造型/色彩/赛璐璐风格/数字背景，补齐完整翼尖并缩小主体构图，未用Python补画。三张正式图同ID替换，原生各1086×1448竖版；备份旧图与旧manifest在`archive/edge-repair-v1/`。DIG-033首稿虽已补全翼尖但左侧留白未达10%，又用imagegen编辑缩小一次，最终安全边达标。现图主体四周可见安全边均≥10%，翼/角/手/脚完整入画；`sources/edge-repair-manifest.json`保留人工目测主体边界估计、尺寸、路径与哈希（不是alpha分割测量）。正式逐卡manifest已更新三条来源和尺寸；完整四次prompt/引用图路径见`prompts.md`修复段。

核对98文件、98独立SHA256，无缺号或重名复用。已看每张生成atlas并查看98张`qa-contact-sheet.jpg`。修正生成器不等高分格：GAL030～035行界600px，GAL046～049行界590px，DIG036～039行界605px，DIG040～045行界585px，DIG046～049行界598px；每格向内2～3px除分隔线。GAL046已单独查看，底部相邻青蓝格残片已消除。

5框中心alpha=0，顶部与底部奶油面板存在。紫框初次生成带白雾窗，已重生成并使用清晰原生alpha版本；卡背初次雾底也已重生成。失败尝试没有发布为正式资源。

## 生图提示规格记录（摘要，非逐字转录）

共同限定：production illustration atlas；严格指定列×行、阅读顺序、每格独立完整主体；no text/labels/frames/UI；真实绘画；深紫纸艺星系或深蓝青色数字空间；禁止同图改名重复。

星系按001～008、009～016、017～022、023～029、030～035、036～039、040～045、046～049八批生成。逐格主体与次序严格按卡表；主要英文描述包括Moon/Mercury/Venus/Mars/Ceres/Pluto/Phobos/Deimos，Io/Callisto/Charon/Triton/Ursa Minor/Cassiopeia/Lyra/Cygnus，Earth/Jupiter/Saturn/Uranus/Neptune/Europa，Ganymede/Titan/Sun/Ursa Major/Scorpius/Leo/Taurus，Orion/M31/M33/M51/M104/M45，M42/M8/M57/M1，Milky Way/M13/M27/M20/M64/M82，black hole/supernova/pulsar/Pillars of Creation。使用tactile layered cut paper、dimensional shadows、restrained luminous rims，所有文本留给代码。

数码同样八批001～008、009～016、017～022、023～029、030～035、036～039、040～045、046～049，逐格角色顺序见manifest。每幅提示明确英文IP名＋标志性配色、体态、头饰、武器、翼/尾/手部；要求faithful classic official anime cel-shaded character style，而不声称生成品是官方原画。

通用框五次独立生成white/emerald/amethyst/gold/ruby，要求portrait3:4、opaque cream top and bottom text panels、transparent illustration opening、embossed layered paper foil、no typography；紫框重生成一次。卡背一张五横排，white/green/purple/gold/red，closed full back、original purple-gold spiral medallion、ornate foil，第二次去掉雾底后采用。

## 2026-11-14 卡图导入与红卡运行依赖

用户已采用非红卡135张同尺寸Q90导入、红卡12张保持无损。147张源PNG不重绘、不缩图；字体、卡框和红卡材质不变。具体成包体积与验收见PRD第50节。

GAL-046黑洞与DIG-046奥米加兽实际使用两张既有批准参考图的指定区域。为避免docs导出排除造成缺图，逐字节复制至`reference_art/01-black-hole-red-holo.png`及`reference_art/02-omegamon-red-holo.png`，正式CardView改引用此处，原docs图继续保留；两张新运行资源为原尺寸1086×1448、无损导入，裁切和Holo参数不变。

源图分别来自`docs/concepts/red-holo-v3/01-black-hole-red-holo.png`及`02-omegamon-red-holo.png`；复制内容SHA-256分别为`89ee281b80872f45ecc2b71e2f30501e303da9e4610fe69fc60b156228baac89`、`1d98c76c55bc0acf5904b8fb936c0c5cbf07fecf36801f4d1a1494019ddf4323`。本次未新增生成或取得角色授权，来源边界沿用此前记录。
