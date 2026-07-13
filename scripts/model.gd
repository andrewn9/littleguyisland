class_name Model extends Node3D

@export_group("Initial Map")
@export var Heightmap: Texture2D
@export var Valuemap: Texture2D

@export_group("")
@onready var geometry = $Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

@export var entity_gen: EntityGen
@export var map_collision: MapCollision

@export var draw_debug: MeshInstance3D

var mouse_position: Vector2

const brushes: Dictionary[StringName, Texture2D] = {
	"default": preload("res://testing/brush.tres"),
	"flat": preload("res://testing/flat brush.tres"),
	"fuzzy": preload("res://testing/fuzzy_brush.png"),
	"grassy": preload("res://testing/grassy_brush.png"),
	"harsh": preload("res://testing/harsher brush.tres"),
	"mountain": preload("res://testing/mountain_brush.png"),
	"shallow": preload("res://testing/shallow brush.tres"),
	"mon": preload("res://testing/Illustration.png"),
	"smooth": preload("res://testing/Smooth.png"),
	"water": preload("res://testing/water.png"),
	"average": preload("res://testing/Smooth.png"),
}

const ROT_VARIANTS := 12
var _rot_pool: Dictionary = {}  # brush_type -> Array[ImageTexture]

var _add_mat := BlitMaterial.new()

var min_stroke = null
var max_stroke = null

func _ready() -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2i(MapData.WORLD_SIZE, MapData.WORLD_SIZE)
	quad.subdivide_width = MapData.RESOLUTION
	quad.subdivide_depth = MapData.RESOLUTION
	quad.orientation = PlaneMesh.FACE_Y
	geometry.mesh = quad.duplicate()

	var geom_shader = geometry.get_surface_override_material(0) as ShaderMaterial
	geom_shader.set_shader_parameter("valuemap", MapData.val)
	geom_shader.set_shader_parameter("heightmap", MapData.height)
	geom_shader.set_shader_parameter("height_scale", MapData.HEIGHT_SCALE)
	geom_shader.set_shader_parameter("texel_size", 1.0/MapData.RESOLUTION)

	geom_shader.set_shader_parameter("land_key", Color.from_rgba8(91, 162, 31))
	geom_shader.set_shader_parameter("mountain_key", Color.GRAY)
	geom_shader.set_shader_parameter("water_key", Color.WHITE)
	geom_shader.set_shader_parameter("base_key", Color.ANTIQUE_WHITE)

	_add_mat.blend_mode = BlitMaterial.BLEND_MODE_ADD

	_bake_rotations()
	
	for tex in MapData.layers.values():
		var ui = TextureRect.new()
		ui.texture = tex
		%Debug.add_child(ui)
	
	if Heightmap:
		MapData.height.blit_rect(
			Rect2i(0, 0, MapData.RESOLUTION, MapData.RESOLUTION),
			Heightmap
		)
	if Valuemap:
		MapData.val.blit_rect(
			Rect2i(0, 0, MapData.RESOLUTION, MapData.RESOLUTION),
			Valuemap
		)
	
	Game.model = self

var drawing := false

func project_screen_pos(pos: Vector2):
	raycast.position = camera.to_local(camera.project_ray_origin(pos))
	raycast.target_position = Vector3(0, 0, -99999)
	raycast.force_raycast_update()
	if raycast.get_collider():
		var target_pos = Vector2(raycast.get_collision_point().x + MapData.WORLD_SIZE / 2, raycast.get_collision_point().z + MapData.WORLD_SIZE / 2) * MapData.RESOLUTION / MapData.WORLD_SIZE
		return target_pos
	return null

func _bake_rotations() -> void:
	for t in brushes:
		var img: Image = brushes[t].get_image()
		if img == null:
			continue  # e.g. a noise texture not generated yet; falls back to unrotated
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var variants: Array[ImageTexture] = []
		for i in ROT_VARIANTS:
			variants.append(_rotate_tex(img, randf() * TAU))
		_rot_pool[t] = variants

func _rotate_tex(src: Image, angle: float) -> ImageTexture:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	var ca := cos(angle)
	var sa := sin(angle)
	for y in h:
		for x in w:
			var dx := x - cx
			var dy := y - cy
			var su := int(dx * ca - dy * sa + cx)
			var sv := int(dx * sa + dy * ca + cy)
			if su >= 0 and su < w and sv >= 0 and sv < h:
				out.set_pixel(x, y, src.get_pixel(su, sv))
	return ImageTexture.create_from_image(out)

func draw_at(tex_pos: Vector2, to: DrawableTexture2D, color: Color, brush_size: int, brush_type := "default", scale_jitter := 0.35, additive := false):
	var island_mult = 0.85
	brush_size *= island_mult
	
	var tex: Texture2D = brushes[brush_type]
	if _rot_pool.has(brush_type):
		var variants: Array = _rot_pool[brush_type]
		tex = variants[randi() % variants.size()]

	if brush_type == "average":
		var s := maxi(1, roundi(brush_size * (1.0 + randf_range(-scale_jitter, scale_jitter))))

		var img = to.get_image()
		var sum = Vector3.ZERO
		var count = 0

		for x in range(clampi(roundi(tex_pos.x - s * 0.5), 0, MapData.RESOLUTION), clampi(roundi(tex_pos.x + s * 0.5), 0, MapData.RESOLUTION)):
			for y in range(clampi(roundi(tex_pos.y - s * 0.5), 0, MapData.RESOLUTION), clampi(roundi(tex_pos.y + s * 0.5), 0, MapData.RESOLUTION)):
				var val = img.get_pixel(x, y)
				sum += Vector3(val.r, val.g, val.b)
				count += 1
		
		sum /= count

		to.blit_rect(
			Rect2i(roundi(tex_pos.x - s * 0.5), roundi(tex_pos.y - s * 0.5), s, s),
			tex, Color(sum.x, sum.y, sum.z, 0.1)
		)
	else:
		var s := maxi(1, roundi(brush_size * (1.0 + randf_range(-scale_jitter, scale_jitter))))
		to.blit_rect(
			Rect2i(roundi(tex_pos.x - s * 0.5), roundi(tex_pos.y - s * 0.5), s, s),
			tex, color, 0, _add_mat if additive else null
		)

	MapData.update()

	if min_stroke:
		min_stroke = min_stroke.min(Vector2i(roundi(tex_pos.x - brush_size * 0.5), roundi(tex_pos.y - brush_size * 0.5)))
	else:
		min_stroke = Vector2i(roundi(tex_pos.x - brush_size * 0.5), roundi(tex_pos.y - brush_size * 0.5))

	if max_stroke:
		max_stroke = max_stroke.max(Vector2i(roundi(tex_pos.x + brush_size * 0.5), roundi(tex_pos.y + brush_size * 0.5)))
	else:
		max_stroke = Vector2i(roundi(tex_pos.x + brush_size * 0.5), roundi(tex_pos.y + brush_size * 0.5))

func stroke(from: Vector2, to: Vector2):
	for i in range(0, (from - to).length(), 2):
		use_tool(from + (to - from).limit_length(i))
		prev_stroke = from + (to - from).limit_length(i)

var prev_stroke

func use_tool(pos: Vector2):
	if Hud.active.name == "Land":
		draw_at(pos, MapData.val, Color.from_rgba8(91, 162, 31, 40), 25, "smooth")
		draw_at(pos, MapData.height, Color.from_rgba8(1, 2, 2, 255), 28, "flat", 0.35, true)
		draw_at(pos, MapData.height, Color.BLACK, 40, "average")
	elif Hud.active.name == "Mountain":
		draw_at(pos, MapData.height, Color.from_rgba8(9, 9, 9, 255), 22, "harsh", 0.35, true)
		draw_at(pos, MapData.height, Color.from_rgba8(4, 4, 4, 60), 3, "mon", 1)
		draw_at(pos, MapData.val, Color.GRAY, 30)
	elif Hud.active.name == "Water":
		draw_at(pos, MapData.height, Color.from_rgba8(0, 0, 0, 255), 10)
		draw_at(pos, MapData.val, Color.from_rgba8(0, 0, 255, 255), 15, "default")
	elif Hud.active.name == "Dig":
		draw_at(pos, MapData.height, Color.from_rgba8(0, 0, 0, 255), 10)
	elif Hud.active.name == "Brush":
		draw_at(pos, MapData.height, Color.BLACK, 30, "average")

func _input(event):
	if Input.is_key_pressed(KEY_SPACE):
		return  # space = camera pan, don't paint
	if event is InputEventMouseButton:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.pressed:
			prev_stroke = project_screen_pos(event.position)
			if prev_stroke:
				use_tool(prev_stroke)
		if not event.pressed and min_stroke:
			var min_x = clamp(min_stroke.x, 0, MapData.RESOLUTION - 1)
			var max_x = clamp(max_stroke.x, 0, MapData.RESOLUTION - 1)
			var min_y = clamp(min_stroke.y, 0, MapData.RESOLUTION - 1)
			var max_y = clamp(max_stroke.y, 0, MapData.RESOLUTION - 1)

			print("Updating entities and map collision")

			if draw_debug:
				draw_debug.position = Vector3((min_x + max_x) * 0.5, 10.0, (min_y + max_y) * 0.5) * MapData.WORLD_SIZE / MapData.RESOLUTION - Vector3(MapData.WORLD_SIZE / 2, 0, MapData.WORLD_SIZE / 2)
				draw_debug.scale = Vector3(max_x - min_x, 1.0, max_y - min_y) * MapData.WORLD_SIZE / MapData.RESOLUTION

			entity_gen.generate(min_x, min_y, max_x, max_y)
			map_collision.update()

			min_stroke = null
			max_stroke = null
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not prev_stroke:
			prev_stroke = project_screen_pos(event.position)
			if prev_stroke:
				use_tool(prev_stroke)
				return

		if prev_stroke && project_screen_pos(event.position):
			stroke(prev_stroke, project_screen_pos(event.position))

	if Input.is_action_just_pressed("out"):
		MapData.height.get_image().save_png("height.png")
		MapData.val.get_image().save_png("value.png")

