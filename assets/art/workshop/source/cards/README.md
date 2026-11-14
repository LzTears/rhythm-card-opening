# 当前工坊圆卡制作源

当前正面只有C09-0、C01-0、C04-0、C12-0，通用卡背为card_back.png。绑定、源图、prompt、SHA及切片报告见[当前卡面清单](../../cards_manifest.json)；玩法身份以项目attack_spec.gd的当前卡集合为准。

保留C01/C04/C09/C12四家族的sheet、清单引用的prompt、C09完整几何生成提示、各自cut目录，以及card_back-original.png、card_back-prompt.json和back-cut。家族sheet包含多个构图格，完整slice-sheet.json和alpha-cleanup.json用于再生当前格，不意味着开放其余卡。当前原始字节与源SHA不能被后处理覆盖。

切片记录采用sprite-gen官方slice-sheet：正面5x1、卡背1x1，chroma-key none、alpha-floor64、noise-min10000、fit contain、target-height472、baseline492、512×512。按保留的报告和当前manifest选择Cxx-0，不依赖外层风格预览或已撤下的比较映射。

媒体由内置image_gen独立生成；具体生成来源见保留的prompt。此说明是当前制作输入说明，不是引擎、像素或主观美术验收报告。旧批量verify_cards.py不适用于当前集合，不应运行来重写当前清单。当前验证入口见项目verification/current。
