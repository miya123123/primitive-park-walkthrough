extends CanvasLayer

const KartMath = preload("res://src/core/kart_math.gd")

var _overlay: Control
var _top_left: VBoxContainer
var _controls_label: Label
var _race_panel: PanelContainer
var _race_label: Label
var _location_banner: PanelContainer
var _location_label: Label
var _ride_banner: PanelContainer
var _ride_label: Label
var _display_seconds: float = 0.0
var _location_token: int = 0

## Receives UI timing values from park configuration.
func configure(settings: Dictionary) -> void:
	_display_seconds = float(settings.get("location_display_seconds", 0.0))

## Connects the HUD to player events without polling player state.
func connect_player(player: Node) -> void:
	var callback: Callable = Callable(self, "_on_location_changed")
	if player.has_signal(&"location_changed") and not player.is_connected(&"location_changed", callback):
		player.connect(&"location_changed", callback)

## Connects the HUD to ride availability and state events.
func connect_ride_coordinator(coordinator: Node) -> void:
	var callback: Callable = Callable(self, "_on_ride_prompt_changed")
	if coordinator.has_signal(&"ride_prompt_changed") and not coordinator.is_connected(&"ride_prompt_changed", callback):
		coordinator.connect(&"ride_prompt_changed", callback)
	var progress_callback: Callable = Callable(self, "_on_ride_progress_changed")
	if coordinator.has_signal(&"ride_progress_changed") and not coordinator.is_connected(&"ride_progress_changed", progress_callback):
		coordinator.connect(&"ride_progress_changed", progress_callback)

## Shows the persistent welcome message.
func show_welcome() -> void:
	var welcome: Label = _overlay.get_node("TopLeft/Welcome") as Label
	welcome.text = tr("HUD_WELCOME")

## Shows a landmark name for the configured duration.
func show_location(display_name: String) -> void:
	_location_token += 1
	var token: int = _location_token
	_location_label.text = tr("HUD_LOCATION").replace("{name}", display_name)
	_location_banner.show()
	_hide_location_later(token)

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_safe_area()

func _on_location_changed(display_name: String) -> void:
	show_location(display_name)

func _on_ride_prompt_changed(state: StringName, display_name: String) -> void:
	show_ride_prompt(state, display_name)

func _on_ride_progress_changed(ride_id: StringName, snapshot: Dictionary) -> void:
	if ride_id == &"go_kart":
		show_ride_progress(snapshot)
	elif ride_id == &"free_fall_tower":
		show_free_fall_progress(snapshot)

## Shows the free-fall stage as a concise event-driven ride banner.
func show_free_fall_progress(snapshot: Dictionary) -> void:
	if _ride_banner == null:
		return
	var status: StringName = StringName(String(snapshot.get("status", "")))
	if status == &"decorative" or status == &"boarding":
		return
	var key: StringName = &"HUD_FREE_FALL_ASCENDING"
	if status == &"suspense":
		key = &"HUD_FREE_FALL_SUSPENSE"
	elif status == &"dropping" or status == &"braking":
		key = &"HUD_FREE_FALL_DROPPING"
	elif status == &"settling":
		key = &"HUD_FREE_FALL_SETTLING"
	_ride_label.text = tr(key)
	_ride_banner.show()

## Shows the kart's event-driven countdown, lap, timer, and result panel.
func show_ride_progress(snapshot: Dictionary) -> void:
	if _race_panel == null:
		return
	var status: StringName = StringName(String(snapshot.get("status", "")))
	if status == &"decorative" or status == &"boarding":
		_race_panel.hide()
		if _controls_label != null:
			_controls_label.text = tr("HUD_CONTROLS")
		return
	if _location_banner != null:
		_location_banner.hide()
	var lap: int = int(snapshot.get("lap", 1))
	var lap_count: int = int(snapshot.get("lap_count", 3))
	var time_seconds: float = float(snapshot.get("time_seconds", 0.0))
	var best_seconds: float = float(snapshot.get("best_seconds", 0.0))
	var best_text: String = KartMath.format_time(best_seconds) if best_seconds > 0.0 else "--:--.--"
	if status == &"countdown":
		_race_label.text = tr("HUD_KART_COUNTDOWN").replace("{seconds}", str(int(ceilf(float(snapshot.get("countdown_seconds", 0.0))))))
	elif status == &"finished":
		_race_label.text = tr("HUD_KART_FINISH").replace("{time}", KartMath.format_time(float(snapshot.get("result_seconds", time_seconds)))).replace("{best}", best_text)
	else:
		_race_label.text = tr("HUD_KART_RACE").replace("{lap}", str(lap)).replace("{laps}", str(lap_count)).replace("{time}", KartMath.format_time(time_seconds)).replace("{best}", best_text)
	_race_panel.show()
	if _controls_label != null:
		_controls_label.text = tr("HUD_KART_CONTROLS")

## Shows an event-driven ride prompt without polling gameplay state.
func show_ride_prompt(state: StringName, display_name: String) -> void:
	if _ride_banner == null or display_name.is_empty():
		if _ride_banner != null:
			_ride_banner.hide()
		return
	var key: StringName = &"HUD_RIDE_AVAILABLE"
	if state == &"waiting":
		key = &"HUD_RIDE_WAITING"
	elif state == &"riding":
		key = &"HUD_RIDE_RUNNING"
		if _location_banner != null:
			_location_banner.hide()
	_ride_label.text = tr(key).replace("{name}", display_name)
	_ride_banner.show()

func _hide_location_later(token: int) -> void:
	await get_tree().create_timer(_display_seconds).timeout
	if token == _location_token and is_instance_valid(_location_banner):
		_location_banner.hide()

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_top_left = VBoxContainer.new()
	_top_left.name = "TopLeft"
	_top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_left.offset_left = 24.0
	_top_left.offset_top = 24.0
	_top_left.offset_right = 470.0
	_top_left.offset_bottom = 112.0
	_top_left.add_theme_constant_override("separation", 8)
	_overlay.add_child(_top_left)

	var controls_panel: PanelContainer = PanelContainer.new()
	controls_panel.name = "ControlsPanel"
	controls_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.11, 0.20, 0.78), Color("#FCE7A8")))
	_top_left.add_child(controls_panel)
	var controls: Label = Label.new()
	controls.name = "Controls"
	controls.text = tr("HUD_CONTROLS")
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color("#FFF8E8"))
	controls.add_theme_constant_override("outline_size", 4)
	controls.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.8))
	controls_panel.add_child(controls)
	_controls_label = controls

	var welcome: Label = Label.new()
	welcome.name = "Welcome"
	welcome.text = tr("HUD_WELCOME")
	welcome.add_theme_font_size_override("font_size", 18)
	welcome.add_theme_color_override("font_color", Color("#FFE18A"))
	welcome.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.10, 0.9))
	welcome.add_theme_constant_override("outline_size", 6)
	_top_left.add_child(welcome)

	_location_banner = PanelContainer.new()
	_location_banner.name = "LocationBanner"
	_location_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_location_banner.offset_left = -220.0
	_location_banner.offset_top = -92.0
	_location_banner.offset_right = 220.0
	_location_banner.offset_bottom = -42.0
	_location_banner.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.08, 0.25, 0.90), Color("#FFD166")))
	_overlay.add_child(_location_banner)
	_location_label = Label.new()
	_location_label.name = "LocationLabel"
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_location_label.add_theme_font_size_override("font_size", 18)
	_location_label.add_theme_color_override("font_color", Color("#FFF8E8"))
	_location_banner.add_child(_location_label)
	_location_banner.hide()

	_ride_banner = PanelContainer.new()
	_ride_banner.name = "RideBanner"
	_ride_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ride_banner.offset_left = -250.0
	_ride_banner.offset_top = -154.0
	_ride_banner.offset_right = 250.0
	_ride_banner.offset_bottom = -104.0
	_ride_banner.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.20, 0.25, 0.94), Color("#7DE2D1")))
	_overlay.add_child(_ride_banner)
	_ride_label = Label.new()
	_ride_label.name = "RideLabel"
	_ride_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ride_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ride_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ride_label.add_theme_font_size_override("font_size", 18)
	_ride_label.add_theme_color_override("font_color", Color("#FFF8E8"))
	_ride_banner.add_child(_ride_label)
	_ride_banner.hide()

	_race_panel = PanelContainer.new()
	_race_panel.name = "KartRacePanel"
	_race_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_race_panel.offset_left = -370.0
	_race_panel.offset_top = 24.0
	_race_panel.offset_right = -24.0
	_race_panel.offset_bottom = 112.0
	_race_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.12, 0.20, 0.92), Color("#FFCF5C")))
	_overlay.add_child(_race_panel)
	_race_label = Label.new()
	_race_label.name = "KartRaceLabel"
	_race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_race_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_label.add_theme_font_size_override("font_size", 17)
	_race_label.add_theme_color_override("font_color", Color("#FFF8E8"))
	_race_panel.add_child(_race_label)
	_race_panel.hide()

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_top = 9.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 9.0
	return style

func _on_viewport_size_changed() -> void:
	_apply_safe_area()

func _apply_safe_area() -> void:
	if _top_left == null or _location_banner == null or _ride_banner == null or _race_panel == null:
		return
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var left_inset: float = 24.0
	var top_inset: float = 24.0
	var bottom_inset: float = 42.0
	var right_inset: float = 24.0
	if safe_area.size.x > 0 and window_size.x > 0:
		left_inset = maxf(left_inset, float(safe_area.position.x) + 12.0)
		top_inset = maxf(top_inset, float(safe_area.position.y) + 12.0)
		bottom_inset = maxf(bottom_inset, float(window_size.y - safe_area.end.y) + 24.0)
		right_inset = maxf(right_inset, float(window_size.x - safe_area.end.x) + 12.0)
	_top_left.offset_left = left_inset
	_top_left.offset_top = top_inset
	_race_panel.offset_right = -right_inset
	_race_panel.offset_top = top_inset
	_location_banner.offset_bottom = -bottom_inset
	_ride_banner.offset_bottom = -(bottom_inset + 62.0)
