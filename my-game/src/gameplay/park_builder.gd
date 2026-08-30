extends Node3D

const ParkConfig = preload("res://src/core/park_config.gd")
const PrimitiveFactory = preload("res://src/core/primitive_factory.gd")
const AttractionAnimator = preload("res://src/gameplay/attraction_animator.gd")
const FreeFallController = preload("res://src/gameplay/free_fall_controller.gd")
const GoKartController = preload("res://src/gameplay/go_kart_controller.gd")

## Emitted when the player enters a landmark trigger volume.
signal landmark_entered(landmark_id: StringName, display_name: String)

var _built: bool = false
var _landmarks: Array = []
var _ride_descriptors: Dictionary = {}
var _ride_providers: Dictionary = {}
var _animator: AttractionAnimator

## Builds the complete park from validated external configuration.
func build(config: Dictionary) -> void:
	if _built:
		return
	var palette_value: Variant = config.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var world_size: float = float(config["world_size"])
	var boundary_height: float = float(config["boundary_height"])
	var gate_width: float = float(config["gate_width"])
	var path_width: float = float(config["path_width"])
	var plaza_radius: float = float(config["plaza_radius"])
	var grass_color: Color = ParkConfig.color_from_hex(palette.get("grass", "#62C985"), Color("#62C985"))
	var path_color: Color = ParkConfig.color_from_hex(palette.get("path", "#F4D6A1"), Color("#F4D6A1"))
	var wall_color: Color = ParkConfig.color_from_hex(palette.get("wall", "#F6B5A8"), Color("#F6B5A8"))
	var trim_color: Color = ParkConfig.color_from_hex(palette.get("trim", "#FFF0B3"), Color("#FFF0B3"))
	var sign_color: Color = ParkConfig.color_from_hex(palette.get("sign", "#5A3B76"), Color("#5A3B76"))
	var landmarks_value: Variant = config["landmarks"]
	var landmarks: Array = landmarks_value
	_landmarks = landmarks
	_ride_descriptors.clear()
	_ride_providers.clear()

	_build_ground(world_size, grass_color, path_color, plaza_radius, path_width)
	_build_boundary(world_size, boundary_height, gate_width, wall_color)
	_build_entrance(world_size, boundary_height, gate_width, trim_color, sign_color)
	_build_trees(config, grass_color)

	var ferris_wheel: Node3D
	var carousel: Node3D
	var coaster_cart: Node3D
	var coaster_track: PackedVector3Array = PackedVector3Array()
	var ferris_speed: float = 0.0
	var carousel_speed: float = 0.0
	var coaster_speed: float = 0.0
	for raw_landmark: Variant in landmarks:
		var landmark: Dictionary = raw_landmark
		var landmark_id: StringName = StringName(String(landmark["id"]))
		var display_name: String = String(landmark["display_name"])
		var landmark_root: Node3D = Node3D.new()
		landmark_root.name = _display_node_name(landmark_id)
		landmark_root.position = ParkConfig.vector3_from_array(landmark["position"])
		add_child(landmark_root)
		var color: Color = ParkConfig.color_from_hex(landmark.get("color", "#FFFFFF"), Color.WHITE)
		var accent: Color = ParkConfig.color_from_hex(landmark.get("accent", "#FFF0B3"), trim_color)
		_create_sign(landmark_root, String(landmark.get("sign_text", display_name.to_upper())), sign_color)
		_create_landmark_zone(landmark_root, landmark_id, display_name, float(landmark["trigger_radius"]))
		match landmark_id:
			"ferris_wheel":
				var ferris_data: Dictionary = _build_ferris_wheel(landmark_root, color, accent)
				ferris_wheel = ferris_data["root"]
				_ride_descriptors[landmark_id] = _create_ride_descriptor(landmark_root, landmark, ferris_data)
				ferris_speed = float(landmark.get("rotation_speed", 0.0))
			"roller_coaster":
				var coaster_data: Dictionary = _build_roller_coaster(landmark_root, color, accent)
				coaster_cart = coaster_data["cart"]
				coaster_track = coaster_data["track"]
				_ride_descriptors[landmark_id] = _create_ride_descriptor(landmark_root, landmark, coaster_data)
				coaster_speed = float(landmark.get("cart_speed", 0.0))
			"carousel":
				var carousel_data: Dictionary = _build_carousel(landmark_root, color, accent)
				carousel = carousel_data["root"]
				_ride_descriptors[landmark_id] = _create_ride_descriptor(landmark_root, landmark, carousel_data)
				carousel_speed = float(landmark.get("rotation_speed", 0.0))
			"free_fall_tower":
				var free_fall_data: Dictionary = _build_free_fall_tower(landmark_root, color, accent, landmark)
				var free_fall_descriptor: Dictionary = _create_ride_descriptor(landmark_root, landmark, free_fall_data)
				free_fall_descriptor["ride_id"] = landmark_id
				free_fall_descriptor["settings"] = landmark
				_ride_descriptors[landmark_id] = free_fall_descriptor
				var free_fall_provider: FreeFallController = FreeFallController.new()
				free_fall_provider.name = "FreeFallController"
				add_child(free_fall_provider)
				free_fall_provider.configure(free_fall_descriptor)
				_ride_providers[landmark_id] = free_fall_provider
			"go_kart":
				var go_kart_data: Dictionary = _build_go_kart(landmark_root, color, accent, landmark)
				var go_kart_descriptor: Dictionary = _create_ride_descriptor(landmark_root, landmark, go_kart_data)
				go_kart_descriptor["ride_id"] = landmark_id
				go_kart_descriptor["settings"] = landmark
				_ride_descriptors[landmark_id] = go_kart_descriptor
				var go_kart_provider: GoKartController = GoKartController.new()
				go_kart_provider.name = "GoKartController"
				add_child(go_kart_provider)
				go_kart_provider.configure(go_kart_descriptor)
				_ride_providers[landmark_id] = go_kart_provider

	_animator = AttractionAnimator.new()
	_animator.name = "AttractionAnimator"
	add_child(_animator)
	var speeds: Dictionary = {
		"ferris_wheel": ferris_speed,
		"carousel": carousel_speed,
		"roller_coaster": coaster_speed
	}
	var animator_config: Dictionary = {"station_tolerance": float(config.get("ride", {}).get("station_tolerance", 0.25))}
	for ride_id: StringName in [&"ferris_wheel", &"carousel", &"roller_coaster"]:
		animator_config[ride_id] = _ride_descriptors.get(ride_id, {})
	_animator.configure(ferris_wheel, carousel, coaster_cart, coaster_track, speeds, animator_config)
	for ride_id: StringName in [&"ferris_wheel", &"roller_coaster", &"carousel"]:
		_ride_providers[ride_id] = _animator
	_built = true

## Returns the generated ride descriptors for the coordinator and tests.
func get_ride_descriptors() -> Dictionary:
	return _ride_descriptors.duplicate()

## Returns the single animator that advances all generated attractions.
func get_attraction_animator() -> AttractionAnimator:
	return _animator

## Returns each ride's provider so the coordinator can dispatch type-specific input.
func get_ride_providers() -> Dictionary:
	return _ride_providers.duplicate()

func _build_ground(world_size: float, grass_color: Color, path_color: Color, plaza_radius: float, path_width: float) -> void:
	PrimitiveFactory.create_box(self, Vector3(world_size, 0.5, world_size), Vector3(0.0, -0.25, 0.0), grass_color, true, &"GrassFloor")
	PrimitiveFactory.create_box(self, Vector3(path_width, 0.06, world_size - 5.0), Vector3(0.0, 0.04, 0.0), path_color, false, &"MainPath")
	PrimitiveFactory.create_box(self, Vector3(world_size - 8.0, 0.06, path_width), Vector3(0.0, 0.045, 0.0), path_color, false, &"CrossPath")
	PrimitiveFactory.create_cylinder(self, plaza_radius, 0.08, Vector3(0.0, 0.08, 0.0), path_color, false, &"CentralPlaza")
	for landmark_value: Variant in _config_landmarks():
		var landmark: Dictionary = landmark_value
		var root_position: Vector3 = ParkConfig.vector3_from_array(landmark["position"])
		var boarding_position: Vector3 = ParkConfig.vector3_from_array(landmark.get("boarding_position", [0.0, 0.0, 0.0]))
		var destination: Vector3 = root_position + boarding_position
		PrimitiveFactory.create_box_between(self, Vector3.ZERO, Vector3(destination.x, 0.06, destination.z), path_width, 0.06, path_color, false, StringName("Path_" + String(landmark["id"])))

func _build_boundary(world_size: float, boundary_height: float, gate_width: float, wall_color: Color) -> void:
	var half_extent: float = world_size / 2.0
	var wall_thickness: float = 0.6
	var segment_length: float = (world_size - gate_width) / 2.0
	var segment_offset: float = gate_width / 2.0 + segment_length / 2.0
	PrimitiveFactory.create_box(self, Vector3(segment_length, boundary_height, wall_thickness), Vector3(-segment_offset, boundary_height / 2.0, half_extent - wall_thickness / 2.0), wall_color, true, &"SouthWallLeft")
	PrimitiveFactory.create_box(self, Vector3(segment_length, boundary_height, wall_thickness), Vector3(segment_offset, boundary_height / 2.0, half_extent - wall_thickness / 2.0), wall_color, true, &"SouthWallRight")
	PrimitiveFactory.create_box(self, Vector3(world_size, boundary_height, wall_thickness), Vector3(0.0, boundary_height / 2.0, -half_extent + wall_thickness / 2.0), wall_color, true, &"NorthWall")
	PrimitiveFactory.create_box(self, Vector3(wall_thickness, boundary_height, world_size), Vector3(-half_extent + wall_thickness / 2.0, boundary_height / 2.0, 0.0), wall_color, true, &"WestWall")
	PrimitiveFactory.create_box(self, Vector3(wall_thickness, boundary_height, world_size), Vector3(half_extent - wall_thickness / 2.0, boundary_height / 2.0, 0.0), wall_color, true, &"EastWall")

func _build_entrance(world_size: float, boundary_height: float, gate_width: float, trim_color: Color, sign_color: Color) -> void:
	var gate_z: float = world_size / 2.0 - 0.35
	var pillar_x: float = gate_width / 2.0
	PrimitiveFactory.create_box(self, Vector3(0.8, 4.4, 0.8), Vector3(-pillar_x, 2.2, gate_z), trim_color, true, &"EntrancePillarLeft")
	PrimitiveFactory.create_box(self, Vector3(0.8, 4.4, 0.8), Vector3(pillar_x, 2.2, gate_z), trim_color, true, &"EntrancePillarRight")
	PrimitiveFactory.create_box(self, Vector3(gate_width + 0.8, 0.8, 0.8), Vector3(0.0, 4.1, gate_z), trim_color, true, &"EntranceHeader")
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "EntranceSign"
	sign_root.position = Vector3(0.0, 0.0, gate_z - 0.48)
	add_child(sign_root)
	var board: MeshInstance3D = PrimitiveFactory.create_box(sign_root, Vector3(gate_width - 0.5, 1.1, 0.16), Vector3(0.0, 3.15, 0.0), sign_color, true, &"EntranceBoard")
	board.rotation.y = PI
	var label: Label3D = Label3D.new()
	label.name = "EntranceLabel"
	label.text = "PRIMITIVE PARK"
	label.font_size = 36
	label.outline_size = 8
	label.modulate = Color("#FFF8E8")
	label.position = Vector3(0.0, 3.15, -0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	sign_root.add_child(label)

func _build_trees(config: Dictionary, grass_color: Color) -> void:
	var tree_positions_value: Variant = config.get("trees", [])
	if not tree_positions_value is Array:
		return
	var trunk_height: float = float(config["tree_trunk_height"])
	var canopy_radius: float = float(config["tree_canopy_radius"])
	var tree_positions: Array = tree_positions_value
	for index: int in range(tree_positions.size()):
		var tree_root: Node3D = Node3D.new()
		tree_root.name = StringName("Tree_%02d" % index)
		tree_root.position = ParkConfig.vector3_from_array(tree_positions[index])
		add_child(tree_root)
		PrimitiveFactory.create_cylinder(tree_root, 0.28, trunk_height, Vector3(0.0, trunk_height / 2.0, 0.0), Color("#9B5B3E"), true, &"Trunk")
		PrimitiveFactory.create_sphere(tree_root, canopy_radius, Vector3(0.0, trunk_height + canopy_radius * 0.65, 0.0), grass_color.darkened(0.22), false, &"Canopy")

func _build_ferris_wheel(parent: Node3D, color: Color, accent: Color) -> Dictionary:
	PrimitiveFactory.create_box(parent, Vector3(0.9, 8.4, 0.9), Vector3(-2.7, 4.2, 0.0), color, true, &"SupportLeft")
	PrimitiveFactory.create_box(parent, Vector3(0.9, 8.4, 0.9), Vector3(2.7, 4.2, 0.0), color, true, &"SupportRight")
	PrimitiveFactory.create_box(parent, Vector3(7.0, 0.5, 1.4), Vector3(0.0, 0.25, 0.0), accent, true, &"FerrisBase")
	var wheel: Node3D = Node3D.new()
	wheel.name = "FerrisWheelSpin"
	wheel.position = Vector3(0.0, 5.0, 0.0)
	parent.add_child(wheel)
	PrimitiveFactory.create_cylinder(wheel, 0.7, 0.5, Vector3.ZERO, accent, false, &"Hub", Vector3(PI / 2.0, 0.0, 0.0))
	var upright_nodes: Array[Node3D] = []
	var seat_anchor: Node3D
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0 - PI / 2.0
		PrimitiveFactory.create_box(wheel, Vector3(0.22, 7.4, 0.22), Vector3.ZERO, accent, false, StringName("Spoke_%02d" % index), Vector3(0.0, 0.0, -angle))
		var cabin_root: Node3D = Node3D.new()
		cabin_root.name = StringName("Cabin_%02d" % index)
		cabin_root.position = Vector3(cos(angle) * 3.7, sin(angle) * 3.7, 0.0)
		wheel.add_child(cabin_root)
		PrimitiveFactory.create_box(cabin_root, Vector3(0.82, 0.62, 0.7), Vector3.ZERO, color, false, &"CabinBody")
		upright_nodes.append(cabin_root)
		if index == 0:
			seat_anchor = Node3D.new()
			seat_anchor.name = "SeatAnchor"
			seat_anchor.position = Vector3(0.0, 0.43, 0.0)
			cabin_root.add_child(seat_anchor)
	return {"root": wheel, "seat_anchor": seat_anchor, "upright_nodes": upright_nodes}

func _build_roller_coaster(parent: Node3D, color: Color, accent: Color) -> Dictionary:
	var track: PackedVector3Array = PackedVector3Array([
		Vector3(-6.5, 2.2, -3.8),
		Vector3(-3.0, 5.3, -5.4),
		Vector3(1.5, 3.1, -5.2),
		Vector3(5.8, 2.4, -1.4),
		Vector3(5.0, 4.2, 3.8),
		Vector3(0.5, 2.7, 5.2),
		Vector3(-4.8, 3.6, 4.0),
		Vector3(-6.8, 2.1, 0.0)
	])
	for index: int in range(track.size()):
		var point: Vector3 = track[index]
		PrimitiveFactory.create_cylinder(parent, 0.22, point.y, Vector3(point.x, point.y / 2.0, point.z), color, true, StringName("TrackSupport_%02d" % index))
		var next_point: Vector3 = track[(index + 1) % track.size()]
		PrimitiveFactory.create_box_between(parent, point + Vector3(-0.38, 0.0, 0.0), next_point + Vector3(-0.38, 0.0, 0.0), 0.18, 0.18, accent, false, StringName("RailA_%02d" % index))
		PrimitiveFactory.create_box_between(parent, point + Vector3(0.38, 0.0, 0.0), next_point + Vector3(0.38, 0.0, 0.0), 0.18, 0.18, accent, false, StringName("RailB_%02d" % index))
	var cart: Node3D = Node3D.new()
	cart.name = "CoasterCart"
	cart.position = track[0]
	parent.add_child(cart)
	PrimitiveFactory.create_box(cart, Vector3(1.0, 0.55, 1.35), Vector3.ZERO, accent, false, &"CartBody")
	var seat_anchor: Node3D = Node3D.new()
	seat_anchor.name = "SeatAnchor"
	seat_anchor.position = Vector3(0.0, 0.65, 0.0)
	cart.add_child(seat_anchor)
	PrimitiveFactory.create_box(parent, Vector3(2.2, 0.35, 1.8), Vector3(-6.5, 0.2, -3.8), color, true, &"CoasterStation")
	return {"cart": cart, "track": track, "seat_anchor": seat_anchor}

func _build_carousel(parent: Node3D, color: Color, accent: Color) -> Dictionary:
	PrimitiveFactory.create_cylinder(parent, 4.0, 0.45, Vector3(0.0, 0.25, 0.0), color, true, &"CarouselBase")
	PrimitiveFactory.create_cylinder(parent, 0.28, 4.2, Vector3(0.0, 2.1, 0.0), accent, true, &"CarouselPole")
	PrimitiveFactory.create_cone(parent, 4.7, 1.3, Vector3(0.0, 4.45, 0.0), color, false, &"CarouselCanopy")
	var spin: Node3D = Node3D.new()
	spin.name = "CarouselSpin"
	spin.position = Vector3(0.0, 0.5, 0.0)
	parent.add_child(spin)
	var seat_anchor: Node3D
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		var horse_position: Vector3 = Vector3(cos(angle) * 2.7, 1.25, sin(angle) * 2.7)
		PrimitiveFactory.create_cylinder(spin, 0.1, 1.8, horse_position + Vector3(0.0, 0.5, 0.0), accent, false, StringName("Pole_%02d" % index))
		var ride_mesh: MeshInstance3D = PrimitiveFactory.create_capsule(spin, 0.28, 1.0, horse_position, color if index % 2 == 0 else accent, false, StringName("Ride_%02d" % index))
		if index == 0:
				seat_anchor = Node3D.new()
				seat_anchor.name = "SeatAnchor"
				seat_anchor.position = Vector3(0.0, 0.35, 0.0)
				ride_mesh.add_child(seat_anchor)
	return {"root": spin, "seat_anchor": seat_anchor}

func _build_free_fall_tower(parent: Node3D, color: Color, accent: Color, landmark: Dictionary) -> Dictionary:
	var tower_height: float = float(landmark.get("tower_height", 24.0))
	var tower_radius: float = 2.7
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + PI / 4.0
		var support_position: Vector3 = Vector3(cos(angle) * tower_radius, tower_height / 2.0, sin(angle) * tower_radius)
		PrimitiveFactory.create_box(parent, Vector3(0.42, tower_height, 0.42), support_position, color, true, StringName("TowerSupport_%02d" % index))
	PrimitiveFactory.create_box_between(parent, Vector3(-tower_radius, tower_height, -tower_radius), Vector3(tower_radius, tower_height, tower_radius), 0.32, 0.32, accent, false, &"TowerTopBeamA")
	PrimitiveFactory.create_box_between(parent, Vector3(-tower_radius, tower_height, tower_radius), Vector3(tower_radius, tower_height, -tower_radius), 0.32, 0.32, accent, false, &"TowerTopBeamB")
	PrimitiveFactory.create_cylinder(parent, 3.4, 0.35, Vector3(0.0, 0.18, 0.0), accent, true, &"FreeFallPlatform")
	var carrier: Node3D = Node3D.new()
	carrier.name = "FreeFallCarrier"
	carrier.position = Vector3(0.0, 0.72, 0.0)
	parent.add_child(carrier)
	PrimitiveFactory.create_box(carrier, Vector3(2.4, 0.55, 1.5), Vector3(0.0, 0.0, 0.0), color, false, &"CarrierBody")
	PrimitiveFactory.create_box(carrier, Vector3(0.18, 1.2, 0.18), Vector3(-0.95, 0.72, 0.0), accent, false, &"HarnessLeft")
	PrimitiveFactory.create_box(carrier, Vector3(0.18, 1.2, 0.18), Vector3(0.95, 0.72, 0.0), accent, false, &"HarnessRight")
	var seat_anchor: Node3D = Node3D.new()
	seat_anchor.name = "SeatAnchor"
	seat_anchor.position = Vector3(0.0, 0.58, 0.0)
	carrier.add_child(seat_anchor)
	var lamps: Array[Node3D] = []
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0
		var lamp: MeshInstance3D = PrimitiveFactory.create_sphere(parent, 0.16, Vector3(cos(angle) * 3.1, tower_height - 0.4, sin(angle) * 3.1), accent, false, StringName("TowerLamp_%02d" % index))
		lamps.append(lamp)
	return {"motion_root": carrier, "seat_anchor": seat_anchor, "lamps": lamps}

func _build_go_kart(parent: Node3D, color: Color, accent: Color, landmark: Dictionary) -> Dictionary:
	var points: Array = []
	var points_value: Variant = landmark.get("track_points", [])
	if points_value is Array:
		for point_value: Variant in points_value:
			points.append(ParkConfig.vector3_from_array(point_value))
	var track_width: float = float(landmark.get("track_width", 3.6))
	var half_width: float = track_width * 0.5
	for index: int in range(points.size()):
		var point: Vector3 = points[index]
		var next_point: Vector3 = points[(index + 1) % points.size()]
		var tangent: Vector3 = (next_point - point)
		tangent.y = 0.0
		tangent = tangent.normalized()
		var side: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		PrimitiveFactory.create_box_between(parent, point + side * half_width + Vector3(0.0, 0.35, 0.0), next_point + side * half_width + Vector3(0.0, 0.35, 0.0), 0.24, 0.7, accent, true, StringName("KartBarrierA_%02d" % index))
		PrimitiveFactory.create_box_between(parent, point - side * half_width + Vector3(0.0, 0.35, 0.0), next_point - side * half_width + Vector3(0.0, 0.35, 0.0), 0.24, 0.7, accent, true, StringName("KartBarrierB_%02d" % index))
		PrimitiveFactory.create_box_between(parent, point + Vector3(0.0, 0.015, 0.0), next_point + Vector3(0.0, 0.015, 0.0), track_width, 0.04, Color("#F8E8BE"), false, StringName("KartLane_%02d" % index))
	var checkpoint_value: Variant = landmark.get("checkpoint_indices", [])
	if checkpoint_value is Array:
		for checkpoint_item: Variant in checkpoint_value:
			var checkpoint_index: int = int(checkpoint_item)
			if checkpoint_index < 0 or checkpoint_index >= points.size():
				continue
			var checkpoint: Vector3 = points[checkpoint_index]
			var next_checkpoint: Vector3 = points[(checkpoint_index + 1) % points.size()]
			var checkpoint_tangent: Vector3 = (next_checkpoint - checkpoint).normalized()
			var checkpoint_side: Vector3 = Vector3(-checkpoint_tangent.z, 0.0, checkpoint_tangent.x)
			PrimitiveFactory.create_box(parent, Vector3(0.18, 2.2, 0.18), checkpoint + checkpoint_side * (half_width + 0.35) + Vector3(0.0, 1.1, 0.0), accent, false, StringName("CheckpointPoleL_%02d" % checkpoint_index))
			PrimitiveFactory.create_box(parent, Vector3(0.18, 2.2, 0.18), checkpoint - checkpoint_side * (half_width + 0.35) + Vector3(0.0, 1.1, 0.0), accent, false, StringName("CheckpointPoleR_%02d" % checkpoint_index))
			PrimitiveFactory.create_box_between(parent, checkpoint + checkpoint_side * (half_width + 0.35) + Vector3(0.0, 2.15, 0.0), checkpoint - checkpoint_side * (half_width + 0.35) + Vector3(0.0, 2.15, 0.0), 0.18, 0.18, color, false, StringName("CheckpointTop_%02d" % checkpoint_index))
	var cart: CharacterBody3D = CharacterBody3D.new()
	cart.name = "GoKartCart"
	cart.collision_layer = 1
	cart.collision_mask = 1
	if not points.is_empty():
		var start: Vector3 = points[0]
		cart.position = Vector3(start.x, 0.45, start.z)
	parent.add_child(cart)
	var cart_shape: CollisionShape3D = CollisionShape3D.new()
	var cart_box: BoxShape3D = BoxShape3D.new()
	cart_box.size = Vector3(1.2, 0.8, 1.8)
	cart_shape.shape = cart_box
	cart.add_child(cart_shape)
	PrimitiveFactory.create_box(cart, Vector3(1.15, 0.48, 1.7), Vector3(0.0, 0.0, 0.0), color, false, &"KartBody")
	PrimitiveFactory.create_box(cart, Vector3(0.9, 0.12, 0.18), Vector3(0.0, 0.37, -0.45), accent, false, &"KartSteeringWheel")
	var seat_anchor: Node3D = Node3D.new()
	seat_anchor.name = "SeatAnchor"
	seat_anchor.position = Vector3(0.0, 0.62, 0.0)
	cart.add_child(seat_anchor)
	return {"cart": cart, "seat_anchor": seat_anchor, "track_points": points, "checkpoint_indices": landmark.get("checkpoint_indices", []), "settings": landmark}

func _create_ride_descriptor(parent: Node3D, landmark: Dictionary, motion_data: Dictionary) -> Dictionary:
	var landmark_id: StringName = StringName(String(landmark["id"]))
	var boarding_position: Vector3 = ParkConfig.vector3_from_array(landmark.get("boarding_position", [0.0, 0.0, 3.0]))
	var exit_position: Vector3 = ParkConfig.vector3_from_array(landmark.get("exit_position", boarding_position + Vector3(0.0, 0.0, 1.8)))
	var boarding_zone: Area3D = _create_ride_zone(parent, landmark_id, boarding_position, float(landmark.get("boarding_radius", 2.0)))
	_create_boarding_pad(parent, boarding_position, Color("#FFF0B3"), landmark_id)
	var exit_marker: Marker3D = Marker3D.new()
	exit_marker.name = "RideExit"
	exit_marker.position = Vector3(exit_position.x, maxf(exit_position.y, 1.05), exit_position.z)
	parent.add_child(exit_marker)
	var descriptor: Dictionary = motion_data.duplicate()
	descriptor["display_name"] = String(landmark["display_name"])
	descriptor["boarding_zone"] = boarding_zone
	descriptor["exit_marker"] = exit_marker
	return descriptor

func _create_ride_zone(parent: Node3D, ride_id: StringName, position: Vector3, radius: float) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "RideZone"
	area.position = Vector3(position.x, 0.0, position.z)
	area.collision_layer = 1
	area.collision_mask = 1
	area.monitoring = true
	area.add_to_group("ride_zone")
	area.set_meta("ride_id", ride_id)
	area.set_meta("boarding_radius", radius)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	area.add_child(collision)
	parent.add_child(area)
	return area

func _create_boarding_pad(parent: Node3D, position: Vector3, color: Color, ride_id: StringName) -> void:
	PrimitiveFactory.create_cylinder(parent, 1.4, 0.08, Vector3(position.x, 0.04, position.z), color, false, StringName("BoardingPad_" + String(ride_id)))

func _create_sign(parent: Node3D, sign_text: String, sign_color: Color) -> void:
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "LandmarkSign"
	sign_root.position = Vector3(0.0, 0.0, 3.0)
	parent.add_child(sign_root)
	PrimitiveFactory.create_box(sign_root, Vector3(4.4, 1.15, 0.18), Vector3(0.0, 2.25, 0.0), sign_color, true, &"SignBoard")
	var label: Label3D = Label3D.new()
	label.name = "SignLabel"
	label.text = sign_text
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color("#FFF8E8")
	label.position = Vector3(0.0, 2.25, -0.13)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	sign_root.add_child(label)

func _create_landmark_zone(parent: Node3D, landmark_id: String, display_name: String, radius: float) -> void:
	var area: Area3D = Area3D.new()
	area.name = "LandmarkZone"
	area.collision_layer = 1
	area.collision_mask = 1
	area.monitoring = true
	area.add_to_group("landmark_zone")
	area.set_meta("landmark_id", StringName(landmark_id))
	area.set_meta("display_name", display_name)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = Vector3(0.0, 1.2, 0.0)
	area.add_child(collision)
	parent.add_child(area)
	area.body_entered.connect(_on_landmark_body_entered.bind(area))

func _on_landmark_body_entered(body: Node3D, area: Area3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		var landmark_id: StringName = StringName(String(area.get_meta("landmark_id", "")))
		var display_name: String = String(area.get_meta("display_name", landmark_id))
		landmark_entered.emit(landmark_id, display_name)

func _config_landmarks() -> Array:
	return _landmarks

func _display_node_name(landmark_id: StringName) -> StringName:
	var words: PackedStringArray = String(landmark_id).split("_")
	var result: String = ""
	for word: String in words:
		result += word.capitalize()
	return StringName(result)
