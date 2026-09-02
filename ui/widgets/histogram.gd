## 横轴分桶的柱状图，用于展示摇杆偏转量的时间分布。
class_name Histogram
extends Control

const PADDING := Vector2(8.0, 6.0)

## 各桶占比 0..1，总和通常为 1。
var values: PackedFloat32Array = PackedFloat32Array()
var caption: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(280, 120)


func set_values(v: PackedFloat32Array) -> void:
	values = v
	queue_redraw()


func _draw() -> void:
	var plot := Rect2(PADDING, size - PADDING * 2.0 - Vector2(0.0, 16.0))
	if plot.size.x <= 4.0 or plot.size.y <= 4.0 or values.is_empty():
		return

	draw_rect(plot, UITheme.BG, true)
	draw_rect(plot, UITheme.OUTLINE, false, 1.0)

	var peak := 0.0
	for v in values:
		peak = maxf(peak, v)
	if peak <= 0.0:
		_draw_caption(plot, "尚无数据")
		return

	var slot := plot.size.x / values.size()
	for i in values.size():
		var h := plot.size.y * (values[i] / peak) * 0.92
		var bar := Rect2(
			Vector2(plot.position.x + slot * i + slot * 0.15, plot.end.y - h),
			Vector2(slot * 0.7, h),
		)
		# 前三个桶是微操区，用暖色标出来，提示这段行程对手感影响最大。
		draw_rect(bar, UITheme.ACCENT_WARM if i < 3 else UITheme.ACCENT, true)

	_draw_caption(plot, caption)


func _draw_caption(plot: Rect2, text: String) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(
		font, Vector2(plot.position.x, plot.end.y + 13.0),
		"0.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED,
	)
	draw_string(
		font, Vector2(plot.end.x - 22.0, plot.end.y + 13.0),
		"1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED,
	)
	if text != "":
		draw_string(
			font, Vector2(plot.position.x + 28.0, plot.end.y + 13.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED,
		)
