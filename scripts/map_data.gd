extends Node

const RESOLUTION := 256
const WORLD_SIZE := 1500.0
const HEIGHT_SCALE := 256

var val: DrawableTexture2D
var height: DrawableTexture2D

var height_img: Image
var val_img: Image

var GRASS_KEY: Color = Color.from_rgba8(85, 130, 0, 255)
var MOUNTAIN_KEY: Color = Color.GRAY

const NAV_WATER_LEVEL := 0.05
const NAV_MOUNTAIN_LEVEL := 0.50

const SWIM_WEIGHT := 10.0

const MAX_SWIM := 40
var astar: AStarGrid2D

const FARM_MAX_ELEVATION := 0.16
var has_farmland := true

var layers: Dictionary = {}


func _ready() -> void:
	val = _make_layer(Color.ANTIQUE_WHITE)
	height = _make_layer(Color.BLACK)
	layers = {val = val, height = height}
	update()


func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex


var _dirty := true
var changed = false


func _process(_delta):
	changed = false
	if _dirty:
		update()
		changed = true
		get_tree().call_group(Entity.TERRAIN_PINNED, "update_world_pos")


func mark_dirty() -> void:
	_dirty = true


func update():
	height_img = height.get_image()
	val_img = val.get_image()
	_land_cache.clear()  # heights moved, so the walkable lookups are stale
	_dirty = false


func _walkable(h: float):
	return h >= NAV_WATER_LEVEL and h <= NAV_MOUNTAIN_LEVEL


func rebuild_nav() -> void:
	if height_img == null:
		update()
	if height_img == null:
		return
	if astar == null:
		astar = AStarGrid2D.new()
		astar.region = Rect2i(0, 0, RESOLUTION, RESOLUTION)
		astar.cell_size = Vector2.ONE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.update()
	for y in RESOLUTION:
		for x in RESOLUTION:
			var h := height_img.get_pixel(x, y).r
			var p := Vector2i(x, y)
			astar.set_point_solid(p, h > NAV_MOUNTAIN_LEVEL)
			astar.set_point_weight_scale(p, SWIM_WEIGHT if h < NAV_WATER_LEVEL else 1.0)
	_scan_farmland()


func _scan_farmland() -> void:
	has_farmland = false
	if height_img == null or val_img == null:
		return
	for y in range(0, RESOLUTION, 2):
		for x in range(0, RESOLUTION, 2):
			var h := height_img.get_pixel(x, y).r
			if h < NAV_WATER_LEVEL + 0.01 or h > FARM_MAX_ELEVATION:
				continue
			var c := val_img.get_pixel(x, y)
			var dm := Vector3(c.r - MOUNTAIN_KEY.r, c.g - MOUNTAIN_KEY.g, c.b - MOUNTAIN_KEY.b).length_squared()
			if dm <= 0.0125:
				continue
			if _has_water_neighbor(x, y):
				has_farmland = true
				return


func _has_water_neighbor(x: int, y: int) -> bool:
	for dy in range(-5, 6, 2):
		for dx in range(-5, 6, 2):
			var nx := clampi(x + dx, 0, RESOLUTION - 1)
			var ny := clampi(y + dy, 0, RESOLUTION - 1)
			if height_img.get_pixel(nx, ny).r < NAV_WATER_LEVEL:
				return true
	return false


var _land_cache := {}


func _nearest_land(p: Vector2i):
	p = p.clamp(Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1))
	if _land_cache.has(p):
		return _land_cache[p]
	var found = _search_land(p)
	_land_cache[p] = found
	return found


func _search_land(p: Vector2i):
	if _walkable(height_img.get_pixelv(p).r):
		return p
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  # only the ring at radius r
				var q := (p + Vector2i(dx, dy)).clamp(Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1))
				if _walkable(height_img.get_pixelv(q).r):
					return q
	return null


func _longest_water_run(path: PackedVector2Array):
	var run := 0
	var mx := 0
	for pt in path:
		if height_img.get_pixelv(pt.clamp(Vector2.ZERO, Vector2.ONE * (RESOLUTION - 1))).r < NAV_WATER_LEVEL:
			run += 1
			mx = maxi(mx, run)
		else:
			run = 0
	return mx


func find_path(from: Vector2, to: Vector2):
	if astar == null:
		rebuild_nav()
	if astar == null:
		return PackedVector2Array()
	var a = _nearest_land(Vector2i(from.round()))
	if a == null:
		return PackedVector2Array()  # standing somewhere with no way off
	var b = _nearest_land(Vector2i(to.round()))
	if b == null:
		return PackedVector2Array()
	var path = astar.get_point_path(a, b)
	if _longest_water_run(path) > MAX_SWIM:
		return PackedVector2Array()  # would need too long a swim -> unreachable
	return path


func clear_path(from: Vector2, to: Vector2):
	if height_img == null:
		return false
	var steps := int(ceil(from.distance_to(to)))
	var run := 0
	var mx := 0
	for i in steps + 1:
		var p := from.lerp(to, float(i) / maxf(steps, 1)).round().clamp(Vector2.ZERO, Vector2.ONE * (RESOLUTION - 1))
		var h := height_img.get_pixelv(p).r
		if h > NAV_MOUNTAIN_LEVEL:
			return false
		if h < NAV_WATER_LEVEL:
			run += 1
			mx = maxi(mx, run)
		else:
			run = 0
	return mx <= MAX_SWIM
