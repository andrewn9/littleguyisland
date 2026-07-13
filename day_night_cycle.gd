extends DirectionalLight3D

var sky: ProceduralSkyMaterial
@export var environment: WorldEnvironment
@export var gradient: Gradient

var time = 0.0

var DAY_LENGTH = 10.0

func _ready():
	sky = environment.environment.sky.sky_material as ProceduralSkyMaterial


func _process(delta):
	time += delta

	var time_day = fmod(time, DAY_LENGTH) / DAY_LENGTH

	var color  = gradient.sample(time_day)

	rotation.x = (time_day + 0.25) * 2.0 * PI
	sky.sky_top_color = color
	sky.sky_horizon_color = color
	sky.ground_bottom_color = color
	sky.ground_horizon_color = color

	if time_day < 0.25 || time_day > 0.75:
		light_color = color
	else:
		light_color = Color.WHITE
