## 横轴分桶的柱状图，用于展示摇杆偏转量的时间分布。
class_name Histogram
extends Control

const PADDING := Vector2(10.0, 8.0)

## 各桶占比 0..1，总和通常为 1。
var values: PackedFloat32Array = PackedFloat32Array()
var caption: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(300, 130)


func set_values(v: PackedFloat32Array) -> void:
	values = v
	queue_redraw()


func _draw() -> void:
	var plot := Rect2(PADDING, size - PADDING * 2.0 - Vector2(0.0, 20.0))
	if plot.size.x <= 4.0 or plot.size.y <= 4.0 or values.is_empty():
		return

	# 底板
	draw_rect(plot, UITheme.BG, true)
	draw_rect(plot, UITheme.OUTLINE, false, 1.0)

	# 微操区底色高亮 (前 30% 行程，即前 3 个桶)
	var slot := plot.size.x / values.size()
	var micro_zone := Rect2(plot.position, Vector2(slot * 3.0, plot.size.y))
	draw_rect(micro_zone, UITheme.ACCENT_WARM * Color(1, 1, 1, 0.08), true)

	var peak := 0.0
	for v in values:
		peak = maxf(peak, v)
	if peak <= 0.0:
		_draw_caption(plot, "尚无数据")
		return

	for i in values.size():
		var h := plot.size.y * (values[i] / peak) * 0.90
		var bar := Rect2(
			Vector2(plot.position.x + slot * i + slot * 0.18, plot.end.y - h),
			Vector2(slot * 0.64, h),
		)
		# 前三个桶是微操区，用暖色标出来
		var color := UITheme.ACCENT_WARM if i < 3 else UITheme.ACCENT
		draw_rect(bar, color, true)

	_draw_caption(plot, caption)


func _draw_caption(plot: Rect2, text: String) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(
		font, Vector2(plot.position.x, plot.end.y + 15.0),
		"0.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED,
	)
	draw_string(
		font, Vector2(plot.end.x - 22.0, plot.end.y + 15.0),
		"1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED,
	)
	draw_string(
		font, Vector2(plot.position.x + 4.0, plot.position.y + 13.0),
		"微操区 (0~30%)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.ACCENT_WARM * Color(1, 1, 1, 0.8),
	)
	if text != "":
		draw_string(
			font, Vector2(plot.position.x + plot.size.x * 0.5 - 30.0, plot.end.y + 15.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_SUB,
		)

