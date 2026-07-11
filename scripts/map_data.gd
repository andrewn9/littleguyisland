extends Node

const RESOLUTION := 128
const WORLD_SIZE := 250.0
const HEIGHT_SCALE := 15

var val : DrawableTexture2D
var height : DrawableTexture2D

var layers : Dictionary = {}

const temp_value : Texture2D = preload("res://testing/sample_value.png")
const temp_height : Texture2D = preload("res://testing/sample_height.png")

func _ready() -> void:
	val = _make_layer(Color.WHITE)
	height = _make_layer(Color.TRANSPARENT)
	layers = {val = val, height = height}
	
	height.blit_rect(
		Rect2i(0, 0, RESOLUTION, RESOLUTION),
		temp_height
	)
	val.blit_rect(
		Rect2i(0, 0, RESOLUTION, RESOLUTION),
		temp_value
	)

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex
