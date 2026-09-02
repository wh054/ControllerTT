extends TestCase


func suite_name() -> String:
	return "命中判定"


func test_正前方的球被命中() -> void:
	var d := HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 1.0)
	assert_near(d, 9.0, 0.001, "应命中球的近侧表面")


func test_偏开的射线不命中() -> void:
	var d := HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(3, 0, -10), 1.0)
	assert_near(d, -1.0, EPS)


func test_擦边命中与擦边未命中() -> void:
	var center := Vector3(0, 0, -10)
	assert_gt(HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, center + Vector3(0.99, 0, 0), 1.0), 0.0)
	assert_near(HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, center + Vector3(1.01, 0, 0), 1.0), -1.0, EPS)


func test_背后的球不命中() -> void:
	var d := HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 10), 1.0)
	assert_near(d, -1.0, EPS)


func test_起点在球内视为命中() -> void:
	assert_near(HitTest.ray_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -0.5), 1.0), 0.0, EPS)


# 准星正对目标时角度误差必须严格为零，否则磁吸会在中心持续抖动。
func test_正对目标时角度误差为零() -> void:
	var offset := HitTest.angular_offset(Vector3(0, 0, -10), Basis.IDENTITY)
	assert_vec_near(offset, Vector2.ZERO, 0.001)


func test_角度误差的符号约定() -> void:
	# 摄像机朝 -Z，目标在右上方：偏航为正、俯仰为正。
	var offset := HitTest.angular_offset(Vector3(1, 1, -10), Basis.IDENTITY)
	assert_gt(offset.x, 0.0, "目标在右侧时偏航应为正")
	assert_gt(offset.y, 0.0, "目标在上方时俯仰应为正")


func test_角度误差的数值() -> void:
	# 正右方 10 米、正前方 10 米 → 偏航 45 度。
	var offset := HitTest.angular_offset(Vector3(10, 0, -10), Basis.IDENTITY)
	assert_near(offset.x, 45.0, 0.001)
	assert_near(offset.y, 0.0, 0.001)


func test_角度误差随摄像机朝向变化() -> void:
	# 摄像机向左转 45 度后，正前方 -Z 的目标应落在右侧 45 度。
	var basis := Basis(Vector3.UP, deg_to_rad(45.0))
	var offset := HitTest.angular_offset(Vector3(0, 0, -10), basis)
	assert_near(offset.x, 45.0, 0.001)


func test_视角半径随距离缩小() -> void:
	var near := HitTest.angular_radius(0.5, 10.0)
	var far := HitTest.angular_radius(0.5, 40.0)
	assert_gt(near, far)
	assert_near(near, rad_to_deg(asin(0.05)), 0.001)


func test_贴脸时视角半径不发散() -> void:
	assert_near(HitTest.angular_radius(1.0, 0.5), 90.0, EPS, "距离小于半径时应夹住而非产生 NaN")
