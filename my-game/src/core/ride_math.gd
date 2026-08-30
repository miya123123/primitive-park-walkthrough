extends RefCounted

## Pure helpers for deterministic ride phase and closed-track calculations.

## Returns the wrapped phase after advancing a looping value by speed * delta.
static func advance_loop(current: float, delta: float, speed: float, period: float) -> float:
	if period <= 0.0:
		return 0.0
	var normalized_current: float = fmod(current, period)
	if normalized_current < 0.0:
		normalized_current += period
	return fmod(normalized_current + maxf(delta, 0.0) * maxf(speed, 0.0), period)

## Reports whether a phase is at the station boundary, including wrap-around.
static func is_at_station(phase: float, period: float, tolerance: float) -> bool:
	if period <= 0.0:
		return false
	var normalized_phase: float = fmod(phase, period)
	if normalized_phase < 0.0:
		normalized_phase += period
	return normalized_phase <= tolerance or period - normalized_phase <= tolerance

## Returns true when a forward loop step crosses the station boundary.
static func crossed_station(previous: float, next: float, period: float) -> bool:
	if period <= 0.0:
		return false
	return next < previous

## Returns true when a forward step crosses the station, including multi-loop steps.
static func crossed_station_by_delta(previous: float, delta: float, speed: float, period: float) -> bool:
	if period <= 0.0 or delta <= 0.0 or speed <= 0.0:
		return false
	var normalized_previous: float = fmod(previous, period)
	if normalized_previous < 0.0:
		normalized_previous += period
	return delta * speed >= period - normalized_previous

## Returns a normalized tangent for a closed polyline at the requested distance.
static func closed_track_tangent(points: PackedVector3Array, distance: float) -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	var remaining: float = maxf(distance, 0.0)
	for index: int in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		var segment: Vector3 = points[next_index] - points[index]
		var segment_length: float = segment.length()
		if segment_length > 0.0001:
			if remaining <= segment_length:
				return segment / segment_length
			remaining -= segment_length
	return (points[1] - points[0]).normalized()
