## 训练场次的主持者：按 [ScenarioDef] 布置靶机、计时、记分。
##
## 四种训练共用这一个类，差别全在 [ScenarioDef] 的参数里。
class_name Scenario
extends Node3D

signal finished
signal stats_changed

## 新靶机与已有靶机的最小间隔（按半径的倍数）。
## 靶机重叠会让"打中哪个"变得含糊，也会干扰辅助瞄准的选靶。
const _MIN_SEPARATION := 3.0
const _PLACEMENT_ATTEMPTS := 24

var stats := SessionStats.new()
var running: bool = false
## 打开参数面板时为 true：计时冻结、靶机停住，但配置仍可热更新。
var paused: bool = false

var _def: ScenarioDef
var _targets: Array[Target] = []
var _rng := RandomNumberGenerator.new()
var _time_left: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_rng.randomize()


## 按当前的场景配置重新开始一场。
func start(def: ScenarioDef) -> void:
	_def = def
	stop()
	stats.reset()
	_elapsed = 0.0
	_time_left = def.duration
	for i in def.target_count:
		_spawn()
	running = true
	paused = false
	_sync_target_processing()
	stats_changed.emit()


func stop() -> void:
	running = false
	paused = false
	for t in _targets:
		t.queue_free()
	_targets.clear()


## 暂停 / 恢复本局。与 [member running] 独立：暂停不是结束，关掉菜单后应从原地继续。
func set_paused(on: bool) -> void:
	paused = on
	_sync_target_processing()


## 把当前 [member ScenarioDef] 立刻铺到场上的靶机，不重开、不清成绩。
## 散布和距离只影响下次换位，拖滑块时把靶机瞬移会让人没法瞄准。
func apply_live() -> void:
	if _def == null:
		return
	_time_left = maxf(0.0, _def.duration - _elapsed)
	while _targets.size() < _def.target_count:
		_spawn()
	while _targets.size() > _def.target_count:
		var extra: Target = _targets.pop_back()
		extra.queue_free()
	for t in _targets:
		t.apply_live(_def)
	_sync_target_processing()
	if running and _time_left <= 0.0:
		running = false
		_sync_target_processing()
		finished.emit()
		return
	stats_changed.emit()


func active_targets() -> Array:
	return _targets


func time_left() -> float:
	return maxf(0.0, _time_left)


func elapsed() -> float:
	return _elapsed


func _process(delta: float) -> void:
	if not running or paused:
		return
	_elapsed += delta
	stats.elapsed = _elapsed
	_time_left -= delta
	if _time_left <= 0.0:
		running = false
		_sync_target_processing()
		for t in _targets:
			t.set_beam_lit(false)
		finished.emit()


## 由 [Player] 在击毁靶机后调用。
func report_kill(t: Target) -> void:
	if not running:
		return
	stats.record_kill(_elapsed - t.spawn_time)
	if _def.respawn_on_hit:
		_place(t)
	else:
		# “不换位”只控制击毁后的布置方式，不应把一个按时长进行的训练局
		# 提前截断。原逻辑会逐个隐藏靶机，打完初始数量后场上再也没有目标。
		# 在当前位置重新初始化可同时恢复生命值、运动状态和出生时间。
		_respawn_in_place(t)
	stats_changed.emit()


func _spawn() -> void:
	var t := Target.new()
	add_child(t)
	_targets.append(t)
	_place(t)
	t.set_process(running and not paused)


func _place(t: Target) -> void:
	t.setup(_def, _pick_position(), _rng, _elapsed)
	t.show()
	t.set_process(running and not paused)


func _respawn_in_place(t: Target) -> void:
	t.setup(_def, t.global_position, _rng, _elapsed)
	t.show()
	t.set_process(running and not paused)


func _sync_target_processing() -> void:
	var should_move := running and not paused
	for t in _targets:
		t.set_process(should_move)


# 随机取一个不与现有靶机重叠的位置。尝试若干次仍失败就接受最后一次，
# 与其为了摆位卡住一帧，不如让两个靶机偶尔靠近一点。
func _pick_position() -> Vector3:
	var pos := Vector3.ZERO
	var min_y := Target.minimum_center_height(_def.target_radius)
	var max_y := maxf(min_y, Player.EYE_HEIGHT + _def.spread_v)
	for attempt in _PLACEMENT_ATTEMPTS:
		pos = Vector3(
			_rng.randf_range(-_def.spread_h, _def.spread_h),
			_rng.randf_range(maxf(min_y, Player.EYE_HEIGHT - _def.spread_v), max_y),
			-_rng.randf_range(_def.distance_min, _def.distance_max),
		)
		if _is_clear(pos):
			break
	return pos


func _is_clear(pos: Vector3) -> bool:
	var min_gap := _def.target_radius * _MIN_SEPARATION + _def.motion_range
	for other in _targets:
		if other.alive and other.global_position.distance_to(pos) < min_gap:
			return false
	return true
