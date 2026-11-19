class_name GameTimer
extends Node
## The run clock. `total_seconds` is split into four equal stages; crossing into
## a stage emits stage_started, which the countdown HUD turns into a colour.
## At zero the run ends: the last line goes up, the game unpauses, the inventory
## is cleared and the scene reloads, which rebuilds every node and hands out a
## fresh clock.
##
## Reach it from anywhere with
##   get_tree().get_first_node_in_group("game_timer")
## It lives in the level rather than in an autoload, so a restart resets it for
## free. It pauses with the game (process_mode INHERIT), so the start menu and
## the pause menu both stop the countdown.

signal stage_started(stage: int, stages: int, seconds_left: float)
signal time_changed(seconds_left: float)
## Emitted once when the clock reaches zero, before the restart delay.
signal expired

## The run is always divided into this many equal stages.
const STAGES: int = 4

## Length of the whole run in seconds. Stages are always a quarter of it, so 60
## gives four 15 second stages.
@export var total_seconds: float = 60.0
## Line shown when the clock runs out.
@export var expired_message: String = "Time's up."
## Seconds that line stays up before the scene reloads.
@export var restart_delay: float = 1.5

var _left: float = 0.0
var _stage_length: float = 0.0
var _stage: int = 0
var _running: bool = false


func _ready() -> void:
	add_to_group("game_timer")
	restart_clock()


func _process(delta: float) -> void:
	if not _running:
		return
	_left = maxf(_left - delta, 0.0)
	time_changed.emit(_left)
	_sync_stage()
	if _left <= 0.0:
		_end_run()


## Seconds left in the run, 0 once it is over.
func seconds_left() -> float:
	return _left


## Length of one stage in seconds: total_seconds divided by STAGES.
func stage_seconds() -> float:
	return _stage_length


## Current stage, 1..STAGES, or 0 while the clock is off.
func current_stage() -> int:
	return _stage


func is_running() -> bool:
	return _running


## Restarts the clock from total_seconds. Called on load and by any re-run.
func restart_clock() -> void:
	_left = maxf(total_seconds, 0.0)
	_stage_length = _left / float(STAGES)
	_stage = 0
	_running = _left > 0.0
	time_changed.emit(_left)
	if not _running:
		push_warning("GameTimer: total_seconds must be above 0; the clock is off.")
		return
	_sync_stage()


## Advances the stage marker and announces it. Safe to call every frame.
func _sync_stage() -> void:
	var stage: int = _stage_for(_left)
	if stage == _stage:
		return
	_stage = stage
	stage_started.emit(stage, STAGES, _left)


## 1-based stage that the remaining seconds belong to: the last quarter is
## stage 4, and exactly 0 still counts as the last one.
func _stage_for(seconds_left: float) -> int:
	if _stage_length <= 0.0:
		return STAGES
	var elapsed: float = maxf(total_seconds, 0.0) - seconds_left
	return clampi(int(elapsed / _stage_length) + 1, 1, STAGES)


## Clock hit zero: announce it, then restart the run the way the pause menu does.
func _end_run() -> void:
	if not _running:
		return
	_running = false
	expired.emit()
	_say(expired_message)
	if restart_delay > 0.0:
		await get_tree().create_timer(restart_delay).timeout
	get_tree().paused = false
	Inventory.clear()
	get_tree().reload_current_scene()


## Talks to whatever advertises itself in the "interact_feedback" group.
func _say(text: String) -> void:
	if text.is_empty():
		return
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)
