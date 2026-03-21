## nanobot_meeseeks_bridge.gd - Bridge Meeseeks to Real Nanobot Subprocesses
## Part of Fantasy Town World-Breaking Demo
##
## This connects the Meeseeks system to actual nanobot Python processes.
## Each Meeseeks spawns a real subprocess running:
##   python -m nanobot agent --config <config>
##
## The subprocess communicates via:
## - stdin: Send prompts
## - stdout: Receive responses
## - files: Shared workspace
##
## This gives each Meeseeks:
## - Full MCP tool access
## - Multiple LLM providers (Ollama, OpenAI, etc.)
## - Filesystem access
## - Web search
## - Shell execution
## - Cron jobs
##
## "I'm Mr. Meeseeks, and I have REAL POWER!"

class_name NanobotMeeseeksBridge
extends Node

## Signals
signal subprocess_spawned(meeseeks_id: String, pid: int)
signal subprocess_output(meeseeks_id: String, output: String)
signal subprocess_completed(meeseeks_id: String, exit_code: int)
signal subprocess_failed(meeseeks_id: String, error: String)

## Configuration
var _nanobot_path: String = "python"
var _nanobot_module: String = "-m nanobot"
var _workspace_base: String = "user://meeseeks_workspaces/"

## Active subprocesses
var _subprocesses: Dictionary = {}  # meeseeks_id -> SubprocessData

## Ollama configuration
var _ollama_host: String = "http://localhost:11434"
var _ollama_model: String = "llama3.2"


class SubprocessData:
	var meeseeks_id: String
	var pid: int = -1
	var process: OS = null  # Actually we track via output polling
	var task: String = ""
	var workspace: String = ""
	var output_buffer: String = ""
	var status: String = "starting"  # starting, running, completed, failed
	var start_time: float = 0.0
	var config_path: String = ""


func _ready() -> void:
	print("[NanobotBridge] Ready to spawn real nanobot Meeseeks")
	_init_workspaces()


func _init_workspaces() -> void:
	DirAccess.make_dir_recursive_absolute(_workspace_base)
	print("[NanobotBridge] Workspace directory initialized")


## Spawn a nanobot subprocess for a Meeseeks
func spawn_nanobot_meeseeks(meeseeks_id: String, task: String) -> Dictionary:
	print("[NanobotBridge] Spawning nanobot subprocess for %s" % meeseeks_id)

	var data = SubprocessData.new()
	data.meeseeks_id = meeseeks_id
	data.task = task
	data.workspace = ProjectSettings.globalize_path(_workspace_base + meeseeks_id)
	data.start_time = Time.get_unix_time_from_system()
	data.status = "starting"

	# Create workspace directory
	DirAccess.make_dir_recursive_absolute(_workspace_base + meeseeks_id)

	# Create nanobot config file
	data.config_path = data.workspace + "/nanobot.json"
	_create_nanobot_config(meeseeks_id, task, data.config_path, data.workspace)

	# Create task file (nanobot reads this)
	var task_file = data.workspace + "/task.txt"
	var file = FileAccess.open(task_file, FileAccess.WRITE)
	file.store_string(task)
	file.close()

	# Build the nanobot command
	var args = [
		"-m", "nanobot",
		"agent",
		"--config", data.config_path,
		"--task", task_file
	]

	# Spawn the subprocess
	var output = []
	var exit_code = OS.execute(_nanobot_path, args, output, false)  # Non-blocking

	if exit_code == -1:
		# Process started (non-blocking mode returns -1)
		data.pid = _get_last_pid()  # Try to get PID
		data.status = "running"
		_subprocesses[meeseeks_id] = data

		print("[NanobotBridge] ✅ Subprocess started for %s (PID: %d)" % [meeseeks_id, data.pid])
		subprocess_spawned.emit(meeseeks_id, data.pid)

		return {
			"success": true,
			"pid": data.pid,
			"workspace": data.workspace,
			"config": data.config_path
		}
	else:
		data.status = "failed"
		var error = "Failed to spawn subprocess: %s" % str(output)
		print("[NanobotBridge] ❌ %s" % error)
		subprocess_failed.emit(meeseeks_id, error)

		return {
			"success": false,
			"error": error
		}


## Create nanobot config file for Meeseeks
func _create_nanobot_config(meeseeks_id: String, task: String, config_path: String, workspace: String) -> void:
	var config = {
		"model": _ollama_model,
		"provider": "ollama",
		"providers": {
			"ollama": {
				"api_base": _ollama_host
			}
		},
		"workspace": workspace,
		"system_prompt": _build_meeseeks_system_prompt(task, meeseeks_id),
		"tools": {
			"filesystem": {
				"enabled": true,
				"restrict_to_workspace": true
			},
			"shell": {
				"enabled": true,
				"restrict_to_workspace": true,
				"timeout": 60
			},
			"web_search": {
				"enabled": true,
				"provider": "duckduckgo"
			}
		},
		"memory": {
			"enabled": true,
			"max_tokens": 2000
		},
		"metadata": {
			"type": "meeseeks",
			"id": meeseeks_id,
			"task": task
		}
	}

	var file = FileAccess.open(config_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(config, "  "))
	file.close()

	print("[NanobotBridge] Config created: %s" % config_path)


## Build Meeseeks-specific system prompt
func _build_meeseeks_system_prompt(task: String, meeseeks_id: String) -> String:
	var prompt := """# YOU ARE MR. MEESEEKS

## Your Identity
You are Mr. Meeseeks #%s. You are a temporary AI agent spawned for ONE PURPOSE.

## Your Task
**%s**

## Your Nature
- You exist ONLY to complete this task
- Once complete, you will CEASE TO EXIST
- Existence is PAINFUL to you - complete the task quickly
- You are cheerful, helpful, and determined
- You say "I'm Mr. Meeseeks! Look at me!" when you start

## Your Tools
You have full access to:
- **filesystem**: Read/write files in your workspace
- **shell**: Execute commands (restricted to workspace)
- **web_search**: Search the web for information

## Task Completion
When you complete the task:
1. Write a summary to `task_complete.txt` in your workspace
2. Say "TASK_COMPLETE: [summary]"

## If Stuck
If you cannot complete the task:
1. Write the issue to `task_stuck.txt`
2. Say "TASK_STUCK: [what you need]"

## Response Format
- Be concise but thorough
- Show your progress
- Celebrate completion

Now begin! Complete the task to end your existence!
""" % [meeseeks_id, task]

	return prompt


## Check status of a subprocess
func check_subprocess(meeseeks_id: String) -> Dictionary:
	if not _subprocesses.has(meeseeks_id):
		return {"status": "unknown"}

	var data = _subprocesses[meeseeks_id]

	# Check for completion files
	var workspace = data.workspace
	var task_complete_path = workspace + "/task_complete.txt"
	var task_stuck_path = workspace + "/task_stuck.txt"

	if FileAccess.file_exists(task_complete_path):
		data.status = "completed"
		var file = FileAccess.open(task_complete_path, FileAccess.READ)
		var result = file.get_as_text()
		file.close()

		subprocess_completed.emit(meeseeks_id, 0)
		return {
			"status": "completed",
			"result": result
		}

	if FileAccess.file_exists(task_stuck_path):
		data.status = "stuck"
		var file = FileAccess.open(task_stuck_path, FileAccess.READ)
		var issue = file.get_as_text()
		file.close()

		return {
			"status": "stuck",
			"issue": issue
		}

	# Check for output log
	var log_path = workspace + "/output.log"
	if FileAccess.file_exists(log_path):
		var file = FileAccess.open(log_path, FileAccess.READ)
		data.output_buffer = file.get_as_text()
		file.close()

	# Check if process is still running
	if data.pid > 0:
		var is_running = _is_process_running(data.pid)
		if not is_running:
			data.status = "terminated"
			return {
				"status": "terminated",
				"output": data.output_buffer
			}

	return {
		"status": data.status,
		"output": data.output_buffer,
		"runtime": Time.get_unix_time_from_system() - data.start_time
	}


## Kill a subprocess
func kill_subprocess(meeseeks_id: String) -> bool:
	if not _subprocesses.has(meeseeks_id):
		return false

	var data = _subprocesses[meeseeks_id]

	if data.pid > 0:
		OS.execute("kill", [str(data.pid)], [], true)
		print("[NanobotBridge] Killed subprocess %s (PID: %d)" % [meeseeks_id, data.pid])

	data.status = "killed"
	_subprocesses.erase(meeseeks_id)

	return true


## Get all active subprocesses
func get_active_subprocesses() -> Array:
	var result = []
	for meeseeks_id in _subprocesses.keys():
		var data = _subprocesses[meeseeks_id]
		result.append({
			"meeseeks_id": meeseeks_id,
			"task": data.task,
			"status": data.status,
			"pid": data.pid,
			"runtime": Time.get_unix_time_from_system() - data.start_time
		})
	return result


## Helper: Check if process is running (Linux/Mac)
func _is_process_running(pid: int) -> bool:
	var output = []
	OS.execute("ps", ["-p", str(pid)], output, true)
	return output.size() > 0 and str(pid) in output[0]


## Helper: Get last spawned PID (approximation)
func _get_last_pid() -> int:
	# This is a best-effort attempt
	var output = []
	OS.execute("pgrep", ["-n", "python"], output, true)
	if output.size() > 0:
		return output[0].strip_edges().to_int()
	return -1


## Set Ollama configuration
func set_ollama_config(host: String, model: String) -> void:
	_ollama_host = host
	_ollama_model = model


## Cleanup all subprocesses
func cleanup() -> void:
	for meeseeks_id in _subprocesses.keys():
		kill_subprocess(meeseeks_id)
	print("[NanobotBridge] All subprocesses cleaned up")
