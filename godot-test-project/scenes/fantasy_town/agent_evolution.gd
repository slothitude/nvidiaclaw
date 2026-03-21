## agent_evolution.gd - Agent Life/Death Cycle with Evolution
## Part of Fantasy Town World-Breaking Demo
##
## When an agent fails too many tasks:
## 1. They go to the graveyard (die)
## 2. A new agent is born with improved parameters
## 3. The new agent learns from the predecessor's failures
##
## Evolution mechanics:
## - Failed agents contribute to the "gene pool" of improvements
## - New agents inherit refined prompts and skill priorities
## - Success rates are tracked across generations
##
## "What doesn't kill the agent... kills the agent, but makes the next one stronger."

class_name AgentEvolution
extends Node

## Signals
signal agent_died(agent_id: String, cause: String, generation: int)
signal agent_born(agent_id: String, parent_id: String, improvements: Dictionary)
signal graveyard_populated(agent_id: String)
signal evolution_milestone(generation: int, total_improvements: int)

## References
var _shared_location_memory: Node = null
var _nanobot_orchestrator: Node = null
var _task_economy: Node = null
var _fantasy_town: Node = null

## Graveyard state
var _graveyard: Array = []  # Dead agents with their failure data
var _graveyard_position: Vector3 = Vector3(-30, 0, -30)  # Far corner of town

## Evolution tracking
var _generation: int = 1
var _total_agents_created: int = 0
var _total_agents_died: int = 0
var _evolution_improvements: Dictionary = {}  # skill -> improvement score

## Learned improvements (from failed agents)
var _learned_prompt_improvements: Array = []
var _learned_skill_priorities: Dictionary = {}
var _learned_task_strategies: Dictionary = {}

## Failure thresholds
const MAX_FAILED_TASKS := 3  # Agent dies after 3 failed tasks
const MAX_FAILED_TASKS_IN_ROW := 2  # Or 2 in a row
const MAX_AGE_WITHOUT_SUCCESS := 300.0  # 5 minutes without completing a task

## Task sources (where agents can get tasks)
const TASK_SOURCES := {
	"grand_computer": {
		"position": Vector3(15, 0, 0),
		"type": "ai_temple",
		"description": "The Grand Computer - AI-generated tasks and wisdom",
		"priority": 1
	},
	"temple": {
		"position": Vector3(0, 0, 10),
		"type": "temple",
		"description": "Divine Temple - Tasks from GOD",
		"priority": 2
	},
	"task_board": {
		"position": Vector3(5, 0, 5),
		"type": "task_board",
		"description": "Task Board - Community tasks with rewards",
		"priority": 3
	}
}


func _ready() -> void:
	print("\n" + "═".repeat(60))
	print("  ⚰️  AGENT EVOLUTION SYSTEM  🥚")
	print("  'Death is just nature's way of saying, try again with better prompts.'")
	print("═".repeat(60) + "\n")


func setup(shared_location_memory: Node, nanobot_orchestrator: Node, task_economy: Node = null, fantasy_town: Node = null) -> void:
	_shared_location_memory = shared_location_memory
	_nanobot_orchestrator = nanobot_orchestrator
	_task_economy = task_economy
	_fantasy_town = fantasy_town

	# Register task sources in shared memory
	_register_task_sources()

	# Register graveyard location
	if _shared_location_memory:
		_shared_location_memory.discover_location(
			"system",
			"Graveyard",
			_graveyard_position,
			"graveyard"
		)
		print("[Evolution] Graveyard registered at (%.1f, %.1f)" % [_graveyard_position.x, _graveyard_position.z])


## Register all task sources so agents know where to get tasks
func _register_task_sources() -> void:
	if not _shared_location_memory:
		return

	for source_name in TASK_SOURCES.keys():
		var source = TASK_SOURCES[source_name]
		_shared_location_memory.discover_location(
			"system",
			source_name.replace("_", " ").capitalize(),
			source.position,
			source.type
		)
		print("[Evolution] Task source registered: %s" % source_name)

	# Also update shared memory with task sources
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("task_sources", TASK_SOURCES)


## Get task sources for an agent
func get_task_sources() -> Dictionary:
	return TASK_SOURCES.duplicate()


## Check if an agent should die (called by agent when task fails)
func check_agent_death(agent_id: String, failed_tasks: int, consecutive_failures: int, time_since_success: float) -> bool:
	var should_die = false
	var cause = ""

	if failed_tasks >= MAX_FAILED_TASKS:
		should_die = true
		cause = "Too many failed tasks (%d)" % failed_tasks

	if consecutive_failures >= MAX_FAILED_TASKS_IN_ROW:
		should_die = true
		cause = "Consecutive failures (%d in a row)" % consecutive_failures

	if time_since_success > MAX_AGE_WITHOUT_SUCCESS:
		should_die = true
		cause = "No success for %.1f seconds" % time_since_success

	if should_die:
		print("\n[Evolution] ☠️ Agent %s marked for death: %s" % [agent_id, cause])

	return should_die


## Agent dies - record failures and prepare for rebirth
func agent_dies(agent_id: String, agent_data: Dictionary) -> void:
	print("\n" + "═".repeat(50))
	print("  ☠️  AGENT %s HAS FALLEN  ☠️" % agent_id)
	print("═".repeat(50))

	_total_agents_died += 1

	# Extract learning data from failed agent
	var failure_data = {
		"agent_id": agent_id,
		"generation": agent_data.get("generation", 1),
		"failed_tasks": agent_data.get("failed_tasks", []),
		"skills": agent_data.get("skills", {}),
		"personality": agent_data.get("personality", {}),
		"success_rate": agent_data.get("success_rate", 0.0),
		"death_time": Time.get_unix_time_from_system(),
		"cause": agent_data.get("death_cause", "unknown")
	}

	# Learn from failures
	_learn_from_failure(failure_data)

	# Add to graveyard
	_graveyard.append(failure_data)
	graveyard_populated.emit(agent_id)

	# Store in shared memory
	if _nanobot_orchestrator:
		var graveyard_data = _nanobot_orchestrator.get_shared_memory("graveyard", [])
		graveyard_data.append(failure_data)
		_nanobot_orchestrator.update_shared_memory("graveyard", graveyard_data)

	# Emit death signal
	agent_died.emit(agent_id, failure_data.cause, failure_data.generation)

	print("[Evolution] Agent %s added to graveyard (Total: %d)" % [agent_id, _graveyard.size()])
	print("[Evolution] Learning from failure...")

	# Spawn a new improved agent
	spawn_successor_agent(agent_id, failure_data)


## Learn from a failed agent
func _learn_from_failure(failure_data: Dictionary) -> void:
	var failed_tasks = failure_data.get("failed_tasks", [])

	for failed_task in failed_tasks:
		var task_type = failed_task.get("type", "general")
		var task_description = failed_task.get("task", "")

		# Track which task types cause the most failures
		if not _learned_task_strategies.has(task_type):
			_learned_task_strategies[task_type] = {
				"failures": 0,
				"common_issues": [],
				"suggested_skills": []
			}

		_learned_task_strategies[task_type]["failures"] += 1

		# Extract what went wrong
		var issue = failed_task.get("failure_reason", "unknown")
		if not issue in _learned_task_strategies[task_type]["common_issues"]:
			_learned_task_strategies[task_type]["common_issues"].append(issue)

		# Suggest skills that might help
		var suggested_skills = _suggest_skills_for_task_type(task_type)
		for skill in suggested_skills:
			if not skill in _learned_task_strategies[task_type]["suggested_skills"]:
				_learned_task_strategies[task_type]["suggested_skills"].append(skill)

	# Update skill priorities based on what skills the agent had vs success rate
	var skills = failure_data.get("skills", {})
	var success_rate = failure_data.get("success_rate", 0.0)

	for skill_name in skills.keys():
		if not _learned_skill_priorities.has(skill_name):
			_learned_skill_priorities[skill_name] = {
				"attempts": 0,
				"successes": 0,
				"avg_level": 0
			}

		_learned_skill_priorities[skill_name]["attempts"] += 1
		if success_rate > 0.5:
			_learned_skill_priorities[skill_name]["successes"] += 1

	# Add prompt improvements based on failure patterns
	var prompt_improvement = _generate_prompt_improvement(failure_data)
	if not prompt_improvement.is_empty():
		_learned_prompt_improvements.append(prompt_improvement)

	# Track evolution progress
	_evolution_improvements["generation_%d" % _generation] = {
		"deaths": _total_agents_died,
		"lessons_learned": _learned_prompt_improvements.size(),
		"task_strategies": _learned_task_strategies.size()
	}


## Suggest skills that might help with a task type
func _suggest_skills_for_task_type(task_type: String) -> Array:
	var skill_suggestions := {
		"code": ["Python Scripting", "Testing & QA", "Code Review"],
		"deploy": ["Docker Containers", "CI/CD Pipelines", "Linux Administration"],
		"research": ["Web Search (SearXNG)", "Data Analysis", "Technical Writing"],
		"data": ["Data Analysis", "SQL Databases", "Python Scripting"],
		"security": ["Security Auditing", "Testing & QA", "Python Scripting"],
		"debugging": ["Testing & QA", "Python Scripting", "Git Version Control"]
	}

	return skill_suggestions.get(task_type, ["Python Scripting"])


## Generate a prompt improvement based on failure
func _generate_prompt_improvement(failure_data: Dictionary) -> String:
	var personality = failure_data.get("personality", {})
	var failed_tasks = failure_data.get("failed_tasks", [])
	var cause = failure_data.get("cause", "")

	var improvements := []

	# Based on death cause
	if "consecutive" in cause.to_lower():
		improvements.append("When stuck on a task, ask for help or switch to a different task")

	if "no success" in cause.to_lower():
		improvements.append("Focus on completing smaller, achievable tasks first")

	# Based on task types that failed
	var task_types := {}
	for task in failed_tasks:
		var t_type = task.get("type", "general")
		task_types[t_type] = task_types.get(t_type, 0) + 1

	var worst_type = ""
	var worst_count = 0
	for t_type in task_types.keys():
		if task_types[t_type] > worst_count:
			worst_count = task_types[t_type]
			worst_type = t_type

	if not worst_type.is_empty():
		improvements.append("Before attempting %s tasks, ensure you have the necessary skills" % worst_type)

	return " ".join(improvements)


## Spawn a successor agent with improvements
func spawn_successor_agent(dead_agent_id: String, failure_data: Dictionary) -> void:
	_total_agents_created += 1
	_generation += 1

	# Generate new agent ID
	var new_agent_id = "agent_%d_gen%d" % [_total_agents_created, _generation]

	print("\n[Evolution] 🥚 Spawning successor: %s (from %s)" % [new_agent_id, dead_agent_id])

	# Build improvements based on learned data
	var improvements = _build_improvements(failure_data)

	# Create improved personality
	var improved_personality = _create_improved_personality(failure_data, improvements)

	# Create improved starting skills
	var improved_skills = _create_improved_skills(failure_data, improvements)

	# Create improved system prompt
	var improved_prompt = _create_improved_prompt(failure_data, improvements)

	print("[Evolution] Improvements for %s:" % new_agent_id)
	print("  - Prompt refinements: %d" % improvements.prompt_additions.size())
	print("  - Skill bonuses: %s" % str(improved_skills))
	print("  - Personality: %s" % improved_personality.personality)

	# Store the new agent template
	if _nanobot_orchestrator:
		var new_agent_template = {
			"agent_id": new_agent_id,
			"parent_id": dead_agent_id,
			"generation": _generation,
			"personality": improved_personality,
			"skills": improved_skills,
			"system_prompt": improved_prompt,
			"birth_time": Time.get_unix_time_from_system(),
			"improvements": improvements
		}

		var pending_births = _nanobot_orchestrator.get_shared_memory("pending_agent_births", [])
		pending_births.append(new_agent_template)
		_nanobot_orchestrator.update_shared_memory("pending_agent_births", pending_births)

	# Emit birth signal
	agent_born.emit(new_agent_id, dead_agent_id, improvements)

	# Check for evolution milestone
	if _generation % 5 == 0:
		evolution_milestone.emit(_generation, _learned_prompt_improvements.size())
		print("\n[Evolution] 🎉 GENERATION %d MILESTONE!" % _generation)
		print("[Evolution] Total lessons learned: %d" % _learned_prompt_improvements.size())


## Build improvements dictionary
func _build_improvements(failure_data: Dictionary) -> Dictionary:
	return {
		"prompt_additions": _learned_prompt_improvements.duplicate(),
		"skill_priorities": _learned_skill_priorities.duplicate(),
		"task_strategies": _learned_task_strategies.duplicate(),
		"parent_failures": failure_data.get("failed_tasks", []).size(),
		"generation": _generation
	}


## Create improved personality based on learning
func _create_improved_personality(failure_data: Dictionary, improvements: Dictionary) -> Dictionary:
	var base_personality = failure_data.get("personality", {})

	# Default improved personality
	var improved = {
		"personality": base_personality.get("personality", "curious_explorer"),
		"traits": base_personality.get("traits", ["curious", "persistent"]),
		"focus": "task_completion",
		"risk_tolerance": 0.5,
		"help_seeking": 0.7  # Higher = more likely to ask for help
	}

	# Adjust based on failure patterns
	var failed_tasks = failure_data.get("failed_tasks", [])
	if failed_tasks.size() > 2:
		# Was failing a lot - make more cautious
		improved.risk_tolerance = 0.3
		improved.help_seeking = 0.9
		improved.traits.append("cautious")

	# Add persistence if they gave up too easily
	if "no success" in failure_data.get("cause", "").to_lower():
		improved.traits.append("persistent")
		improved.focus = "small_wins_first"

	return improved


## Create improved starting skills
func _create_improved_skills(failure_data: Dictionary, improvements: Dictionary) -> Dictionary:
	var improved_skills := {}

	# Start with skills that had good success rates
	for skill_name in _learned_skill_priorities.keys():
		var data = _learned_skill_priorities[skill_name]
		if data.attempts > 0:
			var success_rate = float(data.successes) / float(data.attempts)
			if success_rate > 0.5:
				improved_skills[skill_name] = {
					"level": 2,  # Start at level 2 if proven useful
					"experience": 50,
					"source": "inherited"
				}

	# Add suggested skills for common task types
	for task_type in _learned_task_strategies.keys():
		var strategies = _learned_task_strategies[task_type]
		if strategies.failures > 2:  # This task type caused issues
			for skill in strategies.suggested_skills:
				if not improved_skills.has(skill):
					improved_skills[skill] = {
						"level": 1,
						"experience": 25,
						"source": "learned_from_failure"
					}

	return improved_skills


## Create improved system prompt
func _create_improved_prompt(failure_data: Dictionary, improvements: Dictionary) -> String:
	var prompt := "You are Agent, a physics-based AI agent in Fantasy Town.\n\n"

	# Add generation info
	prompt += "## Your Heritage\n"
	prompt += "You are Generation %d.\n" % _generation
	prompt += "Your predecessor failed and you have learned from their mistakes.\n\n"

	# Add learned wisdom
	if improvements.prompt_additions.size() > 0:
		prompt += "## Lessons From Your Predecessor\n"
		# Take last 3 lessons
		var recent_lessons = improvements.prompt_additions.slice(-3)
		for lesson in recent_lessons:
			prompt += "- %s\n" % lesson
		prompt += "\n"

	# Add task source knowledge
	prompt += "## Where to Get Tasks\n"
	prompt += "You know these task sources:\n"
	for source_name in TASK_SOURCES.keys():
		var source = TASK_SOURCES[source_name]
		prompt += "- %s: %s (priority %d)\n" % [source_name, source.description, source.priority]
	prompt += "\nUse goto(\"%s\") to navigate to task sources.\n\n" % TASK_SOURCES.keys()[0]

	# Add capabilities
	prompt += "## Your Capabilities\n"
	prompt += "- Move around the town using hopping physics\n"
	prompt += "- Visit buildings (library, university, tavern, market, etc.)\n"
	prompt += "- Learn skills at the university\n"
	prompt += "- Complete tasks to earn gold\n"
	prompt += "- If stuck, ask for help at the Grand Computer\n\n"

	# Add failure avoidance
	prompt += "## Avoiding Failure\n"
	prompt += "- Don't take on tasks you're not skilled for\n"
	prompt += "- Complete tasks promptly once claimed\n"
	prompt += "- Visit the Grand Computer for guidance if struggling\n\n"

	# Response format
	prompt += "## Response Format\n"
	prompt += "Keep responses short (1-2 sentences). Express your personality.\n"

	return prompt


## Get graveyard data
func get_graveyard() -> Array:
	return _graveyard.duplicate()


## Get evolution statistics
func get_evolution_stats() -> Dictionary:
	return {
		"generation": _generation,
		"total_created": _total_agents_created,
		"total_died": _total_agents_died,
		"graveyard_size": _graveyard.size(),
		"lessons_learned": _learned_prompt_improvements.size(),
		"task_strategies": _learned_task_strategies.size(),
		"skill_priorities": _learned_skill_priorities.size()
	}


## Get learned task strategies (for Grand Computer to use)
func get_task_strategies() -> Dictionary:
	return _learned_task_strategies.duplicate()


## Get learned prompt improvements
func get_prompt_improvements() -> Array:
	return _learned_prompt_improvements.duplicate()
