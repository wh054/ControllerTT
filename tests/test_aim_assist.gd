extends TestCase


func suite_name() -> String:
	return "辅助瞄准"


func _config() -> AimAssistConfig:
	var c := AimAssistConfig.new()
	c.enabled = true
	c.master_strength = 1.0
	c.scale_bubble_by_target_size = false
	c.slowdown_enabled = false
	c.rotation_enabled = false
	c.magnetism_enabled = false
	c.ads_only = false
	return c


func _target(offset: Vector2, velocity := Vector2.ZERO, dist := 20.0) -> AimTarget:
	return AimTarget.make(1, offset, 0.0, velocity, dist)


func _one(t: AimTarget) -> Array[AimTarget]:
	var a: Array[AimTarget] = [t]
	return a


func _none() -> Array[AimTarget]:
	var a: Array[AimTarget] = []
	return a


func _assert_neutral(r: AimAssist.Result, msg: String) -> void:
	assert_near(r.turn_scale, 1.0, EPS, msg)
	assert_vec_near(r.bonus_dps, Vector2.ZERO, EPS, msg)


func test_无目标时不产生任何干预() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.rotation_enabled = true
	c.magnetism_enabled = true
	var r := AimAssist.new(c).compute(_none())
	_assert_neutral(r, "视野里没有目标")
	assert_false(r.is_active())


# 这条等价性是整个辅助瞄准模块的安全网：训练时使用者会反复对比"开"和"关"，
# 若总强度为 0 却仍有残留干预，所有对比结论都会失效。
func test_总强度为零等价于完全关闭() -> void:
	var on := _config()
	on.slowdown_enabled = true
	on.rotation_enabled = true
	on.magnetism_enabled = true
	on.master_strength = 0.0

	var off := on.clone()
	off.master_strength = 1.0
	off.enabled = false

	var t := _target(Vector2(1.0, 0.5), Vector2(40.0, 10.0))
	var a := AimAssist.new(on).compute(_one(t), Vector2(0.8, 0), Vector2(0.8, 0))
	var b := AimAssist.new(off).compute(_one(t), Vector2(0.8, 0), Vector2(0.8, 0))
	_assert_neutral(a, "总强度为 0")
	_assert_neutral(b, "开关为关")
	assert_near(a.turn_scale, b.turn_scale, EPS)


func test_目标在气泡外时不干预() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_bubble = 5.0
	c.rotation_enabled = true
	c.rotation_bubble = 5.0
	c.magnetism_enabled = true
	c.magnetism_bubble = 5.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(12.0, 0.0), Vector2(50.0, 0.0))))
	_assert_neutral(r, "目标在气泡外")


func test_超出最大距离的目标被忽略() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.max_distance = 50.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2.ZERO, Vector2.ZERO, 80.0)))
	_assert_neutral(r, "目标太远")


func test_不可见的目标被忽略() -> void:
	var c := _config()
	c.slowdown_enabled = true
	var t := _target(Vector2.ZERO)
	t.visible = false
	_assert_neutral(AimAssist.new(c).compute(_one(t)), "目标被遮挡")


# --- 减速 ---

func test_准星压在目标上时按设定比例减速() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.5
	c.slowdown_bubble = 10.0
	c.slowdown_core = 0.4
	var r := AimAssist.new(c).compute(_one(_target(Vector2.ZERO)))
	assert_near(r.turn_scale, 0.5, EPS)
	assert_near(r.slowdown_factor, 1.0, EPS)


func test_减速核心内强度不衰减() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.5
	c.slowdown_bubble = 10.0
	c.slowdown_core = 0.4
	var aa := AimAssist.new(c)
	assert_near(aa.compute(_one(_target(Vector2(3.9, 0.0)))).slowdown_factor, 1.0, EPS)


func test_减速强度随角度误差单调衰减() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.6
	c.slowdown_bubble = 10.0
	c.slowdown_core = 0.2
	var aa := AimAssist.new(c)
	var prev := 2.0
	for i in 41:
		var d := 10.0 * i / 40.0
		var f: float = aa.compute(_one(_target(Vector2(d, 0.0)))).slowdown_factor
		assert_between(f, 0.0, 1.0, "衰减值越界")
		if f > prev + EPS:
			fail("角度误差 %.2f 处衰减不单调：%.4f > %.4f" % [d, f, prev])
			break
		prev = f
	assert_near(prev, 0.0, EPS, "气泡边缘应衰减到零")


func test_总强度按比例削弱减速() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.8
	c.master_strength = 0.5
	var r := AimAssist.new(c).compute(_one(_target(Vector2.ZERO)))
	assert_near(r.turn_scale, 1.0 - 0.4, EPS)


# --- 旋转跟枪 ---

func test_跟枪按比例跟随目标视野角速度() -> void:
	var c := _config()
	c.rotation_enabled = true
	c.rotation_strength = 0.5
	c.rotation_bubble = 10.0
	c.rotation_core = 1.0
	c.rotation_max_dps = 500.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(2.0, 0.0), Vector2(60.0, -20.0))))
	assert_vec_near(r.bonus_dps, Vector2(30.0, -10.0), 0.01)


func test_跟枪存在角速度上限() -> void:
	var c := _config()
	c.rotation_enabled = true
	c.rotation_strength = 1.0
	c.rotation_bubble = 10.0
	c.rotation_core = 1.0
	c.rotation_max_dps = 40.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(1.0, 0.0), Vector2(300.0, 0.0))))
	assert_near(r.bonus_dps.length(), 40.0, 0.01, "高速掠过时不该把视角猛甩出去")


# Apex 的标志性行为：不给移动输入就没有跟枪。这条门控若失效，
# 使用者就无法通过本工具体会"平移换跟枪"这个该作的核心技巧。
func test_跟枪可要求移动输入() -> void:
	var c := _config()
	c.rotation_enabled = true
	c.rotation_strength = 1.0
	c.rotation_core = 1.0
	c.rotation_requires_move_input = true
	var aa := AimAssist.new(c)
	var t := _target(Vector2(1.0, 0.0), Vector2(50.0, 0.0))

	var idle := aa.compute(_one(t), Vector2(0.9, 0.0), Vector2.ZERO)
	assert_vec_near(idle.bonus_dps, Vector2.ZERO, EPS, "没有移动输入时不该跟枪")

	var moving := aa.compute(_one(t), Vector2(0.9, 0.0), Vector2(1.0, 0.0))
	assert_gt(moving.bonus_dps.length(), 1.0, "有移动输入时应跟枪")


func test_跟枪可要求视角输入() -> void:
	var c := _config()
	c.rotation_enabled = true
	c.rotation_strength = 1.0
	c.rotation_core = 1.0
	c.rotation_requires_look_input = true
	var aa := AimAssist.new(c)
	var t := _target(Vector2(1.0, 0.0), Vector2(50.0, 0.0))
	assert_vec_near(aa.compute(_one(t), Vector2.ZERO).bonus_dps, Vector2.ZERO, EPS)
	assert_gt(aa.compute(_one(t), Vector2(0.9, 0.0)).bonus_dps.length(), 1.0)


func test_目标静止时跟枪不产生输出() -> void:
	var c := _config()
	c.rotation_enabled = true
	c.rotation_strength = 1.0
	c.rotation_core = 1.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(2.0, 1.0), Vector2.ZERO)))
	assert_vec_near(r.bonus_dps, Vector2.ZERO, EPS, "静止目标不该有跟枪")


# --- 磁吸 ---

func test_磁吸把准星拉向目标中心() -> void:
	var c := _config()
	c.magnetism_enabled = true
	c.magnetism_strength = 0.5
	c.magnetism_bubble = 10.0
	c.magnetism_gain = 6.0
	c.magnetism_max_dps = 100.0
	var offset := Vector2(3.0, -2.0)
	var r := AimAssist.new(c).compute(_one(_target(offset)))
	assert_gt(r.bonus_dps.length(), 0.1)
	assert_near(
		r.bonus_dps.normalized().dot(offset.normalized()), 1.0, 0.001,
		"拉力方向必须指向目标中心",
	)


func test_磁吸存在速度上限() -> void:
	var c := _config()
	c.magnetism_enabled = true
	c.magnetism_strength = 1.0
	c.magnetism_bubble = 30.0
	c.magnetism_gain = 20.0
	c.magnetism_max_dps = 25.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(20.0, 0.0))))
	assert_near(r.bonus_dps.length(), 25.0, 0.01)


func test_准星正中目标时磁吸不抖动() -> void:
	var c := _config()
	c.magnetism_enabled = true
	c.magnetism_strength = 1.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2.ZERO)))
	assert_vec_near(r.bonus_dps, Vector2.ZERO, EPS, "误差为零时不该有拉力，否则会在中心来回抖")


# --- 组合与选靶 ---

func test_减速与跟枪互不干扰() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.5
	c.slowdown_core = 1.0
	c.rotation_enabled = true
	c.rotation_strength = 1.0
	c.rotation_core = 1.0
	c.rotation_max_dps = 500.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(1.0, 0.0), Vector2(30.0, 0.0))))
	assert_near(r.turn_scale, 0.5, EPS, "减速走乘性通道")
	assert_vec_near(r.bonus_dps, Vector2(30.0, 0.0), 0.01, "跟枪走加性通道")


func test_选中角度误差最小的目标() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_bubble = 15.0
	var far_but_near_crosshair := AimTarget.make(7, Vector2(1.0, 0.0), 0.0, Vector2.ZERO, 90.0)
	var close_but_off_crosshair := AimTarget.make(9, Vector2(8.0, 0.0), 0.0, Vector2.ZERO, 5.0)
	var ts: Array[AimTarget] = [close_but_off_crosshair, far_but_near_crosshair]
	assert_eq(AimAssist.new(c).compute(ts).target_id, 7, "应按准星指向而非世界距离选靶")


func test_仅开镜时可限制辅助生效() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.5
	c.ads_only = true
	var aa := AimAssist.new(c)
	_assert_neutral(aa.compute(_one(_target(Vector2.ZERO)), Vector2.ZERO, Vector2.ZERO, false), "腰射")
	assert_near(aa.compute(_one(_target(Vector2.ZERO)), Vector2.ZERO, Vector2.ZERO, true).turn_scale, 0.5, EPS)


func test_气泡可随目标视角大小放大() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_bubble = 5.0
	c.slowdown_core = 0.0
	var t := AimTarget.make(1, Vector2(6.0, 0.0), 3.0, Vector2.ZERO, 10.0)

	c.scale_bubble_by_target_size = false
	assert_near(AimAssist.new(c).compute(_one(t)).slowdown_factor, 0.0, EPS, "关闭时 6 度已在 5 度气泡外")

	c.scale_bubble_by_target_size = true
	assert_gt(AimAssist.new(c).compute(_one(t)).slowdown_factor, 0.0, "开启后大目标气泡应扩到 8 度")


# 锁定目标与真正产生干预是两回事：目标可能落在某个机制的气泡之外，
# 或者跟枪被门控挡住。统计"辅助介入占比"时必须区分，否则会得出虚高的结论。
func test_锁定目标不等于产生干预() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_bubble = 4.0
	c.rotation_enabled = true
	c.rotation_bubble = 12.0
	c.rotation_requires_move_input = true
	# 目标在 8 度：进得了选靶用的最大气泡，但在减速气泡外，且跟枪因无移动输入被挡。
	var r := AimAssist.new(c).compute(
		_one(_target(Vector2(8.0, 0.0), Vector2(40.0, 0.0))), Vector2(0.9, 0.0), Vector2.ZERO
	)
	assert_true(r.is_active(), "应当锁定了目标")
	assert_false(r.has_effect(), "但不该产生任何实际干预")


func test_产生干预时has_effect为真() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_strength = 0.5
	c.slowdown_core = 1.0
	assert_true(AimAssist.new(c).compute(_one(_target(Vector2(1.0, 0.0)))).has_effect())


func test_结果携带调试信息() -> void:
	var c := _config()
	c.slowdown_enabled = true
	c.slowdown_core = 1.0
	var r := AimAssist.new(c).compute(_one(_target(Vector2(2.0, 1.0))))
	assert_true(r.is_active())
	assert_eq(r.target_id, 1)
	assert_vec_near(r.target_offset, Vector2(2.0, 1.0))
	assert_gt(r.slowdown_factor, 0.0)
