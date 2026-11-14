# 旧红卡参考框清理交付

2026-11-13。来源为docs/concepts/red-holo-v3/01-black-hole-red-holo.png与02-omegamon-red-holo.png。先实际view原参考，逐张独立内置imagegen编辑，保留原星系曲线星纹／数码角线电路红皮金浮雕。去掉全部中文文字，保留奶油纸牌匾、底纸、金线与饰物原有布局高度；画窗与外圆角外部是真alpha透明。没有改动原5框或代码，没有启动Godot/GPU。

正式输出frame_galaxy.png与frame_digimon.png为768×1024。sources/*-native.png为首轮1086×1448原生返回；sources/*-fix-native.png为一次针对性alpha修正返回。两轮均逐张view。首轮更接近原参考纹理，故选首轮；修正轮没有改善严格alpha，且纹理有轻微漂移，未选。prompts/保存所有真实完整请求。原始工具文件仍保留在Codex generated_images目录。

机械导出只使用sprite_gen.util.resample.resize_cell，不使用手工Pillow绘图、inpaint或重新设计框。export_verify.py可复现resize与只读alpha测量；使用sprite-gen独立venv运行。alpha-qa.json记录实际尺寸、hash与区域分布。

## 视觉与alpha结论

- 原参考红皮革、金色浮雕、星纹或电路方块、上下奶油牌匾与纸区布局保留；全字清除，插画移除。
- 3:4尺寸准确，源图与正式图均已view。
- 四外角alpha0，画窗内部没有烘焙黑白或棋盘格；显示工具以黑底展示透明。
- 严格alpha存在生成器限制：星系画窗内97.0144%像素为0，其余最大2/255；数码画窗内98.8540%为0，其余最大1/255。底纸alpha星系251..254、数码252..254；顶纸252..254或252..253。因此是实际有效透明但并非完全二值0/255，不能宣称严格mask通过。
- 边缘存在少量红色半透明碎边，原图完全逐像素同一不能保证，属于内置编辑近似保留结果。可供技术采样阈值mask解决近零／近满alpha，是否采用由主线程集成决定。
- 本轮恢复后持久store未继承，初始暂存误落到父目录assets/collection/red-reference-alignment；已完整复制回正式工程。父目录副本未删除，避免越权清理。唯一正式工程交付目录为当前目录。

Godot材质、正式缩略与3D检视对齐由主线程和技术代理验收，本组不声明引擎验收通过。

