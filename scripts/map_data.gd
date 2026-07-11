extends Node

const RESOLUTION := 128
const WORLD_SIZE := 20.0

var val : DrawableTexture2D
var height : DrawableTexture2D

var layers : Dictionary = {}

const temp_values : Texture2D = preload("res://testing/sample_values.png")

func _ready() -> void:
	val = _make_layer(Color.BLUE)
	height = _make_layer(Color.TRANSPARENT)
	layers = {val = val, height = height}
	
	height.blit_rect(
		Rect2i(0, 0, RESOLUTION, RESOLUTION),
		temp_values
	)

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex
