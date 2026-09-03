## 第一人称武器模型基类。
##
## 提供枪口火光挂载点、瞬时动态光照以及几何体构建辅助工具。
class_name WeaponModel
extends Node3D

var muzzle_marker: Marker3D
var flash_node: Node3D
var flash_light: OmniLight3D
var _flash_timer := 0.0


func _init() -> void:
	_build_model()
	_setup_muzzle_flash()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			if flash_node != null:
				flash_node.visible = false
			if flash_light != null:
				flash_light.visible = false


func fire() -> void:
	_trigger_recoil_animation()
	if flash_node != null:
		flash_node.visible = true
		flash_node.rotation.z = randf() * TAU
		var s := randf_range(0.85, 1.25)
		flash_node.scale = Vector3(s, s, s)
	if flash_light != null:
		flash_light.visible = true
	_flash_timer = 0.045


func _build_model() -> void:
	pass


func _trigger_recoil_animation() -> void:
	pass


func _setup_muzzle_flash() -> void:
	if muzzle_marker == null:
		muzzle_marker = Marker3D.new()
		muzzle_marker.position = Vector3(0, 0, -0.6)
		add_child(muzzle_marker)

	flash_node = Node3D.new()
	flash_node.visible = false
	muzzle_marker.add_child(flash_node)

	# 枪口十字星辉光材质
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.25)
	mat.emission_energy_multiplier = 3.0

	# 两个相互交叉的菱形/平面构成十字星火光
	for rot in [0.0, PI * 0.5]:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.14, 0.07)
		quad.mesh = qm
		quad.material_override = mat
		quad.rotation.z = rot
		quad.position.z = -0.04
		flash_node.add_child(quad)

	# 枪口瞬时动态点光源（照亮枪身与周围环境）
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.82, 0.4)
	flash_light.light_energy = 2.5
	flash_light.omni_range = 3.5
	flash_light.visible = false
	muzzle_marker.add_child(flash_light)


# 辅助工具：创建 PBR 材质
static func make_mat(color: Color, metallic: float = 0.8, roughness: float = 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


# 辅助工具：创建立方体部件
static func make_box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	inst.mesh = bm
	inst.material_override = mat
	inst.position = pos
	if rot != Vector3.ZERO:
		inst.rotation = rot
	parent.add_child(inst)
	return inst


# 辅助工具：创建圆柱部件
static func make_cyl(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	inst.mesh = cm
	inst.material_override = mat
	inst.position = pos
	if rot != Vector3.ZERO:
		inst.rotation = rot
	parent.add_child(inst)
	return inst
