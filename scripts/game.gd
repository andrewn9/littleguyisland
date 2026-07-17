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
	FARM,
	ROCK,
	WELL,
	FARM_BUILDING,
}

func is_built(t: EntityType) -> bool:
	return t == EntityType.HOUSING or t == EntityType.FARM \
			or t == EntityType.WELL or t == EntityType.FARM_BUILDING

var day_fraction := 0.375
var day := 0  # whole days passed

var food := 0.0
var rock := 0.0
var animals := 0
var population := 0
var avg_happiness := 0.0
var total_wood := 0
var house_capacity := 0 # total capacity
var home_count := 0
var farm_count := 0
var tree_count := 0
var well_count := 0
var farm_building_count := 0
var homeless := 0
var build_fail_streak := 0

var food_per_person := 4.0 # stockpile buffer target per folk
var food_consumption := 0.012 # eaten per folk per second
var crop_yield := 5.0

var housing_slack := 4 # extra home multiplier to prepare
var wood_per_house := 4
var homeless_birth_limit := 0.25 # stop breeding when this amout homeless
var birth_food_ratio := 1.15 # how much food to make new children
var birth_happiness := 0.5

signal day_changed

func _ready() -> void:
	day_changed.connect(func(): build_fail_streak = 0)

var _stats_timer := 0.0
func is_night():
	return day_fraction < 0.25 or day_fraction > 0.75

func hungry():
	return food < population * food_per_person

func needs_housing():
	return house_capacity < housing_slack * maxi(population, 1)

func out_of_resources() -> bool:
	return tree_count == 0

func cant_build() -> bool:
	return needs_housing() and tree_count == 0 and total_wood < wood_per_house

func cant_farm() -> bool:
	return population > 0 and hungry() and farm_count == 0 and not MapData.has_farmland

func overcrowded() -> bool:
	return population > 0 and float(homeless) / population > homeless_birth_limit

func no_build_space() -> bool:
	return needs_housing() and build_fail_streak >= 5

func prosperous():
	return population > 0 \
			and food >= population * food_per_person * birth_food_ratio \
			and avg_happiness >= birth_happiness \
			and not overcrowded()

var _pos_cache := {} # each group is a packed vector2 array for speed

func positions(group: String) -> PackedVector2Array:
	if not _pos_cache.has(group):
		_rebuild_positions(group)
	return _pos_cache[group]

func _rebuild_positions(group: String) -> void:
	var arr := PackedVector2Array()
	for e in get_tree().get_nodes_in_group(group):
		arr.append(e.pos)
	_pos_cache[group] = arr

func note_spawn(group: String, p: Vector2) -> void:
	if _pos_cache.has(group):
		_pos_cache[group].append(p)

func nearest_dist(group: String, p: Vector2) -> float:
	var d := 9999.0
	for q in positions(group):
		d = minf(d, p.distance_to(q))
	return d

func count_in_radius(group: String, center: Vector2, radius: float) -> int:
	var c := 0
	for q in positions(group):
		if center.distance_to(q) < radius:
			c += 1
	return c
const LAYER_FADE := 0.75
const LAYER_GROUPS := {
	"nature": ["trees", "rocks", "clouds"],
	"buildings": ["homes", "farms", "farm_buildings", "wells"],
	"folk": ["folk"],
}

var layer_opaque := {}

func layer_is_opaque(key: String) -> bool:
	return layer_opaque.get(key, true)

func set_layer_opaque(key: String, opaque: bool) -> void:
	layer_opaque[key] = opaque
	_apply_layer(key)

func layer_of(group: String) -> String:
	for key in LAYER_GROUPS:
		if group in LAYER_GROUPS[key]:
			return key
	return ""

func _apply_layer(key: String) -> void:
	if not model:
		return
	var amount := 0.0 if layer_is_opaque(key) else LAYER_FADE
	if key == "island":
		_fade(model.geometry, amount)
		return
	if key == "nature":
		_fade(model.entity_gen.prop_batch, amount)
	for g in LAYER_GROUPS.get(key, []):
		for e in get_tree().get_nodes_in_group(g):
			_fade(e, amount)

func fade_new(n: Node, group: String) -> void:
	var key := layer_of(group)
	if key != "" and not layer_is_opaque(key):
		_fade(n, LAYER_FADE)

func _fade(n: Node, amount: float) -> void:
	if n is GeometryInstance3D:
		n.transparency = amount
	for c in n.get_children():
		_fade(c, amount)

func resume():
	paused = false

func pause():
	paused = true

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("person"):
		model.entity_gen.spawn_little_guy(MapData.RESOLUTION/2, MapData.RESOLUTION/2)

func _physics_process(delta: float) -> void:
	if paused:
		scaled_delta = 0
	else:
		scaled_delta = delta * time_scale * 2
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
	water_mat.set_shader_parameter("time_scale", time_scale if not paused else 0.0)

func _refresh_stats() -> void:
	var folks := get_tree().get_nodes_in_group("folk")
	population = folks.size()
	total_wood = 0
	rock = 0.0
	homeless = 0
	var happy_sum := 0.0
	for f in folks:
		total_wood += f.carried_wood
		rock += f.carried_rock
		happy_sum += f.happiness
		if not is_instance_valid(f.home):
			homeless += 1
	avg_happiness = happy_sum / population if population > 0 else 0.0

	var homes := get_tree().get_nodes_in_group("homes")
	home_count = homes.size()
	house_capacity = 0
	for h in homes:
		house_capacity += h.capacity

	for g in _pos_cache: # prune anything freed since the last tick
		_rebuild_positions(g)

	farm_count = get_tree().get_nodes_in_group("farms").size()
	tree_count = get_tree().get_nodes_in_group("trees").size()
	well_count = get_tree().get_nodes_in_group("wells").size()
	farm_building_count = get_tree().get_nodes_in_group("farm_buildings").size()
