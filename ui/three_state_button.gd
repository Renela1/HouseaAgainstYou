class_name ThreeStateButton
extends Button
## A Button whose normal / hover / pressed art comes from one ButtonSkin.
## Godot drives the styles; a short tween eases the scale and brightness between
## them, so hover and press read as motion instead of a hard swap.

## Skin that defines this button's three states and optional label.
@export var skin: ButtonSkin
## How much the button grows while the pointer is over it.
@export_range(0.8, 1.3, 0.01) var hover_scale: float = 1.04
## How much it shrinks while held down.
@export_range(0.8, 1.3, 0.01) var press_scale: float = 0.97
## Brightness multiplier while hovered (1 = unchanged).
@export_range(0.5, 2.0, 0.01) var hover_brightness: float = 1.1
## Seconds for one state change.
@export_range(0.0, 0.5, 0.01) var transition_seconds: float = 0.12

var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_skin()
	resized.connect(_recenter_pivot)
	_recenter_pivot()
	mouse_entered.connect(_on_pointer_entered)
	mouse_exited.connect(_on_pointer_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _apply_skin() -> void:
	if skin == null:
		return
	if not skin.label.is_empty():
		text = skin.label
	add_theme_stylebox_override("normal", skin.style_for(ButtonSkin.State.NORMAL))
	add_theme_stylebox_override("hover", skin.style_for(ButtonSkin.State.HOVER))
	add_theme_stylebox_override("pressed", skin.style_for(ButtonSkin.State.PRESSED))
	add_theme_stylebox_override("disabled", skin.style_for(ButtonSkin.State.NORMAL))
	add_theme_color_override("font_color", skin.font_color)
	add_theme_color_override("font_hover_color", skin.font_hover_color)
	add_theme_color_override("font_pressed_color", skin.font_pressed_color)


## Scale and brightness pivot around the middle of the button.
func _recenter_pivot() -> void:
	pivot_offset = size * 0.5


func _on_pointer_entered() -> void:
	if is_pressed():
		return
	_animate(hover_scale, hover_brightness)


func _on_pointer_exited() -> void:
	if is_pressed():
		return
	_animate(1.0, 1.0)


func _on_button_down() -> void:
	_animate(press_scale, hover_brightness)


func _on_button_up() -> void:
	var over: bool = is_hovered()
	_animate(hover_scale if over else 1.0, hover_brightness if over else 1.0)


## Eases towards a scale and brightness. A new call retargets the same tween, so
## quick in-and-out moves do not queue up behind each other.
func _animate(target_scale: float, brightness: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, transition_seconds)
	_tween.tween_property(self, "modulate", Color(brightness, brightness, brightness, 1.0), transition_seconds)
