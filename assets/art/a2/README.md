# A2 正式像素资产

2026-11-09按用户选定REF-005A2-battle/menu量产，非A3。共17张可导入RGBA PNG；顶层manifest记录所有最终SHA/尺寸/alpha，分目录manifest记录接口。全部美术由内置image_gen实际生成；sprite-gen仅用于透明清理/提取，nearest机械导出不替代绘画。旧资产保留，资产任务未改代码、PRD或GDA会话。

- packs/pack-0..4.png：普通/稀有/史诗/传说/远古，256×384。完整正视竖版封边、无透视。可见bbox高度320，宽234/231/241/234/231；模型未精确生成统一3:4，按真实bbox等比fit60×80du，禁止双轴独立硬拉。模型生成的微小宽差不掩盖，世界代理已收到。
- dispensers/down.png：384×320，bbox[0,60,384,280]，朝下空嘴。mouth暗口中心[192,244]，lip发包anchor[192,272]。可见外形较宽，等比fit80×64后为80×45.833du；按场景需要等比缩放而不拉伸。左右复用90度旋转并同步旋转anchor。
- pack_damage/damage-1..3.png：同256×384全幅注册；不要独立裁bbox。三档中心[72,112,184,272]alpha最大0。顶部/底部与侧边撕痕逐档加强，shader必须乘basealpha裁切。source/registered-preview展示与普通包合成。
- ui/menu-background.png：1600×900，左45%静区无文字按钮，右侧吐包器/五色竖包/猫头鹰蜜蜂海豚圆卡，无狐狸卡族。背景物件允许静物透视，不当战斗形状规格。
- ui/battle-table.png：1600×960，5:3整桌俯视，1000×600du UV0..1映射一次，不repeat；无卡、机器、文字或边中点假发卡口。
- ui/panel.png：220×216，stretch/content四边24；ui/button-normal/hover/pressed/disabled.png：228×77，primary229×77；stretch四边22，content左/右22，上/下8。StyleBoxTexture双轴STRETCH、draw_center true、nearest。文本由游戏绘制。

已查看生成原图、普通包/发卡器正式图、UI contact、damage合成预览；17图实际解码为RGBA。保留A2清新湖绿/象牙/浅蜂蜜木，不把用户选方向当最终运行效果或满意度验收。源图仍有少量色调渐变，UI中心非严格索引平色；低透明度外光已用sprite-gen原生alpha-floor去除，主体最大alpha254保留生成器原值。美术源/提示词/提取报告/机械导出脚本在各source/.gdignore目录。
