## 第一人称武器装配控制器 (Weapon Rig)。
##
## 挂载于玩家 Camera3D 下方，控制武器模型切换、
## 腰射与机瞄位置平滑插值、后坐力反冲阻尼物理以及视线转动惯性摆动 (Sway)。
class_name WeaponRig
extends Node3D

const WeaponModel = preload("res://game/weapon/weapon_model.gd")
const M4Model = preload("res://game/weapon/m4_model.gd")
const DesertEagleModel = preload("res://game/weapon/deagle_model.gd")

enum WeaponType {
	NONE,
	M4,
	DEAGLE,
}

var current_type: WeaponType = WeaponType.NONE
var visible_weapon: bool = true

var m4_model: M4Model
var deagle_model: DesertEagleModel
var _active_model: WeaponModel

# 姿态坐标配置
var _hip_pos := Vector3(0.18, -0.16, -0.38)
var _hip_rot := Vector3(deg_to_rad(1.5), deg_to_rad(-2.0), deg_to_rad(-1.0))

var _ads_pos := Vector3(0.0, -0.062, -0.28)
var _ads_rot := Vector3.ZERO

var _ads_weight := 0.0

# 后坐力与回复阻尼物理
var _recoil_pos := Vector3.ZERO
var _recoil_rot := Vector3.ZERO

# 视线转角惯性摆动 (Sway)
var _sway_pos := Vector3.ZERO
var _sway_rot := Vector3.ZERO
var _idle_time := 0.0


func _ready() -> void:
	m4_model = M4Model.new()
	m4_model.visible = false
	add_child(m4_model)

	deagle_model = DesertEagleModel.new()
	deagle_model.visible = false
	add_child(deagle_model)


func set_weapon(type: WeaponType) -> void:
	current_type = type
	if m4_model != null:
		m4_model.visible = (type == WeaponType.M4) and visible_weapon
	if deagle_model != null:
		deagle_model.visible = (type == WeaponType.DEAGLE) and visible_weapon

	match type:
		WeaponType.M4:
			_active_model = m4_model
			_hip_pos = Vector3(0.18, -0.16, -0.38)
			_hip_rot = Vector3(deg_to_rad(1.5), deg_to_rad(-2.0), deg_to_rad(-1.0))
			_ads_pos = Vector3(0.0, -0.065, -0.26)
			_ads_rot = Vector3.ZERO
		WeaponType.DEAGLE:
			_active_model = deagle_model
			_hip_pos = Vector3(0.16, -0.14, -0.35)
			_hip_rot = Vector3(deg_to_rad(1.2), deg_to_rad(-1.8), deg_to_rad(0.5))
			_ads_pos = Vector3(0.0, -0.052, -0.25)
			_ads_rot = Vector3.ZERO
		_:
			_active_model = null


func is_m4_visible() -> bool:
	return m4_model != null and m4_model.visible


func is_deagle_visible() -> bool:
	return deagle_model != null and deagle_model.visible


func set_ads_ratio(ads_factor: float) -> void:
	_ads_weight = clampf(ads_factor, 0.0, 1.0)


func fire() -> void:
	if _active_model == null or not visible_weapon:
		return
	_active_model.fire()

	# 施加枪械物理后坐力
	match current_type:
		WeaponType.M4:
			# M4: 高频小幅度震颤
			_recoil_pos.z += 0.022
			_recoil_pos.y += 0.003
			_recoil_rot.x += deg_to_rad(2.2)
			_recoil_rot.y += deg_to_rad(randf_range(-0.6, 0.6))
			_recoil_rot.z += deg_to_rad(randf_range(-0.4, 0.4))
		WeaponType.DEAGLE:
			# 沙鹰: 沉重大口径高扬角上跳
			_recoil_pos.z += 0.042
			_recoil_pos.y += 0.008
			_recoil_rot.x += deg_to_rad(6.8)
			_recoil_rot.y += deg_to_rad(randf_range(-0.8, 0.8))
			_recoil_rot.z += deg_to_rad(randf_range(-1.2, 1.2))


func apply_look_sway(yaw_speed: float, pitch_speed: float) -> void:
	if not visible_weapon:
		return
	# 视角移动时，枪支因惯性反向滞后
	var target_sway_x := clampf(-yaw_speed * 0.0004, -0.025, 0.025)
	var target_sway_y := clampf(pitch_speed * 0.0004, -0.020, 0.020)
	var target_rot_z := clampf(yaw_speed * 0.0006, -0.04, 0.04)

	_sway_pos.x = lerpf(_sway_pos.x, target_sway_x, 0.25)
	_sway_pos.y = lerpf(_sway_pos.y, target_sway_y, 0.25)
	_sway_rot.z = lerpf(_sway_rot.z, target_rot_z, 0.25)


func _process(delta: float) -> void:
	if _active_model == null or not visible_weapon:
		return

	# 1. 后坐力阻尼弹簧复位
	var spring_speed := 18.0 if current_type == WeaponType.M4 else 14.0
	_recoil_pos = _recoil_pos.lerp(Vector3.ZERO, spring_speed * delta)
	_recoil_rot = _recoil_rot.lerp(Vector3.ZERO, spring_speed * delta)

	# 2. 转角惯性回弹
	_sway_pos = _sway_pos.lerp(Vector3.ZERO, 10.0 * delta)
	_sway_rot = _sway_rot.lerp(Vector3.ZERO, 10.0 * delta)

	# 3. 待机微呼吸摆动
	_idle_time += delta * (1.8 if _ads_weight < 0.5 else 0.8)
	var breath_x := sin(_idle_time) * 0.0015 * (1.0 - _ads_weight * 0.8)
	var breath_y := cos(_idle_time * 2.0) * 0.0010 * (1.0 - _ads_weight * 0.8)

	# 4. 腰射与机瞄基础位置插值
	var base_pos := _hip_pos.lerp(_ads_pos, _ads_weight)
	var base_rot := _hip_rot.lerp(_ads_rot, _ads_weight)

	# 最终合成坐标
	position = base_pos + _recoil_pos + _sway_pos + Vector3(breath_x, breath_y, 0)
	rotation = base_rot + _recoil_rot + _sway_rot
