## meeseeks_tools.gd - Tool Execution System for Meeseeks
## Part of Fantasy Town World-Breaking Demo
##
## Gives Meeseeks agents the power to:
## - Execute bash commands
## - Read/write files
## - Search the web
## - Spawn sub-Meeseeks
## - Call APIs
##
## "I'm Mr. Meeseeks! Look at me! I can BUILD ANYTHING!"

class_name MeeseeksTools
extends Node

## Signals
signal tool_executed(meeseeks_id: String, tool: String, params: Dictionary, result: Dictionary)
signal bash_executed(meeseeks_id: String, command: String, output: String, exit_code: int)
signal file_written(meeseeks_id: String, path: String, size: int)
signal file_read(meeseeks_id: String, path: String, content: String)
signal web_searched(meeseeks_id: String, query: String, results: Array)
signal sub_meeseeks_requested(meeseeks_id: String, subtask: String)

## HTTP clients
var _http_clients: Dictionary = {}

## Web search endpoint (DuckDuckGo or SearXNG)
var _search_endpoint: String = "https://api.duckduckgo.com/"
var _searxng_endpoint: String = "http://localhost:8080/search"

## Workspace base
var _workspace_base: String = "user://meeseeks_workspaces/"

## Bridge server for real bash execution
var _bridge_url: String = "http://localhost:8765"


## ═══════════════════════════════════════════════════════════════════════════════
## TOOL REGISTRY
## ═══════════════════════════════════════════════════════════════════════════════

const TOOL_DEFINITIONS := {
	"bash": {
		"description": "Execute a bash command. Use for file operations, git, npm, pip, etc.",
		"parameters": {
			"type": "object",
			"properties": {
				"command": {
					"type": "string",
					"description": "The bash command to execute"
				},
				"timeout": {
					"type": "integer",
					"description": "Timeout in seconds (default: 30)",
					"default": 30
				}
			},
			"required": ["command"]
		}
	},

	"write_file": {
		"description": "Write content to a file in the workspace",
		"parameters": {
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Relative path within workspace"
				},
				"content": {
					"type": "string",
					"description": "Content to write"
				}
			},
			"required": ["path", "content"]
		}
	},

	"read_file": {
		"description": "Read content from a file",
		"parameters": {
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Relative path within workspace"
				}
			},
			"required": ["path"]
		}
	},

	"list_dir": {
		"description": "List files in a directory",
		"parameters": {
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Directory path (default: workspace root)",
					"default": "."
				}
			},
			"required": []
		}
	},

	"web_search": {
		"description": "Search the web for information",
		"parameters": {
			"type": "object",
			"properties": {
				"query": {
					"type": "string",
					"description": "Search query"
				},
				"max_results": {
					"type": "integer",
					"description": "Maximum results (default: 5)",
					"default": 5
				}
			},
			"required": ["query"]
		}
	},

	"fetch_url": {
		"description": "Fetch content from a URL",
		"parameters": {
			"type": "object",
			"properties": {
				"url": {
					"type": "string",
					"description": "URL to fetch"
				}
			},
			"required": ["url"]
		}
	},

	"spawn": {
		"description": "Spawn a sub-Meeseeks to handle a subtask",
		"parameters": {
			"type": "object",
			"properties": {
				"task": {
					"type": "string",
					"description": "Task for the sub-Meeseeks"
				}
			},
			"required": ["task"]
		}
	},

	"api_call": {
		"description": "Make an HTTP API call",
		"parameters": {
			"type": "object",
			"properties": {
				"method": {
					"type": "string",
					"description": "HTTP method (GET, POST, PUT, DELETE)",
					"enum": ["GET", "POST", "PUT", "DELETE"]
				},
				"url": {
					"type": "string",
					"description": "API URL"
				},
				"headers": {
					"type": "object",
					"description": "Request headers"
				},
				"body": {
					"type": "object",
					"description": "Request body (for POST/PUT)"
				}
			},
			"required": ["method", "url"]
		}
	},

	"python": {
		"description": "Execute Python code",
		"parameters": {
			"type": "object",
			"properties": {
				"code": {
					"type": "string",
					"description": "Python code to execute"
				}
			},
			"required": ["code"]
		}
	},

	"git": {
		"description": "Execute a git command",
		"parameters": {
			"type": "object",
			"properties": {
				"command": {
					"type": "string",
					"description": "Git command (e.g., 'commit -m \"message\"')"
				}
			},
			"required": ["command"]
		}
	},

	"npm": {
		"description": "Execute an npm command",
		"parameters": {
			"type": "object",
			"properties": {
				"command": {
					"type": "string",
					"description": "npm command (e.g., 'install express')"
				}
			},
			"required": ["command"]
		}
	},

	"pip": {
		"description": "Execute a pip command",
		"parameters": {
			"type": "object",
			"properties": {
				"command": {
					"type": "string",
					"description": "pip command (e.g., 'install requests')"
				}
			},
			"required": ["command"]
		}
	},

	"complete": {
		"description": "Signal task completion and despawn",
		"parameters": {
			"type": "object",
			"properties": {
				"result": {
					"type": "string",
					"description": "Summary of what was accomplished"
				}
			},
			"required": ["result"]
		}
	}
}


## Get tool definitions for LLM function calling
func get_tool_definitions() -> Array:
	var tools = []
	for tool_name in TOOL_DEFINITIONS.keys():
		var tool = TOOL_DEFINITIONS[tool_name].duplicate()
		tool["name"] = tool_name
		tools.append(tool)
	return tools


## Get tool definitions as OpenAI-style function array
func get_openai_tools() -> Array:
	var tools = []
	for tool_name in TOOL_DEFINITIONS.keys():
		tools.append({
			"type": "function",
			"function": {
				"name": tool_name,
				"description": TOOL_DEFINITIONS[tool_name]["description"],
				"parameters": TOOL_DEFINITIONS[tool_name]["parameters"]
			}
		})
	return tools


## ═══════════════════════════════════════════════════════════════════════════════
## TOOL EXECUTION
## ═══════════════════════════════════════════════════════════════════════════════

## Execute a tool call
func execute_tool(meeseeks_id: String, tool_name: String, params: Dictionary) -> Dictionary:
	print("[MeeseeksTools] %s executing: %s" % [meeseeks_id, tool_name])

	var result := {"success": false, "output": "", "error": ""}

	match tool_name:
		"bash":
			result = _tool_bash(meeseeks_id, params)
		"write_file":
			result = _tool_write_file(meeseeks_id, params)
		"read_file":
			result = _tool_read_file(meeseeks_id, params)
		"list_dir":
			result = _tool_list_dir(meeseeks_id, params)
		"web_search":
			result = _tool_web_search(meeseeks_id, params)
		"fetch_url":
			result = _tool_fetch_url(meeseeks_id, params)
		"spawn":
			result = _tool_spawn(meeseeks_id, params)
		"api_call":
			result = _tool_api_call(meeseeks_id, params)
		"python":
			result = _tool_python(meeseeks_id, params)
		"git":
			result = _tool_git(meeseeks_id, params)
		"npm":
			result = _tool_npm(meeseeks_id, params)
		"pip":
			result = _tool_pip(meeseeks_id, params)
		"complete":
			result = _tool_complete(meeseeks_id, params)
		_:
			result.error = "Unknown tool: %s" % tool_name

	tool_executed.emit(meeseeks_id, tool_name, params, result)
	return result


## ═══════════════════════════════════════════════════════════════════════════════
## TOOL IMPLEMENTATIONS
## ═══════════════════════════════════════════════════════════════════════════════

## Bash execution
func _tool_bash(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var command = params.get("command", "")
	if command.is_empty():
		return {"success": false, "error": "No command provided"}

	var timeout = params.get("timeout", 30)

	print("[MeeseeksTools] 🔧 Bash: %s" % command.left(60))

	var output = []
	var exit_code = OS.execute("bash", ["-c", command], output, true, false)

	var result = {
		"success": exit_code == 0,
		"output": "\n".join(output),
		"exit_code": exit_code,
		"command": command
	}

	bash_executed.emit(meeseeks_id, command, result.output, exit_code)

	if exit_code != 0:
		print("[MeeseeksTools] ❌ Exit code: %d" % exit_code)
	else:
		print("[MeeseeksTools] ✅ Success")

	return result


## Write file
func _tool_write_file(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var path = params.get("path", "")
	var content = params.get("content", "")

	if path.is_empty():
		return {"success": false, "error": "No path provided"}

	# Ensure workspace exists
	var workspace = _workspace_base + meeseeks_id
	DirAccess.make_dir_recursive_absolute(workspace)

	# Sanitize path (no .. or absolute paths)
	path = path.replace("..", "").strip_edges()
	if path.begins_with("/") or path.begins_with("C:"):
		path = path.get_file()

	var full_path = workspace + "/" + path

	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "Cannot write to: %s" % full_path}

	file.store_string(content)
	file.close()

	var result = {
		"success": true,
		"path": full_path,
		"size": content.length()
	}

	file_written.emit(meeseeks_id, full_path, content.length())
	print("[MeeseeksTools] 📝 Wrote %d bytes to %s" % [content.length(), path])

	return result


## Read file
func _tool_read_file(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	if path.is_empty():
		return {"success": false, "error": "No path provided"}

	var workspace = _workspace_base + meeseeks_id

	# Sanitize path
	path = path.replace("..", "").strip_edges()
	if path.begins_with("/") or path.begins_with("C:"):
		path = path.get_file()

	var full_path = workspace + "/" + path

	if not FileAccess.file_exists(full_path):
		return {"success": false, "error": "File not found: %s" % path}

	var file = FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot read: %s" % full_path}

	var content = file.get_as_text()
	file.close()

	var result = {
		"success": true,
		"path": full_path,
		"content": content
	}

	file_read.emit(meeseeks_id, full_path, content)
	print("[MeeseeksTools] 📖 Read %d bytes from %s" % [content.length(), path])

	return result


## List directory
func _tool_list_dir(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var path = params.get("path", ".")
	var workspace = _workspace_base + meeseeks_id

	path = path.replace("..", "").strip_edges()
	var full_path = workspace + "/" + path

	if not DirAccess.dir_exists_absolute(full_path):
		return {"success": false, "error": "Directory not found: %s" % path}

	var dir = DirAccess.open(full_path)
	if dir == null:
		return {"success": false, "error": "Cannot open: %s" % full_path}

	var files = []
	var dirs = []

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		if dir.current_is_dir():
			dirs.append(file_name + "/")
		else:
			files.append(file_name)

		file_name = dir.get_next()
	dir.list_dir_end()

	return {
		"success": true,
		"path": path,
		"files": files,
		"directories": dirs,
		"total": files.size() + dirs.size()
	}


## Web search
func _tool_web_search(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var query = params.get("query", "")
	if query.is_empty():
		return {"success": false, "error": "No query provided"}

	var max_results = params.get("max_results", 5)

	print("[MeeseeksTools] 🔍 Searching: %s" % query)

	# Use SearXNG if available, otherwise DuckDuckGo
	var search_url = _searxng_endpoint + "?q=" + query.uri_encode() + "&format=json"

	var http = HTTPRequest.new()
	http.name = "Search_%s" % meeseeks_id
	add_child(http)

	var error = http.request(search_url, [], HTTPClient.METHOD_GET)
	if error != OK:
		# Fallback to DuckDuckGo instant answer
		search_url = "https://api.duckduckgo.com/?q=" + query.uri_encode() + "&format=json"
		error = http.request(search_url, [], HTTPClient.METHOD_GET)

	# For now, return a mock result since we can't await in sync
	# In production, this would be async
	var results = [
		{"title": "Search result for: %s" % query, "snippet": "Relevant information...", "url": "https://example.com"}
	]

	web_searched.emit(meeseeks_id, query, results)

	return {
		"success": true,
		"query": query,
		"results": results
	}


## Fetch URL
func _tool_fetch_url(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var url = params.get("url", "")
	if url.is_empty():
		return {"success": false, "error": "No URL provided"}

	# Validate URL
	if not url.begins_with("http://") and not url.begins_with("https://"):
		return {"success": false, "error": "Invalid URL format"}

	var http = HTTPRequest.new()
	http.name = "Fetch_%s" % meeseeks_id
	add_child(http)

	var error = http.request(url, [], HTTPClient.METHOD_GET)

	# Return async handle
	return {
		"success": true,
		"url": url,
		"status": "fetching"
	}


## Spawn sub-Meeseeks
func _tool_spawn(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var task = params.get("task", "")
	if task.is_empty():
		return {"success": false, "error": "No task provided"}

	sub_meeseeks_requested.emit(meeseeks_id, task)

	return {
		"success": true,
		"task": task,
		"status": "spawning"
	}


## API call
func _tool_api_call(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var method = params.get("method", "GET")
	var url = params.get("url", "")
	var headers = params.get("headers", {})
	var body = params.get("body", {})

	if url.is_empty():
		return {"success": false, "error": "No URL provided"}

	var http = HTTPRequest.new()
	http.name = "API_%s" % meeseeks_id
	add_child(http)

	var header_array = []
	for key in headers.keys():
		header_array.append("%s: %s" % [key, str(headers[key])])

	var body_str = JSON.stringify(body) if not body.is_empty() else ""
	var http_method = HTTPClient.METHOD_GET

	match method.to_upper():
		"POST": http_method = HTTPClient.METHOD_POST
		"PUT": http_method = HTTPClient.METHOD_PUT
		"DELETE": http_method = HTTPClient.METHOD_DELETE

	var error = http.request(url, header_array, http_method, body_str)

	return {
		"success": error == OK,
		"method": method,
		"url": url,
		"status": "pending"
	}


## Python execution
func _tool_python(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var code = params.get("code", "")
	if code.is_empty():
		return {"success": false, "error": "No code provided"}

	# Write code to temp file
	var workspace = _workspace_base + meeseeks_id
	DirAccess.make_dir_recursive_absolute(workspace)

	var script_path = workspace + "/temp_script.py"
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string(code)
	file.close()

	# Execute Python
	var output = []
	var exit_code = OS.execute("python", [script_path], output, true, false)

	return {
		"success": exit_code == 0,
		"output": "\n".join(output),
		"exit_code": exit_code
	}


## Git command
func _tool_git(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var command = params.get("command", "")
	if command.is_empty():
		return {"success": false, "error": "No command provided"}

	# Execute git command
	var output = []
	var exit_code = OS.execute("git", command.split(" "), output, true, false)

	return {
		"success": exit_code == 0,
		"output": "\n".join(output),
		"exit_code": exit_code
	}


## npm command
func _tool_npm(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var command = params.get("command", "")
	if command.is_empty():
		return {"success": false, "error": "No command provided"}

	var output = []
	var exit_code = OS.execute("npm", command.split(" "), output, true, false)

	return {
		"success": exit_code == 0,
		"output": "\n".join(output),
		"exit_code": exit_code
	}


## pip command
func _tool_pip(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var command = params.get("command", "")
	if command.is_empty():
		return {"success": false, "error": "No command provided"}

	var output = []
	var exit_code = OS.execute("pip", command.split(" "), output, true, false)

	return {
		"success": exit_code == 0,
		"output": "\n".join(output),
		"exit_code": exit_code
	}


## Complete task
func _tool_complete(meeseeks_id: String, params: Dictionary) -> Dictionary:
	var result = params.get("result", "Task completed")

	return {
		"success": true,
		"result": result,
		"action": "complete"
	}


## ═══════════════════════════════════════════════════════════════════════════════
## PARSING UTILITIES
## ═══════════════════════════════════════════════════════════════════════════════

## Parse tool calls from LLM response (handles various formats)
func parse_tool_calls(response: String) -> Array:
	var tool_calls = []

	# Try JSON function call format
	var json_regex = RegEx.new()
	json_regex.compile("\\{\\s*\"tool\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"params\"\\s*:\\s*(\\{[^}]*\\})\\s*\\}")

	var matches = json_regex.search_all(response)
	for match in matches:
		var tool_name = match.get_string(1)
		var params_str = match.get_string(2)

		var json = JSON.new()
		if json.parse(params_str) == OK:
			tool_calls.append({
				"tool": tool_name,
				"params": json.data
			})

	# Try inline command format (e.g., "BASH: ls -la")
	if tool_calls.is_empty():
		var inline_patterns = {
			"BASH:": "bash",
			"WRITE:": "write_file",
			"READ:": "read_file",
			"SEARCH:": "web_search",
			"SPAWN:": "spawn",
			"COMPLETE:": "complete",
			"FETCH:": "fetch_url",
			"API:": "api_call"
		}

		for pattern in inline_patterns.keys():
			if pattern in response:
				var start = response.find(pattern) + pattern.length()
				var end = response.find("\n", start)
				if end == -1:
					end = response.length()

				var content = response.substr(start, end - start).strip_edges()

				var tool_name = inline_patterns[pattern]
				var params = {}

				match tool_name:
					"bash":
						params = {"command": content}
					"write_file":
						var parts = content.split(":", true, 1)
						params = {"path": parts[0].strip_edges(), "content": parts[1] if parts.size() > 1 else ""}
					"web_search":
						params = {"query": content}
					"spawn":
						params = {"task": content}
					"complete":
						params = {"result": content}
					"fetch_url":
						params = {"url": content}
					_:
						params = {"content": content}

				tool_calls.append({"tool": tool_name, "params": params})

	return tool_calls


## Set workspace base
func set_workspace_base(path: String) -> void:
	_workspace_base = path
	DirAccess.make_dir_recursive_absolute(_workspace_base)
