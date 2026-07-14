extends Node

const RESOLUTION := 256
const WORLD_SIZE := 1500.0
const HEIGHT_SCALE := 256

var val : DrawableTexture2D
var height : DrawableTexture2D

var height_img : Image
var val_img : Image

var GRASS_KEY: Color = Color.from_rgba8(85, 130, 0, 255)
var MOUNTAIN_KEY: Color = Color.GRAY

const NAV_WATER_LEVEL := 0.05
const NAV_MOUNTAIN_LEVEL := 0.5

const MOUNTAIN_WEIGHT := 100.0
const SWIM_WEIGHT := 10.0

const MAX_SWIM := 18
var astar: AStarGrid2D

var layers : Dictionary = {}

func _ready() -> void:
	val = _make_layer(Color.ANTIQUE_WHITE)
	height = _make_layer(Color.BLACK)
	layers = {val = val, height = height}
	update()

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex

func _process(delta):
	update()

func update():
	height_img = height.get_image()
	val_img = val.get_image()

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
			astar.set_point_weight_scale(p, MOUNTAIN_WEIGHT if h < NAV_MOUNTAIN_LEVEL else 1.0)
			astar.set_point_weight_scale(p, SWIM_WEIGHT if h < NAV_WATER_LEVEL else 1.0)

func _nearest_land(p: Vector2i):
	p = p.clamp(Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1))
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
	var b = _nearest_land(Vector2i(to.round()))
	if a == null or b == null:
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
		var p := from.lerp(to, float(i) / maxf(steps, 1)).round().clamp(
			Vector2.ZERO, Vector2.ONE * (RESOLUTION - 1))
		var h := height_img.get_pixelv(p).r
		if h > NAV_MOUNTAIN_LEVEL:
			return false
		if h < NAV_WATER_LEVEL:
			run += 1
			mx = maxi(mx, run)
		else:
			run = 0
	return mx <= MAX_SWIM
