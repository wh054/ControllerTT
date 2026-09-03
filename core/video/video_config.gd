## 画面与视频设置数据模型。
##
## 维护视场角（FOV）、显示模式、分辨率、垂直同步与帧率限制。
## 严格采用现代主流 FPS（Apex / Overwatch / COD / CS）通用的 16:9 水平视场角标定，
## 并通过数学投影准确转换为摄像机的垂直视场角，从根本上解决广角拉伸与鱼眼畸变。
class_name VideoConfig
extends Resource

enum DisplayMode {
	WINDOWED = 0,             ## 窗口化
	BORDERLESS_FULLSCREEN = 1, ## 无边框全屏
	EXCLUSIVE_FULLSCREEN = 2,  ## 独占全屏
}

enum VSyncMode {
	DISABLED = 0,  ## 关闭（FPS 训练推荐，输入延迟最低）
	ENABLED = 1,   ## 开启
	ADAPTIVE = 2,  ## 自适应
}

enum AntiAliasing {
	MSAA_DISABLED = 0,
	MSAA_2X = 1,
	MSAA_4X = 2,
	MSAA_8X = 3,
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const RESOLUTION_LABELS: Array[String] = [
	"1280 × 720 (720P · 16:9)",
	"1600 × 900 (900P · 16:9)",
	"1920 × 1080 (1080P · 16:9)",
	"2560 × 1440 (2K · 16:9)",
	"3840 × 2160 (4K · 16:9)",
	"当前屏幕原生分辨率",
]

const REFRESH_RATES: Array[int] = [0, 60, 120, 144, 165, 240, 360]
const REFRESH_RATE_LABELS: Array[String] = [
	"自动检测 / 匹配当前显示器物理刷新率 (推荐)",
	"60 Hz (标准 60Hz 办公/普通显示器)",
	"120 Hz (120Hz 高刷屏)",
	"144 Hz (主流电竞 144Hz)",
	"165 Hz (进阶电竞 165Hz)",
	"240 Hz (职业赛级 240Hz)",
	"360 Hz (极限旗舰 360Hz)",
]

const FPS_LIMITS: Array[int] = [0, -1, 60, 120, 144, 165, 240, 360]
const FPS_LABELS: Array[String] = [
	"无限制 (最低输入延迟 · 推荐)",
	"与刷新率同步 (Sync Hz)",
	"60 FPS",
	"120 FPS",
	"144 FPS",
	"165 FPS",
	"240 FPS",
	"360 FPS",
]

## 水平视场角（度，以 16:9 为基准标定）。主流 FPS 常用 90° ~ 110°。
@export_range(60.0, 120.0, 1.0) var fov: float = 103.0

## 开镜（ADS）视场角缩放比率。0.55 即开镜后视场缩小为腰射的 55%。
@export_range(0.3, 0.9, 0.05) var ads_fov_ratio: float = 0.55

## 玩家站姿视线高度，单位米。默认 1.7m 对应标准人体工学眼高。
@export_range(1.4, 2.0, 0.05) var eye_height: float = 1.7

## 目标渲染与输出分辨率（Vector2i.ZERO 表示自适应屏幕原生）
@export var target_resolution: Vector2i = Vector2i.ZERO

## 目标屏幕刷新率（0 表示自适应屏幕硬件原生刷新率）
@export var target_hz: int = 0

## 分辨率预设索引（保留向后兼容）
@export var resolution_index: int = 2

## 目标刷新率索引（保留向后兼容）
@export var refresh_rate_index: int = 0

## 显示模式：窗口化 / 无边框全屏 / 独占全屏
@export var display_mode: DisplayMode = DisplayMode.WINDOWED

## 垂直同步模式。训练器首选关闭以压低摇杆采样与视角更新延迟。
@export var vsync: VSyncMode = VSyncMode.DISABLED

## 最大帧率上限。0 为不设限，-1 为与刷新率同步。
@export var max_fps_index: int = 0

## 3D 抗锯齿品质
@export var msaa: AntiAliasing = AntiAliasing.MSAA_2X


func clone() -> Resource:
	return duplicate(true)


## 获取当前显示器实际支持的所有分辨率列表（严格不大于屏幕物理尺寸，不支持的不出现）
static func get_supported_resolutions(override_screen_size: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var screen_size := override_screen_size
	if screen_size == Vector2i.ZERO:
		screen_size = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2i(1920, 1080)

	var candidates: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]

	var supported: Array[Vector2i] = []
	var has_native := false
	for c in candidates:
		if c.x <= screen_size.x and c.y <= screen_size.y:
			supported.append(c)
			if c == screen_size:
				has_native = true

	if not has_native and screen_size != Vector2i.ZERO:
		supported.append(screen_size)

	return supported


## 获取支持的分辨率中文说明标签
static func get_resolution_labels(supported: Array[Vector2i], override_screen_size: Vector2i = Vector2i.ZERO) -> PackedStringArray:
	var screen_size := override_screen_size
	if screen_size == Vector2i.ZERO:
		screen_size = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2i(1920, 1080)

	var labels := PackedStringArray()
	for res in supported:
		var name := ""
		if res == Vector2i(1280, 720):
			name = "720P · 16:9"
		elif res == Vector2i(1600, 900):
			name = "900P · 16:9"
		elif res == Vector2i(1920, 1080):
			name = "1080P · 16:9"
		elif res == Vector2i(2560, 1440):
			name = "2K · 16:9"
		elif res == Vector2i(3840, 2160):
			name = "4K · 16:9"
		else:
			name = "自适应比例"

		if res == screen_size:
			labels.append("%d × %d (%s · 屏幕物理原生)" % [res.x, res.y, name])
		else:
			labels.append("%d × %d (%s)" % [res.x, res.y, name])
	return labels


## 获取当前显示器实际支持的所有刷新率列表（严格不大于屏幕最高物理刷新率，不可达的不出现）
static func get_supported_refresh_rates(override_hz: float = 0.0) -> Array[int]:
	var native_hz := override_hz
	if native_hz <= 0.0:
		native_hz = DisplayServer.screen_get_refresh_rate()
	if native_hz <= 0.0:
		native_hz = 60.0

	var standard_rates: Array[int] = [60, 75, 120, 144, 165, 240, 360]
	var supported: Array[int] = [0] # 0 代表自动匹配原生

	var native_int := roundi(native_hz)
	var has_native := false

	for r in standard_rates:
		if float(r) <= native_hz + 1.0:
			supported.append(r)
			if r == native_int:
				has_native = true

	if not has_native and native_int > 0:
		supported.append(native_int)
		supported.sort()

	return supported


## 获取支持的刷新率中文说明标签
static func get_refresh_rate_labels(supported: Array[int], override_hz: float = 0.0) -> PackedStringArray:
	var native_hz := override_hz
	if native_hz <= 0.0:
		native_hz = DisplayServer.screen_get_refresh_rate()
	if native_hz <= 0.0:
		native_hz = 60.0

	var labels := PackedStringArray()
	for r in supported:
		if r == 0:
			labels.append("自动匹配硬件 (当前物理: %.0f Hz · 推荐)" % native_hz)
		else:
			var tag := "高刷" if r >= 120 else "标准"
			if absf(float(r) - native_hz) < 1.0:
				tag = "物理原生"
			labels.append("%d Hz (%s)" % [r, tag])
	return labels


## 仅生成当前显示器硬件物理能力支持的一体化规格预设（不支持的组合不出现）
static func get_supported_spec_presets(override_screen: Vector2i = Vector2i.ZERO, override_hz: float = 0.0) -> Array[Dictionary]:
	var screen_size := override_screen
	if screen_size == Vector2i.ZERO:
		screen_size = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2i(1920, 1080)

	var native_hz := override_hz
	if native_hz <= 0.0:
		native_hz = DisplayServer.screen_get_refresh_rate()
	if native_hz <= 0.0:
		native_hz = 60.0

	var candidates: Array[Dictionary] = [
		{
			"label": "2K @ 144Hz (2.5K 高清高刷)",
			"res": Vector2i(2560, 1440),
			"hz": 144,
		},
		{
			"label": "2K @ 60Hz (2.5K 原生标准)",
			"res": Vector2i(2560, 1440),
			"hz": 60,
		},
		{
			"label": "1080P @ 240Hz (赛级超高刷)",
			"res": Vector2i(1920, 1080),
			"hz": 240,
		},
		{
			"label": "1080P @ 144Hz (主流电竞高刷)",
			"res": Vector2i(1920, 1080),
			"hz": 144,
		},
		{
			"label": "1080P @ 60Hz (全高清标准)",
			"res": Vector2i(1920, 1080),
			"hz": 60,
		},
		{
			"label": "720P @ 60Hz (轻负载模式)",
			"res": Vector2i(1280, 720),
			"hz": 60,
		},
		{
			"label": "4K @ 60Hz (4K 超清标准)",
			"res": Vector2i(3840, 2160),
			"hz": 60,
		},
	]

	var valid_presets: Array[Dictionary] = []
	for c in candidates:
		var res: Vector2i = c.res
		var hz: int = c.hz
		if res.x <= screen_size.x and res.y <= screen_size.y and float(hz) <= native_hz + 1.0:
			valid_presets.append(c)

	# 始终在末尾提供自适应当前屏幕原生规格
	valid_presets.append({
		"label": "当前屏幕物理原生规格 (%d×%d @ %.0fHz)" % [screen_size.x, screen_size.y, native_hz],
		"res": screen_size,
		"hz": 0,
	})

	return valid_presets


## 设置选定分辨率
func set_resolution(res: Vector2i) -> void:
	target_resolution = res
	var supp := get_supported_resolutions()
	var idx := supp.find(res)
	resolution_index = idx if idx >= 0 else 0


## 设置选定刷新率
func set_refresh_rate(hz: int) -> void:
	target_hz = hz
	var supp := get_supported_refresh_rates()
	var idx := supp.find(hz)
	refresh_rate_index = idx if idx >= 0 else 0


## 套用规格字典
func apply_spec_dict(dict: Dictionary) -> void:
	if dict.has("res"):
		set_resolution(dict.res)
	if dict.has("hz"):
		set_refresh_rate(dict.hz)


## 核心投影换算：将 16:9 标定下的水平 FOV 转换为当前视口长宽比下的真实垂直 FOV
static func hfov_to_vfov(hfov_deg: float, aspect_ratio: float = 16.0 / 9.0) -> float:
	var h_rad := deg_to_rad(clampf(hfov_deg, 40.0, 140.0))
	var v_rad := 2.0 * atan(tan(h_rad * 0.5) / aspect_ratio)
	return rad_to_deg(v_rad)


## 获取当前生效的腰射垂直 FOV（Godot Camera3D 原生输入）
func vertical_fov(aspect_ratio: float = 16.0 / 9.0) -> float:
	return hfov_to_vfov(fov, aspect_ratio)


## 获取当前生效的开镜垂直 FOV
func ads_vertical_fov(aspect_ratio: float = 16.0 / 9.0) -> float:
	return hfov_to_vfov(fov * ads_fov_ratio, aspect_ratio)


## 获取当前生效的目标屏幕刷新率数值（Hz）
func target_refresh_rate() -> float:
	if target_hz > 0:
		return float(target_hz)
	var supp := get_supported_refresh_rates()
	if refresh_rate_index > 0 and refresh_rate_index < supp.size():
		return float(supp[refresh_rate_index])
	var hw_rate := DisplayServer.screen_get_refresh_rate()
	return hw_rate if hw_rate > 0.0 else 60.0


## 获取当前解析的分辨率二维尺寸（像素）
func current_resolution() -> Vector2i:
	if target_resolution != Vector2i.ZERO:
		return target_resolution
	var supp := get_supported_resolutions()
	if resolution_index >= 0 and resolution_index < supp.size():
		return supp[resolution_index]
	var scr := DisplayServer.screen_get_size()
	return scr if scr.x > 0 and scr.y > 0 else Vector2i(1920, 1080)


## 计算非压缩视频流实时传输带宽（Gbps，含标准消隐开销）
static func estimate_bandwidth_gbps(res: Vector2i, hz: float) -> float:
	var w := float(maxi(res.x, 640))
	var h := float(maxi(res.y, 480))
	var rate := maxf(hz, 30.0)
	# CVT-RB (Reduced Blanking) 标准消隐系数约为 1.20，24bit RGB 4:4:4
	var total_bits_per_sec := w * h * 1.20 * 24.0 * rate
	return total_bits_per_sec / 1_000_000_000.0


## 评估指定分辨率与刷新率下的传输带宽层级与线缆接口瓶颈
static func bandwidth_info(res: Vector2i, hz: float) -> Dictionary:
	var gbps := estimate_bandwidth_gbps(res, hz)
	var tier := "轻量传输"
	var cable := "HDMI 1.4 / DP 1.1 及以上"
	var warning := ""
	var is_bottleneck := false

	if gbps > 25.0:
		tier = "超高带宽（面临线缆瓶颈）"
		cable = "HDMI 2.1 (48Gbps) / DP 1.4 DSC / DP 2.1"
		warning = "⚠️ 受到视频接口带宽限制！常规 HDMI 2.0 / DP 1.2 无法承载 %.1f Gbps，若显示器黑屏或无法开启高刷，请确认使用 HDMI 2.1 或 DP 1.4 (支持 DSC 压缩) 线缆。" % gbps
		is_bottleneck = true
	elif gbps > 14.4:
		tier = "高带宽电竞（接近 HDMI 2.0 上限）"
		cable = "DisplayPort 1.2 / DP 1.4 或 HDMI 2.0 (部分需 YCbCr 4:2:2)"
		warning = "⚡ 接近常见 HDMI 2.0 带宽上限（14.4 Gbps），推荐优先使用 DisplayPort (DP) 接口以确保无损高刷新率输出。"
	elif gbps > 8.0:
		tier = "主流高速带宽"
		cable = "HDMI 2.0 / DP 1.2 及以上"
		warning = ""
	else:
		tier = "标准低带宽"
		cable = "HDMI 1.4 / DP 1.1 及以上通用线缆"
		warning = ""

	return {
		"gbps": gbps,
		"tier": tier,
		"cable": cable,
		"warning": warning,
		"is_bottleneck": is_bottleneck,
	}


## 快捷套用常见分辨率与刷新率组合预设
func apply_spec_preset(preset_idx: int) -> void:
	match preset_idx:
		0: # 1080P @ 144Hz
			resolution_index = 2
			refresh_rate_index = 3
		1: # 1080P @ 240Hz
			resolution_index = 2
			refresh_rate_index = 5
		2: # 2K @ 144Hz
			resolution_index = 3
			refresh_rate_index = 3
		3: # 4K @ 60Hz
			resolution_index = 4
			refresh_rate_index = 1
		4: # 原生最佳
			resolution_index = 5
			refresh_rate_index = 0


## 常用预设：默认平衡预设（103° 经典竞技视场）
static func preset_default() -> Resource:
	var script: GDScript = load("res://core/video/video_config.gd")
	var c = script.new()
	c.fov = 103.0
	c.ads_fov_ratio = 0.55
	c.eye_height = 1.7
	c.resolution_index = 2
	c.refresh_rate_index = 0
	c.display_mode = DisplayMode.WINDOWED
	c.vsync = VSyncMode.DISABLED
	c.max_fps_index = 0
	c.msaa = AntiAliasing.MSAA_2X
	return c


## 常用预设：职业电竞极致性能（最低延迟）
static func preset_competitive() -> Resource:
	var script: GDScript = load("res://core/video/video_config.gd")
	var c = script.new()
	c.fov = 110.0
	c.ads_fov_ratio = 0.55
	c.eye_height = 1.7
	c.resolution_index = 2
	c.refresh_rate_index = 0
	c.display_mode = DisplayMode.BORDERLESS_FULLSCREEN
	c.vsync = VSyncMode.DISABLED
	c.max_fps_index = 0
	c.msaa = AntiAliasing.MSAA_DISABLED
	return c
