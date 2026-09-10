## 靶场空间边界与角色位移约束单元测试。
class_name TestRangeMovement
extends TestCase

const RangeBounds = preload("res://core/range/range_bounds.gd")


func suite_name() -> String:
	return "靶场走位限制"


func test_bounds_by_mode() -> void:
	# 1. 靶场模式 (默认：左右不限，前后保距)
	var b_lane := RangeBounds.get_bounds(RangeBounds.Mode.RANGE_DISTANCE, 13.0)
	assert_near(b_lane.x_min, -13.0, 0.001, "靶场模式左边界不设额外限制，与场地全宽一致")
	assert_near(b_lane.x_max, 13.0, 0.001, "靶场模式右边界不设额外限制，与场地全宽一致")
	assert_near(b_lane.z_min, -0.15, 0.001, "靶场模式前沿应为 -0.15m (严格保持射击距离)")
	assert_near(b_lane.z_max, 0.25, 0.001, "靶场模式后沿应为 0.25m")

	# 2. 固定站位
	var b_fixed := RangeBounds.get_bounds(RangeBounds.Mode.STATION_FIXED, 13.0)
	assert_near(b_fixed.x_min, 0.0, 0.001, "固定站位 X 边界应为 0")
	assert_near(b_fixed.x_max, 0.0, 0.001, "固定站位 X 边界应为 0")
	assert_near(b_fixed.z_min, 0.0, 0.001, "固定站位 Z 边界应为 0")
	assert_near(b_fixed.z_max, 0.0, 0.001, "固定站位 Z 边界应为 0")

	# 3. 自由模式
	var b_free := RangeBounds.get_bounds(RangeBounds.Mode.FREE, 13.0)
	assert_near(b_free.x_min, -13.0, 0.001, "自由模式 X 应为全场")
	assert_near(b_free.x_max, 13.0, 0.001, "自由模式 X 应为全场")
	assert_near(b_free.z_min, -13.0, 0.001, "自由模式 Z 应为全场")
	assert_near(b_free.z_max, 13.0, 0.001, "自由模式 Z 应为全场")


func test_forward_rush_is_strictly_blocked() -> void:
	# 模拟玩家向前推动摇杆，试图冲到靶机脸前进行近距离射击
	var forward_pos := Vector3(0.0, 1.7, -15.0)

	# 靶场模式下，Z 必须被拦截在 -0.15m，绝对禁止越界破坏设计射距
	var clamped := RangeBounds.clamp_position(forward_pos, RangeBounds.Mode.RANGE_DISTANCE, 1.7, 13.0)
	assert_near(clamped.z, -0.15, 0.001, "前移应被严格锁死在射击前沿 -0.15m，保持射距")
	assert_near(clamped.x, 0.0, 0.001, "中心站位 X 应保持 0")

	# 左右任意站位下向前冲，Z 均严格保距
	var side_forward := Vector3(8.0, 1.7, -10.0)
	var clamped_side := RangeBounds.clamp_position(side_forward, RangeBounds.Mode.RANGE_DISTANCE, 1.7, 13.0)
	assert_near(clamped_side.z, -0.15, 0.001, "侧方前移同样严格保距在 -0.15m")
	assert_near(clamped_side.x, 8.0, 0.001, "横向位置应自由保留")


func test_strafe_unrestricted() -> void:
	# 左右大幅度自由走位
	var left_rush := Vector3(-8.0, 1.7, 0.0)
	var right_rush := Vector3(8.0, 1.7, 0.0)

	# 靶场模式不限制左右移动范围（只要在 arena_half 内均自由通行）
	var c_left := RangeBounds.clamp_position(left_rush, RangeBounds.Mode.RANGE_DISTANCE, 1.7, 13.0)
	assert_near(c_left.x, -8.0, 0.001, "靶场模式左横移不限制在小靶位内")
	var c_right := RangeBounds.clamp_position(right_rush, RangeBounds.Mode.RANGE_DISTANCE, 1.7, 13.0)
	assert_near(c_right.x, 8.0, 0.001, "靶场模式右横移不限制在小靶位内")

	# 超出场地边界时由 arena_half 兜底
	var over_arena := Vector3(20.0, 1.7, 0.0)
	var c_over := RangeBounds.clamp_position(over_arena, RangeBounds.Mode.RANGE_DISTANCE, 1.7, 13.0)
	assert_near(c_over.x, 13.0, 0.001, "超出场地由边界限制")

	# 固定站位完全不允许位移
	var c_fixed := RangeBounds.clamp_position(right_rush, RangeBounds.Mode.STATION_FIXED, 1.7, 13.0)
	assert_near(c_fixed.x, 0.0, 0.001, "固定站位 X 应严格为 0")
	assert_near(c_fixed.z, 0.0, 0.001, "固定站位 Z 应严格为 0")


func test_is_in_bounds_detection() -> void:
	assert_true(
		RangeBounds.is_in_bounds(Vector3(0.0, 1.7, 0.0), RangeBounds.Mode.RANGE_DISTANCE),
		"靶场中心点应在范围内"
	)
	assert_true(
		RangeBounds.is_in_bounds(Vector3(8.0, 1.7, 0.1), RangeBounds.Mode.RANGE_DISTANCE),
		"大范围横移点应在范围内"
	)
	assert_false(
		RangeBounds.is_in_bounds(Vector3(0.0, 1.7, -5.0), RangeBounds.Mode.RANGE_DISTANCE),
		"冲入靶区深处不应在范围内"
	)
	assert_false(
		RangeBounds.is_in_bounds(Vector3(20.0, 1.7, 0.0), RangeBounds.Mode.RANGE_DISTANCE),
		"超出场地边界不应在范围内"
	)
