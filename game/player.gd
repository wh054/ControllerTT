## 第一人称玩家。整条"摇杆 → 视角"链路在这里汇合。
##
## 全部逻辑跑在 [method Node._process]（渲染帧）而非物理帧上，这是刻意的：
## 瞄准训练器里输入延迟是第一位的指标，多等一个物理帧就多几毫秒。
## 代价是不能用 CharacterBody3D 的 move_and_slide，但本项目的场地是空旷平地，
## 位移直接积分并夹在边界内即可，没有任何损失。
class_name Player
extends Node3D

const VideoConfig = preload("res://core/video/video_config.gd")
const RangeBounds = preload("res://core/range/range_bounds.gd")

## 俯仰角上下限，度。略小于 90 以免视角翻转。
const PITCH_LIMIT := 89.0
const EYE_HEIGHT := 1.7
## 开镜视场切换所需时间，秒。
const FOV_BLEND_TIME := 0.12

@onready var camera: Camera3D = $Camera3D

## 由 Main 注入。玩家需要向它取靶机列表并回报击杀。
var scenario: Scenario
var stats: SessionStats

var reader := GamepadReader.new()
var processor := StickProcessor.new()
var assist := AimAssist.new()
var sampler := AimSampler.new()

## 暂停时（打开参数面板）停止一切输入处理。
var active: bool = true
var move_speed: float = 6.0
var arena_half: float = 13.0
## 鼠标直接控制视角。它**绕过**整条摇杆管线，只用于没手柄时四处看看，
## 不能用来训练，面板上有对应说明。
var mouse_look: bool = true
var mouse_sensitivity: float = 0.08

## 供 UI 读取的最近一帧状态。
var last_assist: AimAssist.Result = AimAssist.Result.new()
var last_raw_look := Vector2.ZERO
var last_move := Vector2.ZERO
var ads: bool = false
var _last_ads: bool = false

var audio := AudioManager.new()
var weapon_rig := WeaponRig.new()

var _yaw: float = 0.0  ## 度，右为正
var _pitch: float = 0.0  ## 度，上为正
var _fire_cooldown: float = 0.0
var _was_firing: bool = false
var _beam_target: Target = null


func _ready() -> void:
	reader.pick_first_device()
	add_child(audio)
	if camera != null:
		camera.add_child(weapon_rig)
	_sync_config()
	_sync_audio()
	_update_weapon_rig()
	App.profile_changed.connect(_sync_config)
	App.assist_changed.connect(_sync_config)
	App.video_changed.connect(_on_video_changed)
	App.audio_changed.connect(_sync_audio)
	App.weapon_visual_changed.connect(_update_weapon_rig)
	App.scenario_changed.connect(_update_weapon_rig)
	App.range_move_mode_changed.connect(_on_range_move_mode_changed)
	camera.fov = _current_base_vfov()
	reset_pose()


func _sync_config() -> void:
	processor.profile = App.profile
	assist.config = App.assist


func _sync_audio() -> void:
	if audio != null:
		audio.volume = App.sfx_volume
		audio.enabled = App.sfx_enabled


func _update_weapon_rig() -> void:
	if weapon_rig == null:
		return
	match App.weapon_visual:
		AppState.WeaponVisualMode.HIDDEN:
			weapon_rig.visible_weapon = false
			weapon_rig.set_weapon(WeaponRig.WeaponType.NONE)
		AppState.WeaponVisualMode.FORCE_M4:
			weapon_rig.visible_weapon = true
			weapon_rig.set_weapon(WeaponRig.WeaponType.M4)
		AppState.WeaponVisualMode.FORCE_DEAGLE:
			weapon_rig.visible_weapon = true
			weapon_rig.set_weapon(WeaponRig.WeaponType.DEAGLE)
		AppState.WeaponVisualMode.AUTO_BY_SCENARIO:
			weapon_rig.visible_weapon = true
			if App.scenario != null and App.scenario.weapon == ScenarioDef.Weapon.AUTO:
				weapon_rig.set_weapon(WeaponRig.WeaponType.M4)
			else:
				weapon_rig.set_weapon(WeaponRig.WeaponType.DEAGLE)


func _on_video_changed() -> void:
	if camera != null and not ads:
		camera.fov = _current_base_vfov()
	global_position.y = _current_eye_height()


func _current_base_vfov() -> float:
	return App.video.vertical_fov() if App.video != null else VideoConfig.hfov_to_vfov(103.0)


func _current_ads_vfov() -> float:
	return App.video.ads_vertical_fov() if App.video != null else VideoConfig.hfov_to_vfov(103.0 * 0.55)


func _current_eye_height() -> float:
	return App.video.eye_height if App.video != null else 1.7


## 回到场地中央并把视角摆正。重开训练时调用。
func reset_pose() -> void:
	_yaw = 0.0
	_pitch = 0.0
	global_position = Vector3(0.0, _current_eye_height(), 0.0)
	processor.reset()
	sampler.reset()
	_beam_target = null
	_fire_cooldown = 0.0
	_was_firing = false
	_update_weapon_rig()
	_apply_rotation()


func _process(delta: float) -> void:
	if not active:
		return
	last_raw_look = reader.look_raw(delta)
	var raw_move := reader.move_raw(delta)
	ads = reader.aiming()

	last_move = App.profile.move_deadzone.apply(raw_move)
	_advance_movement(last_move, delta)

	# 顺序要紧：先采样靶机（用的是本帧转动**之前**的摄像机基），
	# 再算辅助，最后才真正转动视角。颠倒的话角速度里就会混进玩家自己的转动。
	var aim_targets := sampler.sample(
		camera.global_position, camera.global_basis, _targets(), delta
	)
	var rate := processor.process(last_raw_look, delta, ads)
	last_assist = assist.compute(aim_targets, processor.last_after_deadzone, last_move, ads)

	_advance_look(rate * last_assist.turn_scale + last_assist.bonus_dps, delta)
	_advance_fov(delta)
	_advance_weapon(delta)

	if stats != null:
		stats.sample_stick(processor.last_after_deadzone.length(), last_assist.has_effect())


func _unhandled_input(event: InputEvent) -> void:
	if not active or not mouse_look:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_yaw += m.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - m.relative.y * mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)
		_apply_rotation()


func _targets() -> Array:
	return scenario.active_targets() if scenario != null else []


func get_movement_bounds() -> Dictionary:
	return RangeBounds.get_bounds(App.range_move_mode, arena_half)


func _clamp_position_to_bounds() -> void:
	global_position = RangeBounds.clamp_position(
		global_position, App.range_move_mode, _current_eye_height(), arena_half
	)


func _on_range_move_mode_changed() -> void:
	_clamp_position_to_bounds()


func _advance_movement(move: Vector2, delta: float) -> void:
	if App.range_move_mode == RangeBounds.Mode.STATION_FIXED:
		global_position = Vector3(0.0, _current_eye_height(), 0.0)
		return
	if move == Vector2.ZERO:
		return
	# 摇杆 +y 向下代表向后，故直接用 move.y 作为局部 Z 分量（局部 -Z 为前方）。
	var local := Vector3(move.x, 0.0, move.y)
	var world := Basis(Vector3.UP, deg_to_rad(-_yaw)) * local
	var pos := global_position + world * move_speed * delta
	global_position = RangeBounds.clamp_position(
		pos, App.range_move_mode, _current_eye_height(), arena_half
	)


func _advance_look(rate_dps: Vector2, delta: float) -> void:
	if rate_dps == Vector2.ZERO:
		return
	_yaw = wrapf(_yaw + rate_dps.x * delta, -180.0, 180.0)
	_pitch = clampf(_pitch + rate_dps.y * delta, -PITCH_LIMIT, PITCH_LIMIT)
	if weapon_rig != null:
		weapon_rig.apply_look_sway(rate_dps.x, rate_dps.y)
	_apply_rotation()


func _apply_rotation() -> void:
	# 偏航约定右为正，而 Godot 绕 +Y 旋转是向左，故取负。
	rotation = Vector3(0.0, deg_to_rad(-_yaw), 0.0)
	if camera != null:
		camera.rotation = Vector3(deg_to_rad(_pitch), 0.0, 0.0)


func _advance_fov(delta: float) -> void:
	var base := _current_base_vfov()
	var ads_fov := _current_ads_vfov()
	var target := ads_fov if ads else base
	camera.fov = move_toward(camera.fov, target, absf(base - ads_fov) / FOV_BLEND_TIME * delta)
	if weapon_rig != null:
		var ads_factor := clampf((base - camera.fov) / maxf(0.1, base - ads_fov), 0.0, 1.0)
		weapon_rig.set_ads_ratio(ads_factor)
	if ads != _last_ads:
		if ads and audio != null:
			audio.play_ads()
		_last_ads = ads


func _advance_weapon(delta: float) -> void:
	var def := App.scenario
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var firing := reader.firing()

	match def.weapon:
		ScenarioDef.Weapon.BEAM:
			_advance_beam(delta if firing else -1.0)
		ScenarioDef.Weapon.AUTO:
			if firing and _fire_cooldown <= 0.0:
				_fire_cooldown = 1.0 / maxf(def.fire_rate, 0.1)
				_shoot()
		_:
			if firing and not _was_firing:
				_shoot()

	_was_firing = firing


# 光束模式：不计命中率，只累计准星停在靶上的时间。追踪训练的计分方式。
#
# 必须按住扳机才计时，而不是一直计。理由是这样才和真实交火一致：
# 实战里"枪口对准"和"正在开火"是两件事，只练前者会养成不开枪的习惯。
# delta 为负表示没有开火，此时只熄灭光束不计时。
func _advance_beam(delta: float) -> void:
	var hit := _pick_target() if delta >= 0.0 else null
	if _beam_target != null and _beam_target != hit:
		_beam_target.set_beam_lit(false)
	_beam_target = hit
	if hit == null:
		return
	hit.set_beam_lit(true)
	if stats != null:
		stats.time_on_target += delta


func _shoot() -> void:
	if weapon_rig != null:
		weapon_rig.fire()
	if audio != null:
		if weapon_rig != null and weapon_rig.current_type == WeaponRig.WeaponType.DEAGLE:
			audio.play_deagle_fire()
		else:
			audio.play_m4_fire()

	var hit := _pick_target()
	if stats != null:
		stats.record_shot(hit != null)
	if hit == null:
		return

	if audio != null:
		audio.play_hit()

	if hit.take_hit():
		if audio != null:
			audio.play_kill()
		if scenario != null:
			scenario.report_kill(hit)


# 从准星射出一条射线，返回最近的靶机；没打中返回 null。
func _pick_target() -> Target:
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	var best: Target = null
	var best_t := INF
	for node in _targets():
		var t := node as Target
		if t == null or not t.alive:
			continue
		var d := HitTest.ray_sphere(origin, dir, t.global_position, t.radius)
		if d < 0.0 or d >= best_t:
			continue
		best = t
		best_t = d
	return best
