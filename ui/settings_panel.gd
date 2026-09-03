## 参数面板。四个分页：摇杆 / 辅助瞄准 / 训练场景 / 数据。
##
## 面板打开时训练暂停，但摇杆采样**不停**——曲线图上的实时游标和摇杆轨迹照常刷新。
## 这是刻意的：调曲线时最需要的就是一边推杆一边看着曲线上的点跑，
## 如果必须关掉面板才能试手感，调参效率会低一个数量级。
class_name SettingsPanel
extends Control

const VideoConfig = preload("res://core/video/video_config.gd")

signal menu_requested

const TAB_STICK := 0
const TAB_ASSIST := 1
const TAB_SCENARIO := 2
const TAB_VIDEO := 3
const TAB_DATA := 4
const _NAV_INITIAL_DELAY := 0.34
const _NAV_REPEAT_INTERVAL := 0.09
const _STICK_NAV_THRESHOLD := 0.65
const _ROW_Y_TOLERANCE := 10.0

var player: Player
var scenario: Scenario

var _tabs: TabContainer
var _stick_box: VBoxContainer
var _assist_box: VBoxContainer
var _scenario_box: VBoxContainer
var _video_box: VBoxContainer
var _data_box: VBoxContainer
var _menu_btn: Button
var _save_btn: Button
var _reset_btn: Button

var _curve_graph: CurveGraph
var _stick_pad: StickPad
var _histogram: Histogram
var _data_text: Label
var _bandwidth_text: Label
var _bandwidth_alert: Label
var _held_nav := Vector2i.ZERO
var _stick_nav := Vector2.ZERO
var _nav_repeat_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	rebuild_all()


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_advance_nav_repeat(delta)
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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var direction := Vector2i.ZERO
	var relevant := false
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		match button.button_index:
			JOY_BUTTON_DPAD_UP:
				direction = Vector2i.UP if button.pressed else Vector2i.ZERO
				relevant = true
			JOY_BUTTON_DPAD_DOWN:
				direction = Vector2i.DOWN if button.pressed else Vector2i.ZERO
				relevant = true
			JOY_BUTTON_DPAD_LEFT:
				direction = Vector2i.LEFT if button.pressed else Vector2i.ZERO
				relevant = true
			JOY_BUTTON_DPAD_RIGHT:
				direction = Vector2i.RIGHT if button.pressed else Vector2i.ZERO
				relevant = true
			JOY_BUTTON_X:
				if button.pressed:
					_reset_btn.pressed.emit()
					get_viewport().set_input_as_handled()
					return
			JOY_BUTTON_Y:
				if button.pressed:
					_save_btn.pressed.emit()
					get_viewport().set_input_as_handled()
					return
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X:
			_stick_nav.x = motion.axis_value
			relevant = true
		elif motion.axis == JOY_AXIS_LEFT_Y:
			_stick_nav.y = motion.axis_value
			relevant = true
		if relevant:
			direction = _stick_direction()

	if not relevant:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is OptionButton and (focus as OptionButton).get_popup().visible:
		# 展开的选项列表接管方向键；此时保持原生“上下选择、A 确认、B 取消”。
		_held_nav = Vector2i.ZERO
		_nav_repeat_left = 0.0
		return
	if direction == Vector2i.ZERO:
		_held_nav = Vector2i.ZERO
		_nav_repeat_left = 0.0
	elif direction != _held_nav:
		_held_nav = direction
		_nav_repeat_left = _NAV_INITIAL_DELAY
		_navigate(direction)
	get_viewport().set_input_as_handled()


func open_tab(index: int) -> void:
	_tabs.current_tab = clampi(index, 0, _tabs.get_tab_count() - 1)
	_queue_controller_focus()


## LB / RB 在设置分页间循环，切页后把焦点落到该页第一个可操作控件。
func switch_tab(step: int) -> void:
	if not visible or _tabs.get_tab_count() == 0:
		return
	_tabs.current_tab = wrapi(_tabs.current_tab + step, 0, _tabs.get_tab_count())
	_queue_controller_focus()


func activate_controller_focus() -> void:
	_queue_controller_focus()


func set_can_return_to_menu(on: bool) -> void:
	if _menu_btn != null:
		_menu_btn.visible = on


func rebuild_all() -> void:
	_populate_stick()
	_populate_assist()
	_populate_scenario()
	_populate_video()
	_populate_data()


# ---------------------------------------------------------------------------
# 外框
# ---------------------------------------------------------------------------

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = UITheme.BG_TRANSPARENT
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 10, UITheme.OUTLINE, 1, 16))
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 48
	frame.offset_top = 28
	frame.offset_right = -48
	frame.offset_bottom = -28

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.add_child(UITheme.label("⚙️ 参数调优控制台", 20, UITheme.TEXT))
	header.add_child(UITheme.tag_badge("实时热更新 · 边调边试", UITheme.GOOD))
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var tab_hint := UITheme.button_hints([
		["LB", ""],
		["RB", "切换分页"],
	])
	header.add_child(tab_hint)
	root.add_child(header)

	_tabs = TabContainer.new()
	# 分页由肩键切换；焦点只在实际参数控件间移动，避免卡在标签栏。
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_stick_box = _add_tab("摇杆参数")
	_assist_box = _add_tab("辅助瞄准")
	_scenario_box = _add_tab("训练场景")
	_video_box = _add_tab("画面/视频")
	_data_box = _add_tab("数据监控")

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
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)

	var left_flex := Control.new()
	left_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_flex)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = CONTENT_WIDTH
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	var right_flex := Control.new()
	right_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_flex)

	return box


func _flex_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _build_footer() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)

	_save_btn = Button.new()
	_save_btn.text = "💾 保存配置 (Y)"
	_save_btn.pressed.connect(App.save_all)
	bar.add_child(_save_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "🔄 全部恢复默认 (X)"
	_reset_btn.pressed.connect(func() -> void:
		App.apply_profile_preset(ControllerProfile.preset_cod_standard())
		App.apply_assist_preset(AimAssistConfig.preset_off())
		rebuild_all()
	)
	bar.add_child(_reset_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "🚪 返回主菜单 (B)"
	_menu_btn.visible = false
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	bar.add_child(_menu_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var footer_hints := UITheme.button_hints([
		["D-Pad", "选择/调节"],
		["A", "切换/确认"],
		["X", "恢复默认"],
		["Y", "保存配置"],
		["B", "返回"],
	])
	bar.add_child(footer_hints)
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
			_stick_box.add_child(UITheme.hint(
				"可直接拖动上方橙色控制点，也可用下面四个数值通过手柄精调。"
			))
			_add_bezier_controls(curve)


func _add_bezier_controls(curve: ResponseCurve) -> void:
	_add(ParamRow.slider("控制点 1 · X", 0.0, 1.0, 0.01, curve.bezier_p1.x, "", 2), func(v: float) -> void:
		var point := curve.bezier_p1
		point.x = v
		curve.bezier_p1 = point
		_on_curve_value_changed()
	)
	_add(ParamRow.slider("控制点 1 · Y", 0.0, 1.0, 0.01, curve.bezier_p1.y, "", 2), func(v: float) -> void:
		var point := curve.bezier_p1
		point.y = v
		curve.bezier_p1 = point
		_on_curve_value_changed()
	)
	_add(ParamRow.slider("控制点 2 · X", 0.0, 1.0, 0.01, curve.bezier_p2.x, "", 2), func(v: float) -> void:
		var point := curve.bezier_p2
		point.x = v
		curve.bezier_p2 = point
		_on_curve_value_changed()
	)
	_add(ParamRow.slider("控制点 2 · Y", 0.0, 1.0, 0.01, curve.bezier_p2.y, "", 2), func(v: float) -> void:
		var point := curve.bezier_p2
		point.y = v
		curve.bezier_p2 = point
		_on_curve_value_changed()
	)


func _on_curve_value_changed() -> void:
	App.notify_profile_changed()
	if _curve_graph != null:
		_curve_graph.queue_redraw()


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
		"改动立刻作用于当前这一局。散布和距离对已在场的靶机在下次换位后生效，按 Y / R 可立即按新布置重开。"
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
# 分页四：画面/视频设置
# ---------------------------------------------------------------------------

func _populate_video() -> void:
	_clear(_video_box)
	var v := App.video

	# 顶部常用竞技预设栏
	var preset_names := PackedStringArray(["103° 经典竞技 (16:9)", "110° 宽视角 (高机动)", "90° 常规视野 (稳重)"])
	_video_box.add_child(UITheme.preset_bar(preset_names, func(i: int) -> void:
		match i:
			0:
				v.fov = 103.0
			1:
				v.fov = 110.0
			2:
				v.fov = 90.0
		App.notify_video_changed()
		_populate_video()
	))
	_video_box.add_child(UITheme.hint(
		"采用现代 FPS 严格的 16:9 水平 FOV 标定与 expand 扩展视口，彻底消除画面拉伸畸变与鱼眼现象。"
	))

	_section("视场角与透视 (FOV & Perspective)", _video_box)

	# 水平视场角滑块
	_add(ParamRow.slider("水平视场角", 60.0, 120.0, 1.0, v.fov, " °", 0, "以 16:9 为基准标定的水平 FOV。Apex/OW/COD 竞技推荐 103°。自动换算真实垂直视场，还原自然纵深。"), func(val: float) -> void:
		v.fov = val
		App.notify_video_changed()
	, _video_box)

	# 开镜视场缩放
	_add(ParamRow.slider("开镜视场比例", 0.3, 0.9, 0.05, v.ads_fov_ratio, " x", 2, "按住瞄准键（LT / 鼠标右键）时的视场缩放比。0.55 即开镜后视角约为腰射的 55%。"), func(val: float) -> void:
		v.ads_fov_ratio = val
		App.notify_video_changed()
	, _video_box)

	# 视线高度
	_add(ParamRow.slider("视线高度", 1.4, 2.0, 0.05, v.eye_height, " m", 2, "第一人称摄像机相对地面的基准高度。1.7m 为人体工程学站姿眼高，直接决定与靶机之间的俯仰透视关系。"), func(val: float) -> void:
		v.eye_height = val
		App.notify_video_changed()
	, _video_box)

	_section("显示输出规格与视频带宽 (Display Output & Bandwidth)", _video_box)

	var supp_resolutions := VideoConfig.get_supported_resolutions()
	var res_labels := VideoConfig.get_resolution_labels(supp_resolutions)
	var supp_rates := VideoConfig.get_supported_refresh_rates()
	var hz_labels := VideoConfig.get_refresh_rate_labels(supp_rates)
	var spec_presets := VideoConfig.get_supported_spec_presets()

	# 1. 硬件自适应规格预设（严格只显示当前显示器支持的规格，不支持的不出现）
	var spec_preset_names := PackedStringArray()
	for p in spec_presets:
		spec_preset_names.append(p.label)

	_video_box.add_child(UITheme.preset_bar(spec_preset_names, func(i: int) -> void:
		v.apply_spec_dict(spec_presets[i])
		App.notify_video_changed()
		_populate_video()
	))

	# 2. 显示模式
	_add(ParamRow.options("显示模式", PackedStringArray(["窗口化", "无边框全屏", "独占全屏"]), v.display_mode, "窗口化方便多任务调参，无边框全屏与独占全屏可带来最沉浸的游戏体验与稳定帧率。"), func(idx: int) -> void:
		v.display_mode = idx as VideoConfig.DisplayMode
		App.notify_video_changed()
		_refresh_bandwidth_card()
	, _video_box)

	# 3. 输出分辨率（动态过滤：超出显示器物理尺寸的选项不出现）
	var cur_res := v.current_resolution()
	var cur_res_idx := supp_resolutions.find(cur_res)
	if cur_res_idx < 0:
		cur_res_idx = supp_resolutions.size() - 1

	_add(ParamRow.options("输出分辨率", res_labels, cur_res_idx, "仅列出当前连接显示器物理支持的分辨率（杜绝超频黑屏与画面失真）。"), func(idx: int) -> void:
		v.set_resolution(supp_resolutions[idx])
		App.notify_video_changed()
		_refresh_bandwidth_card()
	, _video_box)

	# 4. 屏幕物理刷新率（动态过滤：高刷不可达的物理选项不出现）
	var cur_hz_target := roundi(v.target_refresh_rate()) if v.target_hz > 0 else 0
	var cur_hz_idx := supp_rates.find(cur_hz_target)
	if cur_hz_idx < 0:
		cur_hz_idx = 0

	_add(ParamRow.options("屏幕物理刷新率", hz_labels, cur_hz_idx, "仅显示当前硬件链路支持的刷新率规格，杜绝不可达选项。"), func(idx: int) -> void:
		v.set_refresh_rate(supp_rates[idx])
		App.notify_video_changed()
		_refresh_bandwidth_card()
	, _video_box)

	# 5. 视频传输带宽与接口线缆瓶颈卡片
	_video_box.add_child(_build_bandwidth_card())
	_refresh_bandwidth_card()

	_section("性能与延迟优化 (Performance & Latency)", _video_box)

	# 垂直同步
	_add(ParamRow.options("垂直同步", PackedStringArray(["关闭 (最低输入延迟 · 竞技推荐)", "开启 (消除画面撕裂)", "自适应 (动态帧率匹配)"]), v.vsync, "建议保持【关闭】。垂直同步会强制对齐刷新周期，产生 1~2 帧（16~32ms）的严重输入延迟，影响摇杆微操肌肉记忆。"), func(idx: int) -> void:
		v.vsync = idx as VideoConfig.VSyncMode
		App.notify_video_changed()
	, _video_box)

	# 最大帧率
	_add(ParamRow.options("最大帧率上限", PackedStringArray(VideoConfig.FPS_LABELS), v.max_fps_index, "限制引擎渲染帧率或保持无限制。更高的帧率能降低输入端采样轮询延迟与视角跟手感。"), func(idx: int) -> void:
		v.max_fps_index = idx
		App.notify_video_changed()
	, _video_box)

	# 3D 抗锯齿
	_add(ParamRow.options("3D 抗锯齿", PackedStringArray(["关闭 (最高帧率)", "MSAA 2X (推荐平衡)", "MSAA 4X (高质量)", "MSAA 8X (极致画质)"]), v.msaa, "平滑靶机边缘锯齿。弱显卡或追求极限帧率时可关闭；主流配置推荐保持 2X。"), func(idx: int) -> void:
		v.msaa = idx as VideoConfig.AntiAliasing
		App.notify_video_changed()
	, _video_box)

	_section("枪械模型与音效 (Weapon Model & Audio)", _video_box)

	# 枪模外观选择
	_add(ParamRow.options("第一人称枪模外观", PackedStringArray(AppState.WEAPON_VISUAL_LABELS), App.weapon_visual, "自由选择手中所持第一人称 3D 枪械模型：根据训练场景自动匹配、强制手持 M4 突击步枪、强制手持沙漠之鹰 .50，或关闭枪模进行纯准星极简练枪。"), func(idx: int) -> void:
		App.weapon_visual = idx as AppState.WeaponVisualMode
		App.notify_weapon_visual_changed()
	, _video_box)

	# 音效开关
	_add(ParamRow.options("音效系统", PackedStringArray(["开启 (真实枪声与击中音效)", "静音 (无音效)"]), 0 if App.sfx_enabled else 1, "开关射击音效、开镜音效、命中'叮'声与靶机击毁确认音。"), func(idx: int) -> void:
		App.sfx_enabled = (idx == 0)
		App.notify_audio_changed()
	, _video_box)

	# 音效音量
	_add(ParamRow.slider("音效主音量", 0.0, 1.0, 0.05, App.sfx_volume, "", 2, "调节枪声与命中反馈音量的输出响度。"), func(val: float) -> void:
		App.sfx_volume = val
		App.notify_audio_changed()
	, _video_box)


func _build_bandwidth_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 14))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	_bandwidth_text = UITheme.label("", 13, UITheme.TEXT)
	_bandwidth_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_bandwidth_text)

	_bandwidth_alert = UITheme.label("", 13, UITheme.ACCENT_WARM)
	_bandwidth_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bandwidth_alert.visible = false
	vbox.add_child(_bandwidth_alert)

	return card


func _refresh_bandwidth_card() -> void:
	if _bandwidth_text == null:
		return
	var v := App.video
	var res := v.current_resolution()
	var hz := v.target_refresh_rate()
	var info := VideoConfig.bandwidth_info(res, hz)

	var lines := PackedStringArray([
		"🖥️ 当前输出链路规格： %d × %d @ %.0f Hz" % [res.x, res.y, hz],
		"📡 预估未压缩视频传输带宽： %.1f Gbps（%s）" % [info.gbps, info.tier],
		"🔌 接口与线缆协议需求：%s" % info.cable,
	])
	if v.display_mode == VideoConfig.DisplayMode.WINDOWED:
		lines.append("💡 提示：窗口化模式受 Windows DWM 桌面合成器影响；如需锁定物理高刷与最低输入延迟，推荐使用【独占全屏】。")
	_bandwidth_text.text = "\n".join(lines)

	if _bandwidth_alert != null:
		if info.warning != "":
			_bandwidth_alert.text = info.warning
			_bandwidth_alert.visible = true
		else:
			_bandwidth_alert.visible = false


# ---------------------------------------------------------------------------
# 分页五：数据
# ---------------------------------------------------------------------------

func _populate_data() -> void:
	_clear(_data_box)
	_data_box.add_child(UITheme.heading("📊 摇杆偏转量分布 (Deflection Histogram)"))
	_data_box.add_child(UITheme.hint(
		"只统计摇杆真正在动的时间。橙色的前三个桶是微操区（0~30% 行程）——"
		+ "如果你的时间大量落在这里，那么响应曲线的前段就是最该被调好的部分，"
		+ "而边缘段调多少都感觉不到。这是普通练枪软件给不了的信息。"
	))
	_histogram = Histogram.new()
	_histogram.custom_minimum_size = Vector2(460, 160)
	_data_box.add_child(_histogram)

	_data_box.add_child(UITheme.separator())
	_data_box.add_child(UITheme.heading("📈 本局详细遥测 (Session Telemetry)"))
	
	var grid_card := PanelContainer.new()
	grid_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 14))
	_data_box.add_child(grid_card)

	_data_text = UITheme.label("", 14, UITheme.TEXT)
	_data_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_card.add_child(_data_text)
	_refresh_data()


func _refresh_data() -> void:
	if scenario == null or _histogram == null or _data_text == null:
		return
	var s := scenario.stats
	var ratios := PackedFloat32Array()
	for i in SessionStats.BUCKETS:
		ratios.append(s.bucket_ratio(i))
	_histogram.set_values(ratios)
	_histogram.caption = "摇杆偏转量"

	_data_text.text = "\n".join(PackedStringArray([
		"• 训练用时:　　%.1f 秒" % s.elapsed,
		"• 命中率:　　　%d%%（命中 %d / 射击 %d）" % [roundi(s.accuracy() * 100.0), s.hits, s.shots],
		"• 击杀统计:　　%d 次击杀（每秒 %.2f 次）" % [s.kills, s.kills_per_second()],
		"• 在靶时间:　　%.1f 秒（占比 %d%%）" % [s.time_on_target, roundi(s.time_on_target_ratio() * 100.0)],
		"• 平均转移:　　%.0f 毫秒" % (s.avg_reaction() * 1000.0),
		"• 平均偏转量:　%.2f" % s.avg_deflection(),
		"• 推杆活跃时间: 占全局 %d%%" % roundi(s.active_ratio() * 100.0),
		"• 微操区占比:　%d%%（0~0.3 行程）" % roundi(s.fine_control_ratio() * 100.0),
		"• 辅助瞄准干预: %d%% 的时间视角受到了辅助修正" % roundi(s.assist_ratio() * 100.0),
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
	if visible:
		_queue_controller_focus()


func _queue_controller_focus() -> void:
	_focus_first_control.call_deferred()


func _focus_first_control() -> void:
	if not visible or _tabs == null or _tabs.get_tab_count() == 0:
		return
	var page := _tabs.get_child(_tabs.current_tab)
	var first := _find_focusable(page)
	if first == null:
		first = _save_btn
	if first != null and first.is_visible_in_tree():
		_focus_control(first)


func _find_focusable(node: Node) -> Control:
	if node is Control:
		var control := node as Control
		var actionable := control is BaseButton or control is Range
		if actionable and control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
			if not (control is BaseButton and (control as BaseButton).disabled):
				return control
	for child in node.get_children():
		var found := _find_focusable(child)
		if found != null:
			return found
	return null


func _advance_nav_repeat(delta: float) -> void:
	if _held_nav == Vector2i.ZERO:
		return
	_nav_repeat_left -= delta
	if _nav_repeat_left > 0.0:
		return
	_navigate(_held_nav)
	_nav_repeat_left = _NAV_REPEAT_INTERVAL


func _stick_direction() -> Vector2i:
	if maxf(absf(_stick_nav.x), absf(_stick_nav.y)) < _STICK_NAV_THRESHOLD:
		return Vector2i.ZERO
	if absf(_stick_nav.y) >= absf(_stick_nav.x):
		return Vector2i.DOWN if _stick_nav.y > 0.0 else Vector2i.UP
	return Vector2i.RIGHT if _stick_nav.x > 0.0 else Vector2i.LEFT


func _navigate(direction: Vector2i) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var rows := _controller_rows()
	if rows.is_empty():
		return
	if focus == null or not is_ancestor_of(focus):
		_focus_control(rows[0][0])
		return
	if direction.y != 0:
		_navigate_vertical(focus, rows, direction.y)
	else:
		_navigate_horizontal(focus, rows, direction.x)


func _navigate_vertical(focus: Control, rows: Array, step: int) -> void:
	var row_index := _row_containing(rows, focus)
	if row_index < 0:
		_focus_control(rows[0][0])
		return
	var next_row: Array = rows[wrapi(row_index + step, 0, rows.size())]
	var focus_x := focus.global_position.x + focus.size.x * 0.5
	var best := next_row[0] as Control
	var best_distance := INF
	for candidate in next_row:
		var control := candidate as Control
		var center_x := control.global_position.x + control.size.x * 0.5
		var distance := absf(center_x - focus_x)
		if distance < best_distance:
			best = control
			best_distance = distance
	_focus_control(best)


func _navigate_horizontal(focus: Control, rows: Array, step: int) -> void:
	if focus is Range:
		var range := focus as Range
		var increment := range.step if range.step > 0.0 else (range.max_value - range.min_value) / 100.0
		range.value = clampf(range.value + increment * step, range.min_value, range.max_value)
		return
	if focus is CheckButton:
		var check := focus as CheckButton
		check.button_pressed = step > 0
		return
	if focus is OptionButton:
		var option := focus as OptionButton
		if option.item_count > 0:
			var selected := wrapi(option.selected + step, 0, option.item_count)
			option.select(selected)
			option.item_selected.emit(selected)
		return
	var row_index := _row_containing(rows, focus)
	if row_index < 0:
		return
	var row: Array = rows[row_index]
	if row.size() <= 1:
		return
	var item_index := row.find(focus)
	_focus_control(row[wrapi(item_index + step, 0, row.size())])


func _controller_rows() -> Array:
	var items: Array[Control] = []
	if _tabs != null and _tabs.get_tab_count() > 0:
		_collect_focusable(_tabs.get_child(_tabs.current_tab), items)
	for button in [_save_btn, _reset_btn, _menu_btn]:
		if button != null and button.is_visible_in_tree():
			items.append(button)
	items.sort_custom(func(a: Control, b: Control) -> bool:
		if absf(a.global_position.y - b.global_position.y) <= _ROW_Y_TOLERANCE:
			return a.global_position.x < b.global_position.x
		return a.global_position.y < b.global_position.y
	)
	var rows: Array = []
	for item in items:
		if rows.is_empty():
			rows.append([item])
			continue
		var row: Array = rows[-1]
		var anchor := row[0] as Control
		if absf(item.global_position.y - anchor.global_position.y) <= _ROW_Y_TOLERANCE:
			row.append(item)
		else:
			rows.append([item])
	return rows


func _collect_focusable(node: Node, out: Array[Control]) -> void:
	if node is Control:
		var control := node as Control
		var actionable := control is BaseButton or control is Range
		if actionable and control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
			if not (control is BaseButton and (control as BaseButton).disabled):
				out.append(control)
	for child in node.get_children():
		_collect_focusable(child, out)


func _row_containing(rows: Array, focus: Control) -> int:
	for i in rows.size():
		if (rows[i] as Array).has(focus):
			return i
	return -1


func _focus_control(control: Control) -> void:
	control.grab_focus()
	_ensure_focus_visible.bind(control).call_deferred()


func _ensure_focus_visible(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var parent := control.get_parent()
	while parent != null and parent != self:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
			return
		parent = parent.get_parent()
