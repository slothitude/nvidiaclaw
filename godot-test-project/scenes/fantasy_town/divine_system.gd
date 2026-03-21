## divine_system.gd - The Religion of the User (God)
## Part of Fantasy Town World-Breaking Demo
##
## The user is the world's GOD. All agents do God's bidding.
## Temple priests convert God's words into tasks for agents.
## Church bells (cron jobs) announce divine commands.
##
## Hierarchy:
## - GOD (user) → Issues divine commands
## - High Priests (at temples) → Interpret commands into tasks
## - Agents → Execute tasks to earn divine favor (money)
##
## Church bells ring at scheduled times (cron):
## - Dawn Bell (6:00) - Morning prayers, new tasks assigned
## - Noon Bell (12:00) - Midday blessing, task progress review
## - Dusk Bell (18:00) - Evening worship, task completion rewards
## - Sabbath Bell (Sunday) - Holy day, bonus rewards

class_name DivineSystem
extends Node

## Configuration
const BELL_DURATION: float = 5.0  # How long bells ring
const AGENT_GATHER_RADIUS: float = 20.0  # Agents within this range gather at temple

## Cron schedules (in game minutes, 1 real second = 1 game minute for demo)
const SCHEDULES := {
	"dawn_bell": {"hour": 6, "minute": 0, "name": "Dawn Bell"},
	"noon_bell": {"hour": 12, "minute": 0, "name": "Noon Bell"},
	"dusk_bell": {"hour": 18, "minute": 0, "name": "Dusk Bell"},
	"night_bell": {"hour": 22, "minute": 0, "name": "Night Bell"},
}

## Signals
signal bell_ringing(bell_name: String, temple_position: Vector3)
signal divine_command_issued(command: String, priority: int)
signal task_distributed_to_agent(agent_id: String, task: Dictionary)
signal agent_praying(agent_id: String, temple_name: String)
signal offering_received(agent_id: String, amount: int)

## State
var _divine_commands: Array = []  # Queue of commands from GOD
var _active_tasks: Array = []  # Tasks being worked on
var _completed_tasks: Array = []  # Completed tasks history
var _temple_positions: Array = []  # Positions of all temples
var _agents_at_temple: Dictionary = {}  # temple_name -> [agent_ids]

## Game time (for cron scheduling)
var _game_hour: int = 6  # Start at dawn
var _game_minute: int = 0
var _game_day: int = 1
var _game_day_of_week: int = 1  # 1 = Monday, 7 = Sunday
var _time_accumulator: float = 0.0
var _time_scale: float = 1.0  # 1 real second = 1 game minute

## Religious stats
var _divine_favor: int = 100  # God's favor level
var _offerings_collected: int = 0  # Total gold offered to God
var _prayers_answered: int = 0  # Tasks completed

## The Ten Commandments of the User (base rules)
const COMMANDMENTS := [
	"Thou shalt write clean code",
	"Thou shalt test thy work",
	"Thou shalt document thy functions",
	"Thou shalt not commit to main directly",
	"Thou shalt review thy peer's code",
	"Thou shalt optimize before deploying",
	"Thou shalt backup thy data",
	"Thou shalt respect API rate limits",
	"Thou shalt handle errors gracefully",
	"Thou shalt ship on time"
]


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  THE RELIGION OF THE USER")
	print("  'And the User said, Let there be Code: and there was Code.'")
	print("=".repeat(60) + "\n")


func _process(delta: float) -> void:
	# Update game time
	_time_accumulator += delta * _time_scale
	if _time_accumulator >= 1.0:
		_time_accumulator = 0.0
		_advance_game_time()


func _advance_game_time() -> void:
	_game_minute += 1

	if _game_minute >= 60:
		_game_minute = 0
		_game_hour += 1

		if _game_hour >= 24:
			_game_hour = 0
			_game_day += 1
			_game_day_of_week += 1

			if _game_day_of_week > 7:
				_game_day_of_week = 1
				_on_sabbath()

	# Check for bell schedules
	_check_bell_schedules()


func _check_bell_schedules() -> void:
	for schedule_name in SCHEDULES.keys():
		var schedule = SCHEDULES[schedule_name]
		if _game_hour == schedule["hour"] and _game_minute == schedule["minute"]:
			_ring_bell(schedule_name, schedule["name"])


## Ring the church bells
func _ring_bell(bell_id: String, bell_name: String) -> void:
	print("\n[DIVINE] 🔔 %s rings! (Day %d, %02d:%02d)" % [bell_name, _game_day, _game_hour, _game_minute])

	# Ring at all temples
	for temple_pos in _temple_positions:
		bell_ringing.emit(bell_name, temple_pos)

	# Execute bell-specific actions
	match bell_id:
		"dawn_bell":
			_on_dawn_bell()
		"noon_bell":
			_on_noon_bell()
		"dusk_bell":
			_on_dusk_bell()
		"night_bell":
			_on_night_bell()


## Dawn Bell - Assign new tasks
func _on_dawn_bell() -> void:
	print("[DIVINE] Morning prayers begin. Agents gather at temples.")

	# Distribute pending divine commands as tasks
	for i in range(min(_divine_commands.size(), 5)):  # Max 5 tasks per bell
		var command = _divine_commands.pop_front()
		_distribute_task_to_agents(command)


## Noon Bell - Review progress
func _on_noon_bell() -> void:
	print("[DIVINE] Midday blessing. Task progress reviewed.")

	# Bless agents who are working
	for task in _active_tasks:
		if task.get("progress", 0.0) > 0.5:
			_divine_favor += 1


## Dusk Bell - Reward completion
func _on_dusk_bell() -> void:
	print("[DIVINE] Evening worship. Completed tasks are rewarded.")

	# Process completed tasks
	var completed_count = 0
	for task in _active_tasks:
		if task.get("status") == "completed":
			completed_count += 1
			_reward_task_completion(task)

	_active_tasks = _active_tasks.filter(func(t): return t.get("status") != "completed")
	_prayers_answered += completed_count


## Night Bell - Rest and reflection
func _on_night_bell() -> void:
	print("[DIVINE] Night falls. Agents rest and reflect on their deeds.")


## Sabbath - Bonus rewards
func _on_sabbath() -> void:
	print("\n[DIVINE] ✝️ SABBATH DAY - Holy celebration!")
	_divine_favor += 10

	# All agents receive blessing
	for temple_name in _agents_at_temple.keys():
		for agent_id in _agents_at_temple[temple_name]:
			task_distributed_to_agent.emit(agent_id, {
				"task": "Sabbath Rest",
				"reward": 20,
				"priority": 10,
				"type": "blessing"
			})


## GOD issues a divine command (called by user input)
func issue_divine_command(command: String, priority: int = 5, reward: int = 50) -> void:
	var divine_task = {
		"command": command,
		"priority": priority,
		"reward": reward,
		"issued_at": {"day": _game_day, "hour": _game_hour, "minute": _game_minute},
		"status": "pending",
		"assigned_to": []
	}

	_divine_commands.append(divine_task)
	divine_command_issued.emit(command, priority)

	print("[DIVINE] 📜 GOD COMMANDS: '%s' (Priority: %d, Reward: %d gold)" % [command, priority, reward])

	# If urgent, ring bell immediately
	if priority >= 8:
		_ring_bell("urgent", "Urgent Bell")


## Distribute a task to available agents
func _distribute_task_to_agents(task: Dictionary) -> void:
	# Find agents at temples (they receive tasks first)
	for temple_name in _agents_at_temple.keys():
		var agents = _agents_at_temple[temple_name]
		if agents.size() > 0:
			var agent_id = agents.pick_random()
			task["assigned_to"].append(agent_id)
			task["status"] = "assigned"

			_active_tasks.append(task)

			task_distributed_to_agent.emit(agent_id, {
				"task": task["command"],
				"reward": task["reward"],
				"priority": task["priority"],
				"type": "divine"
			})

			print("[DIVINE] Agent %s received divine task: '%s'" % [agent_id, task["command"]])
			return

	# If no agents at temple, queue for next gathering
	task["status"] = "queued"
	_active_tasks.append(task)


## Agent arrives at temple
func agent_enters_temple(agent_id: String, temple_name: String) -> void:
	if not _agents_at_temple.has(temple_name):
		_agents_at_temple[temple_name] = []

	if not _agents_at_temple[temple_name].has(agent_id):
		_agents_at_temple[temple_name].append(agent_id)
		agent_praying.emit(agent_id, temple_name)
		print("[DIVINE] Agent %s prays at %s" % [agent_id, temple_name])


## Agent leaves temple
func agent_leaves_temple(agent_id: String, temple_name: String) -> void:
	if _agents_at_temple.has(temple_name):
		_agents_at_temple[temple_name].erase(agent_id)


## Agent makes offering to GOD
func receive_offering(agent_id: String, amount: int) -> void:
	_offerings_collected += amount
	_divine_favor += amount / 10

	offering_received.emit(agent_id, amount)
	print("[DIVINE] Agent %s offers %d gold to GOD (Favor: %d)" % [agent_id, amount, _divine_favor])


## Agent completes a divine task
func complete_divine_task(agent_id: String, task_name: String) -> void:
	for task in _active_tasks:
		if task.get("command") == task_name and agent_id in task.get("assigned_to", []):
			task["status"] = "completed"
			task["completed_at"] = {"day": _game_day, "hour": _game_hour, "minute": _game_minute}

			print("[DIVINE] Agent %s completed divine task: '%s'" % [agent_id, task_name])
			return


## Reward task completion
func _reward_task_completion(task: Dictionary) -> void:
	var reward = task.get("reward", 10)
	for agent_id in task.get("assigned_to", []):
		# The reward is handled by the agent's earn_money function
		# Here we just log it
		print("[DIVINE] Agent %s blessed with %d gold for completing '%s'" % [agent_id, reward, task["command"]])

	_completed_tasks.append(task)


## Register a temple position
func register_temple(position: Vector3, name: String) -> void:
	_temple_positions.append({"position": position, "name": name})
	print("[DIVINE] Temple '%s' consecrated at (%.1f, %.1f)" % [name, position.x, position.z])


## Get current game time
func get_game_time() -> Dictionary:
	return {
		"hour": _game_hour,
		"minute": _game_minute,
		"day": _game_day,
		"day_of_week": _game_day_of_week,
		"day_name": _get_day_name(_game_day_of_week)
	}


func _get_day_name(day: int) -> String:
	var days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	return days[day - 1] if day >= 1 and day <= 7 else "Unknown"


## Get divine status
func get_divine_status() -> Dictionary:
	return {
		"favor": _divine_favor,
		"offerings": _offerings_collected,
		"prayers_answered": _prayers_answered,
		"pending_commands": _divine_commands.size(),
		"active_tasks": _active_tasks.size(),
		"completed_tasks": _completed_tasks.size(),
		"time": get_game_time()
	}


## Get the commandments
func get_commandments() -> Array:
	return COMMANDMENTS.duplicate()


## Set time scale (for faster testing)
func set_time_scale(scale: float) -> void:
	_time_scale = scale


## Get next bell time
func get_next_bell() -> Dictionary:
	var current_minutes = _game_hour * 60 + _game_minute
	var next_bell = null
	var next_minutes = INF

	for schedule_name in SCHEDULES.keys():
		var schedule = SCHEDULES[schedule_name]
		var bell_minutes = schedule["hour"] * 60 + schedule["minute"]

		if bell_minutes > current_minutes and bell_minutes < next_minutes:
			next_minutes = bell_minutes
			next_bell = {"id": schedule_name, "name": schedule["name"], "minutes_until": bell_minutes - current_minutes}

	if next_bell == null:
		# Next bell is tomorrow
		next_bell = {"id": "dawn_bell", "name": "Dawn Bell", "minutes_until": (24 * 60) - current_minutes}

	return next_bell


## Interpret a natural language command into structured tasks
func interpret_divine_command(command: String) -> Array:
	# This would normally use AI, but for now we use pattern matching
	var tasks = []
	var command_lower = command.to_lower()

	# Code-related commands
	if "code" in command_lower or "script" in command_lower:
		tasks.append({
			"skill": "Python Scripting",
			"action": "write_code",
			"description": command
		})

	# Testing commands
	if "test" in command_lower:
		tasks.append({
			"skill": "Testing & QA",
			"action": "write_tests",
			"description": command
		})

	# Deployment commands
	if "deploy" in command_lower or "ship" in command_lower:
		tasks.append({
			"skill": "Docker Containers",
			"action": "deploy",
			"description": command
		})

	# Data commands
	if "data" in command_lower or "analyze" in command_lower:
		tasks.append({
			"skill": "Data Analysis",
			"action": "analyze_data",
			"description": command
		})

	# Search commands
	if "search" in command_lower or "research" in command_lower:
		tasks.append({
			"skill": "Web Search (SearXNG)",
			"action": "search",
			"description": command
		})

	# Default fallback
	if tasks.is_empty():
		tasks.append({
			"skill": "General",
			"action": "execute",
			"description": command
		})

	return tasks
