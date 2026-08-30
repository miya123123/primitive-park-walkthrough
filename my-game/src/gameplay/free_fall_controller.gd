extends "res://src/gameplay/ride_provider.gd"

## フリーフォールタワーのハーネス、上昇、落下前の間、落下、制動を管理する。

const STATE_DECORATIVE: StringName = &"decorative"
const STATE_BOARDING: StringName = &"boarding"
const STATE_HARNESS: StringName = &"harness"
const STATE_ASCENDING: StringName = &"ascending"
const STATE_SUSPENSE: StringName = &"suspense"
const STATE_DROPPING: StringName = &"dropping"
const STATE_BRAKING: StringName = &"braking"
const STATE_SETTLING: StringName = &"settling"

var _ride_id: StringName = &"free_fall_tower"
var _display_name: String = "Free Fall Tower"
var _motion_root: Node3D
var _seat_anchor: Node3D
var _exit_marker: Node3D
var _lamps: Array[Node3D] = []
var _state: StringName = STATE_DECORATIVE
var _elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _suspense_duration: float = 3.0
var _drop_velocity: float = 0.0
var _brake_start_height: float = 0.0
var _base_height: float = 0.0
var _top_height: float = 20.0
var _harness_seconds: float = 0.75
var _ascent_speed: float = 5.0
var _suspense_min_seconds: float = 2.5
var _suspense_max_seconds: float = 4.5
var _drop_acceleration: float = 28.0
var _drop_max_speed: float = 22.0
var _brake_height: float = 7.5
var _brake_seconds: float = 0.7
var _settle_seconds: float = 0.8
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _progress_elapsed: float = 0.0

## Builds a configured provider from the generated tower descriptor.
func configure(descriptor: Dictionary) -> void:
	_ride_id = StringName(String(descriptor.get("ride_id", "free_fall_tower")))
	_display_name = String(descriptor.get("display_name", "Free Fall Tower"))
	_motion_root = descriptor.get("motion_root") as Node3D
	_seat_anchor = descriptor.get("seat_anchor") as Node3D
	_exit_marker = descriptor.get("exit_marker") as Node3D
	_lamps.clear()
	var lamps_value: Variant = descriptor.get("lamps", [])
	if lamps_value is Array:
		for lamp_value: Variant in lamps_value:
			var lamp: Node3D = lamp_value as Node3D
			if lamp != null:
				_lamps.append(lamp)
	var settings_value: Variant = descriptor.get("settings", {})
	var settings: Dictionary = settings_value if settings_value is Dictionary else {}
	_base_height = _motion_root.position.y if is_instance_valid(_motion_root) else 0.0
	_top_height = _base_height + float(settings.get("drop_distance", 20.0))
	_harness_seconds = float(settings.get("harness_seconds", 0.75))
	_ascent_speed = float(settings.get("ascent_speed", 5.0))
	_suspense_min_seconds = float(settings.get("suspense_min_seconds", 2.5))
	_suspense_max_seconds = float(settings.get("suspense_max_seconds", 4.5))
	_drop_acceleration = float(settings.get("drop_acceleration", 28.0))
	_drop_max_speed = float(settings.get("drop_max_speed", 22.0))
	_brake_height = float(settings.get("brake_height", 7.5))
	_brake_seconds = float(settings.get("brake_seconds", 0.7))
	_settle_seconds = float(settings.get("settle_seconds", 0.8))
	_state = STATE_DECORATIVE
	_phase_elapsed = 0.0
	_progress_elapsed = 0.0
	_rng.randomize()
	set_process(true)

## Sets a deterministic random seed for suspense timing tests.
func set_random_seed(seed: int) -> void:
	_rng.seed = seed

## Requests boarding at the stationary tower platform.
func request_boarding(ride_id: StringName) -> bool:
	if ride_id != _ride_id or _state != STATE_DECORATIVE:
		return false
	_state = STATE_BOARDING
	_phase_elapsed = 0.0
	_emit_progress(true)
	station_ready.emit(_ride_id)
	return true

## Cancels a boarding request before the harness closes.
func cancel_boarding(ride_id: StringName) -> void:
	if ride_id == _ride_id and _state == STATE_BOARDING:
		_state = STATE_DECORATIVE
		_emit_progress(true)

## Starts the tower sequence after the player has taken the seat.
func begin_cycle(ride_id: StringName) -> bool:
	if ride_id != _ride_id or _state != STATE_BOARDING or not is_instance_valid(_motion_root):
		return false
	_motion_root.position.y = _base_height
	_state = STATE_HARNESS
	_phase_elapsed = 0.0
	_drop_velocity = 0.0
	_suspense_duration = _rng.randf_range(_suspense_min_seconds, _suspense_max_seconds)
	_emit_progress(true)
	return true

## Free-fall sequences are not manually abortable once the harness closes.
func abort_cycle(_ride_id: StringName) -> bool:
	return false

## A free-fall sequence has no manual reset input.
func reset_cycle(_ride_id: StringName) -> bool:
	return false

## Returns seat, exit, and presentation metadata for RideCoordinator.
func get_ride_descriptor(ride_id: StringName) -> Dictionary:
	if ride_id != _ride_id:
		return {}
	return {
		"seat_anchor": _seat_anchor,
		"exit_marker": _exit_marker,
		"display_name": _display_name,
		"manual_exit": false,
		"ride_kind": "free_fall"
	}

## Returns the current free-fall stage for deterministic tests and HUD copy.
func get_ride_state(ride_id: StringName) -> StringName:
	return _state if ride_id == _ride_id else &"unknown"

## Returns the configured random suspense duration for the active cycle.
func get_suspense_duration() -> float:
	return _suspense_duration

## Advances the sequence without relying on a wall-clock timer.
func advance_simulation(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(_motion_root):
		return
	_elapsed += delta
	_phase_elapsed += delta
	match _state:
		STATE_HARNESS:
			if _phase_elapsed >= _harness_seconds:
				_state = STATE_ASCENDING
				_phase_elapsed = 0.0
		STATE_ASCENDING:
			_motion_root.position.y = move_toward(_motion_root.position.y, _top_height, _ascent_speed * delta)
			if is_equal_approx(_motion_root.position.y, _top_height):
				_state = STATE_SUSPENSE
				_phase_elapsed = 0.0
				_suspense_duration = _rng.randf_range(_suspense_min_seconds, _suspense_max_seconds)
		STATE_SUSPENSE:
			if _phase_elapsed >= _suspense_duration:
				_state = STATE_DROPPING
				_phase_elapsed = 0.0
				_drop_velocity = 0.0
		STATE_DROPPING:
			_drop_velocity = minf(_drop_velocity + _drop_acceleration * delta, _drop_max_speed)
			_motion_root.position.y = maxf(_base_height + _brake_height, _motion_root.position.y - _drop_velocity * delta)
			if _motion_root.position.y <= _base_height + _brake_height + 0.001:
				_state = STATE_BRAKING
				_phase_elapsed = 0.0
				_brake_start_height = _motion_root.position.y
		STATE_BRAKING:
			var brake_ratio: float = clampf(_phase_elapsed / maxf(_brake_seconds, 0.001), 0.0, 1.0)
			_motion_root.position.y = lerpf(_brake_start_height, _base_height, ease(brake_ratio, 0.7))
			if brake_ratio >= 1.0:
				_state = STATE_SETTLING
				_phase_elapsed = 0.0
		STATE_SETTLING:
			_motion_root.position.y = _base_height
			if _phase_elapsed >= _settle_seconds:
				_state = STATE_DECORATIVE
				_phase_elapsed = 0.0
				_emit_progress(true)
				cycle_completed.emit(_ride_id)
	_update_lamps()
	_progress_elapsed += delta
	_emit_progress(false)

func _process(delta: float) -> void:
	advance_simulation(delta)

func _update_lamps() -> void:
	var suspense_active: bool = _state == STATE_SUSPENSE
	var pulse_on: bool = fmod(_phase_elapsed, 0.46) < 0.23
	for lamp: Node3D in _lamps:
		if is_instance_valid(lamp):
			lamp.visible = not suspense_active or pulse_on

func _emit_progress(force: bool) -> void:
	if not force and _progress_elapsed < 0.1:
		_progress_elapsed += 0.0
		return
	_progress_elapsed = 0.0
	progress_changed.emit(_ride_id, {
		"kind": "free_fall",
		"status": String(_state),
		"stage": String(_state),
		"suspense_seconds": _suspense_duration,
		"suspense_elapsed": _phase_elapsed if _state == STATE_SUSPENSE else 0.0
	})
