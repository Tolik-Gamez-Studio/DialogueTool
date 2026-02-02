extends Node
## Global storage manager that handles file operations through configurable storage providers.
## This autoload provides a unified interface for saving/loading dialogue files.

signal provider_changed(provider: StorageProvider)
signal sync_completed(success: bool)
signal sync_status_changed(status: String)

const STORAGE_CONFIG_PATH = "user://storage_config.cfg"

var current_provider: StorageProvider
var _config: ConfigFile = ConfigFile.new()

# Available provider types
var _providers: Dictionary = {
	StorageProvider.StorageType.LOCAL: LocalStorageProvider,
	StorageProvider.StorageType.GITHUB_API: GitHubStorageProvider,
}


func _ready():
	_load_config()
	_initialize_provider()


func _load_config():
	var err = _config.load(STORAGE_CONFIG_PATH)
	if err != OK:
		# First run - try to load defaults from external JSON file
		_load_defaults_from_external_file()
		_save_config()


## Get path to external config file (next to .exe or project root)
func _get_external_config_path() -> String:
	if OS.has_feature("editor"):
		# In editor - use project root
		return ProjectSettings.globalize_path("res://storage_config.json")
	else:
		# Exported - use folder next to executable
		return OS.get_executable_path().get_base_dir().path_join("storage_config.json")


## Load default settings from external storage_config.json
func _load_defaults_from_external_file():
	var config_path = _get_external_config_path()
	print("[Storage] Looking for config at: %s" % config_path)
	
	var defaults = _read_external_config(config_path)
	
	# Determine storage type
	var storage_type_str = defaults.get("storage_type", "local")
	var storage_type = StorageProvider.StorageType.LOCAL
	if storage_type_str == "github":
		storage_type = StorageProvider.StorageType.GITHUB_API
	
	# Get GitHub settings
	var github = defaults.get("github", {})
	var repo_owner = github.get("repo_owner", "")
	var repo_name = github.get("repo_name", "")
	var branch = github.get("branch", "main")
	var token = github.get("token", "")
	var base_path = github.get("base_path", "dialogues")
	
	# Only use GitHub if configured
	if storage_type == StorageProvider.StorageType.GITHUB_API:
		if repo_owner.is_empty() or token.is_empty():
			storage_type = StorageProvider.StorageType.LOCAL
			print("[Storage] GitHub not fully configured, falling back to Local")
	
	_config.set_value("storage", "type", storage_type)
	_config.set_value("github", "repo_owner", repo_owner)
	_config.set_value("github", "repo_name", repo_name)
	_config.set_value("github", "branch", branch)
	_config.set_value("github", "token", token)
	_config.set_value("github", "base_path", base_path)
	
	print("[Storage] Loaded config: type=%s, owner=%s, repo=%s" % [storage_type_str, repo_owner, repo_name])


## Read external JSON config file
func _read_external_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("[Storage] No config file found at: %s" % path)
		print("[Storage] Create storage_config.json next to the executable with your settings")
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[Storage] Cannot open config file: %s" % path)
		return {}
	
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(text)
	if json is Dictionary:
		print("[Storage] Config loaded successfully")
		return json
	
	print("[Storage] Invalid JSON in config file")
	return {}


func _save_config():
	_config.save(STORAGE_CONFIG_PATH)


func _initialize_provider():
	var provider_type = _config.get_value("storage", "type", StorageProvider.StorageType.LOCAL)
	set_provider_type(provider_type)


## Set the storage provider type
func set_provider_type(type: StorageProvider.StorageType) -> bool:
	var provider_class = _providers.get(type)
	if provider_class == null:
		push_error("Unknown storage provider type: %d" % type)
		return false
	
	var provider = provider_class.new()
	var config = _get_provider_config(type)
	
	if provider.initialize(config):
		current_provider = provider
		current_provider.sync_status_changed.connect(_on_sync_status_changed)
		_config.set_value("storage", "type", type)
		_save_config()
		provider_changed.emit(current_provider)
		print("[Storage] Provider set to: %s" % provider.provider_name)
		return true
	else:
		push_error("Failed to initialize storage provider: %s" % provider.provider_name)
		# Fallback to local storage
		if type != StorageProvider.StorageType.LOCAL:
			return set_provider_type(StorageProvider.StorageType.LOCAL)
		return false


func _get_provider_config(type: StorageProvider.StorageType) -> Dictionary:
	match type:
		StorageProvider.StorageType.LOCAL:
			return {}
		StorageProvider.StorageType.GITHUB_API:
			return {
				"repo_owner": _config.get_value("github", "repo_owner", ""),
				"repo_name": _config.get_value("github", "repo_name", ""),
				"branch": _config.get_value("github", "branch", "main"),
				"token": _config.get_value("github", "token", ""),
				"base_path": _config.get_value("github", "base_path", "dialogues"),
			}
	return {}


## Get the current provider type
func get_provider_type() -> StorageProvider.StorageType:
	return _config.get_value("storage", "type", StorageProvider.StorageType.LOCAL)


## Save a file using the current provider
func save_file(path: String, content: String) -> bool:
	if current_provider:
		return current_provider.save_file(path, content)
	return false


## Load a file using the current provider (synchronous for local files)
func load_file(path: String) -> String:
	if current_provider:
		return current_provider.load_file(path)
	return ""


## Load a file from GitHub (async) - use for github:// paths
func load_file_async(path: String) -> String:
	if current_provider and path.begins_with("github://"):
		if current_provider is GitHubStorageProvider:
			return await current_provider.load_file_remote(path)
	return load_file(path)


## List files from remote repository (GitHub)
func list_remote_files(extension: String = ".json") -> Array[String]:
	if current_provider is GitHubStorageProvider:
		return await current_provider.list_files_remote(extension)
	return []


## Check if current provider supports remote file listing
func supports_remote_files() -> bool:
	return current_provider is GitHubStorageProvider and current_provider.is_available


## Check if a file exists
func file_exists(path: String) -> bool:
	if current_provider:
		return current_provider.file_exists(path)
	return false


## Delete a file (async for remote files)
func delete_file(path: String) -> bool:
	if current_provider:
		return await current_provider.delete_file(path)
	return false


## Sync changes to remote (push)
func sync_to_remote(message: String = "") -> bool:
	if current_provider and current_provider.supports_sync:
		var result = current_provider.sync_to_remote(message)
		sync_completed.emit(result)
		return result
	return true


## Sync changes from remote (pull)
func sync_from_remote() -> bool:
	if current_provider and current_provider.supports_sync:
		var result = current_provider.sync_from_remote()
		sync_completed.emit(result)
		return result
	return true


## Get sync status
func get_sync_status() -> Dictionary:
	if current_provider:
		return current_provider.get_sync_status()
	return {}


## Check if current provider supports sync
func supports_sync() -> bool:
	return current_provider != null and current_provider.supports_sync


## Update GitHub configuration
func update_github_config(config: Dictionary) -> bool:
	for key in config:
		_config.set_value("github", key, config[key])
	_save_config()
	
	# Re-initialize if GitHub is the current provider
	if get_provider_type() == StorageProvider.StorageType.GITHUB_API:
		return set_provider_type(StorageProvider.StorageType.GITHUB_API)
	return true


## Get GitHub configuration
func get_github_config() -> Dictionary:
	return {
		"repo_owner": _config.get_value("github", "repo_owner", ""),
		"repo_name": _config.get_value("github", "repo_name", ""),
		"branch": _config.get_value("github", "branch", "main"),
		"token": _config.get_value("github", "token", ""),
		"base_path": _config.get_value("github", "base_path", "dialogues"),
	}


## Validate GitHub configuration
func validate_github_config(config: Dictionary) -> Dictionary:
	var provider = GitHubStorageProvider.new()
	return provider.validate_config(config)


func _on_sync_status_changed(status: String):
	sync_status_changed.emit(status)
