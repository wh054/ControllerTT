## 摇杆输入管线的编排者：把一帧的原始摇杆值变成视角转速。
##
## 管线顺序（顺序本身是有讲究的，不要随意调换）：
##   原始值 → 死区归一化 → 响应曲线 → 灵敏度 → 开镜倍率 → 转向加速 → 平滑 → 反向
##
## 为什么曲线必须在死区**之后**：曲线的定义域是"有效行程的 0..1"。
## 若先过曲线再切死区，曲线的低速段会被死区整段吃掉，中心精细的调节就完全失效了。
##
## 这是本管线里唯一持有状态的地方（加速计时器与平滑历史），
## 因此它是 RefCounted 而非 Resource——状态属于某一次游戏会话，不该被存盘。
class_name StickProcessor
extends RefCounted

## 触发转向加速所需的偏转量下限。略低于 1 是为了容忍摇杆推不满的硬件误差。
const _ACCEL_THRESHOLD := 0.97
## 松杆后加速计时器的衰减倍率。衰减比累积快，避免连续小幅推杆意外攒出加速。
const _ACCEL_DECAY_RATE := 3.0

var profile: ControllerProfile

# --- 供 UI 可视化读取的逐级快照。调试面板要能看出是哪一级把值改坏了。---
var last_raw := Vector2.ZERO
var last_after_deadzone := Vector2.ZERO
var last_after_curve := Vector2.ZERO
var last_boost := 1.0
var last_rate := Vector2.ZERO

var _accel_timer := 0.0
var _smoothed := Vector2.ZERO


func _init(p: ControllerProfile = null) -> void:
	profile = p if p != null else ControllerProfile.new()


## 处理一帧输入。
## [param raw] 硬件原始摇杆值，+x 右 / +y 下，各轴 -1..1。
## [param delta] 帧时长（秒）。
## [param ads] 是否处于开镜状态。
## [return] 视角转速 Vector2(yaw, pitch)，单位度/秒，yaw 右为正、pitch 上为正。
func process(raw: Vector2, delta: float, ads: bool = false) -> Vector2:
	last_raw = raw

	var dz := profile.look_deadzone.apply(raw)
	last_after_deadzone = dz

	var shaped := _apply_curve(dz)
	last_after_curve = shaped

	_advance_accel_timer(dz.length(), delta)
	last_boost = _current_boost()

	var speed_scale := (profile.ads_multiplier if ads else 1.0) * last_boost
	# pitch 在此处翻转符号：输入约定 +y 向下，输出约定 +pitch 向上。
	# 整个代码库里 y 轴的符号翻转只发生在这一行，别在别处再翻一次。
	var rate := Vector2(
		shaped.x * profile.yaw_speed,
		-shaped.y * profile.pitch_speed,
	) * speed_scale

	rate = _smooth(rate, delta)

	if profile.invert_x:
		rate.x = -rate.x
	if profile.invert_y:
		rate.y = -rate.y

	last_rate = rate
	return rate


## 重置会话状态。切换场景或重开时调用，避免上一局的加速状态漏到下一局。
func reset() -> void:
	_accel_timer = 0.0
	_smoothed = Vector2.ZERO
	last_boost = 1.0
	last_rate = Vector2.ZERO


## 当前转向加速的进度 0..1，供 HUD 显示。
func accel_progress() -> float:
	if profile.accel_boost <= 1.0:
		return 0.0
	return clampf((_accel_timer - profile.accel_delay) / profile.accel_time, 0.0, 1.0)


func _apply_curve(dz: Vector2) -> Vector2:
	if profile.curve_mode == ControllerProfile.CurveMode.PER_AXIS:
		return Vector2(
			signf(dz.x) * profile.yaw_curve.evaluate(absf(dz.x)),
			signf(dz.y) * profile.pitch_curve.evaluate(absf(dz.y)),
		)
	# 径向：曲线只作用于模长，方向原样保留，因此对角推杆不会被扭曲。
	var mag := dz.length()
	if mag <= 0.0:
		return Vector2.ZERO
	return dz / mag * profile.yaw_curve.evaluate(minf(mag, 1.0))


func _advance_accel_timer(deflection: float, delta: float) -> void:
	if deflection >= _ACCEL_THRESHOLD:
		_accel_timer += delta
	else:
		_accel_timer = maxf(0.0, _accel_timer - delta * _ACCEL_DECAY_RATE)


func _current_boost() -> float:
	if profile.accel_boost <= 1.0:
		return 1.0
	return lerpf(1.0, profile.accel_boost, accel_progress())


# 一阶低通。用 delta 做指数补偿，保证不同帧率下平滑手感一致——
# 直接用固定系数 lerp 会让高帧率下平滑量偏小，是这类滤波最常见的坑。
func _smooth(rate: Vector2, delta: float) -> Vector2:
	if profile.smoothing <= 0.0:
		_smoothed = rate
		return rate
	var alpha := 1.0 - pow(profile.smoothing, delta * 60.0)
	_smoothed = _smoothed.lerp(rate, clampf(alpha, 0.0, 1.0))
	return _smoothed
