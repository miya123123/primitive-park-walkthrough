extends RefCounted

## Pure movement helpers kept separate from input and scene state.

## Calculates horizontal velocity in the player's local basis.
static func horizontal_velocity(input_vector: Vector2, basis: Basis, speed: float) -> Vector3:
	var direction: Vector3 = basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction * maxf(speed, 0.0)

## Applies gravity or starts a jump when the player is grounded.
static func next_vertical_velocity(current: float, delta: float, gravity: float, grounded: bool, jump_requested: bool, jump_velocity: float) -> float:
	if grounded:
		return jump_velocity if jump_requested else 0.0
	return current - gravity * delta

## Clamps a third-person orbit pitch between the configured down and up limits.
static func clamped_orbit_pitch(current: float, delta_pitch: float, sensitivity: float, min_pitch_degrees: float, max_pitch_degrees: float) -> float:
	var min_limit: float = deg_to_rad(min_pitch_degrees)
	var max_limit: float = deg_to_rad(max_pitch_degrees)
	return clampf(current - delta_pitch * sensitivity, min_limit, max_limit)

## Converts a flat world direction into the player's Godot Y-axis facing angle.
static func target_yaw(direction: Vector3, fallback: float = 0.0) -> float:
	var flat_direction: Vector3 = direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() <= 0.000001:
		return fallback
	flat_direction = flat_direction.normalized()
	return atan2(-flat_direction.x, -flat_direction.z)
