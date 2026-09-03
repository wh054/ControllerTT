## 一局结束后的成绩总结。
##
## 现代战报结算卡片：
## 1. 战绩评级徽章 (S / A / B / C)；
## 2. 核心大指标卡片 + 详细战术数据微卡片；
## 3. 偏转量直方图与 AI 智能调参建议指导；
## 4. 手柄一键快速重开 (A/Y)、调参 (X/Start) 与返回 (B)。
class_name ResultsPanel
extends Control

signal restart_requested
signal settings_requested
signal menu_requested

var _title: Label
var _grade_badge: Label
var _hero_metric_title: Label
var _hero_metric_value: Label
var _stat_card_1: Label
var _stat_card_2: Label
var _stat_card_3: Label
var _advice: Label
var _histogram: Histogram
var _again_button: Button
var _settings_button: Button
var _menu_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_Y:
				restart_requested.emit()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_X:
				settings_requested.emit()
				get_viewport().set_input_as_handled()


func show_for(scenario: Scenario) -> void:
	var s := scenario.stats
	var def := App.scenario
	_title.text = "🏆 %s · 训练战报" % def.display_name

	var ratio: float = 0.0
	if def.weapon == ScenarioDef.Weapon.BEAM:
		ratio = s.time_on_target_ratio()
		_hero_metric_title.text = "在靶时间占比"
		_hero_metric_value.text = "%d%%" % roundi(ratio * 100.0)
		_stat_card_1.text = "在靶时长\n%.1f s / %.1f s" % [s.time_on_target, s.elapsed]
		_stat_card_2.text = "平均偏转\n%.2f 强度" % s.avg_deflection()
		_stat_card_3.text = "微操区占比\n%d%% 行程" % roundi(s.fine_control_ratio() * 100.0)
	else:
		ratio = s.accuracy()
		_hero_metric_title.text = "命中率 (Accuracy)"
		_hero_metric_value.text = "%d%%" % roundi(ratio * 100.0)
		_stat_card_1.text = "击杀统计\n%d 击杀 (%.2f/s)" % [s.kills, s.kills_per_second()]
		_stat_card_2.text = "平均转移\n%.0f ms" % (s.avg_reaction() * 1000.0 if not s.reaction_times.is_empty() else 0.0)
		_stat_card_3.text = "辅助生效\n%d%% 时间" % roundi(s.assist_ratio() * 100.0)

	# 评级计算
	var grade := "S"
	var grade_color := UITheme.GOOD
	if ratio >= 0.88:
		grade = "S"
		grade_color = UITheme.ACCENT
	elif ratio >= 0.72:
		grade = "A"
		grade_color = UITheme.GOOD
	elif ratio >= 0.50:
		grade = "B"
		grade_color = UITheme.ACCENT_WARM
	else:
		grade = "C"
		grade_color = UITheme.BAD

	_grade_badge.text = "评级 " + grade
	_grade_badge.add_theme_color_override("font_color", grade_color)

	var ratios := PackedFloat32Array()
	for i in SessionStats.BUCKETS:
		ratios.append(s.bucket_ratio(i))
	_histogram.set_values(ratios)
	_advice.text = _advise(s)
	show()
	_again_button.grab_focus.call_deferred()


# 根据摇杆分布给出下一步该调什么。
func _advise(s: SessionStats) -> String:
	if s.avg_deflection() <= 0.0:
		return "💡 这一局几乎没有推动摇杆，先试着打完一局再看调参建议。"
	var fine := s.fine_control_ratio()
	var assisted := s.assist_ratio()

	var parts := PackedStringArray()
	if fine > 0.65:
		parts.append(
			"💡 你有 %d%% 的推杆时间落在摇杆前 30%% 行程内，手感主要取决于曲线前段。"
			% roundi(fine * 100.0)
			+ "建议在设置中调大指数（或改用反 S 曲线）压平前段，微操控枪会更沉稳。"
		)
	elif fine < 0.25:
		parts.append(
			"💡 你大部分时间都在大幅推杆，曲线前段影响较小。"
			+ "建议优先将满偏转速（Yaw Speed）调至能一次性转到位的灵敏度。"
		)
	else:
		parts.append("💡 摇杆行程分布较均衡，前后段响应曲线都会显著影响手感。")

	if assisted > 0.5 and App.assist.enabled and App.assist.master_strength > 0.3:
		parts.append(
			"⚠️ 本局有 %d%% 的时间视角受到了辅助瞄准干预。"
			% roundi(assisted * 100.0)
			+ "若想检验真实控杆水平，建议将辅助总强度调至 0 再对比一局。"
		)
	return "\n\n".join(parts)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = UITheme.BG_TRANSPARENT
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centerer := CenterContainer.new()
	add_child(centerer)
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 12, UITheme.OUTLINE, 1, 24))
	frame.custom_minimum_size = Vector2(760, 580)
	centerer.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	frame.add_child(box)

	# 顶部标题栏 + 评级徽章
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_title = UITheme.heading("", 22)
	header.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_grade_badge = UITheme.label("评级 S", 20, UITheme.ACCENT)
	header.add_child(_grade_badge)
	box.add_child(header)
	box.add_child(UITheme.separator())

	# 主成绩卡片 + 3 个次级卡片
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	box.add_child(stats_row)

	# 主核心指标卡
	var hero_card := PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE_ACTIVE, 1, 14))
	hero_card.custom_minimum_size = Vector2(220, 100)
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(hero_card)

	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 2)
	hero_card.add_child(hero_box)
	_hero_metric_title = UITheme.label("在靶时间占比", 12, UITheme.MUTED)
	_hero_metric_value = UITheme.label("0%", 34, UITheme.GOOD)
	hero_box.add_child(_hero_metric_title)
	hero_box.add_child(_hero_metric_value)

	# 3 个小数据卡
	_stat_card_1 = _sub_card(stats_row)
	_stat_card_2 = _sub_card(stats_row)
	_stat_card_3 = _sub_card(stats_row)

	# 中间内容区：左侧直方图，右侧 AI 建议卡片
	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 14)
	box.add_child(mid_row)

	var hist_card := PanelContainer.new()
	hist_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 10))
	hist_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_row.add_child(hist_card)

	var hist_box := VBoxContainer.new()
	hist_box.add_theme_constant_override("separation", 6)
	hist_card.add_child(hist_box)
	hist_box.add_child(UITheme.label("摇杆行程偏转分布", 13, UITheme.TEXT))

	_histogram = Histogram.new()
	_histogram.custom_minimum_size = Vector2(320, 140)
	_histogram.caption = "摇杆偏转分布"
	hist_box.add_child(_histogram)

	var advice_card := PanelContainer.new()
	advice_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 14))
	advice_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_row.add_child(advice_card)

	var advice_box := VBoxContainer.new()
	advice_box.add_theme_constant_override("separation", 6)
	advice_card.add_child(advice_box)
	advice_box.add_child(UITheme.label("智能调参指导", 13, UITheme.ACCENT_WARM))

	_advice = UITheme.hint("")
	_advice.custom_minimum_size = Vector2(300, 120)
	advice_box.add_child(_advice)

	box.add_child(UITheme.separator())

	# 底部操作按钮
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	
	_again_button = Button.new()
	_again_button.text = "再来一局"
	_again_button.custom_minimum_size = Vector2(0, 44)
	_again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_again_button.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(_again_button)

	_settings_button = Button.new()
	_settings_button.text = "调整参数"
	_settings_button.custom_minimum_size = Vector2(0, 44)
	_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	buttons.add_child(_settings_button)

	_menu_button = Button.new()
	_menu_button.text = "返回主菜单"
	_menu_button.custom_minimum_size = Vector2(0, 44)
	_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(_menu_button)
	box.add_child(buttons)

	var footer_hints := UITheme.button_hints([
		["A", "再来一局"],
		["X", "调整参数"],
		["B", "返回主菜单"],
	])
	footer_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer_hints)

	hide()


func _sub_card(parent: Container) -> Label:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 8, UITheme.OUTLINE, 1, 10))
	card.custom_minimum_size = Vector2(150, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var l := UITheme.label("", 13, UITheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(l)
	return l

