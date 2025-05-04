class_name TimelineCell extends PanelContainer


signal button_down
signal button_up
signal button_focus_exited

@onready var single_cell_texture := preload("res://ui/assets/icons/cell_single.svg")
@onready var empty_cell_texture := preload("res://ui/assets/icons/cell_empty.svg")
@onready var left_cell_texture := preload("res://ui/assets/icons/cell_left.svg")
@onready var right_cell_texture := preload("res://ui/assets/icons/cell_right.svg")
@onready var middle_cell_texture := preload("res://ui/assets/icons/cell_middle.svg")

@onready var button := $Button
@onready var texture_rect := $TextureRect

var image_path: String : set = _set_image_path
var timeline: LayerTimeline


func _set_image_path(value: String) -> void:
	image_path = value
	_update()


func _ready() -> void:
	texture_rect.texture = empty_cell_texture
	GlobalSignal.add_listener("timeline_zoom_in", _on_timeline_zoom)
	GlobalSignal.add_listener("timeline_zoom_out", _on_timeline_zoom)


func _update() -> void:
	texture_rect.texture = empty_cell_texture
	
	if not image_path.is_empty():
		texture_rect.texture = single_cell_texture


func lose_focus() -> void:
	button.button_pressed = false


func get_base_sb() -> StyleBoxFlat:
	# TODO: Use theme variation instead
	var sb: StyleBox = StyleBoxFlat.new()
	sb.bg_color = Color("d651613f")
	sb.border_color = Color("1e1e21")
	sb.border_width_right = 1
	return sb


func sub_select() -> void:
	add_theme_stylebox_override("panel", get_base_sb())

func reset_style() -> void:
	var sb: StyleBox = get_base_sb()
	sb.draw_center = false
	add_theme_stylebox_override("panel", sb)

 
func _on_timeline_zoom(cell_width: int) -> void:
	custom_minimum_size.x = cell_width

func _on_button_button_down() -> void: button_down.emit()
func _on_button_button_up() -> void: button_up.emit()
func _on_button_toggled(toggled_on: bool) -> void:
	if toggled_on == false: button_focus_exited.emit()
