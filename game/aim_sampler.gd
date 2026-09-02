## 3D 世界与 [AimAssist] 之间唯一的桥：把场上的靶机翻译成纯角度描述的 [AimTarget]。
##
## 这个类存在的全部理由，是让 core/aim 不必知道 Node3D 的存在。
## 它也是整个项目里唯一需要小心处理"角速度该排除什么"的地方。
class_name AimSampler
extends RefCounted

## 超过这个角度的靶机直接跳过。气泡最大不过 25 度，多采样只是浪费。
const MAX_SAMPLE_ANGLE := 45.0
## 角速度的安全上限，度/秒。靶机重生或瞬移时会产生虚假的巨大角速度，
## 若不夹住，旋转跟枪会把视角猛地甩飞。
const MAX_ANGULAR_SPEED := 720.0

var _prev_target_pos: Dictionary = {}
var _prev_cam_pos := Vector3.ZERO
var _has_prev := false


## 采样一帧。[param targets] 为场上的 [Target] 列表。
func sample(cam_pos: Vector3, cam_basis: Basis, targets: Array, delta: float) -> Array[AimTarget]:
	var out: Array[AimTarget] = []
	var current: Dictionary = {}

	for node in targets:
		var t := node as Target
		if t == null or not t.alive:
			continue
		var pos := t.global_position
		var id := t.get_instance_id()
		current[id] = pos

		var to_target := pos - cam_pos
		var dist := to_target.length()
		if dist <= 0.001:
			continue
		var offset := HitTest.angular_offset(to_target, cam_basis)
		if absf(offset.x) > MAX_SAMPLE_ANGLE or absf(offset.y) > MAX_SAMPLE_ANGLE:
			continue

		var at := AimTarget.new()
		at.id = id
		at.angular_offset = offset
		at.angular_radius = HitTest.angular_radius(t.radius, dist)
		at.angular_velocity = _angular_velocity(id, pos, cam_pos, cam_basis, offset, delta)
		at.distance = dist
		at.visible = true
		out.append(at)

	_prev_target_pos = current
	_prev_cam_pos = cam_pos
	_has_prev = true
	return out


## 换场景或重开时调用，避免用上一局的位置算出巨大的虚假角速度。
func reset() -> void:
	_prev_target_pos.clear()
	_has_prev = false


# 靶机在视野中的角速度，必须排除玩家自身转动视角的贡献。
#
# 做法是把"上一帧"和"这一帧"都投影到**同一个**摄像机基（当前帧的基）上：
# 基相同，则两者之差里就不含玩家的转动，只剩下靶机自身的位移和玩家的平移。
# 玩家平移的贡献要保留——Apex 里"边平移边开镜自动跟枪"正是靠它产生的。
#
# 如果这里不排除玩家转动，旋转跟枪会自我正反馈：玩家一转，辅助跟着加速，视角直接失控。
func _angular_velocity(
	id: int, pos: Vector3, cam_pos: Vector3, cam_basis: Basis, offset: Vector2, delta: float
) -> Vector2:
	if not _has_prev or delta <= 0.0 or not _prev_target_pos.has(id):
		return Vector2.ZERO
	var prev_offset := HitTest.angular_offset(_prev_target_pos[id] - _prev_cam_pos, cam_basis)
	# 靶机绕到背后时偏航会在 ±180 处折返，不做环绕修正会算出上千度的假角速度。
	var d := Vector2(
		wrapf(offset.x - prev_offset.x, -180.0, 180.0),
		wrapf(offset.y - prev_offset.y, -180.0, 180.0),
	)
	return (d / delta).limit_length(MAX_ANGULAR_SPEED)
