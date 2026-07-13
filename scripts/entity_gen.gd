class_name EntityGen extends Node

const STATIC_PROP = preload("res://entities/static_prop.tscn")
const PROP_MAT = preload("res://materials/prop.tres")

const CLOUD = preload("res://entities/cloud.tscn")

var rng = RandomNumberGenerator.new()

var mountain_cluster := NoiseTexture2D.new()
var mountain_noise: PackedFloat32Array = []

var tree_cluster := NoiseTexture2D.new()
var tree_noise: PackedFloat32Array = []

var mountain_textures: Array[Texture2D] = []
var shrub_textures: Array[Texture2D] = []

var body_textures: Array[Texture2D]
var shirt_textures: Array[Texture2D]
var hair_textures: Array[Texture2D]

@export var hair_colors: Gradient

var prop_materials: Dictionary[String, StandardMaterial3D] = {}

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
				var tex = load(path + file.replace(".import", "")) as Texture2D

				if tex:
					textures.append(tex)

		file = dir.get_next()

	dir.list_dir_end()

	return textures


func get_prop_material(texture: Texture2D) -> StandardMaterial3D:
	var mat = PROP_MAT.duplicate(true)
	mat.albedo_texture = texture
	return mat

func _ready():
	mountain_textures = load_textures(
		"res://sprites/props/mountains/"
	)

	shrub_textures = load_textures(
		"res://sprites/props/shrubbery/"
	)
	
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

	trees(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)
	mountains(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)

func spawn_static_prop(pos: Vector2, textures: Array[Texture2D], min_scale: float, max_scale: float):
	if textures.is_empty():
		return

	var ent = STATIC_PROP.instantiate() as Entity

	rng.seed = hash(str(pos.x) + str(pos.y))

	var texture = textures[rng.randi_range(0, textures.size() - 1)]
	var mat = get_prop_material(texture)
	ent.pos = pos
	ent.set_prop_scale(rng.randf_range(min_scale, max_scale))
	ent.set_prop_mat(mat)
	add_child(ent)

func trees(x1: int, y1: int, x2: int, y2: int):
	var height_map = MapData.height_img
	var color_map = MapData.val_img
	var cluster_map = tree_cluster.get_image()

	for x in range(x1, x2):
		for y in range(y1, y2):
			var elevation = height_map.get_pixel(x, y).r

			if elevation < 0.1:
				continue

			var color = color_map.get_pixel(x, y)
			var cluster_val = cluster_map.get_pixel(x, y).r
			var white_val = tree_noise[x * MapData.RESOLUTION + y]

			var diff = color - Color(0.36, 0.64, 0.12)

			if white_val > 0.995 || Vector3(diff.r, diff.g, diff.b).length_squared() < 0.16 && (white_val > 0.95 && white_val * cluster_val > 0.5):
				spawn_static_prop(
					Vector2(x, y),
					shrub_textures,
					1.0,
					1.4
				)



func mountains(x1: int, y1: int, x2: int, y2: int):
	var height_map = MapData.height_img
	var color_map = MapData.val_img
	var cluster_map = mountain_cluster.get_image()

	for x in range(x1, x2):
		for y in range(y1, y2):
			var elevation = height_map.get_pixel(x, y).r

			if elevation < 0.3:
				continue

			var cluster_val = cluster_map.get_pixel(x, y).r
			var white_val = mountain_noise[x * MapData.RESOLUTION + y]

			if white_val * cluster_val > 0.3 && white_val > 0.965:
				var diff = color_map.get_pixel(x, y) - Color.GRAY
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
			if child is Entity and (child as Entity).is_static:
				child.queue_free()
			elif child is GPUParticles3D:
				child.queue_free()

	trees(x1, y1, x2, y2)
	mountains(x1, y1, x2, y2)

func spawn_little_guy(x: int, y: int):
	var ent = load("res://entities/folk.res").instantiate() as Entity

	ent.pos = Vector2(x, y)
	ent.name = "Folk"

	(ent.get_node("Pivot/Sprite/SubViewport/body") as TextureRect).texture = body_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/shirt") as TextureRect).texture = shirt_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/hair") as TextureRect).texture = hair_textures.pick_random()
	(ent.get_node("Pivot/Sprite/SubViewport/hair") as TextureRect).modulate = hair_colors.sample(randf())

	add_child(ent)
