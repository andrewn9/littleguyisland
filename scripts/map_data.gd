extends Node

const RESOLUTION := 128
const WORLD_SIZE := 20.0

var val : DrawableTexture2D
var height : DrawableTexture2D

var layers : Dictionary = {}

func _ready() -> void:
	val = _make_layer(Color.BLUE)
	height = _make_layer(Color.TRANSPARENT)
	layers = {val = val, height = height}
	
	var base_tex := NoiseTexture2D.new()
	base_tex.width = RESOLUTION
	base_tex.height = RESOLUTION
	base_tex.noise = FastNoiseLite.new()
	if base_tex.get_image() == null:
		await base_tex.changed
	height.blit_rect(
		Rect2i(0, 0, RESOLUTION, RESOLUTION),
		base_tex
	)

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex
