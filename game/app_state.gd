## 全局状态（自动加载为 App）：当前的手柄配置、辅助瞄准配置与场景配置。
##
## 用单例而不是层层传参，是因为参数面板、玩家控制器、HUD 三处都要读同一份配置，
## 且面板上任何一次改动都要求立即生效——单例 + 信号是这里最短的路径。
class_name AppState
extends Node

const VideoConfig = preload("res://core/video/video_config.gd")

signal profile_changed
signal assist_changed
signal scenario_changed
signal video_changed
signal weapon_visual_changed
signal audio_changed

enum WeaponVisualMode {
	AUTO_BY_SCENARIO, # 自动（全自动为 M4，半自动/精度为沙鹰）
	FORCE_M4,         # 强制使用 M4 突击步枪
	FORCE_DEAGLE,     # 强制使用 沙漠之鹰 .50 AE
	HIDDEN,           # 隐藏枪模（纯准星模式）
}

const WEAPON_VISUAL_LABELS := [
	"根据场景自动 (连发场景M4 · 点射场景沙鹰)",
	"强制手持 M4 突击步枪",
	"强制手持 沙漠之鹰 .50 AE",
	"隐藏枪模 (纯准星练枪)",
]

const PROFILE_PATH := "user://profile.tres"
const ASSIST_PATH := "user://aim_assist.tres"
const SCENARIO_PATH := "user://scenario.tres"
const VIDEO_PATH := "user://video.tres"

var profile: ControllerProfile
var assist: AimAssistConfig
var scenario: ScenarioDef
var video: VideoConfig

var weapon_visual: WeaponVisualMode = WeaponVisualMode.AUTO_BY_SCENARIO
var sfx_volume: float = 0.85
var sfx_enabled: bool = true


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
	video = _load(VIDEO_PATH) as VideoConfig
	if video == null:
		video = VideoConfig.preset_default()
	apply_video_hardware()


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


func notify_video_changed() -> void:
	apply_video_hardware()
	video_changed.emit()


func notify_weapon_visual_changed() -> void:
	weapon_visual_changed.emit()


func notify_audio_changed() -> void:
	audio_changed.emit()


func apply_profile_preset(p: ControllerProfile) -> void:
	profile = p
	notify_profile_changed()


func apply_assist_preset(c: AimAssistConfig) -> void:
	assist = c
	notify_assist_changed()


func apply_scenario_preset(d: ScenarioDef) -> void:
	scenario = d
	notify_scenario_changed()


func apply_video_preset(v: VideoConfig) -> void:
	video = v
	notify_video_changed()


func apply_video_hardware() -> void:
	if video == null:
		return
	# 1. 窗口模式与全屏
	match video.display_mode:
		VideoConfig.DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if video.resolution_index >= 0 and video.resolution_index < VideoConfig.RESOLUTIONS.size():
				var res := VideoConfig.RESOLUTIONS[video.resolution_index]
				DisplayServer.window_set_size(res)
		VideoConfig.DisplayMode.BORDERLESS_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		VideoConfig.DisplayMode.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# 2. 垂直同步
	match video.vsync:
		VideoConfig.VSyncMode.DISABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		VideoConfig.VSyncMode.ENABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		VideoConfig.VSyncMode.ADAPTIVE:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)

	# 3. 帧率上限与刷新率同步
	var fps_limit := 0
	if video.max_fps_index >= 0 and video.max_fps_index < VideoConfig.FPS_LIMITS.size():
		var raw_val: int = VideoConfig.FPS_LIMITS[video.max_fps_index]
		if raw_val == -1:
			fps_limit = roundi(video.target_refresh_rate())
		else:
			fps_limit = raw_val
	Engine.max_fps = fps_limit

	# 4. 3D 抗锯齿
	var vp := get_viewport()
	if vp != null:
		match video.msaa:
			VideoConfig.AntiAliasing.MSAA_DISABLED:
				vp.msaa_3d = Viewport.MSAA_DISABLED
			VideoConfig.AntiAliasing.MSAA_2X:
				vp.msaa_3d = Viewport.MSAA_2X
			VideoConfig.AntiAliasing.MSAA_4X:
				vp.msaa_3d = Viewport.MSAA_4X
			VideoConfig.AntiAliasing.MSAA_8X:
				vp.msaa_3d = Viewport.MSAA_8X


func save_all() -> void:
	ResourceSaver.save(profile, PROFILE_PATH)
	ResourceSaver.save(assist, ASSIST_PATH)
	ResourceSaver.save(scenario, SCENARIO_PATH)
	ResourceSaver.save(video, VIDEO_PATH)


func _load(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	# 存档来自上一版本时字段可能对不上，读失败就退回内置预设，不要让工具打不开。
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_all()
