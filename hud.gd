extends Control

@onready var wheel: CircularContainer = $CanvasLayer/Bottom/Wheel/Container2

@onready var active = wheel.get_node("Click")

@export var button_inactive_color := Color.from_rgba8(200, 200, 200, 255)
@export var button_pressed_color := Color.from_rgba8(139, 139, 139, 255)

func _ready() -> void:
	for button: TextureButton in wheel.get_children():
		_wire_button(button)

func _wire_button(button: TextureButton) -> void:
	button.modulate = button_inactive_color
	button.pressed.connect(func():
		var tween = create_tween()
		print("modulating")
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
	print("finished, white")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(thing, "modulate", Color.WHITE, 0.025)
	tween.tween_property(thing, "offset_transform_scale", Vector2(1.25, 1.25), 0.06)

func _process(delta: float) -> void:
	pass
