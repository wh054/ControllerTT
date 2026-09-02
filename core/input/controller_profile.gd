## 一套完整的手柄手感参数。可另存为 .tres 在多套配置间切换。
##
## 这个 Resource 是整个工具的"被调对象"——UI 面板改的是它，
## [StickProcessor] 读的是它，存盘存的也是它。
class_name ControllerProfile
extends Resource

enum CurveMode {
	RADIAL,   ## 曲线作用于摇杆模长，方向不变。对角推杆时手感一致，推荐。
	PER_AXIS, ## 曲线分别作用于两轴，可给水平和垂直配不同曲线，但会扭曲对角方向。
}

@export var profile_name: String = "默认"

@export_group("视角摇杆死区")
@export var look_deadzone: DeadzoneConfig
@export_group("移动摇杆死区")
@export var move_deadzone: DeadzoneConfig

@export_group("响应曲线")
@export var curve_mode: CurveMode = CurveMode.RADIAL:
	set(v):
		curve_mode = v
		emit_changed()
## 径向模式下这就是唯一生效的曲线；分轴模式下它负责水平。
@export var yaw_curve: ResponseCurve
## 仅分轴模式下生效，负责垂直。
@export var pitch_curve: ResponseCurve

@export_group("灵敏度（满偏时的转速，度/秒）")
@export_range(30.0, 1200.0, 1.0) var yaw_speed: float = 420.0:
	set(v):
		yaw_speed = v
		emit_changed()
@export_range(30.0, 1200.0, 1.0) var pitch_speed: float = 300.0:
	set(v):
		pitch_speed = v
		emit_changed()
## 开镜时的转速倍率。低于 1 让开镜更稳，高于 1 让开镜更灵活。
@export_range(0.1, 2.0, 0.01) var ads_multiplier: float = 0.7:
	set(v):
		ads_multiplier = v
		emit_changed()

@export_group("转向加速")
## 推满多久之后才开始加速。设长一点可以保证短促的微调不被加速污染。
@export_range(0.0, 1.0, 0.01) var accel_delay: float = 0.12:
	set(v):
		accel_delay = v
		emit_changed()
## 从开始加速到达到最大倍率所需时间。
@export_range(0.01, 2.0, 0.01) var accel_time: float = 0.30:
	set(v):
		accel_time = v
		emit_changed()
## 最大加速倍率。1.0 表示完全关闭转向加速。
@export_range(1.0, 4.0, 0.01) var accel_boost: float = 1.0:
	set(v):
		accel_boost = v
		emit_changed()

@export_group("其他")
@export var invert_x: bool = false:
	set(v):
		invert_x = v
		emit_changed()
@export var invert_y: bool = false:
	set(v):
		invert_y = v
		emit_changed()
## 输出低通滤波强度。能压掉摇杆抖动，代价是引入延迟，默认关闭。
@export_range(0.0, 0.95, 0.01) var smoothing: float = 0.0:
	set(v):
		smoothing = v
		emit_changed()


func _init() -> void:
	if look_deadzone == null:
		look_deadzone = DeadzoneConfig.new()
	if move_deadzone == null:
		move_deadzone = DeadzoneConfig.new()
		move_deadzone.inner = 0.15
		move_deadzone.outer = 0.90
	if yaw_curve == null:
		yaw_curve = ResponseCurve.new()
	if pitch_curve == null:
		pitch_curve = ResponseCurve.new()


## 分轴模式下取垂直曲线，径向模式下垂直不单独生效，返回同一条以免 UI 显示歧义。
func effective_pitch_curve() -> ResponseCurve:
	return pitch_curve if curve_mode == CurveMode.PER_AXIS else yaw_curve


func clone() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = profile_name
	p.look_deadzone = look_deadzone.duplicate_deadzone()
	p.move_deadzone = move_deadzone.duplicate_deadzone()
	p.curve_mode = curve_mode
	p.yaw_curve = yaw_curve.duplicate_curve()
	p.pitch_curve = pitch_curve.duplicate_curve()
	p.yaw_speed = yaw_speed
	p.pitch_speed = pitch_speed
	p.ads_multiplier = ads_multiplier
	p.accel_delay = accel_delay
	p.accel_time = accel_time
	p.accel_boost = accel_boost
	p.invert_x = invert_x
	p.invert_y = invert_y
	p.smoothing = smoothing
	return p


# ---------------------------------------------------------------------------
# 预设。这些数值不是从游戏里逆向出来的精确值，而是对各家公开描述的**手感近似**，
# 目的是给使用者一个熟悉的起点，之后再自行微调。切勿当成"还原"。
# ---------------------------------------------------------------------------

static func preset_linear() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = "线性 1:1"
	p.yaw_curve.type = ResponseCurve.Type.LINEAR
	p.pitch_curve.type = ResponseCurve.Type.LINEAR
	p.look_deadzone.shape = DeadzoneConfig.Shape.RADIAL
	p.look_deadzone.inner = 0.05
	return p


static func preset_cod_standard() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = "COD 标准"
	p.yaw_curve.type = ResponseCurve.Type.POWER
	p.yaw_curve.exponent = 2.0
	p.pitch_curve.type = ResponseCurve.Type.POWER
	p.pitch_curve.exponent = 2.0
	p.yaw_speed = 400.0
	p.pitch_speed = 300.0
	p.ads_multiplier = 0.8
	return p


static func preset_cod_dynamic() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = "COD 动态"
	p.yaw_curve.type = ResponseCurve.Type.REVERSE_S
	p.yaw_curve.strength = 0.55
	p.pitch_curve.type = ResponseCurve.Type.REVERSE_S
	p.pitch_curve.strength = 0.55
	p.yaw_speed = 450.0
	p.pitch_speed = 330.0
	p.accel_boost = 1.4
	return p


static func preset_apex_classic() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = "APEX 经典"
	p.yaw_curve.type = ResponseCurve.Type.POWER
	p.yaw_curve.exponent = 2.6
	p.pitch_curve.type = ResponseCurve.Type.POWER
	p.pitch_curve.exponent = 2.6
	p.yaw_speed = 440.0
	p.pitch_speed = 320.0
	p.ads_multiplier = 0.65
	return p


static func preset_apex_fine_aim() -> ControllerProfile:
	var p := ControllerProfile.new()
	p.profile_name = "APEX 精细瞄准"
	p.yaw_curve.type = ResponseCurve.Type.LINEAR
	p.pitch_curve.type = ResponseCurve.Type.LINEAR
	p.look_deadzone.inner = 0.03
	p.yaw_speed = 380.0
	p.pitch_speed = 280.0
	p.ads_multiplier = 0.6
	return p


static func all_presets() -> Array[ControllerProfile]:
	return [
		preset_linear(),
		preset_cod_standard(),
		preset_cod_dynamic(),
		preset_apex_classic(),
		preset_apex_fine_aim(),
	]
