class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }

@export var wander_radius := 14.0
@export var idle_time_range := Vector2(1.0, 4.0)
@export var water_level := 0.05
@export var walk_speed := 20.0
@export var swim_speed := 8.0

var state: FolkState = FolkState.IDLE

var _idle_left := 0.0

@onready var _sprite = get_node_or_null("Pivot/Sprite")


func _ready() -> void:
	super()
	_rest()


func tick(dt: float) -> void:
	match state:
		FolkState.IDLE:
			_idle_left -= dt
			if _idle_left <= 0.0:
				state = FolkState.WANDER

		FolkState.WANDER:
			var target := _pick_wander_target()
			if target.is_finite():
				target_pos = target
				state = FolkState.WALKING
			else:
				_rest()

		FolkState.WALKING, FolkState.SWIMMING:
			state = FolkState.SWIMMING if _height_at(pos) < water_level \
					else FolkState.WALKING
			speed = swim_speed if state == FolkState.SWIMMING else walk_speed
			_face_target()
			if pos.distance_to(target_pos) < 0.5:
				_rest()

		FolkState.INTERACTING:
			pass  # reserved: stays put until whatever it's doing releases it

		FolkState.DEAD:
			target_pos = pos


func _physics_process(_delta: float) -> void:
	var dt = Game.scaled_delta
	if dt == 0:
		return

	tick(dt)


func _rest() -> void:
	state = FolkState.IDLE
	target_pos = pos
	_idle_left = randf_range(idle_time_range.x, idle_time_range.y)


func _pick_wander_target() -> Vector2:
	for _try in 8:
		var candidate := pos + Vector2.from_angle(randf() * TAU) \
				* randf_range(3.0, wander_radius)
		if _on_map(candidate) and _height_at(candidate) >= water_level:
			return candidate
	for _try in 4:
		var candidate := pos + Vector2.from_angle(randf() * TAU) \
				* randf_range(3.0, wander_radius)
		if _on_map(candidate):
			return candidate
	return Vector2.INF


func _on_map(p: Vector2) -> bool:
	var half := MapData.RESOLUTION * 0.5
	return p.distance_to(Vector2(half, half)) < half - 2.0


func _height_at(p: Vector2) -> float:
	return MapData.height_img.get_pixelv(
		Vector2i(p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1)))
	).r


func _face_target() -> void:
	if _sprite and absf(target_pos.x - pos.x) > 0.1:
		_sprite.flip_h = target_pos.x < pos.x
