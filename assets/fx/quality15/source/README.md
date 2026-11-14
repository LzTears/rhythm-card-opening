# 重击双通道制作源

当前Catalog入口为`scripts/world_quality_catalog.gd`及`world_quality_pairs.gd`。本目录提供E01重击、路径、波与接触的color/light素材，具体可用key、帧数、FPS、pivot、源/输出SHA及选择参数见上层manifest和同名JSON。Catalog只呈现已提交事件，不改目标、伤害或逻辑时刻。

从项目根目录运行`node assets/fx/quality15/source/export.mjs`可再生导出；`verify-sources.mjs`用于源与输出的一致性检查。执行前核对脚本写入位置及其本机pixelfx依赖，避免无意覆盖正式素材。保留当前源文本、source-integrity.json、final-sha.json及各源许可/署名记录。

主爆使用真实爆心，路径按真实from/to定位；wave来自原库shock-ring分轨，contact保留完整短接触反馈。color为透明正文、light为加色光，禁止先烘焙合并。JSON中的源时长、末端采样与N/FPS显示寿命分别保留，纹理不能反向改变玩法事件。

当前集成检查入口见项目verification/current及docs/PRD.md。制作检查只能证明其实际检查对象，不表示主观美术、真实GL或FPS通过；不存在对历史比较图或已撤下单次验收报告的依赖。
