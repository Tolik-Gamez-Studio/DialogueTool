class_name StorageProvider extends RefCounted
## Base class for file storage providers.
## Implement this to add support for different storage backends (local, Git, cloud, etc.)

signal operation_completed(success: bool, message: String)
signal sync_status_changed(status: String)

enum StorageType {
	LOCAL,
	GIT,
	GITHUB_API,
	GITLAB_API,
	SVN
}

## Human-readable name of this storage provider
var provider_name: String = "Base Provider"

## Whether this provider supports remote synchronization
var supports_sync: bool = false

## Whether this provider is currently connected/available
var is_available: bool = true


## Initialize the storage provider with configuration
func initialize(config: Dictionary) -> bool:
	push_error("StorageProvider.initialize() must be overridden")
	return false


## Save content to a file path
func save_file(path: String, content: String) -> bool:
	push_error("StorageProvider.save_file() must be overridden")
	return false


## Load content from a file path
func load_file(path: String) -> String:
	push_error("StorageProvider.load_file() must be overridden")
	return ""


## Check if a file exists
func file_exists(path: String) -> bool:
	push_error("StorageProvider.file_exists() must be overridden")
	return false


## Delete a file
func delete_file(path: String) -> bool:
	push_error("StorageProvider.delete_file() must be overridden")
	return false


## List files in a directory (optionally filtered by extension)
func list_files(directory: String, extension: String = "") -> Array[String]:
	push_error("StorageProvider.list_files() must be overridden")
	return []


## Synchronize local changes with remote (push)
func sync_to_remote(message: String = "") -> bool:
	if not supports_sync:
		return true  # No sync needed for local-only providers
	push_error("StorageProvider.sync_to_remote() must be overridden")
	return false


## Synchronize remote changes to local (pull)
func sync_from_remote() -> bool:
	if not supports_sync:
		return true  # No sync needed for local-only providers
	push_error("StorageProvider.sync_from_remote() must be overridden")
	return false


## Get the current sync status
func get_sync_status() -> Dictionary:
	return {
		"connected": is_available,
		"pending_changes": 0,
		"last_sync": "",
		"message": ""
	}


## Validate configuration before use
func validate_config(config: Dictionary) -> Dictionary:
	return {"valid": true, "errors": []}
