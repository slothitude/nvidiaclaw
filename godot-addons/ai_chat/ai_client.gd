## AI Client
## HTTP client for communicating with the SSH AI Bridge.
class_name AIClient
extends RefCounted

## Emitted when connected to a server
signal connected(session_id: String, ai_cli: String)

## Emitted when disconnected from server
signal disconnected()

## Emitted when a complete message is received
signal message_received(data: Dictionary)

## Emitted for each chunk of a streaming response
signal stream_chunk(chunk: Dictionary)

## Emitted when an error occurs
signal error_occurred(error: String)

## Emitted when server info is received
signal server_info_received(info: Dictionary)

## Base URL for the API
var base_url: String = "http://localhost:8000"

## Current session ID
var session_id: String = ""

## Detected AI CLI type
var ai_cli: String = ""

## Settings reference
var _settings: AISettings

## HTTP request timeout
var _timeout: float = 30.0


func _init(settings: AISettings = null) -> void:
	if settings:
		_settings = settings
		base_url = settings.bridge_url
		_timeout = settings.request_timeout
	else:
		_settings = AISettings.new()


## Connect to an SSH server
func connect_to_server(host: String, username: String, ssh_key: String = "", password: String = "", ai_cli_pref: String = "auto") -> void:
	var http = _create_http_request()
	http.request_completed.connect(_on_connect_completed)

	var body := {
		"host": host,
		"username": username,
		"ai_cli": ai_cli_pref,
		"port": 22
	}

	if not ssh_key.is_empty():
		body["ssh_key"] = _encode_base64(ssh_key)
	elif not password.is_empty():
		body["password"] = password

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var url = base_url + "/api/v1/connect"

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		error_occurred.emit("Failed to create connection request: %d" % err)


## Disconnect from the current server
func disconnect_from_server() -> void:
	if session_id.is_empty():
		return

	var http = _create_http_request()
	http.request_completed.connect(_on_disconnect_completed)

	var url = base_url + "/api/v1/disconnect?session_id=%s" % session_id.uri_encode()
	http.request(url, [], HTTPClient.METHOD_POST)


## Send a message to the AI (non-streaming)
func send_message(message: String, context_files: Array = []) -> void:
	if session_id.is_empty():
		error_occurred.emit("Not connected to any server")
		return

	var http = _create_http_request()
	http.request_completed.connect(_on_message_completed)

	var body := {
		"session_id": session_id,
		"message": message
	}

	if not context_files.is_empty():
		body["context_files"] = context_files

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var url = base_url + "/api/v1/chat"

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		error_occurred.emit("Failed to send message: %d" % err)


## Send a message and stream the response
func stream_message(message: String, context_files: Array = []) -> void:
	if session_id.is_empty():
		error_occurred.emit("Not connected to any server")
		return

	var http = _create_http_request()
	http.request_completed.connect(_on_stream_completed)

	var url = base_url + "/api/v1/chat/stream?session_id=%s&message=%s" % [session_id.uri_encode(), message.uri_encode()]

	if not context_files.is_empty():
		url += "&context_files=" + ",".join(context_files).uri_encode()

	var err = http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		error_occurred.emit("Failed to start stream: %d" % err)


## Check bridge health
func check_health(callback: Callable) -> void:
	var http = _create_http_request()

	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var json = JSON.parse_string(body.get_string_from_utf8())
		var healthy = json.get("status", "") == "healthy"
		callback.call(healthy)
	)

	var url = base_url + "/api/v1/health"
	http.request(url, [], HTTPClient.METHOD_GET)


# === HTTP Request Factory ===

func _create_http_request() -> HTTPRequest:
	var http = HTTPRequest.new()
	http.timeout = _timeout
	return http


# === JSON Helpers ===

func _parse_json_response(body: PackedByteArray) -> Dictionary:
	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		return {"error": "Failed to parse JSON response"}
	return json.data


func _parse_sse_chunks(body: PackedByteArray) -> Array[Dictionary]:
	var text = body.get_string_from_utf8()
	var chunks: Array[Dictionary] = []

	for line in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("data:"):
			var json_text = line.substr(6)  # Remove "data:" prefix
			var json = JSON.new()
			if json.parse(json_text) == OK:
				chunks.append(json.data)

	return chunks


func _encode_base64(text: String) -> String:
	var buffer = PackedByteArray()
	buffer.resize(text.length())
	for i in range(text.length()):
		buffer[i] = text.ord_at(i)
	return Marshalls.raw_to_base64(buffer)


# === Signal Handlers ===

func _on_connect_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data = _parse_json_response(body)
		session_id = data.get("session_id", "")
		ai_cli = data.get("ai_cli_detected", "")
		connected.emit(session_id, ai_cli)

		if data.has("server_info"):
			server_info_received.emit({"info": data.server_info})
	else:
		var error_msg = "Connection failed"
		var data = _parse_json_response(body)
		if data.has("detail"):
			error_msg = data.detail
		error_occurred.emit(error_msg)


func _on_disconnect_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	session_id = ""
	ai_cli = ""
	disconnected.emit()


func _on_message_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data = _parse_json_response(body)
		message_received.emit(data)
	else:
		var error_msg = "Message failed"
		var data = _parse_json_response(body)
		if data.has("detail"):
			error_msg = data.detail
		error_occurred.emit(error_msg)


func _on_stream_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var chunks = _parse_sse_chunks(body)
		for chunk in chunks:
			stream_chunk.emit(chunk)
		# Emit final message with complete status
		message_received.emit({"status": "complete"})
	else:
		var error_msg = "Stream failed"
		var data = _parse_json_response(body)
		if data.has("detail"):
			error_msg = data.detail
		error_occurred.emit(error_msg)
