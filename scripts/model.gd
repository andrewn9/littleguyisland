extends Node3D

@export var threshold := 0.5

@onready var geometry = $Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

var mouse_position: Vector2

const brushes: Dictionary[StringName, Texture2D] = {
	"default": preload("res://testing/brush.tres"),
	"harsh": preload("res://testing/harsher brush.tres"),
}

func _ready() -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2i(MapData.WORLD_SIZE, MapData.WORLD_SIZE)
	quad.subdivide_width = 256
	quad.subdivide_depth = 256
	quad.orientation = PlaneMesh.FACE_Y
	geometry.mesh = quad.duplicate()
	
	var geom_shader = geometry.get_surface_override_material(0) as ShaderMaterial
	geom_shader.set_shader_parameter("valuemap", MapData.val)
	geom_shader.set_shader_parameter("heightmap", MapData.height)
	geom_shader.set_shader_parameter("height_scale", MapData.HEIGHT_SCALE)
	geom_shader.set_shader_parameter("texel_size", 1.0/20)

var drawing := false

func project_screen_pos(pos: Vector2):
	raycast.position = camera.to_local(camera.project_ray_origin(pos))
	raycast.target_position = Vector3(0, 0, -99999)
	raycast.force_raycast_update()
	if raycast.get_collider():
		var target_pos = Vector2(raycast.get_collision_point().x + MapData.WORLD_SIZE / 2, raycast.get_collision_point().z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		return target_pos
	return null

func draw_at(tex_pos: Vector2, to: DrawableTexture2D, color: Color, brush_size: int, brush_type="default"):
	to.blit_rect(
		Rect2i(roundi(tex_pos.x - brush_size * 0.5), roundi(tex_pos.y - brush_size * 0.5), brush_size, brush_size),
		brushes[brush_type], color
	)

func stroke(from: Vector2, to: Vector2):
	for i in range(0, (from - to).length(), 2):
		use_tool(from + (to - from).limit_length(i))
		prev_stroke = from + (to - from).limit_length(i)

var prev_stroke

func use_tool(pos: Vector2):
	if Hud.active == "Land":
		draw_at(pos, MapData.val, Color.GREEN, 18)
		draw_at(pos, MapData.height, Color.WEB_GRAY, 8)
	elif Hud.active == "Mountain":
		draw_at(pos, MapData.height, Color.WHITE, 100, "harsh")
		draw_at(pos, MapData.val, Color.GRAY, 50)
	elif Hud.active == "Water":
		draw_at(pos, MapData.height, Color.BLACK, 5)
		draw_at(pos, MapData.val, Color.BLUE, 5)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.pressed:
			prev_stroke = project_screen_pos(event.position)
			if prev_stroke:
				use_tool(prev_stroke)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not prev_stroke:
			prev_stroke = project_screen_pos(event.position)
			if prev_stroke:
				use_tool(prev_stroke)
				return

		if prev_stroke && project_screen_pos(event.position):
			stroke(prev_stroke, project_screen_pos(event.position))
			
	
