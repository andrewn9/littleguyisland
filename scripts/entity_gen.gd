class_name EntityGen extends Node

const STATIC_PROP = preload("res://entities/static_prop.tscn")
const PROP_MAT = preload("res://materials/prop.tres")
const FOLK_FAB = preload("res://entities/folk.tscn")

const CLOUD = preload("res://entities/cloud.tscn")
const ANIMAL_FAB = preload("res://entities/animal.tscn")

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
const WELL_PATH := "res://sprites/props/well.png"
var well_texture: Texture2D
var farm_building_textures: Array[Texture2D] = []

var farm_textures: Array[Texture2D] = []
var animal_textures: Array[Texture2D] = []
var wildlife_capacity := 80
var _farms: Array = []
var crop_grow_days := Vector2(1.0, 2.5)

var body_textures: Array[Texture2D]
var shirt_textures: Array[Texture2D]
var hair_textures: Array[Texture2D]

@export var hair_colors: Gradient

var prop_materials: Dictionary[int, StandardMaterial3D] = {}

var prop_batch: PropBatch


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


func set_low_gfx_alpha(low: bool) -> void:
	var mode := BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if low \
			else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var base: BaseMaterial3D = PROP_MAT
	base.transparency = mode
	for m in prop_materials.values():
		m.transparency = mode


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

func _init():
	prop_batch = PropBatch.new()
	prop_batch.name = "PropBatch"
	add_child(prop_batch)

func _ready():
	mountain_textures = load_textures("res://sprites/props/mountains/")
	grass_textures = load_textures("res://sprites/props/grasses/")
	bush_textures = load_textures("res://sprites/props/bushes/")
	tree_textures = load_textures("res://sprites/props/trees/")
	house_textures = load_textures("res://sprites/props/house/")
	for p in FARM_STAGE_PATHS:
		farm_textures.append(load(p))
	well_texture = load(WELL_PATH)
	farm_building_textures = load_textures("res://sprites/props/farm_buildings/")
	animal_textures = load_textures("res://sprites/props/animal/")

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

	var loading := Game.pending_load and Save.has_slot(Game.active_slot)
	if loading:
		Save.apply_slot(Game.active_slot, self)
	else:
		plains(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)
		mountains(0, 0, MapData.RESOLUTION, MapData.RESOLUTION)
		wildlife()
	Game.pending_load = false
	Game.day_changed.connect(_wildlife_day)
	Game.day_changed.connect(_settlers_day)
	Hud.begin_world(not loading)


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


func _add_decor(p: Vector2, textures: Array[Texture2D]) -> void:
	if textures.is_empty():
		return
	rng.seed = hash(str(p.x) + str(p.y))
	var texture = textures[rng.randi_range(0, textures.size() - 1)]
	var flipped := rng.randf() < 0.5
	var s := rng.randf_range(1.0, 1.4) * texture.get_width() / float(pixel_size)
	prop_batch.add_decor(texture, flipped, p, s)


func _layer(ent: Node3D, group: String) -> void:
	ent.add_to_group(group)
	if ent is Entity:
		Game.note_spawn(group, (ent as Entity).pos)
	Game.fade_new(ent, group)


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

			if white_val > 0.97 || Vector3(diff.r, diff.g, diff.b).length_squared() < 0.04 && (white_val > 0.8 && white_val * cluster_val > 0.4):
				rng.seed = hash(str(x) + str(y))
				var random = rng.randf_range(0, 100)
				var ent
				if random > 66:
					ent = spawn_static_prop(Vector2(x, y), tree_textures, 1.0, 1.4)
					ent.name = "Tree"
					ent.type = Game.EntityType.TREE
					_layer(ent, "trees")
				elif random > 43:
					_add_decor(Vector2(x, y), bush_textures)
				elif random > 30:
					_add_decor(Vector2(x, y), grass_textures)


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

				var rock = spawn_static_prop(Vector2(x, y), mountain_textures, 0.8 * fac, 1.5 * fac)
				if rock:
					rock.name = "Rock"
					rock.type = Game.EntityType.ROCK
					_layer(rock, "rocks")

				if elevation > 0.7 and not World.low_gfx:
					if height_map.get_pixel(max(x - 1, 0), y).r > elevation or height_map.get_pixel(max(x + 1, MapData.RESOLUTION - 1), y).r > elevation or height_map.get_pixel(x, max(y - 1, 0)).r > elevation or height_map.get_pixel(x, max(y + 1, MapData.RESOLUTION - 1)).r > elevation:
						continue

					var cloud = CLOUD.instantiate() as GPUParticles3D

					cloud.position = Vector3(x, 0, y) * MapData.WORLD_SIZE / MapData.RESOLUTION - Vector3(MapData.WORLD_SIZE / 2, 0, MapData.WORLD_SIZE / 2)
					cloud.position.y += elevation * MapData.HEIGHT_SCALE
					cloud.position += Vector3(rng.randf_range(-100.0, 100.0), rng.randf_range(-50.0, 50.0), rng.randf_range(-100.0, 100.0))
					cloud.rotation.y = rng.randf_range(0, 2 * PI)
					cloud.scale *= rng.randf_range(0.3, 1.0)

					add_child(cloud)
					_layer(cloud, "clouds")


func generate(x1: int, y1: int, x2: int, y2: int):
	if MapData.height_img == null or tree_cluster.get_image() == null \
			or mountain_cluster.get_image() == null:
		return

	for child: Node3D in get_children():
		var x_pos = (child.position.x + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		var y_pos = (child.position.z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE

		if x_pos > x1 and y_pos > y1 and x_pos < x2 and y_pos < y2:
			if child is Entity and (child as Entity).is_static and not Game.is_built((child as Entity).type):
				child.queue_free()  # regrow natural props, keep what the folk built
			elif child is GPUParticles3D:
				free_cloud(child)

	prop_batch.clear_region(x1, y1, x2, y2)  # plains() re-adds the decor below

	plains(x1, y1, x2, y2)
	mountains(x1, y1, x2, y2)

func free_cloud(cloud: GPUParticles3D):
	if not cloud.emitting:
		return
	
	if World.low_gfx:
		cloud.queue_free()
		return
	
	cloud.emitting = false
	await get_tree().create_timer(cloud.lifetime).timeout
	cloud.queue_free()

var name_prefixes = ["chud", "folk", "son", "larp"]

var name_suffixes = ["ington", "tholomew", "weld", "wold", "ette", "ling", "son", "soul", "sen", "lette", "ly", "lee", "let", "wyn", "wald", "sky", "sten", "ny", "lyn", "lis", "len", "ler", "elle", "ton", "sy", "ski", "liet", "ston", "liah", "wig", "land", "man"]

var special_eggs = ["cliff", " quixote", "ihide", "sang", "enheim", "einburg", "company"]

var special_whole_eggs = [
	"John",
	"bongbong",
]

func spawn_home(p: Vector2, capacity := 3) -> Entity:
	var ent = spawn_static_prop(p, house_textures, 1.7, 2.1)
	if ent == null:
		return null
	ent.name = "Home"
	ent.type = Game.EntityType.HOUSING
	_layer(ent, "homes")
	ent.capacity = capacity
	Game.house_capacity += capacity  # reflect at once so the build cap is tight
	return ent


func spawn_well(p: Vector2) -> Entity:
	if well_texture == null:
		return null
	var ent = spawn_static_prop(p, [well_texture] as Array[Texture2D], 1.2, 1.4)
	if ent == null:
		return null
	ent.name = "Well"
	ent.type = Game.EntityType.WELL
	_layer(ent, "wells")
	return ent


func spawn_farm_building(p: Vector2) -> Entity:
	var ent = spawn_static_prop(p, farm_building_textures, 1.4, 1.7)
	if ent == null:
		return null
	ent.name = "FarmBuilding"
	ent.type = Game.EntityType.FARM_BUILDING
	_layer(ent, "farm_buildings")
	return ent


func farm_is_ripe(f: Entity):
	return is_instance_valid(f) and f.type == Game.EntityType.FARM and f.growth_stage >= farm_textures.size() - 1


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
	_layer(ent, "farms")
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

const ANIMAL_SCALE := 1.0

func spawn_animal(p: Vector2):
	if animal_textures.is_empty():
		return null
	var ent = ANIMAL_FAB.instantiate()
	ent.type = Game.EntityType.ANIMAL
	ent.pos = p
	add_child(ent)
	ent.apply_scale(ANIMAL_SCALE)
	var tex: Texture2D = animal_textures.pick_random()
	ent.apply_scale(tex.get_width() / float(pixel_size))
	ent.set_animal_tex(tex, randf() < 0.5)
	ent.name = "Animal"
	_layer(ent, "animals")
	return ent

func wildlife(attempts := 7) -> void:
	if animal_textures.is_empty() or MapData.height_img == null or MapData.val_img == null:
		return
	for _i in attempts:
		_spawn_group()

func _spawn_group() -> void:
	var spot := _find_pasture()
	if spot == Vector2.INF:
		return
	for _n in rng.randi_range(1, 3):
		var at := spot + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 8.0)
		if _pasture_ok(at):
			spawn_animal(at)

func _wildlife_day() -> void:
	if animal_textures.is_empty() or MapData.height_img == null or MapData.val_img == null:
		return
	wildlife_capacity = _wildlife_target()
	if Game.animals >= wildlife_capacity:
		return
	var chance := 0.9 if Game.animals == 0 else 0.3
	if randf() <= chance:
		_spawn_group()

func _wildlife_target() -> int:
	var hits := 0
	const SAMPLES := 240
	for _i in SAMPLES:
		if _pasture_ok(Vector2(randf() * MapData.RESOLUTION, randf() * MapData.RESOLUTION)):
			hits += 1
	if hits == 0:
		return 0
	return clampi(int((float(hits) / SAMPLES) * 120.0), 2, 40)

const SETTLER_DELAY := 1
const SETTLER_PARTY := Vector2i(2, 3)
const SETTLER_RATIONS := 8.0

var _empty_days := 0

func _settlers_day() -> void:
	if Game.population > 0:
		_empty_days = 0
		return
	if MapData.height_img == null or MapData.val_img == null:
		return
	_empty_days += 1
	if _empty_days < SETTLER_DELAY:
		return
	var spot := _find_landing()
	if spot == Vector2.INF:
		return
	_empty_days = 0
	for _n in rng.randi_range(SETTLER_PARTY.x, SETTLER_PARTY.y):
		var at := spot + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 6.0)
		if _habitable(at):
			var f = spawn_little_guy(int(at.x), int(at.y))
			if f:
				f.carried_food = SETTLER_RATIONS
	Hud.push_notification("settlers have landed on the island")

func _find_landing() -> Vector2:
	var spot := _find_pasture()
	if spot != Vector2.INF:
		return spot
	for _try in 60:
		var p := Vector2(randf() * MapData.RESOLUTION, randf() * MapData.RESOLUTION)
		if _habitable(p):
			return p
	return Vector2.INF

func _habitable(p: Vector2) -> bool:
	if p.x < 2.0 or p.y < 2.0 or p.x > MapData.RESOLUTION - 3 or p.y > MapData.RESOLUTION - 3:
		return false
	var h: float = MapData.height_img.get_pixelv(p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r
	return h > MapData.NAV_WATER_LEVEL and h < MapData.NAV_MOUNTAIN_LEVEL


func _find_pasture() -> Vector2:
	for _try in 40:
		var p := Vector2(randf() * MapData.RESOLUTION, randf() * MapData.RESOLUTION)
		if _pasture_ok(p):
			return p
	return Vector2.INF

func _pasture_ok(p: Vector2) -> bool:
	if p.x < 2.0 or p.y < 2.0 or p.x > MapData.RESOLUTION - 3 or p.y > MapData.RESOLUTION - 3:
		return false
	var q := p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))
	var h: float = MapData.height_img.get_pixelv(q).r
	if h <= MapData.NAV_WATER_LEVEL or h >= MapData.NAV_MOUNTAIN_LEVEL:
		return false
	var c: Color = MapData.val_img.get_pixelv(q)
	var d := Vector3(c.r - MapData.GRASS_KEY.r, c.g - MapData.GRASS_KEY.g, c.b - MapData.GRASS_KEY.b)
	return d.length_squared() < 0.08


func spawn_little_guy(x: int, y: int, birth_home: Entity = null):
	var ent = FOLK_FAB.instantiate() as Entity

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
	_layer(ent, "folk")
	ent.name = folk_name

	Hud.push_notification("[i]" + folk_name + " has joined the game [/i]")

	var pop := get_tree().get_nodes_in_group("folk").size()
	if pop == 1:
		_announce("first", "the first folk have arrived")
	elif pop % 50 == 0:
		_announce("pop_%d" % pop, "the population has grown to %d folk!" % pop)

	return ent


var _announced := {}

func _announce(key, msg):
	if _announced.has(key):
		return
	_announced[key] = true
	Hud.push_notification(msg)


const _GROUP_OF := {
	Game.EntityType.TREE: "trees",
	Game.EntityType.ROCK: "rocks",
	Game.EntityType.HOUSING: "homes",
	Game.EntityType.FARM: "farms",
	Game.EntityType.WELL: "wells",
	Game.EntityType.FARM_BUILDING: "farm_buildings",
}
const _NAME_OF := {
	Game.EntityType.TREE: "Tree",
	Game.EntityType.ROCK: "Rock",
	Game.EntityType.HOUSING: "Home",
	Game.EntityType.FARM: "Farm",
	Game.EntityType.WELL: "Well",
	Game.EntityType.FARM_BUILDING: "FarmBuilding",
}

func capture_world() -> Dictionary:
	var node_id := {}
	var order := []
	for g in ["folk", "homes", "farms", "trees", "rocks", "wells", "farm_buildings", "animals"]:
		for e in get_tree().get_nodes_in_group(g):
			if not node_id.has(e):
				node_id[e] = order.size()
				order.append(e)

	var entities := []
	for e in order:
		var rec: Dictionary = e.serialize()
		rec["id"] = node_id[e]
		if e is Folk and is_instance_valid(e.home) and node_id.has(e.home):
			rec["home"] = node_id[e.home]
		else:
			rec["home"] = -1
		entities.append(rec)

	var decor := []
	for key in prop_batch._records:
		var r = prop_batch._records[key]
		for it in r.items:
			decor.append({tex = r.tex.resource_path, flip = r.flipped, px = it.p.x, py = it.p.y, s = it.s})

	return {entities = entities, decor = decor}


func restore_world(data: Dictionary) -> void:
	var id_node := {}
	var folk_links := []  # [folk_node, home_id]
	for rec in data.get("entities", []):
		var node
		if rec.get("kind", "") == "folk":
			node = _restore_folk(rec)
			folk_links.append([node, rec.get("home", -1)])
		elif rec.get("kind", "") == "animal":
			node = _restore_animal(rec)
		else:
			node = _restore_prop(rec)
		if node:
			id_node[rec.get("id", -1)] = node

	for link in folk_links:
		var h = id_node.get(link[1])
		if is_instance_valid(h):
			link[0].home = h
	for h in get_tree().get_nodes_in_group("homes"):
		h.residents.clear()
	for fk in get_tree().get_nodes_in_group("folk"):
		if is_instance_valid(fk.home):
			fk.home.residents.append(fk)

	for d in data.get("decor", []):
		var tex = load(d.get("tex", ""))
		if tex:
			prop_batch.add_decor(tex, d.get("flip", false), Vector2(d.px, d.py), d.s)

	MapData.rebuild_nav()
	if is_instance_valid(Game.model) and is_instance_valid(Game.model.map_collision):
		Game.model.map_collision.update()


func _restore_prop(rec: Dictionary):
	var ent = STATIC_PROP.instantiate() as Entity
	ent.type = rec.type
	ent.get_node("Pivot").scale = Vector3.ONE * float(rec.get("s", 1.0))

	if ent.type == Game.EntityType.FARM:
		ent.plant_day_f = rec.get("plant_day_f", 0.0)
		ent.grow_days = rec.get("grow_days", 2.0)
		ent.growth_stage = rec.get("growth_stage", 0)
		var st: int = clampi(ent.growth_stage, 0, farm_textures.size() - 1)
		ent.set_prop_mat(get_prop_material(farm_textures[st]))
	else:
		var tex = load(rec.get("tex", ""))
		if tex:
			ent.set_prop_mat(get_prop_material(tex, rec.get("flip", false)))

	if ent.type == Game.EntityType.HOUSING:
		ent.capacity = rec.get("capacity", 3)
		ent.last_birth_day = rec.get("last_birth_day", -1)

	ent.pos = Vector2(rec.px, rec.py)
	ent.name = _NAME_OF.get(ent.type, "Prop")
	add_child(ent)
	_layer(ent, _GROUP_OF.get(ent.type, ""))
	if ent.type == Game.EntityType.FARM:
		_farms.append(ent)
	return ent

func _restore_animal(rec: Dictionary):
	var ent = spawn_animal(Vector2(rec.get("px", 0.0), rec.get("py", 0.0)))
	if ent == null:
		return null
	ent.load_state(rec)
	var tex = load(rec.get("tex", ""))
	if tex:
		ent.set_animal_tex(tex, rec.get("flip", false))
	return ent


func _restore_folk(rec: Dictionary) -> Folk:
	var ent = FOLK_FAB.instantiate() as Folk
	ent.type = Game.EntityType.FOLK

	var sv = ent.get_node("Pivot/Sprite/SubViewport")
	var body = load(rec.get("body", ""))
	if body:
		(sv.get_node("body") as TextureRect).texture = body
	var shirt = load(rec.get("shirt", ""))
	if shirt:
		(sv.get_node("shirt") as TextureRect).texture = shirt
	var hair = load(rec.get("hair", ""))
	if hair:
		(sv.get_node("hair") as TextureRect).texture = hair
	(sv.get_node("hair") as TextureRect).modulate = rec.get("hair_mod", Color.WHITE)

	ent.pos = Vector2(rec.px, rec.py)
	add_child(ent)
	ent.name = rec.get("fname", "folk")
	ent.load_state(rec)
	_layer(ent, "folk")
	return ent
