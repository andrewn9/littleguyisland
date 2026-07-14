extends DirectionalLight3D

var sky: ProceduralSkyMaterial
@export var environment: WorldEnvironment
@export var gradient: Gradient

var time = 90.0

var DAY_LENGTH = 240.0

func _ready():
	sky = environment.environment.sky.sky_material as ProceduralSkyMaterial


func _process(delta):
	time += Game.scaled_delta

	var time_day = fmod(time, DAY_LENGTH) / DAY_LENGTH
	Game.day_fraction = time_day
	Game.day = int(time / DAY_LENGTH)

	rotation.x = fmod(time_day + 0.25, 0.5) * -2.0 * PI

	var color  = gradient.sample(time_day)

	environment.environment.background_color = color

	if time_day < 0.25 || time_day > 0.75:
		light_color = color * 1.5
	else:
		light_color = Color.WHITE
