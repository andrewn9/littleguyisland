class_name Entity extends Sprite3D

var pos
var target_pos
var speed = 20

@onready var geometry = %Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

func _ready() -> void:
	pos = Vector2(position.x + MapData.WORLD_SIZE / 2, position.y + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
	
	target_pos = pos
	
func update_height():
	var height = MapData.height.get_image().get_pixelv(pos.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r

	position = Vector3(pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2, height * MapData.HEIGHT_SCALE, pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2)

func _process(delta):
	pos += (target_pos - pos).limit_length(speed * delta)
	update_height()
