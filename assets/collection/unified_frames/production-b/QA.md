# 统一五阶框B组制作QA

2026-11-13。本组只制作grade_2.png（紫史诗）、grade_3.png（金传说）、red_digimon.png（数码红）。三张均单独内置imagegen编辑，唯一传入的几何参考均为red-reference-alignment/frame_galaxy.png。已先view GAL及旧数码框；旧数码框仅作装饰理解，没有传给工具，不沿用其较高头区／不同纸区布局。

原生返回1086×1448，使用sprite_gen.util.resample.resize_cell机械导出768×1024，禁止手绘/Pillow设计修改未做。export_verify.py保存可复现机械导出和只读alpha QA过程；实际运行的是sprite-gen独立venv。production-b已加.gdignore。

每张native和最终PNG均逐张view：紫色为晶莹紫珐琅＋香槟金纹；金色为烫金细雕＋琥珀凹纹；数码红为红皮金电路方块，使用GAL同一曲边顶部牌匾和底纸。均保留空品阶牌匾、插画孔、空主题牌匾、底纸名称简介区和分隔线，无任何字或品牌、水印。无插画、黑底或棋盘底烘焙；view展示黑色为透明显示底。

## 实测限制

- 三张尺寸严格768×1024，窗口采样alpha最大紫1、金2、数码2，符合允许≤2/255残值；外四角紫／数码0，金一个角1/255。
- 底纸无透明洞，但生成器仍输出近满alpha：紫251..254，金/数码252..254；顶纸252..254或252..253。runtime应沿既定阈值恢复近满。
- 视觉上布局跟随GAL，然而不能宣称逐像素完全一致。只读alpha剖面实测中心x384的窗口顶/底转折：GAL82/708；紫84/705；金85/705；数码87/706。左右边缘样本亦有最多数像素漂移。详见geometry-alpha-crosssections.json。建议正式渲染采用统一runtime窗口和纸区定位而不是分别推断alpha孔边界。未擅自手工改设计或补像素。
- 工具请求明确要求所有几何锁定，结果仍属生成器近似编辑；本组如实记录，主线程负责决定是否集成及最终UE截图验收。

每张完整真实prompt位于prompts/；全部native位于sources/；各*-qa.json保存尺寸alpha与SHA256；provenance.json保存工具原始路径。未修改代码／原五阶框，没有运行引擎。

