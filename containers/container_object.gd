class_name ContainerObject
extends Area2D
## A solid container with two independent toggles: open/closed and full/empty.
## What it looks like, what it needs and what it holds all live in `data`
## (a ContainerData resource), so a new container is a new .tres plus an
## instance of this scene.
##
## First successful interaction while FULL: unlock, take every item at once,
## mark EMPTY and force OPEN. While EMPTY, interactions only flip the open/close
## toggle (conditions are still checked). A bag with no room for the whole loot
## is refused before anything is consumed, so items are never lost.

signal opened
signal closed
signal emptied
signal fill_changed(is_full: bool)
signal refused(reason: String)

## Definition of this container. Shared resource — never mutated at runtime.
@export var data: ContainerData
## Initial open/closed state, adjustable per placed container.
@export var starts_open: bool = false
## Initial full/empty state. A container with no contents always starts empty.
@export var starts_full: bool = true

## True while the lid is open.
var is_open: bool = false
## True until the first successful interaction hands over all the contents.
var is_full: bool = true

var _in_reach: bool = false
var _hovered: bool = false
var _flash: float = 0.0
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	add_to_group("containers")
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if data == null:
		push_warning("ContainerObject '%s' has no ContainerData assigned." % name)
		return
	is_full = starts_full and not data.contents_as_entries().is_empty()
	is_open = starts_open
	_resize_shapes()
	_apply_solidity()
	_apply_visuals()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


## Called by InteractZone when this container enters or leaves the player's reach.
func set_in_reach(value: bool) -> void:
	_in_reach = value
	queue_redraw()


## The contract InteractZone looks for. Returns true when it did something.
func interact(_interactor: Node) -> bool:
	if data == null:
		return false
	if not data.conditions_met(Inventory):
		_refuse(data.failure_message(Inventory))
		return false

	if is_full:
		var entries: Array[Dictionary] = data.contents_as_entries()
		if not Inventory.can_add_all(entries):
			_refuse(data.full_bag_text)
			return false
		# Passed the lock and has room: consume the key/gadget, hand over all the
		# loot, then force OPEN. Only this interaction ever transfers contents.
		data.consume_all(Inventory)
		for entry in entries:
			Inventory.add_item(entry["item"] as ItemData, int(entry["quantity"]))
		is_full = false
		fill_changed.emit(false)
		emptied.emit()
		_set_open(true)
		var loot: String = data.loot_message
		if loot.is_empty():
			loot = "Found: %s" % data.contents_label()
		_say(loot)
		return true

	# EMPTY: the only thing left to do is flip the lid.
	_set_open(not is_open)
	return true


## Fills it again (e.g. for a new game loop or a refilling chest).
func refill() -> void:
	if data == null or data.contents_as_entries().is_empty():
		return
	is_full = true
	fill_changed.emit(true)
	queue_redraw()


func _set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	_apply_visuals()
	var line: String = ""
	if is_open:
		opened.emit()
		line = data.open_message
		if line.is_empty():
			line = "Opened the %s." % data.name
	else:
		closed.emit()
		line = data.close_message
		if line.is_empty():
			line = "Closed the %s." % data.name
	_say(line)


func _apply_visuals() -> void:
	if data == null:
		return
	if _sprite != null:
		if data.frames != null:
			var wanted: StringName = data.open_animation if is_open else data.closed_animation
			_sprite.sprite_frames = data.frames
			if data.frames.has_animation(wanted):
				_sprite.animation = wanted
				_sprite.play(wanted)
			else:
				_sprite.stop()
			_sprite.visible = true
		else:
			_sprite.stop()
			_sprite.visible = false
	queue_redraw()


func _resize_shapes() -> void:
	var shape: Shape2D = _make_shape()
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.shape = shape
	var blocker := get_node_or_null("Blocker")
	if blocker != null:
		for child in blocker.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node != null:
				shape_node.shape = _make_shape()


func _make_shape() -> Shape2D:
	if data.shape == ContainerData.Shape.CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = data.size.x * 0.5
		return circle
	var rect := RectangleShape2D.new()
	rect.size = data.size
	return rect


## Containers are fixtures: solid in both states. The blocker follows `size`,
## never the sprite, so opening the lid cannot shove the player.
func _apply_solidity() -> void:
	var blocker := get_node_or_null("Blocker") as StaticBody2D
	if blocker == null:
		return
	var blocks: bool = data != null and data.solid
	blocker.collision_layer = 1 if blocks else 0
	for child in blocker.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			shape_node.set_deferred("disabled", not blocks)


func _refuse(reason: String) -> void:
	_flash = 1.0
	queue_redraw()
	refused.emit(reason)
	_say(reason)


## Talks to whatever node advertises itself in the "interact_feedback" group.
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


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	if _sprite == null or not _sprite.visible:
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
		var outline := Rect2(-data.size * 0.5 - Vector2(4.0, 4.0), data.size + Vector2(8.0, 8.0))
		draw_rect(outline, Color(1.0, 0.28, 0.28, _flash), false, 3.0)


func _draw_body() -> void:
	var body_color: Color = data.open_color if is_open else data.closed_color
	if data.shape == ContainerData.Shape.CIRCLE:
		draw_circle(Vector2.ZERO, data.size.x * 0.5, body_color)
	else:
		draw_rect(Rect2(-data.size * 0.5, data.size), body_color)
		var lid := Rect2(-data.size.x * 0.42, -data.size.y * 0.42, data.size.x * 0.84, data.size.y * 0.22)
		if is_open:
			draw_rect(lid, Color(0.0, 0.0, 0.0, 0.5))
		else:
			draw_rect(lid, Color(0.92, 0.76, 0.36, 0.6))
	if is_full:
		draw_circle(Vector2(data.size.x * 0.5 - 7.0, -data.size.y * 0.5 + 7.0), 3.0, Color(1.0, 0.86, 0.32))
