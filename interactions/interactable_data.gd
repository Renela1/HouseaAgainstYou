class_name InteractableData
extends Resource
## The definition of one interactable object: how it looks, what must be true
## before it responds, and what changes when it does. Every InteractableObject
## points at one of these, so a new object is a new .tres file — never new code.
##
## Sections the current settings do not use are hidden in the Inspector; see
## _validate_property().

enum Kind {
	LEVER,     ## A switch the player flips.
	DOOR,      ## Lets the player through; usually needs a key.
	TERMINAL,  ## A panel or device with a readout.
	CONTAINER, ## Opened once; holds something.
}

enum Shape {
	RECT,   ## Rectangular body, sized by \`size\`.
	CIRCLE, ## Round body, diameter from \`size.x\`.
}

## Stable identifier used by saves and by checks. Treat as permanent.
@export var id: StringName = &""
## Shown in the HUD and in tooltips.
@export var name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.LEVER

@export_group("Conditions")
## Every rule must pass before the object responds.
@export var rules: Array[InteractionRule] = []
## When on, any single passing rule is enough (OR instead of AND).
@export var match_any: bool = false
## The object locks itself after one successful interaction.
@export var one_shot: bool = false
## Blocks movement like a wall. Doors (`kind == DOOR`) drop the block once they
## open; levers, terminals and containers stay solid after use.
@export var solid: bool = false
## Shown when the object is used but no rule failed (e.g. it is already spent).
@export var refusal_text: String = "Nothing happens."

@export_group("Success transformation")
## Body colour after a successful interaction.
@export var success_color: Color = Color(0.42, 0.82, 0.48)
## Body scale after a successful interaction — a cheap "shape change".
@export var success_scale: Vector2 = Vector2(1.0, 0.72)
## Body rotation after a successful interaction, in degrees. A door swings open
## with 90 (or -90 for the other way); 0 leaves it facing as authored.
@export_range(-360.0, 360.0, 1.0) var success_rotation_deg: float = 0.0
## Animate into the transformation instead of snapping to it.
@export var pulse: bool = true

@export_group("Look")
@export var shape: Shape = Shape.RECT
@export var color: Color = Color(0.45, 0.5, 0.62)
## Rect body size, or diameter for a circle.
@export var size: Vector2 = Vector2(56.0, 56.0)

@export_group("Sight")
## Draw a vision cone and track whether the player stands inside it.
@export var has_sight: bool = false
## Require the player to be inside the cone before the object responds.
@export var require_sight: bool = false
@export var sight_radius: float = 220.0
@export_range(1.0, 360.0, 1.0) var sight_angle_deg: float = 90.0
@export var sight_color: Color = Color(0.95, 0.85, 0.35, 0.16)


## Hides the sight fields when the object has no sight. Values are kept.
func _validate_property(property: Dictionary) -> void:
	match property.name:
		"require_sight", "sight_radius", "sight_angle_deg", "sight_color":
			if not has_sight:
				property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


## The rules that did not pass. Empty when the object may be used.
func failing_rules(inventory: PlayerInventory) -> Array[InteractionRule]:
	var failed: Array[InteractionRule] = []
	for rule in rules:
		if rule != null and not rule.is_met(inventory):
			failed.append(rule)
	return failed


## True when the inventory satisfies the rule set (all of them, or any one when
## \`match_any\` is on). No rules means "always usable".
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


## Consumes what the passing rules demand. Unmet rules are skipped, so OR mode
## never eats something the player did not need.
func consume_all(inventory: PlayerInventory) -> void:
	for rule in rules:
		if rule != null and rule.is_met(inventory):
			rule.consume_from(inventory)
