# pixelfx09共享图集源

图集来自本机pixelfx源码导出，包含透明RGBA PNG及Aseprite格式JSON，属于库效果变体。上游[patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)，MIT许可见LICENSE.txt（Patch / Hugo Duprez）。源文件SHA、palette/light/seed及采样范围见manifest.json、source/source-sha256.json与source/vendor_snapshot；没有可验证Git提交号时不补造。

运行时使用JSON的meta.pixelfx网格、帧/FPS与pivot。pivot对齐真实发光核或束源，nearest采样；显示宽度建议不扩大真实攻击范围。WorldFxAtlas将本目录作为共享兜底，具体可达键由当前代码决定。

项目根目录复建：`node assets/fx/pixelfx09/source/export.mjs 2`。数据检查：`node assets/fx/pixelfx09/source/verify.mjs`。参数2为当前制作配置；先核脚本写入位置，不为查看状态无意重导出。source/.gdignore将制作源排除出Godot导入。当前集成检查见项目verification/current，不依赖候选联系表或历史单次报告。
