extends Node

const RESOLUTION := 256
const WORLD_SIZE := 1500.0
const HEIGHT_SCALE := 256

var val : DrawableTexture2D
var height : DrawableTexture2D

var height_img : Image
var val_img : Image

var GRASS_KEY: Color = Color(0.36, 0.64, 0.12)
var MOUNTAIN_KEY: Color = Color.GRAY

var layers : Dictionary = {}

func _ready() -> void:
	val = _make_layer(Color.ANTIQUE_WHITE)
	height = _make_layer(Color.BLACK)
	layers = {val = val, height = height}
	update()

func _make_layer(fill: Color) -> DrawableTexture2D:
	var tex := DrawableTexture2D.new()
	tex.setup(RESOLUTION, RESOLUTION,
		DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, fill)
	return tex

func _process(delta):
	update()

func update():
	height_img = height.get_image()
	val_img = val.get_image()
