# 原有像素几何的批量计算

此模块按原顺序批量生成技能地面／前景像素的六顶点和六颜色，保持原圆弧、线段、裁切、吸附、颜色、透明度和数量。它不决定技能、命中、预算、年龄或可见时间。GDScript 仍选择相同的装饰层与图集，并保留同一重绘请求年龄和图集首次创建顺序。

`Vector2.from_angle`、`snapped`、`lerp` 直接调用当前 Godot 引擎的原生 builtin 接口；其他向量运算使用与官方引擎相同的 float32 操作次序。禁用 fast-math 和 FMA。每个技能实例复用独立的 CPU 缓冲，完成时导出同序 `PackedVector3Array` / `PackedColorArray`，供原来的两层 ArrayMesh 合批上传。

Windows x86_64 DLL 已随工程提供；其他平台或扩展未加载时沿用原 GDScript 路径，其他平台性能未验证。官方 Godot 4.7.2 生成的 ABI 头集中保存在相邻 `feedback_math` 目录；Godot 头和本模块的 MIT 许可证均保留。编译器来源与已核对的官方 Zig 0.14.1 压缩包 SHA256 见相邻 `feedback_math/README.md`。

```powershell
./build.ps1 -Zig '绝对路径/zig.exe'
```

验证脚本位于 `verification/perf-1.0/world-pipeline/`。`native_geometry_equivalence.gd` 对比 108864 项原始顶点／颜色／层级；`native_deferred_geometry_equivalence.gd` 对比 100 帧的几何、年龄、暂停、quiet、预算、atlas 及其首次创建相对顺序。CPU 微基准不作为完整游戏 GPU 帧率结论。

## 0.9 高密度批次合并

`merge(sources)` 接受按原效果顺序排列的四数组记录：地面顶点、地面颜色、前景顶点、前景颜色。先验证类型与配对长度并汇总总长度，再分别一次 resize、按源顺序 memcpy；不执行几何或颜色浮点运算。四个输出缓冲由独立批次实例复用，使用 Godot PackedArray 的写时复制，外部保留的旧输出和自引用输入均保持不变。非法记录返回空数组，World 使用原有 append 回退路径。

World 仍使用相同 ArrayMesh `clear_surfaces` / `add_surface_from_arrays` API、三角形次序、两个层和原来的增删判断。没有修改技能实例的几何生成、预算、寿命、图集、伤害或文字。

本轮分摊与验证在 `verification/cards09/native-batch/`：0/1/20/100/200/240 效果、追加/排队删除/变长/预算变化、COW旧快照、自引用源、非法输入回退，以及真实 E06＋四张LV30快充长排程1200 tick的全部有序顶点／颜色。具体 CPU 数值以该目录 JSON 为准，完整窗口 GPU 验收另由主线程执行。

## 0.9 单技能导出存储复用

`finish()` 的四个输出同样由各技能自己的原生实例复用，仍按原顺序 memcpy 全部顶点和颜色。技能在同步导出前释放自身上一帧的四个引用；外部保留的输出仍由 Godot 写时复制保护。批次输出与技能输出分别持有自己的四个缓冲，互不覆盖；其他平台的 GDScript 路径不变。重绘年龄、预算与图集逻辑不变。分摊、旧输出保留和逐项等价证据位于 `verification/cards09/native-finish/`。

## 完整地面圆弧方向缓存

仅在地面圆弧 `start == 0.0 && sweep == TAU` 时读取固定方向表。SCENE 初始化在注册类之前，按原 double 表达式 `0.0 + TAU * i / count` 调用同一引擎 `Vector2.from_angle`，覆盖 count 8—192 和端点；运行时只读，非完整圆、旋转圆及全部前景圆弧仍调用原路径。像素吸附、裁剪、颜色、六顶点、虚线和数量均不变，继续禁用 fast-math/FMA。

`verification/cards09/native-circle/` 保存原 C/DLL、1868 组原 DLL 的 Packed 输出、9340 项逐字节比对，以及108864/120957原几何回归。独占 headless CPU 微基准中，200/240 效果重绘均值分别从4.963/5.945 ms降至3.665/4.316 ms；完整窗口帧时间仍由单独GPU验收记录决定。

TASK-119: native procedural quad clipping now matches the 1440x600du top-down arena (X -7.2..7.2m, Z 0..6m). The GDScript fallback reads the same PackRules dimensions. Rebuild after changing these geometry limits; atlas batches use their own registered event geometry and are unaffected.

## QUALITY17 图集批量填充

新增独立七参数 `fill_atlas_rows(buffer, rows, slots, clamped_frames, opacity_float64, columns, grid_rows)`，一次填充一个图集batch的已编译固定变换与当前UV/alpha。每行16float、实际使用前12项变换；frame由调用者按各自真实source.frames先clamp。先验证全批输入再通过Godot PackedFloat32Array复制构造／可写accessor写入结果，保留输入及旧快照COW；非法输入返回空、调用者完整GDScript回退。double UV除法／alpha clamp后castfloat32，旧九种几何操作、clip算法、构建flags不变。未新增常驻buffer owner或线程。

本层证据在 `verification/quality17/perf-native-atlas/`：6071项整buffer/mixed/COW/invalid/fallback检查、旧DLL九类操作96场景全Packed字节SHA相同、源码分层逆审。977效果／2172源记录的headless完整submit CPU均值4.335→3.361ms；实际GPU帧率另由主线程验收。

