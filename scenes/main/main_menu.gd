extends MenuButton

@onready var search_icon = preload("res://ui/assets/icons/search.svg")
@onready var storage_icon = preload("res://ui/assets/icons/cloud.svg") if ResourceLoader.exists("res://ui/assets/icons/cloud.svg") else null

var _file_submenu: PopupMenu
var _edit_submenu: PopupMenu


func _ready() -> void:
	var popup: PopupMenu = get_popup()
	popup.transparent = true
	popup.transparent_bg = true

	# Search item
	popup.add_icon_item(search_icon, "Search...")
	popup.set_item_shortcut(0, create_shortcut("Show searchbar"))
	popup.add_separator()

	# File item
	_file_submenu = create_popup_menu()
	_file_submenu.add_item("New file")
	_file_submenu.add_item("Open file")
	_file_submenu.add_separator()
	_file_submenu.add_item("Save file")
	_file_submenu.add_item("Save file as")
	_file_submenu.add_separator()
	_file_submenu.add_item("Sync to Remote")  # index 6
	_file_submenu.add_item("Pull from Remote")  # index 7
	_file_submenu.set_item_shortcut(3, create_shortcut("Save"))
	_file_submenu.index_pressed.connect(_on_file_submenu_pressed)
	popup.add_submenu_node_item("File", _file_submenu)

	# Edit item
	_edit_submenu = create_popup_menu()
	_edit_submenu.add_item("Undo")
	_edit_submenu.add_item("Redo")
	_edit_submenu.add_separator()
	_edit_submenu.add_item("Preferences")
	_edit_submenu.add_item("Storage Settings")  # index 4
	_edit_submenu.set_item_shortcut(0, create_shortcut("Undo"))
	_edit_submenu.set_item_shortcut(1, create_shortcut("Redo"))
	_edit_submenu.index_pressed.connect(_on_edit_submenu_pressed)
	popup.add_submenu_node_item("Edit", _edit_submenu)

	# View item
	var view_submenu: PopupMenu = create_popup_menu()
	view_submenu.add_check_item("Pixel grid")
	view_submenu.add_check_item("Snap to grid")
	view_submenu.add_separator()
	view_submenu.add_item("Zoom in")
	view_submenu.add_item("Zoom out")
	view_submenu.add_item("Zoom to 100%")
	view_submenu.add_item("Zoom to fit")
	view_submenu.add_item("Zoom to selection")
	popup.add_submenu_node_item("View", view_submenu)

	# Node item
	var node_submenu: PopupMenu = create_popup_menu()
	node_submenu.add_item("Add node")
	node_submenu.add_item("Arrange nodes")
	node_submenu.set_item_shortcut(0, create_shortcut("Add node"))
	popup.add_submenu_node_item("Node", node_submenu)
	popup.add_separator()

	# Exit item
	popup.add_item("Exit")
	popup.set_item_shortcut(7, create_shortcut("Exit"))


func create_popup_menu() -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()
	popup.transparent = true
	popup.transparent_bg = true
	return popup


func create_shortcut(action_name: StringName) -> Shortcut:
	var _shortcut := Shortcut.new()
	var inputevent := InputEventAction.new()
	inputevent.action = action_name
	_shortcut.events.append(inputevent)
	return _shortcut


func _on_about_to_popup() -> void:
	var popup: PopupMenu = get_popup()
	await get_tree().process_frame
	popup.position.y -= (get_window().size.y - floor(global_position.y)) + 5
	
	# Update sync menu items visibility based on storage provider
	_update_sync_menu_items()


func _update_sync_menu_items() -> void:
	var supports_sync = Storage.supports_sync()
	_file_submenu.set_item_disabled(6, not supports_sync)  # Sync to Remote
	_file_submenu.set_item_disabled(7, not supports_sync)  # Pull from Remote


func _on_file_submenu_pressed(index: int) -> void:
	match index:
		6:  # Sync to Remote
			if Storage.supports_sync():
				Storage.sync_to_remote("Manual sync from Monologue")
		7:  # Pull from Remote
			if Storage.supports_sync():
				Storage.sync_from_remote()


func _on_edit_submenu_pressed(index: int) -> void:
	match index:
		4:  # Storage Settings
			GlobalSignal.emit("show_storage_settings", [null])
