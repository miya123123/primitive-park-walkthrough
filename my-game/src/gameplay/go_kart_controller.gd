extends "res://src/gameplay/ride_provider.gd"

const KartMath = preload("res://src/core/kart_math.gd")
const ParkConfig = preload("res://src/core/park_config.gd")
const KartRecordStore = preload("res://src/core/kart_record_store.gd")

## ゴーカートのアーケード運転、周回判定、タイムアタック記録を管理する。

const STATE_DECORATIVE: StringName = &"decorative"
const STATE_BOARDING: StringName = &"boarding"
const STATE_COUNTDOWN: StringName = &"countdown"
const STATE_RACING: StringName = &"racing"
const STATE_FINISHED: StringName = &"finished"

var _ride_id: StringName = &"go_kart"
var _display_name: String = "Go-Kart Circuit"
var _cart: CharacterBody3D
var _seat_anchor: Node3D
var _exit_marker: Node3D
var _track_points: Array[Vector3] = []
var _checkpoint_indices: Array[int] = []
var _checkpoint_sequence: Array[int] = []
var _next_checkpoint_cursor: int = 0
var _lap_count: int = 3
var _current_lap: int = 1
var _state: StringName = STATE_DECORATIVE
var _speed: float = 0.0
var _elapsed: float = 0.0
var _countdown_remaining: float = 3.0
var _result_elapsed: float = 0.0
var _progress_elapsed: float = 0.0
var _last_valid_position: Vector3 = Vector3.ZERO
var _last_valid_yaw: float = 0.0
var _ground_height: float = 0.45
var _track_width: float = 3.6
var _max_forward_speed: float = 11.0
var _max_reverse_speed: float = 4.0
var _acceleration: float = 8.0
var _brake_strength: float = 14.0
var _coast_deceleration: float = 4.0
var _steering_degrees_per_second: float = 105.0
var _countdown_seconds: float = 3.0
var _result_display_seconds: float = 3.0
var _best_record_path: String = "user://primitive_park_records.cfg"
var _best_time: float = 0.0
var _last_result_time: float = 0.0

## Builds a configured provider from the generated circuit descriptor.
func configure(descriptor: Dictionary) -> void:
	_ride_id = StringName(String(descriptor.get("ride_id", "go_kart")))
	_display_name = String(descriptor.get("display_name", "Go-Kart Circuit"))
	_cart = descriptor.get("cart") as CharacterBody3D
	_seat_anchor = descriptor.get("seat_anchor") as Node3D
	_exit_marker = descriptor.get("exit_marker") as Node3D
	_ground_height = _cart.position.y if is_instance_valid(_cart) else 0.45
	_track_points.clear()
	var points_value: Variant = descriptor.get("track_points", [])
	if points_value is Array:
		for point_value: Variant in points_value:
			_track_points.append(ParkConfig.vector3_from_array(point_value))
	_checkpoint_indices.clear()
	var checkpoints_value: Variant = descriptor.get("checkpoint_indices", [])
	if checkpoints_value is Array:
		for checkpoint_value: Variant in checkpoints_value:
			if checkpoint_value is int or checkpoint_value is float:
				_checkpoint_indices.append(int(checkpoint_value))
	_checkpoint_sequence = _checkpoint_indices.duplicate()
	if not _checkpoint_sequence.has(0):
		_checkpoint_sequence.append(0)
	var settings_value: Variant = descriptor.get("settings", {})
	var settings: Dictionary = settings_value if settings_value is Dictionary else {}
	_lap_count = maxi(1, int(settings.get("lap_count", 3)))
	_track_width = float(settings.get("track_width", 3.6))
	_countdown_seconds = float(settings.get("countdown_seconds", 3.0))
	_countdown_remaining = _countdown_seconds
	_max_forward_speed = float(settings.get("max_forward_speed", 11.0))
	_max_reverse_speed = float(settings.get("max_reverse_speed", 4.0))
	_acceleration = float(settings.get("acceleration", 8.0))
	_brake_strength = float(settings.get("brake_strength", 14.0))
	_coast_deceleration = float(settings.get("coast_deceleration", 4.0))
	_steering_degrees_per_second = float(settings.get("steering_degrees_per_second", 105.0))
	_result_display_seconds = float(settings.get("result_display_seconds", 3.0))
	_best_record_path = String(settings.get("best_record_path", "user://primitive_park_records.cfg"))
	_best_time = KartRecordStore.load_best(_best_record_path)
	_state = STATE_DECORATIVE
	_reset_to_start()
	set_physics_process(true)

## Requests boarding at the circuit start gate.
func request_boarding(ride_id: StringName) -> bool:
	if ride_id != _ride_id or _state != STATE_DECORATIVE or _track_points.size() < 4:
		return false
	_state = STATE_BOARDING
	_emit_progress(true)
	station_ready.emit(_ride_id)
	return true

## Cancels a request before the countdown begins.
func cancel_boarding(ride_id: StringName) -> void:
	if ride_id == _ride_id and _state == STATE_BOARDING:
		_state = STATE_DECORATIVE
		_emit_progress(true)

## Starts the three-lap countdown after the player takes the driver's seat.
func begin_cycle(ride_id: StringName) -> bool:
	if ride_id != _ride_id or _state != STATE_BOARDING:
		return false
	_reset_to_start()
	_state = STATE_COUNTDOWN
	_countdown_remaining = _countdown_seconds
	_current_lap = 1
	_next_checkpoint_cursor = 0
	_elapsed = 0.0
	_result_elapsed = 0.0
	_last_result_time = 0.0
	_emit_progress(true)
	return true

## Ends a kart session when the rider presses E.
func abort_cycle(ride_id: StringName) -> bool:
	if ride_id != _ride_id or (_state != STATE_COUNTDOWN and _state != STATE_RACING and _state != STATE_FINISHED):
		return false
	_state = STATE_DECORATIVE
	_reset_to_start()
	_emit_progress(true)
	return true

## Returns the kart to the most recently validated checkpoint when R is pressed.
func reset_cycle(ride_id: StringName) -> bool:
	if ride_id != _ride_id or _state != STATE_RACING:
		return false
	_cart.position = _last_valid_position
	_cart.rotation.y = _last_valid_yaw
	_cart.velocity = Vector3.ZERO
	_speed = 0.0
	_emit_progress(true)
	return true

## Returns seat, exit, and control metadata for RideCoordinator and HUD.
func get_ride_descriptor(ride_id: StringName) -> Dictionary:
	if ride_id != _ride_id:
		return {}
	return {
		"seat_anchor": _seat_anchor,
		"exit_marker": _exit_marker,
		"display_name": _display_name,
		"manual_exit": true,
		"ride_kind": "go_kart"
	}

## Returns the current kart state for deterministic tests and diagnostics.
func get_ride_state(ride_id: StringName) -> StringName:
	return _state if ride_id == _ride_id else &"unknown"

## Returns the current race snapshot without mutating provider state.
func get_progress_snapshot() -> Dictionary:
	return _snapshot()

## Returns the best persisted time, or zero when no record exists.
func get_best_time() -> float:
	return _best_time

## Advances the kart with explicit inputs, which also makes headless tests deterministic.
func advance_drive(delta: float, throttle: float, brake: bool, steer: float) -> void:
	if delta <= 0.0 or not is_instance_valid(_cart):
		return
	_progress_elapsed += delta
	if _state == STATE_COUNTDOWN:
		var countdown_step: float = minf(delta, _countdown_remaining)
		_countdown_remaining -= countdown_step
		_emit_progress(false)
		if _countdown_remaining > 0.0:
			return
		_state = STATE_RACING
		_emit_progress(true)
		delta = maxf(delta - countdown_step, 0.0)
	if _state == STATE_RACING:
		_elapsed += delta
		var clamped_throttle: float = clampf(throttle, -1.0, 1.0)
		var target_speed: float = clamped_throttle * (_max_forward_speed if clamped_throttle >= 0.0 else _max_reverse_speed)
		var braking: bool = brake or (absf(clamped_throttle) < 0.01 and absf(_speed) > 0.01)
		var braking_rate: float = _brake_strength if brake else _coast_deceleration
		_speed = KartMath.approach_speed(_speed, target_speed, delta, _acceleration, braking_rate, _coast_deceleration)
		var steering_scale: float = KartMath.steering_factor(_speed, _max_forward_speed)
		if absf(steer) > 0.01:
			var direction_sign: float = -1.0 if _speed < 0.0 else 1.0
			_cart.rotation.y -= clampf(steer, -1.0, 1.0) * deg_to_rad(_steering_degrees_per_second) * steering_scale * direction_sign * delta
		var forward: Vector3 = -_cart.global_transform.basis.z
		_cart.velocity = forward * _speed
		_cart.velocity.y = 0.0
		_cart.move_and_slide()
		if _cart.get_slide_collision_count() > 0:
			_speed *= 0.35
		_check_checkpoint(forward)
		_emit_progress(false)
	elif _state == STATE_FINISHED:
		_result_elapsed += delta
		_emit_progress(false)
		if _result_elapsed >= _result_display_seconds:
			_state = STATE_DECORATIVE
			_reset_to_start()
			_emit_progress(true)
			cycle_completed.emit(_ride_id)

func _physics_process(delta: float) -> void:
	var throttle: float = Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	var brake: bool = Input.is_action_pressed(&"kart_brake")
	var steer: float = Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
	advance_drive(delta, throttle, brake, steer)

func _check_checkpoint(forward: Vector3) -> void:
	if _checkpoint_sequence.is_empty() or _next_checkpoint_cursor >= _checkpoint_sequence.size():
		return
	var checkpoint_index: int = _checkpoint_sequence[_next_checkpoint_cursor]
	if checkpoint_index < 0 or checkpoint_index >= _track_points.size():
		return
	var checkpoint_position: Vector3 = _track_points[checkpoint_index]
	var distance: float = Vector2(_cart.position.x, _cart.position.z).distance_to(Vector2(checkpoint_position.x, checkpoint_position.z))
	var next_point: Vector3 = _track_points[(checkpoint_index + 1) % _track_points.size()]
	var checkpoint_forward: Vector3 = (next_point - checkpoint_position).normalized()
	if not KartMath.valid_checkpoint_crossing(distance, _track_width * 0.9, forward.dot(checkpoint_forward)):
		return
	_last_valid_position = Vector3(checkpoint_position.x, _ground_height, checkpoint_position.z)
	_last_valid_yaw = atan2(-checkpoint_forward.x, -checkpoint_forward.z)
	_next_checkpoint_cursor += 1
	if _next_checkpoint_cursor < _checkpoint_sequence.size():
		return
	_next_checkpoint_cursor = 0
	if _current_lap >= _lap_count:
		_last_result_time = _elapsed
		if _best_time <= 0.0 or _elapsed < _best_time:
			if KartRecordStore.save_best(_best_record_path, _elapsed):
				_best_time = _elapsed
		_state = STATE_FINISHED
		_speed = 0.0
		_cart.velocity = Vector3.ZERO
		_result_elapsed = 0.0
		_emit_progress(true)
	else:
		_current_lap += 1
		_emit_progress(true)

func _reset_to_start() -> void:
	_speed = 0.0
	_elapsed = 0.0
	_result_elapsed = 0.0
	_current_lap = 1
	_next_checkpoint_cursor = 0
	if not is_instance_valid(_cart) or _track_points.is_empty():
		return
	_cart.position = Vector3(_track_points[0].x, _ground_height, _track_points[0].z)
	var tangent: Vector3 = (_track_points[1] - _track_points[0]).normalized()
	_cart.rotation.y = atan2(-tangent.x, -tangent.z)
	_cart.velocity = Vector3.ZERO
	_last_valid_position = _cart.position
	_last_valid_yaw = _cart.rotation.y

func _snapshot() -> Dictionary:
	return {
		"kind": "go_kart",
		"status": String(_state),
		"lap": _current_lap,
		"lap_count": _lap_count,
		"time_seconds": _elapsed,
		"best_seconds": _best_time,
		"countdown_seconds": maxf(_countdown_remaining, 0.0),
		"result_seconds": _last_result_time,
		"checkpoint": _next_checkpoint_cursor,
		"cart_position": _cart.position if is_instance_valid(_cart) else Vector3.ZERO,
		"last_checkpoint_position": _last_valid_position
	}

func _emit_progress(force: bool) -> void:
	if not force and _progress_elapsed < 0.1:
		return
	_progress_elapsed = 0.0
	progress_changed.emit(_ride_id, _snapshot())
