class_name RecentFilesContainer extends VBoxContainer

@export var button_container: Control
@export var save_path: String = Constants.HISTORY_PATH

@onready var button_scene: PackedScene = preload(
	"res://common/windows/welcome_window/recent_file_button.tscn"
)
@onready var title_label: Label = $RecentFilesLabel
@onready var scroll_container: ScrollContainer = $ScrollContainer

var recent_filepaths: Array = []
var _is_loading_remote: bool = false
const MAX_SCROLL_HEIGHT: int = 150  # Maximum height for file list


func _ready() -> void:
	GlobalSignal.add_listener("load_successful", add)
	# Delay connection to ensure Storage is ready
	if Storage:
		Storage.provider_changed.connect(_on_provider_changed)
	# Use call_deferred to avoid issues during _ready
	call_deferred("refresh")


func _on_provider_changed(_provider) -> void:
	refresh()


## Adds a new filepath as recent file and saves it to the history file.
func add(filepath: String) -> void:
	# Don't add github:// paths to local history
	if filepath.begins_with("github://"):
		return
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		recent_filepaths.erase(filepath)
		recent_filepaths.push_front(filepath)
		file.store_string(JSON.stringify(recent_filepaths.slice(0, 10)))
		file.close()
		refresh()


func create_button(filepath: String) -> Control:
	if not button_container:
		push_error("[RecentFiles] button_container is null!")
		return null
	
	# Create container for file button + delete button
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create file button
	var btn = button_scene.instantiate()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_text: String
	
	# Handle GitHub paths
	if filepath.begins_with("github://"):
		btn_text = filepath.replace("github://", "").get_file()
		btn.text = "📁 " + Util.truncate_filename(btn_text)
	else:
		btn_text = filepath.replace("\\", "/")
		btn_text = btn_text.replace("//", "/")
		var parts = btn_text.split("/")
		if parts.size() >= 2:
			parts = parts.slice(-2, parts.size())
			btn_text = parts[0].path_join(parts[1])
		else:
			btn_text = parts.back()
		btn.text = Util.truncate_filename(btn_text)
	
	btn.pressed.connect(GlobalSignal.emit.bind("load_project", [filepath]))
	
	# Create delete button
	var delete_btn = Button.new()
	delete_btn.text = "🗑"
	delete_btn.tooltip_text = "Delete file"
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.pressed.connect(_on_delete_file.bind(filepath, hbox))
	
	hbox.add_child(btn)
	hbox.add_child(delete_btn)
	button_container.add_child(hbox)
	
	print("[RecentFiles] Button added: %s" % btn.text)
	return hbox


## Handle file deletion
func _on_delete_file(filepath: String, container: Control) -> void:
	# Show confirmation
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Delete '%s'?\n\nThis cannot be undone!" % filepath.get_file()
	confirm.title = "Confirm Delete"
	confirm.confirmed.connect(_delete_file_confirmed.bind(filepath, container, confirm))
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _delete_file_confirmed(filepath: String, container: Control, dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	
	var success = false
	if Storage:
		success = await Storage.delete_file(filepath)
	
	if success:
		print("[RecentFiles] Deleted: %s" % filepath)
		recent_filepaths.erase(filepath)
		container.queue_free()
		
		# Also remove from local history
		if not filepath.begins_with("github://"):
			var file = FileAccess.open(save_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(recent_filepaths.slice(0, 10)))
				file.close()
	else:
		push_error("[RecentFiles] Failed to delete: %s" % filepath)


## Create the recent file history save in user directory if it doesn't exist.
func create_file() -> void:
	if not FileAccess.file_exists(save_path):
		FileAccess.open(save_path, FileAccess.WRITE)


## Load the recent file history save and create buttons for it.
func load_file() -> void:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var data = parse_history(file.get_as_text())
		file.close()

		for path in data.slice(0, 3):
			recent_filepaths.append(path)
			create_button(path)


## Return only the recent files that still exist as a JSON array.
func parse_history(text: String) -> Array:
	var data = JSON.parse_string(text)
	if data is Array:
		return data.filter(func(p): return FileAccess.file_exists(p))
	return []


## Load files from GitHub repository
func load_remote_files() -> void:
	if _is_loading_remote:
		return
	_is_loading_remote = true
	
	if title_label:
		title_label.text = "Loading from GitHub..."
	
	var files: Array[String] = []
	if Storage:
		files = await Storage.list_remote_files(".json")
	
	if not is_inside_tree():
		_is_loading_remote = false
		return
	
	print("[RecentFiles] Creating buttons for %d files, button_container=%s" % [files.size(), button_container])
	for path in files.slice(0, 20):  # Show max 20 files
		recent_filepaths.append(path)
		create_button(path)
	print("[RecentFiles] Created %d buttons" % button_container.get_child_count())
	
	if title_label:
		if files.is_empty():
			title_label.text = "No files in repository"
		else:
			title_label.text = "Repository files"
	
	_is_loading_remote = false
	show_or_hide()


## Remake the recent file list.
func refresh() -> void:
	if not is_inside_tree():
		return
	
	for child in button_container.get_children():
		child.queue_free()
	recent_filepaths.clear()
	
	# Check if we should show GitHub files or local recent files
	if Storage and Storage.supports_remote_files():
		if title_label:
			title_label.text = "Repository files"
		show()
		load_remote_files()
	else:
		if title_label:
			title_label.text = "Recent files"
		create_file()
		load_file()
		show_or_hide()


## Show container if recent file buttons are present, otherwise hide it.
func show_or_hide() -> void:
	if button_container.get_child_count() > 0 or _is_loading_remote:
		show()
		# Limit scroll container height
		if scroll_container:
			scroll_container.custom_minimum_size.y = min(button_container.size.y, MAX_SCROLL_HEIGHT)
	else:
		hide()
