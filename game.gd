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
	FOLK,
	FARM
}

var day_fraction := 0.375
var day := 0  # whole days passed

var food := 0.0
var rock := 0.0
var population := 0
var avg_happiness := 0.0
var total_wood := 0
var house_capacity := 0 # total capacity
var farm_count := 0


var food_per_person := 4.0 # stockpile buffer target per folk
var food_consumption := 0.012 # eaten per folk per second
var crop_yield := 5.0

var housing_slack := 5 # extra home multiplier to prepare
var birth_food_ratio := 1.15 # how much food to make new children
var birth_happiness := 0.5

signal day_changed

var _stats_timer := 0.0
func is_night():
	return day_fraction < 0.25 or day_fraction > 0.75

func hungry():
	return food < population * food_per_person

func needs_housing():
	return house_capacity < housing_slack * maxi(population, 1)

func prosperous():
	return population > 0 \
			and food >= population * food_per_person * birth_food_ratio \
			and avg_happiness >= birth_happiness

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

	if scaled_delta > 0.0:
		food = maxf(0.0, food - population * food_consumption * scaled_delta)

	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 0.5
		_refresh_stats()

	var water: MeshInstance3D = model.get_parent().get_node("Water")
	var water_mat: ShaderMaterial = water.get_surface_override_material(0)
	water_mat.set_shader_parameter("time_scale", time_scale if not paused else 0)

func _refresh_stats() -> void:
	population = 0
	total_wood = 0
	house_capacity = 0
	farm_count = 0
	var happy_sum := 0.0
	for e in model.entity_gen.get_children():
		if e is Folk:
			population += 1
			total_wood += e.carried_wood
			happy_sum += e.happiness
		elif e is Entity and e.type == EntityType.HOUSING:
			house_capacity += e.capacity
		elif e is Entity and e.type == EntityType.FARM:
			farm_count += 1
	avg_happiness = happy_sum / population if population > 0 else 0.0
