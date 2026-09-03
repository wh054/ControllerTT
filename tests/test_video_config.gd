class_name TestVideoConfig
extends TestCase

const VideoConfig = preload("res://core/video/video_config.gd")


func suite_name() -> String:
	return "画面与视频配置"


func test_defaults() -> void:
	var v = VideoConfig.preset_default()
	assert_near(v.fov, 103.0, 0.001, "默认视场应为 103°")
	assert_near(v.ads_fov_ratio, 0.55, 0.001, "默认开镜比例应为 0.55x")
	assert_near(v.eye_height, 1.7, 0.001, "默认眼高应为 1.7m")
	assert_eq(v.display_mode, VideoConfig.DisplayMode.WINDOWED, "默认应为窗口化")
	assert_eq(v.vsync, VideoConfig.VSyncMode.DISABLED, "默认垂直同步应关闭以降低输入延迟")
	assert_eq(v.refresh_rate_index, 0, "默认刷新率应为自动检测")


func test_refresh_rates() -> void:
	var v = VideoConfig.preset_default()
	assert_eq(VideoConfig.REFRESH_RATES.size(), 7, "应提供 7 种刷新率选项")
	assert_true(VideoConfig.REFRESH_RATES.has(144), "应包含 144Hz")
	assert_true(VideoConfig.REFRESH_RATES.has(240), "应包含 240Hz")
	assert_true(VideoConfig.REFRESH_RATES.has(360), "应包含 360Hz")

	v.set_refresh_rate(144)
	assert_near(v.target_refresh_rate(), 144.0, 0.001, "选定目标刷新率 144Hz")

	v.set_refresh_rate(240)
	assert_near(v.target_refresh_rate(), 240.0, 0.001, "选定目标刷新率 240Hz")


func test_bandwidth_and_presets() -> void:
	# 1080p @ 60Hz 带宽约 3.58 Gbps
	var bw_1080p_60: float = VideoConfig.estimate_bandwidth_gbps(Vector2i(1920, 1080), 60.0)
	assert_near(bw_1080p_60, 3.58, 0.2, "1080p 60Hz 传输带宽约 3.6 Gbps")

	# 1080p @ 144Hz 带宽约 8.60 Gbps
	var bw_1080p_144: float = VideoConfig.estimate_bandwidth_gbps(Vector2i(1920, 1080), 144.0)
	assert_near(bw_1080p_144, 8.60, 0.3, "1080p 144Hz 传输带宽约 8.6 Gbps")

	# 4K @ 144Hz 带宽约 34.40 Gbps（严重超常规 HDMI 2.0 上限）
	var bw_4k_144: float = VideoConfig.estimate_bandwidth_gbps(Vector2i(3840, 2160), 144.0)
	assert_near(bw_4k_144, 34.40, 0.5, "4K 144Hz 传输带宽约 34.4 Gbps")

	var info_4k_144: Dictionary = VideoConfig.bandwidth_info(Vector2i(3840, 2160), 144.0)
	assert_true(info_4k_144.is_bottleneck, "4K 144Hz 应提示接口线缆瓶颈")

	var v = VideoConfig.preset_default()
	v.apply_spec_dict({"res": Vector2i(1920, 1080), "hz": 144})
	assert_eq(v.target_resolution, Vector2i(1920, 1080), "规格字典应用分辨率应生效")
	assert_eq(v.target_hz, 144, "规格字典应用刷新率应生效")


func test_hardware_filtering() -> void:
	# 1. 分辨率过滤测试：在 1080P 屏幕上，不可出现 2K (1440P) 或 4K
	var supp_1080p := VideoConfig.get_supported_resolutions(Vector2i(1920, 1080))
	assert_true(supp_1080p.has(Vector2i(1920, 1080)), "1080P 屏幕应包含 1080P")
	assert_true(supp_1080p.has(Vector2i(1280, 720)), "1080P 屏幕应包含 720P")
	assert_false(supp_1080p.has(Vector2i(2560, 1440)), "1080P 屏幕绝不能出现 2K")
	assert_false(supp_1080p.has(Vector2i(3840, 2160)), "1080P 屏幕绝不能出现 4K")

	# 在 2K 屏幕上，可出现 1080P 和 2K，但不可出现 4K
	var supp_2k := VideoConfig.get_supported_resolutions(Vector2i(2560, 1440))
	assert_true(supp_2k.has(Vector2i(2560, 1440)), "2K 屏幕应包含 2K")
	assert_false(supp_2k.has(Vector2i(3840, 2160)), "2K 屏幕绝不能出现 4K")

	# 2. 刷新率过滤测试：在 60Hz 屏幕上，绝不出现 120Hz、144Hz 等不可达高刷
	var rates_60 := VideoConfig.get_supported_refresh_rates(60.0)
	assert_true(rates_60.has(60), "60Hz 屏幕应包含 60Hz")
	assert_false(rates_60.has(120), "60Hz 屏幕绝不能出现 120Hz")
	assert_false(rates_60.has(144), "60Hz 屏幕绝不能出现 144Hz")
	assert_false(rates_60.has(240), "60Hz 屏幕绝不能出现 240Hz")

	# 在 144Hz 屏幕上，可出现 60Hz 和 144Hz，但绝不出现 240Hz、360Hz
	var rates_144 := VideoConfig.get_supported_refresh_rates(144.0)
	assert_true(rates_144.has(60), "144Hz 屏幕应支持降频至 60Hz")
	assert_true(rates_144.has(144), "144Hz 屏幕应支持 144Hz")
	assert_false(rates_144.has(240), "144Hz 屏幕绝不能出现 240Hz")

	# 3. 规格预设过滤测试：在 2K 60Hz 屏幕上，预设中绝不出现 144Hz 或 4K
	var presets := VideoConfig.get_supported_spec_presets(Vector2i(2560, 1440), 60.0)
	for p in presets:
		var r: Vector2i = p.res
		var hz: int = p.hz
		assert_true(r.x <= 2560 and r.y <= 1440, "预设分辨率不得超过屏幕物理分辨率")
		assert_true(float(hz) <= 61.0, "预设刷新率不得超过物理最高刷新率")


func test_fov_conversion_math() -> void:
	# 经典 16:9 视场换算验证
	var v103: float = VideoConfig.hfov_to_vfov(103.0, 16.0 / 9.0)
	assert_near(v103, 70.53, 0.1, "103° H-FOV 对应垂直 FOV 约 70.5°")

	var v90: float = VideoConfig.hfov_to_vfov(90.0, 16.0 / 9.0)
	assert_near(v90, 58.72, 0.1, "90° H-FOV 对应垂直 FOV 约 58.7°")

	var v110: float = VideoConfig.hfov_to_vfov(110.0, 16.0 / 9.0)
	assert_near(v110, 77.55, 0.1, "110° H-FOV 对应垂直 FOV 约 77.55°")

	var v120: float = VideoConfig.hfov_to_vfov(120.0, 16.0 / 9.0)
	assert_near(v120, 88.51, 0.1, "120° H-FOV 对应垂直 FOV 约 88.51°")


func test_ads_scaling() -> void:
	var v = VideoConfig.preset_default()
	var v_hip: float = v.vertical_fov()
	var v_ads: float = v.ads_vertical_fov()
	assert_true(v_ads < v_hip, "开镜垂直视场角应显著小于腰射视场角")
	assert_near(v_ads, 33.73, 0.5, "103° 在 0.55 缩放下开镜垂直 FOV 约 33.7°")


func test_presets() -> void:
	var comp = VideoConfig.preset_competitive()
	assert_near(comp.fov, 110.0, 0.001, "电竞预设 FOV 应为 110°")
	assert_eq(comp.vsync, VideoConfig.VSyncMode.DISABLED, "电竞预设 VSync 必须关闭")
	assert_eq(comp.max_fps_index, 0, "电竞预设最大帧率应为无限制")


func test_clone() -> void:
	var v = VideoConfig.preset_default()
	v.fov = 115.0
	var c = v.clone()
	assert_near(c.fov, 115.0, 0.001, "克隆后 FOV 属性应一致")
	c.fov = 85.0
	assert_near(v.fov, 115.0, 0.001, "修改克隆对象不应影响原对象")
