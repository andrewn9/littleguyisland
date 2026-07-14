extends Node

var sim_time := 0

var time_scale := 1.0
var paused := true

var scaled_delta:= 0.0

var model: Model

enum EntityType {
	DECORATIVE,
	HOUSING,
	TREE,
	FOLK
}

var day_fraction := 0.375

func is_night() -> bool:
	return day_fraction < 0.25 or day_fraction > 0.75

func _ready() -> void:
	pass

func resume():
	paused = false

func pause():
	paused = true

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("person"):
		model.entity_gen.spawn_little_guy(MapData.RESOLUTION/2, MapData.RESOLUTION/2)

func _physics_process(delta: float) -> void:
	if paused:
		scaled_delta = 0
	else:
		scaled_delta = delta * time_scale
	if not model:
		return
	var water: MeshInstance3D = model.get_parent().get_node("Water")
	var water_mat: ShaderMaterial = water.get_surface_override_material(0)
	water_mat.set_shader_parameter("time_scale", time_scale if not paused else 0)
