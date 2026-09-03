## 沙漠之鹰 .50 AE 重型手枪第一人称 3D 模型。
##
## 采用拉丝钢与高硬度镀铬 PBR 材质，忠实呈现标志性多边形滑套、
## 顶部导轨、大口径枪口制退开槽以及可活动的滑套后座复进机械机构。
class_name DesertEagleModel
extends WeaponModel

var slide_node: Node3D
var _slide_offset := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if _slide_offset > 0.0:
		_slide_offset = move_toward(_slide_offset, 0.0, 0.28 * delta)
		if slide_node != null:
			slide_node.position.z = _slide_offset


func _trigger_recoil_animation() -> void:
	# 开火瞬间滑套向后抽动 4.2cm
	_slide_offset = 0.042
	if slide_node != null:
		slide_node.position.z = _slide_offset


func _build_model() -> void:
	var mat_chrome := make_mat(Color(0.65, 0.67, 0.70), 0.95, 0.18) # 高光拉丝镀铬
	var mat_black_steel := make_mat(Color(0.12, 0.12, 0.14), 0.85, 0.35)
	var mat_grip := make_mat(Color(0.08, 0.08, 0.09), 0.05, 0.85) # 橡胶防滑握把
	var mat_sight_dot := StandardMaterial3D.new()
	mat_sight_dot.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_sight_dot.albedo_color = Color(1.0, 0.45, 0.1) # 橙红战术准星点

	# 1. 下枪身与击发框架 (Frame & Trigger Guard)
	make_box(Vector3(0.034, 0.036, 0.18), Vector3(0, 0.002, -0.01), mat_black_steel, self)
	# 扳机护圈
	make_box(Vector3(0.018, 0.034, 0.055), Vector3(0, -0.024, -0.02), mat_black_steel, self)
	# 击锤 (Hammer)
	make_box(Vector3(0.012, 0.022, 0.016), Vector3(0, 0.022, 0.092), mat_chrome, self, Vector3(deg_to_rad(-25), 0, 0))

	# 2. 重型战斗握把与弹匣底板 (Combat Grip)
	var grip := make_box(Vector3(0.036, 0.11, 0.052), Vector3(0, -0.068, 0.042), mat_grip, self, Vector3(deg_to_rad(18.0), 0, 0))
	make_box(Vector3(0.038, 0.012, 0.056), Vector3(0, -0.058, 0), mat_black_steel, grip)

	# 3. 固定重型枪管总成 (Heavy Barrel Assembly)
	make_box(Vector3(0.032, 0.034, 0.12), Vector3(0, 0.026, -0.14), mat_chrome, self)
	# 大口径 .50 AE 枪管内膛
	make_cyl(0.007, 0.13, Vector3(0, 0.026, -0.14), mat_black_steel, self, Vector3(PI * 0.5, 0, 0))
	# 枪口上部一体式制退泄气开槽 (Ported Muzzle Slots)
	make_box(Vector3(0.012, 0.006, 0.035), Vector3(0, 0.044, -0.18), mat_black_steel, self)

	# 4. 可活动重型多边形滑套 (Blowback Slide Node)
	slide_node = Node3D.new()
	add_child(slide_node)

	# 滑套主体 (梯形多边形上部与抛壳窗)
	make_box(Vector3(0.036, 0.038, 0.15), Vector3(0, 0.028, 0.015), mat_chrome, slide_node)
	make_box(Vector3(0.030, 0.010, 0.14), Vector3(0, 0.048, 0.015), mat_chrome, slide_node) # 顶部棱形加宽
	make_box(Vector3(0.010, 0.018, 0.038), Vector3(0.018, 0.032, -0.02), mat_black_steel, slide_node) # 抛壳窗

	# 滑套后部防滑锯齿 (Slide Serrations)
	make_box(Vector3(0.038, 0.026, 0.036), Vector3(0, 0.028, 0.065), mat_black_steel, slide_node)

	# 5. 机械瞄具 (Combat Sights)
	# 后缺口照门 (在滑套尾部)
	make_box(Vector3(0.024, 0.016, 0.010), Vector3(0, 0.056, 0.082), mat_black_steel, slide_node)
	make_box(Vector3(0.006, 0.008, 0.012), Vector3(0, 0.061, 0.082), mat_chrome, slide_node) # U型缺口

	# 前准星柱 (在枪管前部)
	make_box(Vector3(0.006, 0.018, 0.010), Vector3(0, 0.050, -0.185), mat_black_steel, self)
	make_cyl(0.002, 0.008, Vector3(0, 0.054, -0.185), mat_sight_dot, self, Vector3(PI * 0.5, 0, 0))

	# 枪口基准点
	muzzle_marker = Marker3D.new()
	muzzle_marker.position = Vector3(0, 0.026, -0.21)
	add_child(muzzle_marker)
