extends RefCounted
## 单局时长只改这里，单位：秒。先结束当前局；修改后重启游戏并开始新局。
const RUN_DURATION_SECONDS: int = 90

## 默认音乐／音效音量，1.0为100%。
const DEFAULT_MUSIC_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0

## 模拟时钟；不要为了调整局长修改它或鼓点BPM。
const TICK_RATE: int = 60
const RUN_TICKS: int = RUN_DURATION_SECONDS * TICK_RATE

static func duration_caption() -> String:
	return "%d秒" % RUN_DURATION_SECONDS

static func clock_caption(remaining_ticks: int = RUN_TICKS) -> String:
	var seconds := ceili(float(maxi(0,remaining_ticks))/float(TICK_RATE))
	return "%02d:%02d" % [seconds/60,seconds%60]
