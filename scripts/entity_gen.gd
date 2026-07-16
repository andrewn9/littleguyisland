class_name EntityGen extends Node

const STATIC_PROP = preload("res://entities/static_prop.tscn")
const PROP_MAT = preload("res://materials/prop.tres")

const CLOUD = preload("res://entities/cloud.tscn")

var rng = RandomNumberGenerator.new()

@export var pixel_size := 1

var mountain_cluster := NoiseTexture2D.new()
var mountain_noise: PackedFloat32Array = []
var mountain_cutoff = 0.965
var tree_cluster := NoiseTexture2D.new()
var tree_noise: PackedFloat32Array = []

var mountain_textures: Array[Texture2D] = []
var grass_textures: Array[Texture2D] = []
var tree_textures: Array[Texture2D] = []
var bush_textures: Array[Texture2D] = []
var house_textures: Array[Texture2D] = []

const FARM_STAGE_PATHS := [
	"res://sprites/props/farmland/fallow.png",
	"res://sprites/props/farmland/wheat1.png",
	"res://sprites/props/farmland/wheat2.png",
	"res://sprites/props/farmland/wheat3.png",
	"res://sprites/props/farmland/wheat4.png",
]
var farm_textures: Array[Texture2D] = []
var _farms: Array = []
var crop_grow_days := Vector2(1.0, 2.5)

var body_textures: Array[Texture2D]
var shirt_textures: Array[Texture2D]
var hair_textures: Array[Texture2D]

@export var hair_colors: Gradient

var prop_materials: Dictionary[int, StandardMaterial3D] = {}

func load_textures(path: StringName) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	var dir = DirAccess.open(path)

	if dir == null:
		print("Could not open: ", path)
		return textures

	dir.list_dir_begin()
	var file = dir.get_next()

	while file != "":
		if !dir.current_is_dir():
			if file.ends_with(".import"):
				file = file.replace(".import", "")
			
			var tex = load(path + file) as Texture2D
			if tex:
				textures.append(tex)

		file = dir.get_next()

	dir.list_dir_end()

	return textures


func get_prop_material(texture: Texture2D, flipped := false) -> StandardMaterial3D:
	var key := texture.get_instance_id() * 2 + int(flipped)
	var cached = prop_materials.get(key)
	if cached:
		return cached
	var mat = PROP_MAT.duplicate(true)
	mat.albedo_texture = texture
	if flipped:  # mirror the sprite horizontally (uv.x -> 1 - uv.x)
		mat.uv1_scale = Vector3(-1, 1, 1)
		mat.uv1_offset = Vector3(1, 0, 0)
	prop_materials[key] = mat
	return mat

func _ready():
	mountain_textures = load_textures(
		"res://sprites/props/mountains/"
	)
	grass_textures = load_textures(
		"res://sprites/props/grasses/"
	)
	bush_textures = load_textures(
		"res://sprites/props/bushes/"
	)
	tree_textures = load_textures(
		"res://sprites/props/trees/"
	)
	house_textures = load_textures(
		"res://sprites/props/house/"
	)
	for p in FARM_STAGE_PATHS:
		farm_textures.append(load(p))


	body_textures = load_textures("res://sprites/folk/body/")
	shirt_textures = load_textures("res://sprites/folk/shirt/")
	hair_textures = load_textures("res://sprites/folk/hair/")

	mountain_cluster.width = MapData.RESOLUTION
	mountain_cluster.height = MapData.RESOLUTION

	var mountain_fast_noise = FastNoiseLite.new()
	mountain_fast_noise.seed = hash("country road")

	mountain_cluster.noise = mountain_fast_noise

	if mountain_cluster.get_image() == null:
		await mountain_cluster.changed

	rng.seed = hash("mountains")

	for i in range(MapData.RESOLUTION * MapData.RESOLUTION):
		mountain_noise.append(rng.randf())

	tree_cluster.width = MapData.RESOLUTION
	tree_cluster.height = MapData.RESOLUTION

	var tree_fast_noise = FastNoiseLite.new()
	tree_fast_noise.seed = hash("the trees of all")

	tree_cluster.noise = tree_fast_noise

	if tree_cluster.get_image() == null:
		await tree_cluster.changed


	rng.seed = hash("tree")

	for i in range(MapData.RESOLUTION * MapData.RESOLUTION):
		tree_noise.append(rng.randf())


	MapData.update()

	plains(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)
	mountains(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)

func spawn_static_prop(pos: Vector2, textures: Array[Texture2D], min_scale: float, max_scale: float):
	if textures.is_empty():
		return

	var ent = STATIC_PROP.instantiate() as Entity

	rng.seed = hash(str(pos.x) + str(pos.y))

	var texture = textures[rng.randi_range(0, textures.size() - 1)]
	var flipped := rng.randf() < 0.5  # random mirror
	var mat = get_prop_material(texture, flipped)
	ent.pos = pos
	ent.apply_scale(rng.randf_range(min_scale, max_scale))
	ent.apply_scale(texture.get_width() / float(pixel_size))
	
	ent.set_prop_mat(mat)
	add_child(ent)
	return ent

func plains(x1: int, y1: int, x2: int, y2: int):
	var height_map = MapData.height_img
	var color_map = MapData.val_img
	var cluster_map = tree_cluster.get_image()

	for x in range(x1, x2):
		for y in range(y1, y2):
			if Vector2(x - MapData.RESOLUTION * 0.5, y - MapData.RESOLUTION * 0.5).length() > MapData.RESOLUTION * 0.5:
				continue

			var elevation = height_map.get_pixel(x, y).r
			if elevation < 0.1:
				continue

			var color = color_map.get_pixel(x, y)

			rng.seed = hash(str(x) + str(y))
			var mdiff = color - MapData.MOUNTAIN_KEY
			if rng.randf() < 0.9 and Vector3(mdiff.r, mdiff.g, mdiff.b).length_squared() < 0.16:
				continue

			var cluster_val = cluster_map.get_pixel(x, y).r
			var white_val = tree_noise[x * MapData.RESOLUTION + y]

			var diff = color - MapData.GRASS_KEY

			if white_val > 0.95 || Vector3(diff.r, diff.g, diff.b).length_squared() < 0.04 && (white_val > 0.8 && white_val * cluster_val > 0.4):
				rng.seed = hash(str(x) + str(y))
				var random = rng.randf_range(0, 100)
				var ent
				if random > 66:
					ent = spawn_static_prop(
						Vector2(x, y),
						tree_textures,
						1.0,
						1.4
					)
					ent.name = "Tree"
					ent.type = Game.EntityType.TREE
					ent.add_to_group("trees")
				elif random > 43:
					ent = spawn_static_prop(
						Vector2(x, y),
						bush_textures,
						1.0,
						1.4
					)
					ent.name = "Bush"
					ent.type = Game.EntityType.DECORATIVE
				elif random > 30:
					ent = spawn_static_prop(
						Vector2(x, y),
						grass_textures,
						1.0,
						1.4
					)
					ent.name = "Grass"
					ent.type = Game.EntityType.DECORATIVE
				

func mountains(x1: int, y1: int, x2: int, y2: int):
	var height_map = MapData.height_img
	var color_map = MapData.val_img
	var cluster_map = mountain_cluster.get_image()

	for x in range(x1, x2):
		for y in range(y1, y2):
			if Vector2(x - MapData.RESOLUTION * 0.5, y - MapData.RESOLUTION * 0.5).length() > MapData.RESOLUTION * 0.5:
				continue
			
			var elevation = height_map.get_pixel(x, y).r

			if elevation < 0.3:
				continue

			var cluster_val = cluster_map.get_pixel(x, y).r
			var white_val = mountain_noise[x * MapData.RESOLUTION + y]

			if white_val * cluster_val > 0.3 && white_val > mountain_cutoff:
				var diff = color_map.get_pixel(x, y) - MapData.MOUNTAIN_KEY
				var val = Vector3(diff.r, diff.g, diff.b).length_squared()

				if val > 0.16:
					continue

				var fac = 1.0 - sqrt(val) / 0.16

				spawn_static_prop(
					Vector2(x, y),
					mountain_textures,
					0.8 * fac,
					1.5 * fac
				)

				if elevation > 0.7:
					if height_map.get_pixel(max(x - 1, 0), y).r > elevation or height_map.get_pixel(max(x + 1, MapData.RESOLUTION - 1), y).r > elevation or height_map.get_pixel(x, max(y - 1, 0)).r > elevation or height_map.get_pixel(x, max(y + 1, MapData.RESOLUTION - 1)).r > elevation:
						continue

					var cloud = CLOUD.instantiate() as GPUParticles3D

					cloud.position = Vector3(x, 0, y) * MapData.WORLD_SIZE / MapData.RESOLUTION - Vector3(MapData.WORLD_SIZE / 2, 0, MapData.WORLD_SIZE / 2)
					cloud.position.y += elevation * MapData.HEIGHT_SCALE
					cloud.position += Vector3(rng.randf_range(-100.0, 100.0), rng.randf_range(-50.0, 50.0), rng.randf_range(-100.0, 100.0))
					cloud.rotation.y = rng.randf_range(0, 2 * PI)
					cloud.scale *= rng.randf_range(0.3, 1.0)

					add_child(cloud)


func generate(x1: int, y1: int, x2: int, y2: int):
	for child: Node3D in get_children():
		var x_pos = (child.position.x + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		var y_pos = (child.position.z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE

		if x_pos > x1 and y_pos > y1 and x_pos < x2 and y_pos < y2:
			if child is Entity and (child as Entity).is_static \
					and (child as Entity).type != Game.EntityType.HOUSING:
				child.queue_free()  # regenerate trees/props, but keep homes
			elif child is GPUParticles3D:
				child.queue_free()

	plains(x1, y1, x2, y2)
	mountains(x1, y1, x2, y2)

var name_prefixes = [
	"chud",
	"folk",
	"son",
	"larp"
]

var name_suffixes = [
	"ington",
	"tholomew",
	"weld",
	"wold",
	"ette",
	"ling",
	"son",
	"soul",
	"sen",
	"lette",
	"ly",
	"lee",
	"let",
	"wyn",
	"wald",
	"sky",
	"sten",
	"ny",
	"lyn",
	"lis",
	"len",
	"ler",
	"elle",
	"ton",
	"sy",
	"ski",
	"liet",
	"ston",
	"liah",
	"wig",
	"land",
	"man"
]

var special_eggs = [
	"cliff",
	" quixote",
	"ihide",
	"sang",
	"enheim",
	"einburg",
	"company"
]

var special_whole_eggs = [
	"John",
	"jera",
]

func spawn_home(p: Vector2, capacity := 3) -> Entity:
	var ent = spawn_static_prop(p, house_textures, 1.7, 2.1)
	if ent == null:
		return null
	ent.name = "Home"
	ent.type = Game.EntityType.HOUSING
	ent.add_to_group("homes")
	ent.capacity = capacity
	Game.house_capacity += capacity  # reflect at once so the build cap is tight
	return ent

func farm_is_ripe(f: Entity):
	return is_instance_valid(f) and f.type == Game.EntityType.FARM \
			and f.growth_stage >= farm_textures.size() - 1

func spawn_farm(p: Vector2):
	if farm_textures.is_empty():
		return null

	var ent = STATIC_PROP.instantiate() as Entity

	ent.pos = p
	ent.name = "Farm"
	ent.type = Game.EntityType.FARM
	ent.plant_day_f = Game.day + Game.day_fraction
	ent.grow_days = randf_range(crop_grow_days.x, crop_grow_days.y)
	ent.growth_stage = 0

	ent.apply_scale(farm_textures[0].get_width() / float(pixel_size))
	ent.set_prop_mat(get_prop_material(farm_textures[0]))

	add_child(ent)
	ent.add_to_group("farms")
	_farms.append(ent)
	Game.farm_count += 1  # reflect at once so the passive-farm cap is tight

	return ent

func _process(_delta: float) -> void:
	if Game.paused:
		return
	var now := Game.day + Game.day_fraction
	var last := farm_textures.size() - 1
	var alive = []
	for f in _farms:
		if !is_instance_valid(f):
			continue
		alive.append(f)
		var elapsed = maxf(now - f.plant_day_f, 0.0)
		var progress = clampf(elapsed / f.grow_days, 0.0, 1.0)
		var stage := mini(int(progress * last), last)
		if stage != f.growth_stage:
			f.growth_stage = stage
			f.set_prop_mat(get_prop_material(farm_textures[stage]))
	_farms = alive

func spawn_little_guy(x: int, y: int, birth_home: Entity = null):
	var ent = load("res://entities/folk.res").instantiate() as Entity

	ent.pos = Vector2(x, y)
	ent.type = Game.EntityType.FOLK

	if birth_home != null:
		(ent as Folk).make_child(birth_home)

	var folk_name: String
	if randf() < 0.05:
		folk_name = name_prefixes.pick_random() + special_eggs.pick_random()
	elif randf() < 0.03:
		folk_name = special_whole_eggs.pick_random()
	else:
		folk_name = name_prefixes.pick_random() + name_suffixes.pick_random()

	(ent.get_node("Pivot/Sprite/SubViewport/body") as TextureRect).texture = body_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/shirt") as TextureRect).texture = shirt_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/hair") as TextureRect).texture = hair_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/hair") as TextureRect).modulate = hair_colors.sample(randf())

	add_child(ent)
	ent.add_to_group("folk")
	ent.name = folk_name

	Hud.push_notification("[i]" + folk_name + " has joined the game [/i]")
	if Game.population == 0:
		Hud.push_notification("the first folk have arrived")
	elif Game.population % 50 == 0:
		Hud.push_notification("the population has grown to " + str(Game.population) + " folk!")
