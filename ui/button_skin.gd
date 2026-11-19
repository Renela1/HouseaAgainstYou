class_name ButtonSkin
extends Resource
## The three visual states of one button, authored as pixel regions of a shared
## tileset. When no atlas is assigned, a burgundy flat-colour fallback is used
## so a menu is still readable before the artwork is wired up.

enum State { NORMAL, HOVER, PRESSED }

## Optional label; overrides the text on the Button when set.
@export var label: String = ""
## The three-state button tileset.
@export var atlas: Texture2D
## Region of this button in each state. Empty regions fall back to flat colours.
@export var region_normal: Rect2i = Rect2i(0, 0, 0, 0)
@export var region_hover: Rect2i = Rect2i(0, 0, 0, 0)
@export var region_pressed: Rect2i = Rect2i(0, 0, 0, 0)
## Nine-patch margins inside each tile. 0 stretches the whole tile.
@export_range(0, 64, 1) var patch_margin: int = 0

@export_group("Text")
@export var font_color: Color = Color(0.96, 0.9, 0.82)
@export var font_hover_color: Color = Color(1.0, 1.0, 1.0)
@export var font_pressed_color: Color = Color(0.9, 0.78, 0.7)

@export_group("Fallback colours")
@export var normal_color: Color = Color(0.36, 0.12, 0.18)
@export var hover_color: Color = Color(0.52, 0.18, 0.26)
@export var pressed_color: Color = Color(0.24, 0.08, 0.12)


func region_for(state: State) -> Rect2i:
	match state:
		State.HOVER:
			return region_hover
		State.PRESSED:
			return region_pressed
		_:
			return region_normal


func color_for(state: State) -> Color:
	match state:
		State.HOVER:
			return hover_color
		State.PRESSED:
			return pressed_color
		_:
			return normal_color


## StyleBox used by ThreeStateButton for one of its theme states.
func style_for(state: State) -> StyleBox:
	var region: Rect2i = region_for(state)
	if atlas != null and region.size.x > 0 and region.size.y > 0:
		var tile := AtlasTexture.new()
		tile.atlas = atlas
		tile.region = Rect2(float(region.position.x), float(region.position.y), float(region.size.x), float(region.size.y))
		var textured := StyleBoxTexture.new()
		textured.texture = tile
		textured.texture_margin_left = patch_margin
		textured.texture_margin_top = patch_margin
		textured.texture_margin_right = patch_margin
		textured.texture_margin_bottom = patch_margin
		return textured
	var flat := StyleBoxFlat.new()
	flat.bg_color = color_for(state)
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.corner_radius_bottom_right = 6
	flat.corner_radius_bottom_left = 6
	flat.border_width_left = 1
	flat.border_width_top = 1
	flat.border_width_right = 1
	flat.border_width_bottom = 1
	flat.border_color = Color(0.75, 0.55, 0.4, 0.55)
	return flat
