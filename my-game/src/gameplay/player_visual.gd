extends Node3D

const MovementMath = preload("res://src/core/movement_math.gd")

@onready var left_arm: Node3D = $LeftArmPivot
@onready var right_arm: Node3D = $RightArmPivot
@onready var left_leg: Node3D = $LeftLegPivot
@onready var right_leg: Node3D = $RightLegPivot

var _turn_speed: float = 0.0
var _walk_cycle_speed: float = 0.0
var _sprint_cycle_speed: float = 0.0
var _limb_swing_degrees: float = 0.0
var _jump_pose_degrees: float = 0.0
var _ride_arm_pose_degrees: float = 0.0
var _ride_leg_pose_degrees: float = 0.0
var _ride_seat_pivot_height: float = 0.84
var _pose_blend_speed: float = 0.0
var _animation_time: float = 0.0
var _ride_pose_active: bool = false
var _standing_position: Vector3 = Vector3.ZERO

## Configures facing and procedural animation values from the park data.
func configure(settings: Dictionary) -> void:
	_standing_position = position
	_turn_speed = float(settings.get("turn_speed", 0.0))
	_walk_cycle_speed = float(settings.get("walk_cycle_speed", 0.0))
	_sprint_cycle_speed = float(settings.get("sprint_cycle_speed", 0.0))
	_limb_swing_degrees = float(settings.get("limb_swing_degrees", 0.0))
	_jump_pose_degrees = float(settings.get("jump_pose_degrees", 0.0))
	_ride_arm_pose_degrees = float(settings.get("ride_arm_pose_degrees", 12.0))
	_ride_leg_pose_degrees = float(settings.get("ride_leg_pose_degrees", 58.0))
	_ride_seat_pivot_height = float(settings.get("ride_seat_pivot_height", 0.84))
	_pose_blend_speed = float(settings.get("pose_blend_speed", 0.0))

## Enables or disables the seated procedural pose used by attractions.
func set_ride_pose(active: bool) -> void:
	_ride_pose_active = active
	position = _standing_position + (Vector3.DOWN * _ride_seat_pivot_height if active else Vector3.ZERO)
	if active:
		rotation.y = 0.0

## Blends the visitor's limbs toward a stable seated pose while riding.
func update_ride_pose(delta: float) -> void:
	if not _ride_pose_active:
		return
	var arm_pose: float = deg_to_rad(_ride_arm_pose_degrees)
	var leg_pose: float = deg_to_rad(_ride_leg_pose_degrees)
	var blend_weight: float = clampf(_pose_blend_speed * delta, 0.0, 1.0)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -arm_pose, blend_weight)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, -arm_pose, blend_weight)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, leg_pose, blend_weight)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, leg_pose, blend_weight)

## Turns the model toward movement and updates its walk, run, or jump pose.
func update_motion(move_direction: Vector3, horizontal_speed: float, grounded: bool, sprinting: bool, delta: float) -> void:
	var flat_direction: Vector3 = move_direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.000001:
		var desired_yaw: float = MovementMath.target_yaw(flat_direction, rotation.y)
		rotation.y = rotate_toward(rotation.y, desired_yaw, _turn_speed * delta)

	var moving: bool = grounded and horizontal_speed > 0.05
	var target_left_arm: float = 0.0
	var target_right_arm: float = 0.0
	var target_left_leg: float = 0.0
	var target_right_leg: float = 0.0
	if moving:
		var cycle_speed: float = _sprint_cycle_speed if sprinting else _walk_cycle_speed
		_animation_time = fmod(_animation_time + delta * cycle_speed, TAU)
		var swing: float = sin(_animation_time) * deg_to_rad(_limb_swing_degrees)
		target_left_arm = swing
		target_right_arm = -swing
		target_left_leg = -swing
		target_right_leg = swing
	elif not grounded:
		var jump_pose: float = deg_to_rad(_jump_pose_degrees)
		target_left_arm = -jump_pose
		target_right_arm = -jump_pose
		target_left_leg = jump_pose
		target_right_leg = jump_pose

	var blend_weight: float = clampf(_pose_blend_speed * delta, 0.0, 1.0)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, target_left_arm, blend_weight)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, target_right_arm, blend_weight)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, target_left_leg, blend_weight)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, target_right_leg, blend_weight)
