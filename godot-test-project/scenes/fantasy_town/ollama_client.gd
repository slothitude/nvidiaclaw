## ollama_client.gd - Ollama API Client for AI-Generated Thoughts
## Part of Fantasy Town World-Breaking Demo
##
## Connects to local Ollama server to generate contextual thoughts
## for agents based on their soul (personality) and current state.
## Supports batch requests for 100+ agents and SearXNG web search.

class_name OllamaClient
extends Node

## Configuration
const OLLAMA_URL := "http://localhost:11434"
const SEARXNG_URL := "http://localhost:8080"
const DEFAULT_MODEL := "llama3.2"
const REQUEST_TIMEOUT := 30.0  # seconds - increased for Ollama
const BATCH_SIZE := 10  # Process 10 agents at a time
const BATCH_INTERVAL := 0.5  # Seconds between batches

## Signals
signal thought_generated(agent_id: String, thought: String)
signal request_failed(agent_id: String, error: String)
signal search_completed(agent_id: String, results: Array)

## State
var _model: String = DEFAULT_MODEL
var _is_available: bool = false
var _pending_requests: Dictionary = {}  # agent_id -> HTTPRequest
var _rate_limit_ms: int = 100  # Reduced for batch processing
var _last_request_time: Dictionary = {}  # agent_id -> timestamp

## Batch processing
var _batch_queue: Array = []  # Pending thought requests
var _batch_timer: float = 0.0
var _is_processing_batch: bool = false
var _search_enabled: bool = false

## Fallback thoughts (used when Ollama unavailable)
const FALLBACK_THOUGHTS := [
	"What a lovely day to explore!",
	"I wonder what's behind that building...",
	"The town feels so alive today!",
	"Maybe I'll find something interesting here.",
	"Hop, hop, hop... where should I go next?",
	"I love this little town.",
	"Is that another friend over there?",
	"The sunshine feels nice on my fur.",
	"I feel like having an adventure!",
	"This place has such nice energy.",
	"I could hop around here all day!",
	"Time to make some new friends!",
	"I sense something exciting nearby...",
	"Every corner holds a new discovery!",
	"Life is good in Fantasy Town."
]


func _ready() -> void:
	_check_availability()


## Check if Ollama server is running
func _check_availability() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_availability_check)

	var url = OLLAMA_URL + "/api/tags"
	var error = http.request(url, [], HTTPClient.METHOD_GET)

	if error != OK:
		_is_available = false
		push_warning("[OllamaClient] Failed to check availability: %s" % error)


func _on_availability_check(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		_is_available = true
		print("[OllamaClient] Connected to Ollama server")
		_ensure_model()
	else:
		_is_available = false
		push_warning("[OllamaClient] Ollama server not available, using fallback thoughts")


## Ensure the model is pulled
func _ensure_model() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_model_check)

	var url = OLLAMA_URL + "/api/tags"
	var error = http.request(url, [], HTTPClient.METHOD_GET)


func _on_model_check(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	var models = json.data.get("models", [])
	for model in models:
		if model.get("name", "").begins_with(_model):
			print("[OllamaClient] Model %s is available" % _model)
			return

	# Model not found, try to pull
	print("[OllamaClient] Model %s not found, attempting to pull..." % _model)
	_pull_model()


func _pull_model() -> void:
	var http = HTTPRequest.new()
	http.timeout = 120.0  # Model pull can take a while
	add_child(http)
	http.request_completed.connect(_on_model_pulled)

	var url = OLLAMA_URL + "/api/pull"
	var body = JSON.stringify({"name": _model})
	var error = http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

	if error != OK:
		push_warning("[OllamaClient] Failed to pull model: %s" % error)


func _on_model_pulled(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		print("[OllamaClient] Model %s pulled successfully" % _model)
	else:
		push_warning("[OllamaClient] Failed to pull model %s" % _model)


## Generate a thought for an agent
func generate_thought(agent_id: String, soul_data: Dictionary, context: Dictionary) -> void:
	# Rate limiting
	var now = Time.get_ticks_msec()
	var last_time = _last_request_time.get(agent_id, 0)
	if now - last_time < _rate_limit_ms:
		print("[OllamaClient] Rate limited agent %s" % agent_id)
		return

	_last_request_time[agent_id] = now

	# If Ollama unavailable, use fallback
	if not _is_available:
		print("[OllamaClient] Ollama not available, using fallback for %s" % agent_id)
		_emit_fallback_thought(agent_id)
		return

	# Cancel any pending request for this agent
	if _pending_requests.has(agent_id):
		var old_http = _pending_requests[agent_id]
		old_http.cancel_request()
		old_http.queue_free()

	# Build the prompt
	var prompt = _build_thought_prompt(soul_data, context)

	# Create HTTP request
	var http = HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_thought_response.bind(agent_id))

	_pending_requests[agent_id] = http

	# Send request
	var url = OLLAMA_URL + "/api/generate"
	var body = JSON.stringify({
		"model": _model,
		"prompt": prompt,
		"stream": false,
		"options": {
			"temperature": 0.8,
			"top_p": 0.9,
			"num_predict": 50
		}
	})

	var error = http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		print("[OllamaClient] HTTP request failed for %s: error %s" % [agent_id, error])
		_pending_requests.erase(agent_id)
		_emit_fallback_thought(agent_id)
	else:
		print("[OllamaClient] Sent request for %s" % agent_id)


## Build a prompt for thought generation
func _build_thought_prompt(soul_data: Dictionary, context: Dictionary) -> String:
	var personality = soul_data.get("personality", "a curious explorer")
	var speech_style = soul_data.get("speech_style", "friendly and casual")
	var mood = soul_data.get("mood", {})
	var memories = soul_data.get("memories", [])

	var happiness = mood.get("happiness", 0.5)
	var energy = mood.get("energy", 0.5)
	var curiosity = mood.get("curiosity", 0.5)

	var current_goal = context.get("current_goal", "exploring")
	var nearby_objects = context.get("nearby_objects", [])
	var position = context.get("position", Vector3.ZERO)

	# Build context description
	var nearby_desc = ""
	if nearby_objects.size() > 0:
		var obj_names = []
		for obj in nearby_objects.slice(0, 3):  # Limit to 3
			obj_names.append(obj.get("type", "something"))
		nearby_desc = "Nearby: " + ", ".join(obj_names) + "."

	# Mood description
	var mood_desc = ""
	if happiness > 0.7:
		mood_desc = "very happy"
	elif happiness > 0.4:
		mood_desc = "content"
	else:
		mood_desc = "a bit down"

	if energy < 0.3:
		mood_desc += " and tired"
	elif energy > 0.7:
		mood_desc += " and energetic"

	var prompt = """You are %s. You speak %s.

Current state: You are %s. Your goal is: %s.
%s

Generate a short thought (1-2 sentences max) that reflects your personality and current situation. Be in character. Do not use quotes.

Thought:""" % [personality, speech_style, mood_desc, current_goal, nearby_desc]

	return prompt


func _on_thought_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, agent_id: String) -> void:
	_pending_requests.erase(agent_id)

	print("[OllamaClient] Response for %s: result=%s code=%s" % [agent_id, result, response_code])

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[OllamaClient] Request failed, using fallback for %s" % agent_id)
		_emit_fallback_thought(agent_id)
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("[OllamaClient] JSON parse failed for %s" % agent_id)
		_emit_fallback_thought(agent_id)
		return

	var response_text = json.data.get("response", "")
	if response_text.is_empty():
		print("[OllamaClient] Empty response for %s" % agent_id)
		_emit_fallback_thought(agent_id)
		return

	# Clean up the response
	var thought = response_text.strip_edges()
	thought = thought.strip_escapes()

	# Limit length
	if thought.length() > 150:
		thought = thought.substr(0, 147) + "..."

	print("[OllamaClient] AI thought for %s: %s" % [agent_id, thought])

	thought_generated.emit(agent_id, thought)


func _emit_fallback_thought(agent_id: String) -> void:
	var thought = FALLBACK_THOUGHTS[randi() % FALLBACK_THOUGHTS.size()]
	thought_generated.emit(agent_id, thought)


## Batch processing for multiple agents
func queue_thought_request(agent_id: String, soul_data: Dictionary, context: Dictionary) -> void:
	_batch_queue.append({
		"agent_id": agent_id,
		"soul_data": soul_data,
		"context": context
	})


func _process(delta: float) -> void:
	if _batch_queue.is_empty() or _is_processing_batch:
		return

	_batch_timer += delta
	if _batch_timer >= BATCH_INTERVAL:
		_batch_timer = 0.0
		_process_next_batch()


func _process_next_batch() -> void:
	if _batch_queue.is_empty():
		return

	_is_processing_batch = true
	var batch = _batch_queue.slice(0, BATCH_SIZE)
	_batch_queue = _batch_queue.slice(BATCH_SIZE)

	for request in batch:
		generate_thought(request.agent_id, request.soul_data, request.context)

	_is_processing_batch = false


## Batch generate thoughts for all agents at once (more efficient)
func generate_batch_thoughts(agent_requests: Array) -> void:
	for request in agent_requests:
		queue_thought_request(
			request.get("agent_id", ""),
			request.get("soul_data", {}),
			request.get("context", {})
		)


## Web search via SearXNG
func web_search(agent_id: String, query: String) -> void:
	if not _search_enabled:
		push_warning("[OllamaClient] SearXNG search not available")
		return

	var http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_on_search_response.bind(agent_id))

	var url = SEARXNG_URL + "/search"
	var params = "?q=%s&format=json&categories=general" % query.uri_encode()
	var error = http.request(url + params, [], HTTPClient.METHOD_GET)

	if error != OK:
		push_warning("[OllamaClient] Search request failed: %s" % error)


func _on_search_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, agent_id: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		search_completed.emit(agent_id, [])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		search_completed.emit(agent_id, [])
		return

	var results = []
	var search_results = json.data.get("results", [])
	for i in range(min(5, search_results.size())):
		var r = search_results[i]
		results.append({
			"title": r.get("title", ""),
			"url": r.get("url", ""),
			"snippet": r.get("content", "")
		})

	search_completed.emit(agent_id, results)


## Check if SearXNG is available
func check_search_availability() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_search_check)

	var error = http.request(SEARXNG_URL, [], HTTPClient.METHOD_GET)
	if error != OK:
		_search_enabled = false


func _on_search_check(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		_search_enabled = true
		print("[OllamaClient] SearXNG search available")
	else:
		_search_enabled = false
		print("[OllamaClient] SearXNG not available, search disabled")


## Get availability status
func is_available() -> bool:
	return _is_available


func is_search_available() -> bool:
	return _search_enabled


## Get pending request count
func get_pending_count() -> int:
	return _pending_requests.size()


## Get queue size
func get_queue_size() -> int:
	return _batch_queue.size()


## Get a fallback thought directly
func get_fallback_thought() -> String:
	return FALLBACK_THOUGHTS[randi() % FALLBACK_THOUGHTS.size()]


## Set the model to use
func set_model(model_name: String) -> void:
	_model = model_name
