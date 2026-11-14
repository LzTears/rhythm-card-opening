# Patapon背景音乐（2026-11-12）

用户最新确认恢复战斗与局外BGM，并要求Fever有可听辨的音乐变化；该要求取代先前无持续BGM的默认规则。四鼓、逐拍合唱、完整Celebrate01、低层撕包金币保持独立，爆发不新增主击音。

来源是TheSandKid公开社区提取档案。原帖：https://www.reddit.com/r/Patapon/comments/lqdzkt/looking_for_the_extracted_audio_files_of_all_3/ ，档案：https://drive.google.com/drive/folders/1x9Ov7zrXKJNvj7HNdonTiMoqSc6isx5Y 。原帖作者说明Patapon3的任务伴奏可与命令回应分开提供。只下载以下三首完整Ogg，没有下载ROM、游戏或整套档案。

| 用途 | 原档曲名 | 完整时长 | 档案目录 |
| --- | --- | --- | --- |
| 普通战斗 | 01Gyorocchi.ogg | 124.049206秒 | BattleBGM - Patapon 3 / Soundrack / Full |
| 局外菜单、工坊、结算适配 | 04Rinririn.ogg | 124.053424秒 | 同上 |
| Fever战斗 | 01Fever.ogg | 64.025397秒 | BattleBGM - Patapon 3 / Soundrack / Fever |

`manifest.json`逐文件保存公开下载链接、文件ID、原名、字节数、SHA-256、完整Ogg页验证、Vorbis声道/采样率/时长。三文件都是下载原字节，44.1kHz双声道，不裁剪、不拼接、不变速、不生成。Rinririn是原作完整伴奏适配局外，并非声称找到原作城镇主题；实际Patapolis子目录只识别到动作短音。

`music("menu")`和`music("battle")`保持Main接线；重复同状态调用不重启。真实`fever_enter`将普通战斗交叉淡入同曲Fever版，真实`preparation_reset`回普通版。持续Fever期间Main重复请求battle不退出Fever、不反复重启音乐。菜单类场景共享局外曲，切状态使用双播放器交叉淡化，所有片段按完整源首尾循环。事件触发无需等歌曲小节，音乐不作为模拟时钟、不修改120BPM判定，也不宣称原录音与玩家节拍严格同步或原文件首尾已无缝衔接。

线性基础增益：局外0.26、普通战斗0.20、Fever0.22，再乘用户music_volume；accepted输入将音乐临时压至55%，合唱字头压至60%，随后缓慢恢复。暂停冻结播放器、淡化及压低释放；音乐静音保持运输位置并置为-80dB，解除静音不从头重播。`get_status().rhythm.bgm`记录真实路径、普通/Fever/局外状态、looped、paused、position、starts_by_track、实际volume_db与duck。

许可边界：社区提取与公开下载不代表官方商用或再分发授权。原游戏权利仍属于相应权利人；当前未取得官方商用授权。此次确认来源说明、下载原字节、Ogg/Vorbis结构和解码完整性，未开启系统扬声器试听，不能把档案instrumental标签当成已完成逐曲人声听审或最终混音验收。
