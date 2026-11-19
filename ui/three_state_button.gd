class_name ThreeStateButton
extends Button
## A Button whose normal / hover / pressed art comes from one ButtonSkin.
## Godot drives the states, so no manual mouse tracking is needed.

## Skin that defines this button's three states and optional label.
@export var skin: ButtonSkin


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_skin()


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
