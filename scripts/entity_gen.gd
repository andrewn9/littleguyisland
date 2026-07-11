extends Node

var tree = preload("res://entities/trees/tree.res")
var mountain = preload("res://entities/mountains/mountain.res")

var rng = RandomNumberGenerator.new()

func pick_random_scene(path: StringName):
	var paths = []
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if !dir.current_is_dir():
			paths.append(path + file)
		file = dir.get_next()
	dir.list_dir_end()
	
	if paths.is_empty():
		return
	
	var scene = load(paths.pick_random())
	return scene

var mountain_cluster := NoiseTexture2D.new()
var mountain_noise: PackedFloat32Array = []

var tree_cluster := NoiseTexture2D.new()
var tree_noise: PackedFloat32Array = []

func _ready():
	mountain_cluster.width = MapData.RESOLUTION
	mountain_cluster.height = MapData.RESOLUTION

	var mountain_fast_noise = FastNoiseLite.new()
	mountain_fast_noise.seed = hash("country road")

	mountain_cluster.noise = mountain_fast_noise
	
	if mountain_cluster.get_image() == null:
		await mountain_cluster.changed

	rng.seed = hash("mountains")
	rng.state = 0

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
	rng.state = 0

	for i in range(MapData.RESOLUTION * MapData.RESOLUTION):
		tree_noise.append(rng.randf())
	
	trees()
	mountains()

func trees():


	for x in range(MapData.RESOLUTION):
		for y in range(MapData.RESOLUTION):
			var height = MapData.height.get_image().get_pixel(x, y).r

			if height < 0.1:
				continue

			var color = MapData.val.get_image().get_pixel(x, y)
			var cluster_val = tree_cluster.get_image().get_pixel(x, y).r
			var white_val = tree_noise[x * MapData.RESOLUTION + y]

			var diff = color - Color(0.1294, 0.698, 0.2902)

			if white_val > 0.998 || Vector3(diff.r, diff.g, diff.b).length_squared() < 0.16 && (white_val > 0.95 && white_val * cluster_val > 0.5):
				var ent = pick_random_scene("res://entities/trees/").instantiate() as Entity

				ent.pos = Vector2(x, y)
				ent.scale = Vector3.ONE * rng.randf_range(0.3, 0.8)

				add_child(ent)
				continue

func mountains():
	for x in range(MapData.RESOLUTION):
		for y in range(MapData.RESOLUTION):
			var cluster_val = mountain_cluster.get_image().get_pixel(x, y).r
			var white_val = mountain_noise[x * MapData.RESOLUTION + y]

			if white_val * cluster_val > 0.3 && white_val > 0.998:
				var diff = MapData.val.get_image().get_pixel(x, y) - Color(0.4941, 0.502, 0.4941)
				if Vector3(diff.r, diff.g, diff.b).length_squared() > 0.16:
					continue

				var ent = pick_random_scene("res://entities/mountains/").instantiate() as Entity

				ent.pos = Vector2(x, y)
				ent.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)

				ent.scale *= 1 - Vector3(diff.r, diff.g, diff.b).length() / 0.4

				add_child(ent)
				continue




		

