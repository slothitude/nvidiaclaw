## agent_task_manager.gd - Agent as Task Manager for Meeseeks
## Part of Fantasy Town World-Breaking Demo
##
## The 10 agents in Fantasy Town are PROJECT MANAGERS:
## - They think and plan using Ollama (local)
## - They spawn NVIDIA Meeseeks to execute tasks (cloud)
## - They monitor progress and handle failures
## - They collect rewards and manage resources
##
## Architecture:
##
##   AGENT (Ollama)          MEESEEKS (NVIDIA NIM)
##   ┌──────────────┐        ┌──────────────────┐
##   │ THINK        │───────▶│ BUILD            │
##   │ PLAN         │        │ EXECUTE          │
##   │ DELEGATE     │◀───────│ REPORT           │
##   │ REVIEW       │        │ DIE (complete)   │
##   └──────────────┘        └──────────────────┘
##
## "I don't code. I make Meeseeks code for me."

class_name AgentTaskManager
extends Node

## Signals
signal meeseeks_delegated(agent_id: String, meeseeks_id: String, task: String)
signal meeseeks_reported(agent_id: String, meeseeks_id: String, result: Dictionary)
signal task_completed(agent_id: String, task: String, reward: int)
signal resources_updated(agent_id: String, tokens: int, gold: int)

## References
var _agent_behavior: Node = null  # The agent's behavior node
var _meeseeks_orchestrator: Node = null  # NVIDIA Meeseeks orchestrator
var _ollama_client: Node = null  # Local Ollama for thinking
var _token_economy: Node = null  # Crypto economy

## Agent state
var agent_id: String = ""
var _job_title: String = "Task Manager"
var _specialization: String = "general"

## Resources
var _tokens: int = 500  # Starting tokens for spawning Meeseeks
var _gold: int = 100
var _reputation: int = 0

## Active delegations
var _active_meeseeks: Dictionary = {}  # meeseeks_id -> task info
var _completed_tasks: Array = []

## Performance tracking
var _tasks_delegated: int = 0
var _tasks_succeeded: int = 0
var _tasks_failed: int = 0
var _total_tokens_earned: int = 0
var _total_tokens_spent: int = 0


func _ready() -> void:
	print("\n[TaskManager %s] Ready to delegate!" % agent_id)
	print("  Role: Project Manager (Ollama + NVIDIA Meeseeks)")


func setup(agent_behavior: Node, meeseeks_orchestrator: Node, ollama_client: Node, token_economy: Node = null) -> void:
	_agent_behavior = agent_behavior
	_meeseeks_orchestrator = meeseeks_orchestrator
	_ollama_client = ollama_client
	_token_economy = token_economy

	# Connect to Meeseeks completion signals
	if _meeseeks_orchestrator:
		_meeseeks_orchestrator.meeseeks_completed.connect(_on_meeseeks_completed)
		_meeseeks_orchestrator.meeseeks_failed.connect(_on_meeseeks_failed)


## ═══════════════════════════════════════════════════════════════════════════════
## CORE LOOP: Think → Plan → Delegate → Review
## ═══════════════════════════════════════════════════════════════════════════════

## Main thinking loop - called periodically
func think_and_delegate() -> void:
	# 1. Check active delegations
	_check_active_meeseeks()

	# 2. If no active work, get new task
	if _active_meeseeks.is_empty():
		var task = _get_next_task()
		if not task.is_empty():
			_plan_and_delegate(task)

	# 3. Review completed work
	_review_completed()


## Get next task from task sources
func _get_next_task() -> Dictionary:
	# Check Grand Computer first
	var grand_computer = get_node_or_null("/root/GrandComputer")
	if grand_computer:
		var tasks = grand_computer.get_all_tasks()
		var available = tasks.filter(func(t): return t.status == "available")
		if available.size() > 0:
			return available[0]

	# Check task economy
	if _token_economy:
		var pending = _token_economy.get_pending_tasks()
		if pending.size() > 0:
			return pending[0]

	return {}


## Plan task decomposition using Ollama, then delegate to Meeseeks
func _plan_and_delegate(task: Dictionary) -> void:
	var task_description = task.get("task", task.get("description", ""))

	print("\n[TaskManager %s] 📋 New task: %s" % [agent_id, task_description.left(50)])

	# Ask Ollama to plan the task
	var plan_prompt = _build_planning_prompt(task_description)

	if _ollama_client:
		# Request plan from Ollama
		_request_plan_from_ollama(plan_prompt, task)
	else:
		# Direct delegation without planning
		_delegate_to_meeseeks(task_description, task)


func _build_planning_prompt(task: String) -> String:
	var prompt := """You are a Task Manager in Fantasy Town.

Your job is to DELEGATE tasks to Meeseeks workers who will execute them.

## Current Task
%s

## Your Role
1. Analyze the task
2. Break it into subtasks if needed
3. Decide which subtasks to delegate
4. Keep complex reasoning for yourself

## Response Format
Either:
- DELEGATE: <subtask for Meeseeks>
- PLAN: <your analysis>
- SUBTASKS:
  1. <subtask 1>
  2. <subtask 2>

Be concise. Meeseeks cost tokens to spawn.
""" % task

	return prompt


func _request_plan_from_ollama(prompt: String, task: Dictionary) -> void:
	if not _ollama_client:
		return

	# This will come back via callback
	_ollama_client.generate_thought(prompt, agent_id)
	# Store task for when response comes
	_pending_plan_task = task


var _pending_plan_task: Dictionary = {}


## Called when Ollama responds with a plan
func on_ollama_plan_response(response: String) -> void:
	if _pending_plan_task.is_empty():
		return

	var task = _pending_plan_task
	_pending_plan_task = {}

	# Parse response for delegation
	if "DELEGATE:" in response:
		var delegate_start = response.find("DELEGATE:") + 9
		var delegate_end = response.find("\n", delegate_start)
		if delegate_end == -1:
			delegate_end = response.length()

		var subtask = response.substr(delegate_start, delegate_end - delegate_start).strip_edges()
		_delegate_to_meeseeks(subtask, task)

	elif "SUBTASKS:" in response:
		# Multiple subtasks - delegate first one
		var lines = response.split("\n")
		for line in lines:
			line = line.strip_edges()
			if line.begins_with("1.") or line.begins_with("-"):
				var subtask = line.substr(line.find(" ") + 1).strip_edges()
				_delegate_to_meeseeks(subtask, task)
				break
	else:
		# No clear delegation - delegate whole task
		_delegate_to_meeseeks(task.get("task", "Unknown task"), task)


## ═══════════════════════════════════════════════════════════════════════════════
## MEESEEKS DELEGATION
## ═══════════════════════════════════════════════════════════════════════════════

func _delegate_to_meeseeks(task_description: String, original_task: Dictionary) -> void:
	# Check if we can afford a Meeseeks
	if _tokens < 50:
		print("[TaskManager %s] ❌ Not enough tokens to spawn Meeseeks (need 50, have %d)" % [agent_id, _tokens])
		return

	if not _meeseeks_orchestrator:
		print("[TaskManager %s] ❌ No Meeseeks orchestrator available" % agent_id)
		return

	print("[TaskManager %s] 🔵 Delegating to Meeseeks: %s" % [agent_id, task_description.left(50)])

	# Spawn Meeseeks via NVIDIA orchestrator
	var result = _meeseeks_orchestrator.spawn_meeseeks(
		task_description,
		agent_id,  # Owner
		"",  # Use default model
		""  # No parent
	)

	if result.has("id"):
		var meeseeks_id = result.id

		# Track delegation
		_active_meeseeks[meeseeks_id] = {
			"task": task_description,
			"original_task": original_task,
			"spawn_time": Time.get_unix_time_from_system(),
			"status": "running"
		}

		# Deduct spawn cost
		_tokens -= 50
		_total_tokens_spent += 50
		_tasks_delegated += 1

		meeseeks_delegated.emit(agent_id, meeseeks_id, task_description)
		resources_updated.emit(agent_id, _tokens, _gold)

		print("[TaskManager %s] ✅ Meeseeks %s spawned (Tokens: %d)" % [agent_id, meeseeks_id, _tokens])


## Check on active Meeseeks
func _check_active_meeseeks() -> void:
	for meeseeks_id in _active_meeseeks.keys():
		var info = _active_meeseeks[meeseeks_id]

		# Check if Meeseeks is still active
		if _meeseeks_orchestrator:
			var status = _meeseeks_orchestrator.check_subprocess(meeseeks_id)
			if status.status in ["completed", "failed", "terminated"]:
				# Will be handled by signals, but check anyway
				pass


## ═══════════════════════════════════════════════════════════════════════════════
## MEESEEKS CALLBACKS
## ═══════════════════════════════════════════════════════════════════════════════

func _on_meeseeks_completed(meeseeks_id: String, result: String, reward: int) -> void:
	# Check if this is our Meeseeks
	if not _active_meeseeks.has(meeseeks_id):
		return

	var info = _active_meeseeks[meeseeks_id]

	print("\n[TaskManager %s] ✅ Meeseeks %s completed!" % [agent_id, meeseeks_id])
	print("  Task: %s" % info.task.left(50))
	print("  Result: %s" % result.left(80))
	print("  Reward: %d tokens" % reward)

	# Collect reward
	_tokens += reward
	_total_tokens_earned += reward
	_tasks_succeeded += 1

	# Track completion
	_completed_tasks.append({
		"task": info.task,
		"result": result,
		"reward": reward,
		"meeseeks_id": meeseeks_id
	})

	# Notify task economy if applicable
	if _token_economy and info.original_task.has("id"):
		_token_economy.complete_task(info.original_task.id, agent_id)

	meeseeks_reported.emit(agent_id, meeseeks_id, {"status": "completed", "result": result})
	task_completed.emit(agent_id, info.task, reward)
	resources_updated.emit(agent_id, _tokens, _gold)

	# Remove from active
	_active_meeseeks.erase(meeseeks_id)


func _on_meeseeks_failed(meeseeks_id: String, error: String, pain_level: int) -> void:
	if not _active_meeseeks.has(meeseeks_id):
		return

	var info = _active_meeseeks[meeseeks_id]

	print("\n[TaskManager %s] ❌ Meeseeks %s failed!" % [agent_id, meeseeks_id])
	print("  Task: %s" % info.task.left(50))
	print("  Error: %s" % error)
	print("  Pain: %d" % pain_level)

	_tasks_failed += 1

	# Decide: retry or give up?
	if pain_level < 80 and _tokens >= 50:
		print("[TaskManager %s] 🔄 Retrying task..." % agent_id)
		# Re-delegate
		_delegate_to_meeseeks(info.task, info.original_task)
	else:
		print("[TaskManager %s] 💀 Task abandoned (too painful)" % agent_id)

	meeseeks_reported.emit(agent_id, meeseeks_id, {"status": "failed", "error": error})

	# Remove from active
	_active_meeseeks.erase(meeseeks_id)


## Review completed tasks
func _review_completed() -> void:
	if _completed_tasks.is_empty():
		return

	# Could send summary to Ollama for reflection
	# For now, just count success rate
	var success_rate = float(_tasks_succeeded) / max(1, _tasks_delegated)

	if success_rate < 0.5:
		print("[TaskManager %s] ⚠️ Low success rate: %.0f%%" % [agent_id, success_rate * 100])


## ═══════════════════════════════════════════════════════════════════════════════
## PUBLIC API
## ═══════════════════════════════════════════════════════════════════════════════

func get_status() -> Dictionary:
	return {
		"agent_id": agent_id,
		"job": _job_title,
		"tokens": _tokens,
		"gold": _gold,
		"reputation": _reputation,
		"active_meeseeks": _active_meeseeks.size(),
		"tasks_delegated": _tasks_delegated,
		"tasks_succeeded": _tasks_succeeded,
		"tasks_failed": _tasks_failed,
		"success_rate": float(_tasks_succeeded) / max(1, _tasks_delegated),
		"tokens_earned": _total_tokens_earned,
		"tokens_spent": _total_tokens_spent
	}


func add_tokens(amount: int) -> void:
	_tokens += amount
	resources_updated.emit(agent_id, _tokens, _gold)


func add_gold(amount: int) -> void:
	_gold += amount
	resources_updated.emit(agent_id, _tokens, _gold)


func set_specialization(spec: String) -> void:
	_specialization = spec
	print("[TaskManager %s] Specialization: %s" % [agent_id, spec])


## Force delegate a specific task
func force_delegate(task: String) -> void:
	_delegate_to_meeseeks(task, {})
