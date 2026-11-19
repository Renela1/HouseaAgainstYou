class_name InteractionRule
extends Resource
## One condition an InteractableObject checks before it lets you interact.
## Rules are authored as .tres files and listed on an InteractableData, so a new
## object's conditions never need code.
##
## Fields the current settings make meaningless are hidden in the Inspector; see
## _validate_property().

## Short label for this condition, e.g. "Rusty Key".
@export var label: String = ""

@export_group("Item requirement")
## Item id that must be carried (see ItemData.id). Empty means "no item check".
@export var requires_item: StringName = &""
## How many are needed.
@export_range(1, 99, 1) var requires_quantity: int = 1
## Remove the item from the bag when the rule passes (a key that breaks off).
@export var consume: bool = false

@export_group("Key / gadget requirement")
## Key id that must be carried (see ItemData.key_id, kind = KEY). Empty = none.
@export var requires_key: StringName = &""
## Gadget tag that must be carried (see ItemData.unlock_tag, kind = GADGET).
@export var requires_tag: StringName = &""

@export_group("Message")
## Shown when this rule fails. Falls back to label, then to a generated line.
@export var failure_text: String = ""


## Hides the fields the current settings do not use. Values are kept, so flipping
## a toggle back and forth never loses data.
func _validate_property(property: Dictionary) -> void:
	var hidden: bool = false
	match property.name:
		"requires_quantity":
			hidden = requires_item == &""
		"consume":
			hidden = requires_item == &""
	if hidden:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


## True when \`inventory\` satisfies this rule.
func is_met(inventory: PlayerInventory) -> bool:
	if inventory == null:
		return false
	if requires_item != &"" and not inventory.has_item(requires_item, requires_quantity):
		return false
	if requires_key != &"" and not inventory.has_key(requires_key):
		return false
	if requires_tag != &"" and not inventory.has_unlock_tag(requires_tag):
		return false
	return true


## What to tell the player when this rule is the one that fails.
func get_failure_text() -> String:
	if not failure_text.is_empty():
		return failure_text
	if not label.is_empty():
		return label
	if requires_item != &"":
		return "Needs %s ×%d" % [requires_item, requires_quantity]
	if requires_key != &"":
		return "Needs the %s key" % requires_key
	if requires_tag != &"":
		return "Needs a gadget"
	return "Locked"


## Takes whatever this rule demands from the bag. Called only after every rule
## in the set has passed.
func consume_from(inventory: PlayerInventory) -> void:
	if not consume or inventory == null:
		return
	if requires_item != &"":
		inventory.remove_item(requires_item, requires_quantity)
