## WizardStep
## Base class for wizard steps.
extends Control
class_name WizardStep

## Emitted when step is completed (for validation)
signal step_completed(is_valid: bool)

## Emitted when user wants to go back
signal go_back()

## Emitted when user wants to go next
signal go_next()

## The step index (0-based)
var step_index: int = 0

## Step title
var title: String = "Step"

## Step description
var description: String = ""


## Validate the step data
func validate() -> bool:
	return true


## Get the step data
func get_data() -> Dictionary:
	return {}


## Set the step data (for editing existing agent)
func set_data(data: Dictionary) -> void:
	pass


## Called when step becomes active
func on_enter() -> void:
	pass


## Called when step becomes inactive
func on_exit() -> void:
	pass
