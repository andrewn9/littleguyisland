class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }
enum Goal { ROAM, GATHER, BUILD, GO_HOME }

var wander_radius := 14.0
var idle_time_range := Vector2(1.0, 4.0)
var water_level := 0.05
var walk_speed := 10.0
var swim_speed := 2.0
var climb_slowdown := 14.0

var adventurousness := 0.5
var social_radius := 24.0

var elevation_attachment := 6.0

var happiness := 0.6

var wood_per_tree := 2
var wood_to_build := 4
var home_capacity := 3

var chop_time := 3.0
var build_time := 4.0

var tree_search_radius := 90.0

var home_group_radius := 70.0

var neighbour_home_radius := 40.0

@export var viewport: SubViewport

var state: FolkState = FolkState.IDLE
var goal: Goal = Goal.ROAM

var home: Entity = null
var carried_wood := 0

var _idle_left := 0.0
var _interact_left := 0.0
var _neighbors := 0
var _community := 0 # neighbouring homes
var _at_home := false
var _social_timer := randf()
var _roam_goal := Vector2.ZERO

var _target_entity: Entity = null
var _pending_tree: Entity = null

@onready var _sprite = $Pivot/Sprite

func _ready():
	super()
	adventurousness = randf()
	_decide()
	is_static = false

func tick(dt: float):
	_update_happiness(dt)

	match state:
		FolkState.IDLE:
			_idle_left -= dt
			if _idle_left <= 0.0:
				_decide()
		FolkState.WALKING, FolkState.SWIMMING:
			state = FolkState.SWIMMING if _height_at(pos) < water_level \
					else FolkState.WALKING
			var base = swim_speed if state == FolkState.SWIMMING else walk_speed
			speed = base * _climb_factor() * lerpf(0.85, 1.1, happiness)
			if pos.distance_to(target_pos) < 1.5:
				_arrive()
		FolkState.INTERACTING:
			_interact_left -= dt
			if _interact_left <= 0.0:
				_finish_interact()
		FolkState.DEAD:
			target_pos = pos


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var camera = get_viewport().get_camera_3d() as CameraController
		 
		var min = camera.unproject_position(global_position + Vector3(0, 14, 0))
		var max = camera.unproject_position(global_position)

		var h = max.y - min.y
		min.x -= h * 2 / 7
		max.x += h * 2 / 7

		if event.position.x > min.x and event.position.x < max.x and event.position.y > min.y and event.position.y < max.y:
			Hud.show_profile(self)
			camera._target_orthographic_size = 35.0
			camera.pan_offset = self.global_position
		
		viewport.push_input(event)

func _physics_process(_delta: float) -> void:
	var dt = Game.scaled_delta
	if dt == 0:
		return
	tick(dt)


func _decide():
	_at_home = false
	goal = _choose_goal()

	match goal:
		Goal.GO_HOME:
			_target_entity = home
			target_pos = home.pos
			state = FolkState.WALKING
		Goal.GATHER:
			var tree = _find_nearest(Game.EntityType.TREE, tree_search_radius)
			if tree:
				_target_entity = tree
				target_pos = tree.pos
				state = FolkState.WALKING
			else:
				_roam()
		Goal.BUILD:
			_target_entity = null
			target_pos = _pick_build_spot()
			state = FolkState.WALKING
		Goal.ROAM:
			_roam()

func _choose_goal() -> Goal:
	if home == null:
		var joinable = _find_joinable_home()
		if joinable:
			home = joinable
			joinable.residents.append(self)

	if Game.is_night():
		return Goal.GO_HOME if home else Goal.ROAM

	if carried_wood >= wood_to_build:
		return Goal.BUILD
	_pending_tree = _find_nearest(Game.EntityType.TREE, tree_search_radius)
	if _pending_tree:
		return Goal.GATHER
	return Goal.ROAM

func _arrive() -> void:
	target_pos = pos
	match goal:
		Goal.GO_HOME:
			if home and pos.distance_to(home.pos) < 4.0:
				_claim_home()
			else:
				_rest()
		Goal.GATHER:
			if _target_entity and _target_entity.type == Game.EntityType.TREE:
				state = FolkState.INTERACTING
				_interact_left = chop_time
			else:
				_rest() # tree already cut
		Goal.BUILD:
			state = FolkState.INTERACTING
			_interact_left = build_time
		Goal.ROAM:
			_rest()

func _finish_interact() -> void:
	match goal:
		Goal.GATHER:
			if _target_entity:
				carried_wood += wood_per_tree
				_target_entity.queue_free()
			_target_entity = null
		Goal.BUILD:
			_make_house()
	_rest()

func _make_house() -> void:
	if carried_wood < wood_to_build:
		return
	var built: Entity = get_parent().spawn_home(pos, home_capacity)
	if built == null:
		return
	carried_wood -= wood_to_build
	if not home:
		home = built
		built.residents.append(self)

func _claim_home() -> void:
	_at_home = true
	state = FolkState.IDLE
	_community = _count_nearby_homes(neighbour_home_radius)
	_idle_left = randf_range(4.0, 8.0) # rest til morn

func _update_happiness(dt: float) -> void:
	_social_timer -= dt
	if _social_timer <= 0.0: # regroup
		_social_timer = 1.0
		_flock_center()

	var drift := 0.03 if _neighbors > 0 else -0.01 # lonliness sadge
	if _at_home:
		drift += 0.06 * (1.0 + 0.4 * _community)
	elif Game.is_night() and not home:
		drift -= 0.05
	if state == FolkState.SWIMMING:
		drift -= 0.08

	happiness = clampf(happiness + drift * dt, 0.0, 1.0)

func _roam() -> void:
	var target := _pick_wander_target()
	if target.is_finite():
		target_pos = target
		state = FolkState.WALKING
	else:
		_rest()
		
func _rest() -> void:
	state = FolkState.IDLE
	target_pos = pos
	var laziness := lerpf(1.4, 0.7, happiness) * lerpf(1.3, 0.6, adventurousness)
	_idle_left = randf_range(idle_time_range.x, idle_time_range.y) * laziness

func _pick_wander_target() -> Vector2:
	if pos.distance_to(_roam_goal) < wander_radius:
		_roam_goal = _new_roam_goal()

	var stride = wander_radius * lerpf(0.8, 1.6, adventurousness)
	var to_goal = _roam_goal - pos
	var heading = to_goal.normalized() if to_goal.length() > 1.0 \
			else Vector2.from_angle(randf() * TAU)
	var here_h = _height_at(pos)

	var best = Vector2.INF
	var best_score = -INF
	for _try in 8:
		var dir = heading.rotated(deg_to_rad(randf_range(-55.0, 55.0)))
		var candidate = pos + dir * randf_range(stride * 0.5, stride)
		if not _on_map(candidate) or _height_at(candidate) < water_level:
			continue
		var progress = (pos.distance_to(_roam_goal) - candidate.distance_to(_roam_goal)) \
				/ stride
		var score = progress + randf() * 0.25
		var scaredness = adventurousness * lerpf(0.4, 1.0, happiness)
		score -= absf(_height_at(candidate) - here_h) * elevation_attachment \
				* (1.0 - scaredness * 0.9)
		if score > best_score:
			best_score = score
			best = candidate

	if best.is_finite():
		return best
	_roam_goal = Vector2.INF
	for _try in 4:
		var candidate = pos + Vector2.from_angle(randf() * TAU) \
				* randf_range(3.0, stride)
		if _on_map(candidate):
			return candidate
	return Vector2.INF

func _new_roam_goal() -> Vector2:
	var nerve = adventurousness * lerpf(0.4, 1.0, happiness)
	var center = Vector2.ONE * MapData.RESOLUTION * 0.5
	var map_r = MapData.RESOLUTION * 0.5 - 4.0
	for _try in 24:
		var g: Vector2
		if randf() < nerve:
			g = center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * map_r
		else:
			var anchor = _flock_center()
			if not anchor.is_finite():
				anchor = pos
			var reach = wander_radius * lerpf(2.0, 6.0, adventurousness)
			g = anchor + Vector2.from_angle(randf() * TAU) * randf_range(0.0, reach)
		if _on_map(g) and _height_at(g) >= water_level:
			return g
	return pos

func _find_nearest(entity_type: Game.EntityType, radius: float):
	var best: Entity = null
	var best_d = radius
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == entity_type:
			var d = pos.distance_to((other as Entity).pos)
			if d < best_d:
				best_d = d
				best = other
	return best

func _find_joinable_home() -> Entity:
	var best: Entity = null
	var best_d = home_group_radius
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.HOUSING:
			var h = other as Entity
			if h.residents.size() < h.capacity:
				var d = pos.distance_to(h.pos)
				if d < best_d:
					best_d = d
					best = h
	return best

func _count_nearby_homes(radius: float) -> int:
	var c = 0
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.HOUSING \
				and other != home and pos.distance_to((other as Entity).pos) < radius:
			c += 1
	return c

func _pick_build_spot() -> Vector2:
	var anchor = pos
	var nearest = _find_nearest(Game.EntityType.HOUSING, 120.0)
	if nearest:
		anchor = nearest.pos
	for _try in 16:
		var spot = anchor + Vector2.from_angle(randf() * TAU) * randf_range(6.0, 16.0)
		if _on_map(spot) and _height_at(spot) >= water_level + 0.02 \
				and _find_nearest_home_dist(spot) > 5.0:
			return spot
	return pos

func _find_nearest_home_dist(p: Vector2) -> float:
	var d = 9999.0
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.HOUSING:
			d = minf(d, p.distance_to((other as Entity).pos))
	return d

func _flock_center() -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for other in get_parent().get_children():
		if other is Folk and other != self and other.state != FolkState.DEAD \
				and pos.distance_to(other.pos) < social_radius:
			sum += other.pos
			count += 1
	_neighbors = count
	if count == 0:
		return Vector2.INF
	return sum / count

func _climb_factor():
	var dir = target_pos - pos
	if dir.length_squared() < 0.01:
		return 1.0
	var ahead = pos + dir.limit_length(3.0)
	var grade = absf(_height_at(ahead) - _height_at(pos)) / 3.0
	var s = grade * climb_slowdown * 4.5
	return clampf(1.0 / (1.0 + s * s), 0.12, 1.0)

func _on_map(p: Vector2):
	var half = MapData.RESOLUTION * 0.5
	return p.distance_to(Vector2(half, half)) < half - 2.0

func _height_at(p: Vector2):
	return MapData.height_img.get_pixelv(p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r
