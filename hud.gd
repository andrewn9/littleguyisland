extends Control

@onready var tools = $CanvasLayer/Toolbar
var active := "Click"

func _ready() -> void:
	for button: TextureButton in tools.get_children():
		button.pressed.connect(func(): 
			toggle(button.name)
		)

func toggle(name: StringName):
	active = name

func _process(delta: float) -> void:
	pass
