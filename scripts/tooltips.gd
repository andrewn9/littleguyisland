extends Node
var TOOLTIP_DELAY := 0.2
var TOOLTIP_MAX_WIDTH := 200
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _hover: Control = null
var _timer := 0.0
var _shown := false

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.11, 0.93)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", sb)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_panel.add_child(_label)
	_layer.add_child(_panel)

func _process(delta: float) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var text := _tooltip_for(hovered) if hovered else ""

	if text == "":
		_hover = null
		_timer = 0.0
		if _shown:
			_panel.visible = false
			_shown = false
		return

	if hovered != _hover:
		_hover = hovered
		_timer = 0.0
		_shown = false
		_panel.visible = false

	if not _shown:
		_timer += delta
		if _timer >= TOOLTIP_DELAY:
			_set_tooltip_text(text)
			_panel.visible = true
			_shown = true
	elif text != _label.text:
		_set_tooltip_text(text)

	if _shown:
		_panel.reset_size()
		var mouse := get_viewport().get_mouse_position()
		var vp := get_viewport().get_visible_rect().size
		var p := mouse + Vector2(16, 18)
		p.x = clampf(p.x, 0.0, maxf(0.0, vp.x - _panel.size.x))
		p.y = clampf(p.y, 0.0, maxf(0.0, vp.y - _panel.size.y))
		_panel.global_position = p

func _set_tooltip_text(text: String) -> void:
	_label.text = text
	var font := _label.get_theme_font("font")
	var fs := _label.get_theme_font_size("font_size")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > TOOLTIP_MAX_WIDTH:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = TOOLTIP_MAX_WIDTH
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.custom_minimum_size.x = 0.0
	_panel.reset_size()

func _tooltip_for(ctrl: Control) -> String:
	var n: Node = ctrl
	while n is Control:
		if (n as Control).tooltip_text != "":
			return (n as Control).tooltip_text
		n = n.get_parent()
	return ""
