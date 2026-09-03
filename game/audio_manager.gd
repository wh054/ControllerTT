## 游戏音效管理器。
##
## 管理多声道射击音效池、命中与击毁反馈音效，
## 确保 12 发/秒高射速下声音不吞音、不卡顿。
class_name AudioManager
extends Node

const SFX_M4 := preload("res://assets/audio/sfx_m4_fire.wav")
const SFX_DEAGLE := preload("res://assets/audio/sfx_deagle_fire.wav")
const SFX_HIT := preload("res://assets/audio/sfx_hit.wav")
const SFX_KILL := preload("res://assets/audio/sfx_kill.wav")
const SFX_ADS := preload("res://assets/audio/sfx_ads.wav")

const POOL_SIZE := 12

var _fire_players: Array[AudioStreamPlayer] = []
var _fire_idx := 0

var _hit_player: AudioStreamPlayer
var _kill_player: AudioStreamPlayer
var _ads_player: AudioStreamPlayer

var volume: float = 0.85
var enabled: bool = true


func _ready() -> void:
	# 构建开火音效池，避免全自动扫射时截断上一发的尾音
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_fire_players.append(p)

	_hit_player = AudioStreamPlayer.new()
	_hit_player.stream = SFX_HIT
	_hit_player.bus = "Master"
	add_child(_hit_player)

	_kill_player = AudioStreamPlayer.new()
	_kill_player.stream = SFX_KILL
	_kill_player.bus = "Master"
	add_child(_kill_player)

	_ads_player = AudioStreamPlayer.new()
	_ads_player.stream = SFX_ADS
	_ads_player.bus = "Master"
	add_child(_ads_player)


func play_m4_fire() -> void:
	_play_stream(SFX_M4, 0.0, 0.04)


func play_deagle_fire() -> void:
	_play_stream(SFX_DEAGLE, 2.0, 0.03)


func play_hit() -> void:
	if not is_inside_tree() or not enabled or volume <= 0.0:
		return
	if _hit_player != null:
		_hit_player.volume_db = linear_to_db(clampf(volume * 1.1, 0.01, 1.5))
		# 微量音高随机抖动，避免连续命中出现听觉疲劳
		_hit_player.pitch_scale = randf_range(0.97, 1.03)
		_hit_player.play()


func play_kill() -> void:
	if not is_inside_tree() or not enabled or volume <= 0.0:
		return
	if _kill_player != null:
		_kill_player.volume_db = linear_to_db(clampf(volume * 1.2, 0.01, 1.5))
		_kill_player.pitch_scale = randf_range(0.99, 1.02)
		_kill_player.play()


func play_ads() -> void:
	if not is_inside_tree() or not enabled or volume <= 0.0:
		return
	if _ads_player != null and not _ads_player.playing:
		_ads_player.volume_db = linear_to_db(clampf(volume * 0.5, 0.01, 1.0))
		_ads_player.play()


func _play_stream(stream: AudioStream, extra_db: float = 0.0, pitch_jitter: float = 0.02) -> void:
	if not is_inside_tree() or not enabled or volume <= 0.0 or _fire_players.is_empty():
		return
	var p := _fire_players[_fire_idx]
	_fire_idx = (_fire_idx + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = linear_to_db(clampf(volume, 0.01, 2.0)) + extra_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
