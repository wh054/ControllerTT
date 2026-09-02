## 界面配色与主题构建。
##
## 这里做的唯一一件不显然的事：用 [SystemFont] 引用操作系统里的中文字体。
## Godot 内置的默认字体不含 CJK 字形，直接用会让所有中文变成方块。
## 走 SystemFont 而不是打包一份字体文件，是为了不给仓库塞进十几兆的二进制。
class_name UITheme
extends RefCounted

const BG := Color(0.055, 0.065, 0.085, 0.94)
const PANEL := Color(0.10, 0.115, 0.145, 0.985)
const PANEL_SOFT := Color(0.135, 0.15, 0.185, 1.0)
const TEXT := Color(0.88, 0.90, 0.94)
const MUTED := Color(0.52, 0.56, 0.64)
const ACCENT := Color(0.34, 0.76, 1.00)
const ACCENT_WARM := Color(1.00, 0.62, 0.30)
const GOOD := Color(0.42, 0.94, 0.55)
const BAD := Color(1.00, 0.42, 0.38)
const GRID := Color(1, 1, 1, 0.09)
const OUTLINE := Color(1, 1, 1, 0.14)

## 按优先级排列的中文字体候选。SystemFont 会挑第一个系统里装了的。
static func font_candidates() -> PackedStringArray:
	return PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"Source Han Sans SC",
		"PingFang SC",
		"SimHei",
		"sans-serif",
	])


static func build_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = font_candidates()
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	return theme


static func panel_style(color: Color, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.border_color = OUTLINE
	s.set_border_width_all(1)
	return s


static func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String) -> Label:
	var l := label(text, 16, ACCENT)
	l.add_theme_constant_override("line_spacing", 6)
	return l


static func hint(text: String) -> Label:
	var l := label(text, 12, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func separator() -> Control:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 10)
	return s


## 一组横向排开的预设按钮。回调收到被点中的下标。
static func preset_bar(names: PackedStringArray, on_pick: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		b.pressed.connect(func() -> void: on_pick.call(index))
		box.add_child(b)
	return box
