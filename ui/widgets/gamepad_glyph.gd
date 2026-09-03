## 手柄按键矢量图标控件。
##
## 绘制标准主机手柄图标：
## 1. 圆形动作按键 (A 绿, B 红, X 蓝, Y 黄)；
## 2. 十字方向键 D-Pad 真实外观 (带 4 向凸起与中心凹陷凹槽)；
## 3. 摇杆图标 (L / R 摇杆圆环与帽顶)；
## 4. 肩键 (LB / RB 胶囊形) 与 扳机 (LT / RT)；
## 5. 菜单/视图键 (Start / Back)。
class_name GamepadGlyph
extends Control

enum GlyphType {
	BTN_A,
	BTN_B,
	BTN_X,
	BTN_Y,
	DPAD,
	DPAD_UP,
	DPAD_DOWN,
	DPAD_LEFT,
	DPAD_RIGHT,
	STICK_L,
	STICK_R,
	BUMPER_LB,
	BUMPER_RB,
	TRIGGER_LT,
	TRIGGER_RT,
	BTN_START,
	BTN_BACK,
	KEYBOARD_KEY,
}

const COLOR_A := Color(0.06, 0.85, 0.45)   # Xbox A 鲜绿
const COLOR_B := Color(0.96, 0.25, 0.35)   # Xbox B 亮红
const COLOR_X := Color(0.00, 0.70, 1.00)   # Xbox X 霓虹蓝
const COLOR_Y := Color(1.00, 0.75, 0.00)   # Xbox Y 暖金黄
const COLOR_DARK := Color(0.09, 0.12, 0.17, 0.95)
const COLOR_OUTLINE := Color(0.35, 0.45, 0.60, 0.8)

var glyph_type: GlyphType = GlyphType.BTN_A:
	set(v):
		glyph_type = v
		_update_size()
		queue_redraw()

var custom_label: String = "":
	set(v):
		custom_label = v
		_update_size()
		queue_redraw()


func _init(type: GlyphType = GlyphType.BTN_A, label: String = "") -> void:
	glyph_type = type
	custom_label = label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()


static func create_from_key(key: String) -> Control:
	var glyph_script: GDScript = load("res://ui/widgets/gamepad_glyph.gd")
	var g: GamepadGlyph = glyph_script.new()
	var k := key.to_upper().strip_edges()
	match k:
		"A":
			g.glyph_type = GlyphType.BTN_A
		"B":
			g.glyph_type = GlyphType.BTN_B
		"X":
			g.glyph_type = GlyphType.BTN_X
		"Y":
			g.glyph_type = GlyphType.BTN_Y
		"D-PAD", "DPAD", "十字键", "方向键":
			g.glyph_type = GlyphType.DPAD
		"D-PAD / 左摇杆", "D-PAD/左摇杆", "DPAD/L":
			g.glyph_type = GlyphType.DPAD
		"L", "LS", "左摇杆", "L摇杆":
			g.glyph_type = GlyphType.STICK_L
		"R", "RS", "右摇杆", "R摇杆":
			g.glyph_type = GlyphType.STICK_R
		"LB":
			g.glyph_type = GlyphType.BUMPER_LB
		"RB":
			g.glyph_type = GlyphType.BUMPER_RB
		"LT":
			g.glyph_type = GlyphType.TRIGGER_LT
		"RT":
			g.glyph_type = GlyphType.TRIGGER_RT
		"START", "MENU", "三":
			g.glyph_type = GlyphType.BTN_START
		"BACK", "VIEW":
			g.glyph_type = GlyphType.BTN_BACK
		_:
			g.glyph_type = GlyphType.KEYBOARD_KEY
			g.custom_label = key
	return g


func _update_size() -> void:
	match glyph_type:
		GlyphType.BTN_A, GlyphType.BTN_B, GlyphType.BTN_X, GlyphType.BTN_Y:
			custom_minimum_size = Vector2(24, 24)
		GlyphType.DPAD, GlyphType.DPAD_UP, GlyphType.DPAD_DOWN, GlyphType.DPAD_LEFT, GlyphType.DPAD_RIGHT:
			custom_minimum_size = Vector2(26, 26)
		GlyphType.STICK_L, GlyphType.STICK_R:
			custom_minimum_size = Vector2(24, 24)
		GlyphType.BUMPER_LB, GlyphType.BUMPER_RB, GlyphType.TRIGGER_LT, GlyphType.TRIGGER_RT:
			custom_minimum_size = Vector2(30, 22)
		GlyphType.BTN_START, GlyphType.BTN_BACK:
			custom_minimum_size = Vector2(28, 22)
		GlyphType.KEYBOARD_KEY:
			var w := maxf(24.0, custom_label.length() * 8.0 + 12.0)
			custom_minimum_size = Vector2(w, 22)


func _draw() -> void:
	var center := size * 0.5
	match glyph_type:
		GlyphType.BTN_A:
			_draw_face_button(center, "A", COLOR_A)
		GlyphType.BTN_B:
			_draw_face_button(center, "B", COLOR_B)
		GlyphType.BTN_X:
			_draw_face_button(center, "X", COLOR_X)
		GlyphType.BTN_Y:
			_draw_face_button(center, "Y", COLOR_Y)
		GlyphType.DPAD:
			_draw_dpad(center)
		GlyphType.STICK_L:
			_draw_stick(center, "L")
		GlyphType.STICK_R:
			_draw_stick(center, "R")
		GlyphType.BUMPER_LB:
			_draw_capsule_button(center, "LB")
		GlyphType.BUMPER_RB:
			_draw_capsule_button(center, "RB")
		GlyphType.TRIGGER_LT:
			_draw_capsule_button(center, "LT")
		GlyphType.TRIGGER_RT:
			_draw_capsule_button(center, "RT")
		GlyphType.BTN_START:
			_draw_menu_button(center, "Start")
		GlyphType.BTN_BACK:
			_draw_menu_button(center, "Back")
		GlyphType.KEYBOARD_KEY:
			_draw_keyboard_key(center, custom_label)


# ---------------------------------------------------------------------------
# 具体图标绘制器
# ---------------------------------------------------------------------------

func _draw_face_button(c: Vector2, letter: String, color: Color) -> void:
	var r := minf(size.x, size.y) * 0.48
	# 外发光边框
	draw_circle(c, r, color)
	# 内部深色衬底
	draw_circle(c, r - 1.8, Color(0.08, 0.10, 0.15, 0.95))
	# 顶部高光弧
	draw_arc(c - Vector2(0, r * 0.2), r * 0.55, PI * 0.8, PI * 1.2, 16, Color(1, 1, 1, 0.25), 1.0, true)
	# 字母
	var font := get_theme_default_font()
	var font_size := 12
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := c + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5 - 1.0)
	draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_dpad(c: Vector2) -> void:
	var arm_len := 10.5
	var arm_thick := 7.0
	var half_thick := arm_thick * 0.5

	# 十字底色与外框
	var h_rect := Rect2(c.x - arm_len, c.y - half_thick, arm_len * 2.0, arm_thick)
	var v_rect := Rect2(c.x - half_thick, c.y - arm_len, arm_thick, arm_len * 2.0)

	# 外层发光轮廓
	var bg_col := Color(0.12, 0.16, 0.24, 0.95)
	var border_col := COLOR_OUTLINE
	draw_rect(h_rect, border_col, true)
	draw_rect(v_rect, border_col, true)

	# 内部填充
	var h_inner := Rect2(c.x - arm_len + 1.0, c.y - half_thick + 1.0, arm_len * 2.0 - 2.0, arm_thick - 2.0)
	var v_inner := Rect2(c.x - half_thick + 1.0, c.y - arm_len + 1.0, arm_thick - 2.0, arm_len * 2.0 - 2.0)
	draw_rect(h_inner, bg_col, true)
	draw_rect(v_inner, bg_col, true)

	# 4 个方向的小箭头
	var arrow_col := Color(0.85, 0.92, 1.0, 0.9)
	# 上
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-2.5, -arm_len + 5.5),
		c + Vector2(2.5, -arm_len + 5.5),
		c + Vector2(0, -arm_len + 2.5),
	]), arrow_col)
	# 下
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-2.5, arm_len - 5.5),
		c + Vector2(2.5, arm_len - 5.5),
		c + Vector2(0, arm_len - 2.5),
	]), arrow_col)
	# 左
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-arm_len + 5.5, -2.5),
		c + Vector2(-arm_len + 5.5, 2.5),
		c + Vector2(-arm_len + 2.5, 0),
	]), arrow_col)
	# 右
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(arm_len - 5.5, -2.5),
		c + Vector2(arm_len - 5.5, 2.5),
		c + Vector2(arm_len - 2.5, 0),
	]), arrow_col)

	# 中心微凹圆盘
	draw_circle(c, 2.8, Color(0.06, 0.08, 0.12))


func _draw_stick(c: Vector2, text: String) -> void:
	var r := minf(size.x, size.y) * 0.46
	# 外轮廓环
	draw_arc(c, r, 0, TAU, 32, COLOR_OUTLINE, 1.2, true)
	draw_circle(c, r - 1.2, Color(0.10, 0.14, 0.20, 0.95))

	# 4 向刻度槽
	var tick_col := Color(0.4, 0.5, 0.65, 0.6)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * (r - 4.0), c + dir * (r - 1.0), tick_col, 1.0)

	# 内部摇杆帽
	draw_circle(c, r * 0.6, Color(0.16, 0.22, 0.32))
	draw_arc(c, r * 0.6, 0, TAU, 24, Color(0.0, 0.8, 1.0, 0.6), 1.0, true)

	var font := get_theme_default_font()
	var font_size := 10
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := c + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5 - 1.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.85, 0.95, 1.0))


func _draw_capsule_button(c: Vector2, text: String) -> void:
	var w := size.x - 2.0
	var h := size.y - 4.0
	var rect := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	# 背景与外边框
	draw_rect(rect, COLOR_OUTLINE, true)
	var inner := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
	draw_rect(inner, Color(0.10, 0.14, 0.22, 0.95), true)

	var font := get_theme_default_font()
	var font_size := 11
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := c + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5 - 1.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.9, 0.95, 1.0))


func _draw_menu_button(c: Vector2, text: String) -> void:
	var w := size.x - 2.0
	var h := size.y - 4.0
	var rect := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	draw_rect(rect, Color(0.25, 0.35, 0.48, 0.8), true)
	var inner := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
	draw_rect(inner, Color(0.08, 0.11, 0.16, 0.95), true)

	var font := get_theme_default_font()
	var font_size := 10
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := c + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5 - 1.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.85, 0.92, 1.0))


func _draw_keyboard_key(c: Vector2, text: String) -> void:
	var w := size.x - 2.0
	var h := size.y - 4.0
	var rect := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	draw_rect(rect, Color(0.22, 0.28, 0.38, 0.8), true)
	var inner := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
	draw_rect(inner, Color(0.07, 0.09, 0.14, 0.95), true)

	var font := get_theme_default_font()
	var font_size := 10
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := c + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5 - 1.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.8, 0.88, 0.95))
