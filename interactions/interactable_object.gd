class_name InteractableObject
extends Area2D
## Anything the player can use: a lever, a door, a terminal, a container. *What*
## it is and what it needs lives in the \`data\` InteractableData; this class only
## handles presence, look, condition checks and the success effect, so every new
## object is a new .tres plus an instance of this scene.
##
## Behaviour a resource cannot express: write a small script that extends this
## class and override _on_activated() / _on_refused().

signal activated(interactor: Node)
signal refused(reason: String)
## Emitted by objects with sight when the player enters or leaves their cone.
signal sight_changed(sees_player: bool)

## Definition of this object. Shared resource — never mutated at runtime.
@export var data: InteractableData

var _in_reach: bool = false
var _hovered: bool = false
var _aware: bool = false
var _used: bool = false
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("interactables")
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if data == null:
		push_warning("InteractableObject '%s' has no InteractableData assigned." % name)
		return
	_resize_shape()
	_apply_solidity()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if data == null or not data.has_sight:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var aware: bool = player != null and _can_see(player)
	if aware == _aware:
		return
	_aware = aware
	queue_redraw()
	sight_changed.emit(aware)


## Called by InteractZone when this object enters or leaves the player's reach.
func set_in_reach(value: bool) -> void:
	_in_reach = value
	queue_redraw()


## The contract InteractZone looks for. Returns true when it did something.
func interact(interactor: Node) -> bool:
	if data == null:
		return false
	if _used and data.one_shot:
		_refuse(data.refusal_text)
		return false
	if data.has_sight and data.require_sight and not _aware:
		_refuse("It only responds from the front.")
		return false
	if not data.conditions_met(Inventory):
		_refuse(data.failure_message(Inventory))
		return false
	data.consume_all(Inventory)
	_used = true
	_apply_success()
	activated.emit(interactor)
	_on_activated(interactor)
	return true


## Override for custom per-object behaviour after a successful interaction.
func _on_activated(_interactor: Node) -> void:
	pass


## Override for custom per-object behaviour when an interaction is refused.
func _on_refused(_reason: String) -> void:
	pass


func _apply_success() -> void:
	_apply_solidity()
	queue_redraw()
	if not data.pulse:
		scale = data.success_scale
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", data.success_scale * 1.12, 0.08)
	tween.tween_property(self, "scale", data.success_scale, 0.14)


func _refuse(reason: String) -> void:
	_flash = 1.0
	queue_redraw()
	refused.emit(reason)
	_on_refused(reason)
	_say(reason)


## Talks to whatever node advertises itself in the "interact_feedback" group, so
## the object never hard-wires a HUD path.
func _say(text: String) -> void:
	if text.is_empty():
		return
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var zone: InteractZone = get_tree().get_first_node_in_group("interact_zone") as InteractZone
	if zone != null:
		zone.request_interact(self)


## Inside the cone: within radius and within half the angle of the facing side.
func _can_see(target: Node2D) -> bool:
	var offset: Vector2 = target.global_position - global_position
	if offset.length_squared() > data.sight_radius * data.sight_radius:
		return false
	if data.sight_angle_deg >= 359.9:
		return true
	var facing: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	return absf(rad_to_deg(facing.angle_to(offset))) <= data.sight_angle_deg * 0.5


func _resize_shape() -> void:
	# The click/overlap area and the physical blocker share one size.
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.shape = _make_shape()
	var blocker := get_node_or_null("Blocker")
	if blocker != null:
		for child in blocker.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node != null:
				shape_node.shape = _make_shape()


func _make_shape() -> Shape2D:
	if data.shape == InteractableData.Shape.CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = data.size.x * 0.5
		return circle
	var rect := RectangleShape2D.new()
	rect.size = data.size
	return rect


## Solid objects carry a Blocker child: a StaticBody2D on the world layer that
## the player collides with while the object should block. Doors stop blocking
## once they open; levers and terminals keep their wall.
func _apply_solidity() -> void:
	var blocker := get_node_or_null("Blocker") as StaticBody2D
	if blocker == null:
		return
	var blocks: bool = data != null and data.solid
	if data != null and data.kind == InteractableData.Kind.DOOR and _used:
		# An opened door is a doorway, not a wall. Fixtures stay solid.
		blocks = false
	blocker.collision_layer = 1 if blocks else 0
	for child in blocker.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.set_deferred("disabled", not blocks)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	if data.has_sight:
		_draw_sight()
	_draw_body()
	var ring_alpha: float = 0.0
	if _hovered:
		ring_alpha = 0.9
	elif _in_reach:
		ring_alpha = 0.45
	if ring_alpha > 0.0:
		var ring_radius: float = maxf(data.size.x, data.size.y) * 0.5 + 6.0
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, ring_alpha), 2.0)
	if _flash > 0.0:
		_draw_flash()


func _draw_body() -> void:
	var body_color: Color = data.success_color if _used else data.color
	if data.shape == InteractableData.Shape.CIRCLE:
		draw_circle(Vector2.ZERO, data.size.x * 0.5, body_color)
	else:
		draw_rect(Rect2(-data.size * 0.5, data.size), body_color)


func _draw_sight() -> void:
	var cone_color: Color = data.sight_color
	if _aware:
		cone_color = Color(cone_color.r, cone_color.g, cone_color.b, minf(cone_color.a + 0.18, 1.0))
	var half: float = deg_to_rad(data.sight_angle_deg) * 0.5
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var steps: int = 20
	for i in steps + 1:
		var angle: float = -half + (half * 2.0) * float(i) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * data.sight_radius)
	draw_colored_polygon(points, cone_color)


func _draw_flash() -> void:
	var flash_color := Color(1.0, 0.28, 0.28, _flash)
	if data.shape == InteractableData.Shape.CIRCLE:
		draw_arc(Vector2.ZERO, data.size.x * 0.5 + 8.0, 0.0, TAU, 32, flash_color, 3.0)
	else:
		var outline := Rect2(-data.size * 0.5 - Vector2(4.0, 4.0), data.size + Vector2(8.0, 8.0))
		draw_rect(outline, flash_color, false, 3.0)
