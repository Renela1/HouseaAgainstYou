class_name InventorySlot
extends RefCounted
## One bag slot: an item definition plus how many are held. Runtime state only —
## deliberately RefCounted, because slots are never authored or saved as assets.

var item: ItemData = null
var quantity: int = 0


func _init(p_item: ItemData = null, p_quantity: int = 0) -> void:
	item = p_item
	quantity = p_quantity


func is_empty() -> bool:
	return item == null or quantity <= 0


func clear() -> void:
	item = null
	quantity = 0


## How many more of `item` this slot could take.
func space_left() -> int:
	if is_empty():
		return 0
	return maxi(item.get_stack_cap() - quantity, 0)
