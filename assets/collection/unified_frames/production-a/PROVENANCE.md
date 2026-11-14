# 统一卡框A：白/绿

2026-11-13。用户要求五阶共用红卡UE几何后的材质编辑。唯一工具引用图为`assets/collection/red-reference-alignment/frame_galaxy.png`（768×1024 RGBA），已先实际查看；白/绿分别独立内置imagegen编辑，不是代码绘画或旧框换名字。完整实际prompt与引用参数见prompts.md。

原生1086×1448分别保存`sources/grade_0-native.png`、`grade_1-native.png`。原始工具路径分别为`C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c/exec-63cbf87b-817f-4cef-8737-f4814c08be8f.png`与同目录`exec-bebdefe8-de79-4863-a090-e56e8b386ebf.png`。

导出用已有sprite-gen：`slice-sheet --chroma-key none --grid 1x1 --names grade_N --cell-width 768 --cell-height 1024 --baseline-y 1024 --target-height 1024 --scale sheet --fit contain --prefix ''`。不启用alpha-floor，不损伤原生细金边；原图近零alpha残值保留，运行时可阈值过滤。报告在processed/slice-sheet.json及processed/green/slice-sheet.json，各`clipped_px=0`，比例0.7065，主体1448→1023像素。随后复制至父目录正式grade_0.png/grade_1.png。

只改变银白简洁／翠绿细金材质，保留源图的顶部空品阶牌匾、透明插画窗、窗下空主题牌匾、大片奶油正文区与水平分隔线。两原生和两正式输出均实际查看，无文字/水印/新增面板；窗口中心透明，奶油纸不透明。不是黑色填充或棋盘图案。

qa-report.json给出尺寸、实际alpha与中心行/列透明范围。模板窗口中心行x29..738、中心列y86..705；白框为x31..737、y89..706，绿框x32..739、y89..705（alpha≤2边界，含边缘抗锯齿）。因此逻辑布局和牌匾结构一致，**生成像素边界仍存在1～3px差异，未伪称逐像素相同**。没有擅自用代码重画或挪面板来隐藏此差异，最终原生UE对齐由主线程验收。

两正式尺寸768×1024 RGBA，中心alpha0，窗口安全内区alpha最大1，顶部/主题/正文纸面采样alpha253。完整检查见qa-report.json。本目录有.gdignore，源图与报告不会被游戏导入；只正式父目录PNG供运行时使用。未改代码或启动引擎。red_meme由C负责，不在本目录冒称已制作。
