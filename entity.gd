class_name Entity extends Sprite3D

var pos: Vector2

@onready var geometry = %Geometry

func update_height():
	var height = MapData.height.get_image().get_pixelv(pos.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r

	position = Vector3(pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2, height * 10, pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2)

func _process(delta):
	pos.x = fmod(pos.x + delta * 20, MapData.RESOLUTION)
	pos.y = fmod(pos.y + delta * 10, MapData.RESOLUTION)

	update_height()