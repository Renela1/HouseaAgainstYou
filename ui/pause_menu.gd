class_name PauseMenu
extends CanvasLayer
## Pause overlay laid out like the start menu: full-screen shade, a "Game paused"
## heading where the logo sits, and the same burgundy button stack. The same
## overlay doubles as the victory screen through show_victory().
##
## Restart is a fresh run: it reloads the scene and tells the start menu to skip
## itself. Back to Main Menu reloads and lets the start menu come up instead.

signal paused_changed(is_paused: bool)
## Emitted just before a restart reload; useful for saving or custom resets.
signal restart_requested

## Set false in tests to check the reset without actually reloading.
@export var perform_reload: bool = true

var _is_open: bool = false

@onready var _shade: ColorRect = $Shade
@onready var _heading: Label = $Heading
@onready var _dropdown: VBoxContainer = $Dropdown
@onready var _pause_button: Button = $PauseButton
@onready var _back_button: Button = $Dropdown/BackButton
@onready var _resume_button: Button = $Dropdown/ResumeButton
@onready var _options_button: Button = $Dropdown/OptionsButton
@onready var _restart_button: Button = $Dropdown/RestartButton


func _ready() -> void:
	# CanvasLayers inherit by default; this one must keep processing while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_pause_button.pressed.connect(toggle_menu)
	_back_button.pressed.connect(_on_back)
	_resume_button.pressed.connect(resume)
	_options_button.pressed.connect(_on_options)
	_restart_button.pressed.connect(_on_restart)
	_show_menu(false)
	if get_tree().paused:
		_pause()


func _show_menu(value: bool) -> void:
	_shade.visible = value
	_heading.visible = value
	_dropdown.visible = value


func is_menu_open() -> bool:
	return _is_open


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
	_heading.text = "Game paused"
	_pause()


## Opens the same overlay as a victory screen, with the heading replaced.
func show_victory(message: String = "You won") -> void:
	_heading.text = message
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


## Placeholder until there is a real options screen.
func _on_options() -> void:
	_say("Options are not set up yet.")


## Restarts the run: same level, fresh clock, no start menu in between.
func _on_restart() -> void:
	_is_open = false
	get_tree().paused = false
	_show_menu(false)
	Inventory.clear()
	restart_requested.emit()
	# The flag is the intent; the reload is just how it is carried out.
	get_tree().root.set_meta("skip_start_menu", true)
	if perform_reload:
		get_tree().reload_current_scene()


## Leaves the run and goes back to the start screen.
func _on_back() -> void:
	_is_open = false
	get_tree().paused = false
	_show_menu(false)
	Inventory.clear()
	get_tree().root.set_meta("skip_start_menu", false)
	if perform_reload:
		get_tree().reload_current_scene()


func _say(text: String) -> void:
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)
