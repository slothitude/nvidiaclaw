## AgentConfig
## Resource class for storing agent configuration.
extends Resource
class_name AgentConfigResource

## Unique agent ID
@export var id: String = ""

## Display name
@export var name: String = "New Agent"

## Description
@export_multiline var description: String = ""

## Emoji icon
@export var icon: String = "🤖"

## AI CLI type (claude, goose, auto)
@export var ai_cli: String = "auto"

## Execution mode (remote, local)
@export var execution_mode: String = "remote"

## Selected skill IDs
@export var skills: PackedStringArray = []

## Selected tool IDs
@export var tools: PackedStringArray = []

## Custom system prompt
@export_multiline var system_prompt: String = ""

## Temperature for AI responses
@export_range(0.0, 2.0) var temperature: float = 0.7

## Associated session ID (when connected)
@export var session_id: String = ""


## Create from dictionary (API response)
static func from_dict(data: Dictionary) -> Resource:
	var config: Resource = preload("res://addons/agent_studio/agent_config.gd").new()
	config.id = data.get("id", "")
	config.name = data.get("name", "Agent")
	config.description = data.get("description", "")
	config.icon = data.get("icon", "🤖")
	config.ai_cli = data.get("ai_cli", "auto")
	config.execution_mode = data.get("execution_mode", "remote")
	config.skills = PackedStringArray(data.get("skills", []))
	config.tools = PackedStringArray(data.get("tools", []))
	config.system_prompt = data.get("system_prompt", "")
	config.temperature = data.get("temperature", 0.7)
	var sid = data.get("session_id", "")
	config.session_id = sid if sid != null else ""
	return config


## Convert to dictionary (for API requests)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"icon": icon,
		"ai_cli": ai_cli,
		"execution_mode": execution_mode,
		"skills": skills,
		"tools": tools,
		"system_prompt": system_prompt,
		"temperature": temperature,
		"session_id": session_id,
	}
