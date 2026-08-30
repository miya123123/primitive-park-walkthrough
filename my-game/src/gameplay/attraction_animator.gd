extends "res://src/gameplay/ride_provider.gd"

const RideMath = preload("res://src/core/ride_math.gd")

## Advances decorative attractions and synchronizes one-cycle ride requests.

signal animation_advanced(elapsed_seconds: float)
const STATE_DECORATIVE: StringName = &"decorative"
const STATE_WAITING: StringName = &"waiting"
const STATE_BOARDING: StringName = &"boarding"
const STATE_RIDING: StringName = &"riding"

var _rides: Dictionary = {}
var _ride_ids: Array[StringName] = []
var _track_points: PackedVector3Array = PackedVector3Array()
var _track_length: float = 0.0
var _elapsed_seconds: float = 0.0
var _station_tolerance: float = 0.25

## Supplies generated attraction nodes, seat descriptors, and configured speeds.
func configure(ferris_wheel: Node3D, carousel: Node3D, coaster_cart: Node3D, track_points: PackedVector3Array, speeds: Dictionary, ride_descriptors: Dictionary = {}) -> void:
	_track_points = track_points
	_track_length = _calculate_track_length()
	_station_tolerance = float(ride_descriptors.get("station_tolerance", 0.25))
	_rides.clear()
	_ride_ids = [&"ferris_wheel", &"carousel", &"roller_coaster"]
	_register_ride(&"ferris_wheel", ferris_wheel, float(speeds.get("ferris_wheel", 0.0)), &"angle", ride_descriptors.get("ferris_wheel", {}))
	_register_ride(&"carousel", carousel, float(speeds.get("carousel", 0.0)), &"angle", ride_descriptors.get("carousel", {}))
	_register_ride(&"roller_coaster", coaster_cart, float(speeds.get("roller_coaster", 0.0)), &"track", ride_descriptors.get("roller_coaster", {}))
	set_process(true)

## Advances every attraction by delta seconds.
func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	_elapsed_seconds += delta
	for ride_id: StringName in _ride_ids:
		_advance_ride(ride_id, delta)
	animation_advanced.emit(_elapsed_seconds)

## Returns the accumulated animation time for diagnostics and compatibility.
func get_elapsed_seconds() -> float:
	return _elapsed_seconds

## Requests the next arrival at a ride's station.
func request_boarding(ride_id: StringName) -> bool:
	if not _rides.has(ride_id):
		return false
	var ride: Dictionary = _rides[ride_id]
	if ride["state"] != STATE_DECORATIVE:
		return false
	if RideMath.is_at_station(float(ride["phase"]), float(ride["period"]), _station_tolerance):
		ride["phase"] = 0.0
		ride["state"] = STATE_BOARDING
		_apply_ride(ride)
		station_ready.emit(ride_id)
	else:
		ride["state"] = STATE_WAITING
	return true

## Cancels a waiting request and returns the attraction to decorative motion.
func cancel_boarding(ride_id: StringName) -> void:
	if not _rides.has(ride_id):
		return
	var ride: Dictionary = _rides[ride_id]
	if ride["state"] == STATE_WAITING or ride["state"] == STATE_BOARDING:
		ride["state"] = STATE_DECORATIVE

## Aborts a ride lease and returns its vehicle to normal decorative motion.
func stop_ride(ride_id: StringName) -> void:
	if not _rides.has(ride_id):
		return
	var ride: Dictionary = _rides[ride_id]
	if ride["state"] == STATE_DECORATIVE:
		return
	ride["state"] = STATE_DECORATIVE
	ride["phase"] = 0.0
	_apply_ride(ride)

## Implements the provider contract for the automatic attractions.
func abort_cycle(ride_id: StringName) -> bool:
	if not _rides.has(ride_id):
		return false
	var was_active: bool = _rides[ride_id]["state"] != STATE_DECORATIVE
	stop_ride(ride_id)
	return was_active

## Automatic attractions do not support a manual reset.
func reset_cycle(_ride_id: StringName) -> bool:
	return false

## Starts exactly one motion cycle from the station.
func begin_cycle(ride_id: StringName) -> bool:
	if not _rides.has(ride_id):
		return false
	var ride: Dictionary = _rides[ride_id]
	if ride["state"] != STATE_BOARDING:
		return false
	ride["phase"] = 0.0
	ride["state"] = STATE_RIDING
	_apply_ride(ride)
	return true

## Returns the generated seat and exit references for a ride.
func get_ride_descriptor(ride_id: StringName) -> Dictionary:
	if not _rides.has(ride_id):
		return {}
	var ride: Dictionary = _rides[ride_id]
	return {
		"seat_anchor": ride["seat_anchor"],
		"exit_marker": ride["exit_marker"],
		"display_name": ride["display_name"],
		"manual_exit": false,
		"ride_kind": "automatic"
	}

## Returns the current internal ride state for deterministic tests.
func get_ride_state(ride_id: StringName) -> StringName:
	if not _rides.has(ride_id):
		return &"unknown"
	return _rides[ride_id]["state"]

## Returns a ride's current normalized phase in meters or radians.
func get_ride_phase(ride_id: StringName) -> float:
	if not _rides.has(ride_id):
		return 0.0
	return float(_rides[ride_id]["phase"])

func _process(delta: float) -> void:
	advance_time(delta)

func _register_ride(ride_id: StringName, motion_root: Node3D, speed: float, motion_type: StringName, descriptor_value: Variant) -> void:
	var descriptor: Dictionary = descriptor_value if descriptor_value is Dictionary else {}
	var period: float = _track_length if motion_type == &"track" else TAU
	var ride: Dictionary = {
		"motion_root": motion_root,
		"speed": maxf(speed, 0.0),
		"motion_type": motion_type,
		"period": period,
		"phase": 0.0,
		"state": STATE_DECORATIVE,
		"seat_anchor": descriptor.get("seat_anchor"),
		"exit_marker": descriptor.get("exit_marker"),
		"display_name": String(descriptor.get("display_name", ride_id)),
		"upright_nodes": descriptor.get("upright_nodes", [])
	}
	_rides[ride_id] = ride
	_apply_ride(ride)

func _advance_ride(ride_id: StringName, delta: float) -> void:
	var ride: Dictionary = _rides.get(ride_id, {})
	if ride.is_empty() or ride["state"] == STATE_BOARDING:
		return
	var previous_phase: float = float(ride["phase"])
	var next_phase: float = RideMath.advance_loop(previous_phase, delta, float(ride["speed"]), float(ride["period"]))
	ride["phase"] = next_phase
	var period: float = float(ride["period"])
	var speed: float = float(ride["speed"])
	var crossed_station: bool = RideMath.crossed_station_by_delta(previous_phase, delta, speed, period)
	if ride["state"] == STATE_WAITING and crossed_station:
		ride["phase"] = 0.0
		ride["state"] = STATE_BOARDING
		_apply_ride(ride)
		station_ready.emit(ride_id)
		return
	if ride["state"] == STATE_RIDING and crossed_station:
		ride["phase"] = 0.0
		ride["state"] = STATE_DECORATIVE
		_apply_ride(ride)
		cycle_completed.emit(ride_id)
		return
	_apply_ride(ride)

func _apply_ride(ride: Dictionary) -> void:
	var motion_root: Node3D = ride["motion_root"] as Node3D
	if not is_instance_valid(motion_root):
		return
	var phase: float = float(ride["phase"])
	if ride["motion_type"] == &"angle":
		if motion_root.name == &"FerrisWheelSpin":
			motion_root.rotation.z = phase
		else:
			motion_root.rotation.y = phase
		for upright_value: Variant in ride["upright_nodes"]:
			var upright_node: Node3D = upright_value as Node3D
			if is_instance_valid(upright_node):
				upright_node.rotation.z = -phase
	else:
		motion_root.position = _sample_track(phase)
		var tangent: Vector3 = _sample_track_tangent(phase)
		motion_root.rotation.y = atan2(-tangent.x, -tangent.z)

func _calculate_track_length() -> float:
	if _track_points.size() < 2:
		return 0.0
	var length: float = 0.0
	for index: int in range(_track_points.size()):
		var next_index: int = (index + 1) % _track_points.size()
		length += _track_points[index].distance_to(_track_points[next_index])
	return length

func _sample_track(distance: float) -> Vector3:
	if _track_points.size() < 2:
		return Vector3.ZERO
	var remaining: float = clampf(distance, 0.0, _track_length)
	for index: int in range(_track_points.size()):
		var next_index: int = (index + 1) % _track_points.size()
		var start: Vector3 = _track_points[index]
		var end: Vector3 = _track_points[next_index]
		var segment_length: float = start.distance_to(end)
		if remaining <= segment_length:
			return start.lerp(end, remaining / maxf(segment_length, 0.0001))
		remaining -= segment_length
	return _track_points[0]

func _sample_track_tangent(distance: float) -> Vector3:
	return RideMath.closed_track_tangent(_track_points, distance)
