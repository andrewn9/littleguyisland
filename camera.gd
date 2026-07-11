extends Camera3D

@export var sensitivity := 0.005
@export var zoom_step := 2.0

var _yaw := 0.0
var _elev := 0.5
var _dist := 25.0

func _ready() -> void:
	_update_camera()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist - zoom_step, 8.0, 60.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist + zoom_step, 8.0, 60.0)
		_update_camera()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * sensitivity
		_elev = clampf(_elev + event.relative.y * sensitivity, 0.1, 1.4)
		_update_camera()

func _update_camera() -> void:
	var offset := Vector3(
		sin(_yaw) * cos(_elev), sin(_elev), cos(_yaw) * cos(_elev)) * _dist
	look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
