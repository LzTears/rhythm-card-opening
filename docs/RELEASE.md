# 节拍开卡1.0.1 · PC / Web

**[下载 Windows x64 PC 包](https://github.com/LzTears/rhythm-card-opening/releases/download/v1.0.1/1.0.1.zip)** · **[下载 Web 包](https://github.com/LzTears/rhythm-card-opening/releases/download/v1.0.1/1.0.1-Web.zip)** · [游戏介绍、截图与操作](https://github.com/LzTears/rhythm-card-opening#readme)

## 本次修复

修复天赋页面鼠标经过其他节点时切换选择，导致右侧升级目标变化的问题。鼠标经过只保留悬停反馈，点击节点才切换选择；鼠标升级、键盘Enter／Space与手柄A确认均作用于当前所选天赋。价格、等级、前置和存档目录保持现行规则。

PC和Web均从修复后的同一份源码重新导出。90秒单局、四拍指令、147张收藏卡、20类天赋及5条成长路线保持不变。

## 下载与启动

| 平台 | 下载显示名 | ZIP大小 | 启动方式 |
| --- | --- | --- | --- |
| Windows x64 | 节拍开卡1.0.1.zip | 163,021,926字节，约155.47 MiB | 完整解压后运行节拍开卡.exe，保持PCK及三个DLL同目录 |
| Web电脑浏览器 | 节拍开卡1.0.1-Web.zip | 135,096,108字节，约128.84 MiB | 安装Python 3.9+，完整解压后运行启动Web内测.cmd |

PC无需安装Godot或Python，需要支持OpenGL 3.3的显卡。普通入口沿用本机v15进度；独立新档启动.cmd使用单独的进度目录。

Web包需在本地通过HTTP运行，不能直接双击index.html。启动后打开 http://localhost:18765/ 并点击开始游戏启用声音；建议使用支持WebGL 2的Chrome／Edge。也可在包目录执行 `python serve.py --port 18765 --open`。浏览器进度与PC独立，沿用同一浏览器和上述地址可保留Web进度；不要清除站点数据或使用无痕模式。

GitHub会将中文附件名规整为1.0.1.zip及1.0.1-Web.zip，显示名和包内目录保留中文。自动附带的Source code为开发源码。历史1.0保留在旧Release。

## SHA-256

PC：

```text
580d14f5f2f07da1beedeb5a6d2bc73844a00626a417693c7d0c2587a3987f58
```

Web：

```text
8dab34d1500b47d7810f94d756305ce0270fc0ea02a37cdd9b54a63a400eed2f
```

附件提供对应校验文件，PC包内37项、Web包内43项文件校验通过。构建号15.20261114.9；PC／Web的106份脚本资源一致。源码及新PC包内分别重跑116项天赋输入专项通过，独立PC EXE启动通过；Web正式入口、声音启用与本地存储启动检查通过。验证使用隔离测试环境，未访问或清理玩家进度；不代表已完成异机、全浏览器或长时真人试玩验收。

## 许可与素材

原创代码MIT；素材与第三方组件遵循独立许可。Patapon音频、部分角色和网络形象的公开再分发授权尚未确认。详见仓库及附件中的THIRD_PARTY_NOTICES.md，以及包内“开源与素材说明.md”和“第三方许可”。
