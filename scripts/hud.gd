extends Control

const PLAY_TEX = preload("res://ui/ui/coloredbuttons/playbutton.png")
const PLAYING_TEX = preload("res://ui/ui/coloredbuttons/playing.png")

@onready var wheel: CircularContainer = $CanvasLayer/Bottom/Wheel/Container2

@onready var active = wheel.get_node("Click")

@onready var time_slider: HSlider = %TimeSlider
@onready var time_label: Label = %TimeSliderLabel
@onready var play_resume: TextureButton = %PlayResume

@onready var size_slider: HSlider = %SizeSlider
@onready var stats_label: Label = %Stats

@onready var settings: NinePatchRect = %Settings
@onready var sens_slider: HSlider = %SensSlider
@onready var vol_slider: HSlider = %VolSlider
@onready var cam_button: CheckButton = %CamButton

@export var button_inactive_color := Color.from_rgba8(200, 200, 200, 255)
@export var button_pressed_color := Color.from_rgba8(139, 139, 139, 255)

var cursor_arrow = preload("res://ui/cursors/pointer.png")

func _ready() -> void:
	for button: TextureButton in wheel.get_children():
		_wire_button(button)

	time_slider.value_changed.connect(_on_time_slider_changed)
	time_slider.set_value_no_signal(log(Game.time_scale) / log(2.0) + 1.0)
	_update_time_label()

	play_resume.pressed.connect(_on_play_resume)
	_update_play_button()

	Input.set_custom_mouse_cursor(cursor_arrow)


func _on_time_slider_changed(value: float) -> void:
	Game.time_scale = pow(2.0, value - 1.0)
	_update_time_label()

func _update_time_label() -> void:
	time_label.text = " speed: %sx  " % str(Game.time_scale)

func _on_play_resume() -> void:
	if Game.paused:
		Game.resume()
	else:
		Game.pause()
	_update_play_button()

func _update_play_button() -> void:
	play_resume.texture_normal = PLAY_TEX if Game.paused else PLAYING_TEX

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

func _on_settings_button_pressed():
	settings.visible = not settings.visible

func _process(delta: float) -> void:
	stats_label.text = "Day %d\nPop: %d\nHappy: %d%%\nWood: %d\nFood: %d%s%s\n farms:%d" % [
		Game.day, Game.population, roundi(Game.avg_happiness * 100.0),
		Game.total_wood, roundi(Game.food),
		"\n hungry" if Game.hungry() else "",
		"\n growth+" if Game.prosperous() else "",
		Game.farm_count
	]

func _on_quit_pressed() -> void:
	get_tree().quit()

@onready var name_label: Label = %NameLabel
@onready var profile: NinePatchRect = %Profile
var focused_folk: Folk
var tracking_folk := false

func show_profile(folk: Folk):
	profile.visible = true
	focused_folk = folk
	name_label.text = folk.name

	profile.get_node("VBoxContainer/HBoxContainer/Picture/Body").texture = folk.get_node("Pivot/Sprite/SubViewport/body").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Shirt").texture = folk.get_node("Pivot/Sprite/SubViewport/shirt").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Hair").texture = folk.get_node("Pivot/Sprite/SubViewport/hair").texture
	profile.get_node("VBoxContainer/HBoxContainer/Picture/Hair").modulate = folk.get_node("Pivot/Sprite/SubViewport/hair").modulate

func hide_profile():
	tracking_folk = false
	profile.visible = false
	focused_folk = null

var focus_cam: Camera3D = null

func _on_pov_button_pressed():
	if not focus_cam:
		if not focused_folk:
			return

		focus_cam = Camera3D.new()
		focused_folk.add_child(focus_cam)
		focus_cam.make_current()
	else:
		focus_cam.queue_free()
		focus_cam = null

func _on_deallocate_button_pressed():
	if focused_folk:
		focused_folk.queue_free()
		hide_profile()

func _on_track_button_pressed():
	if focused_folk:
		tracking_folk = not tracking_folk
