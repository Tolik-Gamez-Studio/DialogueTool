extends HSplitContainer

const MAX_CELL_WIDTH: int = 150
const MIN_CELL_WIDTH: int = 26

@onready var layer_timeline_scroll_container := $LayerTimelineContainer/ScrollContainer

var mouse_hover: bool = false
var cell_width: int = 26


func _input(event: InputEvent) -> void:
	# Disable scroll container if Ctrl is pressed
	if Input.is_action_just_pressed("Ctrl"):
		layer_timeline_scroll_container.mouse_filter = MOUSE_FILTER_IGNORE
	elif Input.is_action_just_released("Ctrl"):
		layer_timeline_scroll_container.mouse_filter = MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and Input.is_action_pressed("Ctrl"):
		var t: float = remap(cell_width, MIN_CELL_WIDTH, MAX_CELL_WIDTH, 0.0, 1.0)
		# zoom in
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cell_width = min(cell_width + lerp(2.0, 12.0, pow(t, 2)), MAX_CELL_WIDTH)
			GlobalSignal.emit("timeline_zoom_in", [cell_width])
		# zoom out
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cell_width = max(cell_width - lerp(2.0, 12.0, pow(t, 2)), MIN_CELL_WIDTH)
			GlobalSignal.emit("timeline_zoom_out", [cell_width])


func _on_mouse_entered() -> void: mouse_hover = true
func _on_mouse_exited() -> void: mouse_hover = false
