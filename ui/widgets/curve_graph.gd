## 响应曲线的可视化与编辑器。
##
## 这个控件是整个工具最核心的一块界面：它把"曲线"这个抽象参数变成看得见的形状，
## 并且实时把当前摇杆的位置画成一个点落在曲线上——
## 使用者能直接看到自己此刻用的是曲线的哪一段，这比任何数字都直观。
class_name CurveGraph
extends Control

signal curve_edited

const SAMPLES := 100
const HANDLE_RADIUS := 7.0
const PADDING := 30.0

var curve: ResponseCurve
## 当前摇杆偏转量 0..1，用于画实时游标。
var live_x: float = 0.0
## 贝塞尔控制点是否可拖拽。
var editable: bool = true

var _dragging: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(320, 240)


func set_live(x: float) -> void:
	if is_equal_approx(x, live_x):
		return
	live_x = clampf(x, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if curve == null:
		return
	var plot := Rect2(
		Vector2(PADDING, PADDING * 0.4),
		size - Vector2(PADDING * 1.4, PADDING * 1.6),
	)
	if plot.size.x <= 4 or plot.size.y <= 4:
		return

	# 背景底板与网格
	draw_rect(plot, UITheme.BG, true)
	_draw_grid(plot)
	_draw_reference(plot)
	_draw_curve(plot)
	if curve.type == ResponseCurve.Type.BEZIER and editable:
		_draw_handles(plot)
	_draw_live(plot)
	_draw_axis_labels(plot)


func _draw_grid(plot: Rect2) -> void:
	for i in 5:
		var f := i / 4.0
		var x := plot.position.x + plot.size.x * f
		var y := plot.position.y + plot.size.y * f
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), UITheme.GRID, 1.0)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), UITheme.GRID, 1.0)
	draw_rect(plot, UITheme.OUTLINE, false, 1.0)


# 线性参考线。有了它才能一眼看出当前曲线是压低了还是抬高了摇杆前段。
func _draw_reference(plot: Rect2) -> void:
	var a := _to_px(plot, 0.0, 0.0)
	var b := _to_px(plot, 1.0, 1.0)
	var steps := 32
	for i in steps:
		if i % 2 == 1:
			continue
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		draw_line(a.lerp(b, t0), a.lerp(b, t1), UITheme.MUTED * Color(1, 1, 1, 0.5), 1.0)


func _draw_curve(plot: Rect2) -> void:
	var pts := PackedVector2Array()
	for i in SAMPLES + 1:
		var x := float(i) / SAMPLES
		pts.append(_to_px(plot, x, curve.evaluate(x)))
	
	# 发光底层
	draw_polyline(pts, UITheme.ACCENT * Color(1, 1, 1, 0.3), 4.0, true)
	# 主曲线
	draw_polyline(pts, UITheme.ACCENT, 2.0, true)


func _draw_handles(plot: Rect2) -> void:
	var origin := _to_px(plot, 0.0, 0.0)
	var corner := _to_px(plot, 1.0, 1.0)
	var p1 := _to_px(plot, curve.bezier_p1.x, curve.bezier_p1.y)
	var p2 := _to_px(plot, curve.bezier_p2.x, curve.bezier_p2.y)
	draw_line(origin, p1, UITheme.ACCENT_WARM * Color(1, 1, 1, 0.5), 1.0)
	draw_line(corner, p2, UITheme.ACCENT_WARM * Color(1, 1, 1, 0.5), 1.0)
	draw_circle(p1, HANDLE_RADIUS, UITheme.ACCENT_WARM)
	draw_circle(p2, HANDLE_RADIUS, UITheme.ACCENT_WARM)


func _draw_live(plot: Rect2) -> void:
	if live_x <= 0.001:
		return
	var y := curve.evaluate(live_x)
	var p := _to_px(plot, live_x, y)
	draw_line(Vector2(p.x, plot.end.y), p, UITheme.GOOD * Color(1, 1, 1, 0.4), 1.0)
	draw_line(Vector2(plot.position.x, p.y), p, UITheme.GOOD * Color(1, 1, 1, 0.4), 1.0)
	draw_circle(p, 7.0, UITheme.GOOD * Color(1, 1, 1, 0.35))
	draw_circle(p, 4.5, UITheme.GOOD)


func _draw_axis_labels(plot: Rect2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(
		font, Vector2(plot.position.x, plot.end.y + 16.0),
		"摇杆偏转 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.MUTED,
	)
	draw_string(
		font, Vector2(plot.end.x - 90.0, plot.position.y + 14.0),
		"↑ 转速输出", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.MUTED,
	)
	if live_x > 0.001:
		var y := curve.evaluate(live_x)
		var val_str := "输入: %.2f  输出: %.2f" % [live_x, y]
		draw_string(
			font, Vector2(plot.position.x + 6.0, plot.position.y + 14.0),
			val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.GOOD,
		)
	elif curve.type == ResponseCurve.Type.BEZIER and editable:
		draw_string(
			font, Vector2(plot.position.x + 6.0, plot.end.y - 8.0),
			"拖动橙色控制点调整曲线", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.MUTED,
		)


func _to_px(plot: Rect2, x: float, y: float) -> Vector2:
	return Vector2(
		plot.position.x + plot.size.x * clampf(x, 0.0, 1.0),
		plot.end.y - plot.size.y * clampf(y, 0.0, 1.0),
	)


func _to_unit(plot: Rect2, px: Vector2) -> Vector2:
	return Vector2(
		clampf((px.x - plot.position.x) / plot.size.x, 0.0, 1.0),
		clampf((plot.end.y - px.y) / plot.size.y, 0.0, 1.0),
	)


func _gui_input(event: InputEvent) -> void:
	if curve == null or not editable or curve.type != ResponseCurve.Type.BEZIER:
		return
	var plot := Rect2(
		Vector2(PADDING, PADDING * 0.4),
		size - Vector2(PADDING * 1.4, PADDING * 1.6),
	)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mb.pressed:
			_dragging = -1
			return
		var p1 := _to_px(plot, curve.bezier_p1.x, curve.bezier_p1.y)
		var p2 := _to_px(plot, curve.bezier_p2.x, curve.bezier_p2.y)
		if mb.position.distance_to(p1) <= mb.position.distance_to(p2):
			_dragging = 0 if mb.position.distance_to(p1) < HANDLE_RADIUS * 2.2 else -1
		else:
			_dragging = 1 if mb.position.distance_to(p2) < HANDLE_RADIUS * 2.2 else -1
		accept_event()
	elif event is InputEventMouseMotion and _dragging >= 0:
		var unit := _to_unit(plot, (event as InputEventMouseMotion).position)
		if _dragging == 0:
			curve.bezier_p1 = unit
		else:
			curve.bezier_p2 = unit
		curve_edited.emit()
		queue_redraw()
		accept_event()

