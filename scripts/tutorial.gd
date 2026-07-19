extends Node

var _active := false
var _ambient_on := false
var _world := 0

func _ready() -> void:
	pass

func begin_world(fresh := false) -> void:
	_world += 1
	_active = false
	_ambient_on = false
	Hud.monkey_clear()
	if Game.tutorial:
		start()
	elif fresh:
		var w := _world
		await _pause(1.2)
		if w != _world or not is_instance_valid(Game.model):
			return
		_spawn_starter_folk(5)
		Hud.monkey_say("here's five little guys to get you started. hit PLAY when you're ready!", 6.0)
	_start_ambient()

func start() -> void:
	if _active:
		return
	_active = true
	_run()

func _finish() -> void:
	_active = false
	Game.tutorial = false
	Hud.monkey_clear()

func _run() -> void:
	await _pause(0.8)
	if not await _say("welcome !! I'm your new personal assistant, suzanne. I'll be giving you helpful tips and tricks! "):
		return

	var cam0 := _cam_xform()
	if not await _say("firstly, try and move."):
		return
	await _pause(0.5)
	if not await _say("drag with the right mouse button to rotate, and scroll to zoom. you can pan with space / middle click"):
		return
	await _pause(2.5)
	if not await _until(func(): return _cam_moved(cam0)):
		return
	if not await _say("you got it!"):
		return

	Hud.monkey_hold("see the wheel at the bottom? that's your toolkit. click the LAND tool to sculpt grass.")
	if not await _until(func(): return Hud.active.name == "Land"):
		return
	if not await _say("you've also got MOUNTAIN, WATER, DIG and a SMOOTHING brush. the size slider next to them sets how wide you paint."):
		return

	var e0 := Game.edit_count
	Hud.monkey_hold("now click and drag on the island to create a nice grass area.")
	if not await _until(func(): return Game.edit_count - e0 >= 40):
		return
	Hud.monkey_hold("folk will prefer to live on flat grass, so make sure to give them a nice place to settle.")
	if not await _say("nice!"):
		return

	if not await _say("let me get you started with some little guys."):
		return
	_spawn_starter_folk(5)

	Hud.monkey_hold("they're frozen in time. hit the PLAY button, bottom-center, to start the sim.")
	if not await _until(func(): return not Game.paused):
		return
	if not await _say("look at them go!"):
		return

	Hud.monkey_hold("folk can chop trees for wood. the bar at bottom-right tracks wood, food, stone and animals.")
	if not await _say("wood is used to build homes. make sure there are trees available if you want to grow your population!"):
		return
	
	var s0: float = Hud.time_slider.value
	Hud.monkey_hold("want it quicker? drag the SPEED slider to fast-forward and watch things grow.")
	if not await _until(func(): return absf(Hud.time_slider.value - s0) > 0.01):
		return
	if not await _say("vroom vroom."):
		return

	if not await _say("top-left is the Island Overview with stats about your island. additional flags like !hungry or +growth will tell you what the population needs."):
		return

	Hud.monkey_hold("individual information can be found by clicking folk with the CLICK tool")
	if not await _say("if your folk ever gets stuck, you can drag them to a new location!"):
		return

	if not await _say("that's all I have for now. shape your island and meet your populations' needs. have fun!"):
		return
	
	_finish()

func _milestones() -> Array:
	return [
		{"key": "night", "cond": func(): return Game.day >= 1,
		 "line": "a full day has passed. folk head home to sleep at night, anyone without a house will begin to feel sad."},

		{"key": "homeless", "cond": func(): return Game.homeless > 0 and Game.population > 0,
		 "line": "some folk have nowhere to sleep. flatten out more grass and keep wood coming in, and they'll build to fill the gap."},

		{"key": "hungry", "cond": func(): return Game.population > 0 and Game.food < Game.population * 1.0,
		 "line": "food is running low! build more grassy areas near water. hungry folk get unhappy fast."},

		{"key": "starving", "cond": func(): return Game.starving > 0,
		 "line": "someone's gone hungry. folk carry their own food and share with whoever is close by, so a village far from the farms can starve while another eats fine. they hold out a few days, then they start dying."},

		{"key": "no_wood", "cond": func(): return Game.build_fail_streak > 6 and Game.total_wood < 4,
		 "line": "the folk are trying to build, but there's not enough wood. make sure there are trees available for them to chop."},

		{"key": "unhappy", "cond": func(): return Game.population >= 4 and Game.avg_happiness < 0.35,
		 "line": "morale is sinking. check the overview flags, usually it's food or housing. a happy island is a growing island."},

		{"key": "animals", "cond": func(): return Game.animals >= 1 and Game.population > 0 and Game.hungry(),
		 "line": "your folk are hungry, and there are animals about. they'll hunt when the crops fall short, though animals may run away"},

		{"key": "extinction", "cond": func(): return Game.population <= 0,
		 "line": "all your folk have perished. if there's open land, a new batch of settlers will arrive in a few days to start over."}
	]

const TIPS := [
	"tip: you can drag a folk with the CLICK tool if they ever get themselves stuck.",
	"tip: the layers menu under the overview fades trees and buildings, handy for seeing what's underneath.",
	"tip: flat grass is prime real estate. steep slopes and sand won't get built on.",
	"tip: the SMOOTHING brush is great for cleaning up jagged terrain.",
	"tip: your world autosaves as you play, and the X up top drops you back to the desktop with everything kept.",
	"tip: click a folk to follow them around, or see the world through their eyes. it's a nice way to spend a minute.",
	"tip: the size slider next to the tools changes how wide you paint. small for detail, big for whole coastlines.",
	"tip: water next to grass is what makes a spot farmable. wells can also satisfy the need for water.",
	"tip: the DIG tool lowers land. dig deep enough near the sea and you'll flood it.",
	"tip: overview flags are your early warning. !hungry and !homeless both mean it's time to reshape something.",
	"tip: settings has graphics, outlines, CRT and volume, if you want to change the vibe.",
	"tip: an island doesn't have to be one blob. multiple islands work fine, folk like to spread out.",
	"tip: animals graze on grassland, more grass attracts more animals. keep some grass and they'll keep coming.",
	"tip: hungry folk hunt. animals run away when folk get close.",
	"tip: even if every folk dies out, new settlers will land in a few days.",
	"boy"
]

const AMBIENT_FIRST := 45.0
const AMBIENT_MIN := 70.0
const AMBIENT_MAX := 150.0
const MIN_GAP := 25.0

func _start_ambient() -> void:
	if _ambient_on:
		return
	_ambient_on = true
	_ambient_loop()

func _ambient_loop() -> void:
	var w := _world
	await _pause(AMBIENT_FIRST)
	var pool: Array = []
	var since_talk := AMBIENT_FIRST
	var next_tip := randf_range(AMBIENT_MIN, AMBIENT_MAX)
	const POLL := 2.0

	while w == _world and is_instance_valid(Game.model):
		await _pause(POLL)
		if _active or Game.paused or Hud.bubble.visible:
			continue
		since_talk += POLL
		if since_talk < MIN_GAP:
			continue

		var line := ""
		for m in _milestones():
			if Game.tips_fired.has(m["key"]):
				continue
			if (m["cond"] as Callable).call():
				Game.tips_fired[m["key"]] = true
				line = m["line"]
				break

		if line == "":
			if since_talk < next_tip:
				continue
			if pool.is_empty():
				pool = TIPS.duplicate()
				pool.shuffle()
			line = pool.pop_back()
			next_tip = randf_range(AMBIENT_MIN, AMBIENT_MAX)

		Hud.monkey_say(line, _read(line))
		since_talk = 0.0
	if w == _world:
		_ambient_on = false

func _alive(w := -1) -> bool:
	if w != -1 and w != _world:
		return false
	var ok := _active and is_instance_valid(Game.model)
	if not ok:
		_active = false
	return ok

func _say(text: String) -> bool:
	var w := _world
	if not _alive(w):
		return false
	Hud.monkey_hold(text)
	await _pause(_read(text))
	return _alive(w)

func _until(cond: Callable, timeout := 45.0) -> bool:
	var w := _world
	var waited := 0.0
	while _alive(w) and not cond.call():
		await get_tree().create_timer(0.15).timeout
		waited += 0.15
		if waited >= timeout:
			break
	return _alive(w)

func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _read(text: String) -> float:
	return clampf(2.5 + text.split(" ").size() * 0.05, 3.0, 14.0)

func _spawn_starter_folk(count: int) -> void:
	if not is_instance_valid(Game.model):
		return
	var gen = Game.model.entity_gen
	var c := MapData.RESOLUTION / 2
	for i in count:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 12.0)
		var guy = gen.spawn_little_guy(int(c + off.x), int(c + off.y))
		guy.age = 3

func _cam_xform() -> Transform3D:
	var cam := get_viewport().get_camera_3d()
	return cam.global_transform if cam else Transform3D.IDENTITY

func _cam_moved(t0: Transform3D) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var t := cam.global_transform
	return t.origin.distance_to(t0.origin) > 3.0 or (t.basis.x - t0.basis.x).length() > 0.05
