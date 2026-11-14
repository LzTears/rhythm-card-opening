# 反馈位置计算加速

此模块只计算现有伤害／普通奖励提示的候选位置与延时。它不读写玩法、目标、随机数、存档、鼠标或资源，不删减提示，不改变字形、样式、生命周期和绘制数量。`world_view.gd` 将冻结的轨迹交给它；返回值只有原候选序号和延时步数。

Windows x86_64 预编译 DLL 已随工程提供，玩家直接使用原启动入口，无需安装编译器。其他平台或扩展未加载时，世界表现继续使用原 GDScript 搜索；其他平台的构建和性能未验证。

## 构建来源

- ABI 头：由本机官方 Godot `4.7.2.stable.official.ed1daf0bf` 执行 `--headless --dump-gdextension-interface` 直接生成，文件内保留 Godot MIT 许可证。
- 编译器：官方 [Zig 0.14.1 Windows x86_64](https://ziglang.org/download/0.14.1/zig-x86_64-windows-0.14.1.zip)。压缩包 SHA256：`554f5378228923ffd558eac35e21af020c73789d87afeabf4bfd16f2e6feed2c`，已与[官方索引](https://ziglang.org/download/index.json)核对。
- C ABI 接入依据：[Godot 官方 C 示例](https://docs.godotengine.org/en/4.5/tutorials/scripting/gdextension/gdextension_c_example.html)。未引入 godot-cpp 或第三方运行库。
- 目标 ABI：Godot `float_64`，即 64 位指针／GDScript Float，32 位 Vector2／Rect2 坐标。当前工程使用官方标准精度引擎。

在 PowerShell 中执行：

```powershell
./build.ps1 -Zig '绝对路径/zig.exe'
```

编译参数固定为 `-std=c11 -O3 -fno-fast-math -ffp-contract=off -shared -target x86_64-windows-gnu`。禁止 fast-math 和 FMA 合并，分别保留 Godot float32 几何运算与 GDScript float64 按原顺序求和。共享采样仅缓存同一实际 double 时刻、同一不可变轨迹的结果；变化、移除、时钟变化均失效。

## 验证边界

证据在 `verification/perf-1.0/world-pipeline/`：`native_feedback_equivalence.gd` 比较原始精确算法的候选位置、延时和九项元数据；`owned_feedback_equivalence.gd` 覆盖真实 60 包连续三波伤害、窗口变化、排队删除和时钟变化。单独 headless CPU 微基准不能作为完整游戏 GPU 帧率结论。
