@tool
extends EditorPlugin
## Agent Studio Plugin
## Adds Agent Studio capabilities to Godot


func _enter_tree() -> void:
	# Add autoload singleton
	add_autoload_singleton("AgentStudio", "res://addons/agent_studio/agent_studio.gd")
	print("[AgentStudio] Plugin enabled")


func _exit_tree() -> void:
	# Remove autoload singleton
	remove_autoload_singleton("AgentStudio")
	print("[AgentStudio] Plugin disabled")
