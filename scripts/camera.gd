class_name CameraController extends Camera3D

@export var sensitivity := 0.005
@export var zoom_step := 2.0
@export var zoom_ramp_speed := 8.0  # snappiness
@export var perspective_distance := 50.0
@export var orthographic_size := 25.0
@export var max_orthographic_size := 840
@export var max_angle := 0.6

var _yaw := 0.0
var _elev := 0.5
var _target_orthographic_size := orthographic_size
const ORTHO_DISTANCE := 2000.0
var start_tween: PropertyTweener

var target: Node3D = null

var pan_offset := Vector3.ZERO
var pan_offset_target := Vector3.ZERO

func _ready() -> void:
	_target_orthographic_size = orthographic_size
	orthographic_size = 1
	_update_camera()
	start_tween = get_tree().create_tween().tween_property(self, "orthographic_size", _target_orthographic_size, 1.0).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	if target:
		pan_offset_target = target.global_position
		_target_orthographic_size = 35

	var t := 1.0 - pow(2.0, -zoom_ramp_speed * delta)
	orthographic_size = lerp(orthographic_size, _target_orthographic_size, t)
	pan_offset = lerp(pan_offset, pan_offset_target, t)
	_update_camera()
	projection = PROJECTION_ORTHOGONAL if Hud.cam_button.button_pressed else PROJECTION_PERSPECTIVE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if projection == PROJECTION_ORTHOGONAL:
					_target_orthographic_size = max(1.0, _target_orthographic_size - zoom_step)
				else:
					perspective_distance = max(perspective_distance - zoom_step, 8.0)
				target = null
				Hud.close_profile()
			MOUSE_BUTTON_WHEEL_DOWN:
				if projection == PROJECTION_ORTHOGONAL:
					_target_orthographic_size = min(_target_orthographic_size + zoom_step, max_orthographic_size)
				else:
					perspective_distance = max(perspective_distance + zoom_step, 8.0)
				target = null
				Hud.close_profile()
	elif event is InputEventMouseMotion and (
			event.button_mask & MOUSE_BUTTON_MASK_MIDDLE
			or (Input.is_key_pressed(KEY_SPACE)
				and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT))):
		_pan(event.relative)
		target = null
		Hud.close_profile()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_yaw -= event.relative.x * sensitivity * Hud.sens_slider.value
		_elev = clampf(_elev + event.relative.y * sensitivity * Hud.sens_slider.value, 0.1, max_angle)


func _pan(relative: Vector2) -> void:
	var wpp := orthographic_size / float(get_viewport().get_visible_rect().size.y)
	var right := global_transform.basis.x
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	pan_offset_target -= right * relative.x * wpp
	pan_offset_target += fwd * relative.y * wpp / maxf(sin(_elev), 0.2)
	var limit := MapData.WORLD_SIZE * 0.5
	pan_offset_target.x = clampf(pan_offset_target.x, -limit, limit)
	pan_offset_target.z = clampf(pan_offset_target.z, -limit, limit)

func _update_camera() -> void:
	var direction := Vector3(
		sin(_yaw) * cos(_elev),
		sin(_elev),
		cos(_yaw) * cos(_elev)
	)
	if projection == PROJECTION_ORTHOGONAL:
		size = orthographic_size
		look_at_from_position(pan_offset + direction * ORTHO_DISTANCE, pan_offset, Vector3.UP)
	else:
		look_at_from_position(pan_offset + direction * perspective_distance, pan_offset, Vector3.UP)
