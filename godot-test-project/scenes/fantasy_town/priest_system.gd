## priest_system.gd - Temple Priests for Divine Guidance
## Part of Fantasy Town World-Breaking Demo
##
## Priests at temples can:
## - Ask clarifying questions about divine decrees
## - Break down decrees into specific tasks
## - Assign tasks to agents based on skills
## - Provide guidance on how to complete tasks
##
## Flow: Decree → Priest asks questions → Tasks created → Agents claim tasks

class_name PriestSystem
extends Node

## Signals
signal question_asked(question: String, options: Array)
signal guidance_received(guidance: String)
signal tasks_created(tasks: Array)

## References
var _divine_system: Node = null
var _task_economy: Node = null
var _nanobot_orchestrator: Node = null
var _shared_location_memory: Node = null

## Current decree being processed
var _current_decree: String = ""
var _decree_context: Dictionary = {}

## Questions database for different decree types
const DECREE_QUESTIONS := {
	"code": [
		{
			"question": "What programming language should be used?",
			"options": ["Python", "JavaScript", "GDScript", "Rust", "Any"],
			"skill": "Python Scripting"
		},
		{
			"question": "What type of code is needed?",
			"options": ["API/Backend", "Frontend/UI", "Script/Automation", "Library/Package", "Full Application"],
			"skill": "Software Architecture"
		},
		{
			"question": "Should it include tests?",
			"options": ["Yes, with full coverage", "Yes, basic tests", "No tests needed"],
			"skill": "Testing & QA"
		}
	],
	"deploy": [
		{
			"question": "Where should it be deployed?",
			"options": ["Docker container", "Kubernetes cluster", "Cloud VM", "Local server", "Not sure yet"],
			"skill": "Docker Containers"
		},
		{
			"question": "Does it need CI/CD pipeline?",
			"options": ["Yes, full pipeline", "Basic automation", "Manual deployment"],
			"skill": "CI/CD Pipelines"
		}
	],
	"research": [
		{
			"question": "What depth of research is needed?",
			"options": ["Quick overview", "Detailed analysis", "Comprehensive report", "Academic level"],
			"skill": "Web Search (SearXNG)"
		},
		{
			"question": "What sources should be prioritized?",
			"options": ["Academic papers", "Official docs", "Blog posts", "All sources"],
			"skill": "Data Analysis"
		}
	],
	"data": [
		{
			"question": "What type of data work?",
			"options": ["Collection/Gathering", "Analysis/Processing", "Visualization", "Storage/Database"],
			"skill": "Data Analysis"
		},
		{
			"question": "What format for the output?",
			"options": ["JSON/CSV", "Database", "Report/Document", "Charts/Graphs"],
			"skill": "Data Visualization"
		}
	],
	"security": [
		{
			"question": "What security focus?",
			"options": ["Code audit", "Penetration testing", "Compliance check", "Vulnerability scan"],
			"skill": "Security Auditing"
		}
	],
	"default": [
		{
			"question": "What is the priority level?",
			"options": ["Critical (urgent)", "High (this week)", "Medium (this month)", "Low (when possible)"],
			"skill": "General"
		},
		{
			"question": "What skills are most relevant?",
			"options": ["Development", "DevOps", "Research", "Design", "Management"],
			"skill": "General"
		}
	]
}

## Task templates based on decree type
const TASK_TEMPLATES := {
	"code": [
		{"task": "Research best practices for {topic}", "reward": 30, "priority": 5},
		{"task": "Design architecture for {topic}", "reward": 50, "priority": 7},
		{"task": "Implement core functionality for {topic}", "reward": 100, "priority": 8},
		{"task": "Write tests for {topic}", "reward": 40, "priority": 6},
		{"task": "Document {topic} code", "reward": 20, "priority": 4}
	],
	"deploy": [
		{"task": "Prepare deployment config for {topic}", "reward": 40, "priority": 6},
		{"task": "Set up CI/CD for {topic}", "reward": 60, "priority": 7},
		{"task": "Deploy {topic} to staging", "reward": 50, "priority": 7},
		{"task": "Test {topic} deployment", "reward": 30, "priority": 6},
		{"task": "Deploy {topic} to production", "reward": 80, "priority": 9}
	],
	"research": [
		{"task": "Search for information on {topic}", "reward": 20, "priority": 5},
		{"task": "Analyze findings on {topic}", "reward": 40, "priority": 6},
		{"task": "Summarize research on {topic}", "reward": 30, "priority": 5},
		{"task": "Present findings on {topic}", "reward": 40, "priority": 6}
	],
	"default": [
		{"task": "Analyze requirements for {topic}", "reward": 30, "priority": 5},
		{"task": "Execute main task: {topic}", "reward": 80, "priority": 7},
		{"task": "Review and verify: {topic}", "reward": 30, "priority": 5}
	]
}


func _ready() -> void:
	print("[PriestSystem] Temple priests ready to interpret divine decrees")


func setup(divine_system: Node, task_economy: Node, nanobot_orchestrator: Node, shared_location_memory: Node = null) -> void:
	_divine_system = divine_system
	_task_economy = task_economy
	_nanobot_orchestrator = nanobot_orchestrator
	_shared_location_memory = shared_location_memory

	if _divine_system:
		_divine_system.divine_command_issued.connect(_on_divine_command_issued)


## Called when GOD issues a divine decree
func _on_divine_command_issued(command: String, priority: int) -> void:
	_current_decree = command
	_decree_context = {"priority": priority}

	# Classify the decree type
	var decree_type = _classify_decree(command)
	_decree_context["type"] = decree_type

	print("[PriestSystem] Priest received decree: '%s' (type: %s)" % [command, decree_type])

	# Generate questions for this decree
	var questions = _generate_questions(decree_type, command)

	if questions.size() > 0:
		# Emit first question for GOD to answer
		question_asked.emit(questions[0].question, questions[0].options)
		print("[PriestSystem] Priest asks: %s" % questions[0].question)
	else:
		# No questions needed, create tasks directly
		_create_tasks_from_decree(command, decree_type, {})


## Classify what type of decree this is
func _classify_decree(command: String) -> String:
	var cmd = command.to_lower()

	if "code" in cmd or "script" in cmd or "program" in cmd or "build" in cmd or "create" in cmd:
		return "code"
	if "deploy" in cmd or "ship" in cmd or "release" in cmd or "launch" in cmd:
		return "deploy"
	if "research" in cmd or "search" in cmd or "find" in cmd or "investigate" in cmd:
		return "research"
	if "data" in cmd or "analyze" in cmd or "process" in cmd:
		return "data"
	if "security" in cmd or "audit" in cmd or "secure" in cmd or "protect" in cmd:
		return "security"
	if "test" in cmd or "qa" in cmd or "verify" in cmd:
		return "code"  # Testing is part of code

	return "default"


## Generate questions based on decree type
func _generate_questions(decree_type: String, command: String) -> Array:
	var questions = DECREE_QUESTIONS.get(decree_type, [])
	var default_questions = DECREE_QUESTIONS.get("default", [])

	# Combine type-specific questions with defaults
	var all_questions = questions + default_questions

	# Customize questions with command context
	for i in range(all_questions.size()):
		all_questions[i] = all_questions[i].duplicate()
		all_questions[i]["decree"] = command

	return all_questions.slice(0, 3)  # Max 3 questions


## Receive answer from GOD (or automated)
func receive_answer(question_index: int, answer: String) -> void:
	var decree_type = _decree_context.get("type", "default")
	var questions = _generate_questions(decree_type, _current_decree)

	if question_index < questions.size():
		var question = questions[question_index]
		_decree_context["answer_%d" % question_index] = {
			"question": question.question,
			"answer": answer,
			"skill": question.skill
		}

		print("[PriestSystem] GOD answered: '%s' -> '%s'" % [question.question, answer])

		# Check if more questions needed
		if question_index + 1 < questions.size():
			# Ask next question
			var next_q = questions[question_index + 1]
			question_asked.emit(next_q.question, next_q.options)
		else:
			# All questions answered, create tasks
			_create_tasks_from_decree(_current_decree, decree_type, _decree_context)


## Create tasks from the decree and answers
func _create_tasks_from_decree(decree: String, decree_type: String, context: Dictionary) -> void:
	var templates = TASK_TEMPLATES.get(decree_type, TASK_TEMPLATES.get("default", []))
	var tasks = []

	# Extract topic from decree (simplified)
	var topic = decree

	for template in templates:
		var task = {
			"task": template.task.replace("{topic}", topic),
			"reward": template.reward,
			"priority": template.priority,
			"type": decree_type,
			"decree": decree,
			"context": context,
			"status": "available",
			"created_at": Time.get_unix_time_from_system()
		}

		# Adjust reward based on priority
		if context.has("priority"):
			task.reward = int(task.reward * (1.0 + context.priority * 0.1))

		tasks.append(task)

	# Store tasks in task economy
	if _task_economy:
		for task in tasks:
			_task_economy.create_task(task.type, task.task, task.priority, task.reward)

	# Store in shared memory for agents
	if _nanobot_orchestrator:
		var existing_tasks = _nanobot_orchestrator.get_shared_memory("temple_tasks", [])
		existing_tasks.append_array(tasks)
		_nanobot_orchestrator.update_shared_memory("temple_tasks", existing_tasks)

	tasks_created.emit(tasks)
	print("[PriestSystem] Created %d tasks from decree: '%s'" % [tasks.size(), decree])

	# Generate guidance message
	var guidance = _generate_guidance(tasks, context)
	guidance_received.emit(guidance)


## Generate guidance message for agents
func _generate_guidance(tasks: Array, context: Dictionary) -> String:
	var guidance = "## Divine Guidance\n\n"
	guidance += "The decree has been interpreted into %d tasks:\n\n" % tasks.size()

	for i in range(tasks.size()):
		var task = tasks[i]
		guidance += "%d. **%s** (Reward: %d gold, Priority: %d)\n" % [i + 1, task.task, task.reward, task.priority]

	guidance += "\nAgents should visit the temple to claim these tasks. Highest priority tasks pay the most gold."

	return guidance


## Get available tasks at temple (for agents)
func get_temple_tasks() -> Array:
	if _nanobot_orchestrator:
		return _nanobot_orchestrator.get_shared_memory("temple_tasks", [])
	return []


## Agent claims a task at temple
func claim_task(agent_id: String, task_index: int) -> Dictionary:
	var tasks = get_temple_tasks()

	if task_index < 0 or task_index >= tasks.size():
		return {"error": "Invalid task index"}

	var task = tasks[task_index]

	if task.get("status") != "available":
		return {"error": "Task already claimed"}

	# Mark as claimed
	task["status"] = "claimed"
	task["claimed_by"] = agent_id
	task["claimed_at"] = Time.get_unix_time_from_system()

	# Update in shared memory
	if _nanobot_orchestrator:
		_nanobot_orchestrator.update_shared_memory("temple_tasks", tasks)

	print("[PriestSystem] Agent %s claimed task: %s" % [agent_id, task.task])

	return task


## Get highest paying task
func get_highest_paying_task() -> Dictionary:
	var tasks = get_temple_tasks()
	var available = tasks.filter(func(t): return t.get("status") == "available")

	if available.is_empty():
		return {}

	# Sort by reward (highest first)
	available.sort_custom(func(a, b): return a.reward > b.reward)
	return available[0]


## Get tasks by skill
func get_tasks_for_skill(skill: String) -> Array:
	var tasks = get_temple_tasks()
	var available = tasks.filter(func(t): return t.get("status") == "available")

	# Match skill to task type
	var matching = []
	for task in available:
		var task_type = task.get("type", "")
		if _skill_matches_type(skill, task_type):
			matching.append(task)

	return matching


## Check if skill matches task type
func _skill_matches_type(skill: String, task_type: String) -> bool:
	var skill_map = {
		"Python Scripting": ["code", "data"],
		"Docker Containers": ["deploy"],
		"CI/CD Pipelines": ["deploy"],
		"Testing & QA": ["code"],
		"Web Search (SearXNG)": ["research"],
		"Data Analysis": ["data", "research"],
		"Security Auditing": ["security"],
		"API Integration": ["code", "deploy"],
		"General": ["default"]
	}

	if skill_map.has(skill):
		return task_type in skill_map[skill]

	return true  # Default: skill can do any task


## Complete a task
func complete_task(agent_id: String, task_task: String) -> void:
	var tasks = get_temple_tasks()

	for task in tasks:
		if task.get("task") == task_task and task.get("claimed_by") == agent_id:
			task["status"] = "completed"
			task["completed_at"] = Time.get_unix_time_from_system()

			# Update in shared memory
			if _nanobot_orchestrator:
				_nanobot_orchestrator.update_shared_memory("temple_tasks", tasks)

			print("[PriestSystem] Agent %s completed task: %s" % [agent_id, task.task])
			return


## Get priest interpretation of decree (for AI prompts)
func get_priest_interpretation(decree: String) -> String:
	var decree_type = _classify_decree(decree)
	var questions = _generate_questions(decree_type, decree)

	var interpretation = "The priests at the temple have received your divine decree:\n"
	interpretation += "'%s'\n\n" % decree
	interpretation += "They interpret this as a **%s** task.\n\n" % decree_type.to_upper()

	if questions.size() > 0:
		interpretation += "The priests have questions to provide better guidance:\n"
		for i in range(questions.size()):
			interpretation += "%d. %s\n" % [i + 1, questions[i].question]
			interpretation += "   Options: %s\n" % ", ".join(questions[i].options)

	return interpretation
