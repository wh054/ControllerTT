## 界面配色与主题构建。
##
## 为手柄优先的主机级 FPS 体验提供高对比度深色高科技视觉规范、
## 统一的控件焦点动效样式以及手柄按键指示器组件。
class_name UITheme
extends RefCounted

const GamepadGlyph = preload("res://ui/widgets/gamepad_glyph.gd")

const BG := Color(0.045, 0.055, 0.075, 0.96)
const BG_TRANSPARENT := Color(0.035, 0.045, 0.065, 0.75)
const PANEL := Color(0.085, 0.105, 0.145, 0.98)
const PANEL_SOFT := Color(0.125, 0.155, 0.205, 0.98)
const PANEL_HIGHLIGHT := Color(0.165, 0.21, 0.285, 1.0)
const CARD_BG := Color(0.075, 0.095, 0.13, 0.95)

const TEXT := Color(0.92, 0.95, 0.98)
const TEXT_SUB := Color(0.72, 0.78, 0.86)
const MUTED := Color(0.48, 0.54, 0.64)

const ACCENT := Color(0.00, 0.85, 1.00)       # 霓虹电光青
const ACCENT_GLOW := Color(0.00, 0.85, 1.00, 0.25)
const ACCENT_WARM := Color(1.00, 0.65, 0.18)  # 暖金琥珀
const GOOD := Color(0.18, 0.88, 0.55)         # 荧光薄荷绿
const BAD := Color(0.98, 0.32, 0.38)          # 珊瑚红

const GRID := Color(1.0, 1.0, 1.0, 0.06)
const OUTLINE := Color(0.20, 0.26, 0.36, 0.75)
const OUTLINE_FOCUS := Color(0.00, 0.85, 1.00, 0.95)
const OUTLINE_ACTIVE := Color(0.00, 0.85, 1.00, 0.55)

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

	# 1. 按钮样式（适配手柄高亮焦点）
	theme.set_stylebox("normal", "Button", _button_normal())
	theme.set_stylebox("hover", "Button", _button_hover())
	theme.set_stylebox("pressed", "Button", _button_pressed())
	theme.set_stylebox("focus", "Button", _button_focus())
	theme.set_stylebox("disabled", "Button", _button_disabled())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", MUTED * Color(1, 1, 1, 0.6))

	# 2. 滑块样式 (HSlider)
	theme.set_stylebox("slider", "HSlider", _slider_track())
	theme.set_stylebox("grabber_area", "HSlider", _slider_area())
	theme.set_stylebox("grabber_area_highlight", "HSlider", _slider_area_highlight())
	theme.set_stylebox("focus", "HSlider", _slider_focus())

	# 3. 选项弹窗 (PopupMenu)
	theme.set_stylebox("panel", "PopupMenu", panel_style(PANEL, 6, OUTLINE_ACTIVE, 1, 6))
	theme.set_stylebox("hover", "PopupMenu", _popup_item_hover())
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)

	# 4. 标签页 (TabBar & TabContainer)
	theme.set_stylebox("tab_selected", "TabBar", _tab_selected())
	theme.set_stylebox("tab_unselected", "TabBar", _tab_unselected())
	theme.set_stylebox("tab_hovered", "TabBar", _tab_hovered())
	theme.set_stylebox("tab_focus", "TabBar", _tab_focus())
	theme.set_stylebox("panel", "TabContainer", _tab_panel())
	theme.set_color("font_selected_color", "TabBar", ACCENT)
	theme.set_color("font_unselected_color", "TabBar", TEXT_SUB)
	theme.set_color("font_hovered_color", "TabBar", TEXT)

	# 5. 滚动条 (VScrollBar)
	theme.set_stylebox("scroll", "VScrollBar", _scroll_track())
	theme.set_stylebox("grabber", "VScrollBar", _scroll_grabber())
	theme.set_stylebox("grabber_highlight", "VScrollBar", _scroll_grabber_highlight())
	theme.set_stylebox("grabber_pressed", "VScrollBar", _scroll_grabber_highlight())

	return theme


static func panel_style(
	color: Color, radius: int = 8, border_color: Color = OUTLINE,
	border_width: int = 1, margin: int = 12
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.border_color = border_color
	s.set_border_width_all(border_width)
	return s


static func card_style(radius: int = 8, focused: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_HIGHLIGHT if focused else PANEL_SOFT
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.border_color = OUTLINE_FOCUS if focused else OUTLINE
	s.set_border_width_all(2 if focused else 1)
	if focused:
		s.shadow_color = ACCENT_GLOW
		s.shadow_size = 8
	return s


static func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size: int = 16) -> Label:
	var l := label(text, size, ACCENT)
	l.add_theme_constant_override("line_spacing", 6)
	return l


static func subheading(text: String) -> Label:
	var l := label(text, 13, TEXT_SUB)
	l.add_theme_constant_override("line_spacing", 4)
	return l


static func hint(text: String) -> Label:
	var l := label(text, 12, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func separator() -> Control:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 14)
	var style := StyleBoxLine.new()
	style.color = OUTLINE * Color(1, 1, 1, 0.4)
	style.thickness = 1
	s.add_theme_stylebox_override("separator", style)
	return s


## 一组横向排开的预设按钮。回调收到被点中的下标。
static func preset_bar(names: PackedStringArray, on_pick: Callable, active_index: int = -1) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		var index := i
		if i == active_index:
			b.add_theme_color_override("font_color", ACCENT)
		b.pressed.connect(func() -> void: on_pick.call(index))
		box.add_child(b)
	return box


## 创建手柄按键指示器胶囊，支持圆形动作键 (A/B/X/Y)、矢量 D-Pad 十字键、摇杆与肩键
static func controller_badge(button_key: String, label_text: String = "") -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var k := button_key.strip_edges()
	if k == "D-Pad / 左摇杆" or k == "D-Pad/左摇杆" or k == "DPAD / L":
		box.add_child(GamepadGlyph.create_from_key("D-Pad"))
		var slash := label("/", 11, MUTED)
		box.add_child(slash)
		box.add_child(GamepadGlyph.create_from_key("L"))
	elif k == "LB / RB" or k == "LB/RB":
		box.add_child(GamepadGlyph.create_from_key("LB"))
		box.add_child(GamepadGlyph.create_from_key("RB"))
	elif k == "A / Y" or k == "A/Y":
		box.add_child(GamepadGlyph.create_from_key("A"))
		var slash := label("/", 11, MUTED)
		box.add_child(slash)
		box.add_child(GamepadGlyph.create_from_key("Y"))
	elif k == "Start / X" or k == "Start/X":
		box.add_child(GamepadGlyph.create_from_key("Start"))
		var slash := label("/", 11, MUTED)
		box.add_child(slash)
		box.add_child(GamepadGlyph.create_from_key("X"))
	else:
		box.add_child(GamepadGlyph.create_from_key(button_key))

	if not label_text.is_empty():
		var desc_lbl := label(label_text, 12, TEXT_SUB)
		box.add_child(desc_lbl)

	return box


## 创建底部操作提示栏
static func button_hints(hints_data: Array) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in hints_data:
		if item is Array and item.size() >= 2:
			bar.add_child(controller_badge(str(item[0]), str(item[1])))
	return bar


## 标签徽章 (如 "持续光束", "追踪考核")
static func tag_badge(text: String, color: Color = ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color * Color(1, 1, 1, 0.15)
	s.border_color = color * Color(1, 1, 1, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 11, color))
	return p


# ---------------------------------------------------------------------------
# 内部样式构建器
# ---------------------------------------------------------------------------

static func _button_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_SOFT
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.border_color = OUTLINE
	s.set_border_width_all(1)
	return s


static func _button_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_HIGHLIGHT
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.border_color = OUTLINE_ACTIVE
	s.set_border_width_all(1)
	return s


static func _button_pressed() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.00, 0.50, 0.65, 0.35)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.border_color = ACCENT
	s.set_border_width_all(1)
	return s


static func _button_focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_HIGHLIGHT
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.border_color = OUTLINE_FOCUS
	s.set_border_width_all(2)
	s.shadow_color = ACCENT_GLOW
	s.shadow_size = 6
	return s


static func _button_disabled() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.09, 0.6)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.border_color = OUTLINE * Color(1, 1, 1, 0.3)
	s.set_border_width_all(1)
	return s


static func _slider_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(0)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.border_color = OUTLINE
	s.set_border_width_all(1)
	return s


static func _slider_area() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT * Color(1, 1, 1, 0.45)
	s.set_corner_radius_all(4)
	return s


static func _slider_area_highlight() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT
	s.set_corner_radius_all(4)
	return s


static func _slider_focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.set_corner_radius_all(6)
	s.border_color = OUTLINE_FOCUS
	s.set_border_width_all(1)
	s.set_content_margin_all(4)
	return s


static func _popup_item_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_HIGHLIGHT
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	s.border_color = OUTLINE_FOCUS
	s.set_border_width_all(1)
	return s


static func _tab_selected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.set_corner_radius_all(6)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.set_content_margin_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.border_color = ACCENT
	s.border_width_top = 2
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_bottom = 0
	return s


static func _tab_unselected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_SOFT * Color(1, 1, 1, 0.6)
	s.set_corner_radius_all(6)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.set_content_margin_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.border_color = OUTLINE * Color(1, 1, 1, 0.4)
	s.set_border_width_all(1)
	return s


static func _tab_hovered() -> StyleBoxFlat:
	var s := _tab_unselected()
	s.bg_color = PANEL_HIGHLIGHT
	s.border_color = OUTLINE_ACTIVE
	return s


static func _tab_focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = OUTLINE_FOCUS
	s.set_border_width_all(1)
	return s


static func _tab_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.set_corner_radius_all(8)
	s.corner_radius_top_left = 0
	s.set_content_margin_all(14)
	s.border_color = OUTLINE
	s.set_border_width_all(1)
	return s


static func _scroll_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.05, 0.07, 0.4)
	s.set_corner_radius_all(3)
	s.content_margin_left = 3
	s.content_margin_right = 3
	return s


static func _scroll_grabber() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = OUTLINE
	s.set_corner_radius_all(3)
	return s


static func _scroll_grabber_highlight() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT * Color(1, 1, 1, 0.8)
	s.set_corner_radius_all(3)
	return s

