extends Node

## Coordinates player input, ride providers, and the single-player ride lease.
##
## State flow: AVAILABLE -> WAITING -> RIDING -> AVAILABLE. Providers own their
## vehicle-specific state while this node owns interaction and player attachment.

signal ride_prompt_changed(state: StringName, display_name: String)
signal ride_started(ride_id: StringName, display_name: String)
signal ride_finished(ride_id: StringName, display_name: String)
signal ride_progress_changed(ride_id: StringName, snapshot: Dictionary)

const STATE_AVAILABLE: StringName = &"available"
const STATE_WAITING: StringName = &"waiting"
const STATE_RIDING: StringName = &"riding"

var _player: Node
var _animator: Node
var _rides: Dictionary = {}
var _providers: Dictionary = {}
var _current_zone: StringName = &""
var _active_ride: StringName = &""
var _pending_ride: StringName = &""

## Connects the single player and optionally keeps the legacy animator fallback.
func configure(player: Node, animator: Node = null) -> void:
	_player = player
	_animator = animator
	if _player != null:
		_connect_player_signal(&"interact_requested", Callable(self, "_on_player_interact"))
		_connect_player_signal(&"ride_exit_requested", Callable(self, "_on_player_exit_requested"))
		_connect_player_signal(&"ride_reset_requested", Callable(self, "_on_player_reset_requested"))
		_connect_player_signal(&"ride_state_changed", Callable(self, "_on_player_ride_state_changed"))
	if _animator != null:
		_register_provider(_animator)

## Registers a generated ride and its type-specific provider.
func register_ride(ride_id: StringName, display_name: String, boarding_zone: Area3D, provider: Node = null) -> void:
	if boarding_zone == null:
		return
	var resolved_provider: Node = provider if provider != null else _animator
	_rides[ride_id] = {"display_name": display_name, "boarding_zone": boarding_zone, "state": STATE_AVAILABLE}
	if resolved_provider != null:
		_providers[ride_id] = resolved_provider
		_register_provider(resolved_provider)
	boarding_zone.body_entered.connect(_on_ride_body_entered.bind(ride_id))
	boarding_zone.body_exited.connect(_on_ride_body_exited.bind(ride_id))

## Returns the current ride lease state for tests and diagnostics.
func get_state() -> StringName:
	if not _active_ride.is_empty():
		return STATE_RIDING
	if not _pending_ride.is_empty():
		return STATE_WAITING
	return STATE_AVAILABLE

## Returns the currently selected attraction, or an empty name.
func get_current_ride_id() -> StringName:
	return _active_ride if not _active_ride.is_empty() else _pending_ride

func _connect_player_signal(signal_name: StringName, callback: Callable) -> void:
	if _player.has_signal(signal_name) and not _player.is_connected(signal_name, callback):
		_player.connect(signal_name, callback)

func _register_provider(provider: Node) -> void:
	if provider == null:
		return
	if provider.has_meta("ride_coordinator_connected") and int(provider.get_meta("ride_coordinator_connected")) == get_instance_id():
		return
	if provider.has_signal(&"station_ready"):
		provider.connect(&"station_ready", Callable(self, "_on_station_ready"))
	if provider.has_signal(&"cycle_completed"):
		provider.connect(&"cycle_completed", Callable(self, "_on_cycle_completed"))
	if provider.has_signal(&"progress_changed"):
		provider.connect(&"progress_changed", Callable(self, "_on_provider_progress_changed"))
	provider.set_meta("ride_coordinator_connected", get_instance_id())

func _on_ride_body_entered(body: Node3D, ride_id: StringName) -> void:
	if body != _player:
		return
	var ride_zone: Dictionary = _rides.get(ride_id, {})
	var boarding_zone: Area3D = ride_zone.get("boarding_zone") as Area3D
	if boarding_zone != null and _player.global_position.distance_to(boarding_zone.global_position) > float(boarding_zone.get_meta("boarding_radius", 3.0)) + 2.0:
		return
	_current_zone = ride_id
	var ride: Dictionary = _rides.get(ride_id, {})
	var display_name: String = String(ride.get("display_name", ride_id))
	if _active_ride.is_empty() and _pending_ride.is_empty():
		ride_prompt_changed.emit(STATE_AVAILABLE, display_name)

func _on_ride_body_exited(body: Node3D, ride_id: StringName) -> void:
	if body != _player:
		return
	if _current_zone == ride_id:
		_current_zone = &""
	if _pending_ride == ride_id:
		var provider: Node = _provider_for(ride_id)
		if provider != null:
			provider.call("cancel_boarding", ride_id)
		_pending_ride = &""
		ride_prompt_changed.emit(STATE_AVAILABLE, "")
	elif _active_ride.is_empty():
		ride_prompt_changed.emit(STATE_AVAILABLE, "")

func _on_player_interact() -> void:
	if _player == null or not _active_ride.is_empty() or _current_zone.is_empty():
		return
	if not _player.call("can_start_ride"):
		return
	var ride: Dictionary = _rides.get(_current_zone, {})
	var provider: Node = _provider_for(_current_zone)
	if ride.is_empty() or provider == null:
		return
	_pending_ride = _current_zone
	if not provider.call("request_boarding", _current_zone):
		_pending_ride = &""
		return
	if _pending_ride == _current_zone:
		ride_prompt_changed.emit(STATE_WAITING, String(ride.get("display_name", _current_zone)))

func _on_station_ready(ride_id: StringName) -> void:
	var provider: Node = _provider_for(ride_id)
	if provider == null:
		return
	if _pending_ride != ride_id or _player == null:
		provider.call("cancel_boarding", ride_id)
		return
	if _current_zone != ride_id or not _player.call("can_start_ride"):
		provider.call("cancel_boarding", ride_id)
		_pending_ride = &""
		return
	var ride: Dictionary = _rides.get(ride_id, {})
	var display_name: String = String(ride.get("display_name", ride_id))
	var descriptor: Dictionary = provider.call("get_ride_descriptor", ride_id)
	if not _player.call("begin_ride", ride_id, descriptor.get("seat_anchor"), descriptor.get("exit_marker")):
		provider.call("cancel_boarding", ride_id)
		_pending_ride = &""
		return
	if not provider.call("begin_cycle", ride_id):
		_player.call("finish_ride", descriptor.get("exit_marker"))
		_pending_ride = &""
		return
	_active_ride = ride_id
	_pending_ride = &""
	ride_started.emit(ride_id, display_name)
	ride_prompt_changed.emit(STATE_RIDING, display_name)

func _on_cycle_completed(ride_id: StringName) -> void:
	if _active_ride != ride_id or _player == null:
		return
	_finish_active_ride(ride_id)

func _on_provider_progress_changed(ride_id: StringName, snapshot: Dictionary) -> void:
	ride_progress_changed.emit(ride_id, snapshot)

func _on_player_exit_requested() -> void:
	if _active_ride.is_empty():
		return
	var ride_id: StringName = _active_ride
	var provider: Node = _provider_for(ride_id)
	if provider == null or not provider.call("abort_cycle", ride_id):
		return
	_finish_active_ride(ride_id)

func _on_player_reset_requested() -> void:
	if _active_ride.is_empty():
		return
	var provider: Node = _provider_for(_active_ride)
	if provider != null:
		provider.call("reset_cycle", _active_ride)

func _on_player_ride_state_changed(riding: bool, _ride_id: StringName) -> void:
	if riding or _active_ride.is_empty():
		return
	var ride_id: StringName = _active_ride
	var provider: Node = _provider_for(ride_id)
	if provider == null:
		return
	var provider_state: StringName = provider.call("get_ride_state", ride_id)
	if provider_state == &"decorative":
		return
	provider.call("abort_cycle", ride_id)
	_finish_active_ride(ride_id)

func _finish_active_ride(ride_id: StringName) -> void:
	if _active_ride != ride_id or _player == null:
		return
	var ride: Dictionary = _rides.get(ride_id, {})
	var display_name: String = String(ride.get("display_name", ride_id))
	var provider: Node = _provider_for(ride_id)
	var descriptor: Dictionary = provider.call("get_ride_descriptor", ride_id) if provider != null else {}
	_player.call("finish_ride", descriptor.get("exit_marker"))
	_active_ride = &""
	ride_finished.emit(ride_id, display_name)
	ride_prompt_changed.emit(STATE_AVAILABLE, display_name if _current_zone == ride_id else "")

func _provider_for(ride_id: StringName) -> Node:
	return _providers.get(ride_id) as Node
