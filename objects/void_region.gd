@tool
class_name VoidRegion
extends Node2D
## Turns an invisible collision area into visible scenery: every CollisionShape2D
## child is filled with `color`, so a ring of shapes around the house reads as the
## black void outside it. Positions, rotations and scales are never touched — the
## fill is drawn exactly where each shape already sits.
##
## Attach it to the Area2D that owns the shapes (or to any Node2D above them). It
## works in the editor too, so the fill follows the shape gizmos while you edit.

@export var color: Color = Color(0.0, 0.0, 0.0, 1.0):
	set(value):
		color = value
		queue_redraw()

## Draw behind everything else so the void can never cover the room or the player.
@export var behind_everything: bool = true:
	set(value):
		behind_everything = value
		_apply_layer()


func _ready() -> void:
	_apply_layer()
	queue_redraw()


func _process(_delta: float) -> void:
	# Editor only: keep the fill in step with shape edits. At runtime the shapes
	# do not move, so one redraw is enough.
	if Engine.is_editor_hint():
		queue_redraw()


func _apply_layer() -> void:
	z_index = -1 if behind_everything else 0


func _draw() -> void:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.shape == null or shape_node.disabled:
			continue
		var xf: Transform2D = shape_node.transform
		draw_set_transform(xf.origin, xf.get_rotation(), xf.get_scale())
		_draw_shape(shape_node.shape)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shape(shape: Shape2D) -> void:
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		draw_rect(Rect2(-size * 0.5, size), color)
	elif shape is CircleShape2D:
		draw_circle(Vector2.ZERO, (shape as CircleShape2D).radius, color)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius: float = capsule.radius
		var straight: float = maxf(capsule.height - radius * 2.0, 0.0)
		draw_rect(Rect2(-radius, -straight * 0.5, radius * 2.0, straight), color)
		draw_circle(Vector2(0.0, -straight * 0.5), radius, color)
		draw_circle(Vector2(0.0, straight * 0.5), radius, color)
	elif shape is ConvexPolygonShape2D:
		var points: PackedVector2Array = (shape as ConvexPolygonShape2D).points
		if points.size() >= 3:
			draw_colored_polygon(points, color)
	elif shape is SegmentShape2D:
		var segment := shape as SegmentShape2D
		draw_line(segment.a, segment.b, color, 2.0)
