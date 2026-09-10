## 训练场地。全程序化生成，不依赖任何美术资源。
##
## 视觉刻意做得朴素：地面网格提供距离与横移的参考，除此之外没有任何装饰。
## 训练场里多余的视觉元素只会干扰对靶机运动的判读。
class_name Arena
extends Node3D

const FLOOR_Y := 0.0
const HALF := 40.0
const WALL_HEIGHT := 10.0
const GRID_STEP := 2.0

const _FLOOR_COLOR := Color(0.09, 0.10, 0.12)
const _GRID_COLOR := Color(0.18, 0.20, 0.25, 0.4)
const _WALL_COLOR := Color(0.13, 0.14, 0.17)
const _BOOTH_STEEL := Color(0.16, 0.17, 0.20)
const _CAUTION_YELLOW := Color(0.95, 0.70, 0.12)
const _SAFETY_RED := Color(0.85, 0.20, 0.20)

const DISTANCE_STEPS: Array[float] = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0]


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_grid()
	_build_walls()
	_build_light()
	_build_shooting_booth()
	_build_distance_markers()
	_build_bullet_trap()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 靶机是自发光的，开辉光才能让它在暗背景里足够醒目。
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	var node := WorldEnvironment.new()
	node.environment = env
	add_child(node)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _FLOOR_COLOR
	mat.roughness = 0.95

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


# 用 ImmediateMesh 画线网格，省掉一张贴图，也便于随时改网格间距。
func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _GRID_COLOR
	mat.vertex_color_use_as_albedo = true

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var steps := int(HALF * 2.0 / GRID_STEP)
	for i in steps + 1:
		var p := -HALF + i * GRID_STEP
		mesh.surface_add_vertex(Vector3(p, 0.02, -HALF))
		mesh.surface_add_vertex(Vector3(p, 0.02, HALF))
		mesh.surface_add_vertex(Vector3(-HALF, 0.02, p))
		mesh.surface_add_vertex(Vector3(HALF, 0.02, p))
	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _build_walls() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _WALL_COLOR
	mat.roughness = 0.9

	var offsets := [
		Vector3(0.0, WALL_HEIGHT * 0.5, -HALF),
		Vector3(0.0, WALL_HEIGHT * 0.5, HALF),
		Vector3(-HALF, WALL_HEIGHT * 0.5, 0.0),
		Vector3(HALF, WALL_HEIGHT * 0.5, 0.0),
	]
	var sizes := [
		Vector3(HALF * 2.0, WALL_HEIGHT, 0.5),
		Vector3(HALF * 2.0, WALL_HEIGHT, 0.5),
		Vector3(0.5, WALL_HEIGHT, HALF * 2.0),
		Vector3(0.5, WALL_HEIGHT, HALF * 2.0),
	]
	for i in offsets.size():
		var box := BoxMesh.new()
		box.size = sizes[i]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = offsets[i]
		add_child(mi)


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 0.75
	light.shadow_enabled = true
	add_child(light)


## 构建全景开放式战术射击台与射击警戒线 (保持设计射距，左右自由横移无侧板阻挡)
func _build_shooting_booth() -> void:
	var total_w := HALF * 2.0

	# 1. 射击席防滑橡胶地垫 (通铺整条射击线)
	var mat_mesh := BoxMesh.new()
	mat_mesh.size = Vector3(total_w, 0.015, 1.8)
	var rubber_mat := StandardMaterial3D.new()
	rubber_mat.albedo_color = Color(0.07, 0.07, 0.08)
	rubber_mat.roughness = 0.95
	var mat_inst := MeshInstance3D.new()
	mat_inst.mesh = mat_mesh
	mat_inst.material_override = rubber_mat
	mat_inst.position = Vector3(0.0, 0.008, 0.45)
	add_child(mat_inst)

	# 2. 地面射击警戒线 (FIRING LINE，位于 Z = -0.50m，通长贯穿左右)
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(total_w, 0.005, 0.12)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = _SAFETY_RED
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.8, 0.15, 0.15)
	line_mat.emission_energy_multiplier = 0.4
	var line_inst := MeshInstance3D.new()
	line_inst.mesh = line_mesh
	line_inst.material_override = line_mat
	line_inst.position = Vector3(0.0, 0.025, -0.50)
	add_child(line_inst)

	# 黄色辅助警示边线
	var yellow_stripe := BoxMesh.new()
	yellow_stripe.size = Vector3(total_w, 0.004, 0.03)
	var yellow_mat := StandardMaterial3D.new()
	yellow_mat.albedo_color = _CAUTION_YELLOW
	var yellow_inst := MeshInstance3D.new()
	yellow_inst.mesh = yellow_stripe
	yellow_inst.material_override = yellow_mat
	yellow_inst.position = Vector3(0.0, 0.026, -0.42)
	add_child(yellow_inst)

	# 3. 战术射击长台 (Shooting Bench, 高 0.96m，位于 Z = -0.95m，平视自然露在屏幕下边缘)
	var bench_top := BoxMesh.new()
	bench_top.size = Vector3(total_w, 0.08, 0.50)
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = _BOOTH_STEEL
	bench_mat.metallic = 0.6
	bench_mat.roughness = 0.45
	var bench_inst := MeshInstance3D.new()
	bench_inst.mesh = bench_top
	bench_inst.material_override = bench_mat
	bench_inst.position = Vector3(0.0, 0.96, -0.95)
	add_child(bench_inst)

	# 射击长台黄色防撞包边
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(total_w, 0.03, 0.03)
	var trim_inst := MeshInstance3D.new()
	trim_inst.mesh = trim_mesh
	trim_inst.material_override = yellow_mat
	trim_inst.position = Vector3(0.0, 1.00, -1.20)
	add_child(trim_inst)

	# 射击长台立柱支撑腿 (每 4 米一组均匀排布)
	for lx in range(-int(HALF) + 4, int(HALF), 4):
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.08, 0.96, 0.08)
		var leg_inst := MeshInstance3D.new()
		leg_inst.mesh = leg_mesh
		leg_inst.material_override = bench_mat
		leg_inst.position = Vector3(float(lx), 0.48, -0.95)
		add_child(leg_inst)

	# 4. 射击线专属下照战术阵列灯 (保证左右走位时各段靶位均有均匀柔和顶光)
	for spot_x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(spot_x, 3.2, 0.2)
		spot.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
		spot.light_color = Color(1.0, 0.96, 0.90)
		spot.light_energy = 1.6
		spot.spot_range = 6.0
		spot.spot_angle = 55.0
		spot.spot_attenuation = 1.0
		add_child(spot)


## 构建靶道纵深距离标尺体系 (10m, 15m, 20m, 25m, 30m, 35m)
func _build_distance_markers() -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.35, 0.45, 0.60, 0.7)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for dist in DISTANCE_STEPS:
		var z_pos: float = -dist

		# 地面横向刻度线 (贯穿开阔靶道)
		var marker_line := BoxMesh.new()
		marker_line.size = Vector3(32.0, 0.006, 0.08)
		var line_inst := MeshInstance3D.new()
		line_inst.mesh = marker_line
		line_inst.material_override = line_mat
		line_inst.position = Vector3(0.0, 0.024, z_pos)
		add_child(line_inst)

		# 左右两侧的距离立柱与 3D 距离指示标牌 (置于靶机刷新区 ±15m 外侧，避免遮挡视线)
		for side_x in [-15.0, 15.0]:
			# 标尺立柱
			var post := BoxMesh.new()
			post.size = Vector3(0.08, 1.2, 0.08)
			var post_inst := MeshInstance3D.new()
			post_inst.mesh = post
			post_inst.material_override = line_mat
			post_inst.position = Vector3(side_x, 0.6, z_pos)
			add_child(post_inst)

			# 3D 发光距离标牌 (如 "10M", "20M", "30M")
			var lbl := Label3D.new()
			lbl.text = "%dM" % int(dist)
			lbl.font_size = 40
			lbl.modulate = Color(0.4, 0.85, 1.0, 0.9)
			lbl.outline_modulate = Color(0.02, 0.06, 0.12)
			lbl.outline_size = 8
			lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			lbl.position = Vector3(side_x, 1.35, z_pos)
			add_child(lbl)


## 构建防跳弹吸能靶墙 (Bullet Trap) 与战术背光
func _build_bullet_trap() -> void:
	var trap_mat := StandardMaterial3D.new()
	trap_mat.albedo_color = Color(0.08, 0.09, 0.11)
	trap_mat.metallic = 0.7
	trap_mat.roughness = 0.85

	# 底部斜向导流阻弹板
	var deflector := BoxMesh.new()
	deflector.size = Vector3(HALF * 1.8, 3.5, 1.0)
	var deflector_inst := MeshInstance3D.new()
	deflector_inst.mesh = deflector
	deflector_inst.material_override = trap_mat
	deflector_inst.position = Vector3(0.0, 1.8, -HALF + 1.2)
	deflector_inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	add_child(deflector_inst)

	# 靶墙底部冷光 LED 氛围照明 (突出靶机剪影)
	var back_light := OmniLight3D.new()
	back_light.position = Vector3(0.0, 0.8, -HALF + 3.0)
	back_light.light_color = Color(0.20, 0.50, 0.90)
	back_light.light_energy = 1.6
	back_light.omni_range = 25.0
	back_light.omni_attenuation = 1.2
	add_child(back_light)
