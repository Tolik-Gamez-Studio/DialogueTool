class_name LayerTimeline extends PanelContainer


signal timeline_updated


@onready var hbox := %HBox

var timeline: MonologueTimeline
var timeline_cell := preload("res://common/ui/fields/timeline/timeline_cell.tscn")
var placement_indicator := preload("res://common/ui/vertical_placement_indicator.tscn")

var current_indicator: Control


func _ready() -> void:
	add_cell()


func add_cell(image_path = "") -> TimelineCell:
	var cells := get_all_cells()
	var is_exposure: bool = false if image_path != null else cells.size() > 0
	
	var new_cell := timeline_cell.instantiate()
	new_cell.timeline = self
	hbox.add_child(new_cell)
	new_cell.is_exposure = is_exposure
	new_cell.custom_minimum_size.x = timeline.get_cell_width()
	new_cell.image_path = image_path
	new_cell._update()
	new_cell.connect("button_down", _on_cell_button_down.bind(new_cell))
	new_cell.connect("button_up", _on_cell_button_up.bind(new_cell))
	new_cell.connect("button_focus_exited", _on_cell_focus_exited)
	
	if get_all_cells().size() > timeline.cell_count:
		timeline.add_cell()
	
	return new_cell


func _on_cell_button_down(cell: TimelineCell) -> void:
	current_indicator = placement_indicator.instantiate()
	hbox.add_child(current_indicator)
	hbox.move_child(current_indicator, cell.get_index()+1)


func _on_cell_button_up(cell: TimelineCell) -> void:
	var indicator_idx = current_indicator.get_index()
	hbox.move_child(cell, indicator_idx)
	
	current_indicator.queue_free()
	current_indicator = null
	timeline.selected_cell_idx = get_all_cells().find(cell)
	timeline.selected_cell_layer_idx = timeline.layer_timeline_vbox.get_children().find(self)
	
	var first_cell: TimelineCell = get_all_cells()[0]
	if first_cell.is_exposure:
		first_cell.is_exposure = false
		first_cell._update()
	
	timeline_updated.emit()
	
	
	timeline.cell_selected(cell, self)
	
	for child in get_all_cells():
		if child == cell:
			continue
		
		child.lose_focus()


func _on_cell_focus_exited() -> void:
	get_all_cells()[timeline.selected_cell_idx].reset_style()
	timeline.cell_deselected()


func _process(_delta: float) -> void:
	if current_indicator == null:
		return
	
	var indicator_dist: float = current_indicator.global_position.x - get_global_mouse_position().x
	var indicator_index: int = current_indicator.get_index()
	var dist: float = timeline.get_cell_width() / 2.0
	if indicator_dist > dist:
		hbox.move_child(current_indicator, indicator_index-1)
	elif indicator_dist <= -dist:
		hbox.move_child(current_indicator, indicator_index+1)


func remove_cell(cell: TimelineCell) -> void:
	var cells: Array = get_all_cells()
	var index: int = cells.find(cell)
	
	if not cell.is_exposure and have_exposure_after(cell):
		var c_after: TimelineCell = cells[index+1]
		c_after.is_exposure = false
		c_after.image_path = cell.image_path
		c_after._update()
		
	hbox.remove_child(cell)
	cell.queue_free()
	
	timeline_updated.emit()


func fill() -> void:
	_clear()
	for _i in range(timeline.cell_count):
		add_cell()


func _clear() -> void:
	for cell in get_all_cells():
		cell.queue_free()


func _from_dict(dict: Dictionary) -> void:
	_clear()
	var frames: Dictionary = dict.get("Frames")
	for frame_idx in frames.keys():
		for i in range(frames[frame_idx].get("Exposure", 1)):
			var frame_data: Dictionary = frames[frame_idx]
			var cell := add_cell()
			cell.is_exposure = i > 0
			if i <= 0:
				cell.image_path = frame_data.get("ImagePath", "")
			cell._update()


func _to_dict() -> Dictionary:
	var dict: Dictionary = {}
	var cells: Array = get_all_cells()
	for cell: TimelineCell in cells:
		if cell.is_exposure: 
			continue
		
		var cell_idx: int = cells.find(cell)
		dict[cell_idx] = {
			"ImagePath": cell.image_path,
			"Exposure": get_frame_duration(cell_idx)
		}
	
	return dict


func get_all_cells() -> Array:
	var cells: Array = []
	for child in hbox.get_children():
		if child is not TimelineCell or child.is_queued_for_deletion():
			continue
		cells.append(child)
	
	return cells


func _to_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.set_animation_speed("default", timeline.fps)
	
	var cells: Array = get_all_cells()
	for i in range(timeline.cell_count):
		var texture: Texture2D
		var frame_duration: float = 1.0
		
		if cells.size() > i:
			var cell: TimelineCell = cells[i-1]
			if cell.is_exposure:
				continue
			
			var idx = cells.find(cell)
			frame_duration = get_frame_duration(idx)
		
			var root_dir = timeline.base_path.get_base_dir() + Path.get_separator()
			var frame_path: String = Path.relative_to_absolute(cell.image_path, root_dir)
			if FileAccess.file_exists(frame_path):
				texture = ImageLoader.load_image(frame_path)
		else:
			texture = Texture2D.new()
		
		sprite_frames.add_frame("default", texture, frame_duration, i)
		
	return sprite_frames


func get_frame_duration(frame_idx: int) -> float:
	var duration: float = 1.0
	
	var cells: Array = get_all_cells().slice(frame_idx+1)
	for cell: TimelineCell in cells:
		if cell.is_exposure:
			duration += 1.0
			continue
		break
	
	return duration


func add_exposure(of_cell: TimelineCell):
	var index: int = get_all_cells().find(of_cell)
	
	var cell: TimelineCell = add_cell()
	cell.is_exposure = true
	hbox.move_child(cell, index+1)
	cell._on_mouse_exited()
	timeline_updated.emit()


func _on_button_pressed() -> void:
	var cell: TimelineCell = add_cell()
	cell.is_exposure = false
	cell._update()
	timeline_updated.emit()


func have_exposure_after(cell: TimelineCell) -> bool:
	var cells := get_all_cells()
	var index: int = cells.find(cell)
	if index == cells.size() - 1:
		return false
	
	return cells[index+1].is_exposure
