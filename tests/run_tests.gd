## 测试入口。用法：
##   godot --headless --path . --script tests/run_tests.gd
##
## 退出码 0 表示全部通过，1 表示有失败，便于将来接 CI。
extends SceneTree

const SUITES := [
	preload("res://tests/test_response_curve.gd"),
	preload("res://tests/test_deadzone.gd"),
	preload("res://tests/test_stick_processor.gd"),
	preload("res://tests/test_aim_assist.gd"),
	preload("res://tests/test_hit_test.gd"),
]


func _initialize() -> void:
	var total_passed := 0
	var all_failures: PackedStringArray = []

	print("")
	print("=== ControllerTT 核心域测试 ===")
	for suite_script in SUITES:
		var suite: TestCase = suite_script.new()
		suite.run()
		total_passed += suite.passed
		var mark := "OK  " if suite.failures.is_empty() else "FAIL"
		print("[%s] %-28s 通过 %d，失败 %d" % [
			mark, suite.suite_name(), suite.passed, suite.failures.size(),
		])
		for f in suite.failures:
			all_failures.append("  %s | %s" % [suite.suite_name(), f])

	print("")
	if all_failures.is_empty():
		print("全部通过，共 %d 项。" % total_passed)
		quit(0)
		return

	print("失败明细：")
	for f in all_failures:
		print(f)
	print("")
	print("通过 %d，失败 %d。" % [total_passed, all_failures.size()])
	quit(1)
