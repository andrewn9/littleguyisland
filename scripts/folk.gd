class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }
enum Goal { ROAM, GATHER, BUILD, GO_HOME, FARM, HARVEST, MINE, BUILD_WELL, BUILD_FARM }

const STATUS_TEXT := {
	FolkState.IDLE: "resting",
	FolkState.WANDER: "folking around",
	FolkState.WALKING: "travelling",
	FolkState.SWIMMING: "swimming",
	FolkState.INTERACTING: "tasking",
	FolkState.DEAD: "decomissioned",
}

var wander_radius := 30.0
var idle_time_range := Vector2(0.20, 0.5)
var water_level := 0.05
var walk_speed := 2.1
var swim_speed := 0.55
var climb_slowdown := 14.0
var meander := 1.4 # width of wander cone
var roam_rest_chance := 0.5
var elevation_attachment := 6.0

var happiness := 0.6
var adventurousness := 0.5
var content_threshold := 0.7 # how happy u gotta be
var adventure_growth := 0.00015
var social_radius := 24.0

var wood_per_tree := 3
var wood_to_build := 4
var home_capacity := 3
var chop_time := 1.5
var build_time := 2.0
var tree_search_radius := 90.0
var share_radius := 24.0

var rock_per_node := 3
var rock_to_build_well := 5
var mine_time := 2.0
var well_time := 3.0
var rock_search_radius := 140.0
var well_water_radius := 12.0
var well_spacing := 30.0
var well_max_elevation := 0.45
var well_reach := 70.0 # dist from home

var wood_to_build_farm_building := 3
var farm_building_time := 2.5
var farm_buildings_per_field := 2
var farm_building_spacing := 5.0

var farm_search_radius := 120.0 # harvest
var farm_reach := 40.0 # start farming x distance from home
var farm_water_radius := 5.0 # radius from water
var farm_max_elevation := 0.16 # only low-lying coastal ground is farmable
var farm_field_radius := 40.0 # grouping for big farm
var farm_spacing := 2.5 # min gap
var plant_time := 2.0
var harvest_time := 1.2
var farm_target_per_person := 1.5 # keep this many crops per folk growing
var hungry_roam_radius := 18.0 # when hungry, stay this close to home
var farm_village_clearance := 14.0

var home_group_radius := 70.0 # how far a homeless folk looks to join a home
var home_spacing := Vector2(6.0, 14.0)
var new_village_dist := Vector2(55.0, 130.0) # how far out a settler looks
var new_village_clearance := 40.0 # dist from other homes
var night_home_range := 30.0
var takeover_radius := 45.0
var neighbour_home_radius := 10.0 # I got x neighbors -> happy

var birth_chance := 0.9 # chance a prosperous home makes a child on a night
var adulthood_age := 3
var child_scale := 0.5
var breed_radius := 30.0

@export var viewport: SubViewport

var state: FolkState = FolkState.IDLE
var goal: Goal = Goal.ROAM
var age := 0
var home: Entity = null
var carried_wood := 0
var carried_rock := 0

var _grown := true
var _seeking_new_village := false
var _birth_home_pos := Vector2.INF
var _base_pivot_scale := Vector3.ONE

var _idle_left := 0.0
var _interact_left := 0.0
var _neighbors := 0
var _community := 0 # neighbouring homes
var _at_home := false
var _social_timer := randf()
var _roam_goal := Vector2.ZERO
var _wander_angle := randf() * TAU # current heading, random-walked for meander

var _target_entity: Entity = null
var _pending_tree: Entity = null
var _pending_crop: Entity = null
var _pending_rock: Entity = null
var _farm_spot := Vector2.INF
var _well_spot := Vector2.INF
var _farm_building_spot := Vector2.INF

var _path: PackedVector2Array = [] # remaining waypoints toward the destination
var _path_i := 0

@onready var _sprite = $Pivot/Sprite


func _ready():
	super()
	_base_pivot_scale = $Pivot.scale
	adventurousness = randf()
	_apply_growth()
	_decide()
	is_static = false
	Game.day_changed.connect(_on_new_day)

func _on_new_day():
	age += 1
	_apply_growth()
	if not _grown and age >= adulthood_age:
		_grown = true
		_become_adult()

func _apply_growth():
	var t := clampf(float(age) / float(adulthood_age), 0.0, 1.0)
	$Pivot.scale = _base_pivot_scale * lerpf(child_scale, 1.0, t)

func make_child(birth_home: Entity):
	home = birth_home
	_grown = false
	age = 0
	_birth_home_pos = birth_home.pos

func _become_adult():
	if is_instance_valid(home):
		home.residents.erase(self)
	home = null
	adventurousness = maxf(adventurousness, randf_range(0.6, 1.0))
	_seeking_new_village = true


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

func _physics_process(_delta: float):
	var dt = Game.scaled_delta
	if dt == 0:
		return
	tick(dt)
	if Hud.focused_folk == self:
		_update_profile()

func _update_profile():
	Hud.name_label.text = name
	Hud.happiness_bar.value = happiness * 100
	Hud.homeless_label.text = "homeless? nah" if is_instance_valid(home) else "homeless? yeah"
	Hud.status_label.text = "status: %s" % STATUS_TEXT[state]
	Hud.age_label.text = "age: %d%s" % [age, " days old" if age != 1 else " day old"]

func _unhandled_input(event):
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var c_min = camera.unproject_position(global_position + Vector3(0, 14, 0))
	var c_max = camera.unproject_position(global_position)
	var h = c_max.y - c_min.y
	c_min.x -= h * 2 / 7
	c_max.x += h * 2 / 7

	var hit: bool = event.position.x > c_min.x and event.position.x < c_max.x \
			and event.position.y > c_min.y and event.position.y < c_max.y
	if hit and Hud.active.name == "Click":
		Hud.show_profile(self)
	elif Hud.focused_folk == self:
		Hud.hide_profile()

	viewport.push_input(event)

func _decide():
	_release_claim() # drop any tree/crop claim from a previous plan
	if _escape_buried():
		return

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
			_go_claim(_pending_tree, _roam)
		Goal.HARVEST:
			_go_claim(_pending_crop, _rest)
		Goal.MINE:
			_go_claim(_pending_rock, _roam)
		Goal.BUILD:
			var spot := _pick_build_spot()
			Game.build_fail_streak = 0 if spot.is_finite() else Game.build_fail_streak + 1
			_go_build_at(spot)
		Goal.FARM:
			_go_build_at(_farm_spot)
		Goal.BUILD_WELL:
			_go_build_at(_well_spot)
		Goal.BUILD_FARM:
			_go_build_at(_farm_building_spot)
		Goal.ROAM:
			_roam()

func _go_build_at(spot: Vector2) -> void:
	_target_entity = null
	if not (spot.is_finite() and _go_to(spot)):
		_rest()

func _escape_buried() -> bool:
	if _height_at(pos) <= MapData.NAV_MOUNTAIN_LEVEL:
		return false
	var land = MapData._nearest_land(Vector2i(pos.round()))
	goal = Goal.ROAM
	_at_home = false
	visible = true
	_target_entity = null
	target_pos = Vector2(land) if land != null else _downhill_step()
	_path = PackedVector2Array([target_pos])
	_path_i = 0
	state = FolkState.WALKING
	return true

func _choose_goal() -> Goal:
	if not _grown:
		if Game.is_night() and is_instance_valid(home):
			return Goal.GO_HOME
		return Goal.ROAM

	if not is_instance_valid(home):
		home = null
		var joinable = _find_joinable_home()
		if joinable:
			home = joinable
			joinable.residents.append(self)
			_seeking_new_village = false

	if Game.is_night():
		if not is_instance_valid(home):
			return Goal.ROAM
		if pos.distance_to(home.pos) > night_home_range:
			var shelter = _find_unowned_home(takeover_radius)
			if shelter and pos.distance_to(shelter.pos) < pos.distance_to(home.pos):
				home.residents.erase(self)
				home = shelter
				shelter.residents.append(self)
		return Goal.GO_HOME

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
		var well_goal := _want_well()
		if well_goal != Goal.ROAM:
			return well_goal

	var farmstead := _want_farm_building()
	if farmstead != Goal.ROAM:
		return farmstead

	return _build_or_gather()

func _want_well() -> Goal:
	var spot := _find_well_spot()
	if not spot.is_finite():
		return Goal.ROAM
	_well_spot = spot
	if carried_rock < rock_to_build_well:
		_share_rock()
	if carried_rock >= rock_to_build_well:
		return Goal.BUILD_WELL
	_pending_rock = _find_nearest(Game.EntityType.ROCK, rock_search_radius, true)
	return Goal.MINE if _pending_rock else Goal.ROAM

func _want_farm_building() -> Goal:
	var spot := _find_farm_building_spot()
	if not spot.is_finite():
		return Goal.ROAM
	_farm_building_spot = spot
	if carried_wood < wood_to_build_farm_building:
		_share_wood(wood_to_build_farm_building)
	if carried_wood >= wood_to_build_farm_building:
		return Goal.BUILD_FARM
	_pending_tree = _find_nearest(Game.EntityType.TREE, tree_search_radius, true)
	return Goal.GATHER if _pending_tree else Goal.ROAM

func _build_or_gather() -> Goal:
	
	if not Game.needs_housing() or Game.no_build_space():
		return Goal.ROAM
	if carried_wood < wood_to_build:
		_share_wood()
	if carried_wood >= wood_to_build:
		return Goal.BUILD
	_pending_tree = _find_nearest(Game.EntityType.TREE, tree_search_radius, true)
	return Goal.GATHER if _pending_tree else Goal.ROAM

func _go_claim(e: Entity, fallback: Callable) -> void:
	if is_instance_valid(e) and e.reserved_by == null and _go_to(e.pos):
		_target_entity = e
		e.reserved_by = self
	else:
		fallback.call()

func _arrive():
	target_pos = pos
	match goal:
		Goal.GO_HOME:
			if home and pos.distance_to(home.pos) < 2.0:
				_claim_home()
				pos = home.pos
			else:
				_rest()
		Goal.GATHER:
			if is_instance_valid(_target_entity) \
					and _target_entity.type == Game.EntityType.TREE:
				_interact(chop_time)
			else:
				_release_claim() # tree already cut / gone
				_rest()
		Goal.HARVEST:
			if is_instance_valid(_target_entity) \
					and get_parent().farm_is_ripe(_target_entity):
				_interact(harvest_time)
			else:
				_release_claim()
				_rest()
		Goal.MINE:
			if is_instance_valid(_target_entity) \
					and _target_entity.type == Game.EntityType.ROCK:
				_interact(mine_time)
			else:
				_release_claim()
				_rest()
		Goal.BUILD:
			_interact(build_time)
		Goal.FARM:
			_interact(plant_time)
		Goal.BUILD_WELL:
			_interact(well_time)
		Goal.BUILD_FARM:
			_interact(farm_building_time)
		Goal.ROAM:
			if randf() < roam_rest_chance:
				_rest()
			else:
				_roam()

func _interact(duration: float) -> void:
	state = FolkState.INTERACTING
	_interact_left = duration

func _finish_interact():
	match goal:
		Goal.GATHER:
			if is_instance_valid(_target_entity):
				carried_wood += wood_per_tree
				_target_entity.queue_free() # claim dies with the tree
			_target_entity = null
		Goal.MINE:
			if is_instance_valid(_target_entity):
				carried_rock += rock_per_node
				_target_entity.queue_free() # claim dies with the rock
			_target_entity = null
		Goal.BUILD:
			_make_house()
		Goal.FARM:
			get_parent().spawn_farm(_farm_spot if _farm_spot.is_finite() else pos)
		Goal.BUILD_WELL:
			if carried_rock >= rock_to_build_well \
					and get_parent().spawn_well(_well_spot if _well_spot.is_finite() else pos):
				carried_rock -= rock_to_build_well
		Goal.BUILD_FARM:
			if carried_wood >= wood_to_build_farm_building \
					and get_parent().spawn_farm_building(
							_farm_building_spot if _farm_building_spot.is_finite() else pos):
				carried_wood -= wood_to_build_farm_building
		Goal.HARVEST:
			if is_instance_valid(_target_entity) \
					and get_parent().farm_is_ripe(_target_entity):
				Game.food += Game.crop_yield
				_target_entity.queue_free() # reaped; claim dies with it
			_target_entity = null
	_rest()

func _release_claim():
	if is_instance_valid(_target_entity) and _target_entity.reserved_by == self:
		_target_entity.reserved_by = null


func _go_to(dest: Vector2) -> bool:
	_path = PackedVector2Array([dest]) if MapData.clear_path(pos, dest) \
			else MapData.find_path(pos, dest)
	if _path.is_empty():
		return false
	_path_i = 0
	target_pos = _path[0]
	state = FolkState.WALKING
	return true

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
		if not _walkable_land(candidate):
			continue
		var score = randf() * 0.5 + dir.dot(goal_dir) * 0.4
		score -= absf(_height_at(candidate) - here_h) * elevation_attachment \
				* (1.0 - scaredness * 0.9)
		if score > best_score:
			best_score = score
			best = candidate
			best_angle = angle

	if best.is_finite():
		_wander_angle = best_angle # carry the heading forward for momentum
		return best

	_roam_goal = Vector2.INF
	for _try in 4:
		_wander_angle += randf_range(1.5, 3.0)
		var candidate = pos + Vector2.from_angle(_wander_angle) * randf_range(3.0, stride)
		if _on_map(candidate):
			return candidate
	return Vector2.INF

func _new_roam_goal() -> Vector2:
	var on_land := func(g: Vector2): return _walkable_land(g)

	if not _grown and _birth_home_pos.is_finite(): # children stay in da crib
		var g := _find_spot(_birth_home_pos, 0.0, hungry_roam_radius, 12, on_land)
		return g if g.is_finite() else _birth_home_pos

	if Game.hungry() and is_instance_valid(home):
		var g := _find_spot(home.pos, 0.0, hungry_roam_radius, 12, on_land)
		return g if g.is_finite() else home.pos

	var nerve := adventurousness * lerpf(0.4, 1.0, happiness)
	var center := Vector2.ONE * MapData.RESOLUTION * 0.5
	var map_r := MapData.RESOLUTION * 0.5 - 4.0
	for _try in 24:
		var g: Vector2
		if randf() < nerve: # strike out anywhere on the island
			g = center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * map_r
		else: # stay around the folk nearby
			var anchor := _flock_center()
			if not anchor.is_finite():
				anchor = pos
			var reach := wander_radius * lerpf(2.0, 6.0, adventurousness)
			g = anchor + Vector2.from_angle(randf() * TAU) * randf_range(0.0, reach)
		if on_land.call(g):
			return g
	return pos

func _downhill_step() -> Vector2:
	var best := pos
	var best_h = _height_at(pos)
	for i in 8:
		var p = pos + Vector2.from_angle(i * PI / 4.0) * 3.0
		if _on_map(p) and _height_at(p) < best_h:
			best_h = _height_at(p)
			best = p
	return best if best != pos else pos + Vector2.from_angle(randf() * TAU) * 3.0

func _climb_factor():
	var dir = target_pos - pos
	if dir.length_squared() < 0.01:
		return 1.0
	var ahead = pos + dir.limit_length(3.0)
	var grade = absf(_height_at(ahead) - _height_at(pos)) / 3.0
	var s = grade * climb_slowdown * 4.5
	return clampf(1.0 / (1.0 + s * s), 0.12, 1.0)


func _make_house():
	if carried_wood < wood_to_build or not Game.needs_housing():
		return
	var built: Entity = get_parent().spawn_home(pos, home_capacity)
	if built == null:
		return
	carried_wood -= wood_to_build

	if not is_instance_valid(home):
		_move_into(built)
	elif pos.distance_to(home.pos) > new_village_clearance:
		home.residents.erase(self)
		_move_into(built)

func _move_into(h: Entity) -> void:
	home = h
	h.residents.append(self)
	_seeking_new_village = false

func _claim_home():
	_at_home = true
	visible = false
	state = FolkState.IDLE
	_community = _count_nearby_homes(neighbour_home_radius)
	_idle_left = randf_range(8.0, 16.0) # rest til morn
	_maybe_birth()

func _maybe_birth():
	if not (Game.is_night() and is_instance_valid(home) and _grown):
		return
	if home.last_birth_day == Game.day or not Game.prosperous():
		return
	if _count_adults_near(breed_radius) < 2:
		return
	if randf() < birth_chance:
		home.last_birth_day = Game.day
		get_parent().spawn_little_guy(int(home.pos.x), int(home.pos.y), home)

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
		drift -= 0.06 # hungry -> unhappy

	happiness = clampf(happiness + drift * dt, 0.0, 1.0)

	if happiness > content_threshold:
		adventurousness = minf(1.0, adventurousness + adventure_growth * dt)

func _share_wood(target := wood_to_build) -> void:
	_share(&"carried_wood", target)

func _share_rock(target := rock_to_build_well) -> void:
	_share(&"carried_rock", target)

func _share(prop: StringName, target: int) -> void:
	var need: int = target - get(prop)
	for other in _group("folk"):
		if need <= 0:
			break
		if other == self or pos.distance_to(other.pos) >= share_radius:
			continue
		var spare: int = other.get(prop) - target
		if spare > 0:
			var give := mini(need, spare)
			other.set(prop, other.get(prop) - give)
			set(prop, get(prop) + give)
			need -= give

func _pick_build_spot() -> Vector2:
	if not (adventurousness > 0.5 and randf() < adventurousness):
		var nearest := _find_nearest(Game.EntityType.HOUSING, 120.0)
		var anchor: Vector2 = nearest.pos if nearest else pos
		var spot := _find_spot(anchor, home_spacing.x, home_spacing.y, 16,
				func(p: Vector2): return _house_spot_ok(p) \
						and _nearest_dist("homes", p) > 5.0)
		if spot.is_finite():
			return spot
	return _pick_frontier_spot()

func _pick_frontier_spot() -> Vector2:
	return _find_spot(pos, new_village_dist.x, new_village_dist.y, 40,
			func(p: Vector2): return _house_spot_ok(p) \
					and _nearest_dist("homes", p) > new_village_clearance)

func _house_spot_ok(p: Vector2) -> bool:
	return _buildable(p) and _nearest_dist("farms", p) > farm_village_clearance

func _buildable(p: Vector2) -> bool:
	return _walkable_land(p) and _height_at(p) >= water_level + 0.02

func _find_farm_spot() -> Vector2:
	var ok := func(p: Vector2): return _on_map(p) and _farmable(p) \
			and not _farm_too_close(p, farm_spacing) \
			and _nearest_dist("homes", p) > farm_village_clearance

	var field := _find_nearest(Game.EntityType.FARM, farm_field_radius)
	if is_instance_valid(field):
		return _find_spot(field.pos, farm_spacing, farm_spacing * 2.0, 24, ok)

	var anchor: Vector2 = home.pos if is_instance_valid(home) else pos
	return _find_spot(anchor, 4.0, farm_reach, 24, ok)

func _farmable(p: Vector2) -> bool:
	var h = _height_at(p)
	if h < water_level + 0.01 or not _fertile(p):
		return false
	if _nearest_dist("wells", p) < well_water_radius:
		return h <= well_max_elevation
	return h <= farm_max_elevation and _near_natural_water(p)

func _fertile(p: Vector2) -> bool:
	var c = MapData.val_img.get_pixelv(
		p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1)))
	var dm = Vector3(c.r - MapData.MOUNTAIN_KEY.r, c.g - MapData.MOUNTAIN_KEY.g,
			c.b - MapData.MOUNTAIN_KEY.b).length_squared()
	return dm > 0.0125

func _near_natural_water(p: Vector2) -> bool:
	var r := int(farm_water_radius)
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if dx * dx + dy * dy > r * r:
				continue
			if _height_at(p + Vector2(dx, dy)) < water_level:
				return true
	return false

func _find_well_spot() -> Vector2:
	var anchor: Vector2 = home.pos if is_instance_valid(home) else pos
	return _find_spot(anchor, 8.0, well_reach, 28, func(p: Vector2):
		var h = _height_at(p)
		return _on_map(p) and h > farm_max_elevation and h <= well_max_elevation \
				and _fertile(p) and not _near_natural_water(p) \
				and _nearest_dist("wells", p) > well_spacing)

func _find_farm_building_spot() -> Vector2:
	var field := _find_nearest(Game.EntityType.FARM, farm_field_radius)
	if not is_instance_valid(field):
		return Vector2.INF
	if _count_in_radius("farm_buildings", field.pos, farm_field_radius) \
			>= farm_buildings_per_field:
		return Vector2.INF
	return _find_spot(field.pos, farm_spacing * 2.0, farm_field_radius * 0.5, 20,
			func(p: Vector2): return _buildable(p) \
					and not _farm_too_close(p, farm_spacing) \
					and _nearest_dist("farm_buildings", p) > farm_building_spacing \
					and _nearest_dist("homes", p) > farm_village_clearance)

func _farm_too_close(p: Vector2, r: float) -> bool:
	return _nearest_dist("farms", p) < r


func _group(name: String) -> Array:
	return get_tree().get_nodes_in_group(name)

func _group_of(t: Game.EntityType) -> String:
	match t:
		Game.EntityType.TREE: return "trees"
		Game.EntityType.HOUSING: return "homes"
		Game.EntityType.FARM: return "farms"
		Game.EntityType.ROCK: return "rocks"
		Game.EntityType.WELL: return "wells"
		Game.EntityType.FARM_BUILDING: return "farm_buildings"
	return ""

func _nearest_in(group: String, radius: float, ok := Callable()) -> Entity:
	var best: Entity = null
	var best_d := radius
	for e in _group(group):
		if ok.is_valid() and not ok.call(e):
			continue
		var d: float = pos.distance_to(e.pos)
		if d < best_d:
			best_d = d
			best = e
	return best

func _count_near(group: String, radius: float, ok := Callable()) -> int:
	var c := 0
	for e in _group(group):
		if ok.is_valid() and not ok.call(e):
			continue
		if pos.distance_to(e.pos) < radius:
			c += 1
	return c

func _find_spot(anchor: Vector2, min_r: float, max_r: float, tries: int,
		ok: Callable) -> Vector2:
	for _try in tries:
		var p := anchor + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)
		if ok.call(p):
			return p
	return Vector2.INF

func _find_nearest(entity_type: Game.EntityType, radius: float, skip_reserved := false) -> Entity:
	return _nearest_in(_group_of(entity_type), radius,
			func(e): return not (skip_reserved and is_instance_valid(e.reserved_by) \
					and e.reserved_by != self))

func _find_ripe_crop(radius: float) -> Entity:
	return _nearest_in("farms", radius,
			func(f): return get_parent().farm_is_ripe(f) \
					and not (is_instance_valid(f.reserved_by) and f.reserved_by != self))

func _find_joinable_home() -> Entity:
	return _nearest_in("homes", home_group_radius, func(h):
		if h.residents.size() >= h.capacity:
			return false
		return not (_seeking_new_village and _birth_home_pos.is_finite() \
				and h.pos.distance_to(_birth_home_pos) < new_village_clearance))

func _find_unowned_home(radius: float) -> Entity:
	return _nearest_in("homes", radius, func(h): return h.residents.is_empty())

func _count_adults_near(r: float) -> int:
	return _count_near("folk", r, func(f): return f.state != FolkState.DEAD and f._grown)

func _count_nearby_homes(radius: float) -> int:
	return _count_near("homes", radius, func(h): return h != home)

func _nearest_dist(group: String, p: Vector2) -> float:
	return Game.nearest_dist(group, p)

func _count_in_radius(group: String, center: Vector2, radius: float) -> int:
	return Game.count_in_radius(group, center, radius)

func _flock_center() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for f in _group("folk"):
		if f != self and f.state != FolkState.DEAD \
				and pos.distance_to(f.pos) < social_radius:
			sum += f.pos
			count += 1
	_neighbors = count
	return sum / count if count > 0 else Vector2.INF


func _on_map(p: Vector2) -> bool:
	var half = MapData.RESOLUTION * 0.5
	return p.distance_to(Vector2(half, half)) < half - 2.0

func _walkable_land(p: Vector2) -> bool:
	var h = _height_at(p)
	return _on_map(p) and h >= water_level and h <= MapData.NAV_MOUNTAIN_LEVEL

func _height_at(p: Vector2):
	return MapData.height_img.get_pixelv(
		p.round().clamp(Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r
