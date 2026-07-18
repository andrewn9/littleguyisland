extends Node

const DIR := "user://saves"
const VERSION := 1
const RES := 256

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.sav" % [DIR, slot]

func _meta_path(slot: int) -> String:
	return "%s/slot_%d.meta" % [DIR, slot]

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func slot_meta(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_meta_path(slot)) != OK:
		return {}
	return {
		name = cfg.get_value("meta", "name", ""),
		day = cfg.get_value("meta", "day", 0),
		population = cfg.get_value("meta", "population", 0),
		saved_unix = cfg.get_value("meta", "saved_unix", 0),
	}

func delete_slot(slot: int) -> void:
	DirAccess.remove_absolute(_slot_path(slot))
	DirAccess.remove_absolute(_meta_path(slot))

func save_slot(slot: int, gen) -> bool:
	if slot < 0 or not is_instance_valid(gen) or MapData.height_img == null:
		return false

	var data := {
		version = VERSION,
		saved_unix = int(Time.get_unix_time_from_system()),
		game = {
			world_name = Game.world_name,
			tutorial = Game.tutorial,
			tips_fired = Game.tips_fired,
			day = Game.day,
			day_fraction = Game.day_fraction,
			food = Game.food,
			animals = Game.animals,
			time_scale = Game.time_scale,
		},
		terrain = {
			height = MapData.height_img.save_png_to_buffer(),
			value = MapData.val_img.save_png_to_buffer(),
		},
		world = gen.capture_world(),
	}

	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open slot %d" % slot)
		return false
	f.store_var(data)
	f.close()

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "name", Game.world_name)
	cfg.set_value("meta", "day", Game.day)
	cfg.set_value("meta", "population", Game.population)
	cfg.set_value("meta", "saved_unix", data.saved_unix)
	cfg.save(_meta_path(slot))
	return true

func apply_slot(slot: int, gen) -> bool:
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var data = f.get_var()
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("save: slot %d is corrupt" % slot)
		return false

	_apply_terrain(data.get("terrain", {}))

	var g: Dictionary = data.get("game", {})
	Game.world_name = g.get("world_name", "")
	Game.tutorial = g.get("tutorial", false)
	Game.tips_fired = g.get("tips_fired", {})
	Game.day = g.get("day", 0)
	Game.day_fraction = g.get("day_fraction", 0.375)
	Game.food = g.get("food", 0.0)
	Game.animals = g.get("animals", 0)
	Game.time_scale = g.get("time_scale", 1.0)
	get_tree().call_group("clock", "apply_time")

	gen.restore_world(data.get("world", {}))
	return true


func _apply_terrain(t: Dictionary) -> void:
	if not t.has("height"):
		return
	var hi := _load_img(t.height)
	var vi := _load_img(t.value)
	if hi == null or vi == null:
		return
		
	MapData.height_img = hi
	MapData.val_img = vi
	var rect := Rect2i(0, 0, RES, RES)
	MapData.height.blit_rect(rect, ImageTexture.create_from_image(hi))
	MapData.val.blit_rect(rect, ImageTexture.create_from_image(vi))
	MapData.mark_dirty()


func _load_img(buf) -> Image:
	if typeof(buf) != TYPE_PACKED_BYTE_ARRAY:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(buf) != OK:
		return null
	return img
