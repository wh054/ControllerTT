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
	stats_changed.emit()


func stop() -> void:
	running = false
	for t in _targets:
		t.queue_free()
	_targets.clear()


func active_targets() -> Array:
	return _targets


func time_left() -> float:
	return maxf(0.0, _time_left)


func elapsed() -> float:
	return _elapsed


func _process(delta: float) -> void:
	if not running:
		return
	_elapsed += delta
	stats.elapsed = _elapsed
	_time_left -= delta
	if _time_left <= 0.0:
		running = false
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
		t.hide()
		if _all_cleared():
			running = false
			finished.emit()
	stats_changed.emit()


func _all_cleared() -> bool:
	for t in _targets:
		if t.alive:
			return false
	return true


func _spawn() -> void:
	var t := Target.new()
	add_child(t)
	_targets.append(t)
	_place(t)


func _place(t: Target) -> void:
	t.setup(_def, _pick_position(), _rng, _elapsed)
	t.show()


# 随机取一个不与现有靶机重叠的位置。尝试若干次仍失败就接受最后一次，
# 与其为了摆位卡住一帧，不如让两个靶机偶尔靠近一点。
func _pick_position() -> Vector3:
	var pos := Vector3.ZERO
	for attempt in _PLACEMENT_ATTEMPTS:
		pos = Vector3(
			_rng.randf_range(-_def.spread_h, _def.spread_h),
			Player.EYE_HEIGHT + _rng.randf_range(-_def.spread_v, _def.spread_v),
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
