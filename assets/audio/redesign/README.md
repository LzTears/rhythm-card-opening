# 真实事件轻量声音（2026-11-12）

玩家四鼓与独立逐拍合唱未替换；当前BGM按用户最新要求见相邻patapon_bgm/README.md；爆发末拍不增加Weapon或impact主击。所有新层走已有sfx音量、静音和暂停控制。

- `fever_enter.wav`：Patapon3 `Celebrate01.wav`完整原字节，2.189206秒。来源TheSandKid社区原音档案，原游戏权利仍属权利人，未建立官方商用授权。第3句末拍真实`fever_enter`后延迟8tick避让合唱字头，不延长输入等待；下一次accepted输入把欢呼余尾压到原增益18%，不裁剪。
- `pack_break.wav`：BigSoundBank Torn paper #9（#3246），Joseph SARDIN & Axeline T.，CC0，0.886646秒。来源：https://bigsoundbank.com/papier-dechire-9-s3246.html 。真人纸张撕裂录音，24位转16位PCM，未剪裁或生成。实际claim时播一次，不对未击破hit播放。
- `coins.wav`：`Coins_Few_05.wav`，0.244771秒，Little Robot Sound Factory，CC-BY 3.0。来源：https://opengameart.org/content/coins-sound-effects-library 。署名：Coins_Few_05 by Little Robot Sound Factory (www.littlerobotsoundfactory.com), CC-BY 3.0 (https://creativecommons.org/licenses/by/3.0/); PCM16 format conversion only.
- `gather.wav`：Patapon2菜单Scroll；`merge.wav`：Patapon2菜单Confirm；`expand.wav`、`spawn.wav`：Patapon2菜单MenuOpen。除merge外从外层参考库原字节复制；merge仅取前0.120秒、末15毫秒淡出防止截断爆音，实际合成groups按唯一from_grade排序，每8tick升一级音高（1.0/1.1/1.2/1.3），同阶多组只播一次，四阶含尾音约0.52秒。沿用社区档案许可边界。它们是适配的轻量菜单提示，不声称原作专用聚拢/合成/纸张素材。

检索过公开Patapon根目录、Menus及Patapolis列表，未识别到专用撕包或金币素材；不从未试听Weapon编号推断用途。外层`参考音频/现成材质-20261112/`保存下载原录音，全部工程WAV和原音SHA-256、位深、采样率、来源、处理见`manifest.json`。不下载游戏或ROM，不使用AI生成声。

接口`play_redesign_events(events:Array,tick:int)`只消费Main传入当前tick、`executed:true`且非空`event_id`的模拟真实事件；按event_id去重，按声音种类+tick聚合。`claim`同时授权撕包，以及reward.coins>0时金币；`skill_event`的pull/expand/merge映射轻量声音，empty及at_cap不造声音；burst/hit不额外主击。聚合不修改任何事件、伤害、金额、目标或账本。同类正在播放时不叠声，音量不随目标数变化。accepted输入和echo短暂压低次要声，暂停冻结压低释放时间和所有播放器，静音会消费事件但不补播。

基础线性增益：鼓输入0.90、echo0.80保持原样；新层欢呼0.48，撕纸0.16，金币0.14，合成0.14，扩圈/聚拢0.12，投放0.10。以上是待试听起点，非主观听感验收。此轮仅验证来源描述、下载字节、WAV结构、时长和SHA；未开启系统扬声器逐项试听，不把录音的内容标签视为听审通过。
