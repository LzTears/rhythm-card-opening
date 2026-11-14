# 战斗 0.6 像素反馈来源

新增 `crit-hit.png/json`：pixelfx 0.3.0 `impacts/crit-hit`，原样导出，28 帧、30fps、216×136、5列6行。游戏按 .42 秒播放用于毁包短爆散；不覆盖原 `assets/fx/pixel` 资源。以 Node 运行本目录 `export.mjs` 可复现，环境变量 `PIXELFX_ROOT` 可指向源码快照。

pixelfx：https://github.com/patch-gg/pixelfx ，MIT；其源文件说明星形、关键帧和火花喷射改编自 Hugo Duprez / Sprite Fusion impact：https://www.spritefusion.com/pixel-art-vfx/impact ，MIT Copyright (c) 2026 Hugo Duprez。许可证沿用项目 `assets/fx/pixel/LICENSE.pixelfx.txt`；源文件保留于本目录 `source/`。

`scripts/pack_trail.gd` 是本项目原生轨迹粒子实现：有界48点历史、.62秒寿命、世界坐标碎光、暖金与薄荷调色、阶梯大小和透明度，暂停冻结，减少特效隐藏。先检索并渲染查看 pixelfx `projectiles/magic-missile`；借鉴“历史路径＋随年龄变细＋流动亮面”的做法，并非JS效果的逐像素移植。保留参考源文件，不生成角色。

早期原型先检索并渲染查看 pixelfx `pickups/loot-beam`，借鉴窄亮芯和上升光流制作短光柱。用户最新要求已覆盖该原型：最终world移除光柱与局部高阶亮相；高阶卡提示由main的顶部横幅承担，场中只有正常小卡飞行。保留参考源码和接触表用于来源追溯，不把原型当最终生效行为。

包装撕半、碎屑和逐包数字为本项目GDScript程序几何，包装仍取原五张PNG的原UV。包装破损从细裂痕到纤维露纸、边缘缺口，再到封边撕裂及局部剥层，三档都按真实剩余HP决定。最新要求不显示血条或耐久条。所有表现只读取事件，不抽规则随机、不发奖、不改坐标。

伤害和奖励改为独立 CanvasLayer(-5) 的全分辨率控件，不经过640像素世界。伤害36px、描边2，使用字体支持的ASCII减号；逐包奖励为40px金币/实际最高卡图标＋30px数量，.65秒收敛。`coin-icon.png` 是项目原生16×16像素图，`coin-icon.mjs` 可复现，使用pixelfx的MIT PNG编码器；不是替换旧素材。

正式美术额外来自本轮媒体代理调用内置imagegen：`assets/art/dispensers`（320×256，黑槽嘴中心160,228，80×64du）；`assets/art/pack_damage`（256×384全幅注册，取base alpha裁切）；`assets/art/reveal_frames`（512²金/红边框，最终供main顶部横幅复用，world不创建局部大框）；`assets/art/ui06/battle-table.png`（1600×960整图映射1000×600du，不平铺、不二次量化）。生成提示词、源图、处理和SHA以各资源目录的manifest为准。

2026-11-09 A2正式选择覆盖上述旧界面/包装资产绑定：当前world使用`assets/art/a2`下的新包、发卡器、桌面、三档damage与圆卡。原资产保留历史，不用其竖瘦crop硬拉。包面改相机朝向刚性quad，只有屏幕内旋转和1.06倍等比受击；动态tail仍为同一48点/.62秒配方，RGB改A2青绿#2f8b79/暖金#c88227，alpha/大小/寿命不改。A2实际source alpha尺寸、透明注册、技术归因和投影回归证据见`verification/a2-shape/QA.md`与各A2资源manifest。
