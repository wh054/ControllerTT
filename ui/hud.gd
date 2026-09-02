## 训练时的抬头显示。
##
## 除了常规的准星与成绩，这里还实时显示**辅助瞄准三种机制各自的生效强度**。
## 这是本工具的训练意图所在：使用者应当能当场看到"刚才那一枪，是我自己压上去的，
## 还是跟枪把准星带过去的"。把辅助做成一个黑箱就失去了训练价值。
class_name HUD
extends Control

const CROSSHAIR_SIZE := 9.0
const CROSSHAIR_GAP := 4.0
const BAR_SLOTS := 10

var player: Player
var scenario: Scenario
## F1 切换：画出辅助气泡的实际角度范围与锁定目标。
var debug_visible: bool = false

var _stick: StickPad
var _scenario_label: Label
var _timer_label: Label
var _primary_label: Label
var _primary_value: Label
var _metrics: Label
var _assist_label: Label
var _device_label: Label


func _ready() -> void:
	# 必须用 set_anchors_and_offsets_preset：只设锚点的话偏移仍是旧值，
	# 控件会缩成最小尺寸留在左上角。这个坑在 CanvasLayer 下的 Control 上尤其容易踩。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func refresh() -> void:
	if player == null or scenario == null:
		return
	_refresh_text()
	_stick.deadzone = App.profile.look_deadzone
	_stick.push_sample(player.last_raw_look, player.processor.last_after_deadzone)
	queue_redraw()


func _refresh_text() -> void:
	var def := App.scenario
	var stats := scenario.stats

	_scenario_label.text = def.display_name
	_timer_label.text = "%0.1f s" % scenario.time_left()
	_primary_label.text = def.primary_metric_label()

	if def.weapon == ScenarioDef.Weapon.BEAM:
		_primary_value.text = "%d%%" % roundi(stats.time_on_target_ratio() * 100.0)
		# 光束要按住扳机才计时，不提示的话新手会打完一局拿到 0% 还不知道为什么。
		var fire_hint := "" if player.reader.firing() else "\n按住右扳机 / 鼠标左键 开火"
		_metrics.text = "在靶 %.1f s / %.1f s\n平均偏转 %.2f\n微操区占比 %d%%%s" % [
			stats.time_on_target, stats.elapsed,
			stats.avg_deflection(), roundi(stats.fine_control_ratio() * 100.0),
			fire_hint,
		]
	else:
		_primary_value.text = "%d%%" % roundi(stats.accuracy() * 100.0)
		_metrics.text = "击杀 %d    射击 %d\n每秒击杀 %.2f\n平均转移 %.0f ms\n微操区占比 %d%%" % [
			stats.kills, stats.shots, stats.kills_per_second(),
			stats.avg_reaction() * 1000.0, roundi(stats.fine_control_ratio() * 100.0),
		]

	_assist_label.text = _assist_text()
	_device_label.text = _device_text()


func _assist_text() -> String:
	var cfg := App.assist
	if not cfg.enabled or cfg.master_strength <= 0.0:
		return "辅助瞄准：关闭"
	var r := player.last_assist
	var lines := PackedStringArray(["辅助瞄准 · %s" % cfg.config_name])
	if cfg.slowdown_enabled:
		lines.append("减速 %s %.2f" % [_bar(r.slowdown_factor), r.turn_scale])
	if cfg.rotation_enabled:
		lines.append("跟枪 %s %.0f°/s" % [_bar(r.rotation_factor), r.bonus_dps.length()])
	if cfg.magnetism_enabled:
		lines.append("磁吸 %s" % _bar(r.magnetism_factor))
	if not r.is_active():
		lines.append("（无目标进入气泡）")
	return "\n".join(lines)


func _device_text() -> String:
	if player.reader.connected():
		return player.reader.device_name()
	return "未检测到手柄\n方向键模拟右摇杆 · WASD 模拟左摇杆"


static func _bar(v: float) -> String:
	var filled := clampi(roundi(v * BAR_SLOTS), 0, BAR_SLOTS)
	return "█".repeat(filled) + "░".repeat(BAR_SLOTS - filled)


func _draw() -> void:
	var center := size * 0.5
	if debug_visible and player != null:
		_draw_assist_bubbles(center)
	_draw_crosshair(center)


func _draw_crosshair(center: Vector2) -> void:
	# 准星变绿表示辅助**正在实际干预**，而不仅仅是锁定了目标。
	var color := UITheme.GOOD if (player != null and player.last_assist.has_effect()) else UITheme.TEXT
	# 先描一圈深色再画亮线，否则准星压在浅色墙面上会看不见。
	for pass_index in 2:
		var width := 3.5 if pass_index == 0 else 1.6
		var c := Color(0, 0, 0, 0.75) if pass_index == 0 else color
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + dir * CROSSHAIR_GAP, center + dir * CROSSHAIR_SIZE, c, width, true)
	draw_circle(center, 1.5, color)


# 气泡是以**准星**为中心定义的角度范围，因此画在屏幕正中而不是画在目标身上。
# 把角度换算成像素需要焦距：f = (视口高/2) / tan(垂直视场/2)。
func _draw_assist_bubbles(center: Vector2) -> void:
	var cfg := App.assist
	if not cfg.enabled or player.camera == null:
		return
	var focal := (size.y * 0.5) / tan(deg_to_rad(player.camera.fov) * 0.5)
	var entries := [
		[cfg.slowdown_enabled, cfg.slowdown_bubble, UITheme.ACCENT],
		[cfg.rotation_enabled, cfg.rotation_bubble, UITheme.GOOD],
		[cfg.magnetism_enabled, cfg.magnetism_bubble, UITheme.ACCENT_WARM],
	]
	for e in entries:
		if not e[0]:
			continue
		var r: float = focal * tan(deg_to_rad(e[1]))
		draw_arc(center, r, 0.0, TAU, 96, (e[2] as Color) * Color(1, 1, 1, 0.35), 1.0, true)

	var locked := player.last_assist
	if locked.is_active():
		var offset_px := Vector2(
			focal * tan(deg_to_rad(locked.target_offset.x)),
			-focal * tan(deg_to_rad(locked.target_offset.y)),
		)
		draw_arc(center + offset_px, 10.0, 0.0, TAU, 24, UITheme.BAD, 1.5, true)


func _build() -> void:
	var top_left := _corner(false, false, 320)
	_scenario_label = UITheme.label("", 22, UITheme.TEXT)
	_timer_label = UITheme.label("", 30, UITheme.ACCENT)
	top_left.add_child(_scenario_label)
	top_left.add_child(_timer_label)

	var top_right := _corner(true, false, 260)
	_primary_label = _right_label("", 14, UITheme.MUTED)
	_primary_value = _right_label("", 34, UITheme.GOOD)
	_metrics = _right_label("", 13, UITheme.MUTED)
	top_right.add_child(_primary_label)
	top_right.add_child(_primary_value)
	top_right.add_child(_metrics)

	var bottom_left := _corner(false, true, 250)
	_stick = StickPad.new()
	_stick.custom_minimum_size = Vector2(150, 150)
	_stick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_left.add_child(_stick)
	bottom_left.add_child(UITheme.label("右摇杆", 12, UITheme.MUTED))
	_device_label = UITheme.label("", 11, UITheme.MUTED)
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_left.add_child(_device_label)

	var bottom_right := _corner(true, true, 300)
	_assist_label = _right_label("", 13, UITheme.TEXT)
	bottom_right.add_child(_assist_label)
	bottom_right.add_child(_right_label(
		"Start / Esc 参数面板    Y / R 重开    F1 辅助气泡", 11, UITheme.MUTED,
	))


func _right_label(text: String, size: int, color: Color) -> Label:
	var l := UITheme.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


# 用显式的锚点加偏移把容器钉在某个角上。
# 上下方向让偏移相等、由 grow_vertical 决定往哪边长，这样内容行数变化时不会跑位。
func _corner(right: bool, bottom: bool, width: float) -> VBoxContainer:
	const MARGIN := Vector2(22.0, 18.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var ax := 1.0 if right else 0.0
	var ay := 1.0 if bottom else 0.0
	box.anchor_left = ax
	box.anchor_right = ax
	box.anchor_top = ay
	box.anchor_bottom = ay

	if right:
		box.offset_left = -width - MARGIN.x
		box.offset_right = -MARGIN.x
		box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		box.offset_left = MARGIN.x
		box.offset_right = MARGIN.x + width
		box.grow_horizontal = Control.GROW_DIRECTION_END

	var vy := -MARGIN.y if bottom else MARGIN.y
	box.offset_top = vy
	box.offset_bottom = vy
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	return box
