## AgentStudio
## Main autoload singleton for Agent Studio.
extends Node

# Preload dependencies
const AgentConfigScript = preload("res://addons/agent_studio/agent_config.gd")
const AgentClientScript = preload("res://addons/agent_studio/agent_client.gd")

## Emitted when an agent is selected
signal agent_selected(agent: Resource)

## Emitted when the agent list changes
signal agents_changed()

## Emitted when a message is sent/received
signal message_added(role: String, content: String)

## Emitted during streaming
signal stream_update(chunk: Dictionary)

## Emitted on errors
signal studio_error(message: String)

## Emitted when connected to SSH
signal ssh_connected(session_id: String)

## Emitted when disconnected
signal ssh_disconnected()

## Bridge URL
@export var bridge_url: String = "http://127.0.0.1:8000"

## API client
var client: RefCounted = null

## Currently selected agent
var current_agent: Resource = null

## Available skills from registry
var available_skills: Array = []

## Available tools from registry
var available_tools: Array = []

## Current session ID (from SSH connection)
var session_id: String = ""

## Detected AI CLI type
var ai_cli: String = ""

## Connection state
var is_connected: bool = false:
	set(value):
		if is_connected != value:
			is_connected = value
			if value:
				ssh_connected.emit(session_id)
			else:
				ssh_disconnected.emit()


func _ready() -> void:
	# Create API client
	client = AgentClientScript.new(self, bridge_url)

	# Connect client signals
	client.agents_loaded.connect(_on_agents_loaded)
	client.agent_created.connect(_on_agent_created)
	client.agent_updated.connect(_on_agent_updated)
	client.agent_deleted.connect(_on_agent_deleted)
	client.skills_loaded.connect(_on_skills_loaded)
	client.tools_loaded.connect(_on_tools_loaded)
	client.error_occurred.connect(_on_client_error)

	# Load initial data
	refresh_all()


## Refresh agents, skills, and tools from the server
func refresh_all() -> void:
	client.fetch_skills()
	client.fetch_tools()
	client.fetch_agents()


## Select an agent for chatting
func select_agent(agent_id: String) -> void:
	var agent: Resource = client.get_agent_by_id(agent_id)
	if agent:
		current_agent = agent
		agent_selected.emit(agent)


## Create a new agent
func create_agent(config: Resource) -> void:
	client.create_agent(config)


## Update an existing agent
func update_agent(agent_id: String, updates: Dictionary) -> void:
	client.update_agent(agent_id, updates)


## Delete an agent
func delete_agent(agent_id: String) -> void:
	client.delete_agent(agent_id)


## Export agent as markdown
func export_agent(agent_id: String, callback: Callable) -> void:
	client.export_agent(agent_id, callback)


## Get all agents
func get_agents() -> Array:
	return client.get_agents()


## Get available skills
func get_skills() -> Array:
	return available_skills


## Get available tools
func get_available_tools() -> Array:
	return available_tools


## Get skill by ID
func get_skill(skill_id: String) -> Dictionary:
	for skill in available_skills:
		if skill.get("id") == skill_id:
			return skill
	return {}


## Get tool by ID
func get_tool(tool_id: String) -> Dictionary:
	for tool in available_tools:
		if tool.get("id") == tool_id:
			return tool
	return {}


## Connect to SSH server (delegates to existing AIChat system)
func connect_ssh(host: String, username: String, ssh_key: String = "", password: String = "") -> void:
	# Use the existing ai_chat system for SSH connection
	# This will be integrated with the existing system
	if current_agent:
		# The agent has a preferred AI CLI
		var pref: String = current_agent.ai_cli
		# This would connect via the existing AIChat system
		# For now, emit a signal for the UI to handle
		studio_error.emit("SSH connection requires ai_chat addon integration")
	else:
		studio_error.emit("Select an agent first")


## Disconnect from SSH
func disconnect_ssh() -> void:
	session_id = ""
	ai_cli = ""
	is_connected = false


# === Signal Handlers ===


func _on_agents_loaded(agents: Array) -> void:
	agents_changed.emit()


func _on_agent_created(agent: Resource) -> void:
	agents_changed.emit()


func _on_agent_updated(agent: Resource) -> void:
	if current_agent and current_agent.id == agent.id:
		current_agent = agent
	agents_changed.emit()


func _on_agent_deleted(agent_id: String) -> void:
	if current_agent and current_agent.id == agent_id:
		current_agent = null
	agents_changed.emit()


func _on_skills_loaded(skills: Array) -> void:
	available_skills = skills


func _on_tools_loaded(tools: Array) -> void:
	available_tools = tools


func _on_client_error(error: String) -> void:
	studio_error.emit(error)
