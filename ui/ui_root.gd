## 界面根节点：装配主菜单、HUD、参数面板与结算面板。
class_name UIRoot
extends CanvasLayer

signal settings_toggled(open: bool)
signal restart_requested
signal random_requested
signal scenario_requested(def: ScenarioDef)
signal menu_requested
signal quit_requested

var _menu: MainMenu
var _hud: HUD
var _settings: SettingsPanel
var _results: ResultsPanel
var _in_session: bool = false


func _ready() -> void:
	var theme := UITheme.build_theme()

	_hud = HUD.new()
	_hud.theme = theme
	_hud.hide()
	add_child(_hud)

	_menu = MainMenu.new()
	_menu.theme = theme
	_menu.random_requested.connect(func() -> void: random_requested.emit())
	_menu.scenario_requested.connect(func(d: ScenarioDef) -> void: scenario_requested.emit(d))
	_menu.settings_requested.connect(func() -> void: set_settings_open(true))
	_menu.quit_requested.connect(func() -> void: quit_requested.emit())
	add_child(_menu)

	_settings = SettingsPanel.new()
	_settings.theme = theme
	_settings.hide()
	_settings.menu_requested.connect(func() -> void: menu_requested.emit())
	add_child(_settings)

	_results = ResultsPanel.new()
	_results.theme = theme
	_results.restart_requested.connect(func() -> void: restart_requested.emit())
	_results.settings_requested.connect(func() -> void: set_settings_open(true))
	_results.menu_requested.connect(func() -> void: menu_requested.emit())
	add_child(_results)


func bind(player: Player, scenario: Scenario) -> void:
	_hud.player = player
	_hud.scenario = scenario
	_settings.player = player
	_settings.scenario = scenario
	_settings.rebuild_all()


func _process(_delta: float) -> void:
	if _in_session and not _settings.visible:
		_hud.refresh()


func menu_visible() -> bool:
	return _menu.visible and not _settings.visible


func in_session() -> bool:
	return _in_session


func enter_play() -> void:
	_in_session = true
	_menu.hide()
	_hud.show()
	hide_results()
	set_settings_open(false)
	_settings.set_can_return_to_menu(true)


func exit_play() -> void:
	_in_session = false
	_hud.hide()
	hide_results()
	set_settings_open(false)
	_settings.set_can_return_to_menu(false)
	_menu.show_home()


func settings_open() -> bool:
	return _settings.visible


func toggle_settings() -> void:
	set_settings_open(not _settings.visible)


func set_settings_open(open: bool) -> void:
	if open == _settings.visible:
		return
	_settings.visible = open
	if open:
		_results.hide()
		_settings.rebuild_all()
		# 主菜单上打开设置时，菜单还在下面衬着；局内则 HUD 继续画准星没问题。
	elif not _in_session:
		_menu.show_home()
	settings_toggled.emit(open)


func open_settings_tab(index: int) -> void:
	set_settings_open(true)
	_settings.open_tab(index)


func menu_go_home() -> void:
	if _settings.visible:
		set_settings_open(false)
		return
	_menu.show_home()


func toggle_debug() -> void:
	_hud.debug_visible = not _hud.debug_visible
	_hud.queue_redraw()


func show_results() -> void:
	_results.show_for(_settings.scenario)


func hide_results() -> void:
	_results.hide()
