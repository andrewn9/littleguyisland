extends Node

const RESOLUTION := 256
const WORLD_SIZE := 1500.0
const HEIGHT_SCALE := 256

var val : DrawableTexture2D
var height : DrawableTexture2D

var layers : Dictionary = {}

func _ready() -> void:
	val = _make_layer(Color.ANTIQUE_WHITE)
	height = _make_layer(Color.BLACK)
	layers = {val = val, height = height}

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex
