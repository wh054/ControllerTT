extends TestCase


func suite_name() -> String:
	return "死区"


func _shapes() -> Array:
	return [DeadzoneConfig.Shape.AXIAL, DeadzoneConfig.Shape.RADIAL, DeadzoneConfig.Shape.HYBRID]


func _shape_label(s: int) -> String:
	match s:
		DeadzoneConfig.Shape.AXIAL: return "轴向"
		DeadzoneConfig.Shape.RADIAL: return "径向"
		_: return "混合"


func _make(shape: int, inner: float = 0.1, outer: float = 0.9) -> DeadzoneConfig:
	var d := DeadzoneConfig.new()
	d.shape = shape
	d.inner = inner
	d.outer = outer
	return d


func test_内死区内输出为零() -> void:
	for s in _shapes():
		var d := _make(s, 0.2, 0.9)
		for v in [Vector2.ZERO, Vector2(0.1, 0.0), Vector2(0.0, -0.15), Vector2(0.1, 0.1)]:
			assert_vec_near(d.apply(v), Vector2.ZERO, EPS, "%s 输入 %v" % [_shape_label(s), v])


func test_达到外死区时输出满偏() -> void:
	for s in _shapes():
		var d := _make(s, 0.1, 0.9)
		assert_near(d.apply(Vector2(0.9, 0.0)).length(), 1.0, 0.001, _shape_label(s))
		assert_near(d.apply(Vector2(0.0, -0.9)).length(), 1.0, 0.001, _shape_label(s))
		assert_near(d.apply(Vector2(1.0, 0.0)).length(), 1.0, 0.001, _shape_label(s))


# 对角方向如果不夹回单位圆，转速会比正方向快 41%，这是轴向死区最经典的坑。
func test_输出模长永不超过1() -> void:
	for s in _shapes():
		var d := _make(s, 0.05, 0.8)
		for i in 33:
			var a := TAU * i / 32.0
			for r in [0.3, 0.6, 0.85, 1.0, 1.4]:
				var out := d.apply(Vector2(cos(a), sin(a)) * r)
				assert_between(out.length(), 0.0, 1.0, "%s 角度%.2f 半径%.2f" % [_shape_label(s), a, r])


func test_径向与混合保持输入方向() -> void:
	for s in [DeadzoneConfig.Shape.RADIAL, DeadzoneConfig.Shape.HYBRID]:
		var d := _make(s, 0.1, 0.9)
		for i in 16:
			var a := TAU * i / 16.0
			var raw := Vector2(cos(a), sin(a)) * 0.6
			var out := d.apply(raw)
			if out.length() <= 0.0:
				continue
			assert_near(
				out.normalized().dot(raw.normalized()), 1.0, 0.002,
				"%s 角度 %.2f 方向被扭曲" % [_shape_label(s), a],
			)


# 死区边界必须连续。若这里出现台阶，摇杆刚离开中心时视角会"弹"一下，
# 这是纯靠手感极难定位、但对追踪类训练致命的缺陷。
func test_内死区边界连续无台阶() -> void:
	for s in _shapes():
		var d := _make(s, 0.25, 0.9)
		var just_outside := d.apply(Vector2(0.2501, 0.0)).length()
		assert_near(just_outside, 0.0, 0.005, "%s 刚出死区时输出应接近零" % _shape_label(s))


func test_有效行程被重新归一化() -> void:
	var d := _make(DeadzoneConfig.Shape.RADIAL, 0.2, 0.8)
	# 行程正中间应当输出 0.5，而不是原始的 0.5。
	assert_near(d.apply(Vector2(0.5, 0.0)).length(), 0.5, 0.001)
	assert_near(d.apply(Vector2(0.35, 0.0)).length(), 0.25, 0.001)


func test_反死区抬升非零输出的下限() -> void:
	var d := _make(DeadzoneConfig.Shape.RADIAL, 0.1, 0.9)
	d.anti_deadzone = 0.3
	assert_vec_near(d.apply(Vector2(0.05, 0.0)), Vector2.ZERO, EPS, "死区内仍应为零")
	var out := d.apply(Vector2(0.1001, 0.0)).length()
	assert_near(out, 0.3, 0.005, "刚出死区就应抬到反死区下限")
	assert_near(d.apply(Vector2(0.9, 0.0)).length(), 1.0, 0.002, "满偏不受反死区影响")


func test_轴向死区在对角被夹到单位圆() -> void:
	var d := _make(DeadzoneConfig.Shape.AXIAL, 0.1, 0.9)
	var out := d.apply(Vector2(0.9, 0.9))
	assert_near(out.length(), 1.0, 0.001)
	assert_near(out.x, out.y, 0.001, "对角应保持 45 度")


# 轴向与径向的实质差别：轴向会把幅度较小的那个轴整个抹掉。
# 这对"只想纯水平转身"是优点，对"缓慢斜向微调"是缺点——
# 使用者需要通过本工具亲自感受这个取舍，所以两种形状都必须保留。
func test_轴向与径向在单轴上一致但会抹掉副轴() -> void:
	var ax := _make(DeadzoneConfig.Shape.AXIAL, 0.1, 0.9)
	var rad := _make(DeadzoneConfig.Shape.RADIAL, 0.1, 0.9)
	assert_vec_near(
		ax.apply(Vector2(0.5, 0.0)), rad.apply(Vector2(0.5, 0.0)), 0.001,
		"纯单轴输入下两者应当一致",
	)

	var mostly_horizontal := Vector2(0.8, 0.07)
	assert_near(ax.apply(mostly_horizontal).y, 0.0, EPS, "轴向应抹掉低于内死区的副轴")
	assert_gt(absf(rad.apply(mostly_horizontal).y), 0.0, "径向应保留副轴上的微调")


func test_混合模式能剔除单轴漂移() -> void:
	var d := _make(DeadzoneConfig.Shape.HYBRID, 0.1, 0.9)
	# 一轴推杆、另一轴有轻微漂移时，漂移轴应被完全剔除。
	var out := d.apply(Vector2(0.6, 0.04))
	assert_near(out.y, 0.0, EPS, "漂移轴未被剔除")
	assert_gt(out.x, 0.0)


func test_外死区小于内死区时不崩溃() -> void:
	var d := DeadzoneConfig.new()
	d.inner = 0.5
	d.outer = 0.5
	for s in _shapes():
		d.shape = s
		var out := d.apply(Vector2(0.8, 0.2))
		assert_between(out.length(), 0.0, 1.0, _shape_label(s))
		assert_false(is_nan(out.x) or is_nan(out.y), "%s 产生了 NaN" % _shape_label(s))


func test_单调性推得越多输出越大() -> void:
	for s in _shapes():
		var d := _make(s, 0.1, 0.9)
		var prev := -1.0
		for i in 101:
			var out := d.apply(Vector2(float(i) / 100.0, 0.0)).length()
			if out < prev - EPS:
				fail("%s 在 %.2f 处输出回落" % [_shape_label(s), float(i) / 100.0])
				break
			prev = out
