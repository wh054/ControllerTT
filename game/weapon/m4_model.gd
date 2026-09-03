## M4A1 战术突击步枪第一人称 3D 模型。
##
## 采用 PBR 金属与聚合物材质，高度还原 M4 经典四向战术导轨、
## STANAG 弯弹匣、伸缩枪托、鸟笼消焰器及光纤准星。
class_name M4Model
extends WeaponModel


func _build_model() -> void:
	var mat_steel := make_mat(Color(0.13, 0.14, 0.16), 0.85, 0.35)
	var mat_polymer := make_mat(Color(0.07, 0.07, 0.08), 0.15, 0.75)
	var mat_metal_bright := make_mat(Color(0.24, 0.25, 0.28), 0.95, 0.20)
	var mat_fiber := StandardMaterial3D.new()
	mat_fiber.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_fiber.albedo_color = Color(0.2, 1.0, 0.4)

	# 1. 上下机匣 (Upper & Lower Receiver)
	make_box(Vector3(0.038, 0.052, 0.16), Vector3(0, 0.018, 0.01), mat_steel, self)
	make_box(Vector3(0.034, 0.060, 0.13), Vector3(0, -0.024, 0.02), mat_steel, self)

	# 抛壳窗与导轨
	make_box(Vector3(0.008, 0.018, 0.045), Vector3(0.020, 0.022, 0.00), mat_metal_bright, self)
	make_box(Vector3(0.024, 0.010, 0.24), Vector3(0, 0.048, -0.03), mat_steel, self)

	# 2. 战术倾角弹匣 (STANAG 30-round Mag)
	var mag := make_box(Vector3(0.028, 0.13, 0.065), Vector3(0, -0.095, -0.035), mat_steel, self, Vector3(deg_to_rad(-10.0), 0, 0))
	make_box(Vector3(0.030, 0.012, 0.068), Vector3(0, -0.062, 0), mat_polymer, mag)

	# 3. 人体工学握把 (Pistol Grip)
	make_box(Vector3(0.030, 0.11, 0.045), Vector3(0, -0.085, 0.085), mat_polymer, self, Vector3(deg_to_rad(22.0), 0, 0))

	# 4. 缓冲管与伸缩枪托 (Buffer Tube & Crane Stock)
	make_cyl(0.013, 0.16, Vector3(0, 0.020, 0.16), mat_steel, self, Vector3(PI * 0.5, 0, 0))
	make_box(Vector3(0.042, 0.085, 0.13), Vector3(0, 0.00, 0.20), mat_polymer, self)
	make_box(Vector3(0.038, 0.095, 0.018), Vector3(0, -0.005, 0.265), mat_polymer, self)

	# 5. 战术鱼骨前护木 (Quad-Rail Handguard)
	make_box(Vector3(0.044, 0.046, 0.19), Vector3(0, 0.020, -0.17), mat_steel, self)
	# 左右上下战术皮轨凹凸细节
	make_box(Vector3(0.048, 0.010, 0.18), Vector3(0, 0.020, -0.17), mat_metal_bright, self)
	make_box(Vector3(0.010, 0.050, 0.18), Vector3(0, 0.020, -0.17), mat_metal_bright, self)

	# 6. 枪管与导气箍 (Barrel & Gas Block)
	make_cyl(0.008, 0.18, Vector3(0, 0.020, -0.35), mat_steel, self, Vector3(PI * 0.5, 0, 0))
	make_box(Vector3(0.018, 0.038, 0.025), Vector3(0, 0.032, -0.32), mat_steel, self)

	# 7. 鸟笼型消焰器 (Flash Hider)
	make_cyl(0.011, 0.040, Vector3(0, 0.020, -0.45), mat_metal_bright, self, Vector3(PI * 0.5, 0, 0))

	# 8. 机械瞄具 (Iron Sights)
	# 后缺口照门 (Rear Sight)
	make_box(Vector3(0.024, 0.024, 0.012), Vector3(0, 0.062, 0.08), mat_steel, self)
	make_box(Vector3(0.006, 0.014, 0.014), Vector3(0, 0.070, 0.08), mat_polymer, self) # 瞄准中心镂空

	# 前准星柱与光纤准星 (Front Sight with Green Fiber)
	make_box(Vector3(0.004, 0.026, 0.008), Vector3(0, 0.058, -0.32), mat_steel, self)
	make_cyl(0.002, 0.012, Vector3(0, 0.068, -0.32), mat_fiber, self, Vector3(PI * 0.5, 0, 0))

	# 枪口基准点
	muzzle_marker = Marker3D.new()
	muzzle_marker.position = Vector3(0, 0.020, -0.48)
	add_child(muzzle_marker)
