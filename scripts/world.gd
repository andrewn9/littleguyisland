class_name World extends Node3D

@onready var ocean_water = preload("res://materials/ocean_water.tres")

static var _instance: World = null

static var _low_gfx := false
static var low_gfx: bool:
	get:
		return _low_gfx
	set(value):
		_low_gfx = value

		if value:
			ProjectSettings.set_setting("rendering/shading/overrides/force_vertex_shading", true)
			ProjectSettings.set_setting("rendering/shading/overrides/force_lambert_over_burley", true)
		else:
			ProjectSettings.set_setting("rendering/shading/overrides/force_vertex_shading", false)
			ProjectSettings.set_setting("rendering/shading/overrides/force_lambert_over_burley", false)

		if _instance:
			_instance._update_gfx(value)

func _update_gfx(value: bool):
	if not get_viewport():
		await RenderingServer.frame_post_draw

	var viewport = get_viewport().get_viewport_rid()

	if value:
		(%Water as MeshInstance3D).material_override = null
		(%Sun as DirectionalLight3D).shadow_enabled = false
		RenderingServer.viewport_set_msaa_2d(viewport, RenderingServer.VIEWPORT_MSAA_DISABLED)
		RenderingServer.viewport_set_msaa_3d(viewport, RenderingServer.VIEWPORT_MSAA_DISABLED)
		RenderingServer.viewport_set_screen_space_aa(viewport, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
	else:
		(%Water as MeshInstance3D).material_override = ocean_water
		(%Sun as DirectionalLight3D).shadow_enabled = true
		RenderingServer.viewport_set_msaa_2d(viewport, RenderingServer.VIEWPORT_MSAA_2X)
		RenderingServer.viewport_set_msaa_3d(viewport, RenderingServer.VIEWPORT_MSAA_2X)
		RenderingServer.viewport_set_screen_space_aa(viewport, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_SMAA)

		reflections = reflections

static var _reflections = true
static var reflections: bool:
	get:
		return _reflections
	set(value):
		if _instance:
			_instance._update_reflections(value)

func _update_reflections(value):
		var material = (%Water as MeshInstance3D).material_override
		if material is ShaderMaterial:
			material.set_shader_parameter("ssr_enabled", value)

func _ready():
	_instance = self
