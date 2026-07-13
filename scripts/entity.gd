class_name Entity extends Node3D

var pos: Vector2
var target_pos: Vector2
var speed = 20

func _ready() -> void:
	if not pos:
		pos = Vector2(position.x + MapData.WORLD_SIZE / 2, position.z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		target_pos = pos
	else:
		target_pos = pos

func set_mesh_size(x):
	$MeshInstance3D.scale *= x 

func update_height():
	var height = MapData.height_img.get_pixelv(pos.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r

	position = Vector3(pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2, height * MapData.HEIGHT_SCALE, pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2)

func _process(delta):
	pos += (target_pos - pos).limit_length(speed * delta)

	update_height()
