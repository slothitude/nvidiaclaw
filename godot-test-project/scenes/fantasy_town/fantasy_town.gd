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
@export var agent_count := 10  # Number of agents to spawn

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

## Ollama Integration (AI-generated thoughts)
var ollama_client = null

## Nanobot Orchestrator (AI agent subprocesses)
var nanobot_orchestrator = null

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

## Click/Selection system
var _agent_panel = null
var _selected_agent: RigidBody3D = null
var _follow_camera: bool = false
var _camera_offset: Vector3 = Vector3(5, 8, 5)
var _default_camera_pos: Vector3 = Vector3.ZERO

## GOD Console
var _god_console = null

## Building purposes (library, market, tavern, etc.)
var building_purposes: Dictionary = {}  # building_name -> purpose data

## Building purpose types with services
const BUILDING_TYPES := {
	"library": {
		"description": "A place of knowledge and learning with access to SearXNG web search",
		"services": ["research", "searxng_search", "read", "study", "web_search"],
		"color": Color(0.3, 0.4, 0.8)
	},
	"university": {
		"description": "An academy for learning new skills - MCPs, Python apps, and more",
		"services": ["learn_skill", "learn_mcp", "learn_python", "study", "teach"],
		"skills_available": [
			# === DEVELOPMENT SKILLS ===
			{
				"name": "Python Scripting",
				"description": "Write and execute Python code",
				"type": "skill",
				"category": "development",
				"cost": 15,
				"prerequisites": [],
				"tools": ["python", "pip", "venv"]
			},
			{
				"name": "Git Version Control",
				"description": "Manage code versions, branches, and collaboration",
				"type": "skill",
				"category": "development",
				"cost": 10,
				"prerequisites": [],
				"tools": ["git", "github", "gitlab"]
			},
			{
				"name": "Testing & QA",
				"description": "Write unit tests, integration tests, and debug code",
				"type": "skill",
				"category": "development",
				"cost": 12,
				"prerequisites": ["Python Scripting"],
				"tools": ["pytest", "unittest", "coverage"]
			},
			{
				"name": "Code Review",
				"description": "Review code for quality, security, and best practices",
				"type": "skill",
				"category": "development",
				"cost": 8,
				"prerequisites": ["Python Scripting"],
				"tools": ["linter", "formatter", "sonar"]
			},
			{
				"name": "JavaScript/TypeScript",
				"description": "Build web applications and APIs",
				"type": "skill",
				"category": "development",
				"cost": 15,
				"prerequisites": [],
				"tools": ["node", "npm", "typescript"]
			},
			{
				"name": "SQL Databases",
				"description": "Query and manage relational databases",
				"type": "skill",
				"category": "development",
				"cost": 12,
				"prerequisites": [],
				"tools": ["postgresql", "mysql", "sqlite"]
			},
			# === DEVOPS SKILLS ===
			{
				"name": "Docker Containers",
				"description": "Build and run containerized applications",
				"type": "skill",
				"category": "devops",
				"cost": 15,
				"prerequisites": [],
				"tools": ["docker", "docker-compose"]
			},
			{
				"name": "Kubernetes",
				"description": "Orchestrate containers at scale",
				"type": "skill",
				"category": "devops",
				"cost": 20,
				"prerequisites": ["Docker Containers"],
				"tools": ["kubectl", "helm", "k8s"]
			},
			{
				"name": "CI/CD Pipelines",
				"description": "Automate build, test, and deployment",
				"type": "skill",
				"category": "devops",
				"cost": 15,
				"prerequisites": ["Git Version Control"],
				"tools": ["github-actions", "jenkins", "gitlab-ci"]
			},
			{
				"name": "Linux Administration",
				"description": "Manage Linux servers and systems",
				"type": "skill",
				"category": "devops",
				"cost": 12,
				"prerequisites": [],
				"tools": ["bash", "systemd", "ssh"]
			},
			{
				"name": "Monitoring & Logging",
				"description": "Set up observability for applications",
				"type": "skill",
				"category": "devops",
				"cost": 10,
				"prerequisites": ["Docker Containers"],
				"tools": ["prometheus", "grafana", "elk"]
			},
			# === DATA SKILLS ===
			{
				"name": "Data Analysis",
				"description": "Analyze datasets and create visualizations",
				"type": "skill",
				"category": "data",
				"cost": 12,
				"prerequisites": ["Python Scripting"],
				"tools": ["pandas", "numpy", "matplotlib"]
			},
			{
				"name": "Machine Learning",
				"description": "Build and train ML models",
				"type": "skill",
				"category": "data",
				"cost": 20,
				"prerequisites": ["Data Analysis"],
				"tools": ["scikit-learn", "pytorch", "tensorflow"]
			},
			{
				"name": "Web Scraping",
				"description": "Extract data from websites",
				"type": "skill",
				"category": "data",
				"cost": 10,
				"prerequisites": ["Python Scripting"],
				"tools": ["beautifulsoup", "selenium", "scrapy"]
			},
			{
				"name": "ETL Pipelines",
				"description": "Build data extraction and transformation pipelines",
				"type": "skill",
				"category": "data",
				"cost": 15,
				"prerequisites": ["SQL Databases", "Python Scripting"],
				"tools": ["airflow", "dbt", "spark"]
			},
			# === CLOUD SKILLS ===
			{
				"name": "AWS Cloud",
				"description": "Deploy and manage AWS services",
				"type": "skill",
				"category": "cloud",
				"cost": 18,
				"prerequisites": ["Linux Administration"],
				"tools": ["aws-cli", "ec2", "s3", "lambda"]
			},
			{
				"name": "Terraform IaC",
				"description": "Infrastructure as Code for cloud resources",
				"type": "skill",
				"category": "cloud",
				"cost": 15,
				"prerequisites": ["AWS Cloud"],
				"tools": ["terraform", "hcl"]
			},
			{
				"name": "Serverless Computing",
				"description": "Build serverless applications",
				"type": "skill",
				"category": "cloud",
				"cost": 12,
				"prerequisites": ["AWS Cloud"],
				"tools": ["lambda", "api-gateway", "dynamodb"]
			},
			# === SECURITY SKILLS ===
			{
				"name": "Security Auditing",
				"description": "Scan code and systems for vulnerabilities",
				"type": "skill",
				"category": "security",
				"cost": 15,
				"prerequisites": ["Linux Administration"],
				"tools": ["nmap", "nessus", "sonarqube"]
			},
			{
				"name": "Secrets Management",
				"description": "Manage credentials and secrets securely",
				"type": "skill",
				"category": "security",
				"cost": 10,
				"prerequisites": [],
				"tools": ["vault", "aws-secrets", "env"]
			},
			# === MCP INTEGRATIONS ===
			{
				"name": "Web Search (SearXNG)",
				"description": "Search the web for information via MCP",
				"type": "mcp",
				"category": "mcp",
				"cost": 10,
				"prerequisites": [],
				"tools": ["searxng"]
			},
			{
				"name": "Filesystem Access",
				"description": "Read and write files via MCP",
				"type": "mcp",
				"category": "mcp",
				"cost": 8,
				"prerequisites": [],
				"tools": ["filesystem-mcp"]
			},
			{
				"name": "GitHub Integration",
				"description": "Interact with GitHub repos via MCP",
				"type": "mcp",
				"category": "mcp",
				"cost": 12,
				"prerequisites": ["Git Version Control"],
				"tools": ["github-mcp"]
			},
			{
				"name": "Database Queries (MCP)",
				"description": "Query databases via MCP protocol",
				"type": "mcp",
				"category": "mcp",
				"cost": 10,
				"prerequisites": ["SQL Databases"],
				"tools": ["postgres-mcp", "sqlite-mcp"]
			},
			# === COMMUNICATION SKILLS ===
			{
				"name": "API Integration",
				"description": "Connect to external REST/GraphQL APIs",
				"type": "skill",
				"category": "communication",
				"cost": 8,
				"prerequisites": [],
				"tools": ["http", "rest", "graphql"]
			},
			{
				"name": "Memory Enhancement",
				"description": "Improve spatial memory recall and storage",
				"type": "skill",
				"category": "communication",
				"cost": 5,
				"prerequisites": [],
				"tools": ["spatial-memory"]
			},
			{
				"name": "Communication Protocol",
				"description": "Learn new languages and protocols",
				"type": "skill",
				"category": "communication",
				"cost": 7,
				"prerequisites": [],
				"tools": ["json", "yaml", "xml"]
			}
		],
		"color": Color(0.6, 0.3, 0.7)
	},
	"tavern": {
		"description": "A cozy place to rest and socialize",
		"services": ["rest", "chat", "hear_rumors", "drink"],
		"color": Color(0.7, 0.5, 0.3)
	},
	"market": {
		"description": "A bustling marketplace",
		"services": ["trade", "buy", "sell", "barter"],
		"color": Color(0.8, 0.7, 0.3)
	},
	"temple": {
		"description": "A sacred place for meditation",
		"services": ["meditate", "heal", "bless", "pray"],
		"color": Color(0.9, 0.9, 0.95)
	},
	"workshop": {
		"description": "A place for crafting and creation",
		"services": ["craft", "repair", "build", "invent"],
		"color": Color(0.6, 0.5, 0.4)
	},
	"home": {
		"description": "A cozy dwelling",
		"services": ["rest", "sleep", "store"],
		"color": Color(0.6, 0.7, 0.6)
	},
	"guard_post": {
		"description": "A defensive watchtower",
		"services": ["patrol", "watch", "protect"],
		"color": Color(0.4, 0.4, 0.5)
	},
	"garden": {
		"description": "A peaceful garden",
		"services": ["relax", "gather", "enjoy_nature"],
		"color": Color(0.4, 0.8, 0.4)
	}
}

const BUILDING_WEIGHTS := {
	"library": 5,      # Fewer libraries
	"university": 3,   # Even fewer universities
	"tavern": 8,
	"market": 10,
	"temple": 5,
	"workshop": 8,
	"home": 40,        # Many homes
	"guard_post": 5,
	"garden": 7
}


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  AWR Fantasy Town - World-Breaking Demo")
	print("  Target: 1000+ physics-based agents with AI thoughts")
	print("=".repeat(60) + "\n")

	# Load AWR components
	_load_awr()

	# Initialize Ollama client for AI-generated thoughts
	_init_ollama()

	# Initialize Nanobot Orchestrator
	_init_nanobot()

	# Create necessary directories
	_init_directories()

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
	if ollama_client and ollama_client.is_available():
		print("  Ollama AI thoughts: ENABLED")
	else:
		print("  Ollama AI thoughts: using fallback mode")
	if nanobot_orchestrator:
		print("  Nanobot Orchestrator: ENABLED")
	print("  Ready for simulation!\n")

	# Setup agent panel UI
	_setup_agent_panel()

	# Setup GOD console
	_setup_god_console()

	# Setup GOD controls
	_setup_god_controls()

	# Setup shared location memory
	_setup_shared_location_memory()

	# Setup minimap
	_setup_minimap()

	# Setup grass and sky
	_setup_environment()

	# Setup Grand Computer (Claude's physical presence)
	_setup_grand_computer()

	# Setup Agent Evolution system
	_setup_evolution()

	# Store default camera position
	_default_camera_pos = camera.position


func _load_awr() -> void:
	# Load spatial memory
	var SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	spatial_memory = SpatialMemoryClass.new(5.0)  # 5 unit cell size
	print("  ✓ AWR Spatial Memory loaded")


func _init_ollama() -> void:
	# Load and create Ollama client
	var OllamaClientClass = load("res://scenes/fantasy_town/ollama_client.gd")
	if OllamaClientClass:
		ollama_client = OllamaClientClass.new()
		add_child(ollama_client)
		print("  ✓ Ollama client initialized (checking connection...)")
	else:
		push_warning("  ✗ Failed to load Ollama client")


func _init_nanobot() -> void:
	# Load and create Nanobot Orchestrator
	var NanobotOrchestratorClass = load("res://scenes/fantasy_town/nanobot_orchestrator.gd")
	if NanobotOrchestratorClass:
		nanobot_orchestrator = NanobotOrchestratorClass.new()
		add_child(nanobot_orchestrator)
		print("  ✓ Nanobot Orchestrator initialized")
	else:
		push_warning("  ✗ Failed to load Nanobot Orchestrator")


func _init_directories() -> void:
	# Create directories for souls and agent memories
	DirAccess.make_dir_recursive_absolute("user://souls/")
	DirAccess.make_dir_recursive_absolute("user://souls/soul_templates/")
	DirAccess.make_dir_recursive_absolute("user://agent_memories/")
	print("  ✓ Created souls and memory directories")


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
	# Assign purpose and name for all building types
	var purpose = _assign_building_purpose(building_positions.size() + 1)
	var building_name = _generate_building_name(base_pos, purpose)

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

				# Add label
				_add_building_label(house, building_name, purpose)

				buildings_node.add_child(house)
				building_positions.append(base_pos)
				if spatial_memory:
					spatial_memory.store(
						building_name.to_lower().replace(" ", "_"),
						base_pos,
						{
							"type": "building",
							"style": "modular_complete",
							"asset": house_name,
							"purpose": purpose["type"],
							"description": purpose["description"],
							"services": purpose["services"],
							"name": building_name
						}
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

				# Add label
				_add_building_label(tower, building_name, purpose)

				buildings_node.add_child(tower)
				building_positions.append(base_pos)
				if spatial_memory:
					spatial_memory.store(
						building_name.to_lower().replace(" ", "_"),
						base_pos,
						{
							"type": "building",
							"style": "tower",
							"asset": tower_name,
							"purpose": purpose["type"],
							"description": purpose["description"],
							"services": purpose["services"],
							"name": building_name
						}
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
	var house = StaticBody3D.new()  # Changed from Node3D to StaticBody3D for collision
	house.position = base_pos

	# Assign purpose and name
	var purpose = _assign_building_purpose(building_positions.size() + 1)
	var building_name = _generate_building_name(base_pos, purpose)
	house.set_meta("building_name", building_name)
	house.set_meta("building_purpose", purpose["type"])

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

	# Add collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(3 * HOUSE_SCALE, 6 * HOUSE_SCALE, 3 * HOUSE_SCALE)
	collision.shape = box_shape
	collision.position.y = 3 * HOUSE_SCALE
	house.add_child(collision)

	# Add label
	_add_building_label(house, building_name, purpose)

	buildings_node.add_child(house)
	building_positions.append(base_pos)

	# Store in spatial memory
	if spatial_memory:
		spatial_memory.store(
			building_name.to_lower().replace(" ", "_"),
			base_pos,
			{
				"type": "building",
				"style": "modular_assembled",
				"purpose": purpose["type"],
				"description": purpose["description"],
				"services": purpose["services"],
				"name": building_name
			}
		)


func _build_fantasy_house(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	var house = Node3D.new()
	house.position = base_pos

	# Assign purpose and name
	var purpose = _assign_building_purpose(building_positions.size() + 1)
	var building_name = _generate_building_name(base_pos, purpose)

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

	# Add label
	_add_building_label(house, building_name, purpose)

	buildings_node.add_child(house)
	building_positions.append(base_pos)

	# Store in spatial memory
	if spatial_memory:
		spatial_memory.store(
			building_name.to_lower().replace(" ", "_"),
			base_pos,
			{
				"type": "building",
				"style": "fantasy",
				"purpose": purpose["type"],
				"description": purpose["description"],
				"services": purpose["services"],
				"name": building_name
			}
		)


func _build_procedural_house_simple(base_pos: Vector3, rng: RandomNumberGenerator) -> void:
	# Simple procedural house fallback
	var house = Node3D.new()
	house.position = base_pos

	# Assign purpose and name
	var purpose = _assign_building_purpose(building_positions.size() + 1)
	var building_name = _generate_building_name(base_pos, purpose)

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

	# Add label
	_add_building_label(house, building_name, purpose)

	buildings_node.add_child(house)
	building_positions.append(base_pos)

	# Store in spatial memory
	if spatial_memory:
		spatial_memory.store(
			building_name.to_lower().replace(" ", "_"),
			base_pos,
			{
				"type": "building",
				"style": "procedural",
				"purpose": purpose["type"],
				"description": purpose["description"],
				"services": purpose["services"],
				"name": building_name
			}
		)


func _find_modular_component(patterns: Array) -> String:
	for pattern in patterns:
		for asset in _modular_components:
			if asset == pattern:
				return asset
	if _modular_components.size() > 0:
		return _modular_components[0]
	return ""


func _assign_building_purpose(building_index: int) -> Dictionary:
	# Use weighted random selection for building types
	var total_weight = 0
	for type in BUILDING_WEIGHTS.keys():
		total_weight += BUILDING_WEIGHTS[type]

	var roll = randi() % total_weight
	var current = 0

	for type in BUILDING_WEIGHTS.keys():
		current += BUILDING_WEIGHTS[type]
		if roll < current:
			var type_data = BUILDING_TYPES[type].duplicate()
			type_data["type"] = type
			return type_data

	# Fallback to home
	var fallback = BUILDING_TYPES["home"].duplicate()
	fallback["type"] = "home"
	return fallback


func get_buildings_by_purpose(purpose: String) -> Array:
	"""Get all buildings with a specific purpose"""
	var result = []
	for i in range(building_positions.size()):
		var building_name = "house_%d" % (i + 1)
		if spatial_memory:
			var node = spatial_memory.get_node(building_name)
			if node and node.metadata.get("purpose") == purpose:
				result.append({
					"name": building_name,
					"position": building_positions[i],
					"services": node.metadata.get("services", [])
				})
	return result


func get_library_buildings() -> Array:
	"""Get all library buildings (for SearXNG access)"""
	return get_buildings_by_purpose("library")


func _generate_building_name(pos: Vector3, purpose: Dictionary) -> String:
	"""Generate a descriptive name for a building based on location and purpose"""
	var direction = ""
	if pos.x > town_size * 0.5:
		direction = "East"
	elif pos.x < -town_size * 0.5:
		direction = "West"
	elif pos.z > town_size * 0.5:
		direction = "South"
	elif pos.z < -town_size * 0.5:
		direction = "North"
	else:
		direction = "Central"

	var purpose_type = purpose.get("type", "house")
	var name_suffix = ""

	match purpose_type:
		"library":
			name_suffix = "Library"
		"university":
			name_suffix = "University"
		"tavern":
			name_suffix = "Tavern"
		"market":
			name_suffix = "Market"
		"temple":
			name_suffix = "Temple"
		"workshop":
			name_suffix = "Workshop"
		"guard_post":
			name_suffix = "Guard Post"
		"garden":
			name_suffix = "Garden"
		_:
			name_suffix = "House"

	return "%s %s" % [direction, name_suffix]


func _add_building_label(building: Node3D, name: String, purpose: Dictionary) -> void:
	"""Add a 3D label above a building"""
	var label = Label3D.new()
	label.text = name
	label.position = Vector3(0, 2, 0)  # User requested height of 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0006  # Same size as speech bubbles
	label.font_size = 24
	label.modulate = Color(1, 1, 1, 0.9)

	# Color based on purpose type
	var color = purpose.get("color", Color.WHITE)
	label.modulate = color

	building.add_child(label)


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

	# Set collision layer for click detection
	# Layer 1 = world, Layer 2 = agents, Layer 4 = buildings
	agent.collision_layer = 2  # Agents are on layer 2
	agent.collision_mask = 1 | 4  # Collide with world and buildings

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

		# Pass Ollama client to agent for AI-generated thoughts
		if ollama_client:
			behavior.set_ollama_client(ollama_client)

		# Pass Nanobot orchestrator to agent
		if nanobot_orchestrator:
			behavior.set_nanobot_orchestrator(nanobot_orchestrator)

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


func _setup_agent_panel() -> void:
	# Load and instantiate agent panel
	var panel_scene = load("res://scenes/fantasy_town/agent_panel.tscn")
	if panel_scene:
		_agent_panel = panel_scene.instantiate()
		add_child(_agent_panel)

		# Setup with Ollama client
		if ollama_client:
			_agent_panel.setup(ollama_client)

		# Connect close signal
		_agent_panel.closed.connect(_on_panel_closed)
		print("  ✓ Agent panel UI loaded")
	else:
		push_warning("Failed to load agent panel")


func _setup_god_console() -> void:
	# Load and instantiate GOD console
	var console_script = load("res://scenes/fantasy_town/god_console.gd")
	if console_script:
		var god_console = console_script.new()
		god_console.name = "GodConsole"
		add_child(god_console)

		# Setup with available systems
		var divine_system = get_node_or_null("DivineSystem")
		var task_economy = get_node_or_null("TaskEconomy")
		var mcp_client = get_node_or_null("MCPClient")

		god_console.setup(divine_system, task_economy, mcp_client, nanobot_orchestrator)
		print("  ✓ GOD console initialized")
	else:
		push_warning("Failed to load GOD console")


func _setup_god_controls() -> void:
	# Load and instantiate GOD controls panel
	var controls_script = load("res://scenes/fantasy_town/god_controls.gd")
	if controls_script:
		var god_controls = controls_script.new()
		god_controls.name = "GodControls"
		add_child(god_controls)

		# Setup with available systems
		var divine_system = get_node_or_null("DivineSystem")
		var task_economy = get_node_or_null("TaskEconomy")

		god_controls.setup(divine_system, nanobot_orchestrator, task_economy)
		print("  ✓ GOD controls panel initialized")
	else:
		push_warning("Failed to load GOD controls")


func _setup_shared_location_memory() -> void:
	# Load and create shared location memory
	var shared_memory_script = load("res://scenes/fantasy_town/shared_location_memory.gd")
	if shared_memory_script:
		var shared_memory = shared_memory_script.new()
		shared_memory.name = "SharedLocationMemory"
		add_child(shared_memory)
		print("  ✓ Shared location memory initialized")
	else:
		push_warning("Failed to load shared location memory")


func _setup_minimap() -> void:
	# Load and create minimap
	var minimap_script = load("res://scenes/fantasy_town/minimap.gd")
	if minimap_script:
		var minimap = minimap_script.new()
		minimap.name = "Minimap"
		minimap.set_camera(camera)
		add_child(minimap)
		print("  ✓ Minimap initialized")
	else:
		push_warning("Failed to load minimap")


func _setup_environment() -> void:
	# Setup grass spawner
	var grass_script = load("res://scenes/fantasy_town/grass_spawner.gd")
	if grass_script:
		var grass = grass_script.new()
		grass.name = "GrassSpawner"
		add_child(grass)
		print("  ✓ Grass spawner initialized")

	# Setup sky controller (if not already in scene)
	var sky_controller_script = load("res://scenes/fantasy_town/sky_controller.gd")
	if sky_controller_script and not has_node("SkyController"):
		var sky = sky_controller_script.new()
		sky.name = "SkyController"
		add_child(sky)
		print("  ✓ Sky controller initialized")


func _setup_grand_computer() -> void:
	# Load and create Grand Computer (Claude's physical presence)
	var grand_computer_script = load("res://scenes/fantasy_town/grand_computer.gd")
	var grand_computer_visual_script = load("res://scenes/fantasy_town/grand_computer_visual.gd")

	if grand_computer_script and grand_computer_visual_script:
		# Create the Grand Computer logic
		var grand_computer = grand_computer_script.new()
		grand_computer.name = "GrandComputer"
		add_child(grand_computer)

		# Create the visual representation
		var visual = grand_computer_visual_script.new()
		visual.name = "GrandComputerVisual"
		visual.position = Vector3(15, 0, 0)  # Place near center of town
		add_child(visual)

		# Get references to other systems
		var divine_system = get_node_or_null("DivineSystem")
		var task_economy = get_node_or_null("TaskEconomy")
		var shared_memory = get_node_or_null("SharedLocationMemory")

		# Setup Grand Computer with all references
		grand_computer.setup(ollama_client, nanobot_orchestrator, task_economy, divine_system, shared_memory)
		grand_computer.set_position(visual.position)
		visual.setup(grand_computer)

		# Register Grand Computer location in shared memory
		if shared_memory:
			shared_memory.discover_location("grand_computer", "Grand Computer", visual.position, "ai_temple")

		# Store in spatial memory
		if spatial_memory:
			spatial_memory.store(
				"grand_computer",
				visual.position,
				{
					"type": "ai_temple",
					"name": "Grand Computer",
					"description": "The physical embodiment of Claude - agents visit for AI-generated tasks",
					"services": ["ai_tasks", "wisdom", "quests", "guidance"]
				}
			)

		print("  ✓ Grand Computer (Claude) initialized at position (%.1f, %.1f)" % [visual.position.x, visual.position.z])
		print("    - Agents can visit for AI-generated tasks and wisdom")
	else:
		push_warning("Failed to load Grand Computer")


func _setup_evolution() -> void:
	# Load and create Agent Evolution system
	var evolution_script = load("res://scenes/fantasy_town/agent_evolution.gd")

	if evolution_script:
		var evolution = evolution_script.new()
		evolution.name = "AgentEvolution"
		add_child(evolution)

		# Get references
		var divine_system = get_node_or_null("DivineSystem")
		var task_economy = get_node_or_null("TaskEconomy")
		var shared_memory = get_node_or_null("SharedLocationMemory")

		# Setup evolution system
		evolution.setup(shared_memory, nanobot_orchestrator, task_economy, self)

		print("  ✓ Agent Evolution system initialized")
		print("    - Agents know task sources: Grand Computer, Temple, Task Board")
		print("    - Failed agents go to graveyard")
		print("    - New agents inherit improved traits")
	else:
		push_warning("Failed to load Agent Evolution system")


func _on_panel_closed() -> void:
	_selected_agent = null
	_follow_camera = false
	# Smoothly return camera to default position
	var tween = create_tween()
	tween.tween_property(camera, "position", _default_camera_pos, 0.5)


func _input(event: InputEvent) -> void:
	# Camera controls
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotate_y(-event.relative.x * 0.01)
		camera.rotate_x(-event.relative.y * 0.01)

	# Zoom and click
	if event is InputEventMouseButton:
		print("Mouse button event: button=%s pressed=%s" % [event.button_index, event.pressed])
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z -= 2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z += 2

		# Left click on agent
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Left click detected, trying to select agent...")
			_try_select_agent()

	# Screenshot capture (F12 key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_capture_screenshot()

	# Escape to deselect
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _agent_panel and _agent_panel.is_visible():
			_agent_panel.hide()
			_selected_agent = null
			_follow_camera = false


func _try_select_agent() -> void:
	# Raycast from camera to find clicked agent
	var camera_3d = camera
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera_3d.project_ray_origin(mouse_pos)
	var to = from + camera_3d.project_ray_normal(mouse_pos) * 1000

	var space_state = get_world_3d().direct_space_state

	# First, try to hit only agents (collision layer 2)
	var agent_query = PhysicsRayQueryParameters3D.create(from, to)
	agent_query.collide_with_areas = false
	agent_query.collide_with_bodies = true
	agent_query.collision_mask = 2  # Only check layer 2 (agents)

	var agent_result = space_state.intersect_ray(agent_query)

	if agent_result and agent_result.has("collider"):
		var collider = agent_result.collider
		if collider is RigidBody3D:
			for child in collider.get_children():
				if child is AgentBehavior:
					_select_agent(collider, child)
					return

	# If no agent hit, check buildings (collision layer 4)
	var building_query = PhysicsRayQueryParameters3D.create(from, to)
	building_query.collide_with_areas = false
	building_query.collide_with_bodies = true
	building_query.collision_mask = 4  # Only check layer 4 (buildings)

	var building_result = space_state.intersect_ray(building_query)

	if building_result and building_result.has("collider"):
		var collider = building_result.collider
		# Check for building metadata
		if collider.has_meta("building_data"):
			_show_building_info(collider)
			return
		# Also check parent for building data
		if collider.get_parent() and collider.get_parent().has_meta("building_data"):
			_show_building_info(collider.get_parent())
			return


func _show_building_info(building: Node) -> void:
	var data = building.get_meta("building_data")
	print("Building: %s - %s" % [data.get("type", "unknown"), data.get("purpose", "unknown")])
	# TODO: Show building info in UI panel


func _select_agent(agent_body: RigidBody3D, agent_behavior: AgentBehavior) -> void:
	_selected_agent = agent_body
	_follow_camera = true

	# Show agent panel
	if _agent_panel:
		_agent_panel.show_agent(agent_behavior)

	print("Selected agent: %s" % agent_behavior.agent_id)


func _process(_delta: float) -> void:
	# Follow selected agent with camera
	if _follow_camera and _selected_agent and _selected_agent.is_inside_tree():
		var target_pos = _selected_agent.global_position + _camera_offset
		camera.position = camera.position.lerp(target_pos, 0.05)

	# Update minimap
	_update_minimap()


func _update_minimap() -> void:
	var minimap = get_node_or_null("Minimap")
	if not minimap:
		return

	# Collect agent data for minimap
	var agent_data = []
	for agent in agents_node.get_children():
		var behavior = agent.get_node_or_null("AgentBehavior")
		if behavior:
			agent_data.append({
				"position": agent.position,
				"agent_id": behavior.agent_id,
				"velocity": behavior._velocity if behavior.has_method("get") else Vector3.ZERO
			})

	minimap.set_agents(agent_data)

	# Collect building data for minimap
	var building_data = []
	for building in buildings_node.get_children():
		building_data.append({
			"position": building.position,
			"purpose": building.get_meta("purpose", "building")
		})
	minimap.set_buildings(building_data)

	# Update selected agent on minimap
	if _selected_agent:
		var behavior = _selected_agent.get_node_or_null("AgentBehavior")
		if behavior:
			minimap.set_selected_agent(behavior.agent_id)


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


## Save all agent memories and souls when exiting
func _exit_tree() -> void:
	print("\nSaving agent memories...")
	var saved_count = 0

	for agent in agents_node.get_children():
		if agent is RigidBody3D:
			for child in agent.get_children():
				if child.has_method("save_personal_memory"):
					child.save_personal_memory()
					saved_count += 1
					break

	print("Saved %d agent memories" % saved_count)
