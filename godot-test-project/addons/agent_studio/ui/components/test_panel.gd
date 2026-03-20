## Test script for Agent Studio
extends Control

# Test the Agent Studio API integration
func _ready() -> void:
	print("=== Agent Studio Test ===")

	# Wait for AgentStudio autoload to be ready
	await get_tree().process_frame

	if AgentStudio:
		print("[Test] AgentStudio autoload found!")

		# Connect signals
		AgentStudio.agents_changed.connect(_on_agents_changed)
		AgentStudio.skills_loaded.connect(_on_skills_loaded)
		AgentStudio.tools_loaded.connect(_on_tools_loaded)
		AgentStudio.studio_error.connect(_on_error)

		# Refresh data
		AgentStudio.refresh_all()
		print("[Test] Refresh triggered")
	else:
		print("[Test] ERROR: AgentStudio autoload not found!")


func _on_agents_changed() -> void:
	var agents = AgentStudio.get_agents()
	print("[Test] Agents loaded: %d" % agents.size())
	for agent in agents:
		print("  - %s (%s)" % [agent.name, agent.id])


func _on_skills_loaded(skills: Array) -> void:
	print("[Test] Skills loaded: %d" % skills.size())
	for skill in skills:
		print("  - %s: %s" % [skill.get("name"), skill.get("description")[:30]])


func _on_tools_loaded(tools: Array) -> void:
	print("[Test] Tools loaded: %d" % tools.size())
	for tool in tools:
		print("  - %s: %s" % [tool.get("name"), tool.get("description")[:30]])


func _on_error(message: String) -> void:
	print("[Test] ERROR: %s" % message)
