## 枪模与音效系统单元测试。
class_name TestWeaponRig
extends TestCase

const WeaponRig = preload("res://game/weapon/weapon_rig.gd")
const AudioManager = preload("res://game/audio_manager.gd")


func suite_name() -> String:
	return "枪械模型与音效"


func test_weapon_switching() -> void:
	var rig = WeaponRig.new()
	rig._ready()

	# 初始状态
	assert_eq(rig.current_type, WeaponRig.WeaponType.NONE, "初始武器类型应为 NONE")

	# 切到 M4
	rig.set_weapon(WeaponRig.WeaponType.M4)
	assert_eq(rig.current_type, WeaponRig.WeaponType.M4, "当前武器应为 M4")
	assert_true(rig.is_m4_visible(), "M4 模型应处于可见状态")
	assert_false(rig.is_deagle_visible(), "沙鹰模型应处于隐藏状态")

	# 切到沙鹰
	rig.set_weapon(WeaponRig.WeaponType.DEAGLE)
	assert_eq(rig.current_type, WeaponRig.WeaponType.DEAGLE, "当前武器应为 沙漠之鹰")
	assert_false(rig.is_m4_visible(), "M4 模型应处于隐藏状态")
	assert_true(rig.is_deagle_visible(), "沙鹰模型应处于可见状态")

	# 隐藏枪模
	rig.visible_weapon = false
	rig.set_weapon(WeaponRig.WeaponType.M4)
	assert_false(rig.is_m4_visible(), "当 visible_weapon 为 false 时模型应隐藏")
	rig.free()


func test_recoil_and_recovery() -> void:
	var rig = WeaponRig.new()
	rig._ready()
	rig.set_weapon(WeaponRig.WeaponType.DEAGLE)

	# 初始位置已初始化
	rig._process(0.016)
	var z0: float = rig.position.z

	# 开火产生反冲
	rig.fire()
	rig._process(0.001)
	var z1: float = rig.position.z
	assert_true(z1 > z0, "沙鹰开火应产生明显的后坐力后座反冲位移")

	# 经过多帧阻尼更新后收敛复位
	for i in 60:
		rig._process(0.016)

	assert_near(rig.position.z, z0, 0.01, "经过阻尼后坐力位置应复位")
	rig.free()


func test_ads_transition() -> void:
	var rig = WeaponRig.new()
	rig._ready()
	rig.set_weapon(WeaponRig.WeaponType.M4)

	# 腰射状态
	rig.set_ads_ratio(0.0)
	rig._process(0.016)
	var hip_x: float = rig.position.x
	assert_true(hip_x > 0.1, "腰射时枪模应位于屏幕右侧偏下方")

	# 机瞄状态
	rig.set_ads_ratio(1.0)
	rig._process(0.016)
	var ads_x: float = rig.position.x
	assert_true(absf(ads_x) < 0.02, "开镜机瞄时枪模应精准对齐中心线")
	rig.free()


func test_audio_playback_methods() -> void:
	var audio = AudioManager.new()
	audio._ready()
	assert_true(audio.enabled, "默认音效应为开启")
	assert_true(audio.volume > 0.5, "默认音效音量应合理")

	# 验证音效方法调用正常，不抛出异常
	audio.play_m4_fire()
	audio.play_deagle_fire()
	audio.play_hit()
	audio.play_kill()
	audio.play_ads()
	audio.free()
