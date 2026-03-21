## minimap.gd - Mini Map for Fantasy Town
## Part of Fantasy Town World-Breaking Demo
##
## Shows a top-down view of the town with:
## - Buildings as gray rectangles
## - Agents as colored dots
## - Camera viewport as a rectangle
##
## Click on minimap to jump camera to that location

class_name Minimap
extends Control

## Configuration
@export var map_size: Vector2 = Vector2(200, 200)
@export var world_bounds: Vector2 = Vector2(100, 100)  # World size in units

## Colors
const BG_COLOR := Color(0.1, 0.1, 0.15, 0.9)
const BUILDING_COLOR := Color(0.5, 0.5, 0.5)
const AGENT_COLOR := Color(0.2, 0.8, 0.3)
const AGENT_SELECTED_COLOR := Color(1.0, 0.8, 0.2)
const CAMERA_COLOR := Color(1, 1, 1, 0.3)
const TEMPLE_COLOR := Color(0.8, 0.7, 0.3)

## References
var _camera: Camera3D = null
var _agents: Array = []  # List of agent nodes
var _buildings: Array = []  # List of {position, size, purpose}
var _selected_agent_id: String = ""

## Signals
signal location_clicked(world_position: Vector3)
signal agent_clicked(agent_id: String)


func _ready() -> void:
	custom_minimum_size = map_size
	_create_background()


func _create_background() -> void:
	# Create panel background
	var panel = PanelContainer.new()
	panel.name = "MinimapPanel"
	panel.custom_minimum_size = map_size
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)


func _draw() -> void:
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, map_size), BG_COLOR)

	# Draw buildings
	for building in _buildings:
		var pos = _world_to_map(building.position)
		var size = building.get("size", Vector2(6, 6))

		# Different colors for different building types
		var color = BUILDING_COLOR
		if building.get("purpose") == "temple":
			color = TEMPLE_COLOR
		elif building.get("purpose") == "library":
			color = Color(0.3, 0.5, 0.7)
		elif building.get("purpose") == "university":
			color = Color(0.6, 0.3, 0.6)
		elif building.get("purpose") == "tavern":
			color = Color(0.7, 0.5, 0.3)

		draw_rect(Rect2(pos - size / 2, size), color)

	# Draw agents as colored dots
	for agent in _agents:
		var pos = _world_to_map(agent.position)
		var agent_id = agent.get("agent_id", "")

		# Highlight selected agent
		var color = AGENT_SELECTED_COLOR if agent_id == _selected_agent_id else AGENT_COLOR

		# Draw agent dot
		draw_circle(pos, 3, color)

		# Draw small direction indicator
		if agent.has("velocity"):
			var vel_2d = Vector2(agent.velocity.x, agent.velocity.z).normalized() * 5
			draw_line(pos, pos + vel_2d, color, 1.0)

	# Draw camera viewport as rectangle
	if _camera:
		var cam_pos = _world_to_map(_camera.position)
		var viewport_size = Vector2(20, 15)  # Approximate viewport size on map
		draw_rect(Rect2(cam_pos - viewport_size / 2, viewport_size), CAMERA_COLOR, false, 1.0)

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.3, 0.3, 0.35), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		var world_pos = _map_to_world(click_pos)

		# Check if clicked on an agent
		for agent in _agents:
			var agent_pos = _world_to_map(agent.position)
			if click_pos.distance_to(agent_pos) < 5:
				agent_clicked.emit(agent.get("agent_id", ""))
				_selected_agent_id = agent.get("agent_id", "")
				accept_event()
				return

		# Otherwise, emit location click
		location_clicked.emit(world_pos)
		accept_event()


func _world_to_map(world_pos: Vector3) -> Vector2:
	return Vector2(
		(world_pos.x / world_bounds.x + 0.5) * map_size.x,
		(world_pos.z / world_bounds.y + 0.5) * map_size.y
	)


func _map_to_world(map_pos: Vector2) -> Vector3:
	return Vector3(
		(map_pos.x / map_size.x - 0.5) * world_bounds.x,
		0,
		(map_pos.y / map_size.y - 0.5) * world_bounds.y
	)


## Set agents list for rendering
func set_agents(agents: Array) -> void:
	_agents = agents
	queue_redraw()


## Set buildings list for rendering
func set_buildings(buildings: Array) -> void:
	_buildings = buildings
	queue_redraw()


## Set camera reference
func set_camera(camera: Camera3D) -> void:
	_camera = camera
	queue_redraw()


## Set selected agent
func set_selected_agent(agent_id: String) -> void:
	_selected_agent_id = agent_id
	queue_redraw()


## Update minimap (call in _process)
func update_minimap() -> void:
	queue_redraw()
