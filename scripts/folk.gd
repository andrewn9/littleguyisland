class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }
enum Goal { ROAM, GATHER, BUILD, GO_HOME, FARM, HARVEST }

var wander_radius := 30.0
var idle_time_range := Vector2(0.20, 0.5)
var water_level := 0.05
var walk_speed := 1.0
var swim_speed := 0.25
var climb_slowdown := 14.0

var meander := 1.4 # width of wander cone
var roam_rest_chance := 0.5

var adventurousness := 0.5
var content_threshold := 0.7
var adventure_growth := 0.00015
var social_radius := 24.0

var elevation_attachment := 6.0

var happiness := 0.6

var wood_per_tree := 2
var wood_to_build := 4
var home_capacity := 3

var chop_time := 3.0
var build_time := 4.0

var farm_search_radius := 120.0 # harvest
var farm_reach := 40.0 # start farming x distance from home
var farm_water_radius := 5.0 # radius from water
var farm_max_elevation := 0.16 # only low-lying coastal ground is farmable
var farm_field_radius := 40.0 # grouping for big farm
var farm_spacing := 2.5 # min gap
var plant_time := 5.0
var harvest_time := 2.5

var farm_target_per_person := 1.5
var hungry_roam_radius := 18.0

var tree_search_radius := 90.0

var home_group_radius := 70.0

var home_spacing := Vector2(1.0, 6.0)

var night_home_range := 30.0
var takeover_radius := 45.0

var birth_chance := 0.75

var share_radius := 24.0

var neighbour_home_radius := 10.0

@export var viewport: SubViewport

var state: FolkState = FolkState.IDLE
var goal: Goal = Goal.ROAM
var age := 0

var home: Entity = null
var carried_wood := 0

var _idle_left := 0.0
var _interact_left := 0.0
var _neighbors := 0
var _community := 0 # neighbouring homes
var _at_home := false
var _social_timer := randf()
var _roam_goal := Vector2.ZERO
var _wander_angle := randf() * TAU  # current heading, random-walked for meander

var _target_entity: Entity = null
var _pending_tree: Entity = null
var _pending_crop: Entity = null
var _farm_spot := Vector2.INF

var _path: PackedVector2Array = []  # remaining waypoints toward the destination
var _path_i := 0

@onready var _sprite = $Pivot/Sprite

func _ready():
	super()
	adventurousness = randf()
	_decide()
	is_static = false
	Game.day_changed.connect(func():
		age +=1
	)

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
			var last := _path_i >= _path.size() - 1
			var arrive_radius = (3.5 if goal == Goal.GO_HOME else 1.5) if last else 1.5
			if pos.distance_to(target_pos) < arrive_radius:
				if last:
					_arrive()
				else:
					_path_i += 1
					target_pos = _path[_path_i]
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

		if event.position.x > min.x and event.position.x < max.x and event.position.y > min.y and event.position.y < max.y and Hud.active.name == "Click":
			Hud.show_profile(self)
		elif Hud.focused_folk == self:
			Hud.hide_profile()
		
		viewport.push_input(event)

func _physics_process(_delta: float):
	var dt = Game.scaled_delta
	if dt == 0:
		return
	tick(dt)
	
	if Hud.focused_folk == self:
		Hud.happiness_bar.value = happiness * 100
		Hud.homeless_label.text = "homeless? nah" if is_instance_valid(home) else "homeless? yeah"
		var doing = ""
		match state:
			FolkState.IDLE:
				doing = "resting"
			FolkState.WANDER:
				doing = "folking around"
			FolkState.WALKING:
				doing = "travelling"
			FolkState.SWIMMING:
				doing = "sailing the high seas"
			FolkState.INTERACTING:
				doing = "tasking"
			FolkState.DEAD:
				doing = "decomissioned"
		Hud.status_label.text = "status: %s" % doing
		Hud.age_label.text = "age: %d%s" % [age, " days old" if age != 1 else " day old"]

func _decide():
	_release_claim()  # drop any tree/crop claim from a previous plan
	goal = _choose_goal()

	if goal == Goal.GO_HOME and is_instance_valid(home) \
			and pos.distance_to(home.pos) < 16.0:
		_claim_home()
		return

	_at_home = false
	visible = true
	match goal:
		Goal.GO_HOME:
			_target_entity = home
			if not _go_to(home.pos):
				_rest()
		Goal.GATHER:
			if is_instance_valid(_pending_tree) and _pending_tree.reserved_by == null \
					and _go_to(_pending_tree.pos):
				_target_entity = _pending_tree
				_pending_tree.reserved_by = self
			else:
				_roam()
		Goal.BUILD:
			_target_entity = null
			if not _go_to(_pick_build_spot()):
				_rest()
		Goal.FARM:
			_target_entity = null
			if not (_farm_spot.is_finite() and _go_to(_farm_spot)):
				_rest()
		Goal.HARVEST:
			if is_instance_valid(_pending_crop) and _pending_crop.reserved_by == null \
					and _go_to(_pending_crop.pos):
				_target_entity = _pending_crop
				_pending_crop.reserved_by = self
			else:
				_rest()
		Goal.ROAM:
			_roam()

func _go_to(dest: Vector2):
	if MapData.clear_path(pos, dest): # straight line
		_path = PackedVector2Array([dest])
	else:
		_path = MapData.find_path(pos, dest)
	if _path.is_empty():
		return false
	_path_i = 0
	target_pos = _path[0]
	state = FolkState.WALKING
	return true

func _choose_goal() -> Goal:
	if not is_instance_valid(home):
		home = null
		var joinable = _find_joinable_home()
		if joinable:
			home = joinable
			joinable.residents.append(self)

	if Game.is_night():
		if is_instance_valid(home):
			if pos.distance_to(home.pos) > night_home_range:
				var shelter = _find_unowned_home(takeover_radius)
				if shelter and pos.distance_to(shelter.pos) < pos.distance_to(home.pos):
					home.residents.erase(self)
					home = shelter
					shelter.residents.append(self)
			return Goal.GO_HOME
		return Goal.ROAM

	
	_pending_crop = _find_ripe_crop(farm_search_radius)
	if _pending_crop:
		return Goal.HARVEST

	if not is_instance_valid(home):
		return _build_or_gather()

	if Game.farm_count < Game.population * farm_target_per_person:
		var spot = _find_farm_spot()
		if spot.is_finite():
			_farm_spot = spot
			return Goal.FARM

	return _build_or_gather()

func _build_or_gather() -> Goal:
	if not Game.needs_housing():
		return Goal.ROAM
	if carried_wood < wood_to_build:
		_share_wood()
	if carried_wood >= wood_to_build:
		return Goal.BUILD
	_pending_tree = _find_nearest(Game.EntityType.TREE, tree_search_radius, true)
	if _pending_tree:
		return Goal.GATHER
	return Goal.ROAM

func _arrive():
	target_pos = pos
	match goal:
		Goal.GO_HOME:
			if home and pos.distance_to(home.pos) < 4.0:
				_claim_home()
			else:
				_rest()
		Goal.GATHER:
			if is_instance_valid(_target_entity) and _target_entity.type == Game.EntityType.TREE:
				state = FolkState.INTERACTING
				_interact_left = chop_time
			else:
				_release_claim()  # tree already cut / gone
				_rest()
		Goal.BUILD:
			state = FolkState.INTERACTING
			_interact_left = build_time
		Goal.FARM:
			state = FolkState.INTERACTING
			_interact_left = plant_time
		Goal.HARVEST:
			if is_instance_valid(_target_entity) and get_parent().farm_is_ripe(_target_entity):
				state = FolkState.INTERACTING
				_interact_left = harvest_time
			else:
				_release_claim()  # crop gone / harvested by someone else
				_rest()
		Goal.ROAM:
			if randf() < roam_rest_chance:
				_rest()
			else:
				_roam()

func _finish_interact():
	match goal:
		Goal.GATHER:
			if is_instance_valid(_target_entity):
				carried_wood += wood_per_tree
				_target_entity.queue_free()  # claim dies with the tree
			_target_entity = null
		Goal.BUILD:
			_make_house()
		Goal.FARM:
			get_parent().spawn_farm(_farm_spot if _farm_spot.is_finite() else pos)
		Goal.HARVEST:
			if get_parent().farm_is_ripe(_target_entity):
				Game.food += Game.crop_yield
				_target_entity.queue_free()  # reaped; claim dies with it
			_target_entity = null
	_rest()

func _release_claim():
	if is_instance_valid(_target_entity) and _target_entity.reserved_by == self:
		_target_entity.reserved_by = null

func _find_ripe_crop(radius: float) -> Entity:
	var best: Entity = null
	var best_d = radius
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.FARM \
				and get_parent().farm_is_ripe(other) \
				and not (is_instance_valid(other.reserved_by) and other.reserved_by != self):
			var d = pos.distance_to((other as Entity).pos)
			if d < best_d:
				best_d = d
				best = other
	return best

func _find_farm_spot() -> Vector2:
	var field = _find_nearest(Game.EntityType.FARM, farm_field_radius)
	if is_instance_valid(field): # existing field
		for _try in 24:
			var spot = field.pos + Vector2.from_angle(randf() * TAU) \
					* randf_range(farm_spacing, farm_spacing * 2.0)
			if _on_map(spot) and _farmable(spot) and not _farm_too_close(spot, farm_spacing):
				return spot
		return Vector2.INF
	
	var anchor = home.pos if is_instance_valid(home) else pos
	for _try in 24:
		var spot = anchor + Vector2.from_angle(randf() * TAU) * randf_range(4.0, farm_reach)
		if _on_map(spot) and _farmable(spot) and not _farm_too_close(spot, farm_spacing):
			return spot
	return Vector2.INF

func _farmable(p: Vector2):
	var h = _height_at(p)
	return h >= water_level + 0.01 and h <= farm_max_elevation \
			and _near_water(p) and _fertile(p)

func _fertile(p: Vector2):
	var c = MapData.val_img.get_pixelv(
		p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1)))
	var dm = Vector3(c.r - MapData.MOUNTAIN_KEY.r, c.g - MapData.MOUNTAIN_KEY.g, c.b - MapData.MOUNTAIN_KEY.b).length_squared()
	return dm > 0.0125

func _near_water(p: Vector2):
	var r := int(farm_water_radius)
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if dx * dx + dy * dy > r * r:
				continue
			if _height_at(p + Vector2(dx, dy)) < water_level:
				return true
	return false

func _farm_too_close(p: Vector2, r: float):
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.FARM \
				and p.distance_to((other as Entity).pos) < r:
			return true
	return false

func _make_house():
	if carried_wood < wood_to_build or not Game.needs_housing():
		return
	var built: Entity = get_parent().spawn_home(pos, home_capacity)
	if built == null:
		return
	carried_wood -= wood_to_build
	if not home:
		home = built
		built.residents.append(self)

func _claim_home():
	_at_home = true
	visible = false
	state = FolkState.IDLE
	_community = _count_nearby_homes(neighbour_home_radius)
	_idle_left = randf_range(8.0, 16.0) # rest til morn
	_maybe_birth()

func _maybe_birth():
	if not (Game.is_night() and is_instance_valid(home)):
		return
	if home.residents.size() < 2 or home.last_birth_day == Game.day:
		return
	if not Game.prosperous():
		return
	if randf() < birth_chance:
		home.last_birth_day = Game.day
		get_parent().spawn_little_guy(int(home.pos.x), int(home.pos.y))

func _update_happiness(dt: float):
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
	if Game.food <= 0.0:
		drift -= 0.06  # hungry -> unhappy

	happiness = clampf(happiness + drift * dt, 0.0, 1.0)

	if happiness > content_threshold:
		adventurousness = minf(1.0, adventurousness + adventure_growth * dt)

func _roam():
	var target := _pick_wander_target()
	if target.is_finite() and _go_to(target):
		return
	_rest()
		
func _rest():
	state = FolkState.IDLE
	target_pos = pos
	var laziness := lerpf(1.4, 0.7, happiness) * lerpf(1.3, 0.6, adventurousness)
	_idle_left = randf_range(idle_time_range.x, idle_time_range.y) * laziness

func _pick_wander_target() -> Vector2:
	var eff_wander = minf(wander_radius, hungry_roam_radius) if Game.hungry() else wander_radius
	if not _roam_goal.is_finite() or pos.distance_to(_roam_goal) < eff_wander:
		_roam_goal = _new_roam_goal()

	var stride = eff_wander * lerpf(0.8, 1.6, adventurousness)
	var to_goal = _roam_goal - pos
	var goal_dir = to_goal.normalized() if to_goal.length() > 1.0 else Vector2.ZERO
	var here_h = _height_at(pos)
	var scaredness = adventurousness * lerpf(0.4, 1.0, happiness)

	var best = Vector2.INF
	var best_score = -INF
	var best_angle = _wander_angle
	for _try in 8:
		var angle = _wander_angle + randf_range(-meander, meander)
		var dir = Vector2.from_angle(angle)
		var candidate = pos + dir * randf_range(stride * 0.6, stride)
		if not _on_map(candidate) or _height_at(candidate) < water_level:
			continue
		var score = randf() * 0.5 + dir.dot(goal_dir) * 0.4
		score -= absf(_height_at(candidate) - here_h) * elevation_attachment \
				* (1.0 - scaredness * 0.9)
		if score > best_score:
			best_score = score
			best = candidate
			best_angle = angle

	if best.is_finite():
		_wander_angle = best_angle  # carry the heading forward for momentum
		return best
	
	_roam_goal = Vector2.INF
	for _try in 4:
		_wander_angle += randf_range(1.5, 3.0)
		var candidate = pos + Vector2.from_angle(_wander_angle) \
				* randf_range(3.0, stride)
		if _on_map(candidate):
			return candidate
	return Vector2.INF

func _new_roam_goal() -> Vector2:
	if Game.hungry() and is_instance_valid(home):
		for _try in 12:
			var g = home.pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, hungry_roam_radius)
			if _on_map(g) and _height_at(g) >= water_level:
				return g
		return home.pos

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

func _find_nearest(entity_type: Game.EntityType, radius: float, skip_reserved := false):
	var best: Entity = null
	var best_d = radius
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == entity_type:
			if skip_reserved and is_instance_valid(other.reserved_by) and other.reserved_by != self:
				continue
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

func _find_unowned_home(radius: float) -> Entity:
	var best: Entity = null
	var best_d = radius
	for other in get_parent().get_children():
		if other is Entity and (other as Entity).type == Game.EntityType.HOUSING:
			var h = other as Entity
			if h.residents.is_empty():
				var d = pos.distance_to(h.pos)
				if d < best_d:
					best_d = d
					best = h
	return best

func _share_wood():
	var need = wood_to_build - carried_wood
	for other in get_parent().get_children():
		if need <= 0:
			break
		if other is Folk and other != self and pos.distance_to(other.pos) < share_radius:
			var spare = other.carried_wood - wood_to_build  # they keep enough to build too
			if spare > 0:
				var give = mini(need, spare)
				other.carried_wood -= give
				carried_wood += give
				need -= give

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
		var spot = anchor + Vector2.from_angle(randf() * TAU) \
				* randf_range(home_spacing.x, home_spacing.y)
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
