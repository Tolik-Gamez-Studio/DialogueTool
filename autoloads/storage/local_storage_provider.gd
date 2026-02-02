class_name LocalStorageProvider extends StorageProvider
## Local file system storage provider.
## This is the default provider that saves files directly to disk.


func _init():
	provider_name = "Local Storage"
	supports_sync = false
	is_available = true


func initialize(_config: Dictionary) -> bool:
	return true


func save_file(path: String, content: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		operation_completed.emit(true, "File saved: %s" % path)
		return true
	else:
		var error = FileAccess.get_open_error()
		operation_completed.emit(false, "Failed to save file: %s (Error: %d)" % [path, error])
		return false


func load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	return ""


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func delete_file(path: String) -> bool:
	var dir = DirAccess.open(path.get_base_dir())
	if dir:
		var error = dir.remove(path.get_file())
		if error == OK:
			operation_completed.emit(true, "File deleted: %s" % path)
			return true
	operation_completed.emit(false, "Failed to delete file: %s" % path)
	return false


func list_files(directory: String, extension: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if extension.is_empty() or file_name.ends_with(extension):
					files.append(directory.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


func validate_config(config: Dictionary) -> Dictionary:
	return {"valid": true, "errors": []}
