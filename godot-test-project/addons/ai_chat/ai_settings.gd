## AI Settings Resource
## Stores configuration for the AI chat addon.
extends Resource

## URL of the SSH AI Bridge server
@export var bridge_url: String = "http://127.0.0.1:8000"

## Default SSH server hostname
@export var default_host: String = "192.168.0.237"

## Default SSH username
@export var default_username: String = "az"

## Path to SSH private key file
@export var ssh_key_path: String = ""

## Preferred AI CLI ("auto", "claude", "goose")
@export var preferred_ai_cli: String = "auto"

## Enable streaming responses via SSE
@export var stream_responses: bool = true

## Maximum messages to keep in history
@export var max_history_messages: int = 100

## Request timeout in seconds
@export var request_timeout: float = 30.0


func save_settings() -> int:
	## Save settings to user:// directory
	return ResourceSaver.save(self, "user://ai_settings.tres")


static func load_settings() -> Resource:
	## Load settings from user:// directory or create new
	if ResourceLoader.exists("user://ai_settings.tres"):
		var loaded = load("user://ai_settings.tres")
		if loaded != null:
			return loaded
	return load("res://addons/ai_chat/ai_settings.gd").new()


static func delete_settings() -> void:
	## Delete saved settings
	if FileAccess.file_exists("user://ai_settings.tres"):
		DirAccess.remove_absolute("user://ai_settings.tres")
