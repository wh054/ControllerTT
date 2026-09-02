## 辅助瞄准参数。
##
## 三种机制拆开而不是合成一个"辅助强度"滑块，是本项目的核心训练价值所在：
## 使用者应当能分辨出自己的枪法依赖的到底是粘滞、跟枪还是磁吸，
## 并且能单独关掉某一项来验证。合成单一滑块会让这件事变得不可能。
class_name AimAssistConfig
extends Resource

@export var config_name: String = "自定义"

## 总开关。
@export var enabled: bool = true:
	set(v):
		enabled = v
		emit_changed()

## 总强度倍率，同时缩放三种机制。为 0 时必须与 enabled=false 完全等价
## （这条等价性由 tests/test_aim_assist.gd 钉死）。
@export_range(0.0, 1.0, 0.01) var master_strength: float = 1.0:
	set(v):
		master_strength = v
		emit_changed()

@export_group("减速 / 粘滞")
@export var slowdown_enabled: bool = true:
	set(v):
		slowdown_enabled = v
		emit_changed()
## 气泡核心处转速的降低比例。0.5 表示准星压在目标上时转速只剩一半。
@export_range(0.0, 0.95, 0.01) var slowdown_strength: float = 0.45:
	set(v):
		slowdown_strength = v
		emit_changed()
## 气泡角度半径，单位度。
@export_range(0.5, 25.0, 0.1) var slowdown_bubble: float = 7.0:
	set(v):
		slowdown_bubble = v
		emit_changed()
## 满强度核心占气泡半径的比例。核心内不衰减，核心外向边缘平滑衰减到零。
@export_range(0.0, 1.0, 0.01) var slowdown_core: float = 0.35:
	set(v):
		slowdown_core = v
		emit_changed()

@export_group("旋转跟枪")
@export var rotation_enabled: bool = true:
	set(v):
		rotation_enabled = v
		emit_changed()
## 跟随目标视野角速度的比例。1.0 表示完全跟住，目标横移时准星自己就贴着走。
@export_range(0.0, 1.0, 0.01) var rotation_strength: float = 0.5:
	set(v):
		rotation_strength = v
		emit_changed()
@export_range(0.5, 25.0, 0.1) var rotation_bubble: float = 9.0:
	set(v):
		rotation_bubble = v
		emit_changed()
@export_range(0.0, 1.0, 0.01) var rotation_core: float = 0.30:
	set(v):
		rotation_core = v
		emit_changed()
## 跟枪产生的角速度上限，防止目标高速掠过时视角被猛甩。
@export_range(0.0, 400.0, 1.0) var rotation_max_dps: float = 140.0:
	set(v):
		rotation_max_dps = v
		emit_changed()
## 需要玩家有视角输入才触发。
@export var rotation_requires_look_input: bool = false:
	set(v):
		rotation_requires_look_input = v
		emit_changed()
## 需要玩家有移动输入才触发。这是 Apex 的标志性行为——
## 不动摇杆就没有跟枪，"边平移边开镜"因此成为该作的核心技巧。
@export var rotation_requires_move_input: bool = false:
	set(v):
		rotation_requires_move_input = v
		emit_changed()

@export_group("磁吸")
@export var magnetism_enabled: bool = false:
	set(v):
		magnetism_enabled = v
		emit_changed()
## 拉向目标中心的强度。
@export_range(0.0, 1.0, 0.01) var magnetism_strength: float = 0.25:
	set(v):
		magnetism_strength = v
		emit_changed()
@export_range(0.5, 25.0, 0.1) var magnetism_bubble: float = 5.0:
	set(v):
		magnetism_bubble = v
		emit_changed()
## 拉力增益，单位 1/秒。角度误差乘以它得到基础拉取角速度。
@export_range(0.5, 20.0, 0.1) var magnetism_gain: float = 6.0:
	set(v):
		magnetism_gain = v
		emit_changed()
## 拉取角速度上限，避免远距离误差大时准星被猛拽。
@export_range(0.0, 200.0, 1.0) var magnetism_max_dps: float = 50.0:
	set(v):
		magnetism_max_dps = v
		emit_changed()

@export_group("通用")
## 超出此世界距离的目标不参与辅助，单位米。
@export_range(5.0, 300.0, 1.0) var max_distance: float = 120.0:
	set(v):
		max_distance = v
		emit_changed()
## 气泡是否随目标视角大小放大。开启后近处的大目标辅助范围更大，更接近真实游戏表现。
@export var scale_bubble_by_target_size: bool = true:
	set(v):
		scale_bubble_by_target_size = v
		emit_changed()
## 仅在开镜时启用辅助。
@export var ads_only: bool = false:
	set(v):
		ads_only = v
		emit_changed()


func clone() -> AimAssistConfig:
	var c: AimAssistConfig = duplicate(true)
	return c


# ---------------------------------------------------------------------------
# 预设。同样是对各家公开行为的**手感近似**，不是逆向出来的精确数值。
# 两套预设的本质差别：COD 偏"黏"（强减速 + 磁吸），Apex 偏"跟"（强跟枪但要求移动输入）。
# ---------------------------------------------------------------------------

static func preset_off() -> AimAssistConfig:
	var c := AimAssistConfig.new()
	c.config_name = "关闭"
	c.enabled = false
	c.master_strength = 0.0
	return c


static func preset_cod() -> AimAssistConfig:
	var c := AimAssistConfig.new()
	c.config_name = "COD 风格"
	c.master_strength = 1.0
	c.slowdown_enabled = true
	c.slowdown_strength = 0.55
	c.slowdown_bubble = 8.0
	c.slowdown_core = 0.40
	c.rotation_enabled = true
	c.rotation_strength = 0.45
	c.rotation_bubble = 8.0
	c.rotation_requires_look_input = false
	c.rotation_requires_move_input = false
	c.magnetism_enabled = true
	c.magnetism_strength = 0.30
	c.magnetism_bubble = 5.0
	c.magnetism_max_dps = 45.0
	return c


static func preset_apex() -> AimAssistConfig:
	var c := AimAssistConfig.new()
	c.config_name = "APEX 风格"
	c.master_strength = 0.6  # 对应该作 PC 端的辅助强度档位
	c.slowdown_enabled = true
	c.slowdown_strength = 0.40
	c.slowdown_bubble = 6.5
	c.slowdown_core = 0.30
	c.rotation_enabled = true
	c.rotation_strength = 0.85
	c.rotation_bubble = 10.0
	c.rotation_max_dps = 160.0
	c.rotation_requires_move_input = true  # 标志性行为：不平移就没有跟枪
	c.magnetism_enabled = false
	c.ads_only = false
	return c


static func preset_slowdown_only() -> AimAssistConfig:
	var c := AimAssistConfig.new()
	c.config_name = "仅减速（练跟枪用）"
	c.slowdown_enabled = true
	c.slowdown_strength = 0.35
	c.rotation_enabled = false
	c.magnetism_enabled = false
	return c


static func all_presets() -> Array[AimAssistConfig]:
	return [preset_off(), preset_cod(), preset_apex(), preset_slowdown_only()]
