class_name Entity extends Node3D

var type: Game.EntityType = Game.EntityType.DECORATIVE
var pos: Vector2
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
	return MapData.height_img.get_pixelv(pos.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r * MapData.HEIGHT_SCALE

func update_height():
	var wx := pos.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
	var wz := pos.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
	var wy := _height_from_map()

	if type == Game.EntityType.HOUSING \
			and wy <= MapData.NAV_WATER_LEVEL * MapData.HEIGHT_SCALE:
		queue_free()
		return

	if not is_static and is_inside_tree():
		var space := get_world_3d().direct_space_state
		var from := Vector3(wx, MapData.HEIGHT_SCALE + 100.0, wz)
		var to := Vector3(wx, -100.0, wz)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if hit:
			wy = hit.position.y

	position = Vector3(wx, wy, wz)

var _positioned := false

func _process(delta):
	if is_static:
		if type == Game.EntityType.HOUSING:
			update_height()
		elif not _positioned:
			update_height()
			_positioned = true
		return

	var dt: float = Game.scaled_delta
	var moved := false
	if dt > 0.0:
		var prev := pos
		pos += (target_pos - pos).limit_length(speed * dt)
		moved = not pos.is_equal_approx(prev)
	if moved or not _positioned:
		update_height()
		_positioned = true
