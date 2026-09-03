## 离屏截图工具，用于在不手动操作的情况下检查各个界面的渲染是否正常。
##
##   godot --path . --resolution 1600x900 tools/shots.tscn
##
## 输出到 shots/ 目录。该目录下有 .gdignore，否则 Godot 会把这些 png 当作纹理资源
## 导入，给每张图生成一个 .import 文件污染仓库。
##
## 之所以做成一个普通场景而不是 `--script` 脚本：`--script` 模式下自动加载的
## 单例不会被注册，App 会解析不到，整个项目都编译不过。
extends Node

const OUTPUT_DIR := "res://shots"

const WARMUP_FRAMES := 70
const SETTLE_FRAMES := 25


func _ready() -> void:
	_capture_all()


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var main := (load("res://game/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var ui: UIRoot = main.get_node("UI")

	await _wait(WARMUP_FRAMES)
	_save("shot_menu.png")

	var menu := ui.get("_menu") as MainMenu
	menu._show_scenarios()
	await _wait(SETTLE_FRAMES)
	_save("shot_scenarios.png")
	menu.show_home()

	main.start_session(ScenarioDef.preset_tracking())
	await _wait(SETTLE_FRAMES)
	_save("shot_hud.png")

	ui.toggle_debug()
	await _wait(SETTLE_FRAMES)
	_save("shot_hud_bubbles.png")
	ui.toggle_debug()

	# M4 突击步枪持枪视角截图
	main.start_session(ScenarioDef.preset_switching())
	await _wait(SETTLE_FRAMES)
	_save("shot_hud_m4.png")

	# 沙漠之鹰重型手枪持枪视角截图
	main.start_session(ScenarioDef.preset_flick())
	await _wait(SETTLE_FRAMES)
	_save("shot_hud_deagle.png")

	ui.open_settings_tab(SettingsPanel.TAB_STICK)
	await _wait(SETTLE_FRAMES)
	_save("shot_settings_stick.png")

	ui.open_settings_tab(SettingsPanel.TAB_ASSIST)
	await _wait(SETTLE_FRAMES)
	_save("shot_settings_assist.png")

	ui.open_settings_tab(SettingsPanel.TAB_SCENARIO)
	await _wait(SETTLE_FRAMES)
	_save("shot_settings_scenario.png")

	ui.open_settings_tab(SettingsPanel.TAB_VIDEO)
	await _wait(SETTLE_FRAMES)
	_save("shot_settings_video.png")

	ui.open_settings_tab(SettingsPanel.TAB_DATA)
	await _wait(SETTLE_FRAMES)
	_save("shot_settings_data.png")

	ui.set_settings_open(false)
	ui.show_results()
	await _wait(SETTLE_FRAMES)
	_save("shot_results.png")

	get_tree().quit(0)


func _wait(frames: int) -> void:
	for i in frames:
		# 截图工具不该抢走用户的鼠标。
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await get_tree().process_frame


func _save(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	print("shots/%s -> %s" % [file_name, "OK" if err == OK else "失败 %d" % err])
