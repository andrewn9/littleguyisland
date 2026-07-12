extends Node

var sim_time := 0

var time_scale := 1.0
var paused := true

var scaled_delta:= 0.0

var model: Model

func _ready() -> void:
	pass

func resume():
	paused = false

func pause():
	paused = true

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("person"):
		model.entity_gen.spawn_person(MapData.WORLD_SIZE/2, MapData.WORLD_SIZE/2)

func _physics_process(delta: float) -> void:
	if paused:
		scaled_delta = 0
	else:
		scaled_delta = delta * time_scale
