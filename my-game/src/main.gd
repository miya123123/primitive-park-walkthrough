extends Node3D

const CONFIG_PATH: String = "res://assets/data/park_config.json"
const ParkConfig = preload("res://src/core/park_config.gd")
const ParkBuilder = preload("res://src/gameplay/park_builder.gd")
const RideCoordinator = preload("res://src/gameplay/ride_coordinator.gd")

@onready var park_root: Node3D = $Park
@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD

var _config: Dictionary = {}

## Loads configuration, builds the park, and connects the event-driven HUD.
func _ready() -> void:
	_ensure_input_actions()
	_config = ParkConfig.load_from_file(CONFIG_PATH)
	var errors: PackedStringArray = ParkConfig.validate(_config)
	if not errors.is_empty():
		for error: String in errors:
			push_error("Park configuration: " + error)
		get_tree().quit(1)
		return
	_configure_environment()
	var builder: ParkBuilder = ParkBuilder.new()
	builder.name = "GeneratedPark"
	park_root.add_child(builder)
	builder.build(_config)
	builder.landmark_entered.connect(_on_landmark_entered)
	player.call("configure", _config["player"])
	var spawn_position: Vector3 = ParkConfig.vector3_from_array(_config.get("spawn_position", [0.0, 1.05, 31.0]))
	player.global_position = spawn_position
	hud.call("configure", _config["ui"])
	hud.call("connect_player", player)
	var ride_coordinator: RideCoordinator = RideCoordinator.new()
	ride_coordinator.name = "RideCoordinator"
	park_root.add_child(ride_coordinator)
	ride_coordinator.configure(player, builder.get_attraction_animator())
	ride_coordinator.ride_prompt_changed.connect(_on_ride_prompt_changed)
	var ride_descriptors: Dictionary = builder.get_ride_descriptors()
	var ride_providers: Dictionary = builder.get_ride_providers()
	for ride_id: StringName in [&"ferris_wheel", &"roller_coaster", &"carousel", &"free_fall_tower", &"go_kart"]:
		var descriptor: Dictionary = ride_descriptors.get(ride_id, {})
		var boarding_zone: Area3D = descriptor.get("boarding_zone") as Area3D
		if boarding_zone != null:
			ride_coordinator.register_ride(ride_id, String(descriptor.get("display_name", ride_id)), boarding_zone, ride_providers.get(ride_id) as Node)
	hud.call("connect_ride_coordinator", ride_coordinator)
	hud.call("show_welcome")

func _on_landmark_entered(_landmark_id: StringName, display_name: String) -> void:
	hud.call("show_location", display_name)

func _on_ride_prompt_changed(state: StringName, display_name: String) -> void:
	hud.call("show_ride_prompt", state, display_name)

func _configure_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "DaylightEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#58B7EF")
	sky_material.sky_horizon_color = Color("#DDF5FF")
	sky_material.ground_bottom_color = Color("#8BC7A5")
	sky_material.ground_horizon_color = Color("#F6D6A1")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.ambient_light_color = Color("#F4F7FF")
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#FFF1D0")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _ensure_input_actions() -> void:
	_add_key_action(&"move_forward", KEY_W)
	_add_key_action(&"move_back", KEY_S)
	_add_key_action(&"move_left", KEY_A)
	_add_key_action(&"move_right", KEY_D)
	_add_key_action(&"jump", KEY_SPACE)
	_add_key_action(&"sprint", KEY_SHIFT)
	_add_key_action(&"interact", KEY_E)
	_add_key_action(&"kart_brake", KEY_SHIFT)

func _add_key_action(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
