## mcp_client.gd - Model Context Protocol Client for Real Integrations
## Part of Fantasy Town World-Breaking Demo
##
## Connects agents to real MCP servers for actual work:
## - Filesystem operations (read/write files)
## - GitHub integration (repos, issues, PRs)
## - Database queries (PostgreSQL, SQLite)
## - Web search (SearXNG)
## - Custom MCP servers
##
## Agents use this via their learned MCP skills.

class_name MCPClient
extends Node

## Configuration
const DEFAULT_TIMEOUT := 30.0
const MAX_RETRIES := 3

## MCP Server endpoints (configurable)
var _mcp_servers: Dictionary = {
	"filesystem": {"url": "http://localhost:3000", "enabled": false},
	"github": {"url": "http://localhost:3001", "enabled": false},
	"postgres": {"url": "http://localhost:3002", "enabled": false},
	"searxng": {"url": "http://localhost:8080", "enabled": false},
}

## HTTP request pool
var _request_pool: Array = []
var _pending_requests: Dictionary = {}

## Signals
signal mcp_response(server: String, tool: String, result: Dictionary)
signal mcp_error(server: String, tool: String, error: String)
signal server_connected(server_name: String)
signal server_disconnected(server_name: String)


func _ready() -> void:
	_check_all_servers()


## Check availability of all MCP servers
func _check_all_servers() -> void:
	for server_name in _mcp_servers.keys():
		_check_server_availability(server_name)


func _check_server_availability(server_name: String) -> void:
	var server = _mcp_servers.get(server_name, {})
	if server.is_empty():
		return

	var http = _get_http_request()
	http.request_completed.connect(_on_server_check.bind(server_name))

	var url = server.get("url", "") + "/health"
	var error = http.request(url, [], HTTPClient.METHOD_GET)

	if error != OK:
		server["enabled"] = false


func _on_server_check(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, server_name: String) -> void:
	var server = _mcp_servers.get(server_name, {})
	if response_code == 200:
		server["enabled"] = true
		server_connected.emit(server_name)
		print("[MCPClient] %s server connected" % server_name)
	else:
		server["enabled"] = false
		server_disconnected.emit(server_name)


## Get or create HTTP request from pool
func _get_http_request() -> HTTPRequest:
	if _request_pool.size() > 0:
		return _request_pool.pop_back()

	var http = HTTPRequest.new()
	http.timeout = DEFAULT_TIMEOUT
	add_child(http)
	return http


## Return HTTP request to pool
func _return_http_request(http: HTTPRequest) -> void:
	http.cancel_request()
	if _request_pool.size() < 10:  # Max pool size
		_request_pool.append(http)
	else:
		http.queue_free()


## Check if a server is available
func is_server_available(server_name: String) -> bool:
	var server = _mcp_servers.get(server_name, {})
	return server.get("enabled", false)


## Get available servers
func get_available_servers() -> Array:
	var available = []
	for server_name in _mcp_servers.keys():
		if _mcp_servers[server_name].get("enabled", false):
			available.append(server_name)
	return available


# =============================================================================
# FILESYSTEM MCP
# =============================================================================

## Read a file via filesystem MCP
func filesystem_read_file(file_path: String, agent_id: String = "") -> void:
	if not is_server_available("filesystem"):
		mcp_error.emit("filesystem", "read_file", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "filesystem", "tool": "read_file", "http": http}

	http.request_completed.connect(_on_filesystem_read.bind(request_id, file_path))

	var server = _mcp_servers["filesystem"]
	var url = server["url"] + "/tools/read_file"
	var body = JSON.stringify({"path": file_path})

	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _on_filesystem_read(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, file_path: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit("filesystem", "read_file", "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		mcp_error.emit("filesystem", "read_file", "JSON parse error")
		_return_http_request(request.get("http"))
		return

	var content = json.data.get("content", "")
	mcp_response.emit("filesystem", "read_file", {"path": file_path, "content": content})
	_return_http_request(request.get("http"))


## Write a file via filesystem MCP
func filesystem_write_file(file_path: String, content: String, agent_id: String = "") -> void:
	if not is_server_available("filesystem"):
		mcp_error.emit("filesystem", "write_file", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "filesystem", "tool": "write_file", "http": http}

	http.request_completed.connect(_on_filesystem_write.bind(request_id, file_path))

	var server = _mcp_servers["filesystem"]
	var url = server["url"] + "/tools/write_file"
	var body = JSON.stringify({"path": file_path, "content": content})

	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _on_filesystem_write(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, file_path: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit("filesystem", "write_file", "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	mcp_response.emit("filesystem", "write_file", {"path": file_path, "success": true})
	_return_http_request(request.get("http"))


## List directory contents
func filesystem_list_directory(dir_path: String, agent_id: String = "") -> void:
	if not is_server_available("filesystem"):
		mcp_error.emit("filesystem", "list_directory", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "filesystem", "tool": "list_directory", "http": http}

	http.request_completed.connect(_on_filesystem_list.bind(request_id, dir_path))

	var server = _mcp_servers["filesystem"]
	var url = server["url"] + "/tools/list_directory"
	var body = JSON.stringify({"path": dir_path})

	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _on_filesystem_list(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, dir_path: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit("filesystem", "list_directory", "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		mcp_error.emit("filesystem", "list_directory", "JSON parse error")
		_return_http_request(request.get("http"))
		return

	var entries = json.data.get("entries", [])
	mcp_response.emit("filesystem", "list_directory", {"path": dir_path, "entries": entries})
	_return_http_request(request.get("http"))


# =============================================================================
# GITHUB MCP
# =============================================================================

## Get repository info
func github_get_repo(owner: String, repo: String, agent_id: String = "") -> void:
	if not is_server_available("github"):
		mcp_error.emit("github", "get_repo", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "github", "tool": "get_repo", "http": http}

	http.request_completed.connect(_on_github_response.bind(request_id, "get_repo"))

	var server = _mcp_servers["github"]
	var url = server["url"] + "/repos/%s/%s" % [owner, repo]

	http.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)


## Create an issue
func github_create_issue(owner: String, repo: String, title: String, body_text: String, agent_id: String = "") -> void:
	if not is_server_available("github"):
		mcp_error.emit("github", "create_issue", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "github", "tool": "create_issue", "http": http}

	http.request_completed.connect(_on_github_response.bind(request_id, "create_issue"))

	var server = _mcp_servers["github"]
	var url = server["url"] + "/repos/%s/%s/issues" % [owner, repo]
	var body = JSON.stringify({"title": title, "body": body_text})

	http.request(url, ["Content-Type: application/json", "Accept: application/json"], HTTPClient.METHOD_POST, body)


## List issues
func github_list_issues(owner: String, repo: String, state: String = "open", agent_id: String = "") -> void:
	if not is_server_available("github"):
		mcp_error.emit("github", "list_issues", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "github", "tool": "list_issues", "http": http}

	http.request_completed.connect(_on_github_response.bind(request_id, "list_issues"))

	var server = _mcp_servers["github"]
	var url = server["url"] + "/repos/%s/%s/issues?state=%s" % [owner, repo, state]

	http.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)


func _on_github_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, tool: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code not in [200, 201]:
		mcp_error.emit("github", tool, "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		mcp_error.emit("github", tool, "JSON parse error")
		_return_http_request(request.get("http"))
		return

	mcp_response.emit("github", tool, json.data)
	_return_http_request(request.get("http"))


# =============================================================================
# DATABASE MCP (PostgreSQL)
# =============================================================================

## Execute a SQL query
func postgres_query(sql: String, params: Array = [], agent_id: String = "") -> void:
	if not is_server_available("postgres"):
		mcp_error.emit("postgres", "query", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "postgres", "tool": "query", "http": http}

	http.request_completed.connect(_on_postgres_response.bind(request_id))

	var server = _mcp_servers["postgres"]
	var url = server["url"] + "/query"
	var body = JSON.stringify({"sql": sql, "params": params})

	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _on_postgres_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit("postgres", "query", "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		mcp_error.emit("postgres", "query", "JSON parse error")
		_return_http_request(request.get("http"))
		return

	var rows = json.data.get("rows", [])
	var affected = json.data.get("rowCount", 0)

	mcp_response.emit("postgres", "query", {"rows": rows, "affected": affected})
	_return_http_request(request.get("http"))


# =============================================================================
# SEARXNG (Web Search)
# =============================================================================

## Search the web
func searxng_search(query: String, categories: String = "general", agent_id: String = "") -> void:
	if not is_server_available("searxng"):
		mcp_error.emit("searxng", "search", "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": "searxng", "tool": "search", "http": http}

	http.request_completed.connect(_on_searxng_response.bind(request_id, query))

	var server = _mcp_servers["searxng"]
	var url = server["url"] + "/search?q=%s&format=json&categories=%s" % [query.uri_encode(), categories]

	http.request(url, [], HTTPClient.METHOD_GET)


func _on_searxng_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String, query: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit("searxng", "search", "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		mcp_error.emit("searxng", "search", "JSON parse error")
		_return_http_request(request.get("http"))
		return

	var results = []
	for r in json.data.get("results", []).slice(0, 5):
		results.append({
			"title": r.get("title", ""),
			"url": r.get("url", ""),
			"snippet": r.get("content", "")
		})

	mcp_response.emit("searxng", "search", {"query": query, "results": results})
	_return_http_request(request.get("http"))


# =============================================================================
# GENERIC MCP CALL
# =============================================================================

## Call any MCP tool
func call_tool(server_name: String, tool_name: String, params: Dictionary, agent_id: String = "") -> void:
	if not is_server_available(server_name):
		mcp_error.emit(server_name, tool_name, "Server not available")
		return

	var http = _get_http_request()
	var request_id = "%s_%d" % [agent_id, Time.get_ticks_msec()]
	_pending_requests[request_id] = {"server": server_name, "tool": tool_name, "http": http}

	http.request_completed.connect(_on_generic_response.bind(request_id))

	var server = _mcp_servers.get(server_name, {})
	var url = server.get("url", "") + "/tools/%s" % tool_name
	var body = JSON.stringify(params)

	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _on_generic_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	var request = _pending_requests.get(request_id, {})
	_pending_requests.erase(request_id)

	var server = request.get("server", "unknown")
	var tool = request.get("tool", "unknown")

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mcp_error.emit(server, tool, "HTTP error: %d" % response_code)
		_return_http_request(request.get("http"))
		return

	var json = JSON.new()
	var data = {}
	if json.parse(body.get_string_from_utf8()) == OK:
		data = json.data

	mcp_response.emit(server, tool, data)
	_return_http_request(request.get("http"))


## Configure a server endpoint
func configure_server(server_name: String, url: String) -> void:
	if not _mcp_servers.has(server_name):
		_mcp_servers[server_name] = {"url": url, "enabled": false}
	else:
		_mcp_servers[server_name]["url"] = url

	_check_server_availability(server_name)


## Get server status
func get_server_status() -> Dictionary:
	var status = {}
	for server_name in _mcp_servers.keys():
		status[server_name] = {
			"url": _mcp_servers[server_name].get("url", ""),
			"enabled": _mcp_servers[server_name].get("enabled", false)
		}
	return status
