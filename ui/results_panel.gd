## 一局结束后的成绩总结。
##
## 除了成绩，这里会根据本局的摇杆分布给出一条**指向性建议**——
## 训练工具如果只丢一堆数字给使用者，多数人不知道下一步该调哪个参数。
class_name ResultsPanel
extends Control

signal restart_requested
signal settings_requested
signal menu_requested

var _title: Label
var _body: Label
var _advice: Label
var _histogram: Histogram
var _again_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func show_for(scenario: Scenario) -> void:
	var s := scenario.stats
	var def := App.scenario
	_title.text = "%s · 本局结束" % def.display_name

	var lines := PackedStringArray()
	if def.weapon == ScenarioDef.Weapon.BEAM:
		lines.append("在靶时间占比　　%d%%" % roundi(s.time_on_target_ratio() * 100.0))
		lines.append("在靶 %.1f s / 总计 %.1f s" % [s.time_on_target, s.elapsed])
	else:
		lines.append("命中率　　　　　%d%%（%d / %d）" % [
			roundi(s.accuracy() * 100.0), s.hits, s.shots,
		])
		lines.append("击杀 %d，每秒 %.2f" % [s.kills, s.kills_per_second()])
		if not s.reaction_times.is_empty():
			lines.append("平均转移 %.0f ms" % (s.avg_reaction() * 1000.0))
	lines.append("")
	lines.append("平均偏转量　　　%.2f" % s.avg_deflection())
	lines.append("微操区（0~0.3）占推杆时间 %d%%" % roundi(s.fine_control_ratio() * 100.0))
	lines.append("辅助瞄准实际生效　%d%% 的时间" % roundi(s.assist_ratio() * 100.0))
	_body.text = "\n".join(lines)

	var ratios := PackedFloat32Array()
	for i in SessionStats.BUCKETS:
		ratios.append(s.bucket_ratio(i))
	_histogram.set_values(ratios)
	_advice.text = _advise(s)
	show()
	# 场次结束时焦点通常还留在已隐藏的 HUD / 设置控件上。
	# 主动落到“再来一局”，手柄无需先碰鼠标即可继续。
	_again_button.grab_focus.call_deferred()


# 根据摇杆分布给出下一步该调什么。规则很朴素，但比一堆裸数字有用得多。
func _advise(s: SessionStats) -> String:
	if s.avg_deflection() <= 0.0:
		return "这一局几乎没有推动摇杆，先试着打完一局再看建议。"
	var fine := s.fine_control_ratio()
	var assisted := s.assist_ratio()

	var parts := PackedStringArray()
	if fine > 0.65:
		parts.append(
			"你有 %d%% 的推杆时间落在摇杆前 30%% 行程内，说明手感几乎完全取决于曲线前段。"
			% roundi(fine * 100.0)
			+ "可以试着调大指数（或改用反 S 曲线）把前段压得更平，微操会明显变细。"
		)
	elif fine < 0.25:
		parts.append(
			"你大部分时间都在大幅推杆，曲线前段对你影响很小。"
			+ "相比调曲线，先把满偏转速调到能一次转到位可能更有效。"
		)
	else:
		parts.append("摇杆行程用得比较均衡，曲线前后段都会影响你的手感。")

	if assisted > 0.5 and App.assist.enabled and App.assist.master_strength > 0.3:
		parts.append(
			"本局有 %d%% 的时间视角受到了辅助干预。想知道自己的真实水平，"
			% roundi(assisted * 100.0)
			+ "把总强度调到 0 再打一局做对比。"
		)
	return "\n\n".join(parts)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 用 CenterContainer 而不是手算居中偏移：结算内容的行数会随场景类型变化，
	# 手算的偏移只在构建那一刻正确。
	var centerer := CenterContainer.new()
	add_child(centerer)
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, 10))
	frame.custom_minimum_size = Vector2(560, 0)
	centerer.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	frame.add_child(box)

	_title = UITheme.label("", 22, UITheme.ACCENT)
	box.add_child(_title)

	_body = UITheme.label("", 15)
	box.add_child(_body)

	_histogram = Histogram.new()
	_histogram.custom_minimum_size = Vector2(480, 120)
	_histogram.caption = "摇杆偏转量分布"
	box.add_child(_histogram)

	_advice = UITheme.hint("")
	_advice.custom_minimum_size.x = 480
	box.add_child(_advice)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_again_button = Button.new()
	_again_button.text = "再来一局（A / Y）"
	_again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_again_button.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(_again_button)

	var tune := Button.new()
	tune.text = "调整参数（Start / Esc）"
	tune.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tune.pressed.connect(func() -> void: settings_requested.emit())
	buttons.add_child(tune)

	var home := Button.new()
	home.text = "返回主菜单"
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(home)
	box.add_child(buttons)

	hide()
