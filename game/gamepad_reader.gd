## 手柄采样。
##
## 关键点：走 [method Input.get_joy_axis] 拿**未经处理的**轴值，
## 而不是 InputMap 的 action strength——后者会先套一层 Godot 自己的死区，
## 那样本工具调出来的死区曲线就全是假的。
##
## 同时提供键盘模拟摇杆，便于没插手柄时验证整条管线（面板上会明确标注）。
class_name GamepadReader
extends RefCounted

## 键盘模拟摇杆从零推到满所需时间，秒。模拟出斜坡而非瞬间满偏，才谈得上像摇杆。
const VIRTUAL_RAMP_TIME := 0.22
## 扳机视为"扣下"的阈值。
const TRIGGER_THRESHOLD := 0.35

var device: int = 0
var allow_keyboard: bool = true

var _virtual_look := Vector2.ZERO
var _virtual_move := Vector2.ZERO


func connected() -> bool:
	return Input.get_connected_joypads().has(device)


func device_name() -> String:
	return Input.get_joy_name(device) if connected() else "未检测到手柄"


## 自动选中第一个已连接的手柄。
func pick_first_device() -> void:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		device = pads[0]


## 右摇杆原始值，+x 右 / +y 下。未接手柄时由方向键模拟。
func look_raw(delta: float) -> Vector2:
	if connected():
		return Vector2(
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y),
		)
	_virtual_look = _ramp(
		_virtual_look, delta, Vector2(_axis(KEY_RIGHT, KEY_LEFT), _axis(KEY_DOWN, KEY_UP))
	)
	return _virtual_look


## 左摇杆原始值，+x 右 / +y 下。未接手柄时由 WASD 模拟。
func move_raw(delta: float) -> Vector2:
	if connected():
		return Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
		)
	_virtual_move = _ramp(
		_virtual_move, delta, Vector2(_axis(KEY_D, KEY_A), _axis(KEY_S, KEY_W))
	)
	return _virtual_move


## 右扳机 0..1。未接手柄时为鼠标左键。
func trigger_right() -> float:
	if connected():
		return maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
	return 1.0 if (allow_keyboard and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0


## 左扳机 0..1。未接手柄时为鼠标右键。
func trigger_left() -> float:
	if connected():
		return maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
	return 1.0 if (allow_keyboard and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) else 0.0


func firing() -> bool:
	return trigger_right() >= TRIGGER_THRESHOLD


func aiming() -> bool:
	return trigger_left() >= TRIGGER_THRESHOLD


func _axis(positive: Key, negative: Key) -> float:
	if not allow_keyboard:
		return 0.0
	return (1.0 if Input.is_key_pressed(positive) else 0.0) \
		- (1.0 if Input.is_key_pressed(negative) else 0.0)


# 把按键的 0/1 变成带斜坡的摇杆值。松开时按同样速率回中。
func _ramp(state: Vector2, delta: float, target: Vector2) -> Vector2:
	if not allow_keyboard:
		return Vector2.ZERO
	var step := delta / VIRTUAL_RAMP_TIME
	return Vector2(
		move_toward(state.x, target.x, step),
		move_toward(state.y, target.y, step),
	)
