class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }

@export_group("Movement")
@export var wander_radius := 14.0
@export var idle_time_range := Vector2(1.0, 4.0)

@export var water_level := 0.05

@export var walk_speed := 20.0
@export var swim_speed := 8.0

@export var climb_slowdown := 14.0

@export var adventurousness := 0.5
@export var social_radius := 24.0
@export var socialness := 1.0

@export var elevation_attachment := 8.0

@export var happiness := 0.6

@export var viewport: SubViewport

var state: FolkState = FolkState.IDLE

var _idle_left := 0.0
var _neighbors := 0
var _social_timer := randf()

@onready var _sprite = get_node_or_null("Pivot/Sprite")

func _ready() -> void:
	super()
	adventurousness = randf()
	_rest()
	is_static = false


func tick(dt: float) -> void:
	_update_happiness(dt)

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
			var base := swim_speed if state == FolkState.SWIMMING else walk_speed
			speed = base * _climb_factor() * lerpf(0.85, 1.1, happiness)
			_face_target()
			if pos.distance_to(target_pos) < 0.5:
				_rest()

		FolkState.INTERACTING:
			pass  # reserved: stays put until whatever it's doing releases it

		FolkState.DEAD:
			target_pos = pos


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var camera = get_viewport().get_camera_3d()
		
		var min = camera.unproject_position(global_position + Vector3(0, 14, 0))
		var max = camera.unproject_position(global_position)

		var h = max.y - min.y
		min.x -= h * 2 / 7
		max.x += h * 2 / 7

		if event.position.x > min.x and event.position.x < max.x and event.position.y > min.y and event.position.y < max.y:
			Hud.show_profile(self)
		
		viewport.push_input(event)

func _physics_process(_delta: float) -> void:
	var dt = Game.scaled_delta
	if dt == 0:
		return

	tick(dt)

func _rest() -> void:
	state = FolkState.IDLE
	target_pos = pos
	var laziness := lerpf(1.4, 0.7, happiness) * lerpf(1.3, 0.6, adventurousness)
	_idle_left = randf_range(idle_time_range.x, idle_time_range.y) * laziness

func _update_happiness(dt: float) -> void:
	_social_timer -= dt
	if _social_timer <= 0.0:
		_social_timer = 1.0
		_flock_center()
	var drift := 0.03 if _neighbors > 0 else -0.015
	if state == FolkState.SWIMMING:
		drift -= 0.08
	happiness = clampf(happiness + drift * dt, 0.0, 1.0)

func _pick_wander_target() -> Vector2:
	var here_h := _height_at(pos)
	var radius := wander_radius * lerpf(0.6, 1.8, adventurousness)
	var flock := _flock_center()
	var best := Vector2.INF
	var best_score := -INF

	for _try in 10:
		var candidate := pos + Vector2.from_angle(randf() * TAU) \
				* randf_range(3.0, radius)
		if not _on_map(candidate) or _height_at(candidate) < water_level:
			continue
		var score := randf() * 0.3  # whimsy
		score -= absf(_height_at(candidate) - here_h) * elevation_attachment \
				* (1.0 - adventurousness * 0.8)
		if flock.is_finite():
			var progress := (pos.distance_to(flock) - candidate.distance_to(flock)) \
					/ maxf(radius, 1.0)
			score += progress * socialness * (1.0 - adventurousness * 0.7) \
					* lerpf(1.5, 0.5, happiness)
		if score > best_score:
			best_score = score
			best = candidate

	if best.is_finite():
		return best
	for _try in 4:
		var candidate := pos + Vector2.from_angle(randf() * TAU) \
				* randf_range(3.0, radius)
		if _on_map(candidate):
			return candidate
	return Vector2.INF

func _flock_center() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for other in get_parent().get_children():
		if other is Folk and other != self and other.state != FolkState.DEAD \
				and pos.distance_to(other.pos) < social_radius:
			sum += other.pos
			count += 1
	_neighbors = count
	if count == 0:
		return Vector2.INF
	return sum / count

func _climb_factor() -> float:
	var dir := target_pos - pos
	if dir.length_squared() < 0.01:
		return 1.0
	var rise := _height_at(pos + dir.limit_length(2.0)) - _height_at(pos)
	if rise <= 0.0:
		return 1.0
	return clampf(1.0 / (1.0 + rise * climb_slowdown * 20.0), 0.2, 1.0)

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
