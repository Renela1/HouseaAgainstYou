class_name PlayerInventory
extends Node
## The player's bag. It knows slots and stack rules, never specific items: any
## ItemData can be added, so new pickups need no inventory changes.
##
## Autoloaded as `Inventory`. The class is named PlayerInventory on purpose —
## an autoload may not share its name with a global class.

signal inventory_changed
signal item_added(item: ItemData, quantity: int)
signal item_removed(item: ItemData, quantity: int)

## Slots created once at startup.
@export var slot_count: int = 12

## Runtime slot state. Not a Resource: slots are live state, never authored assets.
var slots: Array[InventorySlot] = []


func _ready() -> void:
	for i in slot_count:
		slots.append(InventorySlot.new())


## Adds up to `quantity`. Returns what did NOT fit (0 = everything added), so a
## caller can tell "full bag" from "picked up" without re-querying.
func add_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return quantity
	var remaining: int = quantity
	var cap: int = item.get_stack_cap()
	# Pass 1: top up existing stacks first, so one item type isn't spread out.
	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty() or slot.item.id != item.id:
			continue
		var moved: int = mini(cap - slot.quantity, remaining)
		if moved <= 0:
			continue
		slot.quantity += moved
		remaining -= moved
	# Pass 2: open fresh slots with whatever is left.
	for slot in slots:
		if remaining <= 0:
			break
		if not slot.is_empty():
			continue
		var moved: int = mini(cap, remaining)
		slot.item = item
		slot.quantity = moved
		remaining -= moved
	var added: int = quantity - remaining
	if added > 0:
		item_added.emit(item, added)
		inventory_changed.emit()
	return remaining


## Removes up to `quantity` of an item id. Returns how many were actually removed.
func remove_item(id: StringName, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	var remaining: int = quantity
	var first_item: ItemData = null
	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty() or slot.item.id != id:
			continue
		if first_item == null:
			first_item = slot.item
		var moved: int = mini(slot.quantity, remaining)
		slot.quantity -= moved
		remaining -= moved
		if slot.quantity <= 0:
			slot.clear()
	var removed: int = quantity - remaining
	if removed > 0:
		item_removed.emit(first_item, removed)
		inventory_changed.emit()
	return removed


## Total of one item id across every slot.
func count_of(id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.item.id == id:
			total += slot.quantity
	return total


func has_item(id: StringName, quantity: int = 1) -> bool:
	return count_of(id) >= quantity


## True when the bag holds a KEY whose key_id matches — for doors later.
func has_key(key_id: StringName) -> bool:
	if key_id == &"":
		return false
	for slot in slots:
		if slot.is_empty():
			continue
		if slot.item.kind == ItemData.Kind.KEY and slot.item.key_id == key_id:
			return true
	return false


## True when any carried item carries this unlock_tag (KEY/GADGET) — for doors later.
func has_unlock_tag(tag: StringName) -> bool:
	if tag == &"":
		return false
	for slot in slots:
		if slot.is_empty():
			continue
		if slot.item.unlock_tag == tag:
			return true
	return false


## Non-empty slots as [{item: ItemData, quantity: int}] — for UI and saving.
func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot in slots:
		if not slot.is_empty():
			entries.append({"item": slot.item, "quantity": slot.quantity})
	return entries


func clear() -> void:
	for slot in slots:
		slot.clear()
	inventory_changed.emit()
