class_name Animal extends Entity

const SPEED := 1.6
const FLEE_BOOST := 1.35
const SHY_RADIUS := 14.0
const GRAZE_TIME := Vector2(3.0, 7.0)
const MEAT := 12.0 # food yield

const BREED_COOLDOWN := 3
const BREED_CHANCE := 0.35
const CROWD_RADIUS := 40.0
const CROWD_LIMIT := 7
const ADULT_AGE := 2
const MAX_AGE := 26

var _graze_left := 0.0
var _wander_angle := randf() * TAU
var _age := 0
var _last_breed_day := -99
var _fleeing := false
const THREAT_RECHECK := 0.12   # seconds of real time between folk scans
var _threat_timer := randf() * THREAT_RECHECK  # staggered so they don't all scan together
var _threat := Vector2.INF
var _flip := false
var _tex: Texture2D = null

func _ready() -> void:
	super()
	is_static = false
	_graze_left = randf_range(GRAZE_TIME.x, GRAZE_TIME.y)
	add_to_group("animals")
	Game.day_changed.connect(_on_new_day)

func _physics_process(delta: float) -> void:
	var dt: float = Game.scaled_delta
	if dt <= 0.0:
		return
	if not _walkable(pos):
		queue_free()
		return

	_threat_timer -= delta
	if _threat_timer <= 0.0:
		_threat_timer = THREAT_RECHECK
		_threat = _nearest_folk()
	var threat := _threat
	if threat != Vector2.INF:
		_flee_from(threat)
	elif _graze_left > 0.0:
		_graze_left -= dt
		if _graze_left <= 0.0:
			_walk_somewhere()
	elif pos.distance_to(target_pos) < 1.2:
		_graze()

	_face_travel()


func _graze() -> void:
	_fleeing = false
	speed = SPEED
	target_pos = pos
	_graze_left = randf_range(GRAZE_TIME.x, GRAZE_TIME.y)

func _walk_somewhere() -> void:
	_fleeing = false
	speed = SPEED
	var best := Vector2.INF
	var best_score := -INF
	for _try in 6:
		var angle := _wander_angle + randf_range(-1.1, 1.1)
		var candidate := pos + Vector2.from_angle(angle) * randf_range(4.0, 12.0)
		if not _walkable(candidate):
			continue
		var score := (6.0 if _grassy(candidate) else 0.0)
		score -= absf(_height_at(candidate) - _height_at(pos)) * 8.0
		if score > best_score:
			best_score = score
			best = candidate
			_wander_angle = angle
	if best == Vector2.INF:
		_graze()
	else:
		target_pos = best

func _flee_from(threat: Vector2) -> void:
	_fleeing = true
	_graze_left = 0.0
	speed = SPEED * FLEE_BOOST
	var away := (pos - threat).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)
	var dest := pos + away * 14.0
	if _walkable(dest):
		target_pos = dest

func _nearest_folk() -> Vector2:
	var best := Vector2.INF
	var best_d := SHY_RADIUS * SHY_RADIUS
	for p in Game.positions("folk"):
		var d := pos.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best

func _walkable(p: Vector2) -> bool:
	if p.x < 1.0 or p.y < 1.0 or p.x > MapData.RESOLUTION - 2 or p.y > MapData.RESOLUTION - 2:
		return false
	var h := _height_at(p)
	return h > MapData.NAV_WATER_LEVEL and h < MapData.NAV_MOUNTAIN_LEVEL


func _grassy(p: Vector2) -> bool:
	var c: Color = MapData.val_img.get_pixelv(p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1)))
	var d := Vector3(c.r - MapData.GRASS_KEY.r, c.g - MapData.GRASS_KEY.g, c.b - MapData.GRASS_KEY.b)
	return d.length_squared() < 0.08

func _height_at(p: Vector2) -> float:
	return MapData.height_img.get_pixelv(p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r

func _face_travel() -> void:
	var dir := target_pos.x - pos.x
	if absf(dir) < 0.05:
		return
	var want := dir > 0.0
	if want != _flip:
		_flip = want
		_apply_tex()


func _apply_tex() -> void:
	if _tex == null or not is_instance_valid(Game.model):
		return
	set_prop_mat(Game.model.entity_gen.get_prop_material(_tex, _flip))


func set_animal_tex(tex: Texture2D, flip: bool) -> void:
	_tex = tex
	_flip = flip
	_apply_tex()

func _on_new_day() -> void:
	_age += 1
	if _age > MAX_AGE and randf() < 0.35:
		queue_free()
		return
	_try_breed()

func _try_breed() -> void:
	if _age < ADULT_AGE or Game.day - _last_breed_day < BREED_COOLDOWN:
		return
	if not _grassy(pos):
		return
	if not is_instance_valid(Game.model):
		return
	var gen = Game.model.entity_gen
	if Game.animals >= gen.wildlife_capacity:
		return
	var crowd := 0
	var r2 := CROWD_RADIUS * CROWD_RADIUS
	for p in Game.positions("animals"):
		if pos.distance_squared_to(p) < r2:
			crowd += 1
	if crowd > CROWD_LIMIT or randf() > BREED_CHANCE:
		return
	_last_breed_day = Game.day
	gen.spawn_animal(pos + Vector2.from_angle(randf() * TAU) * randf_range(1.0, 3.0))

func serialize() -> Dictionary:
	return {
		kind = "animal",
		type = int(type),
		px = pos.x,
		py = pos.y,
		age = _age,
		last_breed = _last_breed_day,
		flip = _flip,
		tex = _tex.resource_path if _tex else "",
	}

func load_state(d: Dictionary) -> void:
	_age = d.get("age", 0)
	_last_breed_day = d.get("last_breed", -99)
	_graze()
