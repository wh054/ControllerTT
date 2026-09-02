## 全局状态（自动加载为 App）：当前的手柄配置、辅助瞄准配置与场景配置。
##
## 用单例而不是层层传参，是因为参数面板、玩家控制器、HUD 三处都要读同一份配置，
## 且面板上任何一次改动都要求立即生效——单例 + 信号是这里最短的路径。
extends Node

signal profile_changed
signal assist_changed
signal scenario_changed

const PROFILE_PATH := "user://profile.tres"
const ASSIST_PATH := "user://aim_assist.tres"
const SCENARIO_PATH := "user://scenario.tres"

var profile: ControllerProfile
var assist: AimAssistConfig
var scenario: ScenarioDef


func _ready() -> void:
	_ensure_controller_ui_actions()
	profile = _load(PROFILE_PATH) as ControllerProfile
	if profile == null:
		profile = ControllerProfile.preset_cod_standard()
	assist = _load(ASSIST_PATH) as AimAssistConfig
	if assist == null:
		assist = AimAssistConfig.preset_off()
	scenario = _load(SCENARIO_PATH) as ScenarioDef
	if scenario == null:
		scenario = ScenarioDef.preset_tracking()


# Godot 的内置方向导航默认包含 D-pad / 左摇杆，但 ui_accept 与 ui_cancel
# 只有键盘映射。运行时补齐 A / B，保留引擎原有的 Enter、Space 与 Esc。
func _ensure_controller_ui_actions() -> void:
	_add_ui_button_if_missing(&"ui_accept", JOY_BUTTON_A)
	_add_ui_button_if_missing(&"ui_cancel", JOY_BUTTON_B)


func _add_ui_button_if_missing(action: StringName, button: JoyButton) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


## 参数被面板改动后调用。三个通知分开，避免改一个滑块导致场景重开。
func notify_profile_changed() -> void:
	profile_changed.emit()


func notify_assist_changed() -> void:
	assist_changed.emit()


func notify_scenario_changed() -> void:
	scenario_changed.emit()


func apply_profile_preset(p: ControllerProfile) -> void:
	profile = p
	notify_profile_changed()


func apply_assist_preset(c: AimAssistConfig) -> void:
	assist = c
	notify_assist_changed()


func apply_scenario_preset(d: ScenarioDef) -> void:
	scenario = d
	notify_scenario_changed()


func save_all() -> void:
	ResourceSaver.save(profile, PROFILE_PATH)
	ResourceSaver.save(assist, ASSIST_PATH)
	ResourceSaver.save(scenario, SCENARIO_PATH)


func _load(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	# 存档来自上一版本时字段可能对不上，读失败就退回内置预设，不要让工具打不开。
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_all()
