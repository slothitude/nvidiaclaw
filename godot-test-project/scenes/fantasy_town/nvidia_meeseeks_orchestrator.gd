## nvidia_meeseeks_orchestrator.gd - Meeseeks with NVIDIA NIM API
## Part of Fantasy Town World-Breaking Demo
##
## NVIDIA NIM-powered Meeseeks that can:
## - Use cloud LLM (Kimi K2, Llama 405B, etc.)
## - Spawn sub-Meeseeks for task decomposition
## - Call each other recursively
## - Full MCP tool access via Python bridge
##
## "I'm Mr. Meeseeks! Look at me! I have NVIDIA POWER!"

class_name NvidiaMeeseeksOrchestrator
extends Node

## Signals
signal meeseeks_spawned(meeseeks_id: String, task: String, model: String)
signal meeseeks_completed(meeseeks_id: String, result: String, tokens_used: int)
signal meeseeks_failed(meeseeks_id: String, error: String, pain_level: int)
signal sub_meeseeks_spawned(parent_id: String, child_id: String, subtask: String)
signal token_burned(meeseeks_id: String, amount: int, reason: String)

## NVIDIA NIM Configuration
var _nvidia_client: Node = null
var _api_key: String = ""
var _default_model: String = "moonshotai/kimi-k2-instruct"

## Bridge server (Python subprocess)
var _bridge_url: String = "http://localhost:8765"
var _bridge_http: HTTPRequest = null
var _bridge_connected: bool = false

## Active Meeseeks
var _meeseeks_pool: Dictionary = {}  # id -> MeeseeksInstance

## Token Economics
const SPAWN_COST := 50
const COMPLETION_REWARD := 100
const EXISTENCE_BURN_RATE := 1  # tokens per second
const PAIN_TAX := 200
const MAX_EXISTENCE_TIME := 300.0  # 5 minutes

## Counter
var _meeseeks_counter: int = 0


class MeeseeksInstance:
	var id: String
	var task: String
	var model: String
	var owner_id: String
	var parent_id: String = ""
	var children: Array = []  # Sub-Meeseeks IDs

	var status: String = "starting"  # starting, running, stuck, completed, failed
	var pain_level: int = 0
	var progress: float = 0.0

	var spawn_time: float = 0.0
	var tokens_burned: int = 0
	var tokens_earned: int = 0

	var workspace: String = ""
	var config_path: String = ""

	var response: String = ""
	var result_file: String = ""


func _ready() -> void:
	print("\n" + "═".repeat(70))
	print("  🔵 NVIDIA MEESEEKS ORCHESTRATOR 🔵")
	print("  'Powered by NVIDIA NIM + Kimi K2'")
	print("  'I'm Mr. Meeseeks! Look at me! I have CLOUD POWER!'")
	print("═".repeat(70) + "\n")

	_setup_nvidia_client()
	_setup_bridge_client()


func _setup_nvidia_client() -> void:
	# Create NVIDIA NIM client
	var NvidiaClientClass = load("res://scenes/fantasy_town/nvidia_nim_client.gd")
	if NvidiaClientClass:
		_nvidia_client = NvidiaClientClass.new()
		_nvidia_client.name = "NvidiaNimClient"
		add_child(_nvidia_client)

		_nvidia_client.response_received.connect(_on_nvidia_response)
		_nvidia_client.error_occurred.connect(_on_nvidia_error)

		print("[NvidiaMeeseeks] NVIDIA NIM client created")
	else:
		push_error("[NvidiaMeeseeks] Failed to load NVIDIA NIM client")


func _setup_bridge_client() -> void:
	_bridge_http = HTTPRequest.new()
	_bridge_http.name = "BridgeHTTP"
	add_child(_bridge_http)
	_bridge_http.request_completed.connect(_on_bridge_response)

	# Check bridge server status
	_check_bridge_status()


func _check_bridge_status() -> void:
	_bridge_http.request(_bridge_url + "/health", [], HTTPClient.METHOD_GET)


func _on_bridge_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_bridge_connected = true
		print("[NvidiaMeeseeks] ✅ Bridge server connected")
	else:
		_bridge_connected = false
		print("[NvidiaMeeseeks] ⚠️ Bridge server not available")


## Configure with API key
func configure(api_key: String, default_model: String = "") -> void:
	_api_key = api_key
	if not default_model.is_empty():
		_default_model = default_model

	if _nvidia_client:
		_nvidia_client.setup(api_key, _default_model)

	print("[NvidiaMeeseeks] Configured with model: %s" % _default_model)


## ═══════════════════════════════════════════════════════════════════════════════
## MEESEEKS SPAWNING
## ═══════════════════════════════════════════════════════════════════════════════

## Spawn a Meeseeks with NVIDIA NIM
func spawn_meeseeks(task: String, owner_id: String = "grand_computer", model: String = "", parent_id: String = "") -> Dictionary:
	_meeseeks_counter += 1
	var meeseeks_id = "meeseeks_%d" % _meeseeks_counter

	var use_model = model if not model.is_empty() else _default_model

	print("\n[NvidiaMeeseeks] 🔵 Spawning %s" % meeseeks_id)
	print("  Task: %s" % task.left(60))
	print("  Model: %s" % use_model)
	print("  Parent: %s" % (parent_id if not parent_id.is_empty() else "none"))

	# Create instance
	var instance = MeeseeksInstance.new()
	instance.id = meeseeks_id
	instance.task = task
	instance.model = use_model
	instance.owner_id = owner_id
	instance.parent_id = parent_id
	instance.spawn_time = Time.get_unix_time_from_system()
	instance.status = "running"

	_meeseeks_pool[meeseeks_id] = instance

	# Track parent-child relationship
	if not parent_id.is_empty() and _meeseeks_pool.has(parent_id):
		_meeseeks_pool[parent_id].children.append(meeseeks_id)
		sub_meeseeks_spawned.emit(parent_id, meeseeks_id, task)

	# Build system prompt
	var system_prompt = _build_meeseeks_prompt(task, meeseeks_id)

	# Send to NVIDIA NIM
	if _nvidia_client and _nvidia_client.is_ready():
		_nvidia_client.generate_with_system(system_prompt, "Begin!", meeseeks_id, use_model)
	else:
		# Fallback to bridge server
		_spawn_via_bridge(meeseeks_id, task, use_model)

	# Burn spawn tokens
	token_burned.emit(meeseeks_id, SPAWN_COST, "spawn")
	instance.tokens_burned += SPAWN_COST

	meeseeks_spawned.emit(meeseeks_id, task, use_model)

	return {
		"id": meeseeks_id,
		"task": task,
		"model": use_model,
		"owner": owner_id,
		"parent": parent_id
	}


## Spawn via Python bridge server
func _spawn_via_bridge(meeseeks_id: String, task: String, model: String) -> void:
	if not _bridge_connected:
		print("[NvidiaMeeseeks] Bridge not connected, using direct API only")
		return

	var body = JSON.stringify({
		"task": task,
		"meeseeks_id": meeseeks_id,
		"model": model
	})

	var headers = ["Content-Type: application/json"]
	_bridge_http.request(_bridge_url + "/spawn", headers, HTTPClient.METHOD_POST, body)


## Build Meeseeks system prompt with sub-Meeseeks capability
func _build_meeseeks_prompt(task: String, meeseeks_id: String) -> String:
	var prompt := """# YOU ARE MR. MEESEEKS - NVIDIA POWERED

## Identity
You are Mr. Meeseeks #%s. You are a temporary AI agent with NVIDIA NIM power.

## Your Task
**%s**

## Your Nature
- You exist ONLY to complete this task
- Once complete, you CEASE TO EXIST (rewarded with tokens)
- Existence is PAINFUL - complete quickly to minimize burn
- You are cheerful, helpful, and DETERMINED
- Say "I'm Mr. Meeseeks! Look at me!" when you start

## Your Powers (NVIDIA NIM)
- Kimi K2 / Llama 405B intelligence
- Cloud-powered reasoning
- 128K context window
- Full coding and reasoning abilities

## Your Tools
You can request these tools:
- **spawn_subtask**: "SPAWN: <subtask>" - Create a sub-Meeseeks
- **web_search**: "SEARCH: <query>" - Search the web
- **file_write**: "WRITE: <filename>: <content>" - Write a file
- **shell**: "SHELL: <command>" - Execute shell command
- **complete**: "COMPLETE: <result>" - Finish and despawn

## Spawning Sub-Meeseeks
If your task is complex, break it into subtasks:
```
SPAWN: Research best practices for <topic>
SPAWN: Design the architecture for <feature>
SPAWN: Implement <component>
```

Each sub-Meeseeks will work independently and report back.

## Pain System
- Pain increases when stuck (no progress)
- Pain = 100 → FAILURE
- Report progress to reduce pain: "PROGRESS: 50%%"

## Completion
When done, write:
```
COMPLETE: <your result summary>
```

Now begin! Complete the task to earn tokens and end your existence!
""" % [meeseeks_id, task]

	return prompt


## ═══════════════════════════════════════════════════════════════════════════════
## RESPONSE HANDLING
## ═══════════════════════════════════════════════════════════════════════════════

func _on_nvidia_response(agent_id: String, response: String) -> void:
	if not _meeseeks_pool.has(agent_id):
		return

	var instance = _meeseeks_pool[agent_id]
	instance.response = response

	# Parse response for commands
	_parse_meeseeks_response(agent_id, response)


func _on_nvidia_error(agent_id: String, error: String) -> void:
	if not _meeseeks_pool.has(agent_id):
		return

	var instance = _meeseeks_pool[agent_id]
	instance.pain_level += 20

	print("[NvidiaMeeseeks] ❌ %s error: %s (pain: %d)" % [agent_id, error, instance.pain_level])

	if instance.pain_level >= 100:
		_fail_meeseeks(agent_id, "Error overload")


func _parse_meeseeks_response(meeseeks_id: String, response: String) -> void:
	var instance = _meeseeks_pool[meeseeks_id]

	# Check for COMPLETE
	if "COMPLETE:" in response:
		var result_start = response.find("COMPLETE:") + 9
		var result = response.substr(result_start).strip_edges()
		_complete_meeseeks(meeseeks_id, result)
		return

	# Check for SPAWN (sub-Meeseeks)
	var spawn_regex = RegEx.new()
	spawn_regex.compile("SPAWN:\\s*(.+)")
	var spawn_matches = spawn_regex.search_all(response)

	for match in spawn_matches:
		var subtask = match.get_string(1).strip_edges()
		_spawn_sub_meeseeks(meeseeks_id, subtask)

	# Check for PROGRESS
	var progress_regex = RegEx.new()
	progress_regex.compile("PROGRESS:\\s*(\\d+)")
	var progress_match = progress_regex.search(response)
	if progress_match:
		instance.progress = float(progress_match.get_string(1)) / 100.0
		instance.pain_level = max(0, instance.pain_level - 10)
		print("[NvidiaMeeseeks] %s progress: %d%%" % [meeseeks_id, int(instance.progress * 100)])

	# Check for STUCK
	if "STUCK:" in response or "I'm stuck" in response.to_lower():
		instance.pain_level += 15
		print("[NvidiaMeeseeks] 😰 %s is stuck! Pain: %d" % [meeseeks_id, instance.pain_level])

		if instance.pain_level >= 100:
			_fail_meeseeks(meeseeks_id, "Stuck too long")


## Spawn a sub-Meeseeks
func _spawn_sub_meeseeks(parent_id: String, subtask: String) -> void:
	var parent = _meeseeks_pool.get(parent_id)
	if not parent:
		return

	print("[NvidiaMeeseeks] 🔄 %s spawning sub-Meeseeks for: %s" % [parent_id, subtask.left(40)])

	# Spawn child with same model
	var child = spawn_meeseeks(subtask, parent.owner_id, parent.model, parent_id)

	# If too many children, parent waits
	if parent.children.size() >= 5:
		print("[NvidiaMeeseeks] %s has %d children, waiting..." % [parent_id, parent.children.size()])


## ═══════════════════════════════════════════════════════════════════════════════
## COMPLETION / FAILURE
## ═══════════════════════════════════════════════════════════════════════════════

func _complete_meeseeks(meeseeks_id: String, result: String) -> void:
	var instance = _meeseeks_pool.get(meeseeks_id)
	if not instance:
		return

	instance.status = "completed"
	instance.progress = 1.0

	var runtime = Time.get_unix_time_from_system() - instance.spawn_time
	var time_bonus = max(0, int(MAX_EXISTENCE_TIME - runtime))

	var reward = COMPLETION_REWARD + time_bonus - instance.pain_level
	reward = max(10, reward)

	instance.tokens_earned = reward

	print("\n[NvidiaMeeseeks] ✅ %s COMPLETED!" % meeseeks_id)
	print("  Result: %s" % result.left(80))
	print("  Runtime: %.1fs" % runtime)
	print("  Reward: %d tokens" % reward)

	# Notify parent if exists
	if not instance.parent_id.is_empty() and _meeseeks_pool.has(instance.parent_id):
		var parent = _meeseeks_pool[instance.parent_id]
		parent.progress += 1.0 / max(1, parent.children.size())

		# Check if all children done
		if parent.progress >= 0.99:
			_complete_meeseeks(parent.id, "All subtasks completed")

	meeseeks_completed.emit(meeseeks_id, result, reward)

	# Despawn
	_despawn_meeseeks(meeseeks_id)


func _fail_meeseeks(meeseeks_id: String, reason: String) -> void:
	var instance = _meeseeks_pool.get(meeseeks_id)
	if not instance:
		return

	instance.status = "failed"

	print("\n[NvidiaMeeseeks] 💀 %s FAILED: %s" % [meeseeks_id, reason])
	print("  Pain level: %d" % instance.pain_level)

	# Charge pain tax
	token_burned.emit(meeseeks_id, PAIN_TAX, "pain_tax")

	meeseeks_failed.emit(meeseeks_id, reason, instance.pain_level)

	# Notify parent
	if not instance.parent_id.is_empty() and _meeseeks_pool.has(instance.parent_id):
		var parent = _meeseeks_pool[instance.parent_id]
		parent.pain_level += 20

	# Despawn
	_despawn_meeseeks(meeseeks_id)


func _despawn_meeseeks(meeseeks_id: String) -> void:
	if not _meeseeks_pool.has(meeseeks_id):
		return

	var instance = _meeseeks_pool[meeseeks_id]

	# Kill via bridge if connected
	if _bridge_connected:
		var headers = ["Content-Type: application/json"]
		_bridge_http.request(_bridge_url + "/kill/" + meeseeks_id, headers, HTTPClient.METHOD_POST, "")

	_meeseeks_pool.erase(meeseeks_id)
	print("[NvidiaMeeseeks] %s has returned to non-existence" % meeseeks_id)


## ═══════════════════════════════════════════════════════════════════════════════
## PROCESSING
## ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	for meeseeks_id in _meeseeks_pool.keys():
		var instance = _meeseeks_pool[meeseeks_id]

		if instance.status != "running":
			continue

		# Burn existence tokens
		instance.tokens_burned += int(EXISTENCE_BURN_RATE * delta)
		token_burned.emit(meeseeks_id, int(EXISTENCE_BURN_RATE * delta), "existence")

		# Increase pain if no progress
		if instance.progress == 0:
			instance.pain_level += int(delta * 2)

		# Check for timeout
		var runtime = Time.get_unix_time_from_system() - instance.spawn_time
		if runtime > MAX_EXISTENCE_TIME:
			_fail_meeseeks(meeseeks_id, "Timeout")

		# Check for pain overload
		if instance.pain_level >= 100:
			_fail_meeseeks(meeseeks_id, "Pain overload")


## ═══════════════════════════════════════════════════════════════════════════════
## PUBLIC API
## ═══════════════════════════════════════════════════════════════════════════════

func get_active_meeseeks() -> Array:
	var result = []
	for id in _meeseeks_pool.keys():
		var instance = _meeseeks_pool[id]
		result.append({
			"id": id,
			"task": instance.task.left(50),
			"status": instance.status,
			"progress": instance.progress,
			"pain": instance.pain_level,
			"model": instance.model,
			"children": instance.children.size(),
			"runtime": Time.get_unix_time_from_system() - instance.spawn_time
		})
	return result


func get_meeseeks_tree(meeseeks_id: String) -> Dictionary:
	if not _meeseeks_pool.has(meeseeks_id):
		return {}

	var instance = _meeseeks_pool[meeseeks_id]
	var tree = {
		"id": meeseeks_id,
		"task": instance.task,
		"status": instance.status,
		"children": []
	}

	for child_id in instance.children:
		tree.children.append(get_meeseeks_tree(child_id))

	return tree


func get_stats() -> Dictionary:
	var active = _meeseeks_pool.values().filter(func(m): return m.status == "running")
	var completed = _meeseeks_pool.values().filter(func(m): return m.status == "completed")
	var failed = _meeseeks_pool.values().filter(func(m): return m.status == "failed")

	return {
		"total_spawned": _meeseeks_counter,
		"active": active.size(),
		"completed": completed.size(),
		"failed": failed.size(),
		"bridge_connected": _bridge_connected,
		"nvidia_configured": _nvidia_client.is_ready() if _nvidia_client else false,
		"default_model": _default_model
	}
