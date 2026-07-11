extends Node3D

@export var threshold := 0.5

@onready var draw_surface = $InteractionLayer/DrawSurface
@onready var geometry = $Geometry
func _ready() -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2i(MapData.WORLD_SIZE, MapData.WORLD_SIZE)
	quad.subdivide_width = 20
	quad.subdivide_depth = 20
	quad.orientation = PlaneMesh.FACE_Y
	draw_surface.mesh = quad
	geometry.mesh = quad.duplicate()
	
	(draw_surface.get_surface_override_material(0) as StandardMaterial3D).albedo_texture = MapData.height
	
	var geom_shader = geometry.get_surface_override_material(0) as ShaderMaterial
	geom_shader.set_shader_parameter("valuemap", MapData.val)
	geom_shader.set_shader_parameter("heightmap", MapData.height)
	geom_shader.set_shader_parameter("texel_size", 1.0/20)
	
func _process(delta: float) -> void:
	pass
