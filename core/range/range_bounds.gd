## 靶场空间边界与角色位移约束。
##
## 纯数据与几何计算，不依赖 Node3D，可直接进行无副作用的单元测试。
class_name RangeBounds
extends RefCounted

enum Mode {
	RANGE_DISTANCE, ## 靶场保距 (默认：前后保持射距，左右自由横移不设限制)
	STATION_FIXED,  ## 固定站位 (完全禁止位移，纯站桩射击)
	FREE,           ## 自由漫游 (全场无限制走位)
}

# 向后兼容常量别名
const STATION_LANE := Mode.RANGE_DISTANCE
const STATION_WIDE := Mode.RANGE_DISTANCE

const LABELS := [
	"靶场模式 (前后锁定射距 · 左右自由移动)",
	"固定站位 (完全禁止位移 · 纯站桩射击)",
	"自由漫游 (全场无限制自由走位)",
]

## 射击席前后纵深安全区间 (米)：
## 前沿紧贴置物台防撞边 Z = -0.15m，绝对禁止越界冲入靶区；后沿 Z = +0.25m。
const LANE_Z_MIN := -0.15
const LANE_Z_MAX := 0.25


static func get_bounds(mode: int, arena_half: float = 13.0) -> Dictionary:
	match mode:
		Mode.STATION_FIXED:
			return {"x_min": 0.0, "x_max": 0.0, "z_min": 0.0, "z_max": 0.0}
		Mode.FREE:
			return {"x_min": -arena_half, "x_max": arena_half, "z_min": -arena_half, "z_max": arena_half}
		Mode.RANGE_DISTANCE, _:
			# 靶场模式：左右行动范围不设限制 (由全场 arena_half 限制)，前后锁定在射击前沿保持射距
			return {"x_min": -arena_half, "x_max": arena_half, "z_min": LANE_Z_MIN, "z_max": LANE_Z_MAX}


static func clamp_position(pos: Vector3, mode: int, eye_height: float, arena_half: float = 13.0) -> Vector3:
	var b := get_bounds(mode, arena_half)
	return Vector3(
		clampf(pos.x, b.x_min, b.x_max),
		eye_height,
		clampf(pos.z, b.z_min, b.z_max),
	)


static func is_in_bounds(pos: Vector3, mode: int, arena_half: float = 13.0) -> bool:
	var b := get_bounds(mode, arena_half)
	return pos.x >= b.x_min - 0.0001 and pos.x <= b.x_max + 0.0001 \
		and pos.z >= b.z_min - 0.0001 and pos.z <= b.z_max + 0.0001
