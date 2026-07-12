extends Node

const RESOLUTION := 256
const WORLD_SIZE := 1500.0
const HEIGHT_SCALE := 165

var val : DrawableTexture2D
var height : DrawableTexture2D

var layers : Dictionary = {}

const temp_value : Texture2D = preload("res://testing/sample_value.png")
const temp_height : Texture2D = preload("res://testing/sample_height.png")

func _ready() -> void:
	val = _make_layer(Color.ANTIQUE_WHITE)
	height = _make_layer(Color.BLACK)
	layers = {val = val, height = height}
	

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex
