@tool
class_name CircularContainer
extends Container

@export var radius: float = 120.0:
	set(value):
		radius = value
		queue_sort()

@export_range(0.0, 1.0) var radius_ratio: float = 0.0:
	set(value):
		radius_ratio = value
		queue_sort()

@export_range(0.0, 1.0) var item_size_ratio: float = 0.0:
	set(value):
		item_size_ratio = value
		queue_sort()

@export var auto_radius: bool = false:
	set(value):
		auto_radius = value
		queue_sort()

@export var arc_from_degrees: float = -90.0:
	set(value):
		arc_from_degrees = value
		queue_sort()

@export var arc_to_degrees: float = 270.0:
	set(value):
		arc_to_degrees = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange_children()


func _arrange_children() -> void:
	var items := _get_sortable_children()
	var count := items.size()
	if count == 0:
		return

	var center := size * 0.5
	var effective_radius := _get_effective_radius(items)
	var start := deg_to_rad(arc_from_degrees)
	var span := deg_to_rad(arc_to_degrees - arc_from_degrees)

	var step := 0.0
	if is_equal_approx(absf(arc_to_degrees - arc_from_degrees), 360.0):
		step = span / count
	elif count > 1:
		step = span / (count - 1)

	for i in count:
		var child := items[i]
		var angle := start + step * i
		var child_size := _resolve_child_size(child)
		var offset := Vector2(cos(angle), sin(angle)) * effective_radius

		var top_left := center + offset - child_size * 0.5
		fit_child_in_rect(child, Rect2(top_left, child_size))


func _resolve_child_size(child: Control) -> Vector2:
	var result := child.get_combined_minimum_size()

	if item_size_ratio > 0.0:
		var side := minf(size.x, size.y) * item_size_ratio
		return Vector2(side, side)

	if result.x <= 0.0:
		result.x = child.size.x
	if result.y <= 0.0:
		result.y = child.size.y
	return result


func _get_effective_radius(items: Array[Control]) -> float:
	if radius_ratio > 0.0:
		return minf(size.x, size.y) * 0.5 * radius_ratio
	if not auto_radius:
		return radius

	var margin := _get_largest_child_extent(items)
	return maxf(0.0, minf(size.x, size.y) * 0.5 - margin)


func _get_sortable_children() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control != null and control.visible and not control.is_set_as_top_level():
			result.append(control)
	return result


func _get_largest_child_extent(items: Array[Control]) -> float:
	var extent := 0.0
	for child in items:
		var s := _resolve_child_size(child)
		extent = maxf(extent, maxf(s.x, s.y) * 0.5)
	return extent


func _get_minimum_size() -> Vector2:
	if radius_ratio > 0.0:
		return Vector2.ZERO
	var items := _get_sortable_children()
	var margin := _get_largest_child_extent(items)
	var diameter := radius * 2.0 + margin * 2.0
	return Vector2(diameter, diameter)
