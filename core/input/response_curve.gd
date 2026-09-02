## 摇杆响应曲线：把归一化偏转量映射为归一化输出。
##
## 输入输出都是 0..1，与灵敏度无关——曲线只决定"推到一半时出多少力"，
## 推到底出多少由 [ControllerProfile] 的满偏转速决定。两者分开才能各调各的。
##
## 必须满足的不变量（由 tests/test_response_curve.gd 钉死）：
##   1. evaluate(0) == 0    —— 否则摇杆回中时视角会飘
##   2. evaluate(1) == 1    —— 否则满偏转速这个参数就名不副实
##   3. 单调不减            —— 否则推得更多反而转得更慢，手感会彻底崩坏
class_name ResponseCurve
extends Resource

enum Type {
	LINEAR,    ## y = x。1:1 直出，摇杆位移与转速严格成正比。
	POWER,     ## y = x^exponent。指数越大中心越精细、边缘越迅猛，近似 COD「标准」。
	S_CURVE,   ## 慢-快-慢。中段加速，两端精细。
	REVERSE_S, ## 快-慢-快。中段精细、两端迅猛，近似 COD「动态」。
	BEZIER,    ## 三次贝塞尔自定义曲线，两个控制点可在面板上拖。
}

@export var type: Type = Type.POWER:
	set(v):
		type = v
		emit_changed()

## POWER 的指数。1.0 等价于线性；越大，摇杆前半程越"钝"，越适合微操。
@export_range(1.0, 5.0, 0.05) var exponent: float = 2.0:
	set(v):
		exponent = v
		emit_changed()

## S / 反S 曲线的弯曲程度。0 时退化为线性，1 时弯曲最剧烈。
@export_range(0.0, 1.0, 0.01) var strength: float = 0.5:
	set(v):
		strength = v
		emit_changed()

## 贝塞尔第一控制点。x 会被夹到 0..1 以保证曲线对 x 单值。
@export var bezier_p1: Vector2 = Vector2(0.42, 0.12):
	set(v):
		bezier_p1 = v
		emit_changed()

## 贝塞尔第二控制点。
@export var bezier_p2: Vector2 = Vector2(0.78, 0.62):
	set(v):
		bezier_p2 = v
		emit_changed()

## 求值。x 为归一化偏转量，返回归一化输出，两者均为 0..1。
func evaluate(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match type:
		Type.LINEAR:
			return x
		Type.POWER:
			return pow(x, exponent)
		Type.S_CURVE:
			return _s_shape(x, _bend(), false)
		Type.REVERSE_S:
			return _s_shape(x, _bend(), true)
		Type.BEZIER:
			return _bezier(x)
	return x


## 曲线的中文名，用于 UI 显示。
func type_label() -> String:
	match type:
		Type.LINEAR: return "线性"
		Type.POWER: return "指数"
		Type.S_CURVE: return "S 曲线"
		Type.REVERSE_S: return "反 S 曲线"
		Type.BEZIER: return "自定义"
	return "未知"


func duplicate_curve() -> ResponseCurve:
	var c := ResponseCurve.new()
	c.type = type
	c.exponent = exponent
	c.strength = strength
	c.bezier_p1 = bezier_p1
	c.bezier_p2 = bezier_p2
	return c


# strength 0..1 映射到 1..4 的弯曲指数。取 1 作为下界是为了让 strength=0
# 精确退化成线性，这样"关掉弯曲"和"选线性"是同一条曲线，不会有手感跳变。
func _bend() -> float:
	return 1.0 + strength * 3.0


# 以 (0.5, 0.5) 为对称中心拼接两段幂函数。
# reversed=false 得到 S 形（中段陡），true 得到反 S 形（中段缓）。
func _s_shape(x: float, p: float, reversed: bool) -> float:
	if reversed:
		if x < 0.5:
			return 0.5 * (1.0 - pow(1.0 - 2.0 * x, p))
		return 0.5 + 0.5 * pow(2.0 * x - 1.0, p)
	if x < 0.5:
		return 0.5 * pow(2.0 * x, p)
	return 1.0 - 0.5 * pow(2.0 * (1.0 - x), p)


# 端点固定在 (0,0) 与 (1,1) 的三次贝塞尔。给定 x 反解参数 t 再取 y。
# 用二分而非牛顿法：控制点被夹在单位方形内后 x(t) 单调，二分绝不发散，
# 20 次迭代精度约 1e-6，对每帧一次的调用量完全够。
func _bezier(x: float) -> float:
	var x1 := clampf(bezier_p1.x, 0.0, 1.0)
	var x2 := clampf(bezier_p2.x, 0.0, 1.0)
	var lo := 0.0
	var hi := 1.0
	var t := x
	for _i in 20:
		t = (lo + hi) * 0.5
		if _cubic(t, x1, x2) < x:
			lo = t
		else:
			hi = t
	return clampf(_cubic((lo + hi) * 0.5, bezier_p1.y, bezier_p2.y), 0.0, 1.0)


# 三次贝塞尔在端点为 0 和 1 时的展开式。
func _cubic(t: float, c1: float, c2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t
