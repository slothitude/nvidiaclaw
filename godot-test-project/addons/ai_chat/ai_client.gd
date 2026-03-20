## AI Client
## HTTP client for communicating with the SSH AI Bridge.
extends RefCounted

# Preload dependencies
const AISettingsScript = preload("res://addons/ai_chat/ai_settings.gd")

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
var base_url: String = "http://127.0.0.1:8000"

## Current session ID
var session_id: String = ""

## Detected AI CLI type
var ai_cli: String = ""

## Settings reference
var _settings: Resource

## HTTP request timeout
var _timeout: float = 30.0

## Parent node for HTTP requests (must be set for requests to work)
var _parent_node: Node = null

## Keep reference to HTTP request to prevent garbage collection
var _current_http: HTTPRequest = null

## Debug counter for tracking requests
var _request_count: int = 0


func _init(settings: Resource = null, parent_node: Node = null) -> void:
	print("[AIClient] _init called")
	print("[AIClient] parent_node: ", parent_node)
	if settings:
		_settings = settings
		base_url = settings.bridge_url
		_timeout = settings.request_timeout
	else:
		_settings = AISettingsScript.new()
	_parent_node = parent_node
	print("[AIClient] base_url set to: ", base_url)


## Connect to an SSH server
func connect_to_server(host: String, username: String, ssh_key: String = "", password: String = "", ai_cli_pref: String = "auto") -> void:
	_request_count += 1
	var req_id = _request_count
	print("[AIClient #", req_id, "] connect_to_server called")
	print("[AIClient #", req_id, "] base_url: ", base_url)
	print("[AIClient #", req_id, "] parent_node: ", _parent_node)
	print("[AIClient #", req_id, "] parent_node is valid: ", is_instance_valid(_parent_node))

	# Defer to ensure scene tree is ready
	_do_connect.call_deferred(host, username, ssh_key, password, ai_cli_pref, req_id)
	print("[AIClient #", req_id, "] deferred call scheduled")

func _do_connect(host: String, username: String, ssh_key: String, password: String, ai_cli_pref: String, req_id: int) -> void:
	print("[AIClient #", req_id, "] _do_connect executing (deferred)")
	print("[AIClient #", req_id, "] parent_node is valid now: ", is_instance_valid(_parent_node))

	_current_http = _create_http_request()
	if _current_http == null:
		print("[AIClient #", req_id, "] ERROR: HTTPRequest is null!")
		error_occurred.emit("Failed to create HTTP request")
		return

	print("[AIClient #", req_id, "] HTTPRequest created: ", _current_http)
	print("[AIClient #", req_id, "] HTTPRequest is_inside_tree: ", _current_http.is_inside_tree())
	print("[AIClient #", req_id, "] HTTPRequest get_tree(): ", _current_http.get_tree())

	# Store request ID for tracking
	_current_http.set_meta("request_id", req_id)

	var err = _current_http.request_completed.connect(_on_connect_completed)
	print("[AIClient #", req_id, "] Signal connect result: ", err)

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

	print("[AIClient #", req_id, "] Sending request to: ", url)
	print("[AIClient #", req_id, "] Body length: ", json_body.length())

	var request_err = _current_http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	print("[AIClient #", req_id, "] Request result: ", request_err, " (0=OK)")
	if request_err != OK:
		error_occurred.emit("Failed to create connection request: %d" % request_err)
	else:
		print("[AIClient #", req_id, "] Request sent successfully, waiting for response...")


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
	# HTTPRequest must be in scene tree to work
	if _parent_node == null:
		push_error("[AIClient] parent_node is null! HTTP requests won't work!")
		return null
	_parent_node.add_child(http)
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
	var buffer = text.to_utf8_buffer()
	return Marshalls.raw_to_base64(buffer)


# === Signal Handlers ===

func _on_connect_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var req_id = "unknown"
	if _current_http and _current_http.has_meta("request_id"):
		req_id = str(_current_http.get_meta("request_id"))

	print("[AIClient #", req_id, "] ========== RESPONSE RECEIVED ==========")
	print("[AIClient #", req_id, "] result: ", result, " (0=OK, 1=NO_RESPONSE, 2=PARTIAL)")
	print("[AIClient #", req_id, "] response_code: ", response_code)

	var body_text = body.get_string_from_utf8()
	print("[AIClient #", req_id, "] body length: ", body_text.length())
	print("[AIClient #", req_id, "] body preview: ", body_text.left(200))

	if response_code == 200:
		var data = _parse_json_response(body)
		session_id = data.get("session_id", "")
		ai_cli = data.get("ai_cli_detected", "")
		print("[AIClient #", req_id, "] SUCCESS! session_id: ", session_id)
		connected.emit(session_id, ai_cli)

		if data.has("server_info"):
			server_info_received.emit({"info": data.server_info})
	else:
		var error_msg = "Connection failed"
		var data = _parse_json_response(body)
		if data.has("detail"):
			error_msg = data.detail
		print("[AIClient #", req_id, "] ERROR: ", error_msg)
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
