## nvidia_nim_client.gd - NVIDIA NIM API Client for Fantasy Town
## Part of Fantasy Town World-Breaking Demo
##
## Connects agents to NVIDIA's NIM API with Kimi K2 model.
## This gives agents access to powerful cloud LLM instead of local Ollama.
##
## Models available:
## - moonshotai/kimi-k2-instruct (default)
## - meta/llama-3.1-405b-instruct
## - meta/llama-3.1-70b-instruct
## - mistralai/mixtral-8x7b-instruct-v0.1
## - and more at https://build.nvidia.com
##
## Usage:
##   var client = NvidiaNimClient.new()
##   client.setup("your-api-key")
##   var response = await client.generate("Hello!", "agent_0")

class_name NvidiaNimClient
extends Node

## Signals
signal response_received(agent_id: String, response: String)
signal stream_chunk(agent_id: String, chunk: String)
signal error_occurred(agent_id: String, error: String)
signal api_connected()
signal api_disconnected()

## Configuration
var _api_key: String = ""
var _base_url: String = "https://integrate.api.nvidia.com/v1"
var _default_model: String = "moonshotai/kimi-k2-instruct"
var _is_configured: bool = false

## HTTP clients per agent
var _http_clients: Dictionary = {}

## Request tracking
var _pending_requests: Dictionary = {}
var _request_counter: int = 0

## Available models
const AVAILABLE_MODELS := {
	"kimi-k2": {
		"id": "moonshotai/kimi-k2-instruct",
		"name": "Kimi K2",
		"provider": "Moonshot AI",
		"context_length": 131072,
		"best_for": ["reasoning", "coding", "long_context"]
	},
	"llama-405b": {
		"id": "meta/llama-3.1-405b-instruct",
		"name": "Llama 3.1 405B",
		"provider": "Meta",
		"context_length": 131072,
		"best_for": ["general", "reasoning", "multilingual"]
	},
	"llama-70b": {
		"id": "meta/llama-3.1-70b-instruct",
		"name": "Llama 3.1 70B",
		"provider": "Meta",
		"context_length": 131072,
		"best_for": ["general", "fast", "efficient"]
	},
	"mixtral-8x7b": {
		"id": "mistralai/mixtral-8x7b-instruct-v0.1",
		"name": "Mixtral 8x7B",
		"provider": "Mistral AI",
		"context_length": 32768,
		"best_for": ["fast", "efficient", "multilingual"]
	},
	"deepseek-r1": {
		"id": "deepseek-ai/deepseek-r1",
		"name": "DeepSeek R1",
		"provider": "DeepSeek",
		"context_length": 131072,
		"best_for": ["reasoning", "math", "coding"]
	}
}


func _ready() -> void:
	print("\n" + "═".repeat(60))
	print("  🟢 NVIDIA NIM API CLIENT 🟢")
	print("  'Powered by NVIDIA DGX Cloud'")
	print("═".repeat(60) + "\n")


## Setup with API key
func setup(api_key: String, default_model: String = "") -> void:
	_api_key = api_key
	if not default_model.is_empty():
		_default_model = default_model
	_is_configured = true
	api_connected.emit()
	print("[NvidiaNIM] Configured with model: %s" % _default_model)


## Check if client is ready
func is_ready() -> bool:
	return _is_configured and not _api_key.is_empty()


## Generate a response (non-streaming)
func generate(prompt: String, agent_id: String = "default", model: String = "", temperature: float = 0.6, max_tokens: int = 4096) -> void:
	if not is_ready():
		error_occurred.emit(agent_id, "NVIDIA NIM client not configured")
		return

	var use_model = model if not model.is_empty() else _default_model
	var request_id = _create_request_id(agent_id)

	# Create HTTP client
	var http = HTTPRequest.new()
	http.name = "HTTP_%s" % request_id
	add_child(http)
	_http_clients[request_id] = http

	# Build request
	var body = {
		"model": use_model,
		"messages": [
			{"role": "user", "content": prompt}
		],
		"temperature": temperature,
		"top_p": 0.9,
		"max_tokens": max_tokens,
		"stream": false
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key
	]

	var json_string = JSON.stringify(body)
	var url = _base_url + "/chat/completions"

	print("[NvidiaNIM] → Agent %s: Generating response..." % agent_id)

	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		error_occurred.emit(agent_id, "HTTP request failed: %d" % error)
		return

	# Connect response handler
	http.request_completed.connect(_on_generate_response.bind(request_id, agent_id))


## Generate with system prompt
func generate_with_system(system_prompt: String, user_prompt: String, agent_id: String = "default", model: String = "", temperature: float = 0.6, max_tokens: int = 4096) -> void:
	if not is_ready():
		error_occurred.emit(agent_id, "NVIDIA NIM client not configured")
		return

	var use_model = model if not model.is_empty() else _default_model
	var request_id = _create_request_id(agent_id)

	var http = HTTPRequest.new()
	http.name = "HTTP_%s" % request_id
	add_child(http)
	_http_clients[request_id] = http

	var body = {
		"model": use_model,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt}
		],
		"temperature": temperature,
		"top_p": 0.9,
		"max_tokens": max_tokens,
		"stream": false
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key
	]

	var json_string = JSON.stringify(body)
	var url = _base_url + "/chat/completions"

	print("[NvidiaNIM] → Agent %s: Generating with system prompt..." % agent_id)

	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		error_occurred.emit(agent_id, "HTTP request failed: %d" % error)
		return

	http.request_completed.connect(_on_generate_response.bind(request_id, agent_id))


## Generate streaming response
func generate_stream(prompt: String, agent_id: String = "default", model: String = "", temperature: float = 0.6, max_tokens: int = 4096) -> void:
	if not is_ready():
		error_occurred.emit(agent_id, "NVIDIA NIM client not configured")
		return

	# Note: Godot HTTPRequest doesn't support true streaming
	# We'll use non-streaming for now and emit the full response
	# For true streaming, would need HTTPClient directly
	generate(prompt, agent_id, model, temperature, max_tokens)


## Handle generate response
func _on_generate_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, agent_id: String) -> void:
	_cleanup_request(request_id)

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "Request failed: result=%d, code=%d" % [result, response_code]
		print("[NvidiaNIM] ❌ %s" % error_msg)
		error_occurred.emit(agent_id, error_msg)
		return

	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		error_occurred.emit(agent_id, "JSON parse error")
		return

	var response_data = json.data

	# Check for API error
	if response_data.has("error"):
		var error_msg = response_data.error.get("message", "Unknown API error")
		print("[NvidiaNIM] ❌ API Error: %s" % error_msg)
		error_occurred.emit(agent_id, error_msg)
		return

	# Extract response content
	var content = ""
	if response_data.has("choices") and response_data.choices.size() > 0:
		var choice = response_data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			content = choice.message.content

	# Extract usage info
	var usage = response_data.get("usage", {})

	print("[NvidiaNIM] ← Agent %s: Received %d chars (tokens: %d)" % [
		agent_id, content.length(), usage.get("completion_tokens", 0)
	])

	response_received.emit(agent_id, content)


## Chat with conversation history
func chat(messages: Array, agent_id: String = "default", model: String = "", temperature: float = 0.6, max_tokens: int = 4096) -> void:
	if not is_ready():
		error_occurred.emit(agent_id, "NVIDIA NIM client not configured")
		return

	var use_model = model if not model.is_empty() else _default_model
	var request_id = _create_request_id(agent_id)

	var http = HTTPRequest.new()
	http.name = "HTTP_%s" % request_id
	add_child(http)
	_http_clients[request_id] = http

	var body = {
		"model": use_model,
		"messages": messages,
		"temperature": temperature,
		"top_p": 0.9,
		"max_tokens": max_tokens,
		"stream": false
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key
	]

	var json_string = JSON.stringify(body)
	var url = _base_url + "/chat/completions"

	print("[NvidiaNIM] → Agent %s: Chat with %d messages" % [agent_id, messages.size()])

	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		error_occurred.emit(agent_id, "HTTP request failed: %d" % error)
		return

	http.request_completed.connect(_on_generate_response.bind(request_id, agent_id))


## Get available models
func get_available_models() -> Dictionary:
	return AVAILABLE_MODELS.duplicate()


## Get model info
func get_model_info(model_key: String) -> Dictionary:
	return AVAILABLE_MODELS.get(model_key, {})


## Set default model
func set_default_model(model_key: String) -> bool:
	if AVAILABLE_MODELS.has(model_key):
		_default_model = AVAILABLE_MODELS[model_key].id
		print("[NvidiaNIM] Default model set to: %s" % _default_model)
		return true
	elif model_key.contains("/"):
		# Direct model ID
		_default_model = model_key
		print("[NvidiaNIM] Default model set to: %s" % _default_model)
		return true
	return false


## Create request ID
func _create_request_id(agent_id: String) -> String:
	_request_counter += 1
	var request_id = "%s_%d" % [agent_id, _request_counter]
	_pending_requests[request_id] = {
		"agent_id": agent_id,
		"start_time": Time.get_unix_time_from_system()
	}
	return request_id


## Cleanup request
func _cleanup_request(request_id: String) -> void:
	if _http_clients.has(request_id):
		var http = _http_clients[request_id]
		http.queue_free()
		_http_clients.erase(request_id)
	_pending_requests.erase(request_id)


## Test API connection
func test_connection() -> void:
	if not is_ready():
		error_occurred.emit("test", "Not configured")
		return

	generate("Say 'Hello from NVIDIA NIM!' in exactly 5 words.", "test")


## Cleanup
func _exit_tree() -> void:
	for request_id in _http_clients.keys():
		_cleanup_request(request_id)
	api_disconnected.emit()
