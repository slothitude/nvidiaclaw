## AgentClient
## HTTP client for the Agent Studio API.
extends RefCounted

# Preload dependencies
const AgentConfigScript = preload("res://addons/agent_studio/agent_config.gd")

## Emitted when agents list is loaded
signal agents_loaded(agents: Array)

## Emitted when an agent is created
signal agent_created(agent: Resource)

## Emitted when an agent is updated
signal agent_updated(agent: Resource)

## Emitted when an agent is deleted
signal agent_deleted(agent_id: String)

## Emitted when skills are loaded
signal skills_loaded(skills: Array)

## Emitted when tools are loaded
signal tools_loaded(tools: Array)

## Emitted on errors
signal error_occurred(error: String)

## Base URL for the API
var base_url: String = "http://127.0.0.1:8000"

## Parent node for HTTP requests
var _parent_node: Node = null

## HTTP request timeout
var _timeout: float = 30.0

## Cached agents
var _agents: Array = []

## Cached skills
var _skills: Array = []

## Cached tools
var _tools: Array = []


func _init(parent_node: Node = null, url: String = "http://127.0.0.1:8000") -> void:
	_parent_node = parent_node
	base_url = url


## Create an HTTP request node
func _create_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = _timeout
	if _parent_node == null:
		push_error("[AgentClient] parent_node is null!")
		return null
	_parent_node.add_child(http)
	return http


## Parse JSON response
func _parse_json(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	var err := json.parse(body.get_string_from_utf8())
	if err != OK:
		return {"error": "Failed to parse JSON"}
	return json.data


# === Agents API ===


## Fetch all agents from the server
func fetch_agents() -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_agents_loaded)
	var url := base_url + "/api/v1/agents"
	http.request(url, [], HTTPClient.METHOD_GET)


func _on_agents_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data := _parse_json(body)
		if data.has("error"):
			error_occurred.emit(data.error)
			return

		_agents = []
		for agent_data in data:
			_agents.append(AgentConfigScript.from_dict(agent_data))
		agents_loaded.emit(_agents)
	else:
		error_occurred.emit("Failed to load agents: %d" % response_code)


## Create a new agent
func create_agent(config: Resource) -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_agent_created)
	var url := base_url + "/api/v1/agents"
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(config.to_dict())
	http.request(url, headers, HTTPClient.METHOD_POST, json_body)


func _on_agent_created(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data := _parse_json(body)
		if data.has("error"):
			error_occurred.emit(data.error)
			return

		var agent := AgentConfigScript.from_dict(data)
		_agents.append(agent)
		agent_created.emit(agent)
	else:
		var data := _parse_json(body)
		error_occurred.emit("Failed to create agent: " + data.get("detail", "Unknown error"))


## Update an existing agent
func update_agent(agent_id: String, updates: Dictionary) -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_agent_updated.bind(agent_id))
	var url := base_url + "/api/v1/agents/" + agent_id
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(updates)
	http.request(url, headers, HTTPClient.METHOD_PATCH, json_body)


func _on_agent_updated(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, agent_id: String) -> void:
	if response_code == 200:
		var data := _parse_json(body)
		if data.has("error"):
			error_occurred.emit(data.error)
			return

		var agent := AgentConfigScript.from_dict(data)
		# Update cache
		for i in range(_agents.size()):
			if _agents[i].id == agent_id:
				_agents[i] = agent
				break
		agent_updated.emit(agent)
	else:
		var data := _parse_json(body)
		error_occurred.emit("Failed to update agent: " + data.get("detail", "Unknown error"))


## Delete an agent
func delete_agent(agent_id: String) -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_agent_deleted.bind(agent_id))
	var url := base_url + "/api/v1/agents/" + agent_id
	http.request(url, [], HTTPClient.METHOD_DELETE)


func _on_agent_deleted(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, agent_id: String) -> void:
	if response_code == 200:
		# Remove from cache
		for i in range(_agents.size()):
			if _agents[i].id == agent_id:
				_agents.remove_at(i)
				break
		agent_deleted.emit(agent_id)
	else:
		var data := _parse_json(body)
		error_occurred.emit("Failed to delete agent: " + data.get("detail", "Unknown error"))


## Export agent as markdown
func export_agent(agent_id: String, callback: Callable) -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(func(result, code, headers, body):
		if code == 200:
			var data := _parse_json(body)
			callback.call(data)
		else:
			callback.call({"error": "Export failed"})
	)

	var url := base_url + "/api/v1/agents/" + agent_id + "/export"
	http.request(url, [], HTTPClient.METHOD_GET)


# === Registry API ===


## Fetch available skills
func fetch_skills() -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_skills_loaded)
	var url := base_url + "/api/v1/agents/registry/skills"
	http.request(url, [], HTTPClient.METHOD_GET)


func _on_skills_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data: Variant = _parse_json(body)
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			error_occurred.emit(data.error)
			return
		if typeof(data) == TYPE_ARRAY:
			_skills = data
		skills_loaded.emit(_skills)
	else:
		error_occurred.emit("Failed to load skills")


## Fetch available tools
func fetch_tools() -> void:
	var http := _create_http_request()
	if not http:
		return

	http.request_completed.connect(_on_tools_loaded)
	var url := base_url + "/api/v1/agents/registry/tools"
	http.request(url, [], HTTPClient.METHOD_GET)


func _on_tools_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var data: Variant = _parse_json(body)
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			error_occurred.emit(data.error)
			return
		if typeof(data) == TYPE_ARRAY:
			_tools = data
		tools_loaded.emit(_tools)
	else:
		error_occurred.emit("Failed to load tools")


# === Getters ===


func get_agents() -> Array:
	return _agents


func get_skills() -> Array:
	return _skills


func get_tools() -> Array:
	return _tools


func get_agent_by_id(agent_id: String) -> Resource:
	for agent in _agents:
		if agent.id == agent_id:
			return agent
	return null
