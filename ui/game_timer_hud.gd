extends CanvasLayer
## Countdown readout for the GameTimer: minutes:seconds, recoloured when the
## timer crosses into a new stage (green -> white -> yellow -> red).
##
## Placeholder look on purpose: `Time` is a plain Label. Restyle it, or replace
## the Label with a sprite/atlas later and keep the two handlers below.

## One colour per stage, in order. Extra or missing entries are tolerated.
@export var stage_colors: PackedColorArray = PackedColorArray([
	Color(0.42, 0.85, 0.45, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.98, 0.83, 0.25, 1.0),
	Color(0.95, 0.32, 0.3, 1.0),
])

@onready var _label: Label = $Time

## Typed loosely so this works even before the GameTimer class is registered.
var _timer: Node = null


func _ready() -> void:
	# The clock may be created after this node, so bind on the next idle.
	_bind.call_deferred()


func _bind() -> void:
	_timer = get_tree().get_first_node_in_group("game_timer")
	if _timer == null:
		return
	_timer.time_changed.connect(_on_time_changed)
	_timer.stage_started.connect(_on_stage_started)
	_show_time(float(_timer.call("seconds_left")))
	_apply_color(int(_timer.call("current_stage")))


func _on_time_changed(seconds_left: float) -> void:
	_show_time(seconds_left)


func _on_stage_started(stage: int, _stages: int, _seconds_left: float) -> void:
	_apply_color(stage)


## Whole seconds, rounded up so the first frame already reads the full duration
## and 0 only appears once the run is over.
func _show_time(seconds_left: float) -> void:
	var total: int = int(ceil(maxf(seconds_left, 0.0)))
	_label.text = "%d:%02d" % [total / 60, total % 60]


func _apply_color(stage: int) -> void:
	if stage_colors.is_empty():
		return
	var index: int = clampi(stage - 1, 0, stage_colors.size() - 1)
	_label.add_theme_color_override("font_color", stage_colors[index])
