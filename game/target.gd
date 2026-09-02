## 一个靶机。
##
## 没有碰撞体也没有 Area3D——命中判定由 [HitTest] 解析求解，见 core/aim/hit_test.gd 的说明。
## 这里只负责运动与外观。
class_name Target
extends Node3D

const _BASE_COLOR := Color(1.0, 0.35, 0.30)
const _HIT_COLOR := Color(1.0, 0.95, 0.55)
const _BEAM_COLOR := Color(0.45, 1.0, 0.55)

var radius: float = 0.35
var motion: ScenarioDef.Motion = ScenarioDef.Motion.STRAFE
var speed: float = 5.0
var motion_range: float = 6.0
var direction_change_rate: float = 0.8
var health: int = 1
var spawn_time: float = 0.0
var alive: bool = true

var _origin := Vector3.ZERO
var _dir := Vector3.RIGHT
var _phase := 0.0
var _flash := 0.0
var _lit := false
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _rng: RandomNumberGenerator


func setup(def: ScenarioDef, origin: Vector3, rng: RandomNumberGenerator, now: float) -> void:
	_rng = rng
	_origin = origin
	global_position = origin
	radius = def.target_radius
	motion = def.motion
	speed = rng.randf_range(def.speed_min, def.speed_max)
	motion_range = def.motion_range
	direction_change_rate = def.direction_change_rate
	health = def.hits_to_kill
	spawn_time = now
	alive = true
	_phase = rng.randf() * TAU
	_dir = Vector3.RIGHT if rng.randf() < 0.5 else Vector3.LEFT
	if motion == ScenarioDef.Motion.DRIFT:
		_dir = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	_build_visual()


## 热更新运动与尺寸，不换位置。半径变了才重建网格。
func apply_live(def: ScenarioDef) -> void:
	var radius_changed := not is_equal_approx(radius, def.target_radius)
	radius = def.target_radius
	motion = def.motion
	motion_range = def.motion_range
	direction_change_rate = def.direction_change_rate
	var lo := minf(def.speed_min, def.speed_max)
	var hi := maxf(def.speed_min, def.speed_max)
	speed = clampf(speed, lo, hi)
	if health > def.hits_to_kill:
		health = def.hits_to_kill
	if radius_changed:
		_build_visual()


func _process(delta: float) -> void:
	if not alive:
		return
	_advance_motion(delta)
	_advance_flash(delta)


## 被子弹命中。返回是否因此被击毁。
## 击毁后的处置（重生还是留在原地）由 [Scenario] 决定，靶机自己不作主。
func take_hit() -> bool:
	_flash = 1.0
	health -= 1
	if health > 0:
		return false
	alive = false
	return true


## 光束模式下每帧告知是否被照射，用于给出视觉反馈。
func set_beam_lit(lit: bool) -> void:
	if lit == _lit:
		return
	_lit = lit
	_refresh_color()


func _advance_motion(delta: float) -> void:
	match motion:
		ScenarioDef.Motion.STATIC:
			return
		ScenarioDef.Motion.ORBIT:
			_phase += speed / maxf(motion_range, 0.1) * delta
			global_position = _origin + Vector3(
				cos(_phase) * motion_range,
				sin(_phase) * motion_range * 0.35,
				0.0,
			)
		ScenarioDef.Motion.DRIFT:
			_maybe_change_direction(delta)
			var next := global_position + _dir * speed * delta
			# 越界即沿越界轴反弹，保证靶机始终停留在可练习的范围内。
			var offset := next - _origin
			for axis in 3:
				if absf(offset[axis]) > motion_range:
					_dir[axis] = -_dir[axis]
					offset[axis] = signf(offset[axis]) * motion_range
			global_position = _origin + offset
		_:
			_maybe_change_direction(delta)
			var pos := global_position + _dir * speed * delta
			var dx := pos.x - _origin.x
			if absf(dx) > motion_range:
				dx = signf(dx) * motion_range
				_dir = -_dir
			global_position = Vector3(_origin.x + dx, pos.y, pos.z)


# 用"每秒变向概率"而非固定周期，是为了让节奏不可预测——
# 可预测的横移靶练出来的是背板，不是跟枪。
func _maybe_change_direction(delta: float) -> void:
	if direction_change_rate <= 0.0 or _rng == null:
		return
	if _rng.randf() >= direction_change_rate * delta:
		return
	if motion == ScenarioDef.Motion.DRIFT:
		_dir = Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)
		).normalized()
	else:
		_dir = -_dir


func _advance_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta * 5.0)
	_refresh_color()


func _refresh_color() -> void:
	if _material == null:
		return
	var base := _BEAM_COLOR if _lit else _BASE_COLOR
	var c := base.lerp(_HIT_COLOR, _flash)
	_material.albedo_color = c
	_material.emission = c
	_material.emission_energy_multiplier = 0.7 + _flash * 2.0 + (0.5 if _lit else 0.0)


func _build_visual() -> void:
	if _mesh != null:
		_mesh.queue_free()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12

	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.roughness = 0.45
	_refresh_color()

	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.material_override = _material
	add_child(_mesh)
