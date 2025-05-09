class_name LayerTimeline extends PanelContainer


@onready var hbox := %HBox

var timeline_section: TimelineSection
var timeline_cell := preload("res://common/layouts/character_edit/cell.tscn")
var placement_indicator := preload("res://common/layouts/character_edit/vertical_placement_indicator.tscn")

var current_indicator: Control


func _ready() -> void:
	add_cell()


func add_cell() -> TimelineCell:
	var cells := get_all_cells()
	var is_exposure: bool = cells.size() > 0
	
	var new_cell := timeline_cell.instantiate()
	hbox.add_child(new_cell)
	new_cell.timeline = self
	new_cell.is_exposure = is_exposure
	new_cell.custom_minimum_size.x = timeline_section.get_cell_width()
	new_cell._update()
	new_cell.connect("button_down", _on_cell_button_down.bind(new_cell))
	new_cell.connect("button_up", _on_cell_button_up.bind(new_cell))
	new_cell.connect("button_focus_exited", _on_cell_focus_exited)
	
	if get_all_cells().size() > timeline_section.cell_count:
		timeline_section.add_cell()
	
	return new_cell


func _on_cell_button_down(cell: TimelineCell) -> void:
	timeline_section.cell_selected(cell, self)
	
	for child in get_all_cells():
		if child == cell:
			continue
		
		child.lose_focus()
	
	current_indicator = placement_indicator.instantiate()
	hbox.add_child(current_indicator)
	hbox.move_child(current_indicator, cell.get_index()+1)


func _on_cell_button_up(cell: TimelineCell) -> void:
	var indicator_idx = current_indicator.get_index()
	hbox.move_child(cell, indicator_idx)
	
	current_indicator.queue_free()
	current_indicator = null
	timeline_section.selected_cell = cell
	
	var first_cell: TimelineCell = get_all_cells()[0]
	if first_cell.is_exposure:
		first_cell.is_exposure = false


func _on_cell_focus_exited() -> void:
	timeline_section.selected_cell.reset_style()
	timeline_section.cell_deselected()


func _process(_delta: float) -> void:
	if current_indicator == null:
		return
	
	var indicator_dist: float = current_indicator.global_position.x - get_global_mouse_position().x
	var indicator_index: int = current_indicator.get_index()
	var dist: float = timeline_section.get_cell_width() / 2.0
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


func fill() -> void:
	_clear()
	for _i in range(timeline_section.cell_count):
		add_cell()


func _clear() -> void:
	for cell in get_all_cells():
		cell.queue_free()


func _from_dict(dict: Dictionary) -> void:
	_clear()
	var frames: Dictionary = dict.get("Frames")
	for frame_idx: int in frames.keys():
		var frame_data: Dictionary = frames[frame_idx]
		var cell := add_cell()
		cell.image_path = frame_data.get("ImagePath", "")


func _to_dict() -> Dictionary:
	var dict: Dictionary = {}
	for cell: TimelineCell in get_all_cells():
		var cell_idx: int = cell.get_index()
		dict[cell_idx] = {
			"ImagePath": cell.image_path,
			"Exposure": 1
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
	sprite_frames.set_animation_speed("default", timeline_section.fps)
	
	var cells: Array = get_all_cells()
	for cell: TimelineCell in cells:
		if cell.is_exposure:
			continue
		
		var idx = cells.find(cell)
		var texture: Texture2D = PlaceholderTexture2D.new()
		
		if FileAccess.file_exists(cell.image_path):
			var img := Image.load_from_file(cell.image_path)
			if img != null:
				texture = ImageTexture.create_from_image(img)
		
		sprite_frames.add_frame("default", texture, get_frame_duration(idx), idx)
		
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


func _on_button_pressed() -> void:
	var cell: TimelineCell = add_cell()
	cell.is_exposure = false
	cell._update()


func have_exposure_after(cell: TimelineCell) -> bool:
	var cells := get_all_cells()
	var index: int = cells.find(cell)
	if index == cells.size() - 1:
		return false
	
	return cells[index+1].is_exposure
