extends Control

@onready var readme_panel: Panel = $readmepanel

@onready var new_world_popup: ColorRect = %NewWorldPopup
@onready var world_name_edit: LineEdit = %WorldNameEdit
@onready var tutorial_check: CheckBox = %TutorialCheck
@onready var height_label: Label = %HeightLabel
@onready var value_label: Label = %ValueLabel
@onready var reset_confirm: ConfirmationDialog = %ResetConfirm
@onready var image_dialog: FileDialog = %ImageDialog

var _dragging_readme := false
var _readme_grab := Vector2.ZERO

var _nw_slot := -1
var _confirm_slot := -1
var _file_target := ""
var _height_img: Image = null
var _value_img: Image = null
var _slot_buttons := {}

func _ready() -> void:
	$AnimationPlayer.play("boot")
	if Game.skip_boot:
		Game.skip_boot = false
		$AnimationPlayer.seek($AnimationPlayer.get_animation("boot").length, true)
	_wire_dialogs()
	_setup_saves()
	_setup_readme()

func _wire_dialogs() -> void:
	%CreateWorld.pressed.connect(_on_create_world)
	%CancelWorld.pressed.connect(func(): new_world_popup.visible = false)
	%HeightUpload.pressed.connect(_pick_image.bind("height"))
	%ValueUpload.pressed.connect(_pick_image.bind("value"))
	reset_confirm.confirmed.connect(_on_reset_confirmed)
	image_dialog.file_selected.connect(_on_image_selected)

func _setup_saves() -> void:
	var box := %SaveModal.get_node("VFlowContainer")
	var slot := 0
	for child in box.get_children():
		if not (child is Button):
			continue
		_slot_buttons[slot] = child
		_label_slot(slot)
		child.tooltip_text = "left-click: open\nright-click: reset"
		child.pressed.connect(_on_slot_pressed.bind(slot))
		child.gui_input.connect(_on_slot_input.bind(slot))
		slot += 1

func _label_slot(slot: int) -> void:
	var button: Button = _slot_buttons.get(slot)
	if button == null:
		return
	var meta := Save.slot_meta(slot)
	if meta.is_empty():
		button.text = "slot %d — new world" % [slot + 1]
	else:
		var world: String = meta.name if meta.name != "" else "world"
		button.text = "slot %d — %s (day %d, %d folk)" % [slot + 1, world, meta.day, meta.population]

func _on_slot_pressed(slot: int) -> void:
	if Save.has_slot(slot):
		_launch(slot, true)
	else:
		_open_new_world(slot)

func _on_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if Save.has_slot(slot):
			_confirm_slot = slot
			reset_confirm.dialog_text = "Reset slot %d? This deletes the saved world." % [slot + 1]
			reset_confirm.popup_centered()

func _on_reset_confirmed() -> void:
	if _confirm_slot >= 0:
		Save.delete_slot(_confirm_slot)
		_label_slot(_confirm_slot)

func _launch(slot: int, load_existing: bool) -> void:
	Game.active_slot = slot
	Game.pending_load = load_existing
	get_tree().change_scene_to_file("res://game.tscn")

func _open_new_world(slot: int) -> void:
	_nw_slot = slot
	world_name_edit.text = ""
	tutorial_check.button_pressed = true
	_height_img = null
	_value_img = null
	height_label.text = "heightmap: (none)"
	value_label.text = "valuemap: (none)"
	%SaveModal.visible = false
	new_world_popup.visible = true
	world_name_edit.grab_focus()


func _on_create_world() -> void:
	Game.world_name = world_name_edit.text.strip_edges()
	if Game.world_name == "":
		Game.world_name = "island %d" % [_nw_slot + 1]
	Game.tutorial = tutorial_check.button_pressed
	Game.new_world_height_img = _height_img
	Game.new_world_value_img = _value_img
	new_world_popup.visible = false
	_launch(_nw_slot, false) 

func _pick_image(target: String) -> void:
	_file_target = target
	image_dialog.popup_centered_ratio(0.6)


func _on_image_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(MapData.RESOLUTION, MapData.RESOLUTION)
	var fname := path.get_file()
	if _file_target == "height":
		_height_img = img
		height_label.text = "heightmap: " + fname
	elif _file_target == "value":
		_value_img = img
		value_label.text = "valuemap: " + fname

func _setup_readme() -> void:
	readme_panel.visible = false
	$Apps/readme/TextureButton.pressed.connect(_open_readme)
	readme_panel.get_node("Close").pressed.connect(func(): readme_panel.visible = false)
	readme_panel.gui_input.connect(_on_readme_input)


func _open_readme() -> void:
	readme_panel.visible = true
	readme_panel.move_to_front()


func _on_readme_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_readme = event.pressed
		if event.pressed:
			readme_panel.move_to_front()
			_readme_grab = readme_panel.get_global_mouse_position() - readme_panel.global_position
	elif event is InputEventMouseMotion and _dragging_readme:
		readme_panel.global_position = readme_panel.get_global_mouse_position() - _readme_grab

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		$ClickSoundPlayer.play()


func _on_texture_button_pressed() -> void:
	$HorseSoundPlayer.play()


func _on_simexe_pressed() -> void:
	%SaveModal.visible = not %SaveModal.visible
