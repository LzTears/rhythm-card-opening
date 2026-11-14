# 工坊冰晶源与再现

效果源码：`pixelfx/src/fx/workshop/frost-crystals.js`。原创topdown构图为六个独立刻面晶块＋两颗接触星，保空中心。参考recipe位于`pixelfx/references/`，MIT原文位于`pixelfx/LICENSE`。

从`source/pixelfx/`运行标准工具：

```text
node tools/render.mjs workshop/frost-crystals --all --sheet --out <review-directory>
node tools/check.mjs workshop/frost-crystals
node ../export.mjs <dual-channel-export-directory>
```

第三条导出独立color/light PNG、正式JSON、全帧contact和逐帧bounds-audit；不启动引擎，不读取玩家档。完整源duration为23/30秒，标准render包含末端空帧，共24帧，正式运行使用24/30秒。

本目录的`.gdignore`避免将离线core、工具、参考source作为Godot运行资源导入。正式只需上层两PNG与JSON，不能将组合预览sprite sheet误当双通道正式资源。
