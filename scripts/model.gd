extends Node3D

@export var threshold := 0.5

@onready var geometry = $Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

var mouse_position: Vector2

const blot: Texture2D = preload("res://sprites/brush.tres")

func _ready() -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2i(MapData.WORLD_SIZE, MapData.WORLD_SIZE)
	quad.subdivide_width = 49
	quad.subdivide_depth = 49
	quad.orientation = PlaneMesh.FACE_Y
	geometry.mesh = quad.duplicate()
	
	var geom_shader = geometry.get_surface_override_material(0) as ShaderMaterial
	geom_shader.set_shader_parameter("valuemap", MapData.val)
	geom_shader.set_shader_parameter("heightmap", MapData.height)
	geom_shader.set_shader_parameter("height_scale", MapData.HEIGHT_SCALE)
	geom_shader.set_shader_parameter("texel_size", 1.0/20)

var drawing := false

func get_mouse_to_map():
	raycast.position = camera.to_local(camera.project_ray_origin(mouse_position))
	raycast.target_position = Vector3(0, 0, -99999)
	raycast.force_raycast_update()
	if raycast.get_collider():
		var target_pos = Vector2(raycast.get_collision_point().x + MapData.WORLD_SIZE / 2, raycast.get_collision_point().z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		return target_pos
	return Vector2i(-1, -1)

func draw_at(tex_pos: Vector2i, to: DrawableTexture2D):
	var brush_size = 8
	to.blit_rect(
		Rect2i(tex_pos.x - brush_size/2, tex_pos.y - brush_size/2, brush_size, brush_size),
		blot, Color.GRAY
	)

func _input(event):
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		mouse_position = event.position
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			draw_at(get_mouse_to_map(), MapData.val)
			
	
