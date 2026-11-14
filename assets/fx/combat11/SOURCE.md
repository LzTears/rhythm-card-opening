# Combat11 实际图集与复建

本目录正式素材来自本机 pixelfx 0.3.0 / https://github.com/patch-gg/pixelfx ，MIT，Copyright (c) 2026 Patch、Hugo Duprez。完整许可见 LICENSE.txt；使用到的库源码、core、tools/lib 与源文件内上游署名保存在 source/vendor_snapshot。逐文件 SHA256 见 source/source-sha256.json。没有调用图片生成、下载外部位图或更改玩法脚本。

复建：在任意安装 Node 18+ 的机器执行 `node source/export.mjs 7`；核验执行 `node source/verify.mjs`。不需要 npm、浏览器、GPU 或 Godot。脚本内 source windows、palette、seed、坐标变换均固定。manifest 每个 key 的 source_id、source_time、source_sha256、options 对应确切 recipe；不是手工贴图或仅用于展示的参考图。

53 keys：pulse_E01..E08 / echo_E01..E08 / aftershock_E01..E08、chain_E01..E08 / penetration_E01..E08 / pull_E01..E08，加 contact / trail 和仅辅助兼容的 generic chain / penetration / pull。

所有 JSON 使用标准 meta.pixelfx：fps=30、frames、frameSize、pivot、columns=4，未裁切。帧 duration 为 33ms 供通用阅读，正式播放以 fps=30 为准。pulse 10帧/.333s、echo15帧/.5s、aftershock16帧/.533s、contact10帧/.333s、路径13帧/.433s。所有非循环最后一帧全透明。trail12帧/.4s，按原1.2s周期均匀采样循环，循环不加透明终帧。

普通元素图集192×144，pivot[96,72]。contact同尺寸同pivot；trail80×40，pivot[72,20]，向右运动时尾迹延伸左侧，源为青绿 arcane-beam 的中段，不含飞弹或人物。所有路径224×88，pivot[12,44]，右端约[212,44]，按真实 from→to 拉伸；最近邻采样。禁止用 generic 电弧覆盖八元素路径。

元素路径由不同的库轮廓衍生：E01冲击星/碎屑、E02电弧、E03火环/火息/火尾、E04冲击星/冲击浪/波环、E05雪晶/冰息/晶刺、E06毒液/毒云/毒泡、E07叶风/横向风卷/旋流、E08日芒/金束/金纹。chain 三个轮廓节点依次显现；penetration 拉成长路径；pull反向时间并向右汇聚。E02/E06/E08进行源硬编码颜色的最终色板归一，保留各自形状。A2木底使用深边、短亮芯、低辉光，毒云提高透明层密度。

verification/combat11/art 保留候选、round0..7导出查看记录、最终panel全览和 asset-verification.json。首次29素材完成三轮，新增24元素路径经过round3..7五轮；核验覆盖尺寸、53 keys、701帧、时长、末帧透明、路径端点、可见像素。只作素材层验证，不代表游戏接入或GPU性能验收。
