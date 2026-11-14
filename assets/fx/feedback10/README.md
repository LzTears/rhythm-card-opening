# Feedback10共享像素特效

来源为[patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)，MIT，包含Hugo Duprez署名的wind-band技术。许可见LICENSE.txt，原源见source/original，项目适配见source/adapted与source/export-feedback10.mjs。保留源、署名和provenance，图片并非以远程成品替代源码。

本目录是WorldFxAtlas动态回退链的一部分。运行时按每份JSON的图像引用、帧/FPS、pivot及寿命加载，不以旧批次总图数推断当前可达资源。图集不拥有目标选择、事件、随机、伤害或攻击范围。

复建入口：`node assets/fx/feedback10/source/export-feedback10.mjs 5`。来源检查入口：`node assets/fx/feedback10/source/verify-feedback10.mjs`。执行前核对pixelfx依赖和脚本输出位置，避免覆盖现有正式资产。当前集成检查见项目verification/current及docs/PRD.md，来源检查不表示GL、主观美术或性能通过。
