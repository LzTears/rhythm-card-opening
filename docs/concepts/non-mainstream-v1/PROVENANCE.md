# 非主流三张样卡插画来源与核验

2026-11-13。仅用户确认前的三张插画概念，不加入正式卡池，不擅自制作49张。全部实际生成于内置image_gen，一张一调用，共3次；每张1254×1254不透明RGB PNG，无卡框、可读文字或水印。完整实际prompt/工具参数/引用图路径在`prompts.md`，尺寸与独立SHA256在`manifest.json`。主线程负责现有CardView、正式五阶框、标题和红Holo合成。

## 外观参考与可查来源

- 圆头耄耋：[新浪财经转载澎湃新闻，2026-01-01](https://finance.sina.com.cn/jjxw/2026-01-01/doc-inheurvq3067891.shtml)。本次实际读取网页并下载其“圆头耄耋表情包”配图：[原图](https://n.sinaimg.cn/sinakd20260101s/673/w347h326/20260101/a4ba-3446aba973ad2e8aa76a4bf0257633a4.png)，保存`sources/maodie-reference.png`，view_image确认是猫脸表情缩略图集合。参考圆脸、橘毛、扁飞机耳和哈气身份，生成独立广角照片式构图，未复制网页UI/字。
- 奶蛙：[NaiWaHub 奶蛙系列页](https://naiwahub.com/zh/series/nai-wa)。本次实际读页并下载“奶蛙抱臂微笑”图：[原图](https://naiwahub.com/media/naiwa/dot-naiwa-0053-poster.webp)，保存`sources/naiwa-reference.webp`；view_image核对黄身、奶白肚、绿色圆眼、平嘴、灰绿手的怪诞3D外观后作为引用图。用户提供的[香港商报2026-11-12报道地址](https://www.hkcd.com.hk/hkcdweb/content/2026/11/12/content_8785029.html)本次网页工具无法读取，未伪称核验该报道全文。
- 高雅人士：[“鹅是高雅人士”官方账号页面](https://www.sina.cn/media/9037159438)本次实际读取，页面自述William Tell Penguin中国授权官方微博；头像图下载403，未采用。改从[果壳2025-11-19报道](https://www.guokr.com/article/467906)下载其企鹅梗图：[实际外观参考图](https://3-im.guokr.com/RmtHUm5jUjNnLTJDZjFUSF9ld3NLd0Z0V1FPOWRvY3g4BAAAFwQAAEpQ.jpg)，保存`sources/elegant-penguin-reference.jpg`并view_image核对黑白圆肚、墨镜、橙嘴脚的具体3D形象。另下载该报道[素材来源截图](https://1-im.guokr.com/RmsyNzktYUxYYzZlemhfQUh6clRXc3AzckVhdmRvY3g4BAAAPQIAAEpQ.jpg)，保存`sources/elegant-penguin-stock-origin-reference.jpg`；该图仅是素材来源证据，不是生图引用。用户另给的[新民晚报页面](https://paper.xinmin.cn/html/xmwb/2025-11-25/4/225634.html)本次超时，未当作已读来源。

以上图像属于各来源及原权利人，本地参考文件仅用于此概念制作追溯，不声称原创IP或授权素材。三张成图是imagegen依据实际外观参照生成的新构图，不是下载网络原图改名。

## 样图检查

- `art/maodie.png`：照片式广角圆头橘猫，扁耳、哈气张嘴呲牙，表情优先；身体、爪和尾可见，未画成普通萌宠。尾巴靠右边缘约1%，未完全达到提示中的10%留白；头脸和主体无裁切，最终套卡时须检查contain展示，不应声称所有边都10%。
- `art/naiwa.png`：黄身、醒目绿眼、奶白肚、细手臂/腿和暗色手脚，双手抱在身前装正常；保持3D而非动漫。头顶留白约5%，脚底约9%，主体完整但未完全达到提示12%边距；最终套卡需检查不放大裁头。
- `art/elegant-penguin.png`：墨镜、黑领结、黑白圆肚、小橙脚交叉、谢幕姿势；红绒舞台与金聚光，3D滑稽体面。完整主体约12%上下留白，未加文字与Holo覆盖。

已实际查看三次生成结果；3图路径/尺寸/哈希检查通过。按“一张一调用”完成三种方向，未额外批量或重生；最终卡框中是否遮挡、名称与Holo效果由主线程实际渲染验收。用户尚未确认此主题的最终美术，也未确认49个具体卡身份。
