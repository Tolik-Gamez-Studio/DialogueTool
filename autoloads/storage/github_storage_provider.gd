class_name GitHubStorageProvider extends StorageProvider
## GitHub storage provider using REST API.
## No Git installation required - works via HTTP requests.

var _repo_owner: String = ""
var _repo_name: String = ""
var _branch: String = "main"
var _token: String = ""
var _base_path: String = ""  # Folder in repo for dialogue files
var _http: HTTPRequest
var _pending_callback: Callable


func _init():
	provider_name = "GitHub"
	supports_sync = true


func initialize(config: Dictionary) -> bool:
	_repo_owner = config.get("repo_owner", "")
	_repo_name = config.get("repo_name", "")
	_branch = config.get("branch", "main")
	_token = config.get("token", "")
	_base_path = config.get("base_path", "dialogues")
	
	is_available = not _repo_owner.is_empty() and not _repo_name.is_empty() and not _token.is_empty()
	
	print("[GitHub] Initialize - Owner: %s, Repo: %s, Branch: %s, Path: %s, Available: %s" % [
		_repo_owner, _repo_name, _branch, _base_path, str(is_available)
	])
	
	return is_available


func save_file(path: String, content: String) -> bool:
	# Always save locally first (synchronous)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	else:
		return false
	
	if not is_available:
		operation_completed.emit(true, "Saved locally (GitHub not configured)")
		return true
	
	# Upload to GitHub in background (don't block)
	var filename = path.get_file()
	var github_path = _base_path.path_join(filename) if not _base_path.is_empty() else filename
	_upload_file_background(github_path, content, "Update: " + filename)
	
	return true


func _upload_file_background(file_path: String, content: String, message: String) -> void:
	print("[GitHub] Starting upload: %s to %s/%s" % [file_path, _repo_owner, _repo_name])
	var result = await _upload_file(file_path, content, message)
	if result:
		print("[GitHub] Upload SUCCESS: %s" % file_path)
		operation_completed.emit(true, "Synced to GitHub: " + file_path.get_file())
	else:
		print("[GitHub] Upload FAILED: %s" % file_path)
		operation_completed.emit(false, "GitHub sync failed (saved locally)")


func load_file(path: String) -> String:
	# Load from local file (synchronous)
	# For GitHub paths, use load_file_remote() with await
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
	return false


func list_files(directory: String, extension: String = "") -> Array[String]:
	# Local file listing (synchronous)
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


## List files from GitHub repository
func list_files_remote(extension: String = "") -> Array[String]:
	var files: Array[String] = []
	if not is_available:
		return files
	
	var path = _base_path if not _base_path.is_empty() else ""
	var url = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s" % [_repo_owner, _repo_name, path, _branch]
	
	print("[GitHub] Listing files from: %s" % url)
	
	var headers = [
		"Authorization: Bearer " + _token,
		"Accept: application/vnd.github.v3+json",
		"User-Agent: Monologue-Editor"
	]
	
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return files
	
	var result = await http.request_completed
	http.queue_free()
	
	var response_code = result[1]
	if response_code != 200:
		print("[GitHub] List files error: %d" % response_code)
		return files
	
	var json = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json is Array:
		for item in json:
			if item.get("type") == "file":
				var name = item.get("name", "")
				if extension.is_empty() or name.ends_with(extension):
					# Return as github:// path to indicate remote file
					files.append("github://" + item.get("path", ""))
		print("[GitHub] Found %d files" % files.size())
	
	return files


## Download file content from GitHub
func load_file_remote(github_path: String) -> String:
	if not is_available:
		return ""
	
	# Remove github:// prefix if present
	var path = github_path.replace("github://", "")
	
	var url = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s" % [_repo_owner, _repo_name, path, _branch]
	print("[GitHub] Loading file: %s" % path)
	
	var headers = [
		"Authorization: Bearer " + _token,
		"Accept: application/vnd.github.v3+json",
		"User-Agent: Monologue-Editor"
	]
	
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return ""
	
	var result = await http.request_completed
	http.queue_free()
	
	var response_code = result[1]
	if response_code != 200:
		print("[GitHub] Load file error: %d" % response_code)
		return ""
	
	var json = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json.has("content"):
		# Content is base64 encoded
		var content_base64 = json.get("content", "").replace("\n", "")
		var content = Marshalls.base64_to_raw(content_base64).get_string_from_utf8()
		print("[GitHub] Loaded %d bytes" % content.length())
		return content
	
	return ""


func sync_to_remote(message: String = "") -> bool:
	sync_status_changed.emit("Syncing not needed - files upload on save")
	return true


func sync_from_remote() -> bool:
	if not is_available:
		return false
	sync_status_changed.emit("Pull from GitHub not yet implemented")
	return false


func validate_config(config: Dictionary) -> Dictionary:
	var errors: Array = []
	
	if config.get("repo_owner", "").is_empty():
		errors.append("Repository owner is required (e.g. 'username' or 'organization')")
	if config.get("repo_name", "").is_empty():
		errors.append("Repository name is required")
	if config.get("token", "").is_empty():
		errors.append("Personal Access Token is required")
	
	return {"valid": errors.is_empty(), "errors": errors}


# === GitHub API Methods ===

func _upload_file(file_path: String, content: String, message: String) -> bool:
	print("[GitHub] Getting SHA for: %s" % file_path)
	var sha = await _get_file_sha(file_path)
	print("[GitHub] SHA: %s" % (sha if not sha.is_empty() else "(new file)"))
	
	var url = "https://api.github.com/repos/%s/%s/contents/%s" % [_repo_owner, _repo_name, file_path]
	print("[GitHub] URL: %s" % url)
	
	var headers = [
		"Authorization: Bearer " + _token,
		"Accept: application/vnd.github.v3+json",
		"Content-Type: application/json",
		"User-Agent: Monologue-Editor"
	]
	
	var body = {
		"message": message,
		"content": Marshalls.raw_to_base64(content.to_utf8_buffer()),
		"branch": _branch
	}
	if not sha.is_empty():
		body["sha"] = sha
	
	var json_body = JSON.stringify(body)
	
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_PUT, json_body)
	if error != OK:
		print("[GitHub] HTTP request error: %d" % error)
		http.queue_free()
		return false
	
	var result = await http.request_completed
	http.queue_free()
	
	var response_code = result[1]
	var response_body = result[3].get_string_from_utf8()
	print("[GitHub] Response code: %d" % response_code)
	if response_code != 200 and response_code != 201:
		print("[GitHub] Error response: %s" % response_body)
	
	return response_code == 200 or response_code == 201


func _get_file_sha(file_path: String) -> String:
	var url = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s" % [_repo_owner, _repo_name, file_path, _branch]
	var headers = [
		"Authorization: Bearer " + _token,
		"Accept: application/vnd.github.v3+json",
		"User-Agent: Monologue-Editor"
	]
	
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return ""
	
	var result = await http.request_completed
	http.queue_free()
	
	var response_code = result[1]
	if response_code != 200:
		return ""
	
	var json = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json.has("sha"):
		return json["sha"]
	return ""
