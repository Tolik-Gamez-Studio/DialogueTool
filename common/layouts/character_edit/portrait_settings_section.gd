class_name PortraitSettingsSection extends PortraitEditSection


signal changed

var portrait_type := Property.new(MonologueGraphNode.DROPDOWN, {}, "Image")
var image_path := Property.new(MonologueGraphNode.FILE, { "filters": FilePicker.IMAGE })
var offset := Property.new(MonologueGraphNode.VECTOR, {}, [0, 0])
var mirror := Property.new(MonologueGraphNode.TOGGLE, {}, false)

@onready var preview_section := %PreviewSection
@onready var timeline_section := %TimelineSection

var id: String
var base_path: String : set = _set_base_path


func _ready() -> void:
	portrait_type.callers["set_items"] = [[
		{ "id": 0, "text": "Image"     },
		{ "id": 1, "text": "Animation" },
	]]
	portrait_type.change.connect(_on_portrait_type_change)
	image_path.change.connect(_on_image_path_change)
	offset.change.connect(_on_offset_change)
	mirror.change.connect(_on_mirror_change)
	super._ready()


func _set_base_path(val: String) -> void:
	base_path = val
	image_path.setters["base_path"] = val


func _from_dict(dict: Dictionary = {}) -> void:
	var portrait_list: Array = dict.get("Portraits", [])
	if portrait_index >= 0 and portrait_index < portrait_list.size():
		var portrait_dict: Dictionary = portrait_list[portrait_index]["Portrait"]
		super._from_dict(portrait_dict)
		timeline_section._from_dict(portrait_dict.get("Animation", {}))
	_on_portrait_type_change()


func _to_dict() -> Dictionary:
	#var portrait_type_string: String = portrait_type_field.value
	#var dict: Dictionary = {
		#"PortraitType": portrait_type_string,
		#"Offset": offset_vector_field.value,
		#"Mirror": mirror_cb.button_pressed
	#}
	#
	#match portrait_type_string:
		#"Image":
			#dict["ImagePath"] = image_path_fp.value
		#"Animation":
			#dict["Animation"] = timeline_section._to_dict()
	#
	return super._to_dict()


func _on_check_button_toggled(toggled_on: bool) -> void:
	preview_section.update_mirror(toggled_on)


func _on_portrait_type_change(_old_value: Variant = null, _new_value: Variant = null) -> void:
	var _process_type_change = func():
		timeline_section.visible = portrait_type.value == "Animation"
	
	_process_type_change.call_deferred()


func _on_image_path_change(_old_value: Variant = null, new_value: Variant = null) -> void:
	if not new_value:
		return
	
	var is_valid: bool = image_path.field.validate(image_path.value)
	if is_valid:
		var im: Image = Image.new()
		im.load(new_value)
		var texture: ImageTexture = ImageTexture.create_from_image(im)
		preview_section.update_preview(texture)
		return
	preview_section.update_preview(ImageTexture.new())


func _on_offset_change(_old_value: Variant = null, new_value: Variant = null) -> void:
	preview_section.update_offset(new_value)


func _on_mirror_change(_old_value: Variant = null, new_value: Variant = null) -> void:
	preview_section.update_mirror(new_value)
