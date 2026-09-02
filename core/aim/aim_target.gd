## 辅助瞄准眼中的"一个目标"——纯几何描述，不含任何 3D 节点引用。
##
## 这层转换（3D 世界 → 视角空间角度）刻意放在 game 层完成，
## 使得 core/aim 只需处理二维角度，可以脱离引擎单测。
class_name AimTarget
extends RefCounted

## 目标标识，用于跨帧追踪同一个目标（判断辅助是否需要重新锁定）。
var id: int = -1

## 准星指向 → 目标中心的角度误差，单位度。x 为偏航（右为正），y 为俯仰（上为正）。
var angular_offset := Vector2.ZERO

## 目标的视角半径，单位度。距离越远越小，用于按目标大小缩放辅助气泡。
var angular_radius := 0.0

## 目标在视野中掠过的角速度，单位度/秒。
## 关键：这个值**必须排除玩家自身转动视角的贡献**，只保留目标运动与玩家位移带来的部分。
## 否则旋转跟枪会自我正反馈，玩家一转视角辅助就跟着加速，直接失控。
var angular_velocity := Vector2.ZERO

## 世界距离，单位米。超出配置的最大距离则不参与辅助。
var distance := 0.0

## 是否可见（未被遮挡且存活）。被挡住的目标不该产生辅助。
var visible := true


func angular_distance() -> float:
	return angular_offset.length()


static func make(p_id: int, offset: Vector2, radius: float, velocity: Vector2, dist: float) -> AimTarget:
	var t := AimTarget.new()
	t.id = p_id
	t.angular_offset = offset
	t.angular_radius = radius
	t.angular_velocity = velocity
	t.distance = dist
	return t
