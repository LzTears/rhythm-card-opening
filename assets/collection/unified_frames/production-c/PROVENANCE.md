# 非主流统一红卡框

2026-11-13。Root明确承接A未调用任务，单次调用内置image_gen.imagegen。先view唯一几何母版assets/collection/red-reference-alignment/frame_galaxy.png及旧meme红框assets/collection/frames/grade_4.png；实际生图只引用GAL母版。旧框只观察装饰，不用其窗口和文字区结构。

完整提示在prompt.txt；native保留red_meme_native.png，真实生成1086×1448 RGBA。正式../red_meme.png仅用Pillow LANCZOS机械缩放至768×1024，未绘制或修补任何设计、alpha孔、贴图或文字。目录有.gdignore。没有启动引擎。

已view工具输出及最终768×1024图：红金浮雕与四角红宝石、轻微歪眼笑脸/像素暗纹，顶中央空品阶、下中央空主题牌匾、大奶油纸区和横分隔线按GAL布局保留，无文字无插画，无星系主题图案。完整外轮廓可见。

数值alpha检查见qa.json：画窗核心alpha0..2，奶油纸及两个牌匾核心252..254，满足本轮约定的runtime阈值。孔边/外缘有模型生成的零星alpha碎点，未程序修设计。生成孔边存在少量漂移，仍须主线程实际UI对齐验收。
