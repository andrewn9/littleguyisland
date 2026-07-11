extends CollisionShape3D


func _ready():
	var heightmap = HeightMapShape3D.new()

	var image = MapData.height.get_image()

	image.convert(Image.Format.FORMAT_RF)

	heightmap.update_map_data_from_image(image, 0, 1)

	shape = heightmap

	scale = Vector3(MapData.WORLD_SIZE / MapData.RESOLUTION, MapData.HEIGHT_SCALE, MapData.WORLD_SIZE / MapData.RESOLUTION)
