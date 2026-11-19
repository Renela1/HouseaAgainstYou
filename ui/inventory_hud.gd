extends CanvasLayer
## Inventory readout plus a short-lived interaction message. The message half is
## reached by interactables through the "interact_feedback" group, so they never
## hard-wire a HUD path.

@onready var _inventory_label: Label = $Panel/Label
@onready var _message: PanelContainer = $Message
@onready var _message_label: Label = $Message/Label

var _message_time: float = 0.0


func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	add_to_group("interact_feedback")
	_message.visible = false
	_refresh()


func _process(delta: float) -> void:
	if _message_time <= 0.0:
		return
	_message_time -= delta
	if _message_time <= 0.0:
		_message.visible = false


## Called by interactables when they refuse, and by anything else that wants to
## say a line. Any node in the "interact_feedback" group with this method works.
func show_message(text: String) -> void:
	if text.is_empty():
		return
	_message_label.text = text
	_message.visible = true
	_message_time = 2.5


func _refresh() -> void:
	var lines := PackedStringArray()
	for entry in Inventory.get_entries():
		var data: ItemData = entry["item"]
		lines.append("%s ×%d" % [data.name, entry["quantity"]])
	if lines.is_empty():
		_inventory_label.text = "Inventory: empty"
		return
	_inventory_label.text = "Inventory\n" + "\n".join(lines)
