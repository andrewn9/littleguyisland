extends ColorRect

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var mat = material as ShaderMaterial

	mat.set_shader_parameter("resolution", get_viewport().get_visible_rect().size / 2)
