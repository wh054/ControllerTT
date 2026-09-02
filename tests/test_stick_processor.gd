extends TestCase


func suite_name() -> String:
	return "输入管线"


func _profile(inner: float = 0.1, outer: float = 1.0) -> ControllerProfile:
	var p := ControllerProfile.new()
	p.look_deadzone.shape = DeadzoneConfig.Shape.RADIAL
	p.look_deadzone.inner = inner
	p.look_deadzone.outer = outer
	p.yaw_curve.type = ResponseCurve.Type.LINEAR
	p.pitch_curve.type = ResponseCurve.Type.LINEAR
	p.yaw_speed = 400.0
	p.pitch_speed = 300.0
	p.ads_multiplier = 1.0
	p.accel_boost = 1.0
	p.smoothing = 0.0
	return p


func test_松杆时转速为零() -> void:
	var sp := StickProcessor.new(_profile())
	assert_vec_near(sp.process(Vector2.ZERO, 0.016), Vector2.ZERO)
	assert_vec_near(sp.process(Vector2(0.05, 0.05), 0.016), Vector2.ZERO, EPS, "死区内也应为零")


func test_满偏时达到设定转速() -> void:
	var sp := StickProcessor.new(_profile())
	var r := sp.process(Vector2(1.0, 0.0), 0.016)
	assert_near(r.x, 400.0, 0.5)
	assert_near(r.y, 0.0, 0.001)


# 输入约定 +y 向下、输出约定 +pitch 向上，符号翻转必须发生且只发生一次。
# 这类符号错误在游戏里表现为"上下颠倒"，很容易被误当成反转设置的问题。
func test_推杆向上得到向上的俯仰速率() -> void:
	var sp := StickProcessor.new(_profile())
	var r := sp.process(Vector2(0.0, -1.0), 0.016)
	assert_near(r.y, 300.0, 0.5, "摇杆向上应产生正的俯仰速率")


func test_反转设置分别生效() -> void:
	var p := _profile()
	p.invert_y = true
	var sp := StickProcessor.new(p)
	assert_near(sp.process(Vector2(0.0, -1.0), 0.016).y, -300.0, 0.5)

	p.invert_y = false
	p.invert_x = true
	sp.reset()
	assert_near(sp.process(Vector2(1.0, 0.0), 0.016).x, -400.0, 0.5)


# 管线顺序的判别性测试：曲线必须作用在死区归一化**之后**的值上。
# 若顺序颠倒，同样的输入会得到 12.5 而不是 25，这里用具体数字把顺序钉死。
func test_曲线作用于死区归一化之后() -> void:
	var p := _profile(0.5, 1.0)
	p.yaw_speed = 100.0
	p.yaw_curve.type = ResponseCurve.Type.POWER
	p.yaw_curve.exponent = 2.0
	var sp := StickProcessor.new(p)
	# 原始 0.75 → 死区归一化得 0.5 → 平方得 0.25 → 乘 100 得 25。
	assert_near(sp.process(Vector2(0.75, 0.0), 0.016).x, 25.0, 0.1)


func test_开镜倍率缩放转速() -> void:
	var p := _profile()
	p.ads_multiplier = 0.5
	var sp := StickProcessor.new(p)
	assert_near(sp.process(Vector2(1.0, 0.0), 0.016, true).x, 200.0, 0.5)
	sp.reset()
	assert_near(sp.process(Vector2(1.0, 0.0), 0.016, false).x, 400.0, 0.5)


func test_径向模式下对角推杆不改变方向() -> void:
	var p := _profile()
	p.curve_mode = ControllerProfile.CurveMode.RADIAL
	p.yaw_curve.type = ResponseCurve.Type.POWER
	p.yaw_curve.exponent = 3.0
	p.pitch_speed = 400.0
	var sp := StickProcessor.new(p)
	var r := sp.process(Vector2(0.6, 0.6), 0.016)
	assert_near(absf(r.x), absf(r.y), 0.5, "两轴速度应相等，方向未被曲线扭曲")


func test_分轴模式下两轴可用不同曲线() -> void:
	var p := _profile()
	p.curve_mode = ControllerProfile.CurveMode.PER_AXIS
	p.yaw_curve.type = ResponseCurve.Type.LINEAR
	p.pitch_curve.type = ResponseCurve.Type.POWER
	p.pitch_curve.exponent = 2.0
	p.pitch_speed = 400.0
	var sp := StickProcessor.new(p)
	var r := sp.process(Vector2(0.55, -0.55), 0.016)
	assert_gt(absf(r.x), absf(r.y), "线性轴应快于指数轴")


func test_关闭加速时倍率恒为1() -> void:
	var p := _profile()
	p.accel_boost = 1.0
	var sp := StickProcessor.new(p)
	for i in 60:
		sp.process(Vector2(1.0, 0.0), 0.016)
	assert_near(sp.last_boost, 1.0, EPS)
	assert_near(sp.process(Vector2(1.0, 0.0), 0.016).x, 400.0, 0.5)


func test_持续满偏后加速到最大倍率() -> void:
	var p := _profile()
	p.accel_boost = 2.0
	p.accel_delay = 0.1
	p.accel_time = 0.2
	var sp := StickProcessor.new(p)

	assert_near(sp.process(Vector2(1.0, 0.0), 0.05).x, 400.0, 1.0, "延迟期内不应加速")
	for i in 8:
		sp.process(Vector2(1.0, 0.0), 0.05)
	assert_near(sp.last_boost, 2.0, 0.01)
	assert_near(sp.process(Vector2(1.0, 0.0), 0.05).x, 800.0, 1.0)


func test_未推满时不触发加速() -> void:
	var p := _profile()
	p.accel_boost = 2.0
	p.accel_delay = 0.0
	p.accel_time = 0.1
	var sp := StickProcessor.new(p)
	for i in 60:
		sp.process(Vector2(0.7, 0.0), 0.016)
	assert_near(sp.last_boost, 1.0, EPS, "半推杆不该攒出加速")


func test_松杆后加速状态衰减() -> void:
	var p := _profile()
	p.accel_boost = 2.0
	p.accel_delay = 0.1
	p.accel_time = 0.2
	var sp := StickProcessor.new(p)
	for i in 20:
		sp.process(Vector2(1.0, 0.0), 0.05)
	assert_near(sp.last_boost, 2.0, 0.01)
	for i in 20:
		sp.process(Vector2.ZERO, 0.05)
	assert_near(sp.last_boost, 1.0, EPS, "松杆后应回落")


func test_重置清空跨帧状态() -> void:
	var p := _profile()
	p.accel_boost = 2.0
	p.accel_delay = 0.1
	p.accel_time = 0.2
	var sp := StickProcessor.new(p)
	for i in 20:
		sp.process(Vector2(1.0, 0.0), 0.05)
	assert_near(sp.last_boost, 2.0, 0.01)
	sp.reset()
	assert_near(sp.last_boost, 1.0, EPS)
	# 重置后计时器归零，首帧只累积了 0.05 秒，尚未越过 0.1 秒的延迟，因此不该有加速。
	assert_near(sp.process(Vector2(1.0, 0.0), 0.05).x, 400.0, 1.0, "重置后第一帧不该带着上一局的加速")


# 平滑用固定系数 lerp 是这类滤波最常见的坑：帧率一变手感就变。
# 这里验证同样的真实时间内，60Hz 与 240Hz 得到几乎相同的结果。
func test_平滑不受帧率影响() -> void:
	var p := _profile()
	p.smoothing = 0.5

	var slow := StickProcessor.new(p)
	for i in 6:
		slow.process(Vector2(1.0, 0.0), 1.0 / 60.0)

	var fast := StickProcessor.new(p)
	for i in 24:
		fast.process(Vector2(1.0, 0.0), 1.0 / 240.0)

	assert_near(slow.last_rate.x, fast.last_rate.x, 1.0, "两种帧率下 0.1 秒后的转速应一致")


func test_关闭平滑时输出无延迟() -> void:
	var p := _profile()
	p.smoothing = 0.0
	var sp := StickProcessor.new(p)
	assert_near(sp.process(Vector2(1.0, 0.0), 0.016).x, 400.0, 0.5, "第一帧就该到位")


func test_逐级快照可供调试面板读取() -> void:
	var p := _profile(0.2, 1.0)
	p.yaw_curve.type = ResponseCurve.Type.POWER
	p.yaw_curve.exponent = 2.0
	var sp := StickProcessor.new(p)
	sp.process(Vector2(0.6, 0.0), 0.016)
	assert_vec_near(sp.last_raw, Vector2(0.6, 0.0))
	assert_near(sp.last_after_deadzone.x, 0.5, 0.001)
	assert_near(sp.last_after_curve.x, 0.25, 0.001)
