## AI Chat
## Main autoload singleton for the AI chat system.
## Add this as an autoload in Project Settings.
extends Node

## Emitted when connection status changes
signal connection_changed(connected: bool)

## Emitted when a new message is added to history
signal message_added(role: String, content: String)

## Emitted when streaming chunk is received
signal stream_update(chunk: Dictionary)

## Emitted on errors
signal chat_error(message: String)

## Current settings
var settings: AISettings

## Chat history
var history: ChatHistory

## AI client instance
var client: AIClient

## Current connection state
var is_connected: bool = false:
	set(value):
		if is_connected != value:
			is_connected = value
			connection_changed.emit(value)

## Current streaming message (for UI updates)
var _current_stream_content: String = ""


func _ready() -> void:
	# Load settings
	settings = AISettings.load_settings()

	# Initialize history
	history = ChatHistory.new()
	history.max_messages = settings.max_history_messages

	# Create client
	client = AIClient.new(settings)

	# Connect client signals
	client.connected.connect(_on_client_connected)
	client.disconnected.connect(_on_client_disconnected)
	client.message_received.connect(_on_message_received)
	client.stream_chunk.connect(_on_stream_chunk)
	client.error_occurred.connect(_on_client_error)


## Connect to an SSH server with stored settings
func connect_with_defaults() -> void:
	if settings.default_host.is_empty():
		chat_error.emit("No default server configured")
		return

	var key := ""
	if not settings.ssh_key_path.is_empty():
		var file = FileAccess.open(settings.ssh_key_path, FileAccess.READ)
		if file:
			key = file.get_as_text()

	client.connect_to_server(
		settings.default_host,
		settings.default_username,
		key,
		"",
		settings.preferred_ai_cli
	)


## Connect to a specific server
func connect_to_server(host: String, username: String, ssh_key: String = "", password: String = "") -> void:
	client.connect_to_server(host, username, ssh_key, password, settings.preferred_ai_cli)


## Disconnect from current server
func disconnect_from_server() -> void:
	client.disconnect_from_server()


## Send a message to the AI
func send_message(message: String, context_files: Array = []) -> void:
	if not is_connected:
		chat_error.emit("Not connected to any server")
		return

	# Add user message to history
	history.add_user_message(message)
	message_added.emit("user", message)

	# Clear stream content for new message
	_current_stream_content = ""

	if settings.stream_responses:
		client.stream_message(message, context_files)
	else:
		client.send_message(message, context_files)


## Clear chat history
func clear_history() -> void:
	history.clear()


## Save settings
func save_settings() -> void:
	settings.save_settings()


## Load settings
func reload_settings() -> void:
	settings = AISettings.load_settings()
	client._settings = settings
	client.base_url = settings.bridge_url
	client._timeout = settings.request_timeout
	history.max_messages = settings.max_history_messages


## Check if bridge is healthy
func check_bridge_health(callback: Callable) -> void:
	client.check_health(callback)


## Get current session info
func get_session_info() -> Dictionary:
	return {
		"connected": is_connected,
		"session_id": client.session_id,
		"ai_cli": client.ai_cli,
		"host": settings.default_host,
		"username": settings.default_username
	}


# === Signal Handlers ===


func _on_client_connected(session_id: String, ai_cli: String) -> void:
	is_connected = true


func _on_client_disconnected() -> void:
	is_connected = false


func _on_message_received(data: Dictionary) -> void:
	var response = data.get("response", "")
	if not response.is_empty():
		# Add complete response to history
		history.add_assistant_message(response)
		message_added.emit("assistant", response)


func _on_stream_chunk(chunk: Dictionary) -> void:
	var chunk_type = chunk.get("type", "")

	match chunk_type:
		"thinking":
			stream_update.emit(chunk)
		"text":
			var content = chunk.get("content", "")
			_current_stream_content += content
			stream_update.emit(chunk)
		"tool_use":
			stream_update.emit(chunk)
		"complete":
			# Add accumulated stream content to history
			if not _current_stream_content.is_empty():
				history.add_assistant_message(_current_stream_content)
				message_added.emit("assistant", _current_stream_content)
			_current_stream_content = ""
		"error":
			var error_msg = chunk.get("content", "Unknown error")
			chat_error.emit(error_msg)
		"prompt":
			# Interactive prompt - emit for UI to handle
			stream_update.emit(chunk)


func _on_client_error(error: String) -> void:
	chat_error.emit(error)
