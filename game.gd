extends Node3D


func _ready() -> void:
	for tex in MapData.layers.values():
		var ui = TextureRect.new()
		ui.texture = tex
		%Debug.add_child(ui)


func _process(delta: float) -> void:
	pass
