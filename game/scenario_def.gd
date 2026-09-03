## 一个训练场景的全部参数。
##
## 四种训练（追踪 / 甩枪 / 目标切换 / 精度）本质上是同一套逻辑的不同配比，
## 因此做成"一个 Scenario 类 + 一份参数"，而不是四个各写一遍的子类。
## 顺带的好处是这些参数可以直接暴露到面板上，使用者能自己捏出介于两者之间的练习。
class_name ScenarioDef
extends Resource

enum Motion {
	STATIC, ## 静止。用于甩枪与精度。
	STRAFE, ## 水平横移并随机变向。最接近 FPS 里的敌人身法，追踪训练的主力。
	DRIFT,  ## 三维随机漂移。考察垂直方向的跟随。
	ORBIT,  ## 绕中心圆周运动。角速度恒定，适合校准跟枪辅助的强度。
}

enum Weapon {
	BEAM, ## 持续光束。不计命中率，计"在靶时间占比"，追踪训练用。
	SEMI, ## 半自动，每次扣扳机一发。甩枪与精度训练用。
	AUTO, ## 全自动，按住连发。
}

@export var display_name: String = "自定义"
@export_multiline var description: String = ""

@export_group("武器")
@export var weapon: Weapon = Weapon.SEMI
## AUTO 模式的射速，发/秒。
@export_range(1.0, 20.0, 0.5) var fire_rate: float = 8.0
@export_range(1, 10) var hits_to_kill: int = 1

@export_group("靶机")
@export_range(1, 12) var target_count: int = 3
@export_range(0.05, 2.0, 0.01) var target_radius: float = 0.35
@export var respawn_on_hit: bool = true

@export_group("布置")
@export_range(3.0, 120.0, 0.5) var distance_min: float = 18.0
@export_range(3.0, 120.0, 0.5) var distance_max: float = 26.0
## 水平散布半宽，米。决定甩枪的转移幅度。
@export_range(1.0, 60.0, 0.5) var spread_h: float = 14.0
@export_range(0.5, 20.0, 0.5) var spread_v: float = 3.0

@export_group("运动")
@export var motion: Motion = Motion.STRAFE
@export_range(0.0, 20.0, 0.1) var speed_min: float = 3.0
@export_range(0.0, 20.0, 0.1) var speed_max: float = 7.0
## 运动幅度（相对出生点的半径，米）。
@export_range(0.5, 30.0, 0.5) var motion_range: float = 6.0
## 每秒随机变向的概率。调高会显著增加追踪难度。
@export_range(0.0, 4.0, 0.05) var direction_change_rate: float = 0.8

@export_group("时长")
@export_range(10.0, 300.0, 5.0) var duration: float = 60.0


func clone() -> ScenarioDef:
	return duplicate(true) as ScenarioDef


## 该场景的主指标名，用于 HUD 上突出显示。
func primary_metric_label() -> String:
	return "在靶时间" if weapon == Weapon.BEAM else "命中率"


# ---------------------------------------------------------------------------
# 四套内置场景。
# ---------------------------------------------------------------------------

static func preset_tracking() -> ScenarioDef:
	var d := ScenarioDef.new()
	d.display_name = "追踪"
	d.description = "把光束持续压在横移靶上。考察摇杆中低速段的控制力，"\
		+ "也是最能体现响应曲线与旋转跟枪差异的场景。"
	d.weapon = Weapon.BEAM
	d.target_count = 1
	d.target_radius = 0.45
	d.motion = Motion.STRAFE
	d.distance_min = 20.0
	d.distance_max = 20.0
	d.spread_h = 2.0
	d.spread_v = 0.5
	d.speed_min = 4.0
	d.speed_max = 8.0
	d.motion_range = 8.0
	d.direction_change_rate = 1.1
	d.respawn_on_hit = false
	return d


static func preset_flick() -> ScenarioDef:
	var d := ScenarioDef.new()
	d.display_name = "甩枪"
	d.description = "静止靶点间快速转移并点击。考察大幅位移的落点精度，"\
		+ "响应曲线末段过陡会表现为频繁过冲。"
	d.weapon = Weapon.SEMI
	d.target_count = 4
	d.target_radius = 0.32
	d.motion = Motion.STATIC
	d.distance_min = 16.0
	d.distance_max = 24.0
	d.spread_h = 16.0
	d.spread_v = 5.0
	d.respawn_on_hit = true
	return d


static func preset_switching() -> ScenarioDef:
	var d := ScenarioDef.new()
	d.display_name = "目标切换"
	d.description = "多个移动靶之间来回切换。追踪与甩枪的结合，"\
		+ "也是检验辅助瞄准会不会锁错目标的场景。"
	d.weapon = Weapon.AUTO
	d.fire_rate = 9.0
	d.target_count = 3
	d.target_radius = 0.38
	d.motion = Motion.STRAFE
	d.distance_min = 18.0
	d.distance_max = 28.0
	d.spread_h = 13.0
	d.spread_v = 3.0
	d.speed_min = 3.0
	d.speed_max = 6.5
	d.motion_range = 5.0
	d.direction_change_rate = 0.7
	d.respawn_on_hit = true
	return d


static func preset_precision() -> ScenarioDef:
	var d := ScenarioDef.new()
	d.display_name = "精度"
	d.description = "远距离小靶缓慢漂移。考察死区之外最低速段的微操，"\
		+ "内死区偏大或曲线前段偏陡都会在这里暴露。"
	d.weapon = Weapon.SEMI
	d.target_count = 2
	d.target_radius = 0.13
	d.motion = Motion.DRIFT
	d.distance_min = 45.0
	d.distance_max = 65.0
	d.spread_h = 10.0
	d.spread_v = 4.0
	d.speed_min = 0.6
	d.speed_max = 1.6
	d.motion_range = 3.0
	d.direction_change_rate = 0.35
	d.respawn_on_hit = true
	return d


static func all_presets() -> Array[ScenarioDef]:
	return [preset_tracking(), preset_flick(), preset_switching(), preset_precision()]
