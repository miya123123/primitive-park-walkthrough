extends RefCounted

const CONFIG_PATH: String = "res://assets/data/park_config.json"
const ParkConfig = preload("res://src/core/park_config.gd")
const MovementMath = preload("res://src/core/movement_math.gd")
const RideMath = preload("res://src/core/ride_math.gd")
const KartMath = preload("res://src/core/kart_math.gd")
const KartRecordStore = preload("res://src/core/kart_record_store.gd")
const PrimitiveFactory = preload("res://src/core/primitive_factory.gd")
const MainScene = preload("res://scenes/Main.tscn")

var _assertion_count: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _last_landmark_name: String = ""
var _last_ride_prompt_state: StringName = &""
var _last_ride_prompt_name: String = ""

## Runs pure ride phase and track assertions.
func run_ride_tests() -> void:
	_assert(is_equal_approx(RideMath.advance_loop(0.0, 2.0, 0.5, TAU), 1.0), "ride phase should advance by speed and delta")
	_assert(is_equal_approx(RideMath.advance_loop(TAU - 0.1, 1.0, 0.5, TAU), 0.4), "ride phase should wrap at the period")
	_assert(RideMath.is_at_station(0.0, TAU, 0.25), "zero phase should be at the station")
	_assert(RideMath.is_at_station(TAU - 0.1, TAU, 0.25), "phase near wrap should be at the station")
	_assert(RideMath.crossed_station(TAU - 0.1, 0.1, TAU), "wrapped phase should cross the station")
	_assert(RideMath.crossed_station_by_delta(TAU - 0.1, 40.0, 0.5, TAU), "large steps should detect a station crossing")
	var track: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -4.0), Vector3(4.0, 0.0, -4.0)])
	var tangent: Vector3 = RideMath.closed_track_tangent(track, 1.0)
	_assert(tangent.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "track tangent should follow the current segment")
	_assert(is_equal_approx(KartMath.approach_speed(0.0, 10.0, 0.5, 8.0, 14.0, 4.0), 4.0), "kart acceleration should be arcade-friendly")
	_assert(is_equal_approx(KartMath.steering_factor(0.0, 11.0), 0.2), "kart should remain steerable at rest")
	_assert(KartMath.format_time(65.432) == "01:05.43", "kart timer should use centiseconds")
	_assert(KartMath.valid_checkpoint_crossing(1.0, 2.0, 0.8), "forward checkpoint crossing should be accepted")
	_assert(not KartMath.valid_checkpoint_crossing(1.0, 2.0, -0.2), "reverse checkpoint crossing should be rejected")
	var kart_points: Array = [
		Vector3(-10.0, 0.0, 6.0),
		Vector3(-11.0, 0.0, -3.0),
		Vector3(-7.0, 0.0, -8.0),
		Vector3(3.0, 0.0, -9.0),
		Vector3(11.0, 0.0, -5.0),
		Vector3(11.0, 0.0, 2.0),
		Vector3(7.0, 0.0, 8.0),
		Vector3(1.0, 0.0, 7.0),
		Vector3(-2.0, 0.0, 3.0),
		Vector3(-5.0, 0.0, 7.0)
	]
	var kart_boundaries: Dictionary = KartMath.closed_track_boundaries(kart_points, 3.6)
	var left_boundary: Array = kart_boundaries.get("left", [])
	var right_boundary: Array = kart_boundaries.get("right", [])
	_assert(left_boundary.size() == kart_points.size() and right_boundary.size() == kart_points.size(), "kart rails should share one boundary vertex per track point")
	for boundary_index: int in range(kart_points.size()):
		var boundary_next: int = (boundary_index + 1) % kart_points.size()
		_assert(left_boundary[boundary_index].distance_to(left_boundary[boundary_next]) > 0.1, "left kart rail segments should remain connected")
		_assert(right_boundary[boundary_index].distance_to(right_boundary[boundary_next]) > 0.1, "right kart rail segments should remain connected")
		_assert(left_boundary[boundary_index].distance_to(right_boundary[boundary_index]) > 1.0, "kart rail pair should leave a drivable lane")
	var record_path: String = "/private/tmp/primitive_park_kart_record_test_%d.cfg" % Time.get_ticks_usec()
	_assert(KartRecordStore.save_best(record_path, 42.5), "kart best time should be saved")
	_assert(is_equal_approx(KartRecordStore.load_best(record_path), 42.5), "kart best time should be loaded")
	_assert(not KartRecordStore.save_best(record_path, 50.0), "slower kart time should not replace the best")

## Runs configuration validation assertions.
func run_config_tests() -> void:
	var config: Dictionary = ParkConfig.load_from_file(CONFIG_PATH)
	_assert(ParkConfig.validate(config).is_empty(), "park config should validate")
	_assert(is_equal_approx(float(config["world_size"]), 72.0), "world size should be 72m")
	var landmarks: Array = config["landmarks"]
	_assert(landmarks.size() == 5, "five landmarks should be configured")
	var ids: Dictionary = {}
	for raw_landmark: Variant in landmarks:
		var landmark: Dictionary = raw_landmark
		ids[String(landmark["id"])] = true
	_assert(ids.has("ferris_wheel"), "ferris wheel should exist")
	_assert(ids.has("roller_coaster"), "roller coaster should exist")
	_assert(ids.has("carousel"), "carousel should exist")
	_assert(ids.has("free_fall_tower"), "free fall tower should exist")
	_assert(ids.has("go_kart"), "go-kart circuit should exist")
	var player_config: Dictionary = config["player"]
	_assert(is_equal_approx(float(player_config["camera_distance"]), 4.5), "third-person camera distance should be configured")
	_assert(float(player_config["ride_leg_pose_degrees"]) > 0.0, "ride leg pose should be configured")
	_assert(is_equal_approx(float(player_config["ride_seat_pivot_height"]), 0.84), "ride seat pivot height should align the visitor with seat anchors")
	_assert(float(player_config["ride_ground_height_limit"]) > 0.0, "ride ground height limit should be configured")
	_assert(float(config["ride"]["station_tolerance"]) > 0.0, "ride station tolerance should be configured")
	_assert(is_equal_approx(float(config["landmarks"][3]["suspense_min_seconds"]), 2.5), "free-fall suspense minimum should be configured")
	_assert(int(config["landmarks"][4]["lap_count"]) == 3, "go-kart should use three laps")
	_assert(float(player_config["camera_min_pitch_degrees"]) < float(player_config["camera_max_pitch_degrees"]), "camera pitch limits should be ordered")
	var invalid_config: Dictionary = config.duplicate(true)
	invalid_config["world_size"] = 16.0
	_assert(not ParkConfig.validate(invalid_config).is_empty(), "invalid world size should be rejected")
	var invalid_camera: Dictionary = config.duplicate(true)
	invalid_camera["player"]["camera_default_pitch_degrees"] = 90.0
	_assert(not ParkConfig.validate(invalid_camera).is_empty(), "camera default pitch outside limits should be rejected")
	var invalid_ride: Dictionary = config.duplicate(true)
	invalid_ride["landmarks"][0]["boarding_radius"] = 0.0
	_assert(not ParkConfig.validate(invalid_ride).is_empty(), "non-positive boarding radius should be rejected")

## Runs pure movement formula assertions.
func run_movement_tests() -> void:
	var diagonal: Vector3 = MovementMath.horizontal_velocity(Vector2.ONE, Basis.IDENTITY, 5.0)
	_assert(is_equal_approx(diagonal.length(), 5.0), "diagonal speed must be normalized")
	_assert(is_equal_approx(diagonal.x, diagonal.z), "diagonal direction should be even")
	var falling_velocity: float = MovementMath.next_vertical_velocity(0.0, 0.5, 10.0, false, false, 4.5)
	_assert(is_equal_approx(falling_velocity, -5.0), "gravity should be applied over delta")
	var jump_velocity: float = MovementMath.next_vertical_velocity(0.0, 0.016, 10.0, true, true, 4.5)
	_assert(is_equal_approx(jump_velocity, 4.5), "grounded jump should use jump velocity")
	var clamped_up: float = MovementMath.clamped_orbit_pitch(0.0, -10000.0, 0.01, -55.0, 35.0)
	_assert(is_equal_approx(clamped_up, deg_to_rad(35.0)), "orbit pitch must respect the upper limit")
	var clamped_down: float = MovementMath.clamped_orbit_pitch(0.0, 10000.0, 0.01, -55.0, 35.0)
	_assert(is_equal_approx(clamped_down, deg_to_rad(-55.0)), "orbit pitch must respect the lower limit")
	_assert(is_equal_approx(MovementMath.target_yaw(Vector3(0.0, 0.0, -1.0)), 0.0), "forward direction should keep zero yaw")
	_assert(is_equal_approx(MovementMath.target_yaw(Vector3(1.0, 0.0, 0.0)), -PI * 0.5), "right direction should face right")

## Instantiates the main scene and verifies generated runtime structure.
func run_scene_tests(tree: SceneTree) -> void:
	var config: Dictionary = ParkConfig.load_from_file(CONFIG_PATH)
	var main_instance: Node = MainScene.instantiate()
	tree.root.add_child(main_instance)
	await tree.process_frame
	await tree.process_frame
	var park: Node = main_instance.get_node("Park/GeneratedPark")
	_assert(park.get_node_or_null("FerrisWheel") != null, "ferris wheel node should be generated")
	_assert(park.get_node_or_null("RollerCoaster") != null, "roller coaster node should be generated")
	_assert(park.get_node_or_null("Carousel") != null, "carousel node should be generated")
	_assert(park.get_node_or_null("FreeFallTower") != null, "free-fall tower node should be generated")
	_assert(park.get_node_or_null("GoKart") != null, "go-kart node should be generated")
	var coaster_sign_label: Label3D = park.get_node_or_null("RollerCoaster/LandmarkSign/SignLabel") as Label3D
	_assert(coaster_sign_label != null, "roller coaster should expose its attraction name label")
	if coaster_sign_label != null:
		_assert(coaster_sign_label.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "attraction name labels should keep a fixed board orientation")
	_assert(tree.get_nodes_in_group("landmark_zone").size() == 5, "five landmark trigger zones should exist")
	_assert(tree.get_nodes_in_group("ride_zone").size() == 5, "five ride boarding zones should exist")
	_assert(park.get_node_or_null("AttractionAnimator") != null, "one attraction animator should exist")
	_assert(main_instance.get_node_or_null("Park/RideCoordinator") != null, "one ride coordinator should exist")
	var builder_signal: Callable = Callable(self, "_on_landmark_entered")
	if park.has_signal(&"landmark_entered"):
		park.connect(&"landmark_entered", builder_signal)
	var player: CharacterBody3D = main_instance.get_node("Player") as CharacterBody3D
	var player_collision: CollisionShape3D = main_instance.get_node("Player/CollisionShape3D") as CollisionShape3D
	var visual_root: Node3D = main_instance.get_node("Player/VisualRoot") as Node3D
	var camera_yaw: Node3D = main_instance.get_node("Player/CameraYaw") as Node3D
	var camera_pitch: Node3D = main_instance.get_node("Player/CameraYaw/CameraPitch") as Node3D
	var spring_arm: SpringArm3D = main_instance.get_node("Player/CameraYaw/CameraPitch/SpringArm3D") as SpringArm3D
	var camera: Camera3D = main_instance.get_node("Player/CameraYaw/CameraPitch/SpringArm3D/Camera3D") as Camera3D
	await tree.physics_frame
	_assert(visual_root.get_child_count() >= 5, "player should have a visible primitive model")
	_assert(camera.current, "third-person camera should be active")
	_assert(is_equal_approx(spring_arm.spring_length, float(config["player"]["camera_distance"])), "spring arm should use configured distance")
	_assert(spring_arm.shape is SphereShape3D, "spring arm should use a spherical collision cast")
	_assert(camera.position.z > 0.0, "camera should sit behind the player on the spring arm")

	var camera_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	camera_motion.relative = Vector2(80.0, -80.0)
	var yaw_before: float = camera_yaw.rotation.y
	player.call("apply_camera_motion", camera_motion.relative)
	_assert(not is_equal_approx(yaw_before, camera_yaw.rotation.y), "mouse motion should orbit the camera")
	_assert(camera_pitch.rotation.x <= deg_to_rad(35.0) and camera_pitch.rotation.x >= deg_to_rad(-55.0), "camera orbit pitch should remain clamped")
	camera_yaw.rotation.y = 0.0
	camera_pitch.rotation.x = deg_to_rad(float(config["player"]["camera_default_pitch_degrees"]))

	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.name = "CameraTestObstacle"
	obstacle.collision_layer = 1
	obstacle.collision_mask = 1
	var obstacle_shape: CollisionShape3D = CollisionShape3D.new()
	var obstacle_box: BoxShape3D = BoxShape3D.new()
	obstacle_box.size = Vector3(4.0, 4.0, 0.4)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	main_instance.add_child(obstacle)
	obstacle.global_position = player.global_position + Vector3(0.0, float(config["player"]["camera_pivot_height"]), 2.0)
	await tree.physics_frame
	_assert(spring_arm.get_hit_length() < float(config["player"]["camera_distance"]), "spring arm should shorten against an obstacle")
	obstacle.queue_free()
	await tree.process_frame

	var left_arm: Node3D = visual_root.get_node("LeftArmPivot") as Node3D
	var arm_before: float = left_arm.rotation.x
	Input.action_press(&"move_right")
	for step: int in range(12):
		await tree.physics_frame
	Input.action_release(&"move_right")
	_assert(not is_equal_approx(visual_root.rotation.y, 0.0), "model should turn toward movement")
	_assert(not is_equal_approx(arm_before, left_arm.rotation.x), "model limbs should animate while moving")
	visual_root.call("update_motion", Vector3.ZERO, 0.0, false, false, 0.1)
	_assert(left_arm.rotation.x < 0.0, "model should use the configured jump pose while airborne")
	player.global_position = Vector3(0.0, 1.0, 19.0)
	player.velocity = Vector3.ZERO
	visual_root.rotation.y = 0.0
	var carousel_zone: Area3D = park.get_node("Carousel/LandmarkZone") as Area3D
	player.global_position = Vector3(0.0, 1.0, 19.0)
	Input.action_press(&"move_forward")
	for step: int in range(50):
		await tree.physics_frame
	Input.action_release(&"move_forward")
	await tree.physics_frame
	await tree.process_frame
	await tree.process_frame
	_assert(carousel_zone.monitoring, "carousel zone should monitor bodies")
	_assert(_last_landmark_name == "Carousel", "entering carousel zone should emit a landmark event")
	var animator: Node = park.get_node("AttractionAnimator")
	var carousel_spin: Node3D = park.get_node("Carousel/CarouselSpin") as Node3D
	var rotation_before: float = carousel_spin.rotation.y
	var coaster_cart: Node3D = park.get_node("RollerCoaster/CoasterCart") as Node3D
	var cart_position_before: Vector3 = coaster_cart.position
	animator.call("advance_time", 1.0)
	_assert(not is_equal_approx(rotation_before, carousel_spin.rotation.y), "carousel should advance through the animator")
	_assert(not cart_position_before.is_equal_approx(coaster_cart.position), "roller coaster cart should advance on its route")
	var coordinator: Node = main_instance.get_node("Park/RideCoordinator")
	coordinator.ride_prompt_changed.connect(_on_ride_prompt_changed)
	var ride_descriptors: Dictionary = park.call("get_ride_descriptors")
	var ride_providers: Dictionary = park.call("get_ride_providers")
	_assert(ride_providers.get("free_fall_tower") != null, "free-fall tower should expose a provider")
	_assert(ride_providers.get("go_kart") != null, "go-kart should expose a provider")
	for ride_id: StringName in [&"ferris_wheel", &"roller_coaster", &"carousel"]:
		var descriptor: Dictionary = ride_descriptors.get(ride_id, {})
		var boarding_zone: Area3D = descriptor.get("boarding_zone") as Area3D
		_assert(boarding_zone != null, "%s should expose a boarding zone" % ride_id)
		_assert(descriptor.get("seat_anchor") is Node3D, "%s should expose a seat anchor" % ride_id)
		_assert(descriptor.get("exit_marker") is Marker3D, "%s should expose an exit marker" % ride_id)
		player.global_position = Vector3(0.0, 1.05, 0.0)
		player.velocity = Vector3.ZERO
		for clear_step: int in range(3):
			await tree.physics_frame
		_last_ride_prompt_state = &""
		_last_ride_prompt_name = ""
		player.global_position = boarding_zone.global_position + Vector3(0.0, 1.05, 0.0)
		player.velocity = Vector3.ZERO
		for settle_step: int in range(3):
			await tree.physics_frame
		_assert(_last_ride_prompt_state == &"available", "%s should announce an available ride prompt" % ride_id)
		_assert(_last_ride_prompt_name == String(descriptor.get("display_name", ride_id)), "%s prompt should use its display name" % ride_id)
		var interact_event: InputEventKey = InputEventKey.new()
		interact_event.keycode = KEY_E
		interact_event.pressed = true
		player.call("_unhandled_input", interact_event)
		_assert(coordinator.call("get_state") == &"waiting" or coordinator.call("get_state") == &"riding", "%s should publish a waiting or riding state after E" % ride_id)
		for wait_step: int in range(60):
			if player.call("is_riding"):
				break
			animator.call("advance_time", 0.5)
		_assert(player.call("is_riding"), "%s should start after the next station arrival" % ride_id)
		_assert(coordinator.call("get_state") == &"riding", "%s should own the ride lease" % ride_id)
		_assert(not player.call("can_start_ride"), "%s should reject a second ride while riding" % ride_id)
		var ride_camera_yaw_before: float = camera_yaw.rotation.y
		player.call("apply_camera_motion", Vector2(40.0, -20.0))
		_assert(camera.current, "%s should keep the third-person camera active while riding" % ride_id)
		_assert(not is_equal_approx(ride_camera_yaw_before, camera_yaw.rotation.y), "%s should keep camera orbit input while riding" % ride_id)
		if ride_id == &"roller_coaster":
			var coaster_camera_heading: float = camera_yaw.global_rotation.y
			var coaster_player_heading: float = player.global_rotation.y
			var coaster_vehicle_heading: float = coaster_cart.global_rotation.y
			var coaster_vehicle_turn_detected: bool = false
			for coaster_view_step: int in range(16):
				animator.call("advance_time", 0.5)
				await tree.physics_frame
				if absf(wrapf(coaster_cart.global_rotation.y - coaster_vehicle_heading, -PI, PI)) > 0.05:
					coaster_vehicle_turn_detected = true
			_assert(coaster_vehicle_turn_detected, "roller coaster should change vehicle heading along its track")
			_assert(absf(wrapf(camera_yaw.global_rotation.y - coaster_camera_heading, -PI, PI)) < 0.01, "roller coaster supports should not rotate the camera view")
			_assert(absf(wrapf(player.global_rotation.y - coaster_player_heading, -PI, PI)) < 0.01, "roller coaster supports should not rotate the camera parent")
		var seat_anchor: Node3D = descriptor.get("seat_anchor") as Node3D
		player.call("_sync_to_ride_anchor")
		_assert_seated_player(player, visual_root, seat_anchor, float(config["player"]["ride_seat_pivot_height"]), ride_id)
		Input.action_press(&"move_forward")
		await tree.physics_frame
		Input.action_release(&"move_forward")
		await tree.process_frame
		await tree.physics_frame
		_assert(player.velocity.is_zero_approx(), "%s should ignore walking input while riding" % ride_id)
		_assert(player.global_position.distance_to(seat_anchor.global_position) < 0.1, "%s should remain attached while input is pressed" % ride_id)
		var ride_finished: bool = false
		for ride_step: int in range(90):
			animator.call("advance_time", 0.5)
			if not player.call("is_riding"):
				ride_finished = true
				break
		_assert(ride_finished, "%s should finish after one cycle" % ride_id)
		_assert(not player.call("is_riding"), "%s should auto-exit after one cycle" % ride_id)
		_assert(coordinator.call("get_state") == &"available", "%s should release the ride lease after exit" % ride_id)
		_assert(animator.call("get_ride_state", ride_id) == &"decorative", "%s should return to decorative motion" % ride_id)
		await tree.physics_frame
		_assert(not player_collision.disabled, "%s should restore player collision after exit" % ride_id)
		_assert(absf(visual_root.position.y) < 0.01, "%s should restore the standing visual offset after exit" % ride_id)

	var free_fall_descriptor: Dictionary = ride_descriptors["free_fall_tower"]
	var free_fall_provider: Node = ride_providers["free_fall_tower"] as Node
	free_fall_provider.set_process(false)
	_assert(free_fall_descriptor.get("seat_anchor") is Node3D, "free-fall tower should expose a seat anchor")
	_assert(free_fall_provider.call("get_ride_state", &"free_fall_tower") == &"decorative", "free-fall tower should start decorative")
	player.global_position = (free_fall_descriptor["boarding_zone"] as Area3D).global_position + Vector3(0.0, 1.05, 0.0)
	player.velocity = Vector3.ZERO
	for free_fall_settle: int in range(4):
		await tree.physics_frame
		await tree.process_frame
	_last_ride_prompt_state = &""
	var free_fall_event: InputEventKey = InputEventKey.new()
	free_fall_event.keycode = KEY_E
	free_fall_event.pressed = true
	player.call("_unhandled_input", free_fall_event)
	_assert(player.call("is_riding"), "free-fall tower should board immediately")
	_assert_seated_player(player, visual_root, free_fall_descriptor["seat_anchor"] as Node3D, float(config["player"]["ride_seat_pivot_height"]), &"free_fall_tower")
	free_fall_provider.call("set_random_seed", 11)
	free_fall_provider.call("advance_simulation", 1.0)
	for free_fall_step: int in range(12):
		free_fall_provider.call("advance_simulation", 0.5)
	_assert(free_fall_provider.call("get_ride_state", &"free_fall_tower") == &"suspense", "free-fall tower should hold at the top before dropping")
	var suspense_duration: float = float(free_fall_provider.call("get_suspense_duration"))
	_assert(suspense_duration >= 2.5 and suspense_duration <= 4.5, "free-fall suspense should stay within configured random range")
	free_fall_provider.call("advance_simulation", suspense_duration + 0.1)
	_assert(free_fall_provider.call("get_ride_state", &"free_fall_tower") == &"dropping" or free_fall_provider.call("get_ride_state", &"free_fall_tower") == &"braking", "free-fall tower should begin the drop after the pause")
	for free_fall_step: int in range(30):
		free_fall_provider.call("advance_simulation", 0.5)
		if not player.call("is_riding"):
			break
	_assert(not player.call("is_riding"), "free-fall tower should auto-exit after settling")

	var kart_descriptor: Dictionary = ride_descriptors["go_kart"]
	var kart_provider: Node = ride_providers["go_kart"] as Node
	kart_provider.set_physics_process(false)
	var kart_zone: Area3D = kart_descriptor["boarding_zone"] as Area3D
	player.global_position = kart_zone.global_position + Vector3(0.0, 1.05, 0.0)
	player.velocity = Vector3.ZERO
	for kart_settle: int in range(4):
		await tree.physics_frame
		await tree.process_frame
	var kart_event: InputEventKey = InputEventKey.new()
	kart_event.keycode = KEY_E
	kart_event.pressed = true
	player.call("_unhandled_input", kart_event)
	_assert(player.call("is_riding"), "go-kart should board immediately")
	_assert(kart_provider.call("get_ride_state", &"go_kart") == &"countdown", "go-kart should start with a countdown")
	_assert_seated_player(player, visual_root, kart_descriptor["seat_anchor"] as Node3D, float(config["player"]["ride_seat_pivot_height"]), &"go_kart")
	var kart_expected_start: Vector3 = ParkConfig.vector3_from_array(config["landmarks"][4]["track_points"][0])
	var kart_start_position: Vector3 = (kart_descriptor["cart"] as CharacterBody3D).position
	_assert(Vector2(kart_start_position.x, kart_start_position.z).distance_to(Vector2(kart_expected_start.x, kart_expected_start.z)) < 0.01, "go-kart should preserve its configured start point")
	var kart_panel: PanelContainer = main_instance.get_node("HUD/Overlay/KartRacePanel") as PanelContainer
	_assert(kart_panel.visible, "kart countdown should be visible in the HUD")
	kart_provider.call("advance_drive", 2.0, 1.0, false, 0.0)
	_assert(kart_provider.call("get_ride_state", &"go_kart") == &"countdown", "go-kart should keep the countdown before GO")
	kart_provider.call("advance_drive", 1.2, 1.0, false, 0.0)
	_assert(kart_provider.call("get_ride_state", &"go_kart") == &"racing", "go-kart should become controllable after GO")
	_assert(float(kart_provider.call("get_progress_snapshot")["lap_count"]) == 3.0, "go-kart progress should expose three laps")
	var kart_motion_start: Vector3 = (kart_descriptor["cart"] as CharacterBody3D).position
	for kart_drive_step: int in range(30):
		kart_provider.call("advance_drive", 1.0 / 60.0, 1.0, false, 0.0)
	var kart_motion_end: Vector3 = (kart_descriptor["cart"] as CharacterBody3D).position
	_assert(kart_motion_start.distance_to(kart_motion_end) > 0.5, "go-kart should move continuously while throttle is held")
	_assert(kart_provider.call("get_ride_state", &"go_kart") == &"racing", "go-kart should remain drivable instead of finishing immediately")
	var kart_reset_event: InputEventKey = InputEventKey.new()
	kart_reset_event.keycode = KEY_R
	kart_reset_event.pressed = true
	player.call("_unhandled_input", kart_reset_event)
	var kart_after_reset: Dictionary = kart_provider.call("get_progress_snapshot")
	_assert(kart_provider.call("get_ride_state", &"go_kart") == &"racing" and (kart_after_reset["cart_position"] as Vector3).distance_to(kart_after_reset["last_checkpoint_position"] as Vector3) < 0.05, "R should reset the kart to the last checkpoint")
	var kart_exit_event: InputEventKey = InputEventKey.new()
	kart_exit_event.keycode = KEY_E
	kart_exit_event.pressed = true
	player.call("_unhandled_input", kart_exit_event)
	_assert(not player.call("is_riding"), "E should exit the manually driven kart")
	_assert(not kart_panel.visible, "kart HUD should hide after exiting")
	_assert(absf(visual_root.position.y) < 0.01, "go-kart should restore the standing visual offset after exit")
	_assert(player_collision.shape is CapsuleShape3D, "player should use a capsule collision")
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(park, meshes)
	_assert(meshes.size() > 30, "park should contain visible primitive geometry")
	for mesh_instance: MeshInstance3D in meshes:
		_assert(PrimitiveFactory.is_allowed_mesh(mesh_instance.mesh), "all park meshes must be approved primitives")
	var player_meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual_root, player_meshes)
	_assert(player_meshes.size() == 10, "player should contain the complete visitor model")
	for mesh_instance: MeshInstance3D in player_meshes:
		_assert(PrimitiveFactory.is_allowed_mesh(mesh_instance.mesh), "all player meshes must be approved primitives")
	await tree.create_timer(2.7).timeout
	main_instance.queue_free()
	await tree.process_frame

func _on_landmark_entered(_landmark_id: StringName, display_name: String) -> void:
	_last_landmark_name = display_name

func _on_ride_prompt_changed(state: StringName, display_name: String) -> void:
	_last_ride_prompt_state = state
	_last_ride_prompt_name = display_name

## Returns the number of failed assertions.
func failure_count() -> int:
	return _failures.size()

## Returns the number of assertions performed.
func assertion_count() -> int:
	return _assertion_count

## Returns a copy of failure messages for the runner.
func failures() -> PackedStringArray:
	return _failures

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		meshes.append(mesh_instance)
	for child: Node in node.get_children():
		_collect_meshes(child, meshes)

func _assert_seated_player(player: CharacterBody3D, visual_root: Node3D, seat_anchor: Node3D, pivot_height: float, ride_id: StringName) -> void:
	_assert(player.global_position.distance_to(seat_anchor.global_position) < 0.01, "%s should follow its seat anchor" % ride_id)
	var left_leg: Node3D = visual_root.get_node("LeftLegPivot") as Node3D
	var right_leg: Node3D = visual_root.get_node("RightLegPivot") as Node3D
	var hip_center: Vector3 = (left_leg.global_position + right_leg.global_position) * 0.5
	_assert(hip_center.distance_to(seat_anchor.global_position) < 0.02, "%s should align the visitor hip with the seat anchor" % ride_id)
	_assert(is_equal_approx(visual_root.position.y, -pivot_height), "%s should apply the configured seated visual offset" % ride_id)

func _assert(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
