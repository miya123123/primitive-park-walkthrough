extends CharacterBody3D

const MovementMath = preload("res://src/core/movement_math.gd")

## Emitted when the player enters a landmark and the HUD should update.
signal location_changed(display_name: String)
## Emitted when the player presses the ride interaction key.
signal interact_requested
## Emitted when the player requests an exit from a manually driven ride.
signal ride_exit_requested
## Emitted when the player requests a ride reset from a checkpoint.
signal ride_reset_requested
## Emitted when a ride lease starts or ends.
signal ride_state_changed(riding: bool, ride_id: StringName)

@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var visual_root: Node3D = $VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _walk_speed: float = 0.0
var _sprint_multiplier: float = 0.0
var _jump_velocity: float = 0.0
var _gravity: float = 0.0
var _mouse_sensitivity: float = 0.0
var _min_pitch_degrees: float = 0.0
var _max_pitch_degrees: float = 0.0
var _camera_pivot_height: float = 0.0
var _camera_distance: float = 0.0
var _camera_collision_radius: float = 0.0
var _camera_collision_margin: float = 0.0
var _ride_ground_height_limit: float = 1.5
var _pitch: float = 0.0
var _configured: bool = false
var _is_riding: bool = false
var _ride_id: StringName = &""
var _ride_anchor: Node3D
var _ride_exit_marker: Node3D

## Configures movement, orbit camera, and model presentation from park data.
func configure(settings: Dictionary) -> void:
	_walk_speed = float(settings.get("walk_speed", 0.0))
	_sprint_multiplier = float(settings.get("sprint_multiplier", 0.0))
	_jump_velocity = float(settings.get("jump_velocity", 0.0))
	_gravity = float(settings.get("gravity", 0.0))
	_mouse_sensitivity = float(settings.get("mouse_sensitivity", 0.0))
	_min_pitch_degrees = float(settings.get("camera_min_pitch_degrees", 0.0))
	_max_pitch_degrees = float(settings.get("camera_max_pitch_degrees", 0.0))
	_camera_pivot_height = float(settings.get("camera_pivot_height", 0.0))
	_camera_distance = float(settings.get("camera_distance", 0.0))
	_camera_collision_radius = float(settings.get("camera_collision_radius", 0.0))
	_camera_collision_margin = float(settings.get("camera_collision_margin", 0.0))
	_ride_ground_height_limit = float(settings.get("ride_ground_height_limit", 1.5))
	_pitch = deg_to_rad(float(settings.get("camera_default_pitch_degrees", 0.0)))
	camera_yaw.position.y = _camera_pivot_height
	camera_pitch.rotation.x = _pitch
	spring_arm.spring_length = _camera_distance
	spring_arm.margin = _camera_collision_margin
	var camera_shape: SphereShape3D = spring_arm.shape as SphereShape3D
	if camera_shape != null:
		camera_shape.radius = _camera_collision_radius
	camera.fov = float(settings.get("field_of_view", 75.0))
	visual_root.call("configure", settings)
	_configured = true

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		apply_camera_motion(motion.relative)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if _is_riding:
				ride_exit_requested.emit()
			else:
				interact_requested.emit()
		elif event.keycode == KEY_R and _is_riding:
			ride_reset_requested.emit()

## Returns whether the player can accept a new ride lease.
func can_start_ride() -> bool:
	var grounded_enough: bool = is_on_floor() or global_position.y <= _ride_ground_height_limit
	return _configured and not _is_riding and grounded_enough

## Returns whether the player is currently attached to an attraction.
func is_riding() -> bool:
	return _is_riding

## Returns the current ride identifier, or an empty name while walking.
func get_ride_id() -> StringName:
	return _ride_id

## Attaches the player to a generated seat and disables walking collisions.
func begin_ride(ride_id: StringName, seat_anchor: Node3D, exit_marker: Node3D) -> bool:
	if not can_start_ride() or not is_instance_valid(seat_anchor) or not is_instance_valid(exit_marker):
		return false
	_is_riding = true
	_ride_id = ride_id
	_ride_anchor = seat_anchor
	_ride_exit_marker = exit_marker
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	_sync_to_ride_anchor()
	visual_root.call("set_ride_pose", true)
	ride_state_changed.emit(true, ride_id)
	return true

## Places the player at the safe exit marker and restores normal movement.
func finish_ride(exit_marker: Node3D) -> void:
	if not _is_riding:
		return
	if is_instance_valid(exit_marker):
		global_position = exit_marker.global_position
		rotation.y = exit_marker.global_rotation.y
	_is_riding = false
	_ride_id = &""
	_ride_anchor = null
	_ride_exit_marker = null
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", false)
	visual_root.call("set_ride_pose", false)
	ride_state_changed.emit(false, &"")

## Applies a captured mouse delta to the third-person orbit camera.
func apply_camera_motion(relative: Vector2) -> void:
	camera_yaw.rotate_y(-relative.x * _mouse_sensitivity)
	_pitch = MovementMath.clamped_orbit_pitch(
		_pitch,
		relative.y,
		_mouse_sensitivity,
		_min_pitch_degrees,
		_max_pitch_degrees
	)
	camera_pitch.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	if not _configured:
		return
	if _is_riding:
		_sync_to_ride_anchor()
		visual_root.call("update_ride_pose", delta)
		return
	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var speed: float = _walk_speed
	var sprinting: bool = Input.is_action_pressed(&"sprint") and input_direction.length_squared() > 0.0
	if sprinting:
		speed *= _sprint_multiplier
	var horizontal: Vector3 = MovementMath.horizontal_velocity(input_direction, camera_yaw.global_transform.basis, speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = MovementMath.next_vertical_velocity(
		velocity.y,
		delta,
		_gravity,
		is_on_floor(),
		Input.is_action_just_pressed(&"jump"),
		_jump_velocity
	)
	move_and_slide()
	var move_direction: Vector3 = horizontal
	if move_direction.length_squared() > 0.000001:
		move_direction = move_direction.normalized()
	visual_root.call("update_motion", move_direction, horizontal.length(), is_on_floor(), sprinting, delta)

func _sync_to_ride_anchor() -> void:
	if not is_instance_valid(_ride_anchor):
		finish_ride(_ride_exit_marker)
		return
	global_position = _ride_anchor.global_position
	rotation.y = _ride_anchor.global_rotation.y
