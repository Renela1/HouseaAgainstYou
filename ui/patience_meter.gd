class_name PatienceMeter
extends ProgressBar
## How much the house will put up with. FinalDoor adds one failure per botched
## leave attempt; when the bar fills, a failed attempt still lets the player out
## — and the house burns.

signal filled

## Failed attempts needed to fill the meter.
@export_range(1, 20, 1) var max_failures: int = 4


func _ready() -> void:
	add_to_group("patience_meter")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_percentage = false
	step = 1.0
	max_value = float(max_failures)
	value = 0.0


## Adds one failure. Returns true when the meter just filled.
func add_failure() -> bool:
	value = minf(value + 1.0, max_value)
	if value < max_value:
		return false
	filled.emit()
	return true


func reset() -> void:
	value = 0.0


## Failed attempts so far, as an int.
func failures() -> int:
	return int(value)
