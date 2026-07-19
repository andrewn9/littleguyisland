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

@onready var settings: Control = %Settings
@onready var sens_slider: HSlider = %SensSlider
@onready var vol_slider: HSlider = %VolSlider
@onready var cam_button: CheckButton = %CamButton
@onready var gfx_button: CheckButton = %GFXButton
@onready var reflections_button: CheckButton = %ReflectionsButton
@onready var outlines_button: CheckButton = %OutlinesButton
@onready var crt_button: CheckButton = %CRTButton

@onready var notifications = %Notifications

@export var button_inactive_color := Color.from_rgba8(200, 200, 200, 255)
@export var button_pressed_color := Color.from_rgba8(139, 139, 139, 255)

const cursor_arrow = preload("res://ui/cursors/pointer.png")
const cursor_mountain = preload("res://ui/cursors/cursormountain.png")
const cursor_smooth = preload("res://ui/cursors/cursorsmooth.png")
const cursor_shovel = preload("res://ui/cursors/cursorshovel.png")
const cursor_terrain = preload("res://ui/cursors/cursorterrain.png")
const cursor_openhand = preload("res://ui/cursors/openhand.png")
const cursor_closehand = preload("res://ui/cursors/closehand.png")
const HAND_HOTSPOT := Vector2(16, 16)

var hovered_folk: Folk = null
var first_play = false

const SETTINGS_PATH := "user://settings.cfg"

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	sens_slider.set_value_no_signal(cfg.get_value("settings", "sensitivity", sens_slider.value))
	%SensLabel.text = "sensitivity: " + str(sens_slider.value)

	vol_slider.set_value_no_signal(cfg.get_value("settings", "volume", vol_slider.value))
	World.volume = vol_slider.value
	%VolLabel.text = "volume: " + str(vol_slider.value)

	cam_button.set_pressed_no_signal(cfg.get_value("settings", "orthographic", cam_button.button_pressed))

	gfx_button.set_pressed_no_signal(cfg.get_value("settings", "low_gfx", gfx_button.button_pressed))
	World.low_gfx = gfx_button.button_pressed

	reflections_button.set_pressed_no_signal(cfg.get_value("settings", "reflections", reflections_button.button_pressed))
	World.reflections = reflections_button.button_pressed

	outlines_button.set_pressed_no_signal(cfg.get_value("settings", "outlines", outlines_button.button_pressed))
	World.outlines = outlines_button.button_pressed

	crt_button.set_pressed_no_signal(cfg.get_value("settings", "crt", crt_button.button_pressed))
	World.crt = crt_button.button_pressed

	first_play = cfg.get_value("game", "first_game", false)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "sensitivity", sens_slider.value)
	cfg.set_value("settings", "volume", vol_slider.value)
	cfg.set_value("settings", "orthographic", cam_button.button_pressed)
	cfg.set_value("settings", "low_gfx", gfx_button.button_pressed)
	cfg.set_value("settings", "reflections", reflections_button.button_pressed)
	cfg.set_value("settings", "outlines", outlines_button.button_pressed)
	cfg.set_value("settings", "crt", crt_button.button_pressed)
	cfg.set_value("game", "first_game", first_play)
	cfg.save(SETTINGS_PATH)


func _ready() -> void:
	_load_settings()

	for button: TextureButton in wheel.get_children():
		_wire_button(button)

	time_slider.value_changed.connect(_on_time_slider_changed)
	time_slider.set_value_no_signal(log(Game.time_scale) / log(2.0) + 1.0)
	_update_time_label()

	size_slider.value_changed.connect(_on_size_slider_changed)
	_on_size_slider_changed(size_slider.value)

	play_resume.pressed.connect(_on_play_resume)

	play_resume.mouse_entered.connect(
		func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(play_resume, "modulate", Color.WHITE, 0.06)
	)
	play_resume.mouse_exited.connect(func(): _return_to_normal(play_resume))

	_update_play_button()

	Input.set_custom_mouse_cursor(cursor_arrow)

	_build_layers_menu()
	_make_profile_draggable()
	brush_size.visible = _drawing_tool()

	monkey_anim.animation_finished.connect(_on_monkey_anim_done)
	monkey_anim.play("idle")

	talk_sound.finished.connect(_on_talk_sound_finished)


const LAYERS := {
	"island": "terrain geometry",
	"nature": "trees, rocks, grass, bushes and clouds",
	"animals": "the wildlife",
	"buildings": "homes, farms, farmsteads and wells",
	"folk": "the little guys",
}

@onready var layers_list: VBoxContainer = %LayersList
@onready var tutorial := %Tutorial


func start_tutorial() -> void:
	tutorial.start()


func begin_world(fresh: bool) -> void:
	tutorial.begin_world(fresh)


func _build_layers_menu() -> void:
	for key in LAYERS:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = true  # ticked = solid
		cb.add_theme_font_size_override("font_size", 12)
		cb.tooltip_text = "%s\n(untick to make it see-through)" % LAYERS[key]
		cb.toggled.connect(func(on: bool): Game.set_layer_opaque(key, on))
		layers_list.add_child(cb)


func _on_time_slider_changed(value: float) -> void:
	Game.time_scale = pow(2.0, value - 1.0)
	_update_time_label()


func _update_time_label() -> void:
	time_label.text = " speed: %sx  " % str(Game.time_scale)
	time_slider.tooltip_text = "simulation speed: %sx" % str(Game.time_scale)


@onready var brush_size: VBoxContainer = %BrushSize
@onready var brush_size_label: Label = %BrushSizeLabel


func _on_size_slider_changed(value: float) -> void:
	brush_size_label.text = "brush size: %.2fx" % value
	size_slider.tooltip_text = "brush size: %.2fx" % value


func _drawing_tool():
	return active.name != "Click"


func _on_play_resume() -> void:
	if Game.paused:
		Game.resume()
	else:
		Game.pause()
	%"Paused?".visible = Game.paused
	_update_play_button()


func _update_play_button() -> void:
	play_resume.texture_normal = PLAY_TEX if Game.paused else PLAYING_TEX
	play_resume.tooltip_text = "resume sim" if Game.paused else "pause sim"


func _wire_button(button: TextureButton) -> void:
	button.modulate = button_inactive_color
	button.pressed.connect(
		func():
			var tween = create_tween()
			tween.tween_property(button, "modulate", button_pressed_color, 0.05)
			tween.tween_property(button, "modulate", Color.WHITE, 0.025)
			await tween.finished
			toggle(button)
	)
	button.mouse_entered.connect(
		func():
			if button == active:
				return
			var tween = create_tween().set_parallel(true)
			tween.tween_property(button, "offset_transform_scale", Vector2(1.15, 1.15), 0.06)
			tween.tween_property(button, "modulate", Color.WHITE, 0.06)
	)
	button.mouse_exited.connect(
		func():
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

	brush_size.visible = _drawing_tool()

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
	_cursor_key = "" # let _refresh_hover_cursor reapply next frame


var _cursor_key := "" # what's currently shown, so we only reset on a change

var grabbed_folk: Folk = null
var grab_screen := Vector2.ZERO
var dragging_folk := false

func _refresh_hover_cursor() -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	_cursor_on_ui = hovered != null and hovered.mouse_filter == Control.MOUSE_FILTER_STOP

	# priority: UI first, then grabbing a folk, then hovering one, else the tool
	var tex := _tool_cursor
	var hotspot := _tool_hotspot
	var key := "tool"
	if _cursor_on_ui:
		tex = cursor_arrow
		hotspot = Vector2.ZERO
		key = "ui"
	elif is_instance_valid(grabbed_folk):
		tex = cursor_closehand
		hotspot = HAND_HOTSPOT
		key = "grab"
	elif is_instance_valid(hovered_folk):
		tex = cursor_openhand
		hotspot = HAND_HOTSPOT
		key = "hover"

	if key == _cursor_key:
		return
	_cursor_key = key
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)


func _on_settings_button_pressed():
	settings.visible = not settings.visible


@onready var day_count_label: Label = %DayCountLabel
@onready var day_time_label: Label = %DayTimeLabel

@onready var island_pop: Label = $"%IslandStats/VBoxContainer2/HBoxContainer3/PopulationCount"
@onready var island_happy: ProgressBar = $"%IslandStats/VBoxContainer2/HBoxContainer/HappinessProgressBar"
@onready var island_homes: Label = $"%IslandStats/VBoxContainer2/HBoxContainer4/HomeCount"
@onready var island_farms: Label = $"%IslandStats/VBoxContainer2/HBoxContainer4/FarmCount"
@onready var _flags_root := $"%IslandStats/VBoxContainer2/HBoxContainer5"
@onready var flag_starving: Label = _flags_root.get_node("StarvingFlag")
@onready var flag_hungry: Label = _flags_root.get_node("HungryFlag")
@onready var flag_growth: Label = _flags_root.get_node("GrowthFlag")
@onready var flag_building: Label = _flags_root.get_node("BuildingFlag")
@onready var flag_cant_build: Label = _flags_root.get_node("CantBuildFlag")
@onready var flag_no_trees: Label = _flags_root.get_node("NoTreesFlag")
@onready var flag_cant_farm: Label = _flags_root.get_node("CantFarmFlag")
@onready var flag_no_space: Label = _flags_root.get_node("NoSpaceFlag")

@onready var wood_value: Label = %WoodValue
@onready var food_value: Label = %FoodValue
@onready var stone_value: Label = %StoneValue
@onready var animal_value: Label = %AnimalValue

var hide_ui_setting = false

func _process(delta: float) -> void:
	$CanvasLayer.visible = is_instance_valid(Game.model)
	if (hide_ui_setting):
		$CanvasLayer.visible = false
	
	if not is_instance_valid(Game.model):
		return
	_update_island_stats()
	_refresh_hover_cursor()
	_tick_speech(delta)
	if profile.visible and not is_instance_valid(focused_folk):
		hide_profile()

	day_count_label.text = str(Game.day)
	var hr = fmod(Game.day_fraction * 24, 12)
	if hr < 1:
		hr = 12
	day_time_label.text = "%02d:%02d " % [hr, fmod(Game.day_fraction * 24 * 60, 60)]
	day_time_label.text += "AM" if Game.day_fraction < 0.5 else "PM"


	if _in_pov:
		if is_instance_valid(focused_folk) and is_instance_valid(focus_cam):
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
	stone_value.text = str(roundi(Game.rock))
	animal_value.text = str(Game.animals)

	var starving := Game.food <= 0.0 and Game.population > 0
	flag_starving.visible = starving
	flag_hungry.visible = not starving and Game.hungry()
	flag_growth.visible = Game.prosperous()
	flag_cant_build.visible = Game.cant_build()
	flag_building.visible = not Game.cant_build() and Game.needs_housing()
	flag_no_trees.visible = Game.out_of_resources()
	flag_cant_farm.visible = Game.cant_farm()
	flag_no_space.visible = Game.no_build_space()


func _on_quit_pressed() -> void:
	Game.autosave()
	Game.skip_boot = true
	monkey_clear()
	get_tree().change_scene_to_file("res://menu.tscn")


@onready var name_label: Label = %NameLabel
@onready var homeless_label: Label = %HomelessLabel
@onready var status_label: Label = %StatusLabel
@onready var happiness_bar: ProgressBar = %HappinessProgressBar
@onready var food_bar: ProgressBar = %FoodProgress
@onready var profile: Control = %Profile
@onready var age_label: Label = %AgeLabel
var focused_folk: Folk
var tracking_folk := false

var _profile_pos := Vector2.INF
var _dragging_profile := false
var _drag_grab := Vector2.ZERO

var _profile_anchored := false


func _make_profile_draggable() -> void:
	profile.gui_input.connect(_on_profile_gui_input)
	for n in _descendants(profile):
		if n is Label or n is TextureRect or n is Container:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _descendants(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out


func _on_profile_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_profile = event.pressed
		if event.pressed:
			_drag_grab = profile.get_global_mouse_position() - profile.global_position
	elif event is InputEventMouseMotion and _dragging_profile:
		_place_profile(profile.get_global_mouse_position() - _drag_grab)


func _place_profile(p: Vector2) -> void:
	var vp := get_viewport_rect().size
	p.x = clampf(p.x, 0.0, maxf(0.0, vp.x - profile.size.x))
	p.y = clampf(p.y, 0.0, maxf(0.0, vp.y - profile.size.y))
	profile.global_position = p
	_profile_pos = p


func toggle_profile(folk: Folk):
	if not is_instance_valid(folk):
		return
	if focused_folk == folk:
		hide_profile()
	else:
		show_profile(folk)

func show_profile(folk: Folk):
	profile.visible = true
	focused_folk = folk

	if not _profile_anchored:
		profile.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		_profile_anchored = true
	_place_profile(_profile_pos if _profile_pos.is_finite() else profile.global_position)

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
var _in_pov := false
var _pov_dir := Vector3.FORWARD

const POV_EYE_HEIGHT := 9.0


func _on_pov_button_pressed():
	if not _in_pov:
		if not is_instance_valid(focused_folk):
			return

		_in_pov = true
		tracking_folk = false

		_prev_cam = get_viewport().get_camera_3d()
		focus_cam = Camera3D.new()
		focus_cam.top_level = true
		focused_folk.add_child(focus_cam)
		_pov_dir = _folk_heading(focused_folk)
		_place_pov_cam()
		focus_cam.make_current()

		focused_folk.visible = false
	else:
		_exit_pov()


func _exit_pov():
	_in_pov = false
	if is_instance_valid(focused_folk):
		focused_folk.visible = true

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
		push_alert(focused_folk.name + " was deallocated")
		focused_folk.queue_free()
		hide_profile()


func _on_track_button_pressed():
	if focused_folk:
		tracking_folk = not tracking_folk
		if tracking_folk and _in_pov:
			_exit_pov()

func _on_gfx_button_toggled(toggled_on: bool):
	World.low_gfx = toggled_on
	_save_settings()

const ALERT_COLOR := Color("#ff4d4d")


func push_alert(msg: String):
	push_notification(msg, ALERT_COLOR)


func push_notification(msg: String, color := Color.WHITE):
	var label = NOTIFICATION.instantiate()

	if color != Color.WHITE:
		msg = "[color=#%s]%s[/color]" % [color.to_html(false), msg]
	label.text = msg
	notifications.add_child(label)
	notifications.move_child(label, 0)

	await get_tree().create_timer(5.0).timeout

	var tween = get_tree().create_tween()

	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(label.queue_free)

@onready var monkey_anim: AnimationPlayer = %MonkeyAnim
@onready var bubble: NinePatchRect = %MonkeyBubble
@onready var bubble_label: RichTextLabel = %MonkeyBubbleLabel

const BUBBLE_MAX_WIDTH := 180.0
const BUBBLE_MIN_WIDTH := 80.0
const BUBBLE_TAIL_X := 10.0

const BUBBLE_PAD_L := 10.0
const BUBBLE_PAD_R := 12.0
const BUBBLE_PAD_T := 8.0
const BUBBLE_PAD_B := 14.0
const TALKS := ["talk1", "talk2"]

@onready var talk_sound: AudioStreamPlayer = %TalkSound
var talk_sfx: Array[AudioStream] = [
	preload("res://sfx/talk1.ogg"),
	preload("res://sfx/talk2.ogg"),
	preload("res://sfx/talk3.ogg"),
	preload("res://sfx/talk4.ogg"),
	preload("res://sfx/talk5.ogg"),
]
const TALK_PITCH := Vector2(0.92, 1.12)

func _play_talk_sfx() -> void:
	talk_sound.stream = talk_sfx.pick_random()
	talk_sound.pitch_scale = randf_range(TALK_PITCH.x, TALK_PITCH.y)
	talk_sound.play()


func _on_talk_sound_finished() -> void:
	if _flap_left > 0.0 and is_instance_valid(Game.model):
		_play_talk_sfx()

var _speech_left := 0.0
var _flap_left := 0.0

func _flap_time(text: String) -> float:
	return clampf(0.6 + text.split(" ").size() * 0.18, 0.8, 5.0)

func monkey_say(text: String, seconds := 8.0) -> void:
	bubble_label.text = text
	_fit_bubble()
	bubble.visible = true
	_speech_left = seconds
	_flap_left = _flap_time(text)
	monkey_anim.play(TALKS.pick_random())
	_play_talk_sfx()


func monkey_hold(text: String) -> void:
	monkey_say(text, 0.0)


func monkey_clear() -> void:
	_speech_left = 0.0
	_flap_left = 0.0
	bubble.visible = false
	monkey_anim.play("idle")
	talk_sound.stop()

func _fit_bubble() -> void:
	var max_text_w := BUBBLE_MAX_WIDTH - BUBBLE_PAD_L - BUBBLE_PAD_R
	bubble_label.position = Vector2(BUBBLE_PAD_L, BUBBLE_PAD_T)
	bubble_label.size = Vector2(max_text_w, 0)
	var text_w = minf(bubble_label.get_content_width(), max_text_w)
	text_w = maxf(text_w, BUBBLE_MIN_WIDTH - BUBBLE_PAD_L - BUBBLE_PAD_R)

	bubble_label.size = Vector2(text_w, 0)
	var text_h = bubble_label.get_content_height()
	bubble_label.size = Vector2(text_w, text_h)

	var w = text_w + BUBBLE_PAD_L + BUBBLE_PAD_R
	var h = BUBBLE_PAD_T + text_h + BUBBLE_PAD_B
	bubble.size = Vector2(w, h)
	bubble.position = Vector2(BUBBLE_TAIL_X, -bubble.size.y)

func _tick_speech(delta: float) -> void:
	if _flap_left > 0.0:
		_flap_left -= delta
	if _speech_left <= 0.0:
		return
	_speech_left -= delta
	if _speech_left <= 0.0:
		bubble.visible = false
		monkey_anim.play("idle")

func _on_reflections_button_toggled(toggled_on: bool):
	World.reflections = toggled_on
	_save_settings()


func _on_outlines_button_toggled(toggled_on: bool):
	World.outlines = toggled_on
	_save_settings()


func _on_crt_button_toggled(toggled_on: bool):
	World.crt = toggled_on
	_save_settings()


func _on_cam_button_toggled(_toggled_on: bool) -> void:
	_save_settings()


func _on_vol_slider_value_changed(value: float):
	World.volume = value
	%VolLabel.text = "volume: " + str(value)
	_save_settings()


func _on_sens_slider_value_changed(value: float) -> void:
	%SensLabel.text = "sensitivity: " + str(value)
	_save_settings()

func _on_hide_button_pressed():
	print("im hidden king ")
	hide_ui_setting = true

func _unhandled_input(event):
	if hide_ui_setting and event is InputEventMouseButton and event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.pressed:
		hide_ui_setting = false

func _on_monkey_anim_done(_anim: StringName) -> void:
	monkey_anim.play(TALKS.pick_random() if _flap_left > 0.0 else "idle")
