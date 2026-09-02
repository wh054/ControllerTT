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

	await _check_each_scenario_preset()
	await _check_round_finishes()
	await _check_settings_pause()
	await _check_profile_presets_hot_swap()

	print("")
	if _failures.is_empty():
		print("冒烟测试通过。")
		get_tree().quit(0)
		return
	print("冒烟测试失败：")
	for f in _failures:
		print("  " + f)
	get_tree().quit(1)


# 四种场景都要能布置出靶机并正常推进。靶机数、运动方式各不相同，
# 任何一种的参数组合让 _pick_position 死循环或 setup 出错都会在这里暴露。
func _check_each_scenario_preset() -> void:
	for def in ScenarioDef.all_presets():
		def.duration = 30.0
		App.apply_scenario_preset(def)
		await _frames(20)
		_expect(_scenario.running, "%s：应处于进行中" % def.display_name)
		_expect(
			_scenario.active_targets().size() == def.target_count,
			"%s：靶机数应为 %d，实际 %d" % [
				def.display_name, def.target_count, _scenario.active_targets().size(),
			],
		)
		_expect(_scenario.elapsed() > 0.0, "%s：计时应在推进" % def.display_name)
	print("[OK] 四种场景均可正常开局")


func _check_round_finishes() -> void:
	var def := ScenarioDef.preset_flick()
	def.duration = SHORT_DURATION
	App.apply_scenario_preset(def)
	await _seconds(SHORT_DURATION + 0.4)
	_expect(not _scenario.running, "到时后场次应停止")
	_expect(not _player.active, "到时后玩家应停止，否则结算面板后面还在偷偷计分")
	print("[OK] 一局到时后正常结算")


func _check_settings_pause() -> void:
	_ui.set_settings_open(true)
	await _frames(10)
	_expect(not _player.active, "打开参数面板时玩家应暂停")
	_ui.set_settings_open(false)
	await _frames(10)
	_expect(_player.active, "关闭参数面板后玩家应恢复")
	print("[OK] 参数面板正确暂停与恢复")


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
