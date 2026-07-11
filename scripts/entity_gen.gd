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

func trees():
	var cluster := NoiseTexture2D.new()
	cluster.width = MapData.RESOLUTION
	cluster.height = MapData.RESOLUTION

	var fast_noise = FastNoiseLite.new()
	fast_noise.seed = hash("the trees of all")

	cluster.noise = fast_noise
	
	if cluster.get_image() == null:
		await cluster.changed

	rng.seed = hash("tree")
	rng.state = 0

	for x in range(MapData.RESOLUTION - 1):
		for y in range(MapData.RESOLUTION - 1):
			var height = MapData.height.get_image().get_pixel(x, y).r

			if height < 0.1:
				continue

			var color = MapData.val.get_image().get_pixel(x, y)
			var noise = cluster.get_image().get_pixel(x, y).r

			var diff = color - Color(0.1294, 0.698, 0.2902)

			if Vector3(diff.r, diff.g, diff.b).length() < 0.1 && (noise * rng.randf() > 0.6 || rng.randf() > 0.997):
				var ent = pick_random_scene("res://entities/trees/").instantiate() as Entity

				ent.pos = Vector2(x, y)
				ent.scale = Vector3.ONE * rng.randf_range(0.3, 0.8)

				add_child(ent)
				continue
			
			diff = color - Color(0.4941, 0.502, 0.4941)

			if Vector3(diff.r, diff.g, diff.b).length() < 0.1 && (noise * rng.randf() > 0.8 || rng.randf() > 0.997):
				print(color)
				var ent = pick_random_scene("res://entities/trees/").instantiate() as Entity

				ent.pos = Vector2(x, y)
				ent.scale = Vector3.ONE * rng.randf_range(0.3, 0.8)

				add_child(ent)
				continue

func mountains():
	var cluster := NoiseTexture2D.new()
	cluster.width = MapData.RESOLUTION
	cluster.height = MapData.RESOLUTION

	var fast_noise = FastNoiseLite.new()
	fast_noise.seed = hash("mountains")

	cluster.noise = fast_noise
	
	if cluster.get_image() == null:
		await cluster.changed

	var ui = TextureRect.new()
	ui.texture = cluster
	%Debug.add_child(ui)

	rng.seed = hash("mountataat")
	rng.state = 0

	for x in range(MapData.RESOLUTION - 1):
		for y in range(MapData.RESOLUTION - 1):
			var color = MapData.val.get_image().get_pixel(x, y)
			var noise = cluster.get_image().get_pixel(x, y).r

			var diff = color - Color(0.1294, 0.698, 0.2902)
			
			diff = color - Color(0.4941, 0.502, 0.4941)

			if Vector3(diff.r, diff.g, diff.b).length() < 0.1 && (noise * rng.randf() > 0.8 || rng.randf() > 0.997):
				var ent = pick_random_scene("res://entities/mountains/").instantiate() as Entity

				ent.pos = Vector2(x, y)
				ent.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)

				ent.scale *= 1 - Vector3(diff.r, diff.g, diff.b).length() / 0.1

				add_child(ent)
				continue

func _ready():
	trees()
	mountains()
