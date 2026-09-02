## 界面根节点：装配 HUD、参数面板与结算面板，并对外暴露开关。
class_name UIRoot
extends CanvasLayer

signal settings_toggled(open: bool)
signal restart_requested

var _hud: HUD
var _settings: SettingsPanel
var _results: ResultsPanel


func _ready() -> void:
	var theme := UITheme.build_theme()

	_hud = HUD.new()
	_hud.theme = theme
	add_child(_hud)

	_settings = SettingsPanel.new()
	_settings.theme = theme
	_settings.hide()
	add_child(_settings)

	_results = ResultsPanel.new()
	_results.theme = theme
	_results.restart_requested.connect(func() -> void: restart_requested.emit())
	_results.settings_requested.connect(func() -> void: set_settings_open(true))
	add_child(_results)


func bind(player: Player, scenario: Scenario) -> void:
	_hud.player = player
	_hud.scenario = scenario
	_settings.player = player
	_settings.scenario = scenario
	_settings.rebuild_all()


func _process(_delta: float) -> void:
	if not _settings.visible:
		_hud.refresh()


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
	settings_toggled.emit(open)


func open_settings_tab(index: int) -> void:
	set_settings_open(true)
	_settings.open_tab(index)


func toggle_debug() -> void:
	_hud.debug_visible = not _hud.debug_visible
	_hud.queue_redraw()


func show_results() -> void:
	_results.show_for(_settings.scenario)


func hide_results() -> void:
	_results.hide()
