extends DirectionalLight3D

var sky: ProceduralSkyMaterial
@export var environment: WorldEnvironment
@export var gradient: Gradient

var time = 45.0

var DAY_LENGTH = 120.0

func _ready():
	sky = environment.environment.sky.sky_material as ProceduralSkyMaterial


func _process(delta):
	time += delta

	var time_day = fmod(time, DAY_LENGTH) / DAY_LENGTH

	rotation.x = fmod(time_day + 0.25, 0.5) * -2.0 * PI

	var color  = gradient.sample(time_day)

	environment.environment.background_color = color

	if time_day < 0.25 || time_day > 0.75:
		light_color = color * 1.5
	else:
		light_color = Color.WHITE
