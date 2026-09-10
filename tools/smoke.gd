## 集成冒烟测试：把整个游戏真正跑一遍，覆盖单元测试够不到的装配与生命周期。
##
##   godot --headless --path . tools/smoke.tscn
##
## 单元测试只覆盖 core/ 的纯函数，装配错误（信号没接、节点取不到、
## 一局结束后状态没清干净）它一个都发现不了，那些恰恰是改动时最容易弄坏的地方。
extends Node

const SHORT_DURATION := 0.6

var _failures: PackedStringArray = []
var _main: Node
var _ui: UIRoot
var _scenario: Scenario
var _player: Player


func _ready() -> void:
	_run()


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_ui = _main.get_node("UI")
	_scenario = _main.get_node("ScenarioHost")
	_player = _main.get_node("Player")
	await _frames(5)

	await _check_starts_on_menu()
	await _check_controller_ui_flow()
	await _check_each_scenario_preset()
	await _check_targets_stay_above_floor()
	await _check_targets_keep_respawning()
	await _check_round_finishes()
	await _check_settings_pause()
	await _check_settings_apply_live()
	await _check_profile_presets_hot_swap()
	await _check_shooting_range_distance_maintained()
	await _check_return_to_menu()

	print("")
	if _failures.is_empty():
		print("冒烟测试通过。")
		get_tree().quit(0)
		return
	print("冒烟测试失败：")
	for f in _failures:
		print("  " + f)
	get_tree().quit(1)


func _check_starts_on_menu() -> void:
	_expect(not _scenario.running, "启动不应直接开局")
	_expect(not _player.active, "启动时玩家应待机")
	_expect(_ui.menu_visible(), "启动应停在主菜单")
	print("[OK] 启动停在主菜单")


func _check_controller_ui_flow() -> void:
	await _tap_joy(JOY_BUTTON_DPAD_DOWN)
	await _tap_joy(JOY_BUTTON_DPAD_DOWN)
	await _tap_joy(JOY_BUTTON_A)
	_expect(_ui.settings_open(), "主菜单应通过上下选择与 A 打开设置")
	var settings := _ui.get("_settings") as SettingsPanel
	var focus := get_viewport().gui_get_focus_owner()
	_expect(focus != null and settings.is_ancestor_of(focus), "设置打开后焦点应落在可操作控件上")
	var first_focus := focus
	await _tap_axis(JOY_AXIS_LEFT_Y, 1.0)
	focus = get_viewport().gui_get_focus_owner()
	_expect(focus != first_focus, "设置中左摇杆向下应严格移动到下一行")

	var tabs := settings.get("_tabs") as TabContainer
	var before_tab: int = tabs.current_tab
	await _tap_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(tabs.current_tab == before_tab + 1, "RB 应切换到下一设置分页")

	var page := tabs.get_child(tabs.current_tab)
	var sliders := page.find_children("*", "HSlider", true, false)
	var slider := sliders[0] as HSlider
	slider.grab_focus()
	var before_value := slider.value
	await _tap_joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(slider.value > before_value, "D-pad 左右应能调节设置滑块")

	var checks := page.find_children("*", "CheckButton", true, false)
	var check := checks[0] as CheckButton
	check.grab_focus()
	var before_checked := check.button_pressed
	await _tap_joy(JOY_BUTTON_A)
	_expect(check.button_pressed != before_checked, "A 应能切换设置开关")

	await _tap_joy(JOY_BUTTON_RIGHT_SHOULDER)
	page = tabs.get_child(tabs.current_tab)
	var options := page.find_children("*", "OptionButton", true, false)
	var option := options[0] as OptionButton
	option.grab_focus()
	var before_option := option.selected
	await _tap_joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(option.selected != before_option, "选项折叠时左右应直接切换值")
	await _tap_joy(JOY_BUTTON_A)
	_expect(option.get_popup().visible, "A 应能打开设置选项")
	await _tap_joy(JOY_BUTTON_B)
	_expect(_ui.settings_open() and not option.get_popup().visible, "选项展开时 B 应先关闭选项")

	await _tap_joy(JOY_BUTTON_B)
	_expect(not _ui.settings_open() and _ui.menu_visible(), "设置中按 B 应返回主菜单")

	var menu := _ui.get("_menu") as MainMenu
	await _tap_joy(JOY_BUTTON_DPAD_DOWN)
	await _tap_joy(JOY_BUTTON_A)
	var scenario_page := menu.get("_scenario_page") as Control
	_expect(scenario_page.visible, "主菜单应能用方向键与 A 进入场景选择")
	await _tap_joy(JOY_BUTTON_B)
	_expect(not scenario_page.visible and _ui.menu_visible(), "场景选择中按 B 应返回主页")
	print("[OK] 手柄可打开设置、切页、聚焦、调值、确认并返回")


# 四种场景都要能布置出靶机并正常推进。靶机数、运动方式各不相同，
# 任何一种的参数组合让 _pick_position 死循环或 setup 出错都会在这里暴露。
func _check_each_scenario_preset() -> void:
	for def in ScenarioDef.all_presets():
		def.duration = 30.0
		_main.start_session(def)
		await _frames(20)
		_expect(_scenario.running, "%s：应处于进行中" % def.display_name)
		_expect(not _ui.menu_visible(), "%s：开局后主菜单应关掉" % def.display_name)
		_expect(
			_scenario.active_targets().size() == def.target_count,
			"%s：靶机数应为 %d，实际 %d" % [
				def.display_name, def.target_count, _scenario.active_targets().size(),
			],
		)
		_expect(_scenario.elapsed() > 0.0, "%s：计时应在推进" % def.display_name)
	print("[OK] 四种场景均可正常开局")


# 极端垂直散布与三维运动也不能让球体中心随机到地板下，或在运动后穿地。
func _check_targets_stay_above_floor() -> void:
	var def := ScenarioDef.preset_precision()
	def.duration = 30.0
	def.target_count = 12
	def.target_radius = 2.0
	def.spread_v = 20.0
	_main.start_session(def)
	await _frames(3)

	for node in _scenario.active_targets():
		var target := node as Target
		_expect(
			target.global_position.y >= Target.minimum_center_height(target.radius),
			"随机出生的目标不得落到地板下",
		)

	var moving := _scenario.active_targets()[0] as Target
	moving.motion = ScenarioDef.Motion.DRIFT
	moving.speed = 20.0
	moving.set("_dir", Vector3.DOWN)
	moving._process(1.0)
	_expect(
		moving.global_position.y >= Target.minimum_center_height(moving.radius),
		"三维运动后的目标不得穿入地板",
	)
	print("[OK] 目标生成与运动均受地面边界约束")


# 场次以倒计时为生命周期。无论是否开启“换位重生”，连续打完初始靶机后
# 都必须还有可射击目标；这个链路不能只靠“开局时数量正确”的测试覆盖。
func _check_targets_keep_respawning() -> void:
	for relocates in [true, false]:
		var def := ScenarioDef.preset_flick()
		def.duration = 30.0
		def.target_count = 2
		def.hits_to_kill = 1
		def.respawn_on_hit = relocates
		_main.start_session(def)
		await _frames(3)

		for shot in 8:
			var target := _scenario.active_targets()[shot % def.target_count] as Target
			var before := target.global_position
			_expect(target.take_hit(), "单发击杀场景中命中应击毁目标")
			_scenario.report_kill(target)
			_expect(_scenario.running, "连续击毁后场次应继续到倒计时结束")
			_expect(target.alive and target.visible, "击毁后应立即补回可射击目标")
			if not relocates:
				_expect(target.global_position.is_equal_approx(before), "关闭换位时目标应原地重生")

		_expect(_scenario.active_targets().size() == def.target_count, "重生过程不应改变目标总数")
		_expect(_scenario.stats.kills == 8, "连续击毁应完整计分")
	print("[OK] 连续击毁后目标持续补充")


func _check_round_finishes() -> void:
	var def := ScenarioDef.preset_flick()
	def.duration = SHORT_DURATION
	_main.start_session(def)
	await _seconds(SHORT_DURATION + 0.4)
	_expect(not _scenario.running, "到时后场次应停止")
	_expect(not _player.active, "到时后玩家应停止，否则结算面板后面还在偷偷计分")
	var results := _ui.get("_results") as ResultsPanel
	var focus := get_viewport().gui_get_focus_owner()
	_expect(focus != null and results.is_ancestor_of(focus), "结算页应自动取得手柄焦点")
	await _tap_joy(JOY_BUTTON_A)
	_expect(_scenario.running and _player.active, "结算页按 A 应立即再来一局")
	print("[OK] 一局到时后正常结算")


func _check_settings_pause() -> void:
	var def := ScenarioDef.preset_tracking()
	def.duration = 30.0
	_main.start_session(def)
	await _frames(15)

	await _tap_joy(JOY_BUTTON_START)
	await _frames(2)
	var t0 := _scenario.elapsed()
	var pos0: Array[Vector3] = []
	for node in _scenario.active_targets():
		pos0.append((node as Target).global_position)

	await _frames(25)
	_expect(not _player.active, "打开参数面板时玩家应暂停")
	_expect(_scenario.paused, "打开参数面板时应冻结场次")
	_expect(absf(_scenario.elapsed() - t0) < 0.0001, "菜单打开时计时不应前进")
	for i in pos0.size():
		var now: Vector3 = (_scenario.active_targets()[i] as Target).global_position
		_expect(now.distance_to(pos0[i]) < 0.001, "菜单打开时靶机不应移动")

	await _tap_joy(JOY_BUTTON_START)
	await _frames(15)
	_expect(_player.active, "关闭参数面板后玩家应恢复")
	_expect(not _scenario.paused, "关闭参数面板后场次应解除冻结")
	_expect(_scenario.elapsed() > t0, "关闭参数面板后计时应继续")
	print("[OK] 参数面板正确暂停与恢复")


func _check_settings_apply_live() -> void:
	var def := ScenarioDef.preset_flick()
	def.duration = 60.0
	def.target_count = 2
	def.target_radius = 0.3
	_main.start_session(def)
	await _frames(8)

	App.profile.yaw_speed = 777.0
	App.notify_profile_changed()
	_expect(is_equal_approx(_player.processor.profile.yaw_speed, 777.0), "摇杆转速应立刻作用到输入管线")

	App.assist.master_strength = 0.33
	App.notify_assist_changed()
	_expect(is_equal_approx(_player.assist.config.master_strength, 0.33), "辅助强度应立刻作用到瞄准")

	App.scenario.target_count = 5
	App.scenario.target_radius = 0.8
	_scenario.apply_live()
	_expect(_scenario.active_targets().size() == 5, "靶机数量应立刻增减，不必重开")
	var r: float = (_scenario.active_targets()[0] as Target).radius
	_expect(is_equal_approx(r, 0.8), "靶机半径应立刻变化")
	print("[OK] 设置立刻作用于当前这一局")


# 手感参数是热更新的：换预设不能重开局，但必须立刻作用到管线上。
func _check_profile_presets_hot_swap() -> void:
	var before := _scenario.elapsed()
	for p in ControllerProfile.all_presets():
		App.apply_profile_preset(p)
		await _frames(3)
		_expect(
			_player.processor.profile == p,
			"切换到「%s」后管线应立刻用上新配置" % p.profile_name,
		)
	for c in AimAssistConfig.all_presets():
		App.apply_assist_preset(c)
		await _frames(3)
		_expect(_player.assist.config == c, "切换到「%s」后辅助应立刻生效" % c.config_name)
	_expect(_scenario.elapsed() >= before, "换手感参数不该重开当前这一局")
	print("[OK] 手感与辅助参数热更新，且不打断当前场次")


func _check_shooting_range_distance_maintained() -> void:
	_main.start_session(ScenarioDef.preset_flick())
	await _frames(3)

	# 模拟玩家用力持续向前推动左摇杆，试图冲向靶机
	for i in 20:
		_player._advance_movement(Vector2(0.0, -1.0), 0.05)
		await _frames(1)

	_expect(_player.global_position.z >= -0.151, "靶场模式下角色向前移动应被射击席阻挡，不可冲入靶区")
	_expect(_player.global_position.z <= 0.251, "靶场模式下角色应停留在射击席内")

	# 验证与场上所有靶机的纵深距离均保持在设计距离以上
	for node in _scenario.active_targets():
		var t := node as Target
		var depth_dist := _player.global_position.z - t.global_position.z
		_expect(depth_dist >= 14.0, "角色与靶机之间的设计射距应严格保持")

	# 模拟玩家向右横向走位（测试左右不设限制，支持自由晃身与横移跟枪）
	for i in 20:
		_player._advance_movement(Vector2(1.0, 0.0), 0.05)
		await _frames(1)

	_expect(_player.global_position.x > 2.0, "靶场模式下左右行动范围不应限制在小隔间内，应支持自由横向走位")

	print("[OK] 靶场模式严格保持射击距离，且左右走位不设限制")


func _check_return_to_menu() -> void:
	_main.return_to_menu()
	await _frames(8)
	_expect(not _scenario.running, "返回主菜单后场次应停止")
	_expect(not _player.active, "返回主菜单后玩家应待机")
	_expect(_ui.menu_visible(), "应回到主菜单")
	print("[OK] 返回主菜单")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _joy_button(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _tap_joy(button: int) -> void:
	var press := _joy_button(button)
	Input.parse_input_event(press)
	await _frames(2)
	var release := _joy_button(button)
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _tap_axis(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await _frames(2)
	motion = InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = 0.0
	Input.parse_input_event(motion)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
