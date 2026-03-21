@tool
extends EditorPlugin
## Spatial Arrow Nodes - Godot 4.6 Plugin
##
## Provides 3D nodes for spatial memory visualization:
## - THING nodes (concepts) rendered as spheres
## - ARROW nodes (relationships) rendered as 3D arrows
## - Markdown metadata for AI agent context


func _enter_tree() -> void:
	# Add custom types
	add_custom_type(
		"SpatialArrowNode",
		"Node3D",
		preload("res://addons/spatial_arrows/spatial_arrow_node.gd"),
		preload("res://addons/spatial_arrows/icon.svg") if ResourceLoader.exists("res://addons/spatial_arrows/icon.svg") else null
	)
	add_custom_type(
		"SpatialMemoryVisualizer",
		"Node3D",
		preload("res://addons/spatial_arrows/spatial_memory_visualizer.gd"),
		null
	)
	print("[SpatialArrows] Plugin enabled")


func _exit_tree() -> void:
	remove_custom_type("SpatialArrowNode")
	remove_custom_type("SpatialMemoryVisualizer")
	print("[SpatialArrows] Plugin disabled")
