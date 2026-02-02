class_name WelcomeWindow extends MonologueWindow

## Callback for loading projects after file selection.
var file_callback = func(path): GlobalSignal.emit("load_project", [path])

@onready var close_button: BaseButton = %CloseButton
@onready var recent_files: RecentFilesContainer = %RecentFilesContainer
@onready var version_label: Label = %VersionLabel
@onready var local_btn: Button = %LocalBtn
@onready var github_btn: Button = %GitHubBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var storage_status: Label = %StorageStatus

var is_startup: bool = false


func _ready():
	print("[WelcomeWindow] _ready() start")
	super._ready()
	is_startup = true
	if version_label:
		version_label.text = "v" + ProjectSettings.get("application/config/version")
	GlobalSignal.add_listener("show_welcome", show)
	GlobalSignal.add_listener("hide_welcome", _on_hide)
	
	# Initialize storage buttons (deferred to ensure Storage is ready)
	call_deferred("_update_storage_buttons")
	
	# Show window on startup
	call_deferred("show")
	print("[WelcomeWindow] _ready() end")


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


func _update_storage_buttons() -> void:
	if not Storage:
		return
	
	var current_type = Storage.get_provider_type()
	
	# Update button states
	if local_btn:
		local_btn.button_pressed = (current_type == StorageProvider.StorageType.LOCAL)
	if github_btn:
		github_btn.button_pressed = (current_type == StorageProvider.StorageType.GITHUB_API)
	
	# Update status label
	if not storage_status:
		return
	
	match current_type:
		StorageProvider.StorageType.LOCAL:
			storage_status.text = "Files saved locally"
		StorageProvider.StorageType.GITHUB_API:
			var config = Storage.get_github_config()
			var owner = config.get("repo_owner", "")
			var repo = config.get("repo_name", "")
			if owner.is_empty():
				storage_status.text = "GitHub: Not configured"
			else:
				storage_status.text = "GitHub: %s/%s" % [owner, repo]


func _on_local_btn_pressed() -> void:
	Storage.set_provider_type(StorageProvider.StorageType.LOCAL)
	_update_storage_buttons()


func _on_github_btn_pressed() -> void:
	var config = Storage.get_github_config()
	if config.get("repo_owner", "").is_empty():
		# Not configured, open settings with GitHub pre-selected
		GlobalSignal.emit("show_storage_settings", [StorageProvider.StorageType.GITHUB_API])
		_update_storage_buttons()
		return
	Storage.set_provider_type(StorageProvider.StorageType.GITHUB_API)
	_update_storage_buttons()


func _on_storage_settings_pressed() -> void:
	GlobalSignal.emit("show_storage_settings", [null])
