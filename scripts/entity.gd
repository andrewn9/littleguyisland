class_name Entity extends Sprite3D

var pos = Vector2.ZERO
var target_pos = Vector2.ZERO
var speed = 20

@onready var geometry = %Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

func update_height():
	var height = MapData.height.get_image().get_pixelv(pos.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r

	position = Vector3(pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2, height * MapData.HEIGHT_SCALE, pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			raycast.position = camera.to_local(camera.project_ray_origin(event.position))
			raycast.target_position = Vector3(0, 0, -999)
			raycast.force_raycast_update()

			if raycast.get_collider():
				target_pos = Vector2(raycast.get_collision_point().x + MapData.WORLD_SIZE / 2, raycast.get_collision_point().z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE


func _process(delta):
	pos += (target_pos - pos).limit_length(speed * delta)

	update_height()
