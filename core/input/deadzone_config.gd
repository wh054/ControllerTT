## 死区处理：剔除摇杆回中漂移，并把可用行程重新归一化到 0..1。
##
## 归一化这一步容易被忽略但很关键：如果只是简单地把小于内死区的值置零，
## 那么摇杆刚离开死区时输出就会从 0 突跳到 inner，形成一个手感上的"台阶"。
## 正确做法是把 [inner, outer] 这段有效行程线性拉伸回 [0, 1]。
##
## 不变量（由 tests/test_deadzone.gd 钉死）：
##   1. 输出模长恒在 0..1
##   2. 内死区内的输入输出必为零
##   3. 偏转量达到外死区时输出模长为 1
##   4. 径向模式下输出方向与输入方向一致
class_name DeadzoneConfig
extends Resource

enum Shape {
	AXIAL,  ## 轴向（方形）：两轴各自判定。对角方向可用行程更大，是老式手感。
	RADIAL, ## 径向（圆形）：按模长判定，方向不失真。多数现代 FPS 的做法。
	HYBRID, ## 混合：先按轴剔除噪声，再按模长归一化。抗漂移最好且方向不失真。
}

const _EPS := 0.0001

@export var shape: Shape = Shape.RADIAL:
	set(v):
		shape = v
		emit_changed()

## 内死区。低于此偏转量的输入视为噪声。摇杆有回中漂移时调大。
@export_range(0.0, 0.5, 0.005) var inner: float = 0.06:
	set(v):
		inner = v
		emit_changed()

## 外死区。达到此偏转量即视为推到底。摇杆物理上推不满时调小。
@export_range(0.5, 1.0, 0.005) var outer: float = 0.95:
	set(v):
		outer = v
		emit_changed()

## 反死区：把非零输出的下限抬高到这个值。
## 用途与内死区相反——当**游戏本身**有一个关不掉的死区时，用它来抵消。
## 代价是失去最低速段，所以本训练器里默认关闭。
@export_range(0.0, 0.5, 0.005) var anti_deadzone: float = 0.0:
	set(v):
		anti_deadzone = v
		emit_changed()


## 处理一帧的原始摇杆输入。
## raw 为硬件原始值（+x 右 / +y 下，各轴 -1..1），返回同样约定下的归一化结果。
func apply(raw: Vector2) -> Vector2:
	match shape:
		Shape.AXIAL:
			return _apply_axial(raw)
		Shape.HYBRID:
			return _apply_hybrid(raw)
		_:
			return _apply_radial(raw)


func duplicate_deadzone() -> DeadzoneConfig:
	var d := DeadzoneConfig.new()
	d.shape = shape
	d.inner = inner
	d.outer = outer
	d.anti_deadzone = anti_deadzone
	return d


func _apply_radial(raw: Vector2) -> Vector2:
	var mag := raw.length()
	if mag <= inner or mag <= _EPS:
		return Vector2.ZERO
	return raw / mag * _remap(mag)


func _apply_axial(raw: Vector2) -> Vector2:
	# 每轴独立归一化，因此对角方向的模长可能超过 1，必须夹回来，
	# 否则对角转速会比正方向快 41%。
	return Vector2(_remap_axis(raw.x), _remap_axis(raw.y)).limit_length(1.0)


func _apply_hybrid(raw: Vector2) -> Vector2:
	var v := Vector2(
		0.0 if absf(raw.x) <= inner else raw.x,
		0.0 if absf(raw.y) <= inner else raw.y,
	)
	var mag := v.length()
	if mag <= _EPS:
		return Vector2.ZERO
	return v / mag * _remap(mag)


func _remap_axis(v: float) -> float:
	var a := absf(v)
	if a <= inner:
		return 0.0
	return signf(v) * _remap(a)


# 把 [inner, outer] 拉伸到 [0, 1]，再按反死区抬升下限。
func _remap(mag: float) -> float:
	var span: float = maxf(outer - inner, _EPS)
	var n := clampf((mag - inner) / span, 0.0, 1.0)
	if anti_deadzone > 0.0:
		n = anti_deadzone + (1.0 - anti_deadzone) * n
	return n
