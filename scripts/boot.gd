extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("boot")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			$ClickSoundPlayer.play()
			print("s")


func _on_texture_button_pressed() -> void:
	$HorseSoundPlayer.play()


func _on_simexe_pressed() -> void:
	%SaveModal.visible = not %SaveModal.visible
