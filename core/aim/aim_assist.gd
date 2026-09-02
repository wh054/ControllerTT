## 辅助瞄准的组合器：给定视野里的目标，算出这一帧该如何干预玩家的视角。
##
## 输出刻意拆成两部分，因为它们的作用方式完全不同：
##   - [member Result.turn_scale] 是**乘性**的，缩放玩家自己的转速（减速/粘滞）
##   - [member Result.bonus_dps] 是**加性**的，与玩家输入无关的额外转速（跟枪/磁吸）
## 把两者混成一个值会导致"松开摇杆后磁吸也停了"这种错误行为。
##
## 纯计算，无副作用，不持有跨帧状态——因此可以直接在测试里喂构造好的目标验证。
class_name AimAssist
extends RefCounted

## 判定"玩家正在给输入"的摇杆偏转量阈值。
const _INPUT_EPSILON := 0.12


## 一帧的辅助瞄准结果。
class Result extends RefCounted:
	## 玩家转速的乘性缩放，1.0 表示不减速。
	var turn_scale: float = 1.0
	## 附加的视角角速度，度/秒，与玩家输入无关。
	var bonus_dps := Vector2.ZERO
	## 本帧被锁定的目标 id，-1 表示没有目标进入任何气泡。
	var target_id: int = -1
	## 到锁定目标的角度误差，度。供 HUD 调试显示。
	var target_offset := Vector2.ZERO
	## 各机制的实际生效强度 0..1，供调试面板逐项显示，便于分辨手感来自哪一项。
	var slowdown_factor: float = 0.0
	var rotation_factor: float = 0.0
	var magnetism_factor: float = 0.0

	## 是否锁定了目标。注意锁定不等于产生了干预：目标可能落在气泡边缘、
	## 或者跟枪被"需要移动输入"之类的门控挡住。
	func is_active() -> bool:
		return target_id != -1

	## 这一帧是否真的改变了玩家的视角。
	## 统计与准星提示都必须用这个而不是 [method is_active]，
	## 否则"辅助介入时间占比"会把只是锁定了目标的帧也算进去，得出虚高的结论。
	func has_effect() -> bool:
		return not is_equal_approx(turn_scale, 1.0) or bonus_dps.length_squared() > 0.0


var config: AimAssistConfig


func _init(c: AimAssistConfig = null) -> void:
	config = c if c != null else AimAssistConfig.new()


## 计算这一帧的辅助。
## [param targets] 视野内的候选目标。
## [param look_input] 玩家视角摇杆的归一化输入（死区之后），用于判断是否有视角输入。
## [param move_input] 玩家移动摇杆的归一化输入，用于 Apex 式的"需移动才跟枪"。
## [param ads] 是否开镜。
func compute(
	targets: Array[AimTarget],
	look_input: Vector2 = Vector2.ZERO,
	move_input: Vector2 = Vector2.ZERO,
	ads: bool = false,
) -> Result:
	var r := Result.new()
	if not config.enabled or config.master_strength <= 0.0:
		return r
	if config.ads_only and not ads:
		return r

	var target := _select_target(targets)
	if target == null:
		return r

	r.target_id = target.id
	r.target_offset = target.angular_offset

	var master := config.master_strength
	var d := target.angular_distance()
	# 目标越大，气泡越大——远处小目标的辅助自然就弱，这与真实游戏表现一致。
	var size_bonus := target.angular_radius if config.scale_bubble_by_target_size else 0.0

	if config.slowdown_enabled:
		var f := _falloff(d, config.slowdown_bubble + size_bonus, config.slowdown_core)
		r.slowdown_factor = f
		r.turn_scale = 1.0 - config.slowdown_strength * f * master

	if config.rotation_enabled and _rotation_gated(look_input, move_input):
		var f := _falloff(d, config.rotation_bubble + size_bonus, config.rotation_core)
		r.rotation_factor = f
		var follow := target.angular_velocity * config.rotation_strength * f * master
		r.bonus_dps += follow.limit_length(config.rotation_max_dps)

	if config.magnetism_enabled:
		var f := _falloff(d, config.magnetism_bubble + size_bonus, 0.0)
		r.magnetism_factor = f
		if d > 0.0:
			var speed: float = minf(
				config.magnetism_strength * f * master * d * config.magnetism_gain,
				config.magnetism_max_dps,
			)
			r.bonus_dps += target.angular_offset / d * speed

	return r


## 选中最该被辅助的目标：气泡内、可见、距离达标者中角度误差最小的一个。
## 用"角度误差最小"而不是"世界距离最近"，因为玩家的意图由准星指向表达，而非远近。
func _select_target(targets: Array[AimTarget]) -> AimTarget:
	var widest: float = maxf(
		maxf(config.slowdown_bubble, config.rotation_bubble),
		config.magnetism_bubble,
	)
	var best: AimTarget = null
	var best_d := INF
	for t in targets:
		if not t.visible or t.distance > config.max_distance:
			continue
		var limit := widest + (t.angular_radius if config.scale_bubble_by_target_size else 0.0)
		var d := t.angular_distance()
		if d > limit or d >= best_d:
			continue
		best = t
		best_d = d
	return best


func _rotation_gated(look_input: Vector2, move_input: Vector2) -> bool:
	if config.rotation_requires_look_input and look_input.length() < _INPUT_EPSILON:
		return false
	if config.rotation_requires_move_input and move_input.length() < _INPUT_EPSILON:
		return false
	return true


## 气泡内的强度衰减：核心内恒为 1，核心到边缘用 smoothstep 平滑落到 0。
## 用平滑而非线性衰减，是为了避免目标掠过气泡边界时转速出现可感知的突变。
static func _falloff(distance: float, bubble: float, core_ratio: float) -> float:
	if bubble <= 0.0 or distance >= bubble:
		return 0.0
	var core := bubble * clampf(core_ratio, 0.0, 0.999)
	if distance <= core:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (distance - core) / (bubble - core))
