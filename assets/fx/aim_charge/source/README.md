# 蓄力头部火花资产

单颗小型中性灰白亮芯，朝右、细尾向左；最多两枚低亮碎点，无整圈/文字/烟尘/攻击几何。World按真实蓄力progress定位/转向，建议2–3颗错相稀疏采样，不以该动画代替真实读条，也不扩大50/80攻击半径。

接口：charge_sparks.png为192×192 RGBA、4×4格、每格48×48、16帧、30FPS、中心pivot(24,24)，含首末透明端帧；源0.5秒，16帧展示时长0.533333秒。最终内容边界x15..30/y19..28，边缘有充分透明留白。Linear/no repeat/no mipmap、UV夹在各格内；host按元素tone染色。源保color/light独立buffer，正式单RGBA用标准透明composite，与World owner约定不增加必要pass。

参考pixelfx的ui/countdown（弧头火花）、pickups/key-glint（小亮芯）、arcane/spell-charge（剔除过大能量球）。出处与源SHA见provenance.json，LICENSE.txt保MIT署名。

复建：在已安装pixelfx目录运行 `node <本source绝对路径>/export.mjs --round=3 --formal`；PIXELFX_ROOT可指定库。当前集成检查见项目verification/current及docs/PRD.md；Node离线检查不等于正式GL、主观美术或FPS通过。
