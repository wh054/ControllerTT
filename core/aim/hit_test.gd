## 命中判定：射线与球的解析求交。
##
## 刻意不走 Godot 物理引擎，理由有两条：
##   1. 靶子全是球，解析解精确且无采样误差，物理引擎的凸包近似反而会引入偏差；
##   2. 物理查询只能在物理帧里安全调用，而瞄准训练器必须把整条视角链路放在渲染帧上
##      以压低输入延迟。绕开物理引擎就绕开了这个约束。
## 附带好处是这段判定也能脱离引擎单测。
class_name HitTest
extends RefCounted


## 射线与球求交。[param dir] 必须已归一化。
## 返回沿射线的距离；未命中返回 -1。射线起点在球内时返回 0。
static func ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	if c <= 0.0:
		return 0.0  # 起点已在球内
	if b > 0.0:
		return -1.0  # 球在射线背后
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	return -b - sqrt(disc)


## 目标中心相对准星的角度误差，单位度。
## x 为偏航（目标在右为正），y 为俯仰（目标在上为正）。
## [param basis] 为摄像机的世界基（Godot 约定摄像机朝向 -Z）。
static func angular_offset(delta: Vector3, basis: Basis) -> Vector2:
	var l := basis.inverse() * delta
	var horizontal := sqrt(l.x * l.x + l.z * l.z)
	return Vector2(
		rad_to_deg(atan2(l.x, -l.z)),
		rad_to_deg(atan2(l.y, horizontal)),
	)


## 半径为 radius 的球在 distance 处张开的视角半径，单位度。
static func angular_radius(radius: float, distance: float) -> float:
	if distance <= radius:
		return 90.0
	return rad_to_deg(asin(radius / distance))
