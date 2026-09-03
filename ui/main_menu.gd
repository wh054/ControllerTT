## 启动主菜单。
##
## 现代主机风格设计：左侧为主操作卡片，右侧为动态详情与配置预览面板，
## 底部常驻手柄操作指示。
class_name MainMenu
extends Control

signal random_requested
signal scenario_requested(def: ScenarioDef)
signal settings_requested
signal quit_requested

var _home: Control
var _scenario_page: Control
var _home_focus: Button
var _scenario_focus: Button

var _preview_title: Label
var _preview_desc: Label
var _preview_badges: HBoxContainer
var _preview_stats: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	show_home()


func show_home() -> void:
	_home.show()
	_scenario_page.hide()
	show()
	if _home_focus != null:
		_home_focus.grab_focus.call_deferred()


func _show_scenarios() -> void:
	_home.hide()
	_scenario_page.show()
	if _scenario_focus != null:
		_scenario_focus.grab_focus.call_deferred()


## 手柄 B / 键盘返回键使用。只有子页面会被消费，主页继续交给上层处理。
func go_back() -> bool:
	if not visible or not _scenario_page.visible:
		return false
	show_home()
	return true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = UITheme.BG_TRANSPARENT
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_home = _build_home()
	add_child(_home)
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scenario_page = _build_scenario_page()
	add_child(_scenario_page)
	_scenario_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_home() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 36)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 24)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_box)

	# 1. 顶部标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root_box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	var title_lbl := UITheme.heading("ControllerTT", 32)
	title_box.add_child(title_lbl)
	title_box.add_child(UITheme.label("手柄摇杆熟练度与手感调优训练器 · Precision Stick Trainer", 13, UITheme.MUTED))
	header.add_child(title_box)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var device_badge := UITheme.tag_badge("🎮 手柄已就绪 · 1:1 纯净输入管线", UITheme.GOOD)
	header.add_child(device_badge)

	# 2. 主内容分栏区（自适应居中排布）
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 36)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content)

	# 左侧菜单列
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 440
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 4.0
	content.add_child(col)

	_home_focus = _menu_card("🎯 随机训练", "从追踪、甩枪、切换、精度中随机抽取立刻开局")
	_home_focus.pressed.connect(func() -> void: random_requested.emit())
	_home_focus.focus_entered.connect(_preview_random)
	_home_focus.mouse_entered.connect(_preview_random)
	col.add_child(_home_focus)

	var scene_btn := _menu_card("🕹️ 场景训练", "针对性训练：追踪跟枪、大幅甩枪、多目标切换或微操精度")
	scene_btn.pressed.connect(_show_scenarios)
	scene_btn.focus_entered.connect(_preview_scenarios)
	scene_btn.mouse_entered.connect(_preview_scenarios)
	col.add_child(scene_btn)

	var settings_btn := _menu_card("⚙️ 参数设置", "死区形状/大小、响应曲线、辅助瞄准算法与偏转遥测")
	settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	settings_btn.focus_entered.connect(_preview_settings)
	settings_btn.mouse_entered.connect(_preview_settings)
	col.add_child(settings_btn)

	var quit_btn := _menu_card("🚪 退出系统", "保存当前参数配置并退出")
	quit_btn.pressed.connect(func() -> void: quit_requested.emit())
	quit_btn.focus_entered.connect(_preview_quit)
	quit_btn.mouse_entered.connect(_preview_quit)
	col.add_child(quit_btn)

	var col_spacer := Control.new()
	col_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(col_spacer)

	# 右侧动态详情预览卡片
	var preview_card := PanelContainer.new()
	preview_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 12, UITheme.OUTLINE, 1, 24))
	preview_card.custom_minimum_size.x = 480
	preview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_card.size_flags_stretch_ratio = 5.0
	content.add_child(preview_card)

	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 14)
	pbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_card.add_child(pbox)

	_preview_title = UITheme.heading("模式详情", 22)
	pbox.add_child(_preview_title)

	_preview_badges = HBoxContainer.new()
	_preview_badges.add_theme_constant_override("separation", 8)
	pbox.add_child(_preview_badges)

	_preview_desc = UITheme.label("", 14, UITheme.TEXT)
	_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pbox.add_child(_preview_desc)

	pbox.add_child(UITheme.separator())

	# 结构化详细属性卡
	var stats_frame := PanelContainer.new()
	stats_frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 14))
	stats_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbox.add_child(stats_frame)

	_preview_stats = UITheme.label("", 13, UITheme.TEXT_SUB)
	_preview_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_frame.add_child(_preview_stats)

	var pbox_spacer := Control.new()
	pbox_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pbox.add_child(pbox_spacer)

	_preview_random()

	# 3. 底部常驻手柄操作栏
	var footer_row := HBoxContainer.new()
	footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.size_flags_vertical = Control.SIZE_SHRINK_END
	root_box.add_child(footer_row)

	var footer := UITheme.button_hints([
		["D-Pad / 左摇杆", "上下导航"],
		["A", "确认进入"],
		["B", "返回"],
		["Start", "调参面板"],
	])
	footer_row.add_child(footer)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_spacer)

	var ver_lbl := UITheme.label("v1.0 · Godot 4.7 引擎支持", 12, UITheme.MUTED)
	footer_row.add_child(ver_lbl)

	return margin


func _build_scenario_page() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 36)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 20)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(UITheme.heading("🕹️ 场景训练 · 选择训练科目", 28))
	title_box.add_child(UITheme.label("选定一个专项训练场景开局。参数可在局内随时暂停调节并即刻生效。", 13, UITheme.MUTED))
	header.add_child(title_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(col)

	var presets := ScenarioDef.all_presets()
	for i in presets.size():
		var def: ScenarioDef = presets[i]
		var b := _scenario_card(def)
		var picked: ScenarioDef = def
		b.pressed.connect(func() -> void: scenario_requested.emit(picked))
		col.add_child(b)
		if i == 0:
			_scenario_focus = b

	var back_btn := _menu_card("↩ 返回上一级", "")
	back_btn.custom_minimum_size.y = 52
	back_btn.pressed.connect(show_home)
	col.add_child(back_btn)

	var scen_spacer := Control.new()
	scen_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scen_spacer)

	var footer := UITheme.button_hints([
		["D-Pad / 左摇杆", "选择科目"],
		["A", "立即开局"],
		["B", "返回主选单"],
	])
	root_box.add_child(footer)

	return margin


func _menu_card(title: String, subtitle: String) -> Button:
	var b := Button.new()
	b.text = title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]
	b.custom_minimum_size = Vector2(0, 52 if subtitle.is_empty() else 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("line_spacing", 4)
	return b


func _scenario_card(def: ScenarioDef) -> Button:
	var b := Button.new()
	var weapon_text := "持续光束" if def.weapon == ScenarioDef.Weapon.BEAM else "单发点射"
	var metric_text := def.primary_metric_label()
	b.text = "%s  [%s · %s]\n%s" % [def.display_name, weapon_text, metric_text, def.description]
	b.custom_minimum_size = Vector2(0, 80)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("line_spacing", 4)
	return b


func _preview_random() -> void:
	_preview_title.text = "🎯 随机训练 (Quick Random)"
	_clear_badges()
	_preview_badges.add_child(UITheme.tag_badge("快速开局", UITheme.GOOD))
	_preview_badges.add_child(UITheme.tag_badge("全科目轮换", UITheme.ACCENT))
	_preview_desc.text = "系统会从四个专项训练场景中随机抽选一项直接开局。\n适合日常快速热手，检验在不同距离与运动模式下的综合控枪适应能力。"
	_preview_stats.text = "科目包含：\n• 追踪模式：考核在中低速段的平稳跟枪与旋转辅助\n• 甩枪模式：考核大幅度跨区定位与过冲抑制\n• 目标切换：考核击杀后向下一目标的快速转移\n• 精细微操：考核死区边缘最低速段的微操准度"


func _preview_scenarios() -> void:
	_preview_title.text = "🕹️ 场景训练 (Scenario Select)"
	_clear_badges()
	_preview_badges.add_child(UITheme.tag_badge("专项练习", UITheme.ACCENT))
	_preview_badges.add_child(UITheme.tag_badge("4大维度", UITheme.ACCENT_WARM))
	_preview_desc.text = "进入场景选择列表，自主选择特定科目进行深入练习。\n所有场景共享同一套纯净物理管线，可自由调配靶机数量、运动幅度与距离散布。"
	_preview_stats.text = "按 A 键可进入场景列表，按 B 随时返回。"


func _preview_settings() -> void:
	_preview_title.text = "⚙️ 参数调优 (Settings Console)"
	_clear_badges()
	_preview_badges.add_child(UITheme.tag_badge("实时热更新", UITheme.ACCENT))
	_preview_badges.add_child(UITheme.tag_badge("死区 / 曲线 / 辅助", UITheme.GOOD))
	var p := App.profile
	var a := App.assist
	var curve_names := ["线性", "指数", "S 曲线", "反 S 曲线", "自定义贝塞尔"]
	var curve_name: String = curve_names[clampi(p.yaw_curve.type, 0, curve_names.size() - 1)]
	_preview_desc.text = "本训练器的核心所在。可在开启训练的同时边推杆边调参，当场观察曲线落点与遥测数据。"
	_preview_stats.text = "当前配置概览：\n• 响应曲线: %s (指数 %.2f)\n• 死区: 内 %.3f / 外 %.3f\n• 转速: 水平 %.0f °/s / 垂直 %.0f °/s\n• 辅助瞄准: %s (总强度 %.2f)" % [
		curve_name, p.yaw_curve.exponent,
		p.look_deadzone.inner, p.look_deadzone.outer,
		p.yaw_speed, p.pitch_speed,
		"开启" if a.enabled else "关闭", a.master_strength,
	]


func _preview_quit() -> void:
	_preview_title.text = "🚪 退出系统 (Exit)"
	_clear_badges()
	_preview_badges.add_child(UITheme.tag_badge("自动保存", UITheme.MUTED))
	_preview_desc.text = "退出 ControllerTT 训练器。\n所有摇杆参数、响应曲线以及辅助瞄准配置会自动持久化保存到本地 user:// 目录。"
	_preview_stats.text = "下次启动时将自动载入当前调优配置。"


func _clear_badges() -> void:
	for c in _preview_badges.get_children():
		c.queue_free()


