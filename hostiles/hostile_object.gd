class_name HostileObject
extends Area2D
## Something that watches a cone in front of itself.
##
## IDLE -> countdown reaches 0 -> ACTIVE. Whenever the player stands in the cone
## the hostile goes into HIDE, whichever state it was in, because it refuses to
## act while watched. HIDE remembers that state: leaving a hide entered from IDLE
## freezes the countdown at its current value and resumes it from there (it is
## never reset), while leaving one entered from ACTIVE simply returns to ACTIVE.
## HIDE plays its own animation and shows no timer. Interacting calms it back to
## IDLE and keeps it inert for `grace_seconds`; carrying the disable gadget shuts
## it down (DISABLED).
##
## Every hostile runs its own countdown: `data.wake_seconds` starts with the
## game and restarts whenever it is calmed, and wakes it on its own when it
## reaches 0. A DISABLED hostile runs `data.disable_seconds` instead and comes
## back online when that runs out (0 = it stays down). A DISABLED hostile has
## no line of sight, so watching it does nothing.
##
## Everything that differs between hostiles lives in `data`; state-specific
## actions go in _on_activated() or on the state_changed signal.

enum State {
	IDLE,     ## Default. Watching its cone, counting down to a wake-up.
	ACTIVE,   ## Woken up; latched until interacted with.
	HIDE,     ## Watched: hide animation, no timer; remembers whether to return to IDLE or ACTIVE.
	DISABLED, ## Shut down; no sight while it is down.
}

signal state_changed(previous: int, current: int)
## Emitted the moment the player steps into its cone.
signal spotted_player
## Emitted when the disable gadget shuts it down.
signal disabled
## Emitted when a disabled hostile's counter-disable timer runs out and it
## comes back online.
signal reactivated

## Definition of this hostile. Shared resource — never mutated at runtime.
@export var data: HostileData

## Current state. Read it freely; use activate() / calm() / disable() to change it.
var state: State = State.IDLE
## State to restore when the player looks away. IDLE also keeps its frozen timer.
var _hide_return: State = State.IDLE

var _aware: bool = false
var _grace: float = 0.0
var _in_reach: bool = false
var _hovered: bool = false
var _sprite: AnimatedSprite2D = null
## Seconds left on the running countdown and its starting value (for the bar).
var _timer: float = 0.0
var _timer_max: float = 0.0
## True when the running countdown is the counter-disable one.
var _timer_disabled: bool = false
## True while an IDLE countdown is frozen by the player's gaze (inside HIDE).
var _timer_paused: bool = false


func _ready() -> void:
	add_to_group("hostiles")
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if data == null:
		push_warning("HostileObject '%s' has no HostileData assigned." % name)
		return
	_resize_shape()
	_apply_solidity()
	_start_wake_timer()
	_apply_visuals()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	# Sight is live in every state except DISABLED, grace period included.
	if state != State.DISABLED:
		_update_sight()
	# The countdown keeps its remaining seconds; it only ticks when it is not
	# frozen by the player's gaze. HIDE has no timer of its own to run.
	if not _timer_paused and _timer > 0.0:
		_timer = maxf(_timer - delta, 0.0)
		if is_zero_approx(_timer):
			_on_timer_elapsed()
		queue_redraw()
	# Grace only dims the cone now: hiding, not blindness, protects the player.
	if _grace > 0.0:
		_grace = maxf(_grace - delta, 0.0)
		queue_redraw()


## Watches the player and enters/leaves HIDE without disturbing the underlying
## state. The countdown is left exactly where it was, for exit_hide() to resume.
func _update_sight() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var aware: bool = player != null and _can_see(player)
	if aware != _aware:
		_aware = aware
		if aware:
			spotted_player.emit()
		queue_redraw()
	if aware:
		if state == State.IDLE or state == State.ACTIVE:
			enter_hide()
	elif state == State.HIDE:
		exit_hide()


## Puts it on alert. Safe to call from other systems (noise, triggers, ...).
## An already-running countdown is consumed (it already did its job).
func activate() -> void:
	if data == null or state != State.IDLE:
		return
	_timer = 0.0
	_timer_paused = false
	_hide_return = State.IDLE
	_grace = 0.0
	_set_state(State.ACTIVE)
	spotted_player.emit()
	_on_activated()


## Back to watching, with a short visual grace marker on the cone. The player is
## protected by HIDE while watched, not by blindness. This also restarts the
## auto-wake countdown.
func calm() -> void:
	if data == null or state == State.DISABLED:
		return
	_aware = false
	_hide_return = State.IDLE
	_grace = data.grace_seconds
	_set_state(State.IDLE)
	_start_wake_timer()
	queue_redraw()


## Shuts it down. If `data.disable_seconds` is above 0 the counter-disable
## countdown starts instead of the normal one.
func disable() -> void:
	if data == null or state == State.DISABLED:
		return
	_aware = false
	_hide_return = State.IDLE
	_grace = 0.0
	_set_state(State.DISABLED)
	_start_disable_timer()
	disabled.emit()


## Hides from the player's gaze from either IDLE or ACTIVE, remembering which one
## to return to. From IDLE the countdown is frozen at its current value; from
## ACTIVE there is no countdown at all.
func enter_hide() -> void:
	if data == null or state == State.HIDE:
		return
	if state != State.IDLE and state != State.ACTIVE:
		return
	_hide_return = state
	if state == State.IDLE:
		_pause_timer()
	else:
		_timer = 0.0
		_timer_paused = false
	_set_state(State.HIDE)


## Returns to the state the player interrupted. An IDLE countdown resumes from
## the exact value it was frozen at; an ACTIVE hostile simply becomes alert again.
func exit_hide() -> void:
	if data == null or state != State.HIDE:
		return
	var return_state: State = _hide_return
	_hide_return = State.IDLE
	_set_state(return_state)
	if return_state == State.IDLE:
		_resume_timer()
	else:
		_timer = 0.0
		_timer_paused = false
		queue_redraw()


## Comes back online after the counter-disable countdown ran out.
func reactivate() -> void:
	if data == null or state != State.DISABLED:
		return
	_timer = 0.0
	_timer_paused = false
	_hide_return = State.IDLE
	_grace = 0.0
	_set_state(State.ACTIVE)
	reactivated.emit()
	_on_activated()


## Seconds left on the running countdown, 0 when no countdown is running.
func time_left() -> float:
	return _timer


## True when the bag holds this hostile's disable gadget.
func has_disable_gadget() -> bool:
	return data != null and data.disable_item != &"" and Inventory.has_item(data.disable_item, 1)


## The contract InteractZone looks for. The calm-down interaction is
## unconditional; carrying the gadget turns it into a shutdown.
func interact(_interactor: Node) -> bool:
	if data == null or state == State.DISABLED:
		return false
	if has_disable_gadget():
		if data.disable_consume:
			Inventory.remove_item(data.disable_item, 1)
		disable()
		return true
	calm()
	return true


## Override for state-specific behaviour when it is alerted.
func _on_activated() -> void:
	pass


## Called by InteractZone when this object enters or leaves the player's reach.
func set_in_reach(value: bool) -> void:
	_in_reach = value
	queue_redraw()


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous: State = state
	state = next
	_apply_visuals()
	state_changed.emit(previous, next)


## The auto-wake countdown restarts with the game and after every calm.
func _start_wake_timer() -> void:
	_timer_disabled = false
	_set_timer(data.wake_seconds if data != null else 0.0)


## The counter-disable countdown replaces it while the hostile is shut down.
func _start_disable_timer() -> void:
	_timer_disabled = true
	_set_timer(data.disable_seconds if data != null else 0.0)


func _set_timer(seconds: float) -> void:
	_timer = maxf(seconds, 0.0)
	_timer_max = _timer
	_timer_paused = false
	queue_redraw()


## Freezes the countdown at exactly the seconds left. The value is kept so it can
## be resumed later; HIDE itself draws no bar.
func _pause_timer() -> void:
	_timer_paused = true
	queue_redraw()


## Unfreezes the countdown. It continues from the remaining seconds, never from
## the start.
func _resume_timer() -> void:
	if not _timer_paused:
		return
	_timer_paused = false
	queue_redraw()


## A countdown reached 0: wake on its own, or come back online.
func _on_timer_elapsed() -> void:
	var was_disable_timer: bool = _timer_disabled
	_timer = 0.0
	if state == State.IDLE:
		activate()
	elif state == State.DISABLED and was_disable_timer:
		reactivate()


## Pushes the current state's look onto the sprite and the placeholder drawing.
func _apply_visuals() -> void:
	if _sprite != null and data.frames != null:
		if _sprite.sprite_frames != data.frames:
			_sprite.sprite_frames = data.frames
		var animation: StringName = _current_animation()
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation):
			_sprite.play(animation)
	queue_redraw()


func _current_animation() -> StringName:
	match state:
		State.ACTIVE:
			return data.active_animation
		State.HIDE:
			return data.hide_animation
		State.DISABLED:
			return data.disabled_animation
		_:
			return data.idle_animation


func _current_size() -> Vector2:
	if state == State.ACTIVE:
		return data.size * data.active_scale
	return data.size


func _current_color() -> Color:
	match state:
		State.ACTIVE:
			return data.active_color
		State.HIDE:
			return data.hide_color
		State.DISABLED:
			return data.disabled_color
		_:
			return data.idle_color


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
	# The click/overlap area and the physical body share one size.
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
	if data.shape == HostileData.Shape.CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = data.size.x * 0.5
		return circle
	var rect := RectangleShape2D.new()
	rect.size = data.size
	return rect


## Hostiles are physical obstacles in every state; shutting one down does not
## remove it from the room, so the blocker only depends on `data.solid`.
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


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	if state != State.DISABLED:
		_draw_sight()
	if data.frames == null:
		_draw_body()
	_draw_timer()
	var ring_alpha: float = 0.0
	if _hovered:
		ring_alpha = 0.9
	elif _in_reach:
		ring_alpha = 0.45
	if ring_alpha > 0.0:
		var body: Vector2 = _current_size()
		var ring_radius: float = maxf(body.x, body.y) * 0.5 + 6.0
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, ring_alpha), 2.0)


func _draw_body() -> void:
	var body: Vector2 = _current_size()
	var body_color: Color = _current_color()
	if data.shape == HostileData.Shape.CIRCLE:
		draw_circle(Vector2.ZERO, body.x * 0.5, body_color)
	else:
		draw_rect(Rect2(-body * 0.5, body), body_color)


## A thin bar above the body: warm while counting down to an auto-wake, cool
## while counting down from a disable. HIDE shows no bar — the countdown is kept
## internally so it can resume where it left off.
func _draw_timer() -> void:
	if state == State.ACTIVE or state == State.HIDE or _timer_max <= 0.0:
		return
	if _timer <= 0.0:
		return
	var ratio: float = clampf(_timer / _timer_max, 0.0, 1.0)
	var fill: Color = Color(0.55, 0.75, 1.0) if _timer_disabled else Color(0.95, 0.78, 0.3)
	var width: float = clampf(data.size.x, 24.0, 56.0)
	var height: float = 4.0
	var top: float = -data.size.y * 0.5 - 12.0
	var track := Rect2(Vector2(-width * 0.5, top), Vector2(width, height))
	draw_rect(track, Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(track.position, Vector2(width * ratio, height)), fill)


## The cone is bright while the hostile actually sees the player, dim while it is
## inert, hiding or merely latched, and gone once disabled.
func _draw_sight() -> void:
	var cone_color: Color = data.sight_color
	if not _aware or _grace > 0.0 or state == State.HIDE:
		cone_color = Color(cone_color.r, cone_color.g, cone_color.b, cone_color.a * 0.55)
	# A full circle cannot be drawn as a fan (the first and last arc points
	# coincide and triangulation fails), so draw it as a disc.
	if data.sight_angle_deg >= 359.9:
		draw_circle(Vector2.ZERO, data.sight_radius, cone_color)
		return
	var half: float = deg_to_rad(data.sight_angle_deg) * 0.5
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var steps: int = 20
	for i in steps + 1:
		var angle: float = -half + (half * 2.0) * float(i) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * data.sight_radius)
	draw_colored_polygon(points, cone_color)
