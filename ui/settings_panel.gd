## 参数面板。四个分页：摇杆 / 辅助瞄准 / 训练场景 / 数据。
##
## 面板打开时训练暂停，但摇杆采样**不停**——曲线图上的实时游标和摇杆轨迹照常刷新。
## 这是刻意的：调曲线时最需要的就是一边推杆一边看着曲线上的点跑，
## 如果必须关掉面板才能试手感，调参效率会低一个数量级。
class_name SettingsPanel
extends Control

signal menu_requested

const TAB_STICK := 0
const TAB_ASSIST := 1
const TAB_SCENARIO := 2
const TAB_DATA := 3

var player: Player
var scenario: Scenario

var _tabs: TabContainer
var _stick_box: VBoxContainer
var _assist_box: VBoxContainer
var _scenario_box: VBoxContainer
var _data_box: VBoxContainer
var _menu_btn: Button

var _curve_graph: CurveGraph
var _stick_pad: StickPad
var _histogram: Histogram
var _data_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	rebuild_all()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	# 面板开着时玩家的 _process 已停，这里主动采一次样，
	# 否则曲线图上的实时游标会僵住，等于废掉了边调边试的能力。
	var raw := player.reader.look_raw(get_process_delta_time())
	var dz := App.profile.look_deadzone.apply(raw)
	if _stick_pad != null:
		_stick_pad.deadzone = App.profile.look_deadzone
		_stick_pad.push_sample(raw, dz)
	if _curve_graph != null:
		_curve_graph.set_live(dz.length())
	if _tabs.current_tab == TAB_DATA:
		_refresh_data()


func open_tab(index: int) -> void:
	_tabs.current_tab = clampi(index, 0, _tabs.get_tab_count() - 1)


func set_can_return_to_menu(on: bool) -> void:
	if _menu_btn != null:
		_menu_btn.visible = on


func rebuild_all() -> void:
	_populate_stick()
	_populate_assist()
	_populate_scenario()
	_populate_data()


# ---------------------------------------------------------------------------
# 外框
# ---------------------------------------------------------------------------

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 10))
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 48
	frame.offset_top = 32
	frame.offset_right = -48
	frame.offset_bottom = -32

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(UITheme.label("手柄摇杆训练器 · 参数", 20, UITheme.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UITheme.label("Esc 关闭面板并继续训练", 12, UITheme.MUTED))
	root.add_child(header)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_stick_box = _add_tab("摇杆参数")
	_assist_box = _add_tab("辅助瞄准")
	_scenario_box = _add_tab("训练场景")
	_data_box = _add_tab("数据")

	root.add_child(_build_footer())


## 内容列的宽度上限。窗口再宽也不把滑块拉到一米长——
## 一条横跨屏幕的滑块既难瞄准又看不出相对位置。
const CONTENT_WIDTH := 880


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)

	# 左右各放一个可伸缩的空白把内容列挤到中间。
	var lane := HBoxContainer.new()
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lane)
	lane.add_child(_flex_spacer())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.custom_minimum_size.x = CONTENT_WIDTH
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lane.add_child(box)

	lane.add_child(_flex_spacer())
	return box


func _flex_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _build_footer() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	var save := Button.new()
	save.text = "保存配置"
	save.pressed.connect(App.save_all)
	bar.add_child(save)

	var reset := Button.new()
	reset.text = "全部恢复默认"
	reset.pressed.connect(func() -> void:
		App.apply_profile_preset(ControllerProfile.preset_cod_standard())
		App.apply_assist_preset(AimAssistConfig.preset_off())
		rebuild_all()
	)
	bar.add_child(reset)

	_menu_btn = Button.new()
	_menu_btn.text = "返回主菜单"
	_menu_btn.visible = false
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	bar.add_child(_menu_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	bar.add_child(UITheme.label(
		"配置保存在 user:// 下，下次启动自动载入", 11, UITheme.MUTED,
	))
	return bar


# ---------------------------------------------------------------------------
# 分页一：摇杆参数
# ---------------------------------------------------------------------------

func _populate_stick() -> void:
	_clear(_stick_box)
	var p := App.profile

	var names := PackedStringArray()
	var presets := ControllerProfile.all_presets()
	for preset in presets:
		names.append(preset.profile_name)
	_stick_box.add_child(UITheme.preset_bar(names, func(i: int) -> void:
		App.apply_profile_preset(presets[i])
		_populate_stick()
	))
	_stick_box.add_child(UITheme.hint(
		"预设是对各家公开手感描述的近似，不是逆向出的精确数值，请当作调参起点。"
	))
	_stick_box.add_child(UITheme.separator())

	# 曲线图与摇杆图并排，调参时两张图要同时看。
	# 曲线图保持接近正方形：拉扁之后曲线的弯曲程度会被视觉上压缩，看不出区别。
	var visuals := HBoxContainer.new()
	visuals.add_theme_constant_override("separation", 14)
	_curve_graph = CurveGraph.new()
	_curve_graph.curve = p.yaw_curve
	_curve_graph.custom_minimum_size = Vector2(330, 290)
	_curve_graph.curve_edited.connect(App.notify_profile_changed)
	visuals.add_child(_curve_graph)

	_stick_pad = StickPad.new()
	_stick_pad.custom_minimum_size = Vector2(290, 290)
	_stick_pad.deadzone = p.look_deadzone
	visuals.add_child(_stick_pad)
	visuals.add_child(_flex_spacer())
	_stick_box.add_child(visuals)

	_section("响应曲线")
	_add(ParamRow.options(
		"曲线作用方式", PackedStringArray(["径向（保持方向）", "分轴（可分别调）"]),
		p.curve_mode,
		"径向把曲线作用在摇杆模长上，对角推杆方向不失真；分轴可给水平和垂直配不同曲线。",
	), func(v: int) -> void:
		p.curve_mode = v
		App.notify_profile_changed()
		_populate_stick()
	)
	_add_curve_controls(p.yaw_curve, "水平曲线" if p.curve_mode == ControllerProfile.CurveMode.PER_AXIS else "曲线")
	if p.curve_mode == ControllerProfile.CurveMode.PER_AXIS:
		_add_curve_controls(p.pitch_curve, "垂直曲线")

	_section("死区")
	var dz := p.look_deadzone
	_add(ParamRow.options(
		"死区形状", PackedStringArray(["轴向（方形）", "径向（圆形）", "混合"]), dz.shape,
		"轴向会抹掉幅度较小的那个轴；径向保持方向；混合先按轴去噪再按模长归一化。",
	), func(v: int) -> void:
		dz.shape = v
		App.notify_profile_changed()
	)
	_add(ParamRow.slider("内死区", 0.0, 0.5, 0.005, dz.inner, "", 3,
		"摇杆回中后视角仍在飘，就调大这个值。"),
		func(v: float) -> void:
			dz.inner = v
			App.notify_profile_changed()
	)
	_add(ParamRow.slider("外死区", 0.5, 1.0, 0.005, dz.outer, "", 3,
		"摇杆推到底却达不到最高转速，就调小这个值。"),
		func(v: float) -> void:
			dz.outer = v
			App.notify_profile_changed()
	)
	_add(ParamRow.slider("反死区", 0.0, 0.5, 0.005, dz.anti_deadzone, "", 3,
		"用于抵消游戏内关不掉的死区。本训练器自身没有隐藏死区，通常保持 0。"),
		func(v: float) -> void:
			dz.anti_deadzone = v
			App.notify_profile_changed()
	)

	_section("灵敏度")
	_add(ParamRow.slider("水平转速", 30, 1200, 5, p.yaw_speed, " °/s", 0,
		"摇杆推到底时每秒转过的角度。"),
		func(v: float) -> void:
			p.yaw_speed = v
			App.notify_profile_changed()
	)
	_add(ParamRow.slider("垂直转速", 30, 1200, 5, p.pitch_speed, " °/s", 0), func(v: float) -> void:
		p.pitch_speed = v
		App.notify_profile_changed()
	)
	_add(ParamRow.slider("开镜倍率", 0.1, 2.0, 0.01, p.ads_multiplier, "×", 2,
		"按住左扳机（或鼠标右键）开镜时的转速倍率。"),
		func(v: float) -> void:
			p.ads_multiplier = v
			App.notify_profile_changed()
	)

	_section("转向加速")
	_stick_box.add_child(UITheme.hint(
		"推满摇杆并保持一段时间后额外提速，用来兼顾微操与快速转身。倍率为 1 即关闭。"
	))
	_add(ParamRow.slider("最大倍率", 1.0, 4.0, 0.05, p.accel_boost, "×", 2), func(v: float) -> void:
		p.accel_boost = v
		App.notify_profile_changed()
	)
	_add(ParamRow.slider("起始延迟", 0.0, 1.0, 0.01, p.accel_delay, " s", 2,
		"推满后等待多久才开始加速。设长一点可以避免短促的微调被加速污染。"),
		func(v: float) -> void:
			p.accel_delay = v
			App.notify_profile_changed()
	)
	_add(ParamRow.slider("加速时长", 0.01, 2.0, 0.01, p.accel_time, " s", 2), func(v: float) -> void:
		p.accel_time = v
		App.notify_profile_changed()
	)

	_section("其他")
	_add(ParamRow.toggle("水平反转", p.invert_x), func(v: bool) -> void:
		p.invert_x = v
		App.notify_profile_changed()
	)
	_add(ParamRow.toggle("垂直反转", p.invert_y), func(v: bool) -> void:
		p.invert_y = v
		App.notify_profile_changed()
	)
	_add(ParamRow.slider("输出平滑", 0.0, 0.95, 0.01, p.smoothing, "", 2,
		"低通滤波，能压掉摇杆抖动，代价是引入延迟。追踪训练建议保持 0。"),
		func(v: float) -> void:
			p.smoothing = v
			App.notify_profile_changed()
	)


func _add_curve_controls(curve: ResponseCurve, title: String) -> void:
	_stick_box.add_child(UITheme.label(title, 13, UITheme.MUTED))
	_add(ParamRow.options(
		"曲线类型",
		PackedStringArray(["线性", "指数", "S 曲线", "反 S 曲线", "自定义贝塞尔"]),
		curve.type,
		"线性=1:1；指数=中心精细边缘迅猛；反 S=中段精细两端迅猛。",
	), func(v: int) -> void:
		curve.type = v
		App.notify_profile_changed()
		_populate_stick()
	)
	match curve.type:
		ResponseCurve.Type.POWER:
			_add(ParamRow.slider("指数", 1.0, 5.0, 0.05, curve.exponent, "", 2,
				"越大，摇杆前半程越钝，微操越细。1.0 等于线性。"),
				func(v: float) -> void:
					curve.exponent = v
					App.notify_profile_changed()
					_curve_graph.queue_redraw()
			)
		ResponseCurve.Type.S_CURVE, ResponseCurve.Type.REVERSE_S:
			_add(ParamRow.slider("弯曲强度", 0.0, 1.0, 0.01, curve.strength, "", 2,
				"0 时退化为线性。"),
				func(v: float) -> void:
					curve.strength = v
					App.notify_profile_changed()
					_curve_graph.queue_redraw()
			)
		ResponseCurve.Type.BEZIER:
			_stick_box.add_child(UITheme.hint("直接在上方曲线图里拖动两个橙色控制点。"))


# ---------------------------------------------------------------------------
# 分页二：辅助瞄准
# ---------------------------------------------------------------------------

func _populate_assist() -> void:
	_clear(_assist_box)
	var c := App.assist

	var names := PackedStringArray()
	var presets := AimAssistConfig.all_presets()
	for preset in presets:
		names.append(preset.config_name)
	_assist_box.add_child(UITheme.preset_bar(names, func(i: int) -> void:
		App.apply_assist_preset(presets[i])
		_populate_assist()
	))
	_assist_box.add_child(UITheme.hint(
		"三种机制拆开可调，正是为了让你分辨自己的枪法依赖的是哪一种。"
		+ "建议逐项单独打开来体会差异，训练时再逐步调低。游戏内按 F1 可以看到气泡的实际范围。"
	))
	_assist_box.add_child(UITheme.separator())

	_add(ParamRow.toggle("总开关", c.enabled), func(v: bool) -> void:
		c.enabled = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("总强度", 0.0, 1.0, 0.01, c.master_strength, "", 2,
		"同时缩放三种机制。为 0 时与关闭完全等价。"),
		func(v: float) -> void:
			c.master_strength = v
			App.notify_assist_changed()
	, _assist_box)

	_section("减速 / 粘滞", _assist_box)
	_assist_box.add_child(UITheme.hint("准星扫过目标时降低转速，让人更容易停在目标上。"))
	_add(ParamRow.toggle("启用", c.slowdown_enabled), func(v: bool) -> void:
		c.slowdown_enabled = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("强度", 0.0, 0.95, 0.01, c.slowdown_strength, "", 2,
		"0.5 表示准星压在目标上时转速只剩一半。"),
		func(v: float) -> void:
			c.slowdown_strength = v
			App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("气泡半径", 0.5, 25.0, 0.1, c.slowdown_bubble, " °", 1), func(v: float) -> void:
		c.slowdown_bubble = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("满强度核心", 0.0, 1.0, 0.01, c.slowdown_core, "", 2,
		"核心占气泡半径的比例，核心内不衰减。"),
		func(v: float) -> void:
			c.slowdown_core = v
			App.notify_assist_changed()
	, _assist_box)

	_section("旋转跟枪", _assist_box)
	_assist_box.add_child(UITheme.hint(
		"摄像机自动跟随目标的视野角速度，是「自动跟枪」感的主要来源。"
		+ "Apex 要求同时有移动输入才触发，这也是该作「平移换跟枪」技巧的由来。"
	))
	_add(ParamRow.toggle("启用", c.rotation_enabled), func(v: bool) -> void:
		c.rotation_enabled = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("强度", 0.0, 1.0, 0.01, c.rotation_strength, "", 2,
		"1.0 表示完全跟住目标角速度，目标横移时准星自己就贴着走。"),
		func(v: float) -> void:
			c.rotation_strength = v
			App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("气泡半径", 0.5, 25.0, 0.1, c.rotation_bubble, " °", 1), func(v: float) -> void:
		c.rotation_bubble = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("满强度核心", 0.0, 1.0, 0.01, c.rotation_core, "", 2), func(v: float) -> void:
		c.rotation_core = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("角速度上限", 0.0, 400.0, 1.0, c.rotation_max_dps, " °/s", 0,
		"防止目标高速掠过时视角被猛甩。"),
		func(v: float) -> void:
			c.rotation_max_dps = v
			App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.toggle("需要移动输入（APEX 式）", c.rotation_requires_move_input), func(v: bool) -> void:
		c.rotation_requires_move_input = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.toggle("需要视角输入", c.rotation_requires_look_input), func(v: bool) -> void:
		c.rotation_requires_look_input = v
		App.notify_assist_changed()
	, _assist_box)

	_section("磁吸", _assist_box)
	_assist_box.add_child(UITheme.hint("准星被持续拉向目标中心，COD 的表现更明显。"))
	_add(ParamRow.toggle("启用", c.magnetism_enabled), func(v: bool) -> void:
		c.magnetism_enabled = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("强度", 0.0, 1.0, 0.01, c.magnetism_strength, "", 2), func(v: float) -> void:
		c.magnetism_strength = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("气泡半径", 0.5, 25.0, 0.1, c.magnetism_bubble, " °", 1), func(v: float) -> void:
		c.magnetism_bubble = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("拉力增益", 0.5, 20.0, 0.1, c.magnetism_gain, " /s", 1), func(v: float) -> void:
		c.magnetism_gain = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.slider("速度上限", 0.0, 200.0, 1.0, c.magnetism_max_dps, " °/s", 0), func(v: float) -> void:
		c.magnetism_max_dps = v
		App.notify_assist_changed()
	, _assist_box)

	_section("通用", _assist_box)
	_add(ParamRow.slider("最大作用距离", 5.0, 300.0, 1.0, c.max_distance, " m", 0), func(v: float) -> void:
		c.max_distance = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.toggle("气泡随目标大小放大", c.scale_bubble_by_target_size), func(v: bool) -> void:
		c.scale_bubble_by_target_size = v
		App.notify_assist_changed()
	, _assist_box)
	_add(ParamRow.toggle("仅开镜时生效", c.ads_only), func(v: bool) -> void:
		c.ads_only = v
		App.notify_assist_changed()
	, _assist_box)


# ---------------------------------------------------------------------------
# 分页三：训练场景
# ---------------------------------------------------------------------------

func _populate_scenario() -> void:
	_clear(_scenario_box)
	var d := App.scenario

	var names := PackedStringArray()
	var presets := ScenarioDef.all_presets()
	for preset in presets:
		names.append(preset.display_name)
	_scenario_box.add_child(UITheme.preset_bar(names, func(i: int) -> void:
		App.apply_scenario_preset(presets[i])
		_populate_scenario()
	))
	_scenario_box.add_child(UITheme.hint(d.description))
	_scenario_box.add_child(UITheme.separator())
	_scenario_box.add_child(UITheme.hint(
		"改动立刻作用于当前这一局。散布和距离对已在场的靶机在下次换位后生效，按 R 可立即按新布置重开。"
	))

	_section("武器", _scenario_box)
	_add(ParamRow.options("开火方式",
		PackedStringArray(["持续光束（计在靶时间）", "半自动", "全自动"]), d.weapon,
	), func(v: int) -> void:
		d.weapon = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("射速", 1.0, 20.0, 0.5, d.fire_rate, " 发/s", 1), func(v: float) -> void:
		d.fire_rate = v
		_apply_scenario_live()
	, _scenario_box)

	_section("靶机", _scenario_box)
	_add(ParamRow.slider("数量", 1, 12, 1, d.target_count, "", 0), func(v: float) -> void:
		d.target_count = int(v)
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("半径", 0.05, 2.0, 0.01, d.target_radius, " m", 2), func(v: float) -> void:
		d.target_radius = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("击杀所需命中", 1, 10, 1, d.hits_to_kill, "", 0), func(v: float) -> void:
		d.hits_to_kill = int(v)
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.toggle("命中后换位重生", d.respawn_on_hit), func(v: bool) -> void:
		d.respawn_on_hit = v
		_apply_scenario_live()
	, _scenario_box)

	_section("布置", _scenario_box)
	_add(ParamRow.slider("最近距离", 3.0, 120.0, 0.5, d.distance_min, " m", 1), func(v: float) -> void:
		d.distance_min = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("最远距离", 3.0, 120.0, 0.5, d.distance_max, " m", 1), func(v: float) -> void:
		d.distance_max = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("水平散布", 1.0, 60.0, 0.5, d.spread_h, " m", 1,
		"决定甩枪的转移幅度。"), func(v: float) -> void:
		d.spread_h = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("垂直散布", 0.5, 20.0, 0.5, d.spread_v, " m", 1), func(v: float) -> void:
		d.spread_v = v
		_apply_scenario_live()
	, _scenario_box)

	_section("运动", _scenario_box)
	_add(ParamRow.options("运动方式",
		PackedStringArray(["静止", "水平横移", "三维漂移", "圆周"]), d.motion,
	), func(v: int) -> void:
		d.motion = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("最低速度", 0.0, 20.0, 0.1, d.speed_min, " m/s", 1), func(v: float) -> void:
		d.speed_min = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("最高速度", 0.0, 20.0, 0.1, d.speed_max, " m/s", 1), func(v: float) -> void:
		d.speed_max = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("运动幅度", 0.5, 30.0, 0.5, d.motion_range, " m", 1), func(v: float) -> void:
		d.motion_range = v
		_apply_scenario_live()
	, _scenario_box)
	_add(ParamRow.slider("变向频率", 0.0, 4.0, 0.05, d.direction_change_rate, " /s", 2,
		"调高会显著增加追踪难度。设为 0 则运动可预测，那样练出来的是背板而不是跟枪。"),
		func(v: float) -> void:
			d.direction_change_rate = v
			_apply_scenario_live()
	, _scenario_box)

	_section("时长", _scenario_box)
	_add(ParamRow.slider("单局时长", 10.0, 300.0, 5.0, d.duration, " s", 0), func(v: float) -> void:
		d.duration = v
		_apply_scenario_live()
	, _scenario_box)


# ---------------------------------------------------------------------------
# 分页四：数据
# ---------------------------------------------------------------------------

func _populate_data() -> void:
	_clear(_data_box)
	_data_box.add_child(UITheme.heading("摇杆偏转量分布"))
	_data_box.add_child(UITheme.hint(
		"只统计摇杆真正在动的时间。橙色的前三个桶是微操区——"
		+ "如果你的时间大量落在这里，那么响应曲线的前段就是最该被调好的部分，"
		+ "而边缘段调多少都感觉不到。这是普通练枪软件给不了的信息。"
	))
	_histogram = Histogram.new()
	_histogram.custom_minimum_size = Vector2(420, 150)
	_data_box.add_child(_histogram)

	_data_box.add_child(UITheme.separator())
	_data_box.add_child(UITheme.heading("本局数据"))
	_data_text = UITheme.label("", 14, UITheme.TEXT)
	_data_box.add_child(_data_text)
	_refresh_data()


func _refresh_data() -> void:
	if scenario == null or _histogram == null:
		return
	var s := scenario.stats
	var ratios := PackedFloat32Array()
	for i in SessionStats.BUCKETS:
		ratios.append(s.bucket_ratio(i))
	_histogram.set_values(ratios)
	_histogram.caption = "摇杆偏转量"

	_data_text.text = "\n".join(PackedStringArray([
		"用时　　　　%.1f s" % s.elapsed,
		"命中率　　　%d%%（%d / %d）" % [roundi(s.accuracy() * 100.0), s.hits, s.shots],
		"击杀　　　　%d，每秒 %.2f" % [s.kills, s.kills_per_second()],
		"在靶时间　　%.1f s，占比 %d%%" % [s.time_on_target, roundi(s.time_on_target_ratio() * 100.0)],
		"平均转移　　%.0f ms" % (s.avg_reaction() * 1000.0),
		"平均偏转量　%.2f" % s.avg_deflection(),
		"推杆时间　　占全局 %d%%" % roundi(s.active_ratio() * 100.0),
		"微操区占比　%d%%" % roundi(s.fine_control_ratio() * 100.0),
		"辅助生效　　%d%% 的时间视角受到了辅助干预" % roundi(s.assist_ratio() * 100.0),
	]))


# ---------------------------------------------------------------------------
# 构建辅助
# ---------------------------------------------------------------------------

func _apply_scenario_live() -> void:
	if scenario != null:
		scenario.apply_live()


func _section(title: String, box: VBoxContainer = null) -> void:
	var target := box if box != null else _stick_box
	target.add_child(UITheme.separator())
	target.add_child(UITheme.heading(title))


func _add(row: ParamRow, callback: Callable, box: VBoxContainer = null) -> void:
	var target := box if box != null else _stick_box
	target.add_child(row)
	row.changed.connect(callback)


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()
		box.remove_child(c)
