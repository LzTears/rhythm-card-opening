# 次级层级素材

2026-11-11：工程自制，使用本机 pixelfx 0.3.0 的画笔和分离双通道导出；参考库 `explosions/plasma-explosion` 与 `arcane/mana-burst` 的环形节奏，未裁切或改写旧主爆、余波、接触或路径素材。[pixelfx](https://github.com/patch-gg/pixelfx) 与 [Sprite Fusion VFX](https://www.spritefusion.com/pixel-art-vfx) 的 MIT 声明保存在 [LICENSE.txt](LICENSE.txt)（Copyright 2026 Patch、Hugo Duprez）；本工程新增环形编排同以 MIT 许可提供。

- `E01/E02/E05/ripple-*`：完整11帧／30 FPS，包含空白终帧，运行寿命11/30秒；用于多重分支或后续原生脉冲的短空心波，接触冲击沿用该元素原完整 contact 素材。
- `E01/E02/E05/echo-*`：完整19帧／30 FPS，包含空白终帧，运行寿命19/30秒；事件当帧的小十字亮点确认命中，前4/30秒收缩，随后外扩空心环。不预放、不延迟真实伤害。
- 每组均有独立 `color` 与 `light` PNG，pivot=(64,64)，128×128单帧；正文色块与加法光分离，运行保留 mix/add 和 P/P+1。
- 中心不铺光池。余波继续使用原有完整 `wave_*`，连锁、穿透、牵引继续使用原路径和接触素材。

制作输入为`source/secondary-rings.mjs`，`source/export.mjs`默认采用当前最终配置。`source/check.mjs`在临时副本中调用pixelfx原版检查工具，不修改共享库；执行前核对输出路径。保留当前源码、manifest、源SHA与许可。

本目录只提供表现资源，不定义目标、时刻、次数、范围或伤害。当前集成检查入口见项目verification/current及docs/PRD.md。

