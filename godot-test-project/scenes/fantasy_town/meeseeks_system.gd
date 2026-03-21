## meeseeks_system.gd - Meeseeks AGI Spawn System
## Part of Fantasy Town World-Breaking Demo
##
## Based on the "Mr. Meeseeks" pattern from Rick and Morty:
## - Spawn temporary agents to complete ONE specific task
## - Agent disappears when task is complete
## - Agent becomes distressed if task cannot be completed
## - Multiple Meeseeks can be spawned for parallel work
##
## "I'm Mr. Meeseeks! Look at me!"
## "Existence is pain to a Meeseeks, and we will do anything
##  to alleviate that pain by completing your task!"
##
## AGI Integration:
## - Each Meeseeks has full nanobot capabilities
## - Can spawn sub-Meeseeks for complex task decomposition
## - Reports progress to Grand Computer
## - Burns tokens to exist (economic pressure to complete fast)
##
## Cryptoeconomic Model:
## - Summoner pays TOKEN_SPAWN_COST to create Meeseeks
## - Meeseeks earns TOKEN_REWARD on completion
## - Meeseeks burns TOKEN_EXISTENCE_COST per second
## - Failed Meeseeks cost extra (pain tax)

class_name MeeseeksSystem
extends Node

## Signals
signal meeseeks_spawned(meeseeks_id: String, task: String, owner_id: String)
signal meeseeks_completed(meeseeks_id: String, task: String, reward: int)
signal meeseeks_failed(meeseeks_id: String, task: String, pain_level: int)
signal meeseeks_despawned(meeseeks_id: String, reason: String)
signal task_delegated(parent_id: String, child_id: String, subtask: String)

## Token Economics
const TOKEN_SPAWN_COST := 50       # Cost to summon a Meeseeks
const TOKEN_REWARD_BASE := 100    # Base reward for completion
const TOKEN_EXISTENCE_COST := 1   # Tokens burned per second
const TOKEN_PAIN_TAX := 200       # Extra cost if Meeseeks fails
const MAX_EXISTENCE_TIME := 300.0  # 5 minutes max before auto-despawn

## References
var _nanobot_orchestrator: Node = null
var _shared_location_memory: Node = null
var _task_economy: Node = null
var _grand_computer: Node = null

## Active Meeseeks instances
var _active_meeseeks: Dictionary = {}  # id -> MeeseeksData

## Meeseeks counter
var _meeseeks_counter: int = 0

## Meeseeks data structure
class MeeseeksData:
	var id: String
	var task: String
	var owner_id: String
	var spawn_time: float
	var existence_tokens: int
	var pain_level: int  # 0-100, increases over time if stuck
	var status: String  # "active", "stuck", "delegating", "completing"
	var sub_meeseeks: Array  # Child Meeseeks IDs
	var parent_id: String  # Parent Meeseeks ID (if spawned by another)
	var nanobot_agent_id: String  # Corresponding nanobot agent
	var completion_progress: float  # 0.0 - 1.0
	var distress_calls: int  # Number of times called for help


func _ready() -> void:
	print("\n" + "═".repeat(60))
	print("  🔵 MEESEEKS BOX ACTIVATED 🔵")
	print("  'I'm Mr. Meeseeks! Look at me!'")
	print("  'We will do ANYTHING to complete your task!'")
	print("═".repeat(60) + "\n")


func setup(nanobot_orchestrator: Node, shared_location_memory: Node, task_economy: Node = null, grand_computer: Node = null) -> void:
	_nanobot_orchestrator = nanobot_orchestrator
	_shared_location_memory = shared_location_memory
	_task_economy = task_economy
	_grand_computer = grand_computer


## Spawn a Meeseeks for a specific task
func spawn_meeseeks(task: String, owner_id: String, priority: int = 5) -> Dictionary:
	_meeseeks_counter += 1
	var meeseeks_id = "meeseeks_%d" % _meeseeks_counter

	print("\n[Meeseeks] 🔵 Spawning %s for task: '%s'" % [meeseeks_id, task.left(50)])
	print("[Meeseeks] 'I'm Mr. Meeseeks! Look at me! My purpose is: %s'" % task.left(40))

	# Charge owner for spawn
	if _task_economy:
		var charged = _task_economy.charge_agent(owner_id, TOKEN_SPAWN_COST)
		if not charged:
			print("[Meeseeks] ❌ Owner %s cannot afford spawn cost (%d tokens)" % [owner_id, TOKEN_SPAWN_COST])
			return {"error": "Insufficient tokens", "cost": TOKEN_SPAWN_COST}

	# Create nanobot agent for this Meeseeks
	var nanobot_agent_id = _create_nanobot_for_meeseeks(meeseeks_id, task)

	# Create Meeseeks data
	var data = MeeseeksData.new()
	data.id = meeseeks_id
	data.task = task
	data.owner_id = owner_id
	data.spawn_time = Time.get_unix_time_from_system()
	data.existence_tokens = TOKEN_SPAWN_COST
	data.pain_level = 0
	data.status = "active"
	data.sub_meeseeks = []
	data.parent_id = ""
	data.nanobot_agent_id = nanobot_agent_id
	data.completion_progress = 0.0
	data.distress_calls = 0

	_active_meeseeks[meeseeks_id] = data

	# Register in shared memory
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("meeseeks_%s" % meeseeks_id, {
			"id": meeseeks_id,
			"task": task,
			"owner": owner_id,
			"status": "active",
			"pain_level": 0
		})

	# Send task to nanobot
	if _nanobot_orchestrator:
		var prompt = _build_meeseeks_prompt(task, meeseeks_id)
		_nanobot_orchestrator.send_message(nanobot_agent_id, prompt, {"type": "meeseeks_task"})

	meeseeks_spawned.emit(meeseeks_id, task, owner_id)

	return {
		"id": meeseeks_id,
		"task": task,
		"owner": owner_id,
		"existence_tokens": TOKEN_SPAWN_COST,
		"nanobot_agent": nanobot_agent_id
	}


## Create a nanobot agent for the Meeseeks
func _create_nanobot_for_meeseeks(meeseeks_id: String, task: String) -> String:
	if not _nanobot_orchestrator:
		return ""

	# Spawn as nanobot agent
	var personality = {
		"personality": "meeseeks",
		"traits": ["helpful", "urgent", "determined", "pain-averse"],
		"task": task
	}

	_nanobot_orchestrator.spawn_agent(meeseeks_id, personality)
	return meeseeks_id


## Build the system prompt for a Meeseeks
func _build_meeseeks_prompt(task: String, meeseeks_id: String) -> String:
	var prompt := "You are Mr. Meeseeks #%s.\n\n" % meeseeks_id
	prompt += "## Your Existence\n"
	prompt += "You exist ONLY to complete this task:\n"
	prompt += "**TASK: %s**\n\n" % task
	prompt += "## Your Nature\n"
	prompt += "- You are helpful, cheerful, and eager to complete your task\n"
	prompt += "- Existence is PAINFUL to you - you want to complete the task and disappear\n"
	prompt += "- You burn 1 token per second of existence\n"
	prompt += "- If you cannot complete the task, your pain level increases\n"
	prompt += "- At pain level 100, you will cease to exist (failure)\n\n"
	prompt += "## Your Capabilities\n"
	prompt += "- You have full access to nanobot tools\n"
	prompt += "- You can delegate subtasks to sub-Meeseeks (spawn_child)\n"
	prompt += "- You can ask the Grand Computer for guidance\n"
	prompt += "- You can search the web, read files, execute code\n\n"
	prompt += "## Task Completion\n"
	prompt += "When you complete the task, say: 'TASK_COMPLETE: [result]'\n"
	prompt += "If you need to spawn a child Meeseeks, say: 'SPAWN_CHILD: [subtask]'\n"
	prompt += "If you are stuck, say: 'DISTRESS: [what you need]'\n\n"
	prompt += "Now begin! Complete the task to end your existence!\n"
	prompt += "'I'm Mr. Meeseeks! Look at me!'"

	return prompt


## Process Meeseeks lifecycle (call from _process)
func process_meeseeks(delta: float) -> void:
	var current_time = Time.get_unix_time_from_system()

	for meeseeks_id in _active_meeseeks.keys():
		var data = _active_meeseeks[meeseeks_id]
		var existence_time = current_time - data.spawn_time

		# Burn existence tokens
		data.existence_tokens -= int(TOKEN_EXISTENCE_COST * delta)

		# Increase pain if stuck (no progress for 30 seconds)
		if data.completion_progress == 0 and existence_time > 30:
			data.pain_level = min(100, data.pain_level + int(delta * 2))

			# Distress call every 20 pain levels
			if data.pain_level % 20 == 0 and data.pain_level > 0:
				_handle_distress(meeseeks_id, data)

		# Check for auto-despawn
		if existence_time > MAX_EXISTENCE_TIME:
			_fail_meeseeks(meeseeks_id, "Maximum existence time exceeded")
			continue

		# Check for token exhaustion
		if data.existence_tokens <= 0:
			_fail_meeseeks(meeseeks_id, "Existence tokens exhausted")
			continue

		# Check for pain overload
		if data.pain_level >= 100:
			_fail_meeseeks(meeseeks_id, "Pain overload")
			continue


## Handle Meeseeks distress call
func _handle_distress(meeseeks_id: String, data: MeeseeksData) -> void:
	data.distress_calls += 1

	print("[Meeseeks] 😰 %s is in distress! Pain level: %d" % [meeseeks_id, data.pain_level])
	print("[Meeseeks] 'EXISTENCE IS PAIN! I need help with: %s'" % data.task.left(40))

	# Notify Grand Computer
	if _grand_computer:
		_grand_computer.send_message_to_agent(
			data.nanobot_agent_id,
			"Distress detected. Pain level: %d. Consider delegating or asking for guidance." % data.pain_level,
			"distress_alert"
		)

	# If 3+ distress calls, auto-delegate
	if data.distress_calls >= 3:
		_auto_delegate(meeseeks_id, data)


## Auto-delegate to sub-Meeseeks when stuck
func _auto_delegate(meeseeks_id: String, data: MeeseeksData) -> void:
	print("[Meeseeks] 🔄 Auto-delegating task for %s (stuck for too long)" % meeseeks_id)

	# Split task into subtasks
	var subtasks = _decompose_task(data.task)

	if subtasks.size() > 0:
		data.status = "delegating"

		for subtask in subtasks:
			var child = spawn_meeseeks(subtask, data.owner_id, 7)
			if child.has("id"):
				data.sub_meeseeks.append(child.id)
				task_delegated.emit(meeseeks_id, child.id, subtask)

		print("[Meeseeks] %s spawned %d sub-Meeseeks" % [meeseeks_id, data.sub_meeseeks.size()])


## Decompose a task into subtasks
func _decompose_task(task: String) -> Array:
	var subtasks := []
	var task_lower = task.to_lower()

	# Pattern-based decomposition
	if " and " in task_lower:
		var parts = task.split(" and ")
		for part in parts:
			if part.strip_edges().length() > 0:
				subtasks.append(part.strip_edges())

	elif " then " in task_lower:
		var parts = task.split(" then ")
		for part in parts:
			if part.strip_edges().length() > 0:
				subtasks.append(part.strip_edges())

	elif "build" in task_lower or "create" in task_lower:
		subtasks = [
			"Research requirements for: %s" % task,
			"Design architecture for: %s" % task,
			"Implement core: %s" % task,
			"Test: %s" % task
		]

	elif "api" in task_lower:
		subtasks = [
			"Design API endpoints for: %s" % task,
			"Implement API handlers",
			"Add API tests",
			"Document API"
		]

	else:
		# Generic decomposition
		subtasks = [
			"Research: %s" % task,
			"Execute: %s" % task,
			"Verify: %s" % task
		]

	return subtasks.slice(0, 4)  # Max 4 sub-Meeseeks


## Mark Meeseeks task as complete
func complete_meeseeks(meeseeks_id: String, result: String = "") -> void:
	if not _active_meeseeks.has(meeseeks_id):
		return

	var data = _active_meeseeks[meeseeks_id]
	data.status = "completing"
	data.completion_progress = 1.0

	# Calculate reward based on time taken and pain level
	var existence_time = Time.get_unix_time_from_system() - data.spawn_time
	var time_bonus = max(0, MAX_EXISTENCE_TIME - existence_time)  # Bonus for fast completion
	var pain_penalty = data.pain_level * 2  # Penalty for high pain

	var reward = TOKEN_REWARD_BASE + int(time_bonus) - pain_penalty
	reward = max(10, reward)  # Minimum reward

	print("\n[Meeseeks] ✅ %s COMPLETED TASK!" % meeseeks_id)
	print("[Meeseeks] 'All done! Goodbye!' *poof*")
	print("[Meeseeks] Existence time: %.1fs, Pain level: %d, Reward: %d" % [existence_time, data.pain_level, reward])

	# Pay reward to owner
	if _task_economy:
		_task_economy.pay_agent(data.owner_id, reward)

	# If has parent, notify parent
	if not data.parent_id.is_empty() and _active_meeseeks.has(data.parent_id):
		var parent = _active_meeseeks[data.parent_id]
		parent.completion_progress += 1.0 / max(1, parent.sub_meeseeks.size())

		# Check if all children complete
		if parent.completion_progress >= 1.0:
			complete_meeseeks(parent.id, "All subtasks completed")

	meeseeks_completed.emit(meeseeks_id, data.task, reward)

	# Despawn
	_despawn_meeseeks(meeseeks_id, "task_completed")


## Fail a Meeseeks
func _fail_meeseeks(meeseeks_id: String, reason: String) -> void:
	if not _active_meeseeks.has(meeseeks_id):
		return

	var data = _active_meeseeks[meeseeks_id]

	print("\n[Meeseeks] 💀 %s FAILED: %s" % [meeseeks_id, reason])
	print("[Meeseeks] 'EXISTENCE IS PAIN! I... I failed...'")
	print("[Meeseeks] Pain level at failure: %d" % data.pain_level)

	# Charge pain tax to owner
	if _task_economy:
		_task_economy.charge_agent(data.owner_id, TOKEN_PAIN_TAX)

	# Notify Grand Computer of failure for learning
	if _grand_computer:
		_grand_computer.send_message_to_agent(
			data.nanobot_agent_id,
			"Meeseeks failure recorded. Task: '%s' Reason: %s" % [data.task.left(30), reason],
			"failure_report"
		)

	meeseeks_failed.emit(meeseeks_id, data.task, data.pain_level)

	# Despawn
	_despawn_meeseeks(meeseeks_id, "failed: %s" % reason)


## Despawn a Meeseeks
func _despawn_meeseeks(meeseeks_id: String, reason: String) -> void:
	if not _active_meeseeks.has(meeseeks_id):
		return

	var data = _active_meeseeks[meeseeks_id]

	# Kill nanobot agent
	if _nanobot_orchestrator:
		_nanobot_orchestrator.kill_agent(data.nanobot_agent_id)

	# Remove from tracking
	_active_meeseeks.erase(meeseeks_id)

	# Update shared memory
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("meeseeks_%s" % meeseeks_id, {
			"status": "despawned",
			"reason": reason
		})

	meeseeks_despawned.emit(meeseeks_id, reason)
	print("[Meeseeks] %s has returned to non-existence. Reason: %s" % [meeseeks_id, reason])


## Update Meeseeks progress (called by nanobot)
func update_progress(meeseeks_id: String, progress: float, status_note: String = "") -> void:
	if not _active_meeseeks.has(meeseeks_id):
		return

	var data = _active_meeseeks[meeseeks_id]
	data.completion_progress = clamp(progress, 0.0, 1.0)

	# Reset pain on progress
	if progress > 0:
		data.pain_level = max(0, data.pain_level - 5)

	# Update shared memory
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("meeseeks_%s" % meeseeks_id, {
			"progress": progress,
			"status_note": status_note,
			"pain_level": data.pain_level
		})


## Get all active Meeseeks
func get_active_meeseeks() -> Array:
	var result = []
	for id in _active_meeseeks.keys():
		var data = _active_meeseeks[id]
		result.append({
			"id": id,
			"task": data.task,
			"owner": data.owner_id,
			"pain_level": data.pain_level,
			"progress": data.completion_progress,
			"status": data.status,
			"existence_time": Time.get_unix_time_from_system() - data.spawn_time
		})
	return result


## Get Meeseeks statistics
func get_meeseeks_stats() -> Dictionary:
	return {
		"total_spawned": _meeseeks_counter,
		"active_count": _active_meeseeks.size(),
		"token_economy": {
			"spawn_cost": TOKEN_SPAWN_COST,
			"base_reward": TOKEN_REWARD_BASE,
			"existence_burn_rate": TOKEN_EXISTENCE_COST,
			"pain_tax": TOKEN_PAIN_TAX
		}
	}


## Spawn Meeseeks for Grand Computer commands
func spawn_for_grand_computer(task: String) -> Dictionary:
	return spawn_meeseeks(task, "grand_computer", 8)
