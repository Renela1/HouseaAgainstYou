@tool
class_name StillObject
extends Node2D
## Scenery that shares the player's and the walls' depth order. Its origin is the
## point it stands on, so it draws in front of everything above that line and
## behind everything below it — the same rule the player and the wall strip use.
##
## It draws through a child `Sprite` node: the sprite's offset is kept so the
## bottom of the art sits on this node's origin, which is what makes the sorting
## land on the object's base instead of its middle. Assign the texture on the
## child sprite as usual, or set `texture` here and it is handed to the child.
##
## When `solid` is on it also grows a `Blocker` StaticBody2D sitting on the base,
## so the player walks into it instead of through it.
##
## Keep it a direct child of the Y-sorted parent (Main) and leave its z_index at
## 0 — Y-sort orders it, and a z_index would take it out of that ordering.

## Optional. When set, it is assigned to the child sprite.
@export var texture: Texture2D:
	set(value):
		texture = value
		_sync()

## Nudge the art off its base, in source-texture pixels (e.g. (0, -4) to sink it).
@export var art_offset: Vector2 = Vector2.ZERO:
	set(value):
		art_offset = value
		_sync()

@export_group("Collision")
## Blocks the player. Turn off for pure decoration.
@export var solid: bool = true:
	set(value):
		solid = value
		_sync()

## Exact size of the blocking box, in world pixels. Left at (0, 0) it sizes itself
## from the art: as wide as the drawing, `footprint_depth` deep.
@export var collision_size: Vector2 = Vector2.ZERO:
	set(value):
		collision_size = value
		_sync()

## Nudge the blocking box from its automatic place on the base line.
@export var collision_offset: Vector2 = Vector2.ZERO:
	set(value):
		collision_offset = value
		_sync()

## Depth of the blocking box when `collision_size` is left at (0, 0).
@export_range(1.0, 256.0, 1.0) var footprint_depth: float = 16.0:
	set(value):
		footprint_depth = value
		_sync()

const ART_NAME: String = "Sprite"
const BLOCKER_NAME: String = "Blocker"
const SHAPE_NAME: String = "Shape"


func _ready() -> void:
	if z_index != 0:
		push_warning("StillObject '%s': z_index is %d. Leave it at 0 so Y-sort can order it against the player and the walls." % [name, z_index])
	_sync()


## Keeps the sprite bottom-aligned on the origin and the blocker on the base.
func _sync() -> void:
	if not is_inside_tree():
		return
	var art: Node2D = _art()
	var size: Vector2 = _art_size(art)
	if size.y > 0.0:
		var offset: Vector2 = Vector2(0.0, -size.y * 0.5) + art_offset
		if art is Sprite2D:
			var sprite := art as Sprite2D
			if texture != null:
				sprite.texture = texture
			sprite.centered = true
			sprite.offset = offset
		elif art is AnimatedSprite2D:
			var animated := art as AnimatedSprite2D
			animated.centered = true
			animated.offset = offset
	# The sprite's own scale shrinks the art, so the footprint has to follow it.
	var world: Vector2 = Vector2(size.x * absf(art.scale.x), size.y * absf(art.scale.y))
	_sync_blocker(world)


## A StaticBody2D on the base. The box is driven by the exports above, so it is
## resized from the Inspector and never fights what the scene has saved.
func _sync_blocker(art_world_size: Vector2) -> void:
	var body := get_node_or_null(BLOCKER_NAME) as StaticBody2D
	if not solid:
		if body != null:
			body.queue_free()
		return
	if body == null:
		body = StaticBody2D.new()
		body.name = BLOCKER_NAME
		add_child(body)
		if owner != null:
			body.owner = owner
	var shape_node := body.get_node_or_null(SHAPE_NAME) as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = SHAPE_NAME
		body.add_child(shape_node)
		if owner != null:
			shape_node.owner = owner
	var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect

	if collision_size.x > 0.0 and collision_size.y > 0.0:
		rect.size = collision_size
	elif art_world_size.x > 0.0:
		# Auto: as wide as the drawing, `footprint_depth` deep.
		rect.size = Vector2(art_world_size.x, footprint_depth)
	else:
		rect.size = Vector2(32.0, footprint_depth)
	# Sit on the base line, then take the manual nudge on top of that.
	shape_node.position = Vector2(0.0, -rect.size.y * 0.5) + collision_offset


## The child that draws the art, created on first use so a fresh StillObject has
## somewhere to put a texture.
func _art() -> Node2D:
	var existing := get_node_or_null(ART_NAME) as Node2D
	if existing != null:
		return existing
	var sprite := Sprite2D.new()
	sprite.name = ART_NAME
	add_child(sprite)
	if owner != null:
		sprite.owner = owner
	return sprite


func _art_size(art: Node2D) -> Vector2:
	if art is Sprite2D:
		var art_texture: Texture2D = (art as Sprite2D).texture
		return art_texture.get_size() if art_texture != null else Vector2.ZERO
	if art is AnimatedSprite2D:
		var animated := art as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation):
			return Vector2.ZERO
		if animated.sprite_frames.get_frame_count(animated.animation) <= 0:
			return Vector2.ZERO
		var frame: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		return frame.get_size() if frame != null else Vector2.ZERO
	return Vector2.ZERO
