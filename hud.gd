extends Control

@onready var tools = $CanvasLayer/Toolbar
var active := "Click"

func _ready() -> void:
	for button: TextureButton in tools.get_children():
		button.pressed.connect(func(): 
			toggle(button.name)
		)
		button.mouse_entered.connect(func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(button, "offset_transform_scale", Vector2(1.5, 1.5), 0.2)
		)
		button.mouse_exited.connect(func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(button, "offset_transform_scale", Vector2(1.0, 1.0), 0.2)
		)

func toggle(name: StringName):
	active = name

func _process(delta: float) -> void:
	pass
