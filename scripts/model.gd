extends Node3D

@export var threshold := 0.5

@onready var geometry = $Geometry

@onready var raycast: RayCast3D = %RayCast3D
@onready var camera: Camera3D = %Camera

@export var entity_gen: EntityGen

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

var first_stroke = null
var last_stroke = null

func _ready() -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2i(MapData.WORLD_SIZE, MapData.WORLD_SIZE)
	quad.subdivide_width = 256
	quad.subdivide_depth = 256
	quad.orientation = PlaneMesh.FACE_Y
	geometry.mesh = quad.duplicate()

	var geom_shader = geometry.get_surface_override_material(0) as ShaderMaterial
	geom_shader.set_shader_parameter("valuemap", MapData.val)
	geom_shader.set_shader_parameter("heightmap", MapData.height)
	geom_shader.set_shader_parameter("height_scale", MapData.HEIGHT_SCALE)
	geom_shader.set_shader_parameter("texel_size", 1.0/MapData.RESOLUTION)

	_bake_rotations()

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

func draw_at(tex_pos: Vector2, to: DrawableTexture2D, color: Color, brush_size: int, brush_type := "default", scale_jitter := 0.35):
	var tex: Texture2D = brushes[brush_type]
	if _rot_pool.has(brush_type):
		var variants: Array = _rot_pool[brush_type]
		tex = variants[randi() % variants.size()]

	if brush_type == "average":
		var s := maxi(1, roundi(brush_size * (1.0 + randf_range(-scale_jitter, scale_jitter))))

		var img = to.get_image()
		var sum = Vector3.ZERO
		var count = 0

		for x in range(roundi(tex_pos.x - s * 0.5), roundi(tex_pos.x + s * 0.5)):
			for y in range(roundi(tex_pos.y - s * 0.5), roundi(tex_pos.y + s * 0.5)):
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
			tex, color
		)

	if not first_stroke:
		first_stroke = Vector4i(roundi(tex_pos.x - brush_size * 0.5), roundi(tex_pos.y - brush_size * 0.5), roundi(tex_pos.x + brush_size * 0.5), roundi(tex_pos.y + brush_size * 0.5))
	last_stroke = Vector4i(roundi(tex_pos.x - brush_size * 0.5), roundi(tex_pos.y - brush_size * 0.5), roundi(tex_pos.x + brush_size * 0.5), roundi(tex_pos.y + brush_size * 0.5))

func stroke(from: Vector2, to: Vector2):
	for i in range(0, (from - to).length(), 2):
		use_tool(from + (to - from).limit_length(i))
		prev_stroke = from + (to - from).limit_length(i)

var prev_stroke

func use_tool(pos: Vector2):
	if Hud.active == "Land":
		draw_at(pos, MapData.val, Color.from_rgba8(91, 162, 31, 255), 25, "smooth")
		draw_at(pos, MapData.height, Color.from_rgba8(30, 30, 30, 255), 28, "flat")
	elif Hud.active == "Mountain":
		draw_at(pos, MapData.height, Color.GRAY, 20, "mon")
		draw_at(pos, MapData.val, Color.GRAY, 20)
	elif Hud.active == "Water":
		draw_at(pos, MapData.height, Color.BLACK, 7)
		draw_at(pos, MapData.val, Color.WHITE, 7, "water")
	elif Hud.active == "Dig":
		draw_at(pos, MapData.height, Color.from_rgba8(0, 0, 0, 255), 10)
	elif Hud.active == "Brush":
		draw_at(pos, MapData.height, Color.BLACK, 7, "average")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.pressed:
			prev_stroke = project_screen_pos(event.position)
			if prev_stroke:
				use_tool(prev_stroke)
		if not event.pressed and first_stroke:
			var min_x = clamp(min(first_stroke.x, first_stroke.z, last_stroke.x, last_stroke.z), 0, MapData.RESOLUTION - 1)
			var max_x = clamp(max(first_stroke.x, first_stroke.z, last_stroke.x, last_stroke.z), 0, MapData.RESOLUTION - 1)
			var min_y = clamp(min(first_stroke.y, first_stroke.w, last_stroke.y, last_stroke.w), 0, MapData.RESOLUTION - 1)
			var max_y = clamp(max(first_stroke.y, first_stroke.w, last_stroke.y, last_stroke.w), 0, MapData.RESOLUTION - 1)
			entity_gen.generate(min_x, min_y, max_x, max_y)
			first_stroke = null
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

