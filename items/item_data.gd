class_name ItemData
extends Resource
## One kind of thing the player can carry: a coin, a key, a gadget. Every
## PickableItem points at one of these, so new variety is a new .tres file —
## never new code.
##
## Kind-specific fields are hidden in the Inspector unless the chosen `kind`
## uses them; see _validate_property().

enum Kind {
	RESOURCE,   ## Plain material or currency (coins, scrap).
	KEY,        ## Opens a lock; carries `key_id`.
	TOOL,       ## Reusable and wears out; carries `durability`.
	GADGET,     ## Interactive device; carries `unlock_tag`.
	CONSUMABLE, ## Spent on use.
}

## Stable identifier used by saves and by checks (doors, quests). Treat as permanent.
@export var id: StringName = &""
## Shown in the HUD and in tooltips.
@export var name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.RESOURCE

@export_group("Stacking")
@export var stackable: bool = true
## Cap per slot; ignored when `stackable` is off (a unique item always holds 1).
@export_range(1, 999, 1) var max_stack_size: int = 99

@export_group("Kind-specific")
## Which lock this KEY opens.
@export var key_id: StringName = &""
## Tag a door or terminal can query with Inventory.has_unlock_tag().
@export var unlock_tag: StringName = &""
## Uses before a TOOL breaks; 0 = unlimited.
@export_range(0, 999, 1) var durability: int = 0

@export_group("Look")
## Placeholder art: the pickup is drawn as a circle of this colour.
@export var color: Color = Color(0.95, 0.78, 0.25)
@export_range(4.0, 32.0, 1.0) var radius: float = 10.0


## Hides the fields the current `kind` does not use. Values are kept, so
## switching kind back and forth never loses data.
func _validate_property(property: Dictionary) -> void:
	var hidden: bool = false
	match property.name:
		"max_stack_size":
			hidden = not stackable
		"key_id":
			hidden = kind != Kind.KEY
		"unlock_tag":
			hidden = kind != Kind.KEY and kind != Kind.GADGET
		"durability":
			hidden = kind != Kind.TOOL
	if hidden:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


## Per-slot cap. Keeps special cases out of the inventory: a unique item simply
## reports a cap of 1.
func get_stack_cap() -> int:
	return max_stack_size if stackable else 1
