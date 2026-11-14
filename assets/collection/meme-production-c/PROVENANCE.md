# 非主流媒体 C 组来源与生成记录

2026-11-13。用户整体批准的 v2 夸张动作风格；18 个最终资产由内置 `image_gen.imagegen` 分别调用真实生成。13 插画＋5 卡背，另有 MEM-042 构图纠正与 MEM-049 方形纠正，共 20 次调用。没有 CLI/API 替换、程序绘图或调色代替生成；没有启动 Godot。

完整原始提示、编辑参考与生成原路径在 `manifest.json`，逐张提示副本在 `prompts/`，最终原始源图在 `sources/`。正式插画在 `../cards/`，卡背在 `../backs/`。本次只复制图片，没有程序修改像素。弃用版本仍保留在生成原路径，并在 manifest 的 rejected 中记录。

题材依据：`docs/concepts/non-mainstream-v2/catalog-draft.md` 与 `sources.md`。这些来源仅证明题材和可辨识外观，不代表商业授权。

- MEM019：SteamHappy 搜索图显示大白眼、两门牙、红舌；参考页面 https://www.reddit.com/r/Steam/comments/k8n1sr/new_steamhappy_emoticon_png_super_hd_version/ 。Imgur 原图下载因目标拒绝连接失败，未伪称本地读取。
- MEM020/021：只读 A 组 `references/media-contact.jpg` 和 `media-index.json`，真实 Doge/Cheems/Swole Doge 外观；参考原报道和来源详见 S07/S14。Bonk 构图为本项目轻敲软棒演绎。
- MEM022：已下载并 view 检查 `references/drog.jpg`，URL https://images.gamebanana.com/img/ss/mods/69ed990552da8.jpg ，页面 https://gamebanana.com/mods/672472 。只作刀盾狗比例参考，没有复制进入最终图片。
- MEM023：图搜参考 https://x.com/crhmnic/status/2090036162501185616 ，黄袋鼠、圆肚、棕鼻、长耳；以 S16 已批准题材为准，新场景无品牌。
- MEM024：OIIA/Ethel 图搜与 S17 外观线索，页面 https://es-us.noticias.yahoo.com/spinning-cat-origen-meme-gato-054315585.html 。本项目全身旋转残影演绎。
- MEM042..045：S25 具名 AI 脑腐题材，复用 B 组只读 `forward-prompts.json` 中提示。图搜外观交叉：Lirili 的象头、仙人掌身、凉鞋；Patapim 的长鼻猴、树身、大脚，未采用网页扩写战斗神兽叙事。 https://commons.wikimedia.org/wiki/File:Brr_brr_patapim.jpg 与 https://music.apple.com/mx/album/liril%C3%AC-laril%C3%A0-single/1811674553 。
- MEM047：view 后引用本项目已认可 `art/maodie.png` 编辑，保持同猫；改为空中飞扑、双前爪、三个早时刻后影，非换背景。
- MEM048：view 后引用本项目已认可 `art/naiwa.png` 编辑，七只黄身浅肚绿眼奶蛙不同表情长桌，非同姿复制。
- MEM049：经典滑稽黄脸，夸张上扬嘴角、两眼同向；第二次内置编辑仅纠正方形画布。Holo 留引擎叠加。
- 五卡背：先 view 旧 `back_0.png` 和 `digimon_back_4.png` 品质体系；独立生成全新歪眼笑脸＋破像素贴纸主题。白背作为后四背一致性编辑参考，后四背分别真实生成，不是调色。全部请求实际透明外缘。

## 目检与限制

全部 20 次工具输出都已观察；18 张最终资产均无字幕、品牌、水印或卡面框。插画不含 Holo。044/045 的安全边比要求紧但身体各部分完整；048 最右抬手接近边缘，长桌构图整体可读。五卡背完整边框且区别于旋纹/电路蛋；白绿紫金红主色与雕刻复杂度递进。

数值检查 `qa-metadata.json`：五背均 1086×1448、RGBA、alpha 范围 0..255，精确 3:4。生成透明外缘存在零星孤立 alpha 碎点触及画布边；源图完整保留，由主线程按统一透明清理流程处理后再验收实际游戏呈现。卡背未烘焙 Holo。

未替代 root 的正式卡框接入、GPU/引擎检视或最终 UI 验收。

## 追加委派 MEM017/018

Root 明确将 A 组尚未调用的 MEM017/018 交给 C 组，A 最终负责001..016。新增2次独立内置imagegen调用，两图均1254×1254 RGB，无字幕。完整提示、源与参考在 `appendix-manifest.json`，逐张提示和源图已写入对应目录。017先view正式001/002，引用001编辑为同猫侧身弓背、双耳压平、闭嘴蓄势；018先view003/004并引用为身份和粗图风格，编辑为双掌拍桌、桌面弹起、前扑表情。两张均查看工具最终图并接受；无引擎操作。

## 追加委派 MEM013/014

Root 后续明确交出 A 组尚未调用的013/014。各进行1次独立内置imagegen调用，并目检接受。013先view A组 cats-12/13 实际苹果猫参考，再生成完整红苹果身体、粗拼贴猫脸、细腿迈步；014先view A组 vibe-reference.jpg，再身份参考编辑为半闭眼白猫歪头与左右残影，保留压缩照片质感。两图无字无框，无引擎操作。完整提示、源、参考、尺寸与SHA256见 `appendix-013-014-manifest.json`，逐张提示与源图写入对应目录。
