## fantasy_town.gd - Fantasy Town Scene with AWR Integration
## Part of AWR World-Breaking Demo
##
## A procedurally generated fantasy town where physics-based agents live.
## Integrates with AWR's Spatial Memory for agent reasoning.
##
## Goal: 1000+ agents with real physics simulation

extends Node3D

## Asset paths
const ASSETS_PATH := "res://assets/kenney/fantasy-town/"
const MODULAR_BUILDINGS_PATH := "res://assets/kenney/modular-buildings/Models/GLB/"
const CUBE_PETS_PATH := "res://assets/kenney/cube-pets/"

## Agent models (cube pets)
var _agent_models: Array = []

## Town configuration
@export var town_size := 40  # Grid size (smaller for denser town)
@export var building_density := 0.45  # More buildings
@export var agent_count := 100  # Number of agents to spawn

## Node references
@onready var buildings_node: Node3D = $Buildings
@onready var props_node: Node3D = $Props
@onready var nature_node: Node3D = $Nature
@onready var roads_node: Node3D = $Roads
@onready var agents_node: Node3D = $Agents
@onready var camera: Camera3D = $Camera3D

## AWR Integration
var spatial_memory = null
var agent_scene = null

## Asset caches
var _wall_assets: Array = []
var _roof_assets: Array = []
var _prop_assets: Array = []
var _nature_assets: Array = []
var _road_assets: Array = []
var _house_assets: Array = []  # Complete houses from modular buildings
var _tower_assets: Array = []  # Towers from modular buildings
var _modular_components: Array = []  # Building components

## Scale constants (1 unit = 1 meter)
const HOUSE_SCALE := 2.0      # Houses ~5-7m tall (visible from distance)
const TREE_SCALE := 1.5       # Trees ~5-6m tall
const PROP_SCALE := 1.2       # Props (fences, carts) ~1.5m
const AGENT_SCALE := 0.6      # Agents ~0.6m tall (small cute creatures)
const ROAD_SCALE := 1.0       # Roads

## Town layout (for agent navigation)
var town_grid: Dictionary = {}  # Vector2i -> String (building/road/empty)
var building_positions: Array = []  # Vector3 positions of buildings


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  AWR Fantasy Town - World-Breaking Demo")
	print("  Target: 1000+ physics-based agents")
	print("=".repeat(60) + "\n")

	# Load AWR components
	_load_awr()

	# Load assets
	_load_assets()

	# Build the town
	_build_town()

	# Spawn agents
	_spawn_agents()

	# Initialize spatial memory with town layout
	_init_spatial_memory()

	print("\n  Town built with %d buildings" % building_positions.size())
	print("  %d agents spawned" % agents_node.get_child_count())
	print("  Ready for simulation!\n")


func _load_awr() -> void:
	# Load spatial memory
	var SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	spatial_memory = SpatialMemoryClass.new(5.0)  # 5 unit cell size
	print("  ✓ AWR Spatial Memory loaded")


func _load_assets() -> void:
	# Load fantasy town assets
	var dir = DirAccess.open(ASSETS_PATH)
	if dir == null:
		push_error("Cannot open assets directory: " + ASSETS_PATH)
		return

	# Categorize assets by type
	var files = []
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".glb") and not file.begins_with("."):
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()

	# Load cube pets (agent models)
	var pets_dir = DirAccess.open(CUBE_PETS_PATH)
	if pets_dir:
		pets_dir.list_dir_begin()
		var pet_file = pets_dir.get_next()
		while pet_file != "":
			if pet_file.ends_with(".glb") and pet_file.begins_with("animal-"):
				_agent_models.append(pet_file)
			pet_file = pets_dir.get_next()
		pets_dir.list_dir_end()

	# Categorize by name patterns
	for f in files:
		var name = f.get_basename()

		# Separate walls and roofs for building houses
		if name.begins_with("wall"):
			_wall_assets.append(f)
		elif name.begins_with("roof"):
			_roof_assets.append(f)

		# Nature (trees, rocks)
		elif name.begins_with("tree") or name.begins_with("rock") or name.begins_with("hedge"):
			_nature_assets.append(f)

		# Roads
		elif name.begins_with("road"):
			_road_assets.append(f)

		# Props (everything else - fences, carts, banners, etc.)
		else:
			_prop_assets.append(f)

	# Load modular buildings (complete houses and components)
	var modular_dir = DirAccess.open(MODULAR_BUILDINGS_PATH)
	if modular_dir:
		modular_dir.list_dir_begin()
		var mod_file = modular_dir.get_next()
		while mod_file != "":
			if mod_file.ends_with(".glb") and not mod_file.begins_with("."):
				var name = mod_file.get_basename()
				if "sample-house" in name:
					_house_assets.append(mod_file)
				elif "sample-tower" in name:
					_tower_assets.append(mod_file)
				elif name.begins_with("building-"):
					_modular_components.append(mod_file)
			mod_file = modular_dir.get_next()
		modular_dir.list_dir_end()

	print("  Assets loaded: %d houses, %d towers, %d modular, %d nature, %d props, %d agents" % [
		_house_assets.size(), _tower_assets.size(), _modular_components.size(),
		_nature_assets.size(), _prop_assets.size(), _agent_models.size()
	])


func _build_town() -> void:
	print("  Building town layout...")

	# Create main road (center horizontal and vertical)
	_build_roads()

	# Create buildings along roads
	_build_buildings()

	# Add nature (trees, rocks)
	_add_nature()

	# Add props (fences, carts, etc.)
	_add_props()


func _build_roads() -> void:
	# Main road (horizontal)
	for x in range(-town_size, town_size):
		var pos = Vector3(x * 2, 0.05, 0)
		_place_road_segment(roads_node, pos)
		town_grid[Vector2i(x, 0)] = "road"

	# Main road (vertical)
	for z in range(-town_size, town_size):
		var pos = Vector3(0, 0.05, z * 2)
		_place_road_segment(roads_node, pos)
		town_grid[Vector2i(0, z)] = "road"

	# Cross road
	for x in range(-town_size, town_size):
		var pos = Vector3(x * 2, 0.05, 10)
		_place_road_segment(roads_node, pos)
		town_grid[Vector2i(x, 5)] = "road"


func _place_road_segment(parent: Node3D, pos: Vector3) -> void:
	# Try to use Kenney road asset
	if _road_assets.size() > 0:
		var asset_name = _road_assets[randi() % _road_assets.size()]
		var asset_path = ASSETS_PATH + asset_name

		if ResourceLoader.exists(asset_path):
			var scene = load(asset_path)
			if scene:
				var instance = scene.instantiate()
				instance.position = pos
				parent.add_child(instance)
				return

	# Fallback: gray box
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position = pos

	var box = BoxMesh.new()
	box.size = Vector3(2, 0.1, 2)
	mesh_instance.mesh = box

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.25, 0.3)
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)


func _build_buildings() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic for reproducibility

	# Place buildings in a grid pattern
	for x in range(-town_size + 2, town_size - 2, 4):
		for z in range(-town_size + 2, town_size - 2, 4):
			var grid_pos = Vector2i(x / 2, z / 2)

			# Skip if on road
			if town_grid.has(grid_pos):
				continue

			# Random chance to place building
			if rng.randf() > building_density:
				continue

			var pos = Vector3(x * 2, 0, z * 2)
			_build_house(pos, rng)


func _build_house(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	# Priority 1: Use complete modular house if available
	if _house_assets.size() > 0:
		var house_name = _house_assets[rng.randi() % _house_assets.size()]
		var house_path = MODULAR_BUILDINGS_PATH + house_name

		if ResourceLoader.exists(house_path):
			var house_scene = load(house_path)
			if house_scene:
				var house = house_scene.instantiate()
				house.position = base_pos
				house.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)
				buildings_node.add_child(house)
				building_positions.append(base_pos)
				if spatial_memory:
					spatial_memory.store(
						"house_%d" % building_positions.size(),
						base_pos,
						{"type": "building", "style": "modular_complete", "asset": house_name}
					)
				return

	# Priority 2: Use tower if available (10% chance)
	if _tower_assets.size() > 0 and rng.randf() < 0.1:
		var tower_name = _tower_assets[rng.randi() % _tower_assets.size()]
		var tower_path = MODULAR_BUILDINGS_PATH + tower_name

		if ResourceLoader.exists(tower_path):
			var tower_scene = load(tower_path)
			if tower_scene:
				var tower = tower_scene.instantiate()
				tower.position = base_pos
				tower.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE * 1.5, HOUSE_SCALE)  # Taller
				buildings_node.add_child(tower)
				building_positions.append(base_pos)
				if spatial_memory:
					spatial_memory.store(
						"house_%d" % building_positions.size(),
						base_pos,
						{"type": "building", "style": "tower", "asset": tower_name}
					)
				return

	# Priority 3: Build from modular components
	if _modular_components.size() > 0:
		_build_modular_house(base_pos, rng)
		return

	# Priority 4: Use fantasy-town wall + roof
	if _wall_assets.size() > 0:
		_build_fantasy_house(base_pos, rng)
		return

	# Fallback: Procedural house
	_build_procedural_house_simple(base_pos, rng)


func _build_modular_house(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	var house = Node3D.new()
	house.position = base_pos

	# Build a simple house from modular components
	# Base: building-block or building-corner
	var base_component = _find_modular_component(["building-block.glb", "building-corner.glb"])
	if base_component != "":
		var base_scene = load(MODULAR_BUILDINGS_PATH + base_component)
		if base_scene:
			var base_node = base_scene.instantiate()
			base_node.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)
			house.add_child(base_node)

	# Add window section (middle floor)
	var window_component = _find_modular_component([
		"building-window.glb", "building-windows.glb", "building-window-large.glb"
	])
	if window_component != "":
		var window_scene = load(MODULAR_BUILDINGS_PATH + window_component)
		if window_scene:
			var window_node = window_scene.instantiate()
			window_node.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)
			window_node.position.y = HOUSE_SCALE * 2.0
			house.add_child(window_node)

	buildings_node.add_child(house)
	building_positions.append(base_pos)

	if spatial_memory:
		spatial_memory.store(
			"house_%d" % building_positions.size(),
			base_pos,
			{"type": "building", "style": "modular_assembled"}
		)


func _build_fantasy_house(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	var house = Node3D.new()
	house.position = base_pos

	# Use fantasy-town wall + roof
	var wall_block = _find_asset_by_pattern(_wall_assets, ["wall-block.glb", "wall.glb"])
	var roof_asset = _find_asset_by_pattern(_roof_assets, ["roof-gable.glb", "roof-flat.glb"])

	if wall_block != "" and ResourceLoader.exists(ASSETS_PATH + wall_block):
		var wall_scene = load(ASSETS_PATH + wall_block)
		if wall_scene:
			var wall = wall_scene.instantiate()
			wall.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)
			house.add_child(wall)

	if roof_asset != "" and ResourceLoader.exists(ASSETS_PATH + roof_asset):
		var roof_scene = load(ASSETS_PATH + roof_asset)
		if roof_scene:
			var roof = roof_scene.instantiate()
			roof.scale = Vector3(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)
			roof.position.y = HOUSE_SCALE * 2.5
			house.add_child(roof)

	buildings_node.add_child(house)
	building_positions.append(base_pos)


func _build_procedural_house_simple(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	# Simple procedural house fallback
	var house = Node3D.new()
	house.position = base_pos

	var width = rng.randf_range(4, 6)
	var depth = rng.randf_range(4, 6)
	var height = rng.randf_range(4, 6)

	# House body
	var body = MeshInstance3D.new()
	body.position = Vector3(0, height / 2, 0)
	var box = BoxMesh.new()
	box.size = Vector3(width, height, depth)
	body.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(rng.randf_range(0.05, 0.12), 0.4, 0.8)
	body.material_override = mat
	house.add_child(body)

	# Roof
	var roof = MeshInstance3D.new()
	roof.position = Vector3(0, height + 0.8, 0)
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(width + 1, 1.5, depth + 1)
	roof.mesh = roof_box

	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.5, 0.2, 0.1)
	roof.material_override = roof_mat
	house.add_child(roof)

	buildings_node.add_child(house)
	building_positions.append(base_pos)


func _find_modular_component(patterns: Array) -> String:
	for pattern in patterns:
		for asset in _modular_components:
			if asset == pattern:
				return asset
	if _modular_components.size() > 0:
		return _modular_components[0]
	return ""


func _find_asset_by_pattern(asset_list: Array, patterns: Array) -> String:
	for pattern in patterns:
		for asset in asset_list:
			if asset == pattern or asset.get_basename() == pattern.get_basename():
				return asset
	if asset_list.size() > 0:
		return asset_list[0]
	return ""


func _add_nature() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 123

	# Scatter trees using Kenney nature assets (more trees!)
	for i in range(100):  # Increased from 50 to 100
		var x = rng.randi_range(-town_size, town_size) * 2
		var z = rng.randi_range(-town_size, town_size) * 2
		var grid_pos = Vector2i(x / 2, z / 2)

		# Skip if on road or building
		if town_grid.has(grid_pos):
			continue

		var pos = Vector3(x, 0, z)

		# Try to use Kenney nature asset
		if _nature_assets.size() > 0:
			var asset_name = _nature_assets[rng.randi() % _nature_assets.size()]
			var asset_path = ASSETS_PATH + asset_name

			if ResourceLoader.exists(asset_path):
				var scene = load(asset_path)
				if scene:
					var instance = scene.instantiate()
					instance.position = pos
					instance.scale = Vector3(TREE_SCALE, TREE_SCALE, TREE_SCALE)
					nature_node.add_child(instance)
					continue

		# Fallback: create simple tree
		var tree_node = Node3D.new()
		tree_node.position = pos

		var trunk = MeshInstance3D.new()
		trunk.position = Vector3(0, 1, 0)
		var trunk_box = BoxMesh.new()
		trunk_box.size = Vector3(0.3, 2, 0.3)
		trunk.mesh = trunk_box
		var trunk_mat = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
		trunk.material_override = trunk_mat
		tree_node.add_child(trunk)

		var foliage = MeshInstance3D.new()
		foliage.position = Vector3(0, 2.5, 0)
		var foliage_box = BoxMesh.new()
		foliage_box.size = Vector3(1.5, 1.5, 1.5)
		foliage.mesh = foliage_box
		var foliage_mat = StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(0.1, 0.6, 0.1)
		foliage.material_override = foliage_mat
		tree_node.add_child(foliage)

		nature_node.add_child(tree_node)


func _add_props() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 456

	# Add props near buildings using Kenney prop assets
	for building_pos in building_positions:
		if rng.randf() > 0.7:  # 30% chance to add props (was 50%)
			continue

		# Place 1-3 props near each building
		var num_props = rng.randi_range(1, 3)
		for i in range(num_props):
			var offset = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
			var pos = building_pos + offset

			# Try to use Kenney prop asset
			if _prop_assets.size() > 0:
				var asset_name = _prop_assets[rng.randi() % _prop_assets.size()]
				var asset_path = ASSETS_PATH + asset_name

				if ResourceLoader.exists(asset_path):
					var scene = load(asset_path)
					if scene:
						var instance = scene.instantiate()
						instance.position = pos
						instance.scale = Vector3(PROP_SCALE, PROP_SCALE, PROP_SCALE)
						props_node.add_child(instance)
						continue

			# Fallback: create simple crate or barrel
			var prop = MeshInstance3D.new()
			prop.position = pos

			var prop_box = BoxMesh.new()
			if rng.randf() > 0.5:
				prop_box.size = Vector3(0.8, 0.8, 0.8)  # Crate
			else:
				prop_box.size = Vector3(0.6, 1.0, 0.6)  # Barrel

			prop.mesh = prop_box

			var prop_mat = StandardMaterial3D.new()
			prop_mat.albedo_color = Color(0.4, 0.3, 0.2)
			prop.material_override = prop_mat

			props_node.add_child(prop)


func _place_asset(asset_list: Array, parent: Node3D, pos: Vector3, category: String) -> void:
	# Get fallback color based on category
	var fallback_color := Color.WHITE
	match category:
		"road": fallback_color = Color(0.3, 0.3, 0.35)  # Dark gray
		"building": fallback_color = Color(0.6, 0.5, 0.3)  # Brown/tan
		"nature": fallback_color = Color(0.2, 0.6, 0.2)  # Green
		"prop": fallback_color = Color(0.5, 0.4, 0.3)  # Wood color

	if asset_list.is_empty():
		# Create fallback box directly if no assets
		_create_fallback_box(parent, pos, fallback_color)
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(pos)

	var asset = asset_list[rng.randi() % asset_list.size()]
	var result = _instantiate_asset(asset, parent, pos, fallback_color)

	if result == null:
		_create_fallback_box(parent, pos, fallback_color)


func _instantiate_asset(asset_name: String, parent: Node3D, pos: Vector3, fallback_color: Color = Color.WHITE) -> Node3D:
	var path = ASSETS_PATH + asset_name

	# Check if asset exists (imported GLB shows as .scn or .glb with .import)
	var exists = ResourceLoader.exists(path)
	if not exists:
		# Create fallback box if asset doesn't exist
		return _create_fallback_box(parent, pos, fallback_color)

	var scene = load(path)
	if scene == null:
		return _create_fallback_box(parent, pos, fallback_color)

	var instance = scene.instantiate()
	if instance == null:
		return _create_fallback_box(parent, pos, fallback_color)

	instance.position = pos
	parent.add_child(instance)
	return instance


func _create_fallback_box(parent: Node3D, pos: Vector3, color: Color) -> Node3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position = pos

	var box = BoxMesh.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	mesh_instance.mesh = box

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)
	return mesh_instance


func _spawn_agents() -> void:
	print("  Spawning %d agents..." % agent_count)

	# Create simple agent bodies (colored cubes for now)
	# TODO: Use proper agent models from Cube Pets

	var rng = RandomNumberGenerator.new()
	rng.seed = 789

	for i in range(agent_count):
		var agent = _create_agent(i, rng)
		agents_node.add_child(agent)


func _create_agent(id: int, rng: RandomNumberGenerator) -> Node3D:
	# Create agent with physics body
	var agent = RigidBody3D.new()
	agent.name = "Agent_%d" % id

	# Random starting position (on a road)
	var x = rng.randi_range(-town_size / 2, town_size / 2) * 2
	var z = rng.randi_range(-town_size / 2, town_size / 2) * 2
	agent.position = Vector3(x, 1, z)

	# Add collision shape
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	collision.shape = sphere
	agent.add_child(collision)

	# Use cube pet model if available, otherwise fallback to sphere
	if _agent_models.size() > 0:
		var model_name = _agent_models[id % _agent_models.size()]
		var model_path = CUBE_PETS_PATH + model_name

		if ResourceLoader.exists(model_path):
			var model_scene = load(model_path)
			if model_scene:
				var model = model_scene.instantiate()
				model.scale = Vector3(AGENT_SCALE, AGENT_SCALE, AGENT_SCALE)
				agent.add_child(model)
			else:
				_add_fallback_visual(agent, rng)
		else:
			_add_fallback_visual(agent, rng)
	else:
		_add_fallback_visual(agent, rng)

	# Add AgentBehavior component (integrates BDI, Meeseeks, Spatial Memory)
	var behavior_script = load("res://scenes/fantasy_town/agent_behavior.gd")
	if behavior_script:
		var behavior = behavior_script.new()
		behavior.agent_id = str(id)
		behavior.wander_radius = town_size
		behavior.goal_update_interval = rng.randf_range(3.0, 8.0)
		agent.add_child(behavior)

	# Store in spatial memory
	if spatial_memory:
		spatial_memory.store(
			"agent_%d" % id,
			agent.position,
			{
				"type": "agent",
				"model": _agent_models[id % _agent_models.size()] if _agent_models.size() > 0 else "sphere",
				"home_position": Vector3(x, 1, z),
				"has_ai": true
			}
		)

	return agent


func _add_fallback_visual(agent: RigidBody3D, rng: RandomNumberGenerator) -> void:
	# Fallback: colored sphere
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh

	# Random color
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(rng.randf(), 0.7, 0.9)
	mesh_instance.material_override = material
	agent.add_child(mesh_instance)


func _init_spatial_memory() -> void:
	print("  Spatial memory initialized with %d nodes" % spatial_memory.size())

	# Demo: Find path from first building to first agent
	if building_positions.size() > 0 and agents_node.get_child_count() > 0:
		var start = building_positions[0]
		var end = agents_node.get_child(0).position

		var path = spatial_memory.find_path(
			"house_1",
			"agent_0"
		)

		if path:
			print("  Path found from house_1 to agent_0: distance %.1f" % path.distance)


func _input(event: InputEvent) -> void:
	# Camera controls
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotate_y(-event.relative.x * 0.01)
		camera.rotate_x(-event.relative.y * 0.01)

	# Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z -= 2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z += 2

	# Screenshot capture (F12 key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_capture_screenshot()


func _capture_screenshot() -> void:
	# Wait a frame to ensure render is complete
	await get_tree().process_frame

	var image = get_viewport().get_texture().get_image()

	# Generate filename with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "user://fantasy_town_%s.png" % timestamp

	image.save_png(filename)
	print("Screenshot saved: %s" % filename)

	# Also save to project folder for easy access
	var project_path = ProjectSettings.globalize_path(filename)
	print("Full path: %s" % project_path)
