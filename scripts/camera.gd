extends Camera3D

@export var sensitivity := 0.005
@export var zoom_step := 2.0
@export var zoom_ramp_speed := 8.0  # snappiness
@export var perspective_distance := 50.0
@export var orthographic_size := 25.0
@export var max_orthographic_size := 840

var _yaw := 0.0
var _elev := 0.5
var _target_orthographic_size := orthographic_size
const ORTHO_DISTANCE := 400.0
var start_tween: PropertyTweener

func _ready() -> void:
	var target = orthographic_size
	orthographic_size = 1
	_target_orthographic_size = target
	_update_camera()
	near = -2000
	start_tween = get_tree().create_tween().tween_property(self, "orthographic_size", target, 1.0).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	var t := 1.0 - pow(2.0, -zoom_ramp_speed * delta)
	orthographic_size = lerp(orthographic_size, _target_orthographic_size, t)
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if projection == PROJECTION_ORTHOGONAL:
					_target_orthographic_size = max(1.0, _target_orthographic_size - zoom_step)
				else:
					perspective_distance = max(perspective_distance - zoom_step, 8.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if projection == PROJECTION_ORTHOGONAL:
					_target_orthographic_size = min(_target_orthographic_size + zoom_step, max_orthographic_size)
				else:
					perspective_distance = max(perspective_distance + zoom_step, 8.0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_yaw -= event.relative.x * sensitivity
		_elev = clampf(_elev + event.relative.y * sensitivity, 0.1, 0.6)

func _update_camera() -> void:
	var direction := Vector3(
		sin(_yaw) * cos(_elev),
		sin(_elev),
		cos(_yaw) * cos(_elev)
	)
	if projection == PROJECTION_ORTHOGONAL:
		size = orthographic_size
		look_at_from_position(direction * ORTHO_DISTANCE, Vector3.ZERO, Vector3.UP)
	else:
		look_at_from_position(direction * perspective_distance, Vector3.ZERO, Vector3.UP)
