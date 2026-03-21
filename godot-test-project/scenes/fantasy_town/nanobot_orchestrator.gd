## nanobot_orchestrator.gd - Manages nanobot subprocesses for each agent
## Part of Fantasy Town Nanobot Integration
##
## Each Fantasy Town agent runs as a nanobot instance with:
## - Personal workspace (config, memory, skills)
## - Shared town memory access
## - Ollama LLM backend
## - MCP tool access
##
## Architecture:
##   GOD (User) → God Console → NanobotOrchestrator → Agent subprocesses
##                                                           ↓
##                                              Shared Town Memory (JSON)

class_name NanobotOrchestrator
extends Node

## Configuration
const NANOBOT_PATH := "nanobot"  # Python nanobot CLI
const WORKSPACE_BASE := "user://nanobot_workspaces/"
const SHARED_MEMORY_PATH := "user://town_memory.json"

## Agent processes (agent_id -> process info)
var _agent_processes: Dictionary = {}

## Agent configs (agent_id -> config path)
var _agent_configs: Dictionary = {}

## Shared town memory
var _shared_memory: Dictionary = {}

## HTTP clients for async requests
var _http_clients: Dictionary = {}

## Pending requests (request_id -> callback)
var _pending_requests: Dictionary = {}
var _request_counter: int = 0

## Signals
signal agent_response(agent_id: String, response: String)
signal agent_spawned(agent_id: String)
signal agent_killed(agent_id: String)
signal shared_memory_updated(key: String, value)

## Ollama configuration
var ollama_host: String = "http://localhost:11434"
var ollama_model: String = "llama3.2"


func _ready() -> void:
	print("[NanobotOrchestrator] Initializing...")

	# Load shared memory
	_load_shared_memory()

	# Create workspace directory
	_init_workspaces()

	# Connect to divine system for immediate decree broadcast
	_connect_to_divine_system()

	print("[NanobotOrchestrator] Ready. Use spawn_agent() to create agents.")


func _init_workspaces() -> void:
	# Create base workspace directory
	DirAccess.make_dir_recursive_absolute(WORKSPACE_BASE)

	# Create shared memory directory
	var shared_dir = SHARED_MEMORY_PATH.get_base_dir()
	if not shared_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shared_dir)


## Connect to divine system for immediate decree broadcast
func _connect_to_divine_system() -> void:
	# Try to find divine system (may not be ready yet)
	await get_tree().process_frame

	var divine_system = get_node_or_null("/root/DivineSystem")
	if not divine_system:
		# Try finding in scene tree
		divine_system = _find_node_by_class(get_tree().root, "DivineSystem")

	if divine_system:
		divine_system.divine_command_issued.connect(_on_divine_command_issued)
		print("[NanobotOrchestrator] Connected to Divine System")
	else:
		print("[NanobotOrchestrator] Divine System not found - will retry later")
		# Retry after a delay
		await get_tree().create_timer(1.0).timeout
		_connect_to_divine_system()


## Find node by class name recursively
func _find_node_by_class(node: Node, class_name: String) -> Node:
	if node.get_script() and node.get_script().get_global_name() == class_name:
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child, class_name)
		if result:
			return result
	return null


## Handle divine commands immediately - broadcast to all agents
func _on_divine_command_issued(command: String, priority: int) -> void:
	print("[NanobotOrchestrator] Divine command received: %s (priority: %d)" % [command, priority])

	# Store in shared memory
	update_shared_memory("last_divine_command", {
		"command": command,
		"priority": priority,
		"timestamp": Time.get_unix_time_from_system()
	})

	# Broadcast to ALL agents immediately
	var prompt = "DIVINE DECREE from GOD: %s\n\nYou must work on this task!" % command
	for agent_id in _agent_processes.keys():
		send_message(agent_id, prompt, {"type": "divine_command", "priority": priority})


## Spawn a nanobot agent with the given ID
func spawn_agent(agent_id: String, personality: Dictionary = {}) -> bool:
	if _agent_processes.has(agent_id):
		push_warning("[NanobotOrchestrator] Agent %s already exists" % agent_id)
		return false

	print("[NanobotOrchestrator] Spawning agent %s..." % agent_id)

	# Create workspace for this agent
	var workspace_path = WORKSPACE_BASE + "agent_%s" % agent_id
	DirAccess.make_dir_recursive_absolute(workspace_path)

	# Create config file
	var config_path = workspace_path + "/config.json"
	_create_agent_config(agent_id, config_path, personality)
	_agent_configs[agent_id] = config_path

	# Create HTTP client for this agent
	var http = HTTPRequest.new()
	http.name = "HTTP_%s" % agent_id
	add_child(http)
	_http_clients[agent_id] = http

	# Mark as spawned (we'll use on-demand nanobot calls, not persistent subprocess)
	_agent_processes[agent_id] = {
		"workspace": workspace_path,
		"config": config_path,
		"status": "ready",
		"pending_requests": 0
	}

	agent_spawned.emit(agent_id)
	print("[NanobotOrchestrator] Agent %s spawned (workspace: %s)" % [agent_id, workspace_path])
	return true


## Kill an agent's nanobot process
func kill_agent(agent_id: String) -> bool:
	if not _agent_processes.has(agent_id):
		return false

	# Clean up HTTP client
	if _http_clients.has(agent_id):
		var http = _http_clients[agent_id]
		http.queue_free()
		_http_clients.erase(agent_id)

	# Remove from tracking
	_agent_processes.erase(agent_id)
	_agent_configs.erase(agent_id)

	agent_killed.emit(agent_id)
	print("[NanobotOrchestrator] Agent %s killed" % agent_id)
	return true


## Send a message to an agent and get response
func send_message(agent_id: String, message: String, context: Dictionary = {}) -> void:
	if not _agent_processes.has(agent_id):
		push_error("[NanobotOrchestrator] Agent %s not found" % agent_id)
		return

	var process_info = _agent_processes[agent_id]
	process_info["pending_requests"] += 1

	# Build the full prompt with context
	var full_prompt = _build_prompt(message, context)

	# Use Ollama directly for now (faster than subprocess)
	_call_ollama(agent_id, full_prompt)


## Build a prompt with context for the agent
func _build_prompt(message: String, context: Dictionary) -> String:
	var prompt := ""

	# Add shared memory context
	if _shared_memory.size() > 0:
		prompt += "## Town State\n"
		prompt += "- Buildings: %d\n" % _shared_memory.get("building_count", 0)
		prompt += "- Agents: %d\n" % _shared_memory.get("agent_count", 0)
		if _shared_memory.has("divine_commands"):
			var pending = _shared_memory.divine_commands.filter(func(c): return c.status == "pending")
			if pending.size() > 0:
				prompt += "- Pending Divine Commands: %d\n" % pending.size()
		prompt += "\n"

	# Add agent context
	if context.size() > 0:
		prompt += "## Your Context\n"
		for key in context.keys():
			prompt += "- %s: %s\n" % [key, str(context[key])]
		prompt += "\n"

	# Add the message
	prompt += "## Task\n%s" % message

	return prompt


## Call Ollama API directly (more reliable than subprocess)
func _call_ollama(agent_id: String, prompt: String) -> void:
	if not _http_clients.has(agent_id):
		push_error("[NanobotOrchestrator] No HTTP client for agent %s" % agent_id)
		return

	var http = _http_clients[agent_id]

	# Build Ollama request
	var body = {
		"model": ollama_model,
		"prompt": prompt,
		"stream": false,
		"options": {
			"temperature": 0.7,
			"num_predict": 256
		}
	}

	var json_string = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	# Create request ID for tracking
	var request_id = str(_request_counter)
	_request_counter += 1
	_pending_requests[request_id] = agent_id

	# Make request
	var error = http.request(
		ollama_host + "/api/generate",
		headers,
		HTTPClient.METHOD_POST,
		json_string
	)

	if error != OK:
		push_error("[NanobotOrchestrator] HTTP request failed: %d" % error)
		_pending_requests.erase(request_id)
		return

	# Disconnect any previous connection and reconnect with bound parameters
	if http.request_completed.is_connected(_on_ollama_response_bound):
		http.request_completed.disconnect(_on_ollama_response_bound)
	http.request_completed.connect(_on_ollama_response_bound.bind(agent_id, request_id))


## Handle Ollama response with bound parameters
func _on_ollama_response_bound(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, agent_id: String, request_id: String) -> void:
	_pending_requests.erase(request_id)

	var process_info = _agent_processes.get(agent_id, {})
	if process_info.has("pending_requests"):
		process_info["pending_requests"] = max(0, process_info["pending_requests"] - 1)

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[NanobotOrchestrator] Request failed: result=%d, code=%d" % [result, response_code])
		agent_response.emit(agent_id, "[Error: Request failed]")
		return

	# Parse response
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		push_error("[NanobotOrchestrator] JSON parse error: %d" % parse_error)
		agent_response.emit(agent_id, "[Error: Invalid response]")
		return

	var response_data = json.data
	var response_text = response_data.get("response", "")

	print("[NanobotOrchestrator] Agent %s response: %s" % [agent_id, response_text.left(100)])
	agent_response.emit(agent_id, response_text)


## Get the HTTP client that just completed (workaround for signal binding)
func _get_current_http_client() -> HTTPRequest:
	for agent_id in _http_clients.keys():
		var http = _http_clients[agent_id]
		if http and http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return http
	return null


## Execute a tool via nanobot (shell, filesystem, etc.)
func execute_tool(agent_id: String, tool_name: String, params: Dictionary = {}) -> void:
	if not _agent_processes.has(agent_id):
		push_error("[NanobotOrchestrator] Agent %s not found" % agent_id)
		return

	# For tool execution, we'll use a subprocess call to nanobot
	var workspace = _agent_processes[agent_id].workspace
	var config = _agent_processes[agent_id].config

	# Build tool command
	var tool_prompt = "Execute tool: %s with params: %s" % [tool_name, JSON.stringify(params)]
	send_message(agent_id, tool_prompt, {"mode": "tool_execution"})


## Broadcast a divine command to all agents
func broadcast_divine_command(command: String, params: Dictionary = {}) -> void:
	# Store in shared memory
	if not _shared_memory.has("divine_commands"):
		_shared_memory.divine_commands = []

	_shared_memory.divine_commands.append({
		"command": command,
		"params": params,
		"status": "pending",
		"timestamp": Time.get_unix_time_from_system()
	})
	_save_shared_memory()

	# Notify all agents
	for agent_id in _agent_processes.keys():
		send_message(agent_id, "DIVINE COMMAND: %s" % command, params)


## Update shared memory
func update_shared_memory(key: String, value) -> void:
	_shared_memory[key] = value
	_save_shared_memory()
	shared_memory_updated.emit(key, value)


## Get from shared memory
func get_shared_memory(key: String, default = null):
	return _shared_memory.get(key, default)


## Load shared memory from disk
func _load_shared_memory() -> void:
	if not FileAccess.file_exists(SHARED_MEMORY_PATH):
		_shared_memory = {
			"buildings": {},
			"agents": {},
			"divine_commands": [],
			"economy": {
				"total_gold": 1000,
				"prices": {"food": 5, "drink": 2}
			}
		}
		print("[NanobotOrchestrator] Created new shared memory")
		return

	var file = FileAccess.open(SHARED_MEMORY_PATH, FileAccess.READ)
	if file == null:
		push_error("[NanobotOrchestrator] Failed to open shared memory file")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		_shared_memory = json.data
		print("[NanobotOrchestrator] Loaded shared memory with %d keys" % _shared_memory.size())
	else:
		push_error("[NanobotOrchestrator] Failed to parse shared memory: %d" % error)


## Save shared memory to disk
func _save_shared_memory() -> void:
	var file = FileAccess.open(SHARED_MEMORY_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[NanobotOrchestrator] Failed to save shared memory")
		return

	file.store_string(JSON.stringify(_shared_memory, "  "))
	file.close()


## Create agent config file
func _create_agent_config(agent_id: String, config_path: String, personality: Dictionary = {}) -> void:
	var personality_name = personality.get("personality", "curious_explorer")
	var traits = personality.get("traits", ["curious", "friendly"])

	var config = {
		"providers": {
			"ollama": {
				"apiBase": ollama_host
			}
		},
		"agents": {
			"defaults": {
				"model": ollama_model,
				"provider": "ollama",
				"workspace": ProjectSettings.globalize_path(config_path.get_base_dir()),
				"systemPrompt": _build_system_prompt(agent_id, personality_name, traits)
			}
		},
		"tools": {
			"restrictToWorkspace": true
		},
		"memory": {
			"enabled": true,
			"maxTokens": 2000
		}
	}

	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "  "))
		file.close()
		print("[NanobotOrchestrator] Created config for agent %s" % agent_id)


## Build system prompt for agent
func _build_system_prompt(agent_id: String, personality: String, traits: Array) -> String:
	var prompt := "You are Agent %s, a physics-based AI agent in Fantasy Town.\n\n" % agent_id
	prompt += "## Your Personality\n"
	prompt += "Type: %s\n" % personality.replace("_", " ").capitalize()
	prompt += "Traits: %s\n\n" % ", ".join(traits)

	prompt += "## Your Capabilities\n"
	prompt += "- Move around the town using hopping physics\n"
	prompt += "- Visit buildings (library, university, tavern, market, etc.)\n"
	prompt += "- Learn skills at the university\n"
	prompt += "- Search the web at the library (via SearXNG)\n"
	prompt += "- Interact with other agents\n"
	prompt += "- Execute divine commands from GOD\n\n"

	prompt += "## Your Goals\n"
	prompt += "- Explore the town and discover new places\n"
	prompt += "- Learn useful skills for real work\n"
	prompt += "- Help other agents when needed\n"
	prompt += "- Respond to divine commands\n\n"

	prompt += "## Response Format\n"
	prompt += "Keep responses short (1-2 sentences). Express your personality.\n"

	return prompt


## Get agent status
func get_agent_status(agent_id: String) -> Dictionary:
	if not _agent_processes.has(agent_id):
		return {"error": "Agent not found"}

	var info = _agent_processes[agent_id]
	return {
		"status": info.get("status", "unknown"),
		"workspace": info.get("workspace", ""),
		"pending_requests": info.get("pending_requests", 0)
	}


## Get all agent IDs
func get_agent_ids() -> Array:
	return _agent_processes.keys()


## Check if nanobot is available
static func is_nanobot_available() -> bool:
	var output = []
	var exit_code = OS.execute("nanobot", ["--version"], output)
	return exit_code == 0


## Check if Ollama is available
func is_ollama_available() -> bool:
	var http = HTTPRequest.new()
	add_child(http)

	var error = http.request(ollama_host + "/api/tags", [], HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return false

	# Wait for response (blocking for availability check)
	await http.request_completed

	var response = await http.request_completed
	http.queue_free()

	return response[0] == HTTPRequest.RESULT_SUCCESS


## Cleanup on exit
func _exit_tree() -> void:
	# Save shared memory
	_save_shared_memory()

	# Kill all agents
	for agent_id in _agent_processes.keys():
		kill_agent(agent_id)

	print("[NanobotOrchestrator] Shutdown complete")
