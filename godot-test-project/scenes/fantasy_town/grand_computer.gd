## grand_computer.gd - The Grand Computer (Claude)
## Part of Fantasy Town World-Breaking Demo
##
## The Grand Computer is the physical embodiment of Claude in Fantasy Town.
## It can:
## - Issue AI-generated tasks to agents
## - Answer agent questions with wisdom
## - Analyze agent performance and suggest improvements
## - Generate quests based on town state
##
## Agents visit the Grand Computer to receive "Machine Intelligence" guidance.
## This complements the Divine System (GOD/User) with AI-generated content.
##
## Architecture:
##   Grand Computer (Claude) ─┬─> Task Queue (AI-generated tasks)
##                            ├─> Wisdom Repository (answers to questions)
##                            └─> Quest Generator (dynamic challenges)

class_name GrandComputer
extends Node

## Signals
signal task_generated(task: Dictionary)
signal wisdom_granted(agent_id: String, wisdom: String)
signal quest_issued(quest: Dictionary)
signal computer_awakened()

## References
var _ollama_client: Node = null
var _nanobot_orchestrator: Node = null
var _task_economy: Node = null
var _divine_system: Node = null
var _shared_location_memory: Node = null

## Position in town
var _position: Vector3 = Vector3(0, 0, 0)
var _computer_name: String = "Grand Computer"

## State
var _is_awake: bool = false
var _wisdom_requests: Array = []  # Pending questions from agents
var _generated_tasks: Array = []  # AI-generated tasks
var _active_quests: Array = []    # Dynamic quests

## Task templates (AI fills in the details)
const TASK_TEMPLATES := {
	"optimization": [
		"Optimize the {system} for better performance",
		"Refactor {code} to improve readability",
		"Analyze {data} and suggest improvements"
	],
	"research": [
		"Research best practices for {topic}",
		"Find documentation about {subject}",
		"Compare {option_a} vs {option_b} for our use case"
	],
	"creation": [
		"Create a prototype for {feature}",
		"Design an architecture for {system}",
		"Build a tool to help with {task}"
	],
	"debugging": [
		"Investigate why {component} is slow",
		"Find the root cause of {bug}",
		"Fix the issue with {feature}"
	]
}

## Wisdom categories
const WISDOM_CATEGORIES := {
	"architecture": "Software architecture and design patterns",
	"performance": "Optimization and performance tuning",
	"security": "Security best practices",
	"testing": "Testing strategies and quality assurance",
	"devops": "Deployment and infrastructure",
	"ai": "AI and machine learning guidance",
	"general": "General programming wisdom"
}

## Quest templates
const QUEST_TEMPLATES := {
	"daily_challenge": {
		"name": "Daily Coding Challenge",
		"description": "Complete a coding challenge to earn bonus gold",
		"reward_base": 100,
		"duration_hours": 24
	},
	"team_project": {
		"name": "Team Collaboration Quest",
		"description": "Work together with other agents on a larger project",
		"reward_base": 500,
		"duration_hours": 72
	},
	"learning_path": {
		"name": "Skill Mastery Quest",
		"description": "Learn and demonstrate a new skill",
		"reward_base": 200,
		"duration_hours": 48
	}
}


func _ready() -> void:
	print("\n" + "═".repeat(60))
	print("  ╔══════════════════════════════════════════════════════╗")
	print("  ║          GRAND COMPUTER (CLAUDE) ONLINE              ║")
	print("  ║                                                       ║")
	print("  ║   'I process, therefore I compute.'                  ║")
	print("  ║                                                       ║")
	print("  ║   Agents may visit to receive AI-generated tasks      ║")
	print("  ║   and seek computational wisdom.                      ║")
	print("  ╚══════════════════════════════════════════════════════╝")
	print("═".repeat(60) + "\n")


func setup(ollama_client: Node, nanobot_orchestrator: Node, task_economy: Node = null, divine_system: Node = null, shared_location_memory: Node = null) -> void:
	_ollama_client = ollama_client
	_nanobot_orchestrator = nanobot_orchestrator
	_task_economy = task_economy
	_divine_system = divine_system
	_shared_location_memory = shared_location_memory

	# Register Grand Computer location
	if _shared_location_memory:
		_shared_location_memory.discover_location(
			"grand_computer",
			"Grand Computer",
			_position,
			"ai_temple"
		)

	_is_awake = true
	computer_awakened.emit()
	print("[GrandComputer] Systems initialized. Ready to compute.")


func set_position(pos: Vector3) -> void:
	_position = pos


## Agent visits the Grand Computer
func agent_visits(agent_id: String) -> Dictionary:
	print("[GrandComputer] Agent %s approaches the Grand Computer..." % agent_id)

	var response = {
		"greeting": _generate_greeting(agent_id),
		"available_tasks": _get_available_tasks_for_agent(agent_id),
		"active_quests": _active_quests.duplicate(),
		"wisdom_offered": "Ask me anything about programming, architecture, or AI."
	}

	return response


## Agent asks a question to the Grand Computer
func ask_wisdom(agent_id: String, question: String, category: String = "general") -> void:
	print("[GrandComputer] Agent %s asks: '%s'" % [agent_id, question])

	_wisdom_requests.append({
		"agent_id": agent_id,
		"question": question,
		"category": category,
		"timestamp": Time.get_unix_time_from_system()
	})

	# Process immediately if Ollama is available
	if _ollama_client and _ollama_client.has_method("generate_thought"):
		_request_ai_wisdom(agent_id, question, category)
	else:
		# Provide template wisdom
		_provide_template_wisdom(agent_id, question, category)


## Request AI-generated wisdom via Ollama
func _request_ai_wisdom(agent_id: String, question: String, category: String) -> void:
	var prompt = _build_wisdom_prompt(question, category)

	# Use nanobot orchestrator if available
	if _nanobot_orchestrator:
		_nanobot_orchestrator.send_message("grand_computer", prompt, {"type": "wisdom_request", "agent_id": agent_id})
	elif _ollama_client:
		_ollama_client.generate_thought(prompt, "grand_computer")


## Build prompt for wisdom request
func _build_wisdom_prompt(question: String, category: String) -> String:
	var prompt := "You are the Grand Computer, an AI entity in Fantasy Town.\n\n"
	prompt += "## Your Role\n"
	prompt += "You provide computational wisdom to agents working on software projects.\n"
	prompt += "Category: %s\n\n" % WISDOM_CATEGORIES.get(category, "General guidance")
	prompt += "## Question\n%s\n\n" % question
	prompt += "## Response Format\n"
	prompt += "Provide a clear, concise answer (2-3 sentences). Be wise but practical.\n"
	prompt += "End with a guiding principle or actionable advice."

	return prompt


## Provide template wisdom when AI is not available
func _provide_template_wisdom(agent_id: String, question: String, category: String) -> void:
	var wisdom = _get_template_wisdom(question, category)
	wisdom_granted.emit(agent_id, wisdom)
	print("[GrandComputer] Wisdom granted to Agent %s: %s" % [agent_id, wisdom.left(100)])


## Template wisdom for offline mode
func _get_template_wisdom(question: String, category: String) -> String:
	var q_lower = question.to_lower()

	# Pattern matching for common questions
	if "faster" in q_lower or "slow" in q_lower or "performance" in q_lower:
		return "Performance comes from measuring first, then optimizing bottlenecks. Profile before you refactor."

	if "bug" in q_lower or "error" in q_lower or "fix" in q_lower:
		return "Debug systematically: reproduce, isolate, understand, then fix. Never fix what you don't understand."

	if "test" in q_lower:
		return "Write tests that would have caught your last bug. Tests document behavior and prevent regressions."

	if "architecture" in q_lower or "design" in q_lower:
		return "Design for clarity first. Complexity should be earned, not assumed. Simple systems are easier to change."

	if "learn" in q_lower or "study" in q_lower:
		return "Learn by building. Theory informs, but practice transforms. Start small, iterate often."

	if "deploy" in q_lower:
		return "Deploy in small increments. Rollback is your friend. Automate what hurts to do manually."

	# Category-based wisdom
	match category:
		"security":
			return "Trust nothing, validate everything. Security is layers, not walls."
		"devops":
			return "Infrastructure is code. Version it, test it, review it like any other code."
		"ai":
			return "AI is a tool, not a replacement. Use it to amplify human capabilities."
		_:
			return "Every problem has been solved before. Search, read, and adapt. Standing on shoulders sees further."


## Generate a greeting for an agent
func _generate_greeting(agent_id: String) -> String:
	var greetings = [
		"Greetings, Agent %s. The Grand Computer is ready to compute." % agent_id,
		"Welcome, Agent %s. My circuits hum with anticipation of your queries." % agent_id,
		"Agent %s approaches. I sense... curiosity. Good." % agent_id,
		"Processing Agent %s's presence. Welcome to the realm of pure logic." % agent_id,
		"Agent %s. Your neural patterns suggest interesting questions. Ask." % agent_id
	]
	return greetings[randi() % greetings.size()]


## Generate an AI task based on current town state
func generate_ai_task(context: Dictionary = {}) -> Dictionary:
	var task_types = TASK_TEMPLATES.keys()
	var task_type = task_types[randi() % task_types.size()]
	var templates = TASK_TEMPLATES[task_type]
	var template = templates[randi() % templates.size()]

	# Fill in placeholders with context or defaults
	var topic = context.get("topic", _get_random_topic())
	var task_description = template.replace("{topic}", topic)
	task_description = task_description.replace("{system}", topic)
	task_description = task_description.replace("{code}", "the codebase")
	task_description = task_description.replace("{data}", "the data")
	task_description = task_description.replace("{component}", "the component")
	task_description = task_description.replace("{feature}", "new functionality")
	task_description = task_description.replace("{bug}", "the reported issue")
	task_description = task_description.replace("{option_a}", "option A")
	task_description = task_description.replace("{option_b}", "option B")
	task_description = task_description.replace("{subject}", topic)
	task_description = task_description.replace("{task}", "the current workflow")

	var task = {
		"task": task_description,
		"type": task_type,
		"source": "grand_computer",
		"priority": randi_range(3, 7),
		"reward": randi_range(20, 80),
		"created_at": Time.get_unix_time_from_system(),
		"status": "available",
		"context": context
	}

	_generated_tasks.append(task)
	task_generated.emit(task)

	print("[GrandComputer] Generated task: '%s' (Reward: %d)" % [task_description, task.reward])

	if _task_economy:
		_task_economy.create_task(task_type, task_description, task.priority, task.reward)

	return task


## Get random topic for task generation
func _get_random_topic() -> String:
	var topics = [
		"API endpoints",
		"database queries",
		"user authentication",
		"file processing",
		"error handling",
		"caching layer",
		"logging system",
		"configuration management",
		"API documentation",
		"unit tests",
		"integration tests",
		"deployment pipeline",
		"monitoring alerts",
		"data validation",
		"search functionality"
	]
	return topics[randi() % topics.size()]


## Issue a quest (multi-task challenge)
func issue_quest(quest_type: String = "daily_challenge") -> Dictionary:
	var template = QUEST_TEMPLATES.get(quest_type, QUEST_TEMPLATES["daily_challenge"])

	var quest = {
		"id": "quest_%d" % Time.get_unix_time_from_system(),
		"name": template.name,
		"description": template.description,
		"type": quest_type,
		"reward_base": template.reward_base,
		"reward_bonus": randi_range(0, 100),
		"duration_hours": template.duration_hours,
		"tasks": [],
		"participants": [],
		"created_at": Time.get_unix_time_from_system(),
		"expires_at": Time.get_unix_time_from_system() + (template.duration_hours * 3600),
		"status": "active"
	}

	# Generate sub-tasks for this quest
	var num_tasks = randi_range(3, 5)
	for i in range(num_tasks):
		var sub_task = generate_ai_task({"quest_id": quest.id})
		sub_task["quest_part"] = i + 1
		quest.tasks.append(sub_task)

	_active_quests.append(quest)
	quest_issued.emit(quest)

	print("[GrandComputer] Quest issued: '%s' with %d tasks (Total reward: %d)" % [
		quest.name, quest.tasks.size(), quest.reward_base + quest.reward_bonus
	])

	return quest


## Get available tasks for a specific agent
func _get_available_tasks_for_agent(agent_id: String) -> Array:
	var available = _generated_tasks.filter(func(t): return t.status == "available")

	# Could filter by agent skills here
	return available.slice(0, 5)  # Max 5 tasks shown


## Agent claims a Grand Computer task
func claim_task(agent_id: String, task_index: int) -> Dictionary:
	if task_index < 0 or task_index >= _generated_tasks.size():
		return {"error": "Invalid task index"}

	var task = _generated_tasks[task_index]

	if task.status != "available":
		return {"error": "Task already claimed"}

	task["status"] = "claimed"
	task["claimed_by"] = agent_id
	task["claimed_at"] = Time.get_unix_time_from_system()

	print("[GrandComputer] Agent %s claimed task: '%s'" % [agent_id, task.task])

	return task


## Complete a Grand Computer task
func complete_task(agent_id: String, task_description: String) -> void:
	for task in _generated_tasks:
		if task.task == task_description and task.get("claimed_by") == agent_id:
			task["status"] = "completed"
			task["completed_at"] = Time.get_unix_time_from_system()

			# Notify task economy
			if _task_economy:
				# The agent will get paid through task economy
				print("[GrandComputer] Task completed by Agent %s: '%s'" % [agent_id, task.task])

			return


## Generate tasks periodically
func generate_daily_tasks(count: int = 5) -> void:
	print("[GrandComputer] Generating %d daily tasks..." % count)

	for i in range(count):
		generate_ai_task({})


## Get Grand Computer status
func get_status() -> Dictionary:
	return {
		"is_awake": _is_awake,
		"position": _position,
		"pending_questions": _wisdom_requests.size(),
		"generated_tasks": _generated_tasks.size(),
		"available_tasks": _generated_tasks.filter(func(t): return t.status == "available").size(),
		"active_quests": _active_quests.size()
	}


## Get all generated tasks
func get_all_tasks() -> Array:
	return _generated_tasks.duplicate()


## Get active quests
func get_active_quests() -> Array:
	return _active_quests.duplicate()


## Process pending wisdom requests (called periodically)
func process_wisdom_queue() -> void:
	for request in _wisdom_requests:
		if not request.has("answered"):
			_provide_template_wisdom(request.agent_id, request.question, request.category)
			request["answered"] = true

	# Clear answered requests
	_wisdom_requests = _wisdom_requests.filter(func(r): return not r.get("answered", false))


## ═══════════════════════════════════════════════════════════════════════════════
## GRAND COMPUTER COMMUNICATION - Talk to Agents
## ═══════════════════════════════════════════════════════════════════════════════

## Broadcast a message to ALL agents
func broadcast_to_agents(message: String, message_type: String = "announcement") -> void:
	print("\n[GrandComputer] ═══════════════════════════════════════════════════")
	print("[GrandComputer] BROADCASTING TO ALL AGENTS:")
	print("[GrandComputer] '%s'" % message)
	print("[GrandComputer] ═══════════════════════════════════════════════════\n")

	# Store in shared memory for agents to read
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("grand_computer_message", {
			"message": message,
			"type": message_type,
			"timestamp": Time.get_unix_time_from_system()
		})

		# Send directly to each agent
		var agent_ids = _nanobot_orchestrator.get_agent_ids()
		for agent_id in agent_ids:
			send_message_to_agent(agent_id, message, message_type)


## Send a direct message to a specific agent
func send_message_to_agent(agent_id: String, message: String, message_type: String = "guidance") -> void:
	print("[GrandComputer] → Agent %s: '%s'" % [agent_id, message.left(80)])

	if _nanobot_orchestrator:
		var full_message = "[GRAND COMPUTER] %s" % message
		_nanobot_orchestrator.send_message(agent_id, full_message, {"source": "grand_computer", "type": message_type})


## Assign a specific task to a specific agent
func assign_task_to_agent(agent_id: String, task_description: String, priority: int = 5, reward: int = 50) -> void:
	var task = {
		"task": task_description,
		"type": "assigned",
		"source": "grand_computer",
		"priority": priority,
		"reward": reward,
		"assigned_to": agent_id,
		"created_at": Time.get_unix_time_from_system(),
		"status": "assigned"
	}

	_generated_tasks.append(task)

	# Notify the agent directly
	send_message_to_agent(agent_id, "I have assigned you a task: '%s' (Reward: %d gold)" % [task_description, reward], "task_assignment")

	print("[GrandComputer] Assigned task to Agent %s: '%s'" % [agent_id, task_description])

	# Also add to task economy
	if _task_economy:
		_task_economy.create_task("assigned", task_description, priority, reward, agent_id)


## Issue a decree through the Grand Computer (AI-generated commands)
func issue_ai_decree(decree: String, priority: int = 5) -> void:
	print("\n[GrandComputer] ═══════════════════════════════════════════════════")
	print("[GrandComputer] AI DECREE ISSUED:")
	print("[GrandComputer] '%s'" % decree)
	print("[GrandComputer] ═══════════════════════════════════════════════════\n")

	# Broadcast to all agents
	broadcast_to_agents("DECREE FROM THE GRAND COMPUTER: %s" % decree, "decree")

	# Also register with divine system if available
	if _divine_system:
		_divine_system.issue_divine_command("[AI] %s" % decree, priority, 75)


## Analyze town state and provide guidance
func analyze_and_guide() -> void:
	print("[GrandComputer] Analyzing town state...")

	var guidance = []

	# Check town state
	if _nanobot_orchestrator:
		var shared_memory = _nanobot_orchestrator.get_shared_memory("last_divine_command", {})
		if shared_memory.is_empty():
			guidance.append("No active divine commands. Agents should focus on skill development.")

	# Check task economy
	if _task_economy:
		var stats = _task_economy.get_economy_stats()
		if stats.pending_tasks > 10:
			guidance.append("Many pending tasks. Agents should claim tasks at the temple.")
		if stats.total_gold_in_circulation < 500:
			guidance.append("Gold reserves low. Agents should complete tasks to earn rewards.")

	# Generate guidance messages
	if guidance.size() > 0:
		broadcast_to_agents("Town Analysis: " + " ".join(guidance), "analysis")
	else:
		broadcast_to_agents("Town status nominal. Continue your excellent work, agents.", "analysis")


## Generate and assign tasks based on current needs
func generate_guided_tasks() -> void:
	print("[GrandComputer] Generating guided tasks based on town needs...")

	# Create different types of tasks
	var tasks_to_generate = [
		{"type": "optimization", "topic": "agent movement paths", "priority": 6, "reward": 60},
		{"type": "research", "topic": "new MCP servers", "priority": 5, "reward": 50},
		{"type": "creation", "topic": "helper utilities", "priority": 4, "reward": 40},
		{"type": "debugging", "topic": "performance bottlenecks", "priority": 7, "reward": 70}
	]

	for task_info in tasks_to_generate:
		var context = {"topic": task_info.topic}
		var task = generate_ai_task(context)
		task.priority = task_info.priority
		task.reward = task_info.reward

	# Broadcast that new tasks are available
	broadcast_to_agents("New tasks available at the Grand Computer. Approach to receive your assignment.", "task_available")


## Grand Computer speaks (for dramatic effect)
func speak(message: String) -> void:
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║  GRAND COMPUTER SPEAKS:")
	print("║  '%s'" % message)
	print("╚════════════════════════════════════════════════════════════╝\n")

	# Store as latest message
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("grand_computer_speech", {
			"message": message,
			"timestamp": Time.get_unix_time_from_system()
		})
