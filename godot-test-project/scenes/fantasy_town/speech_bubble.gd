## speech_bubble.gd - 3D Speech Bubble for Agent Communication
## Part of Fantasy Town World-Breaking Demo
##
## Uses Label3D with billboard mode for 3D speech bubbles.
## Features:
## - Typewriter text animation
## - Color coding by mood
## - Fade in/out transitions
## - Auto-hide after duration
## - SHRUNK SIZE for better visibility

class_name SpeechBubble
extends Node3D

## Configuration
@export var display_duration: float = 3.0
@export var typewriter_speed: float = 0.03
@export var fade_duration: float = 0.2

## Components
@onready var label: Label3D = $Label3D
@onready var background: MeshInstance3D = $Background
var _border: MeshInstance3D = null
var _border_mat: StandardMaterial3D = null

## State
var _full_text: String = ""
var _displayed_text: String = ""
var _char_index: int = 0
var _typewriter_timer: float = 0.0
var _display_timer: float = 0.0
var _is_showing: bool = false
var _fade_alpha: float = 0.0
var _is_fading_in: bool = false
var _is_fading_out: bool = false

## Cached colors
var _label_color: Color = Color.WHITE
var _bg_color: Color = Color(0.1, 0.1, 0.15, 0.8)

## Colors by mood
const MOOD_COLORS := {
	"happy": Color(1.0, 0.95, 0.6),
	"excited": Color(1.0, 0.8, 0.5),
	"curious": Color(0.7, 0.9, 1.0),
	"sad": Color(0.6, 0.7, 0.9),
	"tired": Color(0.8, 0.8, 0.8),
	"thoughtful": Color(0.85, 0.8, 0.95),
	"chat": Color(0.6, 1.0, 0.8),
	"friendly": Color(0.8, 0.95, 0.8)
}


func _ready() -> void:
	# Configure Label3D - 2x bigger for better readability
	if label:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.double_sided = true
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0006  # 2x bigger than before (was 0.0003)
		_label_color = label.modulate
		_label_color.a = 0.0
		label.modulate = _label_color

	if background:
		_setup_background()


func _setup_background() -> void:
	if not background.mesh:
		background.mesh = QuadMesh.new()
		background.mesh.orientation = PlaneMesh.FACE_Y

	# Create material with border effect using gradient
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = _bg_color
	mat.albedo_color.a = 0.0
	background.material_override = mat
	background.mesh.size = Vector2(0.08, 0.03)  # 2x bigger to match text

	# Create border mesh (slightly larger, behind main background)
	var border = MeshInstance3D.new()
	border.name = "Border"
	var border_mesh = QuadMesh.new()
	border_mesh.orientation = PlaneMesh.FACE_Y
	border.mesh = border_mesh

	var border_mat = StandardMaterial3D.new()
	border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_mat.no_depth_test = true
	border_mat.albedo_color = Color(0.6, 0.55, 0.4, 0.9)  # Golden border color
	border_mat.albedo_color.a = 0.0
	border.material_override = border_mat
	border.mesh.size = Vector2(0.085, 0.035)  # Slightly larger than background

	# Position border slightly behind background
	border.position = Vector3(0, 0, 0.001)
	add_child(border)
	_border = border
	_border_mat = border_mat


func _process(delta: float) -> void:
	if not _is_showing:
		return

	if _is_fading_in:
		_fade_alpha = min(1.0, _fade_alpha + delta / fade_duration)
		_update_alpha(_fade_alpha)
		if _fade_alpha >= 1.0:
			_is_fading_in = false

	if _is_fading_out:
		_fade_alpha = max(0.0, _fade_alpha - delta / fade_duration)
		_update_alpha(_fade_alpha)
		if _fade_alpha <= 0.0:
			_is_fading_out = false
			_is_showing = false
			hide()
		return

	# Typewriter effect
	if _char_index < _full_text.length():
		_typewriter_timer += delta
		if _typewriter_timer >= typewriter_speed:
			_typewriter_timer = 0.0
			_char_index += 1
			_displayed_text = _full_text.substr(0, _char_index)
			if label:
				label.text = _displayed_text
			_update_background_size()
	else:
		_display_timer += delta
		if _display_timer >= display_duration:
			hide_text()


func show_text(text: String, mood_color: Color = Color.WHITE) -> void:
	_full_text = text
	_displayed_text = ""
	_char_index = 0
	_typewriter_timer = 0.0
	_display_timer = 0.0
	_is_showing = true
	_is_fading_in = true
	_is_fading_out = false
	_fade_alpha = 0.0

	if label:
		label.text = ""
		_label_color = Color(mood_color.r, mood_color.g, mood_color.b, 0.0)
		label.modulate = _label_color

		# Smaller font for shrunk bubbles
		if text.length() > 60:
			label.font_size = 10
		elif text.length() > 30:
			label.font_size = 12
		else:
			label.font_size = 14

	show()


func show_text_with_mood(text: String, mood: String) -> void:
	var color = MOOD_COLORS.get(mood.to_lower(), Color.WHITE)
	show_text(text, color)


func hide_text() -> void:
	if _is_showing and not _is_fading_out:
		_is_fading_out = true


func hide_immediate() -> void:
	_is_showing = false
	_is_fading_in = false
	_is_fading_out = false
	_fade_alpha = 0.0
	_update_alpha(0.0)
	hide()


func is_showing() -> bool:
	return _is_showing


func _update_alpha(alpha: float) -> void:
	if label:
		_label_color.a = alpha
		label.modulate = _label_color

	if background and background.material_override:
		var mat = background.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha * 0.85

	# Update border alpha
	if _border_mat:
		_border_mat.albedo_color.a = alpha * 0.95


func _update_background_size() -> void:
	if not background or not label:
		return

	# Very small sizing for tiny bubbles (20x smaller)
	var char_width = 0.00125  # 20x smaller
	var padding = 0.005
	var border_padding = 0.003  # Extra padding for border

	var text_width = _displayed_text.length() * char_width
	text_width = clamp(text_width, 0.02, 0.075)

	# Update background size
	background.mesh.size = Vector2(text_width + padding, 0.0125)

	# Update border size (slightly larger than background)
	if _border and _border.mesh:
		_border.mesh.size = Vector2(text_width + padding + border_padding * 2, 0.0125 + border_padding * 2)


func position_above_agent(agent_height: float = 1.0) -> void:
	position = Vector3(0, agent_height + 0.025, 0)  # Closer to agent
