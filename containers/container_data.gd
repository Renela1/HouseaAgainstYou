class_name ContainerData
extends Resource
## The definition of one container: conditions, contents, look and solidity.
## Every ContainerObject points at one of these, so a new container is a new
## .tres file — never new code. Conditions use the same InteractionRule
## resources as interactables and support the same "requires key" fields.
##
## State is NOT stored here: this resource is shared between instances.
## `is_open` / `is_full` live on ContainerObject.

enum Shape {
	RECT,   ## Rectangular body, sized by `size`.
	CIRCLE, ## Round body, diameter from `size.x`.
}

## Stable identifier used by saves and checks. Treat as permanent.
@export var id: StringName = &""
## Shown in HUD messages, e.g. "Opened the cabinet."
@export var name: String = "container"
@export_multiline var description: String = ""
@export var shape: Shape = Shape.RECT
## Click/overlap area and physical blocker both use this size.
@export var size: Vector2 = Vector2(56.0, 48.0)

@export_group("Conditions")
## Every rule must pass before the container responds.
@export var rules: Array[InteractionRule] = []
## When on, any single passing rule is enough (OR instead of AND).
@export var match_any: bool = false
## Shown when a condition fails (a missing key, for example).
@export var refusal_text: String = "It's locked."
## Shown when the bag cannot hold all the contents yet.
@export var full_bag_text: String = "Your bag is full."

@export_group("Contents")
## Every item type inside and its amount. Empty contents means it starts EMPTY.
@export var contents: Array[ContainerEntry] = []
## Overrides the generated "Found: ..." line shown when it is emptied.
@export var loot_message: String = ""
## Shown when it opens; overridden by loot_message on the emptying click.
@export var open_message: String = ""
## Shown when it closes.
@export var close_message: String = ""

@export_group("Look")
## Placeholder body colour while closed (used when no `frames` are assigned).
@export var closed_color: Color = Color(0.52, 0.34, 0.2)
## Placeholder body colour while open.
@export var open_color: Color = Color(0.3, 0.2, 0.14)

@export_group("Physics")
## Blocks movement like a wall in both states, like a fixture.
@export var solid: bool = true

@export_group("State sprites")
## Optional animation set with one animation per state. When assigned, the
## placeholder shape above is not drawn.
@export var frames: SpriteFrames
@export var closed_animation: StringName = &"closed"
@export var open_animation: StringName = &"open"


## Hides the fields the current settings do not use. Values are kept.
func _validate_property(property: Dictionary) -> void:
	if property.name == "closed_animation" or property.name == "open_animation":
		if frames == null:
			property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


## The rules that did not pass. Empty when the container may be used.
func failing_rules(inventory: PlayerInventory) -> Array[InteractionRule]:
	var failed: Array[InteractionRule] = []
	for rule in rules:
		if rule != null and not rule.is_met(inventory):
			failed.append(rule)
	return failed


## True when the inventory satisfies the rule set (all, or any one in OR mode).
func conditions_met(inventory: PlayerInventory) -> bool:
	if rules.is_empty():
		return true
	var failed: Array[InteractionRule] = failing_rules(inventory)
	if match_any:
		return failed.size() < rules.size()
	return failed.is_empty()


## What to tell the player when conditions_met() is false.
func failure_message(inventory: PlayerInventory) -> String:
	var failed: Array[InteractionRule] = failing_rules(inventory)
	if failed.is_empty():
		return refusal_text
	return failed[0].get_failure_text()


## Consumes what the passing rules demand. Called only after every rule passes.
func consume_all(inventory: PlayerInventory) -> void:
	for rule in rules:
		if rule != null and rule.is_met(inventory):
			rule.consume_from(inventory)


## Valid contents as {item: ItemData, quantity: int} for the inventory API.
func contents_as_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in contents:
		if entry == null or entry.item == null or entry.quantity <= 0:
			continue
		result.append({"item": entry.item, "quantity": entry.quantity})
	return result


## Comma-separated "Item ×n" list for the default loot message.
func contents_label() -> String:
	var parts: Array[String] = []
	for entry in contents:
		if entry == null:
			continue
		var label: String = entry.get_label()
		if not label.is_empty():
			parts.append(label)
	return ", ".join(parts)
