extends TestCase

const SAMPLES := 200


func suite_name() -> String:
	return "响应曲线"


func _all_variants() -> Array[ResponseCurve]:
	var out: Array[ResponseCurve] = []
	for e in [1.0, 1.5, 2.0, 3.3, 5.0]:
		var c := ResponseCurve.new()
		c.type = ResponseCurve.Type.POWER
		c.exponent = e
		out.append(c)
	for s in [0.0, 0.25, 0.6, 1.0]:
		for t in [ResponseCurve.Type.S_CURVE, ResponseCurve.Type.REVERSE_S]:
			var c := ResponseCurve.new()
			c.type = t
			c.strength = s
			out.append(c)
	var lin := ResponseCurve.new()
	lin.type = ResponseCurve.Type.LINEAR
	out.append(lin)
	for pts in [[Vector2(0.4, 0.1), Vector2(0.8, 0.7)], [Vector2(0.1, 0.6), Vector2(0.5, 0.9)], [Vector2(0.0, 0.0), Vector2(1.0, 1.0)]]:
		var c := ResponseCurve.new()
		c.type = ResponseCurve.Type.BEZIER
		c.bezier_p1 = pts[0]
		c.bezier_p2 = pts[1]
		out.append(c)
	return out


# 不变量 1 与 2：端点必须锚死。
# 违反 f(0)=0 会让摇杆回中后视角持续漂移；违反 f(1)=1 会让"满偏转速"这个参数失真。
func test_端点固定在0和1() -> void:
	for c in _all_variants():
		assert_near(c.evaluate(0.0), 0.0, 0.002, "%s 在 0 处" % c.type_label())
		assert_near(c.evaluate(1.0), 1.0, 0.002, "%s 在 1 处" % c.type_label())


# 不变量 3：单调不减。这是最关键的一条——一旦违反，会出现"推得更多反而转得更慢"，
# 手感会彻底崩坏，而且在游戏里极难察觉是曲线的问题。
func test_全部曲线单调不减() -> void:
	for c in _all_variants():
		var prev := -1.0
		for i in SAMPLES + 1:
			var x := float(i) / SAMPLES
			var y := c.evaluate(x)
			if y < prev - 0.0005:
				fail("%s 在 x=%.3f 处回落：%.5f < %.5f" % [c.type_label(), x, y, prev])
				break
			prev = y


func test_输出始终落在0到1() -> void:
	for c in _all_variants():
		for i in SAMPLES + 1:
			var y := c.evaluate(float(i) / SAMPLES)
			assert_between(y, 0.0, 1.0, "%s" % c.type_label())


func test_定义域外的输入被夹住() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.POWER
	assert_near(c.evaluate(-3.0), 0.0)
	assert_near(c.evaluate(7.0), 1.0)


func test_线性即恒等映射() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.LINEAR
	for i in 11:
		var x := float(i) / 10.0
		assert_near(c.evaluate(x), x)


# 参数取退化值时必须精确回落到线性，否则"把弯曲调到 0"和"选线性"会是两种手感，
# 使用者在面板上来回切换时会遇到无法解释的跳变。
func test_指数为1时退化为线性() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.POWER
	c.exponent = 1.0
	for i in 11:
		var x := float(i) / 10.0
		assert_near(c.evaluate(x), x)


func test_弯曲强度为0时S与反S均退化为线性() -> void:
	for t in [ResponseCurve.Type.S_CURVE, ResponseCurve.Type.REVERSE_S]:
		var c := ResponseCurve.new()
		c.type = t
		c.strength = 0.0
		for i in 11:
			var x := float(i) / 10.0
			assert_near(c.evaluate(x), x, EPS, c.type_label())


func test_指数曲线中心比线性更精细() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.POWER
	c.exponent = 2.0
	# 前半程输出低于线性，才谈得上"微操更细"。
	assert_lt(c.evaluate(0.25), 0.25)
	assert_lt(c.evaluate(0.5), 0.5)


func test_S曲线两端缓中段陡() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.S_CURVE
	c.strength = 1.0
	assert_lt(c.evaluate(0.25), 0.25)
	assert_near(c.evaluate(0.5), 0.5, 0.001)
	assert_gt(c.evaluate(0.75), 0.75)


func test_反S曲线两端陡中段缓() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.REVERSE_S
	c.strength = 1.0
	assert_gt(c.evaluate(0.25), 0.25)
	assert_near(c.evaluate(0.5), 0.5, 0.001)
	assert_lt(c.evaluate(0.75), 0.75)


func test_S与反S关于中心对称() -> void:
	for t in [ResponseCurve.Type.S_CURVE, ResponseCurve.Type.REVERSE_S]:
		var c := ResponseCurve.new()
		c.type = t
		c.strength = 0.7
		for i in 11:
			var x := float(i) / 10.0
			assert_near(c.evaluate(x) + c.evaluate(1.0 - x), 1.0, 0.001, c.type_label())


func test_贝塞尔控制点在对角线上时为线性() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.BEZIER
	c.bezier_p1 = Vector2(1.0 / 3.0, 1.0 / 3.0)
	c.bezier_p2 = Vector2(2.0 / 3.0, 2.0 / 3.0)
	for i in 11:
		var x := float(i) / 10.0
		assert_near(c.evaluate(x), x, 0.002)


# 控制点被拖到方框外时不能让曲线炸掉，UI 上的拖拽很容易越界。
func test_贝塞尔控制点越界仍然安全() -> void:
	var c := ResponseCurve.new()
	c.type = ResponseCurve.Type.BEZIER
	c.bezier_p1 = Vector2(-5.0, 3.0)
	c.bezier_p2 = Vector2(9.0, -2.0)
	for i in 21:
		var y := c.evaluate(float(i) / 20.0)
		assert_between(y, 0.0, 1.0)


func test_克隆是深拷贝() -> void:
	var a := ResponseCurve.new()
	a.type = ResponseCurve.Type.POWER
	a.exponent = 3.0
	var b := a.duplicate_curve()
	b.exponent = 1.0
	assert_near(a.exponent, 3.0, EPS, "修改副本不应影响原件")
	assert_eq(b.type, ResponseCurve.Type.POWER)
