extends Panel

const VIEWPORT_EDGE_PADDING: float = 0.0

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(false)
	_clamp_inside_viewport()


func _process(_delta: float) -> void:
	if dragging:
		global_position = _clamped_global_position(get_global_mouse_position() - drag_offset)


func _on_move_button_down() -> void:
	dragging = true
	drag_offset = get_global_mouse_position() - global_position
	set_process(true)


func _on_move_button_up() -> void:
	dragging = false
	_clamp_inside_viewport()
	set_process(false)


func _clamp_inside_viewport() -> void:
	global_position = _clamped_global_position(global_position)


func _clamped_global_position(desired_position: Vector2) -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var panel_size: Vector2 = get_global_rect().size
	var min_position: Vector2 = viewport_rect.position + Vector2(VIEWPORT_EDGE_PADDING, VIEWPORT_EDGE_PADDING)
	var max_position: Vector2 = viewport_rect.position + viewport_rect.size - panel_size - Vector2(VIEWPORT_EDGE_PADDING, VIEWPORT_EDGE_PADDING)
	max_position.x = max(max_position.x, min_position.x)
	max_position.y = max(max_position.y, min_position.y)
	return Vector2(
		clamp(desired_position.x, min_position.x, max_position.x),
		clamp(desired_position.y, min_position.y, max_position.y)
	)
