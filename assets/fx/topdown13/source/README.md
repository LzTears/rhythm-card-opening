# 俯视图集制作源

本目录保存topdown13共享图集的可再生输入。源SHA、源FPS/时长、采样区间、调色及适配方式见上层manifest与各图集JSON；pixelfx原源码随vendor_snapshot保留，许可见上层LICENSE.txt。

在项目根目录按需要运行`node assets/fx/topdown13/source/export.mjs`生成，`node assets/fx/topdown13/source/verify.mjs`检查。先核脚本输出位置，不把运行制作脚本视为无修改检查。paper-press.mjs提供俯视重击，生产heavy从源RELEASE=0.10秒开始，不在实际命中后另等该延迟。

运行时WorldFxAtlas按JSON和实际可达key载入共享纹理；别名图集可引用同一PNG。方向、半径与目标来自真实事件，native主体使用primary_radius，coverage只表现同一攻击已有范围。不能按文件中存在其他元素或别名推断当前解锁范围，也不能因当前仅重击就移除仍被预热的共享图集。

当前集成验证见项目verification/current及docs/PRD.md。源与纹理一致性检查不代替实际Main、游戏画面、主观美术或性能测量。
