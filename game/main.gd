## 顶层装配：主菜单、训练场次、界面与全局快捷键。
extends Node3D

@onready var player: Player = $Player
@onready var scenario: Scenario = $ScenarioHost
@onready var ui: UIRoot = $UI

var _in_session: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	player.scenario = scenario
	player.active = false
	ui.bind(player, scenario)
	ui.settings_toggled.connect(_on_settings_toggled)
	ui.restart_requested.connect(restart)
	ui.random_requested.connect(_on_random)
	ui.scenario_requested.connect(start_session)
	ui.menu_requested.connect(return_to_menu)
	ui.quit_requested.connect(func() -> void: get_tree().quit())
	scenario.finished.connect(_on_scenario_finished)
	# 局内换场景预设才重开；主菜单上改设置不应把人丢进训练场。
	App.scenario_changed.connect(_on_scenario_changed)
	_capture_mouse(false)


func start_session(def: ScenarioDef) -> void:
	App.scenario = def.clone() if def != null else App.scenario
	_in_session = true
	ui.enter_play()
	restart()


func return_to_menu() -> void:
	_in_session = false
	scenario.stop()
	player.active = false
	player.reset_pose()
	ui.exit_play()
	_capture_mouse(false)


func restart() -> void:
	if not _in_session:
		return
	scenario.start(App.scenario)
	player.stats = scenario.stats
	player.reset_pose()
	player.active = not ui.settings_open()
	scenario.set_paused(ui.settings_open())
	ui.hide_results()
	if not ui.settings_open():
		_capture_mouse(true)


func _on_random() -> void:
	var presets := ScenarioDef.all_presets()
	start_session(presets[_rng.randi_range(0, presets.size() - 1)])


func _on_scenario_changed() -> void:
	if _in_session:
		restart()


func _on_scenario_finished() -> void:
	player.active = false
	scenario.set_paused(false)
	ui.show_results()
	_capture_mouse(false)


func _on_settings_toggled(open: bool) -> void:
	if not _in_session:
		_capture_mouse(false)
		return
	scenario.set_paused(open)
	player.active = (not open) and scenario.running
	if not open and scenario.running:
		player.sampler.reset()
	_capture_mouse(not open)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				if _in_session:
					ui.toggle_settings()
				else:
					ui.menu_go_home()
			KEY_R:
				if _in_session:
					restart()
			KEY_F1:
				if _in_session:
					ui.toggle_debug()
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_START:
				ui.toggle_settings()
			JOY_BUTTON_BACK:
				if _in_session:
					restart()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if _in_session and not ui.settings_open() and not ui.menu_visible():
			_capture_mouse(true)


func _capture_mouse(capture: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
