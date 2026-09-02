## 启动主菜单。
##
## 训练器的入口必须先让人选择「练什么」，而不是一打开就丢进上一局的场景——
## 否则「随机训练」和「场景训练」这两个意图会被启动流程吞掉。
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	show_home()


func show_home() -> void:
	_home.show()
	_scenario_page.hide()
	show()
	if _home_focus != null:
		_home_focus.grab_focus()


func _show_scenarios() -> void:
	_home.hide()
	_scenario_page.show()
	if _scenario_focus != null:
		_scenario_focus.grab_focus()


## 手柄 B / 键盘返回键使用。只有子页面会被消费，主页继续交给上层处理。
func go_back() -> bool:
	if not visible or not _scenario_page.visible:
		return false
	show_home()
	return true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_home = _build_home()
	add_child(_home)
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scenario_page = _build_scenario_page()
	add_child(_scenario_page)
	_scenario_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_home() -> Control:
	var root := Control.new()
	var col := _menu_column()
	root.add_child(col)

	col.add_child(UITheme.label("ControllerTT", 36, UITheme.TEXT))
	col.add_child(UITheme.label("手柄摇杆训练器", 16, UITheme.MUTED))
	col.add_child(_gap(18))

	_home_focus = _menu_button("随机训练", "从四个场景里抽一个立刻开局")
	_home_focus.pressed.connect(func() -> void: random_requested.emit())
	col.add_child(_home_focus)

	var scene_btn := _menu_button("场景训练", "自己选追踪、甩枪、切换或精度")
	scene_btn.pressed.connect(_show_scenarios)
	col.add_child(scene_btn)

	var settings_btn := _menu_button("设置", "死区、响应曲线、辅助瞄准")
	settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	col.add_child(settings_btn)

	var quit_btn := _menu_button("退出", "")
	quit_btn.pressed.connect(func() -> void: quit_requested.emit())
	col.add_child(quit_btn)

	col.add_child(_gap(12))
	col.add_child(UITheme.hint("方向键 / 左摇杆选择，A / 回车确认"))
	return root


func _build_scenario_page() -> Control:
	var root := Control.new()
	var col := _menu_column()
	root.add_child(col)

	col.add_child(UITheme.label("场景训练", 28, UITheme.TEXT))
	col.add_child(UITheme.hint("选一个场景开局。参数可在局内或设置里再调。"))
	col.add_child(_gap(14))

	var presets := ScenarioDef.all_presets()
	for i in presets.size():
		var def: ScenarioDef = presets[i]
		var b := _menu_button(def.display_name, def.description)
		# 闭包按值捕获，避免循环变量全部指向最后一个。
		var picked: ScenarioDef = def
		b.pressed.connect(func() -> void: scenario_requested.emit(picked))
		col.add_child(b)
		if i == 0:
			_scenario_focus = b

	col.add_child(_gap(8))
	var back := _menu_button("返回", "")
	back.pressed.connect(show_home)
	col.add_child(back)
	return root


func _menu_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.position = Vector2(72, 90)
	col.custom_minimum_size.x = 420
	return col


func _menu_button(title: String, hint: String) -> Button:
	var b := Button.new()
	b.text = title if hint.is_empty() else "%s\n%s" % [title, hint]
	b.custom_minimum_size = Vector2(420, 52 if hint.is_empty() else 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	b.add_theme_color_override("font_focus_color", UITheme.ACCENT)
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
