## 顶层装配：把玩家、场次、界面接在一起，并处理全局快捷键。
extends Node3D

@onready var player: Player = $Player
@onready var scenario: Scenario = $ScenarioHost
@onready var ui: UIRoot = $UI


func _ready() -> void:
	player.scenario = scenario
	ui.bind(player, scenario)
	ui.settings_toggled.connect(_on_settings_toggled)
	ui.restart_requested.connect(restart)
	scenario.finished.connect(_on_scenario_finished)
	# 换场景配置要重开一局；手感参数是热更新的，不该打断当前练习。
	App.scenario_changed.connect(restart)
	restart()
	_capture_mouse(true)


func restart() -> void:
	scenario.start(App.scenario)
	player.stats = scenario.stats
	player.reset_pose()
	player.active = not ui.settings_open()
	ui.hide_results()


func _on_scenario_finished() -> void:
	# 必须停掉玩家，否则结算面板后面还在继续开火与转视角，成绩会被污染。
	player.active = false
	ui.show_results()
	_capture_mouse(false)


func _on_settings_toggled(open: bool) -> void:
	player.active = not open
	_capture_mouse(not open)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				ui.toggle_settings()
			KEY_R:
				restart()
			KEY_F1:
				ui.toggle_debug()
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_START:
				ui.toggle_settings()
			JOY_BUTTON_BACK:
				restart()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if not ui.settings_open():
			_capture_mouse(true)


func _capture_mouse(capture: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
