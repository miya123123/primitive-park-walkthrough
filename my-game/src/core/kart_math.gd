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

## Returns continuous left/right boundary vertices for a closed kart track.
##
## Each corner shares one mitered vertex with its neighboring segments. This
## keeps the two collision rails connected at bends instead of letting the
## independently offset segment ends overlap the drivable lane.
static func closed_track_boundaries(points: Array, track_width: float) -> Dictionary:
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	if points.size() < 2 or track_width <= 0.0:
		return {"left": left, "right": right}
	var half_width: float = track_width * 0.5
	var point_count: int = points.size()
	for index: int in range(point_count):
		var point: Vector3 = points[index]
		var previous: Vector3 = points[(index - 1 + point_count) % point_count]
		var next: Vector3 = points[(index + 1) % point_count]
		var incoming: Vector3 = point - previous
		incoming.y = 0.0
		var outgoing: Vector3 = next - point
		outgoing.y = 0.0
		if incoming.length_squared() <= 0.000001:
			incoming = outgoing
		if outgoing.length_squared() <= 0.000001:
			outgoing = incoming
		if incoming.length_squared() <= 0.000001 or outgoing.length_squared() <= 0.000001:
			left.append(point + Vector3.LEFT * half_width)
			right.append(point + Vector3.RIGHT * half_width)
			continue
		incoming = incoming.normalized()
		outgoing = outgoing.normalized()
		var incoming_normal: Vector3 = Vector3(-incoming.z, 0.0, incoming.x)
		var outgoing_normal: Vector3 = Vector3(-outgoing.z, 0.0, outgoing.x)
		var miter: Vector3 = incoming_normal + outgoing_normal
		if miter.length_squared() <= 0.000001:
			miter = outgoing_normal
		else:
			miter = miter.normalized()
		# Limit extremely sharp corners to a stable two-width bevel rather than
		# producing a long spike that could create a new collision obstacle.
		var miter_scale: float = half_width / maxf(absf(miter.dot(outgoing_normal)), 0.5)
		miter_scale = minf(miter_scale, half_width * 2.0)
		left.append(point + miter * miter_scale)
		right.append(point - miter * miter_scale)
	return {"left": left, "right": right}
