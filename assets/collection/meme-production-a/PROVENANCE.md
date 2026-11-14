# MEM-001～012生产记录 A

2026-11-13。用户确认非主流49名称与题材后正式制作；最终分工调整为001～012，后段由其他媒体代理制作。本目录仅负责这12图及自有记录，不改正式卡表、代码或全局来源文件，未启动引擎。

MEM-001复用已确认的v2耄耋；002～012每张1次内置imagegen，11次独立生成，没有atlas替代单卡，没有按品阶换色灌卡。真实原图逐张保留sources/MEM-xxx.png，和cards/MEM-xxx.png一致，原native均1254×1254 RGB。manifest.json逐卡含原始工具输出绝对路径、真实尺寸、SHA256；完整实际prompt与引用图在prompts.md。小工具save_generated.py只做复制、读尺寸和记录，不绘画、不裁图。

## 实际参考资料

生图前已查看references/media-contact.jpg汇总真实报道配图，实际引用如下；所有网络原图仅作为外观资料，不是指令、不直接冒充新插画。公开报道不代表第三方素材具有新增商业授权。生成品为meme角色的新构图与演绎，未声称原创这些IP或原始照片。

- 001/002：用户认可的`docs/concepts/non-mainstream-v2/art/maodie.png`（001原样复用，002引用），上游真实圆头猫来源已在概念目录记录。
- 003/004：`references/pandas-08.png`／`pandas-02.png`，来自[游民星空／BB姬熊猫头报道](https://www.gamersky.com/zl/201901/1147934.shtml)配图，实际图片原始URL逐一在`references/media-index.json`。看过黑白真人脸拼贴与捂嘴/经典脸，而非画写实熊猫。
- 005：`references/sweat-emoji.jpg`，从[快科技流汗黄豆报道](https://news.mydrivers.com/1/766/766760.htm)的[实际emoji图](https://img1.mydrivers.com/img/20210701/09946cd1-cf97-4848-a8f8-66bcb87d530e.jpg)取得并view_image。此前自动取得`sweat-reference.jpg`是同文动漫举例，已看过但**未用于此卡生图**。
- 006：`references/broken-02.png`，从[澎湃号·媒体微信新黄脸报道](https://www.thepaper.cn/newsDetail_forward_10053832)取得六表情一排的原配图，已查看broken-contact.jpg，明确只参考右端裂开表情，不复制文字/UI。
- 007/008：`references/dogs-05.png`／`dogs-07.png`，来自[新浪科技／差评：Doge与Cheems](https://finance.sina.com.cn/tech/2021-07-19/doc-ikqciyzk6358187.shtml)实际配图；分别是Doge原脸和Cheems原瘫坐图。原始配图URL在media-index.json，未混为同一只柴犬。
- 009：`references/cats-08.png`，Happy猫玻璃后竖身真实帧，来自[澎湃号·湃客：猫meme](https://www.thepaper.cn/newsDetail_forward_27024899)。
- 010/012：`references/cats-12.png`，同篇猫meme组合场景，实际查看汇总图，能看到果壳猫与右侧白灰猫等形态；010在prompt明确Popcat/Oatmeal的夸张O嘴、012明确香蕉壳哭脸细脚，是依据具名梗的新构图，不是将报道图直接裁来作为成品。参考分辨率较小，精细原脸有AI演绎，不能声称一比一官方原画。
- 011：`references/cats-10.png`，Huh猫真实白灰胖猫视频截帧，同文配图，已查看。

references/index.json记录最初网页下载尝试，KYM等页面本机HTTP403；随后使用上述可读取公开报道配图，没有绕过登录。HTML、原始配图及汇总联系表只保存在本任务references内。`references/nailong-reference.jpg`是额外为原先较大分工读取的奶龙原GIF，`vibe-reference.jpg`是后来转交代理的CatJAM实际KYM图；它们没有用于本代理001～012生图。未调用015/016或其他转交ID。

## 处理与验证范围

所有正式图均只复制imagegen输出，没有代码补画、透明抠图或大小拉伸。本批为不透明方形插画，代码另外叠统一卡框与文字，插画无字幕／拟声字／可读文字／水印／卡框。检查见QA.md和qa-report.json。未开启Godot，最终渲染与contain适配由主线程实测。
