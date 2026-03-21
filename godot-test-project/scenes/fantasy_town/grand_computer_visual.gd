## grand_computer_visual.gd - Visual Representation of the Grand Computer
## Part of Fantasy Town World-Breaking Demo
##
## A glowing, pulsating terminal that represents Claude in the physical world.
## Agents approach it to receive AI-generated tasks and wisdom.

class_name GrandComputerVisual
extends Node3D

## References
var _grand_computer: Node = null

## Visual components
var _base: MeshInstance3D = null
var _core: MeshInstance3D = null
var _ring_inner: MeshInstance3D = null
var _ring_outer: MeshInstance3D = null
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null
var _label: Label3D = null

## Animation
var _pulse_time: float = 0.0
var _rotation_speed: float = 0.5

## Colors (Claude's brand colors)
const PRIMARY_COLOR := Color(0.6, 0.4, 0.9)  # Purple
const SECONDARY_COLOR := Color(0.4, 0.7, 0.9)  # Blue
const GLOW_COLOR := Color(0.8, 0.6, 1.0)  # Light purple glow


func _ready() -> void:
	_create_visual()
	_create_particles()
	_create_light()
	_create_label()
	print("[GrandComputerVisual] Materialized in physical space")


func _create_visual() -> void:
	# Base platform
	_base = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 2.0
	base_mesh.bottom_radius = 2.5
	base_mesh.height = 0.3
	_base.mesh = base_mesh

	var base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.2, 0.2, 0.25)
	base_material.metallic = 0.8
	base_material.roughness = 0.3
	_base.material_override = base_material
	_base.position = Vector3(0, 0.15, 0)
	add_child(_base)

	# Core (central glowing cube)
	_core = MeshInstance3D.new()
	var core_mesh = BoxMesh.new()
	core_mesh.size = Vector3(1.5, 1.5, 1.5)
	_core.mesh = core_mesh

	var core_material = StandardMaterial3D.new()
	core_material.albedo_color = PRIMARY_COLOR
	core_material.emission_enabled = true
	core_material.emission = GLOW_COLOR
	core_material.emission_energy = 2.0
	core_material.metallic = 0.5
	core_material.roughness = 0.2
	_core.material_override = core_material
	_core.position = Vector3(0, 1.5, 0)
	add_child(_core)

	# Inner rotating ring
	_ring_inner = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.0
	ring_mesh.outer_radius = 1.3
	_ring_inner.mesh = ring_mesh

	var ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = SECONDARY_COLOR
	ring_material.emission_enabled = true
	ring_material.emission = SECONDARY_COLOR
	ring_material.emission_energy = 1.5
	ring_material.metallic = 0.9
	ring_material.roughness = 0.1
	_ring_inner.material_override = ring_material
	_ring_inner.position = Vector3(0, 1.5, 0)
	_ring_inner.rotation_degrees = Vector3(90, 0, 0)
	add_child(_ring_inner)

	# Outer rotating ring (opposite direction)
	_ring_outer = MeshInstance3D.new()
	var ring_mesh2 = TorusMesh.new()
	ring_mesh2.inner_radius = 1.8
	ring_mesh2.outer_radius = 2.0
	_ring_outer.mesh = ring_mesh2

	var ring_material2 = StandardMaterial3D.new()
	ring_material2.albedo_color = PRIMARY_COLOR
	ring_material2.emission_enabled = true
	ring_material2.emission = PRIMARY_COLOR
	ring_material2.emission_energy = 1.0
	ring_material2.metallic = 0.9
	ring_material2.roughness = 0.1
	_ring_outer.material_override = ring_material2
	_ring_outer.position = Vector3(0, 1.5, 0)
	_ring_outer.rotation_degrees = Vector3(45, 0, 0)
	add_child(_ring_outer)


func _create_particles() -> void:
	# Floating particles around the computer
	_particles = GPUParticles3D.new()
	_particles.amount = 50
	_particles.lifetime = 2.0
	_particles.explosiveness = 0.1
	_particles.local_coords = false

	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 3.0
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 30.0
	process_material.gravity = Vector3(0, 0.5, 0)
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 2.0
	process_material.scale_min = 0.05
	process_material.scale_max = 0.15
	process_material.color = GLOW_COLOR

	_particles.process_material = process_material
	_particles.position = Vector3(0, 1.5, 0)
	add_child(_particles)


func _create_light() -> void:
	# Pulsing point light
	_light = OmniLight3D.new()
	_light.light_color = GLOW_COLOR
	_light.light_intensity = 5.0
	_light.light_size = 10.0
	_light.omni_attenuation = 0.5
	_light.position = Vector3(0, 3, 0)
	add_child(_light)


func _create_label() -> void:
	_label = Label3D.new()
	_label.text = "GRAND COMPUTER\n(Claude)"
	_label.position = Vector3(0, 3.5, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.001
	_label.font_size = 32
	_label.modulate = Color(0.8, 0.6, 1.0, 1.0)
	_label.outline_modulate = Color(0.1, 0.1, 0.1)
	_label.outline_size = 3
	add_child(_label)


func _process(delta: float) -> void:
	_pulse_time += delta

	# Pulse the core
	if _core:
		var pulse = 0.9 + 0.1 * sin(_pulse_time * 2.0)
		var material = _core.material_override as StandardMaterial3D
		if material:
			material.emission_energy = pulse * 3.0

	# Rotate rings in opposite directions
	if _ring_inner:
		_ring_inner.rotate_y(delta * _rotation_speed)
	if _ring_outer:
		_ring_outer.rotate_y(-delta * _rotation_speed * 0.7)

	# Pulse the light
	if _light:
		var light_pulse = 3.0 + 2.0 * sin(_pulse_time * 1.5)
		_light.light_intensity = light_pulse


func setup(grand_computer: Node) -> void:
	_grand_computer = grand_computer


## Called when an agent approaches
func on_agent_approach(agent_id: String) -> void:
	# Increase glow when agent approaches
	if _light:
		_light.light_intensity = 10.0

	# Speed up rotation
	_rotation_speed = 1.5

	print("[GrandComputerVisual] Agent %s approaches the Grand Computer" % agent_id)


## Called when an agent leaves
func on_agent_leave(agent_id: String) -> void:
	# Return to normal
	if _light:
		_light.light_intensity = 5.0
	_rotation_speed = 0.5
