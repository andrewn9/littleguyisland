@tool
extends NinePatchRect

@export var mirrored := false:
	set(value):
		mirrored = value
		_layout()

@export var height_ratio := 0.14:
	set(value):
		height_ratio = value
		_layout()


@export_range(-0.2, 0.2) var tuck_ratio := 0.0:
	set(value):
		tuck_ratio = value
		_layout()


func _ready() -> void:
	get_parent_control().resized.connect(_layout)
	_layout()


func _layout() -> void:
	if texture == null or not is_inside_tree():
		return
	var p := get_parent_control()
	if p == null:
		return
	var wheel_side := minf(p.size.x, p.size.y)

	var edge_to_wheel := p.size.x * 0.5 - wheel_side * 0.5
	var h := wheel_side * height_ratio

	var s := h / float(texture.get_height())

	scale = Vector2(s, s)
	const BLEED := 2.0
	var span := edge_to_wheel + wheel_side * tuck_ratio  # on-screen bar length
	size = Vector2(span / s + BLEED / s, texture.get_height() + BLEED / s)
	position = Vector2(p.size.x - span if mirrored else -BLEED, p.size.y - h)
