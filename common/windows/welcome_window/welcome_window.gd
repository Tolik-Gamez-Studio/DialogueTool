class_name WelcomeWindow extends MonologueWindow

## Callback for loading projects after file selection.
var file_callback = func(path): GlobalSignal.emit("load_project", [path])

@onready var close_button: BaseButton = %CloseButton
@onready var recent_files: RecentFilesContainer = %RecentFilesContainer
@onready var version_label: Label = %VersionLabel

var is_startup: bool = false


func _ready():
	super._ready()
	is_startup = true
	version_label.text = "v" + ProjectSettings.get("application/config/version")
	GlobalSignal.add_listener("show_welcome", show)
	GlobalSignal.add_listener("hide_welcome", _on_hide)


func _input(_event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_ESCAPE) and not is_startup:
		GlobalSignal.emit("last_tab")
		hide()


func _on_hide() -> void:
	is_startup = false
	hide()


func _on_new_file_btn_pressed() -> void:
	GlobalSignal.emit("save_file_request", [load_callback, ["*.json"]])


func _on_open_file_btn_pressed() -> void:
	GlobalSignal.emit("open_file_request", [load_callback, ["*.json"]])


func load_callback(path: String) -> void:
	GlobalSignal.emit("load_project", [path])
