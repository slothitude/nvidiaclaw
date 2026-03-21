## task_economy.gd - Task & Economy System
## Part of Fantasy Town World-Breaking Demo
##
## Manages task generation, assignment, and economic rewards.
## Tasks come from:
## - Divine commands (GOD's will)
## - Building needs (market needs traders)
## - Agent goals (self-improvement)
## - External requests (MCP/API calls)
##
## Economy flow:
## - Tasks have gold rewards
## - Agents earn gold by completing tasks
## - Agents spend gold on skills, items, services
## - Temples collect offerings (gold sink)

class_name TaskEconomy
extends Node

## Configuration
const BASE_TASK_REWARD := 10
const SKILL_BONUS_PER_LEVEL := 5
const URGENT_MULTIPLIER := 2.0
const DIVINE_BONUS := 1.5

## Task categories with base rewards
const TASK_CATEGORIES := {
	"development": {
		"base_reward": 20,
		"skills": ["Python Scripting", "JavaScript/TypeScript", "Git Version Control"],
		"examples": [
			"Write a function to parse JSON",
			"Create a REST API endpoint",
			"Refactor legacy code"
		]
	},
	"devops": {
		"base_reward": 25,
		"skills": ["Docker Containers", "Kubernetes", "CI/CD Pipelines"],
		"examples": [
			"Deploy to production",
			"Set up monitoring",
			"Configure load balancer"
		]
	},
	"data": {
		"base_reward": 18,
		"skills": ["Data Analysis", "Machine Learning", "SQL Databases"],
		"examples": [
			"Analyze user behavior",
			"Train a classifier",
			"Create data visualization"
		]
	},
	"security": {
		"base_reward": 30,
		"skills": ["Security Auditing", "Secrets Management"],
		"examples": [
			"Scan for vulnerabilities",
			"Rotate API keys",
			"Review access logs"
		]
	},
	"research": {
		"base_reward": 12,
		"skills": ["Web Search (SearXNG)", "Data Analysis"],
		"examples": [
			"Research best practices",
			"Find documentation",
			"Compare solutions"
		]
	},
	"trading": {
		"base_reward": 15,
		"skills": ["API Integration", "Communication Protocol"],
		"examples": [
			"Buy supplies",
			"Sell crafted items",
			"Negotiate contract"
		]
	},
	"teaching": {
		"base_reward": 8,
		"skills": [],  # Any skill can be taught
		"examples": [
			"Teach Python to apprentice",
			"Share knowledge",
			"Mentor junior agent"
		]
	},
	"divine": {
		"base_reward": 50,
		"skills": [],  # Any skill
		"examples": [
			"Fulfill GOD's command",
			"Complete holy task",
			"Spread the word"
		]
	}
}

## Market prices for goods and services
const MARKET_PRICES := {
	# Learning costs
	"skill_training_basic": 20,
	"skill_training_advanced": 50,
	"skill_training_expert": 100,

	# Services
	"temple_blessing": 10,
	"tavern_meal": 5,
	"tavern_drink": 2,
	"healing": 15,

	# Tools
	"basic_tools": 30,
	"advanced_tools": 80,

	# Divine
	"offering_small": 10,
	"offering_medium": 50,
	"offering_large": 100
}

## Signals
signal task_created(task: Dictionary)
signal task_assigned(task_id: String, agent_id: String)
signal task_completed(task_id: String, agent_id: String, reward: int)
signal transaction_made(agent_id: String, amount: int, reason: String)
signal market_fluctuation(item: String, old_price: int, new_price: int)

## State
var _all_tasks: Dictionary = {}  # task_id -> task
var _task_queue: Array = []  # Pending tasks sorted by priority
var _agent_balances: Dictionary = {}  # agent_id -> gold
var _agent_earnings: Dictionary = {}  # agent_id -> total earned
var _agent_spending: Dictionary = {}  # agent_id -> total spent
var _task_counter: int = 0
var _market_modifiers: Dictionary = {}  # item -> price modifier


func _ready() -> void:
	print("[Economy] Task & Economy system initialized")


## Generate a unique task ID
func _generate_task_id() -> String:
	_task_counter += 1
	return "task_%d_%d" % [Time.get_ticks_msec(), _task_counter]


## Create a new task
func create_task(category: String, description: String, priority: int = 5, custom_reward: int = -1) -> Dictionary:
	var task_id = _generate_task_id()
	var category_data = TASK_CATEGORIES.get(category, {"base_reward": BASE_TASK_REWARD, "skills": []})

	var reward = custom_reward if custom_reward > 0 else category_data["base_reward"]
	reward = _apply_priority_modifier(reward, priority)

	var task = {
		"id": task_id,
		"category": category,
		"description": description,
		"priority": priority,
		"base_reward": category_data["base_reward"],
		"final_reward": reward,
		"required_skills": category_data.get("skills", []),
		"status": "pending",
		"assigned_to": null,
		"created_at": Time.get_ticks_msec(),
		"completed_at": 0,
		"progress": 0.0
	}

	_all_tasks[task_id] = task
	_enqueue_task(task)

	task_created.emit(task)
	print("[Economy] Task created: '%s' (Reward: %d gold)" % [description, reward])

	return task


## Apply priority modifier to reward
func _apply_priority_modifier(base_reward: int, priority: int) -> int:
	var modifier = 1.0 + (priority - 5) * 0.1  # +/- 10% per priority level
	return int(base_reward * modifier)


## Enqueue task in priority queue
func _enqueue_task(task: Dictionary) -> void:
	_task_queue.append(task)
	_task_queue.sort_custom(func(a, b): return a["priority"] > b["priority"])


## Get next task for an agent based on their skills
func get_next_task_for_agent(agent_id: String, agent_skills: Dictionary) -> Dictionary:
	for i in range(_task_queue.size()):
		var task = _task_queue[i]

		if task["status"] != "pending":
			continue

		# Check if agent has required skills
		var can_do = true
		var skill_bonus = 0

		for required_skill in task["required_skills"]:
			if agent_skills.has(required_skill):
				skill_bonus += agent_skills[required_skill].get("level", 1) * SKILL_BONUS_PER_LEVEL
			else:
				# Agent doesn't have required skill, but might still attempt
				can_do = false

		if can_do or task["required_skills"].is_empty():
			task["assigned_to"] = agent_id
			task["status"] = "assigned"
			task["skill_bonus"] = skill_bonus
			task["final_reward"] = task["base_reward"] + skill_bonus

			_task_queue.erase(task)
			task_assigned.emit(task["id"], agent_id)

			return task

	return {}


## Assign specific task to agent
func assign_task_to_agent(task_id: String, agent_id: String) -> bool:
	if not _all_tasks.has(task_id):
		return false

	var task = _all_tasks[task_id]

	if task["status"] != "pending":
		return false

	task["assigned_to"] = agent_id
	task["status"] = "assigned"

	_task_queue.erase(task)
	task_assigned.emit(task_id, agent_id)

	return true


## Complete a task and pay reward
func complete_task(task_id: String) -> int:
	if not _all_tasks.has(task_id):
		return 0

	var task = _all_tasks[task_id]

	if task["status"] != "assigned":
		return 0

	task["status"] = "completed"
	task["completed_at"] = Time.get_ticks_msec()

	var reward = task["final_reward"]
	var agent_id = task["assigned_to"]

	# Pay the agent
	add_gold(agent_id, reward)

	# Track earnings
	if not _agent_earnings.has(agent_id):
		_agent_earnings[agent_id] = 0
	_agent_earnings[agent_id] += reward

	task_completed.emit(task_id, agent_id, reward)
	print("[Economy] Task '%s' completed by %s! Earned %d gold" % [task["description"], agent_id, reward])

	return reward


## Add gold to agent's balance
func add_gold(agent_id: String, amount: int) -> void:
	if not _agent_balances.has(agent_id):
		_agent_balances[agent_id] = 0

	_agent_balances[agent_id] += amount


## Spend gold (returns false if insufficient funds)
func spend_gold(agent_id: String, amount: int, reason: String = "") -> bool:
	if not _agent_balances.has(agent_id):
		_agent_balances[agent_id] = 0

	if _agent_balances[agent_id] < amount:
		return false

	_agent_balances[agent_id] -= amount

	if not _agent_spending.has(agent_id):
		_agent_spending[agent_id] = 0
	_agent_spending[agent_id] += amount

	transaction_made.emit(agent_id, -amount, reason)
	return true


## Get agent's gold balance
func get_balance(agent_id: String) -> int:
	return _agent_balances.get(agent_id, 0)


## Transfer gold between agents
func transfer_gold(from_agent: String, to_agent: String, amount: int) -> bool:
	if spend_gold(from_agent, amount, "transfer to %s" % to_agent):
		add_gold(to_agent, amount)
		transaction_made.emit(to_agent, amount, "transfer from %s" % from_agent)
		return true
	return false


## Buy from market
func buy_item(agent_id: String, item_name: String) -> bool:
	var base_price = MARKET_PRICES.get(item_name, 0)
	if base_price == 0:
		return false

	var final_price = base_price + _market_modifiers.get(item_name, 0)

	if spend_gold(agent_id, final_price, "bought %s" % item_name):
		print("[Economy] Agent %s bought %s for %d gold" % [agent_id, item_name, final_price])
		return true

	return false


## Get market price
func get_market_price(item_name: String) -> int:
	var base = MARKET_PRICES.get(item_name, 0)
	return base + _market_modifiers.get(item_name, 0)


## Update market prices (called periodically)
func fluctuate_market() -> void:
	for item in MARKET_PRICES.keys():
		var old_price = get_market_price(item)
		# Random fluctuation +/- 10%
		var change = int(MARKET_PRICES[item] * randf_range(-0.1, 0.1))
		_market_modifiers[item] = change

		var new_price = get_market_price(item)
		if old_price != new_price:
			market_fluctuation.emit(item, old_price, new_price)


## Get economy statistics
func get_economy_stats() -> Dictionary:
	var total_gold = 0
	var total_earned = 0
	var total_spent = 0

	for agent_id in _agent_balances.keys():
		total_gold += _agent_balances[agent_id]

	for agent_id in _agent_earnings.keys():
		total_earned += _agent_earnings[agent_id]

	for agent_id in _agent_spending.keys():
		total_spent += _agent_spending[agent_id]

	return {
		"total_gold_in_circulation": total_gold,
		"total_earned": total_earned,
		"total_spent": total_spent,
		"pending_tasks": _task_queue.size(),
		"completed_tasks": _all_tasks.values().filter(func(t): return t["status"] == "completed").size(),
		"agent_count": _agent_balances.size()
	}


## Get agent financial report
func get_agent_report(agent_id: String) -> Dictionary:
	return {
		"balance": get_balance(agent_id),
		"total_earned": _agent_earnings.get(agent_id, 0),
		"total_spent": _agent_spending.get(agent_id, 0),
		"tasks_completed": _all_tasks.values().filter(func(t): return t["assigned_to"] == agent_id and t["status"] == "completed").size()
	}


## Generate random task (for demo)
func generate_random_task() -> Dictionary:
	var categories = TASK_CATEGORIES.keys()
	var category = categories[randi() % categories.size()]
	var category_data = TASK_CATEGORIES[category]

	var examples = category_data["examples"]
	var description = examples[randi() % examples.size()] if examples.size() > 0 else "Complete task"

	var priority = randi_range(1, 10)

	return create_task(category, description, priority)


## Get pending tasks count
func get_pending_tasks_count() -> int:
	return _task_queue.size()


## Get all pending tasks
func get_pending_tasks() -> Array:
	return _task_queue.duplicate()
