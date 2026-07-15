extends Control

const PLAY_TEX = preload("res://ui/ui/coloredbuttons/playbutton.png")
const PLAYING_TEX = preload("res://ui/ui/coloredbuttons/playing.png")
const NOTIFICATION = preload("res://ui/notification.tscn")

@onready var wheel: CircularContainer = $CanvasLayer/Bottom/Wheel/Container2

@onready var active = wheel.get_node("Click")

@onready var time_slider: HSlider = %TimeSlider
@onready var time_label: Label = %TimeSliderLabel
@onready var play_resume: TextureButton = %PlayResume

@onready var size_slider: HSlider = %SizeSlider

@onready var settings: NinePatchRect = %Settings
@onready var sens_slider: HSlider = %SensSlider
@onready var vol_slider: HSlider = %VolSlider
@onready var cam_button: CheckButton = %CamButton

@onready var notifications = %Notifications

@export var button_inactive_color := Color.from_rgba8(200, 200, 200, 255)
@export var button_pressed_color := Color.from_rgba8(139, 139, 139, 255)

const cursor_arrow = preload("res://ui/cursors/pointer.png")
const cursor_mountain = preload("res://ui/cursors/cursormountain.png")
const cursor_smooth = preload("res://ui/cursors/cursorsmooth.png")
const cursor_shovel = preload("res://ui/cursors/cursorshovel.png")
const cursor_terrain = preload("res://ui/cursors/cursorterrain.png")

func _ready() -> void:
	for button: TextureButton in wheel.get_children():
		_wire_button(button)

	time_slider.value_changed.connect(_on_time_slider_changed)
	time_slider.set_value_no_signal(log(Game.time_scale) / log(2.0) + 1.0)
	_update_time_label()

	size_slider.value_changed.connect(_on_size_slider_changed)
	_on_size_slider_changed(size_slider.value)

	play_resume.pressed.connect(_on_play_resume)
	
	play_resume.mouse_entered.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(play_resume, "modulate", Color.WHITE, 0.06)
	)
	play_resume.mouse_exited.connect(func():
		_return_to_normal(play_resume)
	)
	
	
	_update_play_button()

	Input.set_custom_mouse_cursor(cursor_arrow)

func _on_time_slider_changed(value: float) -> void:
	Game.time_scale = pow(2.0, value - 1.0)
	_update_time_label()

func _update_time_label() -> void:
	time_label.text = " speed: %sx  " % str(Game.time_scale)
	time_slider.tooltip_text = "simulation speed: %sx" % str(Game.time_scale)

func _on_size_slider_changed(value: float) -> void:
	size_slider.tooltip_text = "brush size: %.2fx" % value

func _on_play_resume() -> void:
	if Game.paused:
		Game.resume()
	else:
		Game.pause()
	_update_play_button()

func _update_play_button() -> void:
	play_resume.texture_normal = PLAY_TEX if Game.paused else PLAYING_TEX
	play_resume.tooltip_text = "resume sim" if Game.paused else "pause sim"

func _wire_button(button: TextureButton) -> void:
	button.modulate = button_inactive_color
	button.pressed.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "modulate", button_pressed_color, 0.05)
		tween.tween_property(button, "modulate", Color.WHITE, 0.025)
		await tween.finished
		toggle(button)
	)
	button.mouse_entered.connect(func():
		if button == active:
			return
		var tween = create_tween().set_parallel(true)
		tween.tween_property(button, "offset_transform_scale", Vector2(1.15, 1.15), 0.06)
		tween.tween_property(button, "modulate", Color.WHITE, 0.06)
	)
	button.mouse_exited.connect(func():
		if button == active:
			return
		_return_to_normal(button)
	)

func _return_to_normal(button: Control):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(button, "offset_transform_scale", Vector2(1.0, 1.0), 0.06)
	tween.tween_property(button, "modulate", button_inactive_color, 0.06)

func toggle(thing: Control):
	_return_to_normal(active)
	active = thing
	var tween = create_tween().set_parallel(true)
	tween.tween_property(thing, "modulate", Color.WHITE, 0.025)
	tween.tween_property(thing, "offset_transform_scale", Vector2(1.25, 1.25), 0.06)

	match active.name:
		"Land":
			_set_tool_cursor(cursor_terrain, Vector2(0, 32))
		"Brush":
			_set_tool_cursor(cursor_smooth, Vector2(0, 32))
		"Mountain":
			_set_tool_cursor(cursor_mountain, Vector2(0, 32))
		"Dig":
			_set_tool_cursor(cursor_shovel, Vector2(0, 32))
		"Click":
			_set_tool_cursor(cursor_arrow, Vector2(0, 0))

var _tool_cursor: Texture2D = cursor_arrow
var _tool_hotspot := Vector2.ZERO
var _cursor_on_ui := false

func _set_tool_cursor(tex: Texture2D, hotspot: Vector2) -> void:
	_tool_cursor = tex
	_tool_hotspot = hotspot
	if not _cursor_on_ui:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)

func _refresh_hover_cursor() -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var on_ui := hovered != null and hovered.mouse_filter == Control.MOUSE_FILTER_STOP
	if on_ui == _cursor_on_ui:
		return
	_cursor_on_ui = on_ui
	if on_ui:
		Input.set_custom_mouse_cursor(cursor_arrow)
	else:
		Input.set_custom_mouse_cursor(_tool_cursor, Input.CURSOR_ARROW, _tool_hotspot)

func _on_settings_button_pressed():
	settings.visible = not settings.visible

@onready var day_count_label: Label = %DayCountLabel
@onready var day_time_label: Label = %DayTimeLabel

@onready var island_pop: Label = $"%IslandStats/VBoxContainer2/HBoxContainer3/PopulationCount"
@onready var island_happy: ProgressBar = $"%IslandStats/VBoxContainer2/HBoxContainer/HappinessProgressBar"
@onready var island_homes: Label = $"%IslandStats/VBoxContainer2/HBoxContainer4/HomeCount"
@onready var island_farms: Label = $"%IslandStats/VBoxContainer2/HBoxContainer6/FarmCount"
@onready var _flags_root := $"%IslandStats/VBoxContainer2/HBoxContainer5"
@onready var flag_starving: Label = _flags_root.get_node("StarvingFlag")
@onready var flag_hungry: Label = _flags_root.get_node("HungryFlag")
@onready var flag_growth: Label = _flags_root.get_node("GrowthFlag")
@onready var flag_building: Label = _flags_root.get_node("BuildingFlag")
@onready var flag_cant_build: Label = _flags_root.get_node("CantBuildFlag")
@onready var flag_no_trees: Label = _flags_root.get_node("NoTreesFlag")
@onready var flag_cant_farm: Label = _flags_root.get_node("CantFarmFlag")

@onready var wood_value: Label = %WoodValue
@onready var food_value: Label = %FoodValue

func _process(delta: float) -> void:
	_update_island_stats()
	_refresh_hover_cursor()

	day_count_label.text = str(Game.day)
	var hr = fmod(Game.day_fraction * 24, 12)
	if hr < 1:
		hr = 12
	day_time_label.text = "%02d:%02d " % [hr, fmod(Game.day_fraction * 24 * 60, 60)]
	day_time_label.text += "AM" if Game.day_fraction < 0.5 else "PM"

	if focus_cam:
		if is_instance_valid(focused_folk):
			var heading := _folk_heading(focused_folk)
			_pov_dir = _pov_dir.slerp(heading, 1.0 - pow(0.002, delta))
			_place_pov_cam()
		else:
			_exit_pov()

func _update_island_stats() -> void:
	island_pop.text = str(Game.population)
	island_happy.value = Game.avg_happiness * 100.0
	island_homes.text = str(Game.home_count)
	island_farms.text = str(Game.farm_count)

	wood_value.text = str(Game.total_wood)
	food_value.text = str(roundi(Game.food))

	var starving := Game.food <= 0.0 and Game.population > 0
	flag_starving.visible = starving
	flag_hungry.visible = not starving and Game.hungry()
	flag_growth.visible = Game.prosperous()
	flag_cant_build.visible = Game.cant_build()
	flag_building.visible = not Game.cant_build() and Game.needs_housing()
	flag_no_trees.visible = Game.out_of_resources()
	flag_cant_farm.visible = Game.cant_farm()
func _on_quit_pressed() -> void:
	get_tree().quit()

@onready var name_label: Label = %NameLabel
@onready var homeless_label: Label = %HomelessLabel
@onready var status_label: Label = %StatusLabel
@onready var happiness_bar: ProgressBar = %HappinessProgressBar
@onready var profile: Control = %Profile
@onready var age_label: Label = %AgeLabel
var focused_folk: Folk
var tracking_folk := false

func show_profile(folk: Folk):
	profile.visible = true
	focused_folk = folk

	profile.get_node("VBoxContainer/HBoxContainer/Picture/Body").texture = folk.get_node("Pivot/Sprite/SubViewport/body").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Shirt").texture = folk.get_node("Pivot/Sprite/SubViewport/shirt").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Hair").texture = folk.get_node("Pivot/Sprite/SubViewport/hair").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Hair").modulate = folk.get_node("Pivot/Sprite/SubViewport/hair").modulate

func hide_profile():
	tracking_folk = false
	profile.visible = false
	focused_folk = null

var focus_cam: Camera3D = null
var _prev_cam: Camera3D = null
var _pov_dir := Vector3.FORWARD

const POV_EYE_HEIGHT := 8.0

func _on_pov_button_pressed():
	if not focus_cam:
		if not focused_folk:
			return

		_prev_cam = get_viewport().get_camera_3d()
		focus_cam = Camera3D.new()
		focus_cam.top_level = true
		focused_folk.add_child(focus_cam)
		_pov_dir = _folk_heading(focused_folk)
		_place_pov_cam()
		focus_cam.make_current()
	else:
		_exit_pov()

func _exit_pov():
	if is_instance_valid(focus_cam):
		focus_cam.queue_free()
	focus_cam = null
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null

func _folk_heading(folk: Folk) -> Vector3:
	var d := folk.target_pos - folk.pos
	var flat := Vector3(d.x, 0.0, d.y)
	return flat.normalized() if flat.length() > 0.01 else _pov_dir

func _place_pov_cam() -> void:
	var eye := focused_folk.global_position + Vector3.UP * POV_EYE_HEIGHT * focused_folk.scale.y
	focus_cam.global_position = eye
	focus_cam.look_at(eye + _pov_dir, Vector3.UP)

func _on_deallocate_button_pressed():
	if focused_folk:
		push_notification(focused_folk.name + " was deallocated")
		focused_folk.queue_free()
		hide_profile()

func _on_track_button_pressed():
	if focused_folk:
		tracking_folk = not tracking_folk

func push_notification(msg: String):
	var label = NOTIFICATION.instantiate(0)

	label.text = msg
	notifications.add_child(label)
	notifications.move_child(label, 0)

	await get_tree().create_timer(5.0).timeout

	var tween = get_tree().create_tween()

	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(label.queue_free)
