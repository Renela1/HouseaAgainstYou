class_name InteractZone
extends Area2D
## The player's reach: tracks everything interactable that overlaps it and
## forwards clicks to the target itself. The zone knows only the `interact()`
## contract, so the same node serves pickups now and doors later.

signal target_entered(target: Node2D)
signal target_exited(target: Node2D)
## Emitted when a click lands on something out of reach, or not interactable.
signal interact_refused(target: Node2D)

## Reach radius in pixels.
@export var radius: float = 96.0
## Draw a faint ring while at least one target is in reach.
@export var show_ring: bool = true

var _targets: Array[Node2D] = []


func _ready() -> void:
	add_to_group("interact_zone")
	monitoring = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_shape()
	queue_redraw()


## True while `target` overlaps the reach circle.
func is_in_range(target: Node) -> bool:
	return _targets.has(target)


## Everything currently in reach.
func get_targets() -> Array[Node2D]:
	return _targets.duplicate()


## Closest target to the zone, or null when nothing is in reach.
func get_nearest() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for target in _targets:
		var dist: float = global_position.distance_squared_to(target.global_position)
		if dist < best_dist:
			best_dist = dist
			best = target
	return best


## The single gatekeeper: refuses anything out of range, otherwise calls
## `interact(interactor)` on the target. Pickups and doors both work unchanged.
## A successful interaction also tells the player which animation to play.
func request_interact(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not is_in_range(target) or not target.has_method("interact"):
		interact_refused.emit(target)
		return false
	# Asked before the call: starting a gadget fix may consume the item that
	# decides whether this is a disable or a plain hostile interaction.
	var kind: StringName = _interaction_kind(target)
	var interacted: bool = bool(target.call("interact", get_parent()))
	if interacted:
		_play_interaction(kind)
	return interacted


## The interaction kind, named after the player animation it should play. A
## target may answer for itself; otherwise its group names the kind.
func _interaction_kind(target: Node) -> StringName:
	if target.has_method("interaction_kind"):
		return StringName(target.call("interaction_kind"))
	if target.is_in_group("pickables"):
		return &"pickup"
	if target.is_in_group("interactables"):
		return &"interact"
	if target.is_in_group("hostiles"):
		return &"hostile_interact"
	return &"interact"


## Hands the kind to the interactor (this zone's parent, the player). Interactors
## without the method are simply not told.
func _play_interaction(kind: StringName) -> void:
	var interactor: Node = get_parent()
	if interactor != null and interactor.has_method("play_interaction"):
		interactor.call("play_interaction", kind)


func _build_shape() -> void:
	var shape_node: CollisionShape2D = null
	for child in get_children():
		shape_node = child as CollisionShape2D
		if shape_node != null:
			break
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "Shape"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle


func _on_area_entered(area: Area2D) -> void:
	_track(area)


func _on_area_exited(area: Area2D) -> void:
	_untrack(area)


func _on_body_entered(body: Node2D) -> void:
	_track(body)


func _on_body_exited(body: Node2D) -> void:
	_untrack(body)


func _track(node: Node2D) -> void:
	if node == null or _targets.has(node) or not node.has_method("interact"):
		return
	_targets.append(node)
	if node.has_method("set_in_reach"):
		node.call("set_in_reach", true)
	target_entered.emit(node)
	queue_redraw()


func _untrack(node: Node2D) -> void:
	if node == null or not _targets.has(node):
		return
	_targets.erase(node)
	if is_instance_valid(node) and node.has_method("set_in_reach"):
		node.call("set_in_reach", false)
	target_exited.emit(node)
	queue_redraw()


func _draw() -> void:
	if not show_ring or _targets.is_empty():
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.16), 1.5)
