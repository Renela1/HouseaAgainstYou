class_name FinalDoor
extends InteractableObject
## The way out. It needs `required_item` (the golden key) and every hostile in
## the level shut down before the player may leave.
##
## A failed attempt wakes every hostile that is still IDLE (ACTIVE ones stay
## ACTIVE, DISABLED ones stay down) and ticks the patience meter. Once the meter
## is full, a failed attempt still lets the player force the door — then the
## house burns and the run restarts with the pickables back in place.
##
## The interactable base supplies reach tracking, hover, shape, click routing,
## the refusal flash and the HUD message channel; only the outcome logic is here.

## Emitted when the player gets out with every hostile disabled.
signal escaped
## Emitted when a forced exit starts the burn sequence.
signal burned_out

@export_group("Escape")
## Item id the player must carry to attempt the exit. Empty = no item needed.
@export var required_item: StringName = &"golden_key"
@export var need_key_text: String = "The final door needs the golden key."
@export var not_safe_text: String = "Not yet — they are still awake."
@export var escape_text: String = "You escaped."
@export var victory_text: String = "You won"
@export var force_text: String = "You force the door open."
@export var burned_text: String = "Your house was burnt."

@export_group("Burn")
## Seconds between forcing the door and the house going up.
@export var burn_delay: float = 1.0
## Seconds the burn message stays up before the run restarts.
@export var burn_hold: float = 2.0
## Restart the scene after the burn. Turn off when a run manager takes over.
@export var auto_restart: bool = true

## True while the forced-exit sequence runs; blocks further attempts.
var _resolving: bool = false


func interact(interactor: Node) -> bool:
	if data == null or _resolving or _used:
		return false
	if required_item != &"" and not Inventory.has_item(required_item, 1):
		_refuse(need_key_text)
		return false
	if _all_hostiles_disabled():
		_open()
		escaped.emit()
		activated.emit(interactor)
		_show_victory()
		return true
	# The house is not quiet yet: wake whatever is still asleep and count it.
	_wake_hostiles()
	var meter: PatienceMeter = get_tree().get_first_node_in_group("patience_meter") as PatienceMeter
	var out_of_patience: bool = meter != null and meter.add_failure()
	if not out_of_patience:
		_refuse(not_safe_text)
		return true
	_open()
	_say(force_text)
	_burn_sequence()
	return true


## True when every hostile in the level is shut down.
func _all_hostiles_disabled() -> bool:
	for node in get_tree().get_nodes_in_group("hostiles"):
		var hostile := node as HostileObject
		if hostile == null or hostile.state != HostileObject.State.DISABLED:
			return false
	return true


## IDLE hostiles wake immediately, ACTIVE stay ACTIVE, DISABLED stay down.
func _wake_hostiles() -> void:
	for node in get_tree().get_nodes_in_group("hostiles"):
		var hostile := node as HostileObject
		if hostile != null:
			hostile.activate()


## Swings the door open (and locks it into its success look).
func _open() -> void:
	_used = true
	_apply_success()


## Announces the win and opens the pause overlay with "You won" as its heading.
func _show_victory() -> void:
	_say(victory_text)
	var menu: PauseMenu = get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	if menu != null:
		menu.show_victory(victory_text)


## Leave anyway, then burn the house and reset the run.
func _burn_sequence() -> void:
	_resolving = true
	await get_tree().create_timer(burn_delay).timeout
	_say(burned_text)
	burned_out.emit()
	if not auto_restart:
		return
	await get_tree().create_timer(burn_hold).timeout
	Inventory.clear()
	get_tree().reload_current_scene()
