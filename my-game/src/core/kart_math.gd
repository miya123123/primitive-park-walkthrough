extends RefCounted

## ゴーカートの入力・表示に使う純粋な計算ヘルパー。

## 目標速度へアーケードらしく近づける。
static func approach_speed(current: float, target: float, delta: float, acceleration: float, braking: float, coast: float) -> float:
	if delta <= 0.0:
		return current
	var rate: float = acceleration
	if absf(target) < absf(current):
		rate = braking if not is_zero_approx(target) else coast
	return move_toward(current, target, maxf(rate, 0.0) * delta)

## 速度に応じてステアリング量を抑え、低速でも曲がれるようにする。
static func steering_factor(speed: float, max_speed: float) -> float:
	return clampf(absf(speed) / maxf(max_speed, 0.001), 0.2, 1.0)

## 秒数をタイムアタック表示用の mm:ss.hh へ変換する。
static func format_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var minutes: int = int(safe_seconds) / 60
	var whole_seconds: int = int(safe_seconds) % 60
	var centiseconds: int = int(roundf(fmod(safe_seconds, 1.0) * 100.0))
	if centiseconds >= 100:
		centiseconds = 0
		whole_seconds += 1
	if whole_seconds >= 60:
		whole_seconds = 0
		minutes += 1
	return "%02d:%02d.%02d" % [minutes, whole_seconds, centiseconds]

## 同じ順序でチェックポイントを通過したかを判定する。
static func valid_checkpoint_crossing(distance: float, gate_radius: float, forward_dot: float) -> bool:
	return distance <= gate_radius and forward_dot >= 0.0
