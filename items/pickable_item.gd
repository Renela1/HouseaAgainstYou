class_name PickableItem
extends Area2D
## Anything the player can pick up. *What* it is lives in the `item` ItemData;
## this class only handles presence, look and the transfer, so every new pickup
## is a new .tres plus an instance of this scene.

signal picked_up(item: ItemData, quantity: int)
## Emitted when a pickup is refused, e.g. the bag is full.
signal pickup_refused(item: ItemData)

## Definition of this pickup. Shared resource — never mutated at runtime.
@export var item: ItemData
## How many are lying here.
@export_range(1, 999, 1) var quantity: int = 1

var _in_reach: bool = false
var _hovered: bool = false


func _ready() -> void:
	add_to_group("pickables")
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if item == null:
		push_warning("PickableItem '%s' has no ItemData assigned." % name)
		return
	_resize_shape()
	queue_redraw()


## Called by InteractZone when this pickup enters or leaves the player's reach.
func set_in_reach(value: bool) -> void:
	_in_reach = value
	queue_redraw()


## The contract InteractZone looks for. Returns true when something was taken.
func interact(_interactor: Node) -> bool:
	if item == null:
		return false
	var leftover: int = Inventory.add_item(item, quantity)
	var taken: int = quantity - leftover
	if taken <= 0:
		pickup_refused.emit(item)
		return false
	quantity = leftover
	picked_up.emit(item, taken)
	if quantity <= 0:
		queue_free()
	return true


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var zone: InteractZone = get_tree().get_first_node_in_group("interact_zone") as InteractZone
	if zone != null:
		zone.request_interact(self)


func _resize_shape() -> void:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null:
			continue
		var circle := CircleShape2D.new()
		circle.radius = item.radius + 6.0
		shape_node.shape = circle


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	if item == null:
		return
	draw_circle(Vector2.ZERO, item.radius, item.color)
	var ring_alpha: float = 0.0
	if _hovered:
		ring_alpha = 0.9
	elif _in_reach:
		ring_alpha = 0.45
	if ring_alpha > 0.0:
		draw_arc(Vector2.ZERO, item.radius + 4.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, ring_alpha), 2.0)
