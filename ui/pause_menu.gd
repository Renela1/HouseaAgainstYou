class_name PauseMenu
extends CanvasLayer
## Top-left pause button plus a drop-down menu. Runs while the tree is paused,
## freezes the game on open, and restores every state on Restart by reloading
## the scene after clearing the inventory.

signal paused_changed(is_paused: bool)
## Emitted just before the scene reload; useful for saving or custom resets.
signal restart_requested

## Set false in tests to check the reset without actually reloading.
@export var perform_reload: bool = true

var _is_open: bool = false

@onready var _shade: ColorRect = $Shade
@onready var _dropdown: VBoxContainer = $Dropdown
@onready var _pause_button: Button = $PauseButton
@onready var _back_button: Button = $Dropdown/BackButton
@onready var _resume_button: Button = $Dropdown/ResumeButton
@onready var _options_button: Button = $Dropdown/OptionsButton
@onready var _restart_button: Button = $Dropdown/RestartButton


func _ready() -> void:
	# CanvasLayers inherit by default; this one must keep processing while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_button.pressed.connect(toggle_menu)
	_back_button.pressed.connect(_on_back)
	_resume_button.pressed.connect(resume)
	_options_button.pressed.connect(_on_options)
	_restart_button.pressed.connect(_on_restart)
	_show_menu(false)
	if get_tree().paused:
		_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_P:
		toggle_menu()
		get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if _is_open:
		resume()
	else:
		pause()


func pause() -> void:
	if _is_open:
		return
	_pause()


func resume() -> void:
	if not _is_open:
		return
	_is_open = false
	get_tree().paused = false
	_show_menu(false)
	paused_changed.emit(false)


func _pause() -> void:
	_is_open = true
	get_tree().paused = true
	_show_menu(true)
	paused_changed.emit(true)


func _show_menu(value: bool) -> void:
	_shade.visible = value
	_dropdown.visible = value


func is_menu_open() -> bool:
	return _is_open


## Main menu is a placeholder for now, so it only acknowledges the click.
func _on_back() -> void:
	_say("Main menu is not set up yet.")


## Options is a placeholder for now, so it only acknowledges the click.
func _on_options() -> void:
	_say("Options are not set up yet.")


func _on_restart() -> void:
	get_tree().paused = false
	_is_open = false
	_show_menu(false)
	Inventory.clear()
	restart_requested.emit()
	if perform_reload:
		get_tree().reload_current_scene()


func _say(text: String) -> void:
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)
