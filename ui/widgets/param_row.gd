## 参数面板里的一行控件。滑块 / 开关 / 下拉三种形态共用一个类，
## 这样设置面板的构建代码可以保持声明式的一条条排下去，不必为每种控件写胶水。
class_name ParamRow
extends HBoxContainer

signal changed(value: Variant)

const LABEL_WIDTH := 160
const VALUE_WIDTH := 82

var _slider: HSlider
var _value_label: Label
var _check: CheckButton
var _option: OptionButton
var _suffix: String = ""
var _decimals: int = 2


static func slider(
	text: String, lo: float, hi: float, step: float, value: float,
	suffix: String = "", decimals: int = 2, tip: String = "",
) -> ParamRow:
	var row := ParamRow.new()
	row._suffix = suffix
	row._decimals = decimals
	row._add_label(text, tip)

	row._slider = HSlider.new()
	row._slider.min_value = lo
	row._slider.max_value = hi
	row._slider.step = step
	row._slider.value = value
	row._slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row._slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row._slider.custom_minimum_size.y = 28
	row.add_child(row._slider)

	row._value_label = UITheme.label("", 13, UITheme.ACCENT)
	row._value_label.custom_minimum_size.x = VALUE_WIDTH
	row._value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(row._value_label)

	row._slider.value_changed.connect(row._on_slider)
	row._refresh_value_text(value)
	return row


static func toggle(text: String, value: bool, tip: String = "") -> ParamRow:
	var row := ParamRow.new()
	row._add_label(text, tip)
	row._check = CheckButton.new()
	row._check.button_pressed = value
	row._check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row._check.text = "开启" if value else "关闭"
	row._check.toggled.connect(func(v: bool) -> void:
		row._check.text = "开启" if v else "关闭"
		row.changed.emit(v)
	)
	row.add_child(row._check)
	return row


static func options(text: String, items: PackedStringArray, selected: int, tip: String = "") -> ParamRow:
	var row := ParamRow.new()
	row._add_label(text, tip)
	row._option = OptionButton.new()
	for item in items:
		row._option.add_item(item)
	row._option.selected = selected
	row._option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row._option.custom_minimum_size.y = 32
	row.add_child(row._option)
	row._option.item_selected.connect(func(i: int) -> void: row.changed.emit(i))
	return row


## 外部（如套用预设后）同步显示值，不触发 [signal changed]。
func set_value_silent(value: Variant) -> void:
	if _slider != null:
		_slider.set_block_signals(true)
		_slider.value = value
		_slider.set_block_signals(false)
		_refresh_value_text(value)
	elif _check != null:
		_check.set_pressed_no_signal(value)
		_check.text = "开启" if value else "关闭"
	elif _option != null:
		_option.set_block_signals(true)
		_option.selected = value
		_option.set_block_signals(false)


func set_row_enabled(on: bool) -> void:
	modulate.a = 1.0 if on else 0.45
	for c in get_children():
		if c is Control and c != get_child(0):
			var control := c as Control
			control.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
			control.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _add_label(text: String, tip: String) -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size.y = 36
	var l := UITheme.label(text, 13, UITheme.TEXT)
	l.custom_minimum_size.x = LABEL_WIDTH
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	add_child(l)


func _on_slider(v: float) -> void:
	_refresh_value_text(v)
	changed.emit(v)


func _refresh_value_text(v: float) -> void:
	if _value_label != null:
		_value_label.text = String.num(v, _decimals) + _suffix

