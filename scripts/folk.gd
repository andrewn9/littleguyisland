class_name Folk extends Entity

enum FolkState { IDLE, WANDER, WALKING, SWIMMING, INTERACTING, DEAD }

var state: FolkState = FolkState.IDLE

func _ready() -> void:
	state = FolkState.IDLE
	target_pos = pos

func tick():
	print("IM HUNGRY")

func _physics_process(delta: float) -> void:
	var dt = Game.scaled_delta
	if dt == 0:
		return
	
	tick()
