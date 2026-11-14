extends Node
## Original input voices, event-authorized echoes and independent background music.

const GameConfig = preload("res://scripts/game_config.gd")
const RHYTHM_AUDIO_ROOT := "res://assets/audio/patapon_build_v8/"
const RHYTHM_ECHO_ROOT := "res://assets/audio/patapon_cadence_v12/"
const RHYTHM_KEYS := ["pata","pon","don","chaka"]
const RHYTHM_DRUM_KEYS := RHYTHM_KEYS
const REFERENCE_BPM := 120
const RHYTHM_INPUT_VOICES := 8
const INPUT_GAIN := .90
const ECHO_GAIN := .80
const ECHO_STEP_TICKS := 30
const JUDGEMENT_PATHS := {"perfect":"res://assets/audio/judgement/perfect.wav","miss":"res://assets/audio/judgement/miss.wav"}
const JUDGEMENT_SEEN_LIMIT := 256
var judgement_player: AudioStreamPlayer
var judgement_streams: Dictionary = {}
var judgement_seen: Dictionary = {}
var judgement_seen_order: Array[String] = []
var judgement_counts := {"perfect":0,"miss":0}
var judgement_consumed := 0
var judgement_kind := ""
var judgement_last_tick := -1
var judgement_batch_tick := -1
var judgement_duck_remaining := 0.0
const REDESIGN_ROOT := "res://assets/audio/redesign/"
const REDESIGN_GAIN := {"fever_enter":.48,"pack_break":.16,"coins":.14,"gather":.12,"merge":.14,"expand":.12,"spawn":.10}
var redesign_players: Dictionary = {}
var redesign_seen: Dictionary = {}
var redesign_groups: Dictionary = {}
var redesign_counts: Dictionary = {}
var redesign_consumed := 0
var redesign_pending: Array[Dictionary] = []
var redesign_duck_remaining := 0.0
var redesign_duck_level := 1.0
var redesign_fever_ducked := false
var redesign_merge_history: Array[Dictionary] = []

const MUSIC = {"menu":"res://assets/audio/patapon_bgm/menu_rinririn.ogg", "battle":"res://assets/audio/patapon_bgm/battle_gyorocchi.ogg","battle_fever":"res://assets/audio/patapon_bgm/battle_gyorocchi_fever.ogg"}
const BGM_BOOST_DB := 2.0 # User-confirmed global music lift; drum ducking remains downstream.
const BATTLE_BGM_EXTRA_DB := 7.0 # Cumulative battle-only lift: original 2 dB + newly added 5 dB; menu gain is unchanged.
const BGM_TRACK_ADJUST_DB := {"battle":2.0,"battle_fever":-2.0} # Latest per-track adjustment; menu remains unchanged.
const MUSIC_GAIN := {"menu":.26,"battle":.20,"battle_fever":.22}
var battle_music_fever := false
var music_starts: Dictionary = {}
var music_phrase_duck := 1.0
var music_phrase_duck_remaining := 0.0
const SOUNDS = {
	"ui_click":"res://assets/audio/sfx/ui_click.wav", "charge":"res://assets/audio/sfx/charge.wav",
	"impact":"res://assets/audio/sfx/impact.wav", "flip":"res://assets/audio/sfx/flip.wav",
	"hit":"res://assets/audio/sfx/hit.wav", "harvest":"res://assets/audio/sfx/harvest.wav",
	"rare":"res://assets/audio/sfx/rare.wav", "ancient":"res://assets/audio/sfx/ancient.wav",
	"upgrade":"res://assets/audio/sfx/upgrade.wav",
	"collect":"res://assets/audio/sfx/collect.wav", "result":"res://assets/audio/sfx/result.wav"
}
const ORDINARY_VOICES := 12
const IMPORTANT_VOICES := 2
# One foreground accent and at most one 40ms release tail. These priorities only
# arbitrate playback, never gameplay/reward events. Red takes precedence over gold.
const IMPORTANT_PRIORITY = {"harvest":10,"rare":20,"ancient":30,"upgrade":40,"result":50}
const IMPORTANT_RELEASE_SECONDS := .04
# Linear trims after the existing call-site gain. Suggested listening starting
# points: leave impact/hit/flip/UI intact; harvest/collect/charge sit below reveals.
const SOUND_GAIN = {"charge":.72,"collect":.70,"harvest":.60,"rare":.95,"ancient":1.0,"upgrade":1.15,"result":1.0}
const MIX_CEILING_DB := -1.0
var enabled: bool = false
var music_volume: float = GameConfig.DEFAULT_MUSIC_VOLUME
var sfx_volume: float = GameConfig.DEFAULT_SFX_VOLUME
var music_muted: bool = false
var sfx_muted: bool = false
var ducked: bool = false
var duck_gain: float = 1.0
var desired_music: String = ""
var active_music: String = ""
var music_players: Array[AudioStreamPlayer] = []
var sfx_players: Array[AudioStreamPlayer] = []
var important_players: Array[AudioStreamPlayer] = []
var important_state: Array[Dictionary] = []
var mix_bus: StringName = &""
var music_gains: Array[float] = [0.0,0.0]
var music_targets: Array[float] = [0.0,0.0]
var current_voice: int = 0
var stream_cache: Dictionary = {}
var last_sound_ms: Dictionary = {}
var retry_timer: float = 0.0
var rhythm_music_players: Array[AudioStreamPlayer] = [] # Retired, never populated.
var rhythm_sfx_players: Array[AudioStreamPlayer] = []
var rhythm_streams: Dictionary = {}
var rhythm_assets: Dictionary = {}
var rhythm_echo_streams: Dictionary = {}
var rhythm_echo_assets: Dictionary = {}
var rhythm_event_counts: Dictionary = {}
var rhythm_input_counts: Dictionary = {}
var rhythm_echo_counts: Dictionary = {}
var rhythm_input_history: Array = []
var rhythm_echo_history: Array = []
var rhythm_echo_seen: Dictionary = {}
var rhythm_echo_seen_order: Array[String] = []
var rhythm_echo_consumed := 0
var rhythm_echo_prime_tick := -1
var rhythm_voice_steals := 0
var rhythm_voice_cursor := 0
var rhythm_paused := false
var rhythm_active := false
var rhythm_clock_tick := -1
var rhythm_waiting_for_sync := false
var rhythm_beat_count := 0 # Reference metadata only; no audio beat scheduler.
var rhythm_last_key := ""
var rhythm_last_response_key := ""
var rhythm_bgm: AudioStreamPlayer = null
var rhythm_bgm_stream: AudioStream = null
var response_music_player: AudioStreamPlayer = null
var response_music_streams: Dictionary = {}
var response_music_assets: Dictionary = {}
var terminal_tail_active := false # Retired; completed results never wait on audio.
var web_play_requests: Array[Dictionary] = [] # Diagnostic requests, never an audio clock.
var web_play_request_total := 0

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		set_process(false)
		return
	_setup_players()
	_load_rhythm_assets()
	_load_stream(str(SOUNDS.ui_click))
	if OS.has_feature("web"):
		for path: String in SOUNDS.values():
			_load_stream(path)
	_load_stream(str(MUSIC.menu),true)

func _load_rhythm_assets() -> void:
	for player in rhythm_sfx_players:
		player.stop()
		player.stream = null
	rhythm_streams.clear()
	rhythm_assets.clear()
	rhythm_echo_streams.clear()
	rhythm_echo_assets.clear()
	# Independent original inputs and derived troop echoes. Neither can fall
	# back to the other voice family; no response clip or music is loaded.
	for key in RHYTHM_KEYS:
		var path := RHYTHM_AUDIO_ROOT+str(key)+".wav"
		var stream := _load_stream(path)
		if stream!=null:
			rhythm_streams[key] = stream
		rhythm_assets[key] = {"source":"sample" if stream!=null else "missing_original",
			"origin":"community_patapon_extract","path":path if stream!=null else "",
			"requested_path":path,"length_seconds":stream.get_length() if stream!=null else 0.0}
		var echo_path := RHYTHM_ECHO_ROOT+"echo_"+str(key)+".wav"
		var echo_stream := _load_stream(echo_path)
		if echo_stream!=null:
			rhythm_echo_streams[key] = echo_stream
		rhythm_echo_assets[key] = {"source":"sample" if echo_stream!=null else "missing_echo",
			"origin":"derived_original_troop_response","path":echo_path if echo_stream!=null else "",
			"requested_path":echo_path,"length_seconds":echo_stream.get_length() if echo_stream!=null else 0.0}

func _setup_players() -> void:
	# This router owns the bus and removes it on exit. Never modify Master or an
	# unrelated app's buses. Safety limiting includes the existing music crossfade.
	if not music_players.is_empty():
		return
	mix_bus = StringName("RoundCardMix%d" % get_instance_id())
	if OS.has_feature("web"):
		# Godot 4.7.2 Web Sample's addAt(-1) inserts before Master, forming
		# a send cycle and silencing Sample voices. setCount appends correctly.
		AudioServer.set_bus_count(AudioServer.bus_count+1)
	else:
		AudioServer.add_bus()
	var bus_index := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus_index,mix_bus)
	AudioServer.set_bus_send(bus_index,&"Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MIX_CEILING_DB
	limiter.pre_gain_db = 0.0
	limiter.release = .1
	AudioServer.add_bus_effect(bus_index,limiter)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = mix_bus
		_configure_web_playback(player,true)
		add_child(player)
		music_players.append(player)
	for index in range(ORDINARY_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.bus = mix_bus
		_configure_web_playback(player)
		add_child(player)
		sfx_players.append(player)
	for index in range(IMPORTANT_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Important%d" % index
		player.bus = mix_bus
		_configure_web_playback(player)
		add_child(player)
		important_players.append(player)
		important_state.append({})
	for index in range(RHYTHM_INPUT_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "OriginalInput%d" % index
		player.bus = mix_bus
		_configure_web_playback(player)
		add_child(player)
		rhythm_sfx_players.append(player)
	judgement_player = AudioStreamPlayer.new()
	judgement_player.name = "JudgementCue"
	judgement_player.bus = mix_bus
	_configure_web_playback(judgement_player)
	add_child(judgement_player)
	for key in JUDGEMENT_PATHS:
		var cue := _load_stream(JUDGEMENT_PATHS[key])
		if cue!=null: judgement_streams[key] = cue
	for key in REDESIGN_GAIN:
		var player := AudioStreamPlayer.new()
		player.name = "Event_"+str(key)
		player.bus = mix_bus
		_configure_web_playback(player)
		add_child(player)
		redesign_players[key] = player
		_load_stream(REDESIGN_ROOT+str(key)+".wav")

func _configure_web_playback(player: AudioStreamPlayer, is_music: bool = false) -> void:
	if not OS.has_feature("web"):
		return
	# Web Sample uses Web Audio for prompt one-shots, with no Godot bus effects.
	# Keep long Ogg loops/crossfades in the streaming mixer to avoid expanding
	# every full-length track into duplicated Web Audio PCM sample buffers.
	# The Web shell owns the common output protection for both playback paths.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM if is_music else AudioServer.PLAYBACK_TYPE_SAMPLE

func _record_web_play_request(player: AudioStreamPlayer, kind: String, key: String, tick: int = -1) -> void:
	if not OS.has_feature("web"):
		return
	# A successful play() request is not evidence of audible output or latency.
	web_play_request_total += 1
	web_play_requests.append({"serial":web_play_request_total,"kind":kind,"key":key,"tick":tick,
		"requested_usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),
		"playback_type":player.playback_type,"playing":player.playing,
		"has_playback":player.has_stream_playback(),"paused":player.stream_paused})
	if web_play_requests.size()>128:
		web_play_requests.pop_front()

func apply_settings(settings: Dictionary) -> void:
	music_volume = clampf(float(settings.get("music_volume",GameConfig.DEFAULT_MUSIC_VOLUME)),0,1)
	sfx_volume = clampf(float(settings.get("sfx_volume",GameConfig.DEFAULT_SFX_VOLUME)),0,1)
	music_muted = bool(settings.get("music_muted",false))
	sfx_muted = bool(settings.get("sfx_muted",false))
	if not enabled:
		return
	if sfx_muted or sfx_volume<=0:
		stop_sfx()
	else:
		for player in sfx_players:
			if player.playing:
				player.volume_db = _sound_volume(float(player.get_meta("sound_gain",1.0)))
		_update_important(0.0)
	_update_music_volume()
	_update_rhythm_volume()
	_update_redesign_volume()
	_update_judgement_volume()

func set_ducked(value: bool) -> void:
	ducked = value

func music(track: String) -> void:
	# Main retains its menu/battle API. Repeated battle requests preserve Fever.
	if track=="battle" and battle_music_fever: track = "battle_fever"
	_switch_music(track)

func _switch_music(track: String) -> void:
	desired_music = track
	var was_battle := active_music in ["battle","battle_fever"]
	rhythm_active = track in ["battle","battle_fever"]
	if not enabled or not MUSIC.has(track):
		return
	if active_music==track and music_players[current_voice].playing:
		return
	if active_music!=track:
		if was_battle!=rhythm_active: stop_sfx()
		if not rhythm_active:
			reset_rhythm()
		music_phrase_duck = 1.0
		music_phrase_duck_remaining = 0.0
	var stream: AudioStream = _load_stream(str(MUSIC[track]),true)
	if stream==null:
		return
	var next_voice := 1-current_voice
	music_players[next_voice].stop()
	music_players[next_voice].stream = stream
	music_players[next_voice].set_meta("music_track",track)
	music_players[next_voice].stream_paused = rhythm_paused
	music_gains[next_voice] = 0.0
	music_targets[next_voice] = 1.0
	music_targets[current_voice] = 0.0
	music_players[next_voice].volume_db = -80
	music_players[next_voice].play()
	_record_web_play_request(music_players[next_voice],"music",track)
	current_voice = next_voice
	active_music = track
	music_starts[track] = int(music_starts.get(track,0))+1

func _set_battle_music_fever(value: bool) -> void:
	var track := "battle_fever" if value else "battle"
	if battle_music_fever==value and active_music==track:
		return
	battle_music_fever = value
	_switch_music(track)

func _sync_battle_music_state(state: Dictionary) -> void:
	# Snapshot state selects the persistent accompaniment only. It never
	# fabricates an entry celebration, response word or other one-shot event.
	if rhythm_active and state.get("fever_active") is bool:
		_set_battle_music_fever(bool(state.fever_active))

func play(key: String, gain: float = 1.0, cooldown_ms: int = 55) -> void:
	if not enabled or sfx_muted or sfx_volume<=0 or not SOUNDS.has(key):
		return
	# Battle uses only the original four drum samples. Keep the UI button audible while
	# suppressing pack hits, reveals, reward tails and all legacy combat layers.
	if rhythm_active and key!="ui_click":
		return
	var now := Time.get_ticks_msec()
	if now-int(last_sound_ms.get(key,-10000))<cooldown_ms:
		return
	var stream: AudioStream = _load_stream(str(SOUNDS[key]))
	if stream==null:
		return
	var sound_gain := maxf(0.0,gain)*float(SOUND_GAIN.get(key,1.0))
	if IMPORTANT_PRIORITY.has(key):
		if _play_important(key,stream,sound_gain):
			last_sound_ms[key] = now
		return
	var same_count := 0
	var free_player: AudioStreamPlayer = null
	for player in sfx_players:
		if not player.playing and free_player==null:
			free_player = player
		elif player.playing and player.stream==stream:
			same_count += 1
	if same_count>=4 or free_player==null:
		return
	last_sound_ms[key] = now
	free_player.stream = stream
	if key=="ui_click":
		free_player.stream_paused = false
	free_player.set_meta("sound_gain",sound_gain)
	free_player.volume_db = _sound_volume(sound_gain)
	free_player.play()
	_record_web_play_request(free_player,"sfx",key)

func _sound_volume(gain: float) -> float:
	return linear_to_db(maxf(.0001,sfx_volume*gain))

func _play_important(key: String, stream: AudioStream, gain: float) -> bool:
	var priority := int(IMPORTANT_PRIORITY[key])
	var free_index := -1
	var lowest_index := -1
	var lowest_priority := 10000
	for index in range(important_players.size()):
		var player := important_players[index]
		var state := important_state[index]
		if not player.playing:
			if free_index<0:
				free_index = index
			continue
		# A second copy cannot retrigger/stack even when callers pass cooldown=0.
		if str(state.get("key",""))==key or int(state.get("priority",0))>=priority:
			return false
		if int(state.get("priority",0))<lowest_priority:
			lowest_priority = int(state.get("priority",0))
			lowest_index = index
	if free_index<0:
		free_index = lowest_index
	if free_index<0:
		return false
	# Release lower accents without chopping an ordinary impact/hit/flip peak.
	# Rapid escalation can recycle only the lower important release tail.
	important_players[free_index].stop()
	for index in range(important_players.size()):
		if index!=free_index and important_players[index].playing:
			var remaining := float(important_state[index].get("release",-1.0))
			important_state[index]["release"] = IMPORTANT_RELEASE_SECONDS if remaining<0 else remaining
	var player := important_players[free_index]
	important_state[free_index] = {"key":key,"priority":priority,"gain":gain,"release":-1.0}
	player.stream = stream
	player.volume_db = _sound_volume(gain)
	player.play()
	_record_web_play_request(player,"important",key)
	return true

func _update_important(delta: float) -> void:
	for index in range(important_players.size()):
		var player := important_players[index]
		if not player.playing:
			if not important_state[index].is_empty():
				important_state[index] = {}
			if player.stream!=null:
				player.stream = null
			continue
		var state := important_state[index]
		var release := float(state.get("release",-1.0))
		var gain := float(state.get("gain",1.0))
		if release>=0:
			release = maxf(0.0,release-delta)
			state["release"] = release
			if release<=0:
				player.stop()
				player.stream = null
				important_state[index] = {}
				continue
			gain *= release/IMPORTANT_RELEASE_SECONDS
		player.volume_db = _sound_volume(gain)

func stop_sfx() -> void:
	_stop_judgement()
	for player: AudioStreamPlayer in redesign_players.values():
		player.stop()
		player.stream = null
	redesign_pending.clear()
	for player in sfx_players+important_players:
		player.stop()
		player.stream = null
	for index in range(important_state.size()):
		important_state[index] = {}
	for player in rhythm_sfx_players:
		player.stop()
		player.stream = null

func reset_rhythm() -> void:
	_stop_judgement()
	judgement_seen.clear()
	judgement_seen_order.clear()
	judgement_counts = {"perfect":0,"miss":0}
	judgement_consumed = 0
	judgement_last_tick = -1
	judgement_batch_tick = -1
	judgement_duck_remaining = 0.0
	battle_music_fever = false
	for player: AudioStreamPlayer in redesign_players.values():
		player.stop()
		player.stream = null
		player.stream_paused = false
	redesign_seen.clear()
	redesign_groups.clear()
	redesign_counts.clear()
	redesign_pending.clear()
	redesign_consumed = 0
	redesign_duck_remaining = 0.0
	redesign_duck_level = 1.0
	redesign_fever_ducked = false
	redesign_merge_history.clear()
	rhythm_clock_tick = -1
	rhythm_beat_count = 0
	rhythm_last_key = ""
	rhythm_last_response_key = ""
	rhythm_paused = false
	rhythm_waiting_for_sync = false
	rhythm_event_counts.clear()
	rhythm_input_counts.clear()
	rhythm_echo_counts.clear()
	rhythm_input_history.clear()
	rhythm_echo_history.clear()
	rhythm_echo_seen.clear()
	rhythm_echo_seen_order.clear()
	rhythm_echo_consumed = 0
	rhythm_echo_prime_tick = -1
	rhythm_voice_steals = 0
	rhythm_voice_cursor = 0
	for player in rhythm_sfx_players:
		player.stop()
		player.stream = null
		player.stream_paused = false
	for player in music_players+sfx_players+important_players:
		player.stream_paused = false

func set_rhythm_paused(value: bool) -> void:
	rhythm_paused = value
	if is_instance_valid(judgement_player): judgement_player.stream_paused = value
	for player in music_players+sfx_players+important_players+rhythm_sfx_players:
		player.stream_paused = value
	for player: AudioStreamPlayer in redesign_players.values():
		player.stream_paused = value

func _stop_judgement() -> void:
	if is_instance_valid(judgement_player):
		judgement_player.stop()
		judgement_player.stream = null
		judgement_player.stream_paused = false
	judgement_kind = ""

func _update_judgement_volume() -> void:
	if not is_instance_valid(judgement_player): return
	var gain := .55 if judgement_duck_remaining>0.0 else 1.0
	judgement_player.volume_db = -80.0 if sfx_muted or sfx_volume<=0 else _sound_volume(gain)

func play_judgement_events(events: Array, tick: int) -> void:
	# Consume real, current Simulation judgements, never UI events or snapshots.
	if not enabled or rhythm_paused or not rhythm_active or tick<=rhythm_echo_prime_tick or tick<judgement_batch_tick: return
	var selected := ""
	for raw: Variant in events:
		if not raw is Dictionary: continue
		var event: Dictionary = raw
		if event.get("type")!="rhythm_judgement" or not event.get("executed",false) is bool or event.get("executed",false)!=true or event.get("tick",-1)!=tick: continue
		var kind := str(event.get("grade",""))
		if kind=="perfect":
			if str(event.get("scope",""))!="phrase": continue
			if event.get("accepted",false)!=true: continue
		elif kind=="miss":
			if str(event.get("reason","")) not in ["timeout","too_fast","handoff_timeout"]: continue
		else: continue
		var event_id := str(event.get("event_id",""))
		if event_id.is_empty(): continue
		var token := str(event.get("run_id",""))+":"+event_id
		if judgement_seen.has(token): continue
		judgement_seen[token] = true
		judgement_seen_order.append(token)
		if judgement_seen_order.size()>JUDGEMENT_SEEN_LIMIT:
			judgement_seen.erase(judgement_seen_order.pop_front())
		judgement_consumed += 1 # Muted cues are consumed, not queued for unmute.
		if selected!="miss": selected = kind
	if selected.is_empty(): return
	judgement_batch_tick = tick
	if sfx_muted or sfx_volume<=0 or not judgement_streams.has(selected): return
	# A single voice bounds consecutive Perfect tails and lets Miss replace them.
	judgement_player.stop()
	judgement_player.stream = judgement_streams[selected]
	judgement_player.stream_paused = false
	judgement_kind = selected
	judgement_last_tick = tick
	judgement_counts[selected] += 1
	_update_judgement_volume()
	judgement_player.play()
	_record_web_play_request(judgement_player,"judgement",selected,tick)

func judgement_state() -> Dictionary:
	var assets: Dictionary = {}
	for key in JUDGEMENT_PATHS:
		var cue: AudioStream = judgement_streams.get(key)
		assets[key] = {"path":JUDGEMENT_PATHS[key],"loaded":cue!=null,"length_seconds":cue.get_length() if cue!=null else 0.0}
	return {"assets":assets,"counts":judgement_counts.duplicate(),"consumed":judgement_consumed,"active_kind":judgement_kind,"playing":judgement_player.playing if is_instance_valid(judgement_player) else false,"paused":judgement_player.stream_paused if is_instance_valid(judgement_player) else false,"volume_db":judgement_player.volume_db if is_instance_valid(judgement_player) else -80.0,"voice_count":1 if is_instance_valid(judgement_player) else 0,"last_tick":judgement_last_tick,"seen_count":judgement_seen.size(),"duck_remaining":judgement_duck_remaining}

## Only Main's current simulation event batch may authorize these quiet layers.
## Aggregation changes playback only; reward/damage events remain untouched.
func play_redesign_events(events: Array, tick: int) -> void:
	if rhythm_paused or not rhythm_active or tick<=rhythm_echo_prime_tick:
		return
	for pending in redesign_pending.duplicate():
		if int(pending.tick)<=tick:
			redesign_pending.erase(pending)
			_play_redesign(str(pending.key),float(pending.get("pitch",1.0)))
	var groups: Dictionary = {}
	var merge_grades: Dictionary = {}
	for raw: Variant in events:
		if not raw is Dictionary:
			continue
		var event: Dictionary = raw
		if event.get("executed",false)!=true or event.get("tick",-1)!=tick:
			continue
		var token := str(event.get("event_id",""))
		if token.is_empty() or redesign_seen.has(token):
			continue
		redesign_seen[token] = true # Muted events are consumed, never replayed later.
		redesign_consumed += 1
		var kind := str(event.get("type",""))
		if kind=="fever_enter":
			_set_battle_music_fever(true)
			groups["fever_enter"] = true
		elif kind=="preparation_reset":
			_set_battle_music_fever(false)
		elif kind=="claim":
			groups["pack_break"] = true
			var reward: Dictionary = event.get("reward",{})
			if int(reward.get("coins",0))>0:
				groups["coins"] = true
		elif kind=="spawn":
			groups["spawn"] = true
		elif kind=="skill_event" and not bool(event.get("empty",false)):
			match str(event.get("kind","")):
				"pull": groups["gather"] = true
				"expand":
					if not bool(event.get("at_cap",false)): groups["expand"] = true
				"merge":
					for group: Dictionary in event.get("groups",[]):
						var grade := int(group.get("from_grade",-1))
						if grade>=0 and grade<4:
							merge_grades[grade] = true
					if not merge_grades.is_empty(): groups["merge"] = true
	for key: String in groups:
		var group_token := "%s:%d" % [key,tick]
		if redesign_groups.has(group_token):
			continue
		redesign_groups[group_token] = true
		if key=="fever_enter":
			# Preserve all 2.189s, offset onset 8 ticks past the fourth echo head.
			redesign_fever_ducked = false
			if enabled and not sfx_muted and sfx_volume>0.0:
				redesign_pending.append({"key":key,"tick":tick+8})
		elif key=="merge":
			var grades := merge_grades.keys()
			grades.sort()
			for index in range(grades.size()):
				var pitch := 1.0+.10*int(grades[index])
				if index==0:
					_play_redesign(key,pitch)
				elif enabled and not sfx_muted and sfx_volume>0.0:
					redesign_pending.append({"key":key,"tick":tick+index*8,"pitch":pitch})
		else:
			_play_redesign(key)

func _play_redesign(key: String, pitch: float = 1.0) -> void:
	if not enabled or rhythm_paused or sfx_muted or sfx_volume<=0 or not redesign_players.has(key):
		return
	var stream := _load_stream(REDESIGN_ROOT+key+".wav")
	if stream==null:
		return
	var player: AudioStreamPlayer = redesign_players[key]
	# At most one voice per material, never proportional to targets or coins.
	if player.playing and key!="merge":
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.stream_paused = false
	_update_redesign_volume()
	player.play()
	_record_web_play_request(player,"event",key,rhythm_clock_tick)
	redesign_counts[key] = int(redesign_counts.get(key,0))+1
	if key=="merge":
		redesign_merge_history.append({"pitch":pitch})

func _duck_redesign(level: float, seconds: float, from_input: bool = false) -> void:
	redesign_duck_level = minf(redesign_duck_level,level)
	redesign_duck_remaining = maxf(redesign_duck_remaining,seconds)
	if from_input:
		redesign_fever_ducked = true
	_update_redesign_volume()

func _update_redesign_volume() -> void:
	for key: String in redesign_players:
		var player: AudioStreamPlayer = redesign_players[key]
		var attenuation := redesign_duck_level
		if key=="fever_enter" and redesign_fever_ducked:
			attenuation = minf(attenuation,.18)
		var level := sfx_volume*float(REDESIGN_GAIN[key])*attenuation
		player.volume_db = -80.0 if sfx_muted or level<=0.0 else linear_to_db(level)

func _redesign_status() -> Dictionary:
	var voices: Dictionary = {}
	for key: String in redesign_players:
		var player: AudioStreamPlayer = redesign_players[key]
		voices[key] = {"playing":player.playing,"paused":player.stream_paused,"volume_db":player.volume_db,"position_seconds":player.get_playback_position()}
	return {"played_counts":redesign_counts.duplicate(),"consumed_events":redesign_consumed,"seen_events":redesign_seen.size(),"groups":redesign_groups.size(),"pending":redesign_pending.duplicate(true),"duck_remaining":redesign_duck_remaining,"duck_level":redesign_duck_level,"fever_ducked":redesign_fever_ducked,"merge_history":redesign_merge_history.duplicate(true),"gains":REDESIGN_GAIN.duplicate(),"voices":voices,"extra_burst_impact":false}

func rhythm_count_in(_beat: int) -> void:
	# Retired compatibility hook: waiting never creates a drum voice.
	pass

func prime_rhythm(state: Dictionary, tick: int) -> void:
	rhythm_clock_tick = tick
	rhythm_echo_prime_tick = tick
	_sync_battle_music_state(state)
	# Snapshot recovery never plays a response that was already committed.
	var raw_event: Variant = state.get("response_event",{})
	if raw_event is Dictionary:
		var token := _echo_event_token(raw_event)
		if not token.is_empty() and raw_event.tick<=tick:
			_claim_echo_token(token)

func sync_rhythm(state: Dictionary, tick: int) -> void:
	if not enabled or not rhythm_active or rhythm_paused:
		return
	rhythm_clock_tick = tick
	if tick<=rhythm_echo_prime_tick:
		return
	_sync_battle_music_state(state)
	var raw_event: Variant = state.get("response_event",{})
	if not raw_event is Dictionary or raw_event.get("tick",-1)!=tick:
		return
	var event: Dictionary = raw_event
	var token := _echo_event_token(event)
	if token.is_empty() or rhythm_echo_seen.has(token):
		return
	# Consume even muted/missing voices. Unmuting or importing a sample later
	# must not replay a stale committed response event.
	_claim_echo_token(token)
	rhythm_echo_consumed += 1
	if _rhythm_voice(str(event.key),false,ECHO_GAIN,tick,"echo"):
		rhythm_last_response_key = str(event.key)
		rhythm_echo_history.append({"key":str(event.key),"tick":tick,"serial":int(event.serial),
			"command_serial":int(event.command_serial),"beat":int(event.beat),"preset_id":str(event.preset_id),"token":token})
		if rhythm_echo_history.size()>128:
			rhythm_echo_history.pop_front()

func _echo_event_token(event: Dictionary) -> String:
	if not event.has_all(["type","serial","command_serial","preset_id","mode","key","beat","tick","executed"]):
		return ""
	if str(event.type)!="rhythm_response" or not event.executed is bool or not bool(event.executed):
		return ""
	if event.has("phase") and str(event.phase)!="respond":
		return ""
	if str(event.key) not in RHYTHM_KEYS or str(event.mode)!=str(event.preset_id) or str(event.preset_id).is_empty():
		return ""
	if not (event.serial is int or event.serial is float) or not (event.beat is int or event.beat is float) or not (event.tick is int or event.tick is float):
		return ""
	if not is_finite(float(event.serial)) or not is_finite(float(event.beat)) or not is_finite(float(event.tick)):
		return ""
	var serial := int(event.serial)
	var beat := int(event.beat)
	if serial<=0 or event.serial!=serial or event.command_serial!=serial or beat<0 or beat>3 or event.beat!=beat or event.tick<0 or event.tick!=int(event.tick):
		return ""
	return "%d:%d" % [serial,beat]

func _claim_echo_token(token: String) -> void:
	if rhythm_echo_seen.has(token):
		return
	rhythm_echo_seen[token] = true
	rhythm_echo_seen_order.append(token)
	if rhythm_echo_seen_order.size()>256:
		rhythm_echo_seen.erase(rhythm_echo_seen_order.pop_front())

func finish_rhythm_tail(_state: Dictionary, _tick: int) -> bool:
	# Event echoes have no composed-clip or terminal-result delay.
	return false

func rhythm_input(key: String, judgement: Dictionary) -> void:
	if not enabled or rhythm_paused or not rhythm_active or key not in RHYTHM_KEYS:
		return
	if judgement.has("accepted") and not bool(judgement.accepted):
		return
	rhythm_last_key = key
	_duck_redesign(.18,.35,true)
	_duck_music(.55,.28)
	_rhythm_voice(key,false,INPUT_GAIN,int(judgement.get("tick",rhythm_clock_tick)))

func _rhythm_voice(key: String, _musical: bool, gain: float, input_tick: int = -1, stream_kind: String = "input") -> bool:
	var streams: Dictionary = rhythm_echo_streams if stream_kind=="echo" else rhythm_streams
	if not enabled or rhythm_paused or key not in RHYTHM_KEYS or not streams.has(key) or sfx_muted or sfx_volume<=0.0:
		return false
	if stream_kind=="echo":
		_duck_redesign(.30,.22)
		_duck_music(.60,.18)
	var selected: AudioStreamPlayer = null
	for player in rhythm_sfx_players:
		if not player.playing:
			selected = player
			break
	if selected==null:
		selected = rhythm_sfx_players[rhythm_voice_cursor]
		rhythm_voice_cursor = (rhythm_voice_cursor+1)%rhythm_sfx_players.size()
		rhythm_voice_steals += 1
	judgement_duck_remaining = maxf(judgement_duck_remaining,.18)
	_update_judgement_volume()
	selected.stop()
	selected.stream = streams[key]
	selected.stream_paused = false
	selected.set_meta("rhythm_gain",gain)
	selected.set_meta("rhythm_key",key)
	selected.set_meta("stream_kind",stream_kind)
	selected.volume_db = linear_to_db(maxf(.0001,sfx_volume*gain))
	selected.play()
	_record_web_play_request(selected,stream_kind,key,input_tick)
	rhythm_event_counts[key] = int(rhythm_event_counts.get(key,0))+1
	if stream_kind=="echo":
		rhythm_echo_counts[key] = int(rhythm_echo_counts.get(key,0))+1
	else:
		rhythm_input_counts[key] = int(rhythm_input_counts.get(key,0))+1
		rhythm_input_history.append({"key":key,"input_tick":input_tick,"clock_tick":rhythm_clock_tick})
		if rhythm_input_history.size()>64:
			rhythm_input_history.pop_front()
	return true

func _update_rhythm_volume() -> void:
	for player in rhythm_sfx_players:
		var level := sfx_volume*float(player.get_meta("rhythm_gain",1.0))
		player.volume_db = -80.0 if sfx_muted or level<=0 else linear_to_db(level)

func _load_stream(path: String, looped: bool = false) -> AudioStream:
	if not enabled:
		return null
	if stream_cache.has(path):
		return stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream==null:
		return null
	if stream is AudioStreamOggVorbis:
		stream.loop = looped
	elif stream is AudioStreamWAV:
		if looped:
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length()*stream.mix_rate))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	stream_cache[path] = stream
	if OS.has_feature("web") and not looped and not AudioServer.is_stream_registered_as_sample(stream):
		# Official Web guidance: perform synchronous sample decoding at load time,
		# rather than making the first drum hit pay the registration cost.
		AudioServer.register_stream_as_sample(stream)
	return stream

func _process(delta: float) -> void:
	if not rhythm_paused:
		judgement_duck_remaining = maxf(0.0,judgement_duck_remaining-delta)
	_update_judgement_volume()
	if not rhythm_paused:
		music_phrase_duck_remaining = maxf(0.0,music_phrase_duck_remaining-delta)
		if music_phrase_duck_remaining<=0.0:
			music_phrase_duck = move_toward(music_phrase_duck,1.0,delta*2.5)
		redesign_duck_remaining = maxf(0.0,redesign_duck_remaining-delta)
		if redesign_duck_remaining<=0.0:
			redesign_duck_level = move_toward(redesign_duck_level,1.0,delta*3.0)
	_update_redesign_volume()
	_update_important(delta)
	if not rhythm_paused:
		duck_gain = move_toward(duck_gain,.22 if ducked else 1.0,delta*2.6)
	retry_timer += delta
	if retry_timer>=2.0:
		retry_timer = 0.0
		if active_music!=desired_music:
			music(desired_music)
	for index in range(2):
		if not rhythm_paused:
			music_gains[index] = move_toward(music_gains[index],music_targets[index],delta/1.1)
		if music_targets[index]==0 and music_gains[index]<=.0001 and music_players[index].playing:
			music_players[index].stop()
			music_players[index].stream = null
	_update_music_volume()
	_update_rhythm_volume()

func _update_music_volume() -> void:
	for index in range(music_players.size()):
		var track := str(music_players[index].get_meta("music_track","menu"))
		var boost := BGM_BOOST_DB + (BATTLE_BGM_EXTRA_DB if track in ["battle","battle_fever"] else 0.0) + float(BGM_TRACK_ADJUST_DB.get(track,0.0))
		var volume := music_volume*music_gains[index]*duck_gain*float(MUSIC_GAIN.get(track,.20))*db_to_linear(boost)*music_phrase_duck
		music_players[index].volume_db = -80.0 if music_muted or volume<=.0001 else linear_to_db(volume)

func _duck_music(level: float, seconds: float) -> void:
	music_phrase_duck = minf(music_phrase_duck,level)
	music_phrase_duck_remaining = maxf(music_phrase_duck_remaining,seconds)
	_update_music_volume()

func _bgm_status() -> Dictionary:
	var player: AudioStreamPlayer = music_players[current_voice] if not music_players.is_empty() else null
	return {"enabled":enabled and MUSIC.has(active_music),"state":"fever" if active_music=="battle_fever" else ("normal" if active_music=="battle" else "menu"),"source":"community_patapon3_instrumental","path":str(MUSIC.get(active_music,"")),"track":active_music,"playing":player.playing if player!=null else false,"paused":player.stream_paused if player!=null else false,"starts":int(music_starts.get(active_music,0)),"starts_by_track":music_starts.duplicate(),"position_seconds":player.get_playback_position() if player!=null else 0.0,"looped":player!=null and player.stream is AudioStreamOggVorbis and player.stream.loop,"volume_db":player.volume_db if player!=null else -80.0,"base_gain":float(MUSIC_GAIN.get(active_music,0.0)),"phrase_duck":music_phrase_duck,"phrase_duck_remaining":music_phrase_duck_remaining,"timing_authority":"simulation_120bpm_independent_of_music"}

func get_status() -> Dictionary:
	var count := 0
	for player in sfx_players:
		if player.playing:
			count += 1
	var important: Array = []
	for index in range(important_players.size()):
		if important_players[index].playing:
			var state := important_state[index]
			important.append({"key":str(state.get("key","")),"releasing":float(state.get("release",-1.0))>=0,"volume_db":important_players[index].volume_db})
	var voices: Array = []
	for player in music_players:
		voices.append({"playing":player.playing,"paused":player.stream_paused,"track":str(player.get_meta("music_track","")),"path":str(MUSIC.get(str(player.get_meta("music_track","")),"")),"position_seconds":player.get_playback_position(),"volume_db":player.volume_db,"looped":player.stream is AudioStreamOggVorbis and player.stream.loop})
	return {"enabled":enabled,"track":active_music,"desired_track":desired_music,"ducked":ducked,"sfx_voices":count+important.size(),"ordinary_sfx_voices":count,"important_sfx_voices":important.size(),"important_players":important,"mix_ceiling_db":MIX_CEILING_DB,"cached_assets":stream_cache.size(),"music_volume":music_volume,"sfx_volume":sfx_volume,"music_muted":music_muted,"sfx_muted":sfx_muted,"music_players":voices,"rhythm":_rhythm_status(),"web_audio":web_audio_state()}

func web_audio_state() -> Dictionary:
	var is_web := OS.has_feature("web")
	var voices: Array[Dictionary] = []
	var registered_samples := 0
	if is_web:
		for stream: AudioStream in stream_cache.values():
			if AudioServer.is_stream_registered_as_sample(stream):
				registered_samples += 1
		for child: Node in get_children():
			if not child is AudioStreamPlayer:
				continue
			var player := child as AudioStreamPlayer
			voices.append({"name":str(player.name),"playback_type":player.playback_type,
				"path":player.stream.resource_path if player.stream!=null else "",
				"playing":player.playing,"has_playback":player.has_stream_playback(),
				"paused":player.stream_paused,"position_seconds":player.get_playback_position(),
				"volume_db":player.volume_db,"pitch_scale":player.pitch_scale})
	return {"enabled":is_web,"policy":"stream_music_sample_oneshots" if is_web else "native_unchanged",
		"sample_bus_effects_supported":false if is_web else true,
		"sample_output_protection":"web_shell" if is_web else "godot_hard_limiter",
		"output_latency_seconds":AudioServer.get_output_latency() if enabled else 0.0,
		"timing_authority":"simulation_120bpm","audible_latency_measured":false,
		"registered_samples":registered_samples,"voices":voices,"play_request_total":web_play_request_total,
		"play_requests":web_play_requests.duplicate(true)}

func _rhythm_status() -> Dictionary:
	var sampled := 0
	var sampled_echoes := 0
	for asset: Dictionary in rhythm_assets.values():
		if str(asset.get("source",""))=="sample": sampled += 1
	for asset: Dictionary in rhythm_echo_assets.values():
		if str(asset.get("source",""))=="sample": sampled_echoes += 1
	var voices: Array = []
	for player in rhythm_sfx_players:
		if player.has_stream_playback():
			voices.append({"key":str(player.get_meta("rhythm_key","")),"stream_kind":str(player.get_meta("stream_kind","input")),"playing":player.playing,"paused":player.stream_paused,
				"position_seconds":player.get_playback_position(),"volume_db":player.volume_db})
	return {"active":rhythm_active,"paused":rhythm_paused,"clock_tick":rhythm_clock_tick,"beats":rhythm_echo_consumed,
		"last_key":rhythm_last_key,"last_response_key":rhythm_last_response_key,"waiting_for_sync":false,
		"source":"relative_cadence_call_response" if sampled==4 and sampled_echoes==4 else "missing_cadence_samples",
		"palette":"relative_cadence_call_response","palette_mode":"relative_cadence_call_response","no_auto_response":false,
		"reference_bpm":REFERENCE_BPM,"bpm":REFERENCE_BPM,"reference_only":false,"echo_step_ticks":ECHO_STEP_TICKS,
		"input_interval_gate_seconds":0.0,"input_timing_authority":"simulation","echo_event_authority":"current_executed_response_event",
		"no_full_response_clip":true,"no_auto_idle_sounds":true,"input_gain":INPUT_GAIN,"echo_gain":ECHO_GAIN,
		"instruments":rhythm_streams.size(),"sampled_instruments":sampled,"fallback_instruments":0,
		"missing_instruments":RHYTHM_KEYS.size()-sampled,"battle_legacy_sfx_enabled":false,
		"loaded_echoes":rhythm_echo_streams.size(),"echo_sampled_instruments":sampled_echoes,"echo_fallback_instruments":0,
		"missing_echoes":RHYTHM_KEYS.size()-sampled_echoes,"echo_assets":rhythm_echo_assets.duplicate(true),
		"assets":rhythm_assets.duplicate(true),"played_counts":rhythm_event_counts.duplicate(),
		"input_counts":rhythm_input_counts.duplicate(),"echo_counts":rhythm_echo_counts.duplicate(),
		"input_history":rhythm_input_history.duplicate(true),"echo_history":rhythm_echo_history.duplicate(true),"voice_players":voices,"input_players":voices,
		"echo_consumed_events":rhythm_echo_consumed,"echo_seen_tokens":rhythm_echo_seen.size(),"echo_prime_tick":rhythm_echo_prime_tick,
		"voice_limit":RHYTHM_INPUT_VOICES,"voice_steals":rhythm_voice_steals,
		"bgm":_bgm_status(),
		"judgement":judgement_state(),"redesign":_redesign_status(),"response_music":_response_music_status()}

func _response_music_status() -> Dictionary:
	return {"mode":"no_full_phrase_music","enabled":false,"source":"disabled","path":"","reason":"individual_event_echoes_only",
		"loaded_clips":0,"assets":{},"continuous_bgm":false,"playing":false,"paused":false,"looped":false,
		"starts":0,"resumes":0,"corrections":0,"position_seconds":0.0,"expected_position_seconds":0.0,
		"token":"","preset_id":"","first_tick":-1,"stop_tick":-1,"needs_sync":false,
		"terminal_tail_active":false,"terminal_tail_pending_music":"","terminal_tail_remaining_seconds":0.0}

func _exit_tree() -> void:
	reset_rhythm()
	stop_sfx()
	for player in music_players:
		player.stop()
		player.stream = null
	rhythm_streams.clear()
	rhythm_assets.clear()
	rhythm_echo_streams.clear()
	rhythm_echo_assets.clear()
	stream_cache.clear()
	last_sound_ms.clear()
	var bus_index := AudioServer.get_bus_index(mix_bus)
	if not mix_bus.is_empty() and bus_index>0:
		AudioServer.remove_bus(bus_index)
	mix_bus = &""
