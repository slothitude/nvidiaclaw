## sky_controller.gd - Procedural Sky Controller for Fantasy Town
## Part of Fantasy Town World-Breaking Demo
##
## Controls the procedural sky with:
## - Day/night cycle
## - Animated clouds
## - Flying birds
## - Dynamic sun position

class_name SkyController
extends WorldEnvironment

## Day/night cycle settings
@export var day_duration: float = 600.0  # Seconds for a full day (10 min default)
@export var start_hour: float = 8.0  # Start at 8 AM
@export var enable_day_night: bool = true

## Sky colors for different times
@export var dawn_color_top: Color = Color(0.6, 0.4, 0.6)
@export var dawn_color_bottom: Color = Color(0.9, 0.6, 0.4)
@export var day_color_top: Color = Color(0.4, 0.6, 0.9)
@export var day_color_bottom: Color = Color(0.7, 0.85, 1.0)
@export var dusk_color_top: Color = Color(0.4, 0.3, 0.5)
@export var dusk_color_bottom: Color = Color(0.9, 0.5, 0.3)
@export var night_color_top: Color = Color(0.05, 0.05, 0.15)
@export var night_color_bottom: Color = Color(0.1, 0.1, 0.2)

## Time tracking
var _time: float = 0.0
var _game_hour: float = 8.0

## Sky material
var _sky_material: ShaderMaterial = null

## Directional light (sun)
var _sun_light: DirectionalLight3D = null


func _ready() -> void:
	_setup_sky()
	_setup_sun()
	print("[SkyController] Sky initialized. Day duration: %.1f seconds" % day_duration)


func _process(delta: float) -> void:
	if not enable_day_night:
		return

	_time += delta

	# Calculate game hour (0-24)
	var day_progress = fmod(_time, day_duration) / day_duration
	_game_hour = start_hour + day_progress * 24.0
	_game_hour = fmod(_game_hour, 24.0)

	# Update sky
	_update_sky_colors()
	_update_sun_position()
	_update_clouds()


func _setup_sky() -> void:
	# Create sky material from shader
	var shader = load("res://shaders/sky_with_clouds.gdshader")
	if not shader:
		push_error("[SkyController] Could not load sky shader!")
		return

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = shader

	# Create sky resource
	var sky = Sky.new()
	sky.sky_material = _sky_material

	# Create environment
	if not environment:
		environment = Environment.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

	# Set initial parameters
	_sky_material.set_shader_parameter("cloud_speed", 0.05)
	_sky_material.set_shader_parameter("cloud_scale", 2.0)
	_sky_material.set_shader_parameter("cloud_density", 0.5)
	_sky_material.set_shader_parameter("bird_speed", 1.0)
	_sky_material.set_shader_parameter("bird_count", 8)
	_sky_material.set_shader_parameter("time", 0.0)


func _setup_sun() -> void:
	# Find existing sun or create one
	_sun_light = get_node_or_null("../Sun")
	if not _sun_light:
		_sun_light = get_node_or_null("../DirectionalLight3D")

	if not _sun_light:
		# Create sun light
		_sun_light = DirectionalLight3D.new()
		_sun_light.name = "Sun"
		_sun_light.light_color = Color(1.0, 0.95, 0.8)
		_sun_light.light_intensity = 1.0
		_sun_light.shadow_enabled = true
		get_parent().add_child(_sun_light)


func _update_sky_colors() -> void:
	if not _sky_material:
		return

	# Determine time of day
	var hour = _game_hour
	var sky_top: Color
	var sky_bottom: Color

	if hour < 6.0:  # Night
		sky_top = night_color_top
		sky_bottom = night_color_bottom
	elif hour < 8.0:  # Dawn
		var t = (hour - 6.0) / 2.0
		sky_top = night_color_top.lerp(dawn_color_top, t)
		sky_bottom = night_color_bottom.lerp(dawn_color_bottom, t)
	elif hour < 10.0:  # Morning
		var t = (hour - 8.0) / 2.0
		sky_top = dawn_color_top.lerp(day_color_top, t)
		sky_bottom = dawn_color_bottom.lerp(day_color_bottom, t)
	elif hour < 17.0:  # Day
		sky_top = day_color_top
		sky_bottom = day_color_bottom
	elif hour < 19.0:  # Dusk
		var t = (hour - 17.0) / 2.0
		sky_top = day_color_top.lerp(dusk_color_top, t)
		sky_bottom = day_color_bottom.lerp(dusk_color_bottom, t)
	elif hour < 21.0:  # Evening
		var t = (hour - 19.0) / 2.0
		sky_top = dusk_color_top.lerp(night_color_top, t)
		sky_bottom = dusk_color_bottom.lerp(night_color_bottom, t)
	else:  # Night
		sky_top = night_color_top
		sky_bottom = night_color_bottom

	# Update shader colors
	_sky_material.set_shader_parameter("sky_color_top", Vector4(sky_top.r, sky_top.g, sky_top.b, 1.0))
	_sky_material.set_shader_parameter("sky_color_bottom", Vector4(sky_bottom.r, sky_bottom.g, sky_bottom.b, 1.0))

	# Update sun color based on time
	if _sun_light:
		if hour < 6.0 or hour > 20.0:  # Night
			_sun_light.light_intensity = 0.1
		elif hour < 8.0 or hour > 18.0:  # Dawn/Dusk
			_sun_light.light_intensity = 0.5
			_sun_light.light_color = Color(1.0, 0.7, 0.5)
		else:  # Day
			_sun_light.light_intensity = 1.0
			_sun_light.light_color = Color(1.0, 0.95, 0.8)


func _update_sun_position() -> void:
	if not _sun_light:
		return

	# Calculate sun angle based on time
	# 6 AM = sunrise (0 degrees), 6 PM = sunset (180 degrees)
	var hour = _game_hour
	var sun_angle: float

	if hour < 6.0 or hour > 18.0:
		# Night - sun below horizon
		sun_angle = -0.3
		_sun_light.visible = false
	else:
		# Day - sun arcs across sky
		var day_progress = (hour - 6.0) / 12.0  # 0 at 6 AM, 1 at 6 PM
		sun_angle = sin(day_progress * PI)  # Peaks at noon
		_sun_light.visible = true

		# Set sun rotation
		var rotation_x = (0.5 - day_progress) * PI  # -90 to 90 degrees
		_sun_light.rotation.x = rotation_x

	# Update shader sun angle
	if _sky_material:
		_sky_material.set_shader_parameter("sun_angle", sun_angle)


func _update_clouds() -> void:
	if not _sky_material:
		return

	# Update time in shader
	_sky_material.set_shader_parameter("time", _time)

	# Vary cloud density slightly over time
	var cloud_density = 0.4 + 0.2 * sin(_time * 0.01)
	_sky_material.set_shader_parameter("cloud_density", cloud_density)


## Get current game hour
func get_game_hour() -> float:
	return _game_hour


## Set time of day (0-24)
func set_time_of_day(hour: float) -> void:
	_game_hour = fmod(hour, 24.0)
	_time = (_game_hour - start_hour) / 24.0 * day_duration
	if _time < 0:
		_time += day_duration
	_update_sky_colors()
	_update_sun_position()


## Fast-forward time (for testing)
func fast_forward(seconds: float) -> void:
	_time += seconds


## Set weather preset
func set_weather(weather: String) -> void:
	match weather:
		"clear":
			_sky_material.set_shader_parameter("cloud_density", 0.2)
			_sky_material.set_shader_parameter("bird_count", 10)
		"cloudy":
			_sky_material.set_shader_parameter("cloud_density", 0.7)
			_sky_material.set_shader_parameter("bird_count", 3)
		"overcast":
			_sky_material.set_shader_parameter("cloud_density", 0.9)
			_sky_material.set_shader_parameter("bird_count", 0)
		_:
			push_warning("[SkyController] Unknown weather preset: %s" % weather)
