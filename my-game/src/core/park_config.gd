extends RefCounted

## Loads and validates the external data used to build the park.
##
## The runtime keeps this data in dictionaries so the project does not need
## editor-generated custom resources for this small, procedural vertical slice.

const REQUIRED_LANDMARKS: Array = [
	"ferris_wheel",
	"roller_coaster",
	"carousel",
	"free_fall_tower",
	"go_kart"
]

## Loads a JSON configuration file into a dictionary.
static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

## Returns a list of human-readable configuration errors.
static func validate(config: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var world_size_value: Variant = config.get("world_size", null)
	if not _is_number(world_size_value) or float(world_size_value) < 32.0:
		errors.append("world_size must be a number of at least 32.0")
	var boundary_height_value: Variant = config.get("boundary_height", null)
	if not _is_number(boundary_height_value) or float(boundary_height_value) <= 0.0:
		errors.append("boundary_height must be positive")
	for key: String in ["gate_width", "path_width", "plaza_radius"]:
		var value: Variant = config.get(key, null)
		if not _is_number(value) or float(value) <= 0.0:
			errors.append("%s must be positive" % key)
	var spawn_position: Vector3 = vector3_from_array(config.get("spawn_position", []), Vector3(999.0, 999.0, 999.0))
	var half_extent_for_spawn: float = float(world_size_value) / 2.0 if _is_number(world_size_value) else 0.0
	if absf(spawn_position.x) >= half_extent_for_spawn or absf(spawn_position.z) >= half_extent_for_spawn or spawn_position.y <= 0.0:
		errors.append("spawn_position must be above the ground and inside the world")

	var player_value: Variant = config.get("player", null)
	if not player_value is Dictionary:
		errors.append("player must be an object")
	else:
		var player_config: Dictionary = player_value
		for key: String in [
			"walk_speed",
			"sprint_multiplier",
			"jump_velocity",
			"gravity",
			"mouse_sensitivity",
			"camera_max_pitch_degrees",
			"camera_pivot_height",
			"camera_distance",
			"camera_collision_radius",
			"camera_collision_margin",
			"field_of_view",
			"turn_speed",
			"walk_cycle_speed",
			"sprint_cycle_speed",
			"limb_swing_degrees",
			"jump_pose_degrees",
			"pose_blend_speed",
			"ride_arm_pose_degrees",
			"ride_leg_pose_degrees",
			"ride_ground_height_limit"
		]:
			var value: Variant = player_config.get(key, null)
			if not _is_number(value) or float(value) <= 0.0:
				errors.append("player.%s must be positive" % key)
		var min_pitch: Variant = player_config.get("camera_min_pitch_degrees", null)
		if not _is_number(min_pitch):
			errors.append("player.camera_min_pitch_degrees must be a number")
		var max_pitch: Variant = player_config.get("camera_max_pitch_degrees", null)
		if not _is_number(max_pitch):
			errors.append("player.camera_max_pitch_degrees must be a number")
		if _is_number(min_pitch) and _is_number(max_pitch) and float(min_pitch) >= float(max_pitch):
			errors.append("player camera pitch limits must be ordered")
		var default_pitch: Variant = player_config.get("camera_default_pitch_degrees", null)
		if not _is_number(default_pitch):
			errors.append("player.camera_default_pitch_degrees must be a number")
		elif _is_number(min_pitch) and _is_number(max_pitch) and (float(default_pitch) < float(min_pitch) or float(default_pitch) > float(max_pitch)):
			errors.append("player.camera_default_pitch_degrees must be within camera pitch limits")

	var landmarks_value: Variant = config.get("landmarks", null)
	if not landmarks_value is Array:
		errors.append("landmarks must be an array")
	else:
		var landmarks: Array = landmarks_value
		if landmarks.size() != REQUIRED_LANDMARKS.size():
			errors.append("landmarks must contain exactly %d entries" % REQUIRED_LANDMARKS.size())
		var seen_ids: Dictionary = {}
		var half_extent: float = float(world_size_value) / 2.0 if _is_number(world_size_value) else 0.0
		for raw_landmark: Variant in landmarks:
			if not raw_landmark is Dictionary:
				errors.append("every landmark must be an object")
				continue
			var landmark: Dictionary = raw_landmark
			var landmark_id: String = String(landmark.get("id", ""))
			if landmark_id.is_empty():
				errors.append("every landmark needs an id")
			elif seen_ids.has(landmark_id):
				errors.append("landmark ids must be unique: %s" % landmark_id)
			else:
				seen_ids[landmark_id] = true
			var position: Vector3 = vector3_from_array(landmark.get("position", []), Vector3(999.0, 999.0, 999.0))
			if absf(position.x) >= half_extent or absf(position.z) >= half_extent:
				errors.append("landmark %s is outside the world" % landmark_id)
			for position_key: String in ["boarding_position", "exit_position"]:
				var ride_position: Vector3 = vector3_from_array(landmark.get(position_key, []), Vector3(999.0, 999.0, 999.0))
				var world_ride_position: Vector3 = position + ride_position
				if absf(world_ride_position.x) >= half_extent or absf(world_ride_position.z) >= half_extent:
					errors.append("landmark %s %s is outside the world" % [landmark_id, position_key])
			var boarding_radius: Variant = landmark.get("boarding_radius", null)
			if not _is_number(boarding_radius) or float(boarding_radius) <= 0.0:
				errors.append("landmark %s needs a positive boarding_radius" % landmark_id)
			if landmark_id == "roller_coaster":
				var cart_speed: Variant = landmark.get("cart_speed", null)
				if not _is_number(cart_speed) or float(cart_speed) <= 0.0:
					errors.append("landmark %s needs a positive cart_speed" % landmark_id)
			elif landmark_id == "ferris_wheel" or landmark_id == "carousel":
				var rotation_speed: Variant = landmark.get("rotation_speed", null)
				if not _is_number(rotation_speed) or float(rotation_speed) <= 0.0:
					errors.append("landmark %s needs a positive rotation_speed" % landmark_id)
			elif landmark_id == "free_fall_tower":
				for key: String in ["tower_height", "drop_distance", "harness_seconds", "ascent_speed", "suspense_min_seconds", "suspense_max_seconds", "drop_acceleration", "drop_max_speed", "brake_height", "brake_seconds", "settle_seconds"]:
					var value: Variant = landmark.get(key, null)
					if not _is_number(value) or float(value) <= 0.0:
						errors.append("landmark %s.%s must be positive" % [landmark_id, key])
				var suspense_min: Variant = landmark.get("suspense_min_seconds", null)
				var suspense_max: Variant = landmark.get("suspense_max_seconds", null)
				if _is_number(suspense_min) and _is_number(suspense_max) and float(suspense_min) > float(suspense_max):
					errors.append("landmark %s suspense range must be ordered" % landmark_id)
			elif landmark_id == "go_kart":
				for key: String in ["track_width", "lap_count", "countdown_seconds", "max_forward_speed", "max_reverse_speed", "acceleration", "brake_strength", "coast_deceleration", "steering_degrees_per_second", "result_display_seconds"]:
					var value: Variant = landmark.get(key, null)
					if not _is_number(value) or float(value) <= 0.0:
						errors.append("landmark %s.%s must be positive" % [landmark_id, key])
				var points_value: Variant = landmark.get("track_points", null)
				if not points_value is Array or (points_value as Array).size() < 4:
					errors.append("landmark %s needs at least four track_points" % landmark_id)
				elif points_value is Array:
					for point_value: Variant in points_value:
						if vector3_from_array(point_value, Vector3(999.0, 999.0, 999.0)).x >= 999.0:
							errors.append("landmark %s track_points must contain three numbers" % landmark_id)
							break
				var checkpoints_value: Variant = landmark.get("checkpoint_indices", null)
				if not checkpoints_value is Array or (checkpoints_value as Array).is_empty():
					errors.append("landmark %s needs checkpoint_indices" % landmark_id)
				elif points_value is Array and checkpoints_value is Array:
					for checkpoint_value: Variant in checkpoints_value:
						if not (checkpoint_value is int or checkpoint_value is float) or int(checkpoint_value) < 0 or int(checkpoint_value) >= (points_value as Array).size():
							errors.append("landmark %s checkpoint index is outside track_points" % landmark_id)
							break
			var trigger_radius: Variant = landmark.get("trigger_radius", null)
			if not _is_number(trigger_radius) or float(trigger_radius) <= 0.0:
				errors.append("landmark %s needs a positive trigger_radius" % landmark_id)
		for required_id: String in REQUIRED_LANDMARKS:
			if not seen_ids.has(required_id):
				errors.append("missing required landmark: %s" % required_id)

	var ui_value: Variant = config.get("ui", null)
	if not ui_value is Dictionary:
		errors.append("ui must be an object")
	else:
		var ui_config: Dictionary = ui_value
		var display_seconds: Variant = ui_config.get("location_display_seconds", null)
		if not _is_number(display_seconds) or float(display_seconds) <= 0.0:
			errors.append("ui.location_display_seconds must be positive")

	var ride_value: Variant = config.get("ride", null)
	if not ride_value is Dictionary:
		errors.append("ride must be an object")
	else:
		var ride_config: Dictionary = ride_value
		var station_tolerance: Variant = ride_config.get("station_tolerance", null)
		if not _is_number(station_tolerance) or float(station_tolerance) <= 0.0:
			errors.append("ride.station_tolerance must be positive")
	return errors

## Converts a JSON array with three numbers into a Vector3.
static func vector3_from_array(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if not value is Array:
		return fallback
	var values: Array = value
	if values.size() < 3 or not _is_number(values[0]) or not _is_number(values[1]) or not _is_number(values[2]):
		return fallback
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

## Converts a CSS-style color string into a Color.
static func color_from_hex(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if not value is String:
		return fallback
	return Color.from_string(String(value), fallback)

static func _is_number(value: Variant) -> bool:
	return value is int or value is float
