## grass_spawner.gd - Procedural Grass for Fantasy Town
## Spawns grass meshes using MultiMesh for performance

class_name GrassSpawner
extends Node3D

## Configuration
@export var grass_area_size: Vector2 = Vector2(80, 80)
@export var grass_density: int = 300  # Grass blades per chunk
@export var chunk_size: float = 20.0
@export var grass_height: float = 0.4

## Material
var _grass_material: ShaderMaterial = null
var _time: float = 0.0
var _grass_chunks: Array = []


func _ready() -> void:
	_create_grass_material()
	_spawn_grass()
	print("[GrassSpawner] Grass spawned with %d chunks" % _grass_chunks.size())


func _process(delta: float) -> void:
	_time += delta
	if _grass_material:
		_grass_material.set_shader_parameter("time", _time)


func _create_grass_material() -> void:
	var shader = load("res://shaders/grass_wind.gdshader")
	if shader:
		_grass_material = ShaderMaterial.new()
		_grass_material.shader = shader
		_grass_material.set_shader_parameter("wind_strength", 0.3)
		_grass_material.set_shader_parameter("wind_speed", 1.2)
		_grass_material.set_shader_parameter("time", 0.0)


func _spawn_grass() -> void:
	var half_area = grass_area_size / 2.0
	var chunks_x = int(ceil(grass_area_size.x / chunk_size))
	var chunks_z = int(ceil(grass_area_size.y / chunk_size))

	for cx in range(chunks_x):
		for cz in range(chunks_z):
			var origin = Vector3(
				-half_area.x + cx * chunk_size,
				0,
				-half_area.y + cz * chunk_size
			)
			_spawn_chunk(origin)


func _spawn_chunk(origin: Vector3) -> void:
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true

	var blade = _create_blade_mesh()
	multimesh.mesh = blade
	multimesh.instance_count = grass_density

	seed(hash(str(origin)))

	for i in range(grass_density):
		var pos = Vector3(randf() * chunk_size, 0, randf() * chunk_size)
		var rot = randf() * TAU
		var scale = 0.6 + randf() * 0.8

		var t = Transform3D().rotated(Vector3.UP, rot).scaled(Vector3(scale, scale, scale))
		t.origin = origin + pos
		multimesh.set_instance_transform(i, t)
		multimesh.set_instance_color(i, Color(0.8 + randf() * 0.4, 0.8 + randf() * 0.4, 0.8 + randf() * 0.4))

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _grass_material:
		mmi.material_override = _grass_material
	add_child(mmi)
	_grass_chunks.append(mmi)


func _create_blade_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)

	var verts = PackedVector3Array([
		Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), Vector3(0, grass_height, 0)
	])
	var norms = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uvs = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0)])
	var idx = PackedInt32Array([0, 1, 2])

	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
