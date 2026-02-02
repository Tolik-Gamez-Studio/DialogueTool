class_name StorageSettingsWindow extends MonologueWindow
## Simple window for configuring storage - Local or GitHub (via API, no Git needed)

@onready var storage_type_option: OptionButton = %StorageTypeOption
@onready var github_settings: VBoxContainer = %GitHubSettings
@onready var repo_owner_edit: LineEdit = %RepoOwnerEdit
@onready var repo_name_edit: LineEdit = %RepoNameEdit
@onready var branch_edit: LineEdit = %BranchEdit
@onready var token_edit: LineEdit = %TokenEdit
@onready var base_path_edit: LineEdit = %BasePathEdit
@onready var status_label: Label = %StatusLabel
@onready var save_button: Button = %SaveButton


func _ready():
	super._ready()
	
	# Ensure OptionButton has items (always rebuild to match enum values)
	storage_type_option.clear()
	storage_type_option.add_item("Local (on this computer)", StorageProvider.StorageType.LOCAL)  # ID = 0
	storage_type_option.add_item("GitHub (cloud sync)", StorageProvider.StorageType.GITHUB_API)  # ID = 2
	
	_load_current_settings()
	_update_ui_visibility()
	
	# Connect global signal to show this window
	GlobalSignal.add_listener("show_storage_settings", _show_with_type)


func _show_with_type(preselect_type: Variant = null) -> void:
	if preselect_type != null and preselect_type is int:
		_select_storage_type(preselect_type)
		_update_ui_visibility()
	# Bring to front
	show()
	move_to_foreground()
	grab_focus()


func _select_storage_type(storage_type: int) -> void:
	for i in storage_type_option.item_count:
		if storage_type_option.get_item_id(i) == storage_type:
			storage_type_option.selected = i
			break


func _load_current_settings():
	var current_type = Storage.get_provider_type()
	_select_storage_type(current_type)
	
	# Load GitHub config
	var github_config = Storage.get_github_config()
	repo_owner_edit.text = github_config.get("repo_owner", "")
	repo_name_edit.text = github_config.get("repo_name", "")
	branch_edit.text = github_config.get("branch", "main")
	token_edit.text = github_config.get("token", "")
	base_path_edit.text = github_config.get("base_path", "dialogues")
	
	_update_status()


func _update_ui_visibility():
	var selected_type = storage_type_option.get_item_id(storage_type_option.selected)
	github_settings.visible = (selected_type == StorageProvider.StorageType.GITHUB_API)


func _update_status():
	var current_type = Storage.get_provider_type()
	match current_type:
		StorageProvider.StorageType.LOCAL:
			status_label.text = "Files saved on this computer"
		StorageProvider.StorageType.GITHUB_API:
			var config = Storage.get_github_config()
			if config.get("repo_owner", "").is_empty():
				status_label.text = "GitHub: Not configured"
			else:
				status_label.text = "GitHub: %s/%s" % [config.get("repo_owner"), config.get("repo_name")]


func _on_storage_type_changed(_index: int):
	_update_ui_visibility()


func _on_save_pressed():
	var selected_type = storage_type_option.get_item_id(storage_type_option.selected) as StorageProvider.StorageType
	
	if selected_type == StorageProvider.StorageType.GITHUB_API:
		var github_config = {
			"repo_owner": repo_owner_edit.text.strip_edges(),
			"repo_name": repo_name_edit.text.strip_edges(),
			"branch": branch_edit.text.strip_edges(),
			"token": token_edit.text.strip_edges(),
			"base_path": base_path_edit.text.strip_edges(),
		}
		
		# Validate
		var validation = Storage.validate_github_config(github_config)
		if not validation.get("valid", false):
			_show_error("Configuration Error", "\n".join(validation.get("errors", [])))
			return
		
		Storage.update_github_config(github_config)
	
	if Storage.set_provider_type(selected_type):
		status_label.text = "Settings saved!"
		_update_status.call_deferred()
		# Close window after short delay
		await get_tree().create_timer(0.5).timeout
		hide()
	else:
		_show_error("Error", "Failed to save settings")


func _show_error(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_close_pressed():
	hide()


func _on_paste_token_pressed():
	_paste_to_field(token_edit)


## Paste from clipboard - works on Web via JavaScript
func _paste_to_field(target_edit: LineEdit) -> void:
	if OS.has_feature("web"):
		# Use JavaScript Clipboard API with async/Promise handling
		var js_code = """
		(async function() {
			try {
				const text = await navigator.clipboard.readText();
				return text;
			} catch(e) {
				// Fallback: try to use a prompt
				return prompt('Paste your text here (Ctrl+V):') || '';
			}
		})()
		"""
		# Create callback for async result
		var callback = JavaScriptBridge.create_callback(_on_clipboard_result.bind(target_edit))
		JavaScriptBridge.eval("navigator.clipboard.readText().then(text => { window._godot_cb(text); }).catch(() => { const t = prompt('Paste your token here:'); if(t) window._godot_cb(t); });".replace("window._godot_cb", ""), true)
		
		# Simpler approach: use prompt as fallback
		var result = JavaScriptBridge.eval("prompt('Paste your GitHub token here:')")
		if result and result != "null" and not str(result).is_empty():
			target_edit.text = str(result)
			status_label.text = "Token pasted!"
	else:
		var clipboard_text = DisplayServer.clipboard_get()
		if not clipboard_text.is_empty():
			target_edit.text = clipboard_text
			status_label.text = "Pasted from clipboard"


func _on_clipboard_result(args, target_edit: LineEdit):
	if args.size() > 0:
		target_edit.text = str(args[0])
