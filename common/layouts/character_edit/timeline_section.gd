class_name TimelineSection extends PortraitEditSection


const IMAGE = ["*.bmp,*.jpg,*.jpeg,*.png,*.svg,*.webp;Image Files"]
const DEFAULT_LAYER_NAME: String = "new layer %s"

var filters: Array = ["*.bmp", "*.jpg", "*.jpeg", "*.png", "*.svg", "*.webp"]

@onready var timeline := $TimelineContainer/Timeline
@onready var layer_vbox := %LayerVBox
@onready var layer_timeline_vbox := %LayerTimelineVBox
@onready var cell_number_hbox := %CellNumberHBox
@onready var preview_section := %PreviewSection
@onready var fps_spinbox := %FpsSpinBox
@onready var layer_container := %LayerContainer
@onready var import_frame_button := %ImportFrameButton

@onready var layer := preload("res://common/layouts/character_edit/layer.tscn")
@onready var layer_timeline := preload("res://common/layouts/character_edit/layer_timeline.tscn")
@onready var cell_number := preload("res://common/layouts/character_edit/cell_number.tscn")
@onready var placement_indicator := preload("res://common/layouts/character_edit/horizontal_placement_indicator.tscn")

var cell_count: int = 1
var base_path: String
var selected_cell: TimelineCell
var fps: int : get = _get_fps
var current_indicator: Control


func _get_fps() -> int:
	return fps_spinbox.value


func _process(_delta: float) -> void:
	if current_indicator == null:
		return
	
	var indicator_dist: float = current_indicator.global_position.y - get_global_mouse_position().y
	var indicator_index: int = current_indicator.get_index()
	if indicator_dist > 26:
		layer_vbox.move_child(current_indicator, indicator_index-1)
	elif indicator_dist <= -26:
		layer_vbox.move_child(current_indicator, indicator_index+1)


func _from_dict(dict: Dictionary) -> void:
	_clear()
	cell_count = dict.get("FrameCount", 1)
	fps_spinbox.value = dict.get("Fps", 12)
	selected_cell = null
	
	var default_layer_data := [
		{
			"LayerName": "Layer 1", "Visible": true, "EditorLock": false,
			"Frames": { 0: { "ImagePath": "", "Exposure": 1 }}
		}
	]
	
	for layer_data in dict.get("Layers", default_layer_data):
		add_timeline()
		layer_vbox.get_children().back().timeline_label.text = layer_data.get("LayerName", "undefined")
		layer_timeline_vbox.get_children().back()._from_dict(layer_data)
	_update_cell_number()
	
	#preview_section.update_preview()
	_update_preview()
	


func _clear() -> void:
	cell_count = 1
	for child in layer_vbox.get_children():
		child.queue_free()
	for child in layer_timeline_vbox.get_children():
		child.queue_free()


func get_cell_width() -> int:
	return layer_container.cell_width


func add_timeline() -> void:
	var new_layer: Layer = layer.instantiate()
	var new_layer_timeline: LayerTimeline = layer_timeline.instantiate()
	
	new_layer_timeline.timeline_section = self
	
	layer_vbox.add_child(new_layer)
	layer_timeline_vbox.add_child(new_layer_timeline)
	
	new_layer.timeline_label.text = DEFAULT_LAYER_NAME % layer_vbox.get_child_count()
	new_layer.hover_button.connect("button_down", _on_layer_button_down.bind(new_layer))
	new_layer.hover_button.connect("button_up", _on_layer_button_up.bind(new_layer))
	
	_update_preview()


func _update_cell_number() -> void:
	for cell in cell_number_hbox.get_children():
		cell.queue_free()
	
	for i in range(cell_count):
		var new_cell := cell_number.instantiate()
		new_cell.cell_number = i+1
		new_cell.custom_minimum_size.x = get_cell_width()
		cell_number_hbox.add_child(new_cell)


func _update_preview() -> void:
	# Don't update if this function is called too early.
	if layer_timeline_vbox == null:
		return
	
	var sprites: Array = []
	for child_timeline in layer_timeline_vbox.get_children():
		sprites.append(child_timeline._to_sprite_frames())
	
	preview_section.update_animation(sprites)


func add_cell() -> void:
	cell_count += 1
	_update_cell_number()
	_update_preview()

func _to_dict() -> Dictionary:
	var dict: Dictionary = {
		"Fps": fps,
		"FrameCount": cell_count,
		"Layers": []
	}
	
	for l: Layer in layer_vbox.get_children():
		var layer_idx: int = l.get_index()
		var l_timeline: LayerTimeline= layer_timeline_vbox.get_child(layer_idx)
		dict["Layers"].append({
			"LayerName": l.timeline_label.text,
			"Visible": true,
			"EditorLock": false,
			"Frames": l_timeline._to_dict()
		})
		
	return dict


func _on_btn_add_cell_pressed() -> void:
	add_cell()


func _on_btn_add_layer_pressed() -> void:
	add_timeline()


func _on_button_pressed() -> void:
	if selected_cell == null:
		return
	
	GlobalSignal.emit("open_file_request",
			[_on_file_selected, IMAGE, base_path.get_base_dir()])


func _on_file_selected(path: String) -> void:
	if selected_cell == null:
		return
	
	selected_cell.image_path = Path.absolute_to_relative(path, base_path)
	selected_cell._update()
	_update_preview()


func cell_selected(s_cell: TimelineCell, s_timeline: LayerTimeline) -> void:
	var cell_idx: int = s_timeline.hbox.get_children().find(s_cell)
	var timeline_idx: int = layer_timeline_vbox.get_children().find(s_timeline)
	sub_select(cell_idx, timeline_idx)
	
	if not s_cell.is_exposure:
		import_frame_button.disabled = false


func cell_deselected() -> void:
	var disable_func: Callable = func() -> void:
		if import_frame_button.has_focus():
			return
			
		import_frame_button.disabled = true
		selected_cell = null
		sub_select(-1, -1)
	
	disable_func.call_deferred()


func sub_select(col_idx: int, row_idx: int) -> void:
	var deselect: bool = col_idx <= -1 and row_idx <= -1
	for cell in cell_number_hbox.get_children():
		cell.reset_style()
	
	var timeline_idx: int = 0
	for t: LayerTimeline in layer_timeline_vbox.get_children():
		var cell_idx: int = 0
		for cell in t.get_all_cells():
			if cell_idx == col_idx and not deselect:
				cell.sub_select()
				if row_idx != timeline_idx:
					cell.lose_focus()
			else:
				cell.reset_style()
				cell.lose_focus()
			cell_idx += 1
		timeline_idx += 1
	
	if not deselect:
		cell_number_hbox.get_child(col_idx).sub_select()


func _on_layer_scroll_container_gui_input(_event: InputEvent) -> void:
	%LayerTimelineScrollContainer.scroll_vertical = %LayerScrollContainer.scroll_vertical


func _on_layer_timeline_scroll_container_gui_input(_event: InputEvent) -> void:
	%LayerScrollContainer.scroll_vertical = %LayerTimelineScrollContainer.scroll_vertical


func _on_layer_button_down(target_layer: Layer) -> void:
	var layer_idx: int = layer_vbox.get_children().find(target_layer)
	
	current_indicator = placement_indicator.instantiate()
	layer_vbox.add_child(current_indicator)
	layer_vbox.move_child(current_indicator, layer_idx+1)


func _on_layer_button_up(target_layer: Layer) -> void:
	var layer_idx: int = layer_vbox.get_children().find(target_layer)
	var t_layer_timeline: LayerTimeline = layer_timeline_vbox.get_child(layer_idx-1)
	layer_vbox.move_child(target_layer, current_indicator.get_index())
	layer_timeline_vbox.move_child(t_layer_timeline, current_indicator.get_index()-1)
	
	current_indicator.queue_free()
	current_indicator = null
