## 摇杆可视化：同时画出原始值、死区处理后的值，以及最近一段时间的轨迹。
##
## 轨迹是这里最有用的东西。静态的一个点只能说明"现在推到哪"，
## 而一条轨迹能暴露出回中漂移、推杆抖动、以及对角方向被死区形状扭曲——
## 这些问题光看数字或者在游戏里凭手感都很难发现。
class_name StickPad
extends Control

const TRAIL_LENGTH := 120
const PADDING := 12.0

var deadzone: DeadzoneConfig
var raw := Vector2.ZERO
var processed := Vector2.ZERO
var show_trail: bool = true

var _trail: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)


## 每帧喂入一组采样。processed 为死区处理后的值。
func push_sample(p_raw: Vector2, p_processed: Vector2) -> void:
	raw = p_raw
	processed = p_processed
	if show_trail:
		_trail.append(p_processed)
		if _trail.size() > TRAIL_LENGTH:
			_trail.remove_at(0)
	queue_redraw()


func clear_trail() -> void:
	_trail.clear()
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - PADDING
	if radius <= 4.0:
		return

	# 雷达底盘
	draw_circle(center, radius, UITheme.BG)
	draw_arc(center, radius, 0.0, TAU, 72, UITheme.OUTLINE, 1.0, true)
	
	# 刻度十字线
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), UITheme.GRID, 1.0)
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), UITheme.GRID, 1.0)
	draw_arc(center, radius * 0.5, 0.0, TAU, 48, UITheme.GRID, 1.0, true)

	_draw_deadzone(center, radius)
	_draw_trail(center, radius)

	# 原始点与处理后点
	var raw_pos := center + raw * radius
	var proc_pos := center + processed * radius
	if raw.length_squared() > 0.001:
		draw_circle(raw_pos, 3.5, UITheme.MUTED * Color(1, 1, 1, 0.8))
	if processed.length_squared() > 0.001:
		draw_circle(proc_pos, 7.0, UITheme.ACCENT * Color(1, 1, 1, 0.35))
		draw_circle(proc_pos, 4.5, UITheme.ACCENT)
		draw_line(center, proc_pos, UITheme.ACCENT * Color(1, 1, 1, 0.4), 1.0)

	var font := get_theme_default_font()
	if font != null:
		var pct := roundi(processed.length() * 100.0)
		draw_string(
			font, Vector2(6.0, size.y - 4.0),
			"偏转: %d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			UITheme.ACCENT if pct > 0 else UITheme.MUTED,
		)
		draw_string(
			font, Vector2(size.x - 72.0, size.y - 4.0),
			"灰=原 蓝=效", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, UITheme.MUTED,
		)


# 死区的形状要如实画出来：轴向死区是方的，径向是圆的。
func _draw_deadzone(center: Vector2, radius: float) -> void:
	if deadzone == null:
		return
	var color := UITheme.ACCENT_WARM * Color(1, 1, 1, 0.45)
	if deadzone.shape == DeadzoneConfig.Shape.AXIAL:
		for r: float in [deadzone.inner, deadzone.outer]:
			var half := radius * r
			draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2)), color, false, 1.0)
		return
	draw_arc(center, radius * deadzone.inner, 0.0, TAU, 48, color, 1.0, true)
	draw_arc(center, radius * deadzone.outer, 0.0, TAU, 64, color, 1.0, true)


func _draw_trail(center: Vector2, radius: float) -> void:
	if _trail.size() < 2:
		return
	# 越旧越淡
	for i in range(1, _trail.size()):
		var t := float(i) / _trail.size()
		draw_line(
			center + _trail[i - 1] * radius,
			center + _trail[i] * radius,
			UITheme.GOOD * Color(1, 1, 1, t * 0.65),
			1.5,
		)

