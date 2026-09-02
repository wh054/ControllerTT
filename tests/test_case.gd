## 极简测试基类。
##
## 不引入 GUT 之类的第三方测试框架，是因为本项目只需要对纯函数做数值断言，
## 几十行就够了，而多一个 addon 就多一份升级 Godot 时会坏掉的东西。
## 若将来需要测场景树或异步行为，再换成 GUT 也不迟。
##
## 子类里所有以 test_ 开头的方法都会被自动执行。
class_name TestCase
extends RefCounted

const EPS := 0.0001

var failures: PackedStringArray = []
var passed: int = 0

var _current: String = ""


## 子类覆写，返回中文套件名，用于报告输出。
func suite_name() -> String:
	return get_script().resource_path.get_file()


func run() -> void:
	for m in get_method_list():
		var n: String = m.name
		if not n.begins_with("test_"):
			continue
		_current = n
		var before := failures.size()
		call(n)
		if failures.size() == before:
			passed += 1


func fail(msg: String) -> void:
	failures.append("%s :: %s" % [_current, msg])


func check(condition: bool, msg: String) -> void:
	if not condition:
		fail(msg)


func assert_true(condition: bool, msg: String = "") -> void:
	check(condition, "期望为真，实际为假。%s" % msg)


func assert_false(condition: bool, msg: String = "") -> void:
	check(not condition, "期望为假，实际为真。%s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	check(actual == expected, "期望 %s，实际 %s。%s" % [expected, actual, msg])


func assert_near(actual: float, expected: float, eps: float = EPS, msg: String = "") -> void:
	check(
		absf(actual - expected) <= eps,
		"期望 %.6f ± %.6f，实际 %.6f。%s" % [expected, eps, actual, msg],
	)


func assert_vec_near(actual: Vector2, expected: Vector2, eps: float = EPS, msg: String = "") -> void:
	check(
		actual.distance_to(expected) <= eps,
		"期望 %v ± %.6f，实际 %v。%s" % [expected, eps, actual, msg],
	)


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	check(actual > threshold, "期望 > %.6f，实际 %.6f。%s" % [threshold, actual, msg])


func assert_lt(actual: float, threshold: float, msg: String = "") -> void:
	check(actual < threshold, "期望 < %.6f，实际 %.6f。%s" % [threshold, actual, msg])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	check(
		actual >= lo - EPS and actual <= hi + EPS,
		"期望落在 [%.6f, %.6f]，实际 %.6f。%s" % [lo, hi, actual, msg],
	)
