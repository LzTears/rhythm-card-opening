# QUALITY17 冰霜 E05

正式素材为 `main/wave/path/contact` 各一对 `-color.png`、`-light.png`，四份同名 JSON 使用 QUALITY15 格式。颜色层保留原始 alpha，光层保留原始加色 RGB；禁止先将两层烘焙再以 mix 显示。

主效果复用 pixelfx `ice/snowflake-burst` 完整 create/draw、flakeDesign、雪花分叉、flare、Particles、Lights，保留 3.2 秒原生时间与 30 FPS。适配仅包括方形留白／真爆心锚点、取消雪花的侧视落地与单轴重力，将运动放到桌面平面。它是保留原雪花细节的桌面平面适配，非原PNG逐像素副本。主实体尺度基准 40px，pivot=(96,96)；外部光晕与飞散雪粒不用于扩大伤害圈。

Wave 实质复用原库 plasma-explosion 的完整双 shock-ring track，换冷蓝配色；它不恢复已移除的 E03 发射器。Path 完整导出 actor-free thrust，from=(43,42)→to=(109,42)，66px 协议。Contact 完整导出 hit-spark，提交同帧已有短白热 diamond/cross 和光，补充主效果原生 0.16 秒聚霜段。

| 角色 | 帧 / FPS | 原源时长 | 实际播放寿命 N/FPS | body_radius_px |
|---|---:|---:|---:|---:|
| main | 97 / 30 | 3.2s | 3.233333s | 40 |
| wave | 52 / 30 | 1.7s | 1.733333s | 92 |
| path | 24 / 30 | 0.75s | 0.8s | 66 |
| contact | 16 / 30 | 0.5s | 0.533333s | 37 |

末端采样完整保留，所有终帧 color/light 均为空。Wave 原轨在源时间结束前已有空白尾段，未裁尾或加速。没有改变规则、事件、伤害、目标、圈、保存或任何 runtime 文件。

重建：Node 运行 `source/prepare.mjs` 后，运行 `source/export.mjs`；检查 `source/check.mjs`。工具使用本机只读 pixelfx vendor。`source/upstream`保留原源文本与署名；源/输出SHA以当前manifest和图集JSON为准。Source 目录 `.gdignore` 排除 authoring 联系表导入。原库与 Sprite Fusion 上游 MIT 署名保留在源文件头。

当前集成检查入口见项目verification/current及docs/PRD.md；制作检查不代表实际Main、主观美术或FPS通过。

