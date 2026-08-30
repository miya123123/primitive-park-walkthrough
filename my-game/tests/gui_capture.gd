extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")

## Captures deterministic runtime frames for local visual QA; not part of gameplay.
func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_instance: Node = MainScene.instantiate()
	root.add_child(main_instance)
	var generated_park: Node = main_instance.get_node("Park/GeneratedPark")
	for step: int in range(4):
		await process_frame
		await physics_frame
	var park: Node = generated_park
	_save_viewport("/private/tmp/primitive_park_initial_20260828.png")
	var descriptors: Dictionary = park.call("get_ride_descriptors")
	var player: Node = main_instance.get_node("Player")
	var kart_zone: Area3D = descriptors["go_kart"]["boarding_zone"] as Area3D
	player.global_position = kart_zone.global_position + Vector3(0.0, 1.05, 0.0)
	player.velocity = Vector3.ZERO
	for step: int in range(8):
		await physics_frame
		await process_frame
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	player.call("_unhandled_input", event)
	for step: int in range(3):
		await process_frame
		await physics_frame
	_save_viewport("/private/tmp/primitive_park_kart_hud_20260828.png")
	var kart_exit: InputEventKey = InputEventKey.new()
	kart_exit.keycode = KEY_E
	kart_exit.pressed = true
	player.call("_unhandled_input", kart_exit)
	var free_fall_zone: Area3D = descriptors["free_fall_tower"]["boarding_zone"] as Area3D
	player.global_position = free_fall_zone.global_position + Vector3(0.0, 1.05, 0.0)
	player.velocity = Vector3.ZERO
	for step: int in range(8):
		await physics_frame
		await process_frame
	var free_fall_event: InputEventKey = InputEventKey.new()
	free_fall_event.keycode = KEY_E
	free_fall_event.pressed = true
	player.call("_unhandled_input", free_fall_event)
	var free_fall_provider: Node = park.call("get_ride_providers")["free_fall_tower"] as Node
	if not player.call("is_riding"):
		main_instance.get_node("Park/RideCoordinator").call("_on_ride_body_entered", player, &"free_fall_tower")
		player.call("_unhandled_input", free_fall_event)
	free_fall_provider.set_process(false)
	free_fall_provider.call("advance_simulation", 0.8)
	free_fall_provider.call("advance_simulation", 4.2)
	await process_frame
	await physics_frame
	await process_frame
	_save_viewport("/private/tmp/primitive_park_freefall_suspense_20260828.png")
	main_instance.free()
	for cleanup_step: int in range(4):
		await process_frame
	quit(0)

func _save_viewport(path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(path)
