extends AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	volume_db = -80
	play()
	var tween = create_tween()
	tween.tween_property(self, "volume_db", -20.0, 2.0)
