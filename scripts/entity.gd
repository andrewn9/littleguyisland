class_name Entity extends Node3D

var type: Game.EntityType = Game.EntityType.DECORATIVE
var _pos: Vector2
var pos: Vector2:
	get:
		return _pos
	set(value):
		_pos = value
		update_world_pos()
var target_pos: Vector2
var speed = 20
var is_static := true

var residents: Array = []
var capacity := 3

var reserved_by: Node = null

var growth_stage := 0
var plant_day_f := 0.0
var grow_days := 4.0

var last_birth_day := -1

func _ready() -> void:
	if not pos:
		pos = Vector2(position.x + MapData.WORLD_SIZE / 2, position.z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		target_pos = pos
	else:
		target_pos = pos

func apply_scale(x):
	$Pivot.scale *= x 

func set_prop_tex(tex):
	$Pivot/Sprite.texture = tex

func set_prop_mat(mat):
	$Pivot/MeshInstance3D.set_surface_override_material(0, mat)

func _height_from_map() -> float:
	var p1 = pos.floor().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))
	var p2 = pos.ceil().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))

	if p1 == p2:
		return MapData.height_img.get_pixelv(pos.clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r * MapData.HEIGHT_SCALE

	var d1 = pos - p1
	var d2 = p2 - pos

	var h = MapData.height_img.get_pixelv(p1).r * (1 - d1.x) * (1 - d1.y)
	h += MapData.height_img.get_pixelv(p2).r * (1 - d2.x) * (1 - d2.y)
	h += MapData.height_img.get_pixelv(Vector2(p1.x, p2.y)).r * (1 - d1.x) * (1 - d2.y)
	h += MapData.height_img.get_pixelv(Vector2(p2.x, p1.y)).r * (1 - d2.x) * (1 - d1.y)

	return h * MapData.HEIGHT_SCALE

func update_world_pos():
	var wx := pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
	var wz := pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
	var wy := _height_from_map()

	if type == Game.EntityType.HOUSING \
			and wy <= MapData.NAV_WATER_LEVEL * MapData.HEIGHT_SCALE:
		queue_free()
		return

	position = Vector3(wx, wy, wz)

func _process(delta):
	if (MapData.changed):
		update_world_pos()

	var dt: float = Game.scaled_delta
	if dt > 0.0:
		pos += (target_pos - pos).limit_length(speed * dt)
