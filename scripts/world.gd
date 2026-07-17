class_name World extends Node3D

@onready var ocean_water = preload("res://materials/ocean_water.tres")

var _low_gfx := false
var low_gfx : bool :
	get:
		return _low_gfx
	set(value):
		_low_gfx = value

		if value:
			(%Water as MeshInstance3D).material_override = ocean_water
			(%Sun as DirectionalLight3D).shadow_enabled = true
		else:
			(%Water as MeshInstance3D).material_override = null
			(%Sun as DirectionalLight3D).shadow_enabled = false

# func _ready():
	# low_gfx = false