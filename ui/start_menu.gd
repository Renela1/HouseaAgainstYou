extends CanvasLayer
## The first screen. Holds the tree paused while it is up, so the clock, the
## hostiles and the player all wait for Play. A restart from the pause menu asks
## it to stay hidden, so that run starts straight away.
##
## The logo is the `Art` TextureRect: an AtlasTexture cropped from the UI sheet
## at res://art/ui/home_against_you_ui.png. The buttons are ThreeStateButton
## nodes sharing ui/definitions/burgundy_button.tres, so normal / hover / pressed
## come from the burgundy three-state atlas.

signal game_started

@onready var _play: Button = $Buttons/PlayButton
@onready var _options: Button = $Buttons/OptionsButton
@onready var _quit: Button = $Buttons/QuitButton

var _open: bool = false


func _ready() -> void:
	# Runs while the tree is paused, since that is exactly how it starts.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play.pressed.connect(start_game)
	_options.pressed.connect(_on_options)
	_quit.pressed.connect(_on_quit)
	if _consume_restart_request():
		return
	open()


## True when the previous scene asked to restart straight into the game (the
## pause menu's Restart), in which case this screen steps out of the way.
func _consume_restart_request() -> bool:
	var root_window: Window = get_tree().root
	if not bool(root_window.get_meta("skip_start_menu", false)):
		return false
	root_window.set_meta("skip_start_menu", false)
	_open = true
	start_game()
	return true


## Shows the menu and freezes the run.
func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true


## Hides the menu, unfreezes the run and starts the clock's countdown.
func start_game() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	game_started.emit()


func is_open() -> bool:
	return _open


## Placeholder until there is a real options screen.
func _on_options() -> void:
	_say("Options are not set up yet.")


func _on_quit() -> void:
	get_tree().quit()


func _say(text: String) -> void:
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)
