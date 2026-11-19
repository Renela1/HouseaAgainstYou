class_name ContainerEntry
extends Resource
## One item type a ContainerData holds, and how many of it are inside.
## Several entries can list the same item; they are stacked by the inventory.
## Authored as an inline resource in a container .tres, so the contents are
## edited entirely in the Inspector — no code needed for a new container.

## Which item definition this entry holds.
@export var item: ItemData
## How many of it are in the container (1-999).
@export_range(1, 999, 1) var quantity: int = 1


func _validate_property(property: Dictionary) -> void:
	if property.name == "quantity" and item == null:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


## Readable label for HUD feedback, e.g. "Coin ×3".
func get_label() -> String:
	if item == null:
		return ""
	var shown: String = item.name if not item.name.is_empty() else String(item.id)
	return "%s ×%d" % [shown, quantity]
