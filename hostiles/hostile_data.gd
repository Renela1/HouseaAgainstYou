class_name HostileData
extends Resource
## One kind of hostile: a guard, a turret, a refrigerator with an attitude. Every
## HostileObject points at one of these, so a new hostile is a new .tres file —
## never new code.
##
## Every state can have its own colour, size and animation. Fields that do not
## apply are hidden in the Inspector; see _validate_property().

enum Shape {
	RECT,   ## Rectangular body, sized by `size`.
	CIRCLE, ## Round body, diameter from `size.x`.
}

## Stable identifier used by saves and by checks. Treat as permanent.
@export var id: StringName = &""
## Shown in the HUD and in tooltips.
@export var name: String = ""
@export_multiline var description: String = ""
@export var shape: Shape = Shape.RECT

@export_group("Look")
## Body size while IDLE.
@export var size: Vector2 = Vector2(64.0, 64.0)
@export var idle_color: Color = Color(0.9, 0.9, 0.92)
@export var active_color: Color = Color(0.96, 0.6, 0.35)
## Body colour while it is hiding from the player's gaze (ACTIVE + watched).
@export var hide_color: Color = Color(0.62, 0.66, 0.75, 0.42)
@export var disabled_color: Color = Color(0.45, 0.47, 0.5)
## Body size multiplier while ACTIVE, e.g. (1.7, 1) for a door swinging open.
@export var active_scale: Vector2 = Vector2.ONE

@export_group("Physics")
## Blocks movement like a wall. The collision follows `size`, never
## `active_scale`, so an opening body cannot shove the player. A DISABLED
## hostile stays exactly where it is and stays solid.
@export var solid: bool = true

@export_group("State sprites")
## Optional animation set holding one animation per state (names below). When
## assigned, the placeholder shape is not drawn.
@export var frames: SpriteFrames
## Multiplier applied to the sprite art only, so the drawing can be fitted to the
## room without moving the body: `size` above keeps driving collision.
@export var sprite_scale: Vector2 = Vector2.ONE
@export var idle_animation: StringName = &"idle"
@export var active_animation: StringName = &"active"
@export var hide_animation: StringName = &"hide"
@export var disabled_animation: StringName = &"disabled"

@export_group("Sight")
@export var sight_radius: float = 260.0
## Where the cone points, in degrees, independent of the node's rotation and of
## the sprite: 0 = right, 90 = down, 180 = left, 270 = up. Wraps past 360.
@export_range(0.0, 360.0, 1.0) var sight_direction_deg: float = 0.0
@export_range(1.0, 360.0, 1.0) var sight_angle_deg: float = 80.0
@export var sight_color: Color = Color(0.95, 0.35, 0.3, 0.16)

@export_group("States")
## Seconds the sight cone stays dimmed after an interaction. Sight itself stays
## active: being watched puts the hostile into HIDE, which is what protects the
## player.
@export_range(0.0, 30.0, 0.1) var grace_seconds: float = 2.5

@export_group("Timers")
## Seconds the player spends fitting the disable gadget before this hostile
## actually goes DISABLED. 0 = instant. The gadget is spent when the fix starts.
@export_range(0.0, 30.0, 0.1) var fix_seconds: float = 3.0
## Seconds until it wakes on its own while IDLE. The countdown starts when the
## game starts and restarts every time the player calms it. 0 = it only ever
## wakes when it sees the player.
@export_range(0.0, 120.0, 0.1) var wake_seconds: float = 5.0
## Seconds a DISABLED hostile stays down before it comes back online (usually
## longer than `wake_seconds`, so shutting it down really buys time).
## 0 = it stays disabled for good.
@export_range(0.0, 300.0, 0.1) var disable_seconds: float = 15.0

@export_group("Disable")
## Item id the player must carry to disable this hostile. Empty = cannot be disabled.
@export var disable_item: StringName = &""
## Consume the gadget when it is used.
@export var disable_consume: bool = false

@export_group("Hover outline")
## Width in source-texture pixels of the outline drawn while the mouse is over
## this hostile's sprite. 0 disables the effect. Requires `Frames` above.
@export_range(0.0, 16.0, 0.5) var hover_outline_width: float = 4.0
## Outline colour, including its alpha.
@export var hover_outline_tint: Color = Color(1, 1, 1, 1)


## Hides the fields the current settings do not use. Values are kept.
func _validate_property(property: Dictionary) -> void:
	var hidden: bool = false
	match property.name:
		"active_scale":
			hidden = frames != null
		"idle_animation", "active_animation", "hide_animation", "disabled_animation":
			hidden = frames == null
		"sprite_scale":
			hidden = frames == null
		"hover_outline_width", "hover_outline_tint":
			hidden = frames == null
		"disable_consume":
			hidden = disable_item == &""
	if hidden:
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
