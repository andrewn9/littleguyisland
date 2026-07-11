class_name Entity extends Sprite3D

var pos: Vector2

@onready var geometry = %Geometry

func update_height():
	var height = MapData.height.get_image().get_pixelv(pos.round()).r

	position = Vector3(pos.x, height, pos.y)

func _process(delta):
	pass
