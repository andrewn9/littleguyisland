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
			astar.set_point_solid(Vector2i(x, y), not _walkable(height_img.get_pixel(x, y).r))

func _nearest_walkable(p: Vector2i):
	p = p.clamp(Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1))
	if not astar.is_point_solid(p):
		return p
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  # only the ring at radius r
				var q := (p + Vector2i(dx, dy)).clamp(Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1))
				if not astar.is_point_solid(q):
					return q
	return null

func find_path(from: Vector2, to: Vector2):
	if astar == null:
		rebuild_nav()
	if astar == null:
		return PackedVector2Array()
	var a = _nearest_walkable(Vector2i(from.round()))
	var b = _nearest_walkable(Vector2i(to.round()))
	if a == null or b == null:
		return PackedVector2Array()
	return astar.get_point_path(a, b)

func clear_path(from: Vector2, to: Vector2):
	if height_img == null:
		return false
	var steps := int(ceil(from.distance_to(to)))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / maxf(steps, 1)).round().clamp(
			Vector2.ZERO, Vector2.ONE * (RESOLUTION - 1))
		if not _walkable(height_img.get_pixelv(p).r):
			return false
	return true
