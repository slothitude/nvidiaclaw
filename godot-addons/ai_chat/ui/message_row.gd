## Message Row
## A single message row in the chat display.
extends HBoxContainer

# UI Elements
@onready var role_label: Label = $RoleLabel
@onready var content_label: RichTextLabel = $ContentLabel
@onready var timestamp_label: Label = $TimestampLabel


func setup(p_role: String, p_content: String, p_timestamp: String = "") -> void:
	if role_label:
		role_label.text = p_role.to_upper()
		_apply_role_style(p_role)

	if content_label:
		content_label.text = p_content

	if timestamp_label:
		timestamp_label.text = p_timestamp


func _apply_role_style(role: String) -> void:
	match role.to_lower():
		"user":
			role_label.add_theme_color_override("font_color", Color.CYAN)
		"assistant":
			role_label.add_theme_color_override("font_color", Color.GREEN)
		"error":
			role_label.add_theme_color_override("font_color", Color.RED)
		"system":
			role_label.add_theme_color_override("font_color", Color.YELLOW)
		_:
			role_label.add_theme_color_override("font_color", Color.WHITE)
