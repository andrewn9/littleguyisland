extends Camera3D

@export var sensitivity := 0.005
@export var zoom_step := 2.0

@export var perspective_distance := 50.0
@export var orthographic_size := 25.0

var _yaw := 0.0
var _elev := 0.5

const ORTHO_DISTANCE := 400.0

func _ready() -> void:
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if projection == PROJECTION_ORTHOGONAL:
					orthographic_size = max(1.0, orthographic_size - zoom_step)
				else:
					perspective_distance = max(perspective_distance - zoom_step, 8.0)
				_update_camera()

			MOUSE_BUTTON_WHEEL_DOWN:
				if projection == PROJECTION_ORTHOGONAL:
					orthographic_size += zoom_step
				else:
					perspective_distance = max(perspective_distance + zoom_step, 8.0)
				_update_camera()

	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_yaw -= event.relative.x * sensitivity
		_elev = clampf(_elev + event.relative.y * sensitivity, 0.1, 1.4)
		_update_camera()

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
