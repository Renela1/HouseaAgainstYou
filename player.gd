extends CharacterBody2D
## Walk/idle character driven by WASD or the arrow keys. The Camera child follows
## it; world bounds belong to the level, not to this script.
##
## Movement animations are looked up by facing, so a direction can be added later
## without touching this script:
##   "walk_up" / "walk_down" / "walk_left" / "walk_right"
##   "idle_up" / "idle_down" / "idle_left" / "idle_right"
## A missing directional animation falls back to the plain "walk" / "idle" pair,
## and left/right on the fallback flips the sprite. If a state has no usable
## frames at all (for example an empty "idle"), the current pose is held instead
## of playing a blank animation.
##
## Interactions play an animation named after their kind, when
## art/player_frames.tres has one:
##   "pickup"           clicking a pickable item
##   "interact"         a door, the final door, a lever, a container
##   "hostile_interact" calming a hostile by hand
##   "disable"          fitting the disable gadget into a hostile
## Until those animations exist the interaction shows a text line naming the
## missing one. Movement is locked while an interaction animation runs, so the
## player cannot walk out of the pose.

const WALK_BASE: StringName = &"walk"
const IDLE_BASE: StringName = &"idle"

@export var speed: float = 320.0
## Used by the "walk" / "idle" fallback; directional animations are played
## as authored, without flipping.
@export var flip_fallback_for_left: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite

## Last facing, kept so the idle animation matches the way the player stopped.
var _facing: StringName = &"down"
## Animation currently playing, or &"" when the player is free to move.
var _interaction: StringName = &""
## Seconds left on it.
var _interaction_left: float = 0.0


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if not is_interacting():
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_advance_interaction(delta)
	_animate(direction)


## True while an interaction animation owns the sprite and movement is locked.
func is_interacting() -> bool:
	return _interaction != &""


## Plays the animation for `kind`, or reports which one is still missing. Called
## by InteractZone after an interaction succeeded; an empty kind does nothing.
func play_interaction(kind: StringName) -> void:
	if kind == &"":
		return
	if _has_frames(kind):
		_interaction = kind
		_interaction_left = _animation_seconds(sprite.sprite_frames, kind)
		sprite.play(kind)
		return
	_say("%s: no '%s' animation yet" % [_kind_label(kind), kind])


func _advance_interaction(delta: float) -> void:
	if _interaction == &"":
		return
	_interaction_left = maxf(_interaction_left - delta, 0.0)
	if _interaction_left <= 0.0:
		_interaction = &""


## One pass through `animation`, from its frame count and speed.
func _animation_seconds(frames: SpriteFrames, animation: StringName) -> float:
	var count: int = frames.get_frame_count(animation)
	var speed_fps: float = frames.get_animation_speed(animation)
	if count <= 0 or speed_fps <= 0.0:
		return 0.5
	return maxf(float(count) / speed_fps, 0.2)


## Picks the animation for this frame: a facing-specific one when it exists,
## otherwise the shared walk/idle pair, otherwise hold the current pose.
func _animate(direction: Vector2) -> void:
	if is_interacting():
		return
	var moving: bool = direction != Vector2.ZERO
	if moving:
		_facing = _facing_for(direction)

	var base: StringName = WALK_BASE if moving else IDLE_BASE
	var directional: StringName = StringName("%s_%s" % [base, _facing])

	if _has_frames(directional):
		# Authored per direction, so it draws as-is without a flip.
		sprite.flip_h = false
		_play(directional)
		return
	if _has_frames(base):
		if moving and flip_fallback_for_left:
			sprite.flip_h = direction.x < 0.0
		_play(base)
		return
	# Nothing usable for this state: hold the pose rather than going blank.
	if sprite.is_playing():
		sprite.pause()


## Godot keeps the animation name after it finishes, so the name alone is not
## enough: a stopped sprite has to be told to play again.
func _play(animation: StringName) -> void:
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


## Dominant axis of travel, as an animation suffix.
func _facing_for(direction: Vector2) -> StringName:
	if absf(direction.y) > absf(direction.x):
		return &"up" if direction.y < 0.0 else &"down"
	return &"left" if direction.x < 0.0 else &"right"


func _has_frames(animation: StringName) -> bool:
	var frames: SpriteFrames = sprite.sprite_frames
	return frames != null and frames.has_animation(animation) and frames.get_frame_count(animation) > 0


func _kind_label(kind: StringName) -> String:
	match kind:
		&"pickup":
			return "Pickup"
		&"interact":
			return "Interact"
		&"hostile_interact":
			return "Hostile"
		&"disable":
			return "Disable"
		_:
			return String(kind).capitalize()


## Talks to whatever advertises itself in the "interact_feedback" group, so the
## player never hard-wires a HUD path.
func _say(text: String) -> void:
	var feedback: Node = get_tree().get_first_node_in_group("interact_feedback")
	if feedback != null and feedback.has_method("show_message"):
		feedback.call("show_message", text)
