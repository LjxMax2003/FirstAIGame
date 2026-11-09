extends Node

# =====================================================================
# 全局音频服务（BGM + 音效）。autoload 名 `Audio`。
#
# 【为什么是一个 autoload，而不是每个场景各挂一个播放器】
# BGM 要跨场景（主菜单 → 守夜 → 回主菜单）连续存在，切场景时不该断掉重来；
# 音效则必须**集中限流** —— 同屏上百只忘影被清掉时，如果每次击杀都真的播一声，
# 一秒钟会叠出几十个声音（响度爆表、还把音频线程占满）。
# 所以所有播放请求都走这里：谁想发声只报"是什么声音"，播不播、播多大声由这里决定。
#
# 【每类音效的 gap / voices 是怎么定的】
# 数值不是随手拍的，按"玩家实际能分辨"来：
#   击杀 die      —— 满屏击杀时每秒十几次，gap 0.09s（约 11 次/秒）＋ 最多 3 个并行，
#                    听感是"一片倒下的杂响"，而不会糊成一条持续噪音。
#   灯花 gem      —— 铜铃一吸可能一帧收几十颗，gap 0.06s ＋ 2 并行就够形成"叮叮"的流。
#   受击 hurt     —— 无敌帧本身就是 0.5s，gap 0.3s 保证一次挨打只响一下。
#   升级 levelup  —— 一次升级只该有一声；连升多级时由 UI 逐张卡播。
#   Boss boss_spawn —— 全局事件，gap 0.6s 防止小 Boss 与真 Boss 同帧叠两层。
#   铜锣 gong     —— 1.8s 一敲，gap 0.2s 只是防止多把铜锣同帧。
#
# 【音量为什么分三层】
#   ① 单个音效的 gain：素材本身响度差异很大（Boss 登场 RMS -9 dB，击杀声 -34 dB），
#      不在这里补正，玩家会听到"Boss 震耳、击杀像没播"。
#   ② 总线音量：玩家在设置里调的音乐/音效，走 AudioServer 的 Music / SFX 总线。
#   ③ 暂停闪避：整树暂停（升级三选一 / 暂停菜单 / 结算）时把 Music 压低 10 dB，
#      玩家在看卡时不会被 BGM 盖住思考。
# =====================================================================

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
## BGM 交叉淡入时长。0.75s 比一次场景切换的过场稍长，听感是"换曲"而不是"断掉"
const FADE := 0.75
## 暂停时音乐压低多少 dB
const DUCK_DB := -10.0
## 音效播放器数量。按上面的并行上限粗算，10 个足够覆盖所有音效同时发生
## v9：加到 14。新增的 hit_aoe(3) + hit_single(2) 会与原有的
## enemy_die(3) / gem(2) 同时抢声部；10 个会在后期"人一多就没声音"，
## 而且那种丢失是静默的（_take_voice 拿不到播放器就 return，不报错）。
const VOICES := 14

## BGM 表：路径 + 基准音量。
## main_menu 素材 RMS 只有 -30 dB（比战斗曲轻 10 dB），不补正的话主菜单会像没开音乐。
const BGM_DEF: Dictionary = {
	"menu": {"file": "res://assets/audio/bgm/main_menu.wav", "gain": 8.0},
	"combat": {"file": "res://assets/audio/bgm/combat.wav", "gain": 0.0},
}

## 音效表：路径 + 基准音量 + 最小间隔（秒）+ 同类并行上限 + 音高抖动
const SFX_DEF: Dictionary = {
	"gem": {
		"file": "res://assets/audio/sfx/player/gem.wav",
		"gain": 9.0, "gap": 0.06, "voices": 2, "pitch": 0.10,
	},
	"hurt": {
		"file": "res://assets/audio/sfx/player/hurt.wav",
		"gain": 0.0, "gap": 0.30, "voices": 1, "pitch": 0.0,
	},
	"levelup": {
		"file": "res://assets/audio/sfx/player/levelup.wav",
		"gain": 3.0, "gap": 0.30, "voices": 1, "pitch": 0.0,
	},
	"enemy_die": {
		"file": "res://assets/audio/sfx/enemy/die.wav",
		"gain": 10.0, "gap": 0.09, "voices": 3, "pitch": 0.08,
	},
	"boss_spawn": {
		"file": "res://assets/audio/sfx/event/boss_spawn.wav",
		"gain": -6.0, "gap": 0.60, "voices": 1, "pitch": 0.0,
	},
	"gong": {
		"file": "res://assets/audio/sfx/weapon/gong.wav",
		"gain": 5.0, "gap": 0.20, "voices": 1, "pitch": 0.0,
	},
	# ---------------------------------------------------------------- v9 A4：命中音
	# 此前 9 把武器共用 "enemy_die"，打中时**一声不响** —— 四条反馈通道里唯一全空的一条。
	# 现在按"锐/钝"分两档，由 Enemy.take_damage 依 WeaponDB.dmg_kind 选择。
	# ⚠️ gain 取负：命中每秒几十次，必须明显低于击杀音（enemy_die +10）。
	#    命中音要是和击杀一样响，玩家就分不出"打中了"和"打死了"，反馈反而变糊。
	# gap 0.040/0.045 都比 PresentationFX.QUIET_WINDOW(0.055) 短一点：
	# 允许多把武器同时响（用 voices 收口），但同一把不会连成一串。
	"hit_aoe": {
		"file": "res://assets/audio/sfx/weapon/hit_aoe.wav",
		"gain": 4.0, "gap": 0.040, "voices": 3, "pitch": 0.12,
	},
	"hit_single": {
		"file": "res://assets/audio/sfx/weapon/hit_single.wav",
		"gain": 2.0, "gap": 0.045, "voices": 2, "pitch": 0.09,
	},
	# ---------------------------------------------------------------- v9 F1：UI 音
	# 全工程按钮此前是**完全静音**的（ui/ 目录是空的）。三档语义：
	# click 无音高抖动（界面反馈不需要生机），confirm 稍响（这是"我决定好了"），
	# back 压低（退回去不该比往前走更响亮）。
	"ui_click": {
		"file": "res://assets/audio/sfx/ui/ui_click.wav",
		"gain": 0.0, "gap": 0.02, "voices": 2, "pitch": 0.0,
	},
	"ui_confirm": {
		"file": "res://assets/audio/sfx/ui/ui_confirm.wav",
		"gain": 2.0, "gap": 0.05, "voices": 1, "pitch": 0.0,
	},
	"ui_back": {
		"file": "res://assets/audio/sfx/ui/ui_back.wav",
		"gain": -1.0, "gap": 0.05, "voices": 1, "pitch": 0.0,
	},
}

var _bgm: Array[AudioStreamPlayer] = []
var _bgm_index := 0
var _bgm_id := ""
var _bgm_tween: Tween = null
var _sfx: Array[AudioStreamPlayer] = []
var _voice_i := 0
var _last_ms: Dictionary = {}
var _streams: Dictionary = {}
var _music_bus := -1
var _sfx_bus := -1
var _ducked := false

func _ready() -> void:
	# 暂停时也要继续处理：音乐闪避与 finished 兜底都依赖它
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "BGM%d" % i
		p.bus = BUS_MUSIC
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_bgm.append(p)
		p.finished.connect(_on_bgm_finished.bind(i))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.bus = BUS_SFX
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx.append(p)
	apply_volumes()

# ---------------------------------------------------------------- 总线
## 运行时补齐 Music / SFX 两条总线（工程没有 default_bus_layout.tres）。
## 用名字取，不缓存下标给外部 —— 总线一旦重排，缓存的下标会指向别的总线。
func _ensure_buses() -> void:
	_music_bus = AudioServer.get_bus_index(BUS_MUSIC)
	if _music_bus < 0:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, BUS_MUSIC)
		AudioServer.set_bus_send(_music_bus, "Master")
	_sfx_bus = AudioServer.get_bus_index(BUS_SFX)
	if _sfx_bus < 0:
		AudioServer.add_bus()
		_sfx_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus, BUS_SFX)
		AudioServer.set_bus_send(_sfx_bus, "Master")
	_add_limiter()

## Master 上加一个硬限幅器：满屏击杀 + Boss 登场同帧时峰值必然叠高，
## 不压的话会把耳朵炸一下。ceiling -1 dB 是留给人耳的安全余量。
func _add_limiter() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if master < 0:
		return
	for i in AudioServer.get_bus_effect_count(master):
		var e: AudioEffect = AudioServer.get_bus_effect(master, i)
		if e is AudioEffectHardLimiter or e is AudioEffectLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(master, lim)

## 把 Settings 里的两个音量推到总线上。设置面板改完、启动时、以及默认值重置时都调它。
func apply_volumes() -> void:
	_apply_music_bus()
	if _sfx_bus >= 0:
		var v: float = clampf(Settings.sfx_volume, 0.0, 1.0)
		AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(v, 0.001)))
		AudioServer.set_bus_mute(_sfx_bus, v < 0.02)

func _apply_music_bus() -> void:
	if _music_bus < 0:
		return
	var v: float = clampf(Settings.music_volume, 0.0, 1.0)
	var db: float = linear_to_db(maxf(v, 0.001))
	if _ducked:
		db += DUCK_DB
	AudioServer.set_bus_volume_db(_music_bus, db)
	AudioServer.set_bus_mute(_music_bus, v < 0.02)

func _process(_delta: float) -> void:
	var want: bool = get_tree().paused
	if want != _ducked:
		_ducked = want
		_apply_music_bus()

# ---------------------------------------------------------------- BGM
func play_bgm(id: String) -> void:
	if not BGM_DEF.has(id):
		push_warning("Audio: 未知 BGM %s" % id)
		return
	if _bgm_id == id and _bgm_playing():
		return
	var s: AudioStream = _load(String((BGM_DEF[id] as Dictionary)["file"]))
	if s == null:
		return
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	var next: AudioStreamPlayer = _bgm[_bgm_index ^ 1]
	var old: AudioStreamPlayer = _bgm[_bgm_index]
	next.stream = s
	next.set_meta("id", id)
	next.volume_db = -80.0
	next.pitch_scale = 1.0
	next.play()
	_bgm_index ^= 1
	_bgm_id = id
	var gain: float = float((BGM_DEF[id] as Dictionary).get("gain", 0.0))
	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	_bgm_tween.tween_property(next, "volume_db", gain, FADE)
	if old.playing:
		_bgm_tween.tween_property(old, "volume_db", -80.0, FADE)
		_bgm_tween.chain().tween_callback(old.stop)

func stop_bgm() -> void:
	_bgm_id = ""
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	for p in _bgm:
		if p.playing:
			_bgm_tween.tween_property(p, "volume_db", -80.0, FADE)
	_bgm_tween.chain().tween_callback(func() -> void:
		for p in _bgm:
			p.stop())

func _bgm_playing() -> bool:
	for p in _bgm:
		if p.playing:
			return true
	return false

## 兜底：素材没烘进循环时用 finished 重播。
## 被交叉淡出的旧曲不重播 —— 它的 meta id 已经不是当前曲目。
func _on_bgm_finished(idx: int) -> void:
	var p: AudioStreamPlayer = _bgm[idx]
	if p.stream == null:
		return
	if String(p.get_meta("id", "")) != _bgm_id:
		return
	p.play()

# ---------------------------------------------------------------- 音效
## 唯一的发声入口。extra_db 用于同一素材的强弱变体（比如破盾时的闷响）。
func play_sfx(id: String, extra_db: float = 0.0) -> void:
	if not SFX_DEF.has(id):
		push_warning("Audio: 未知音效 %s" % id)
		return
	var def: Dictionary = SFX_DEF[id]
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_ms.get(id, -999.0)) < float(def.get("gap", 0.0)):
		return
	if _count_voices(id) >= int(def.get("voices", 1)):
		return
	var s: AudioStream = _load(String(def["file"]))
	if s == null:
		return
	var p: AudioStreamPlayer = _take_voice()
	if p == null:
		return
	var pitch: float = float(def.get("pitch", 0.0))
	p.stream = s
	p.volume_db = float(def.get("gain", 0.0)) + extra_db
	p.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	p.set_meta("key", id)
	p.set_meta("start_ms", Time.get_ticks_msec())
	p.play()
	_last_ms[id] = now

func _count_voices(id: String) -> int:
	var n := 0
	for p in _sfx:
		if p.playing and String(p.get_meta("key", "")) == id:
			n += 1
	return n

## 优先拿空闲的；全都在响就抢最早那个（长音效不该把短音效永远堵在外面）
func _take_voice() -> AudioStreamPlayer:
	for p in _sfx:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer = _sfx[0]
	var oldest_ms: int = int(oldest.get_meta("start_ms", 0))
	for p in _sfx:
		var t: int = int(p.get_meta("start_ms", 0))
		if t < oldest_ms:
			oldest_ms = t
			oldest = p
	if oldest.playing:
		oldest.stop()
	return oldest

func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	if not ResourceLoader.exists(path):
		push_warning("Audio: 找不到音频资源 %s（还没导入？）" % path)
		return null
	var s: AudioStream = load(path) as AudioStream
	if s != null:
		_streams[path] = s
	return s
