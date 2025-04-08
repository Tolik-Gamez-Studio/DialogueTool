extends Window


@export var dns_checkbox: CheckBox
@export var preferences_path: String = "user://preferences.save"

var preferences: ConfigFile = ConfigFile.new()


func _ready() -> void:
	var error = preferences.load(preferences_path)
	var do_not_show: bool
	if error == OK:
		do_not_show = preferences.get_value("Preview", "do_not_show", false)
	
	var version = ProjectSettings.get("application/config/version")
	var is_pre_release = version.split("-").size() > 1
	
	visible = is_pre_release and not do_not_show
	grab_focus()


func _on_button_pressed() -> void:
	if dns_checkbox:
		preferences.set_value("Preview", "do_not_show", dns_checkbox.button_pressed)
		preferences.save(preferences_path)
	hide()


func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
