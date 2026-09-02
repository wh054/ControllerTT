## 一次训练的成绩与遥测。
##
## 除了常规的命中率之外，这里刻意记录了**摇杆偏转量的分布直方图**。
## 这是本工具区别于普通练枪软件的地方：它能回答"我的时间实际花在摇杆行程的哪一段上"，
## 而这一段恰恰就是响应曲线里最该被调好的部分。只看命中率是看不出这件事的。
class_name SessionStats
extends RefCounted

## 偏转量直方图的分桶数，每桶覆盖 0.1 的行程。
const BUCKETS := 10

var elapsed: float = 0.0
var shots: int = 0
var hits: int = 0
var kills: int = 0
## 光束模式下准星停留在目标上的累计时间。
var time_on_target: float = 0.0
## 从目标出现到被击中的间隔，反映反应与转移速度。
var reaction_times: PackedFloat32Array = PackedFloat32Array()
## 摇杆偏转量的时间分布，索引 i 表示偏转量落在 [i/10, (i+1)/10) 的采样数。
var deflection_buckets: PackedInt32Array = PackedInt32Array()
## 辅助瞄准实际生效的时间占比统计用：有辅助介入的采样数。
var assisted_samples: int = 0

## 判定"摇杆正在被使用"的阈值。低于此值的采样不计入直方图。
const _ACTIVE_THRESHOLD := 0.02

var _samples: int = 0
var _active_samples: int = 0
var _deflection_sum: float = 0.0


func _init() -> void:
	deflection_buckets.resize(BUCKETS)


func reset() -> void:
	elapsed = 0.0
	shots = 0
	hits = 0
	kills = 0
	time_on_target = 0.0
	reaction_times = PackedFloat32Array()
	deflection_buckets = PackedInt32Array()
	deflection_buckets.resize(BUCKETS)
	assisted_samples = 0
	_samples = 0
	_active_samples = 0
	_deflection_sum = 0.0


## 每帧采样一次摇杆状态。deflection 为死区处理后的偏转量 0..1。
##
## 直方图只统计摇杆真正在动的帧。如果把松杆的帧也算进去，第一个桶会吃掉绝大多数样本，
## 直方图就退化成"你有多少时间没在动摇杆"，对调曲线毫无参考价值。
func sample_stick(deflection: float, assist_active: bool) -> void:
	_samples += 1
	if assist_active:
		assisted_samples += 1
	if deflection < _ACTIVE_THRESHOLD:
		return
	_active_samples += 1
	_deflection_sum += deflection
	var i := clampi(int(deflection * BUCKETS), 0, BUCKETS - 1)
	deflection_buckets[i] += 1


func record_shot(hit: bool) -> void:
	shots += 1
	if hit:
		hits += 1


func record_kill(reaction: float) -> void:
	kills += 1
	if reaction > 0.0:
		reaction_times.append(reaction)


func accuracy() -> float:
	return float(hits) / shots if shots > 0 else 0.0


func kills_per_second() -> float:
	return kills / elapsed if elapsed > 0.0 else 0.0


func time_on_target_ratio() -> float:
	return time_on_target / elapsed if elapsed > 0.0 else 0.0


func assist_ratio() -> float:
	return float(assisted_samples) / _samples if _samples > 0 else 0.0


func avg_reaction() -> float:
	if reaction_times.is_empty():
		return 0.0
	var sum := 0.0
	for t in reaction_times:
		sum += t
	return sum / reaction_times.size()


## 摇杆在动时的平均偏转量。
func avg_deflection() -> float:
	return _deflection_sum / _active_samples if _active_samples > 0 else 0.0


## 摇杆在动的时间占整场的比例。
func active_ratio() -> float:
	return float(_active_samples) / _samples if _samples > 0 else 0.0


## 第 i 桶占"摇杆在动"的采样的比例，供直方图绘制。
func bucket_ratio(i: int) -> float:
	if _active_samples <= 0 or i < 0 or i >= BUCKETS:
		return 0.0
	return float(deflection_buckets[i]) / _active_samples


## 摇杆行程低段（0 ~ 0.3，微操区）占推杆时间的比例。
## 这个比例高，说明响应曲线的前段对你影响最大，应当优先调它。
func fine_control_ratio() -> float:
	if _active_samples <= 0:
		return 0.0
	var low := 0
	for i in 3:
		low += deflection_buckets[i]
	return float(low) / _active_samples
