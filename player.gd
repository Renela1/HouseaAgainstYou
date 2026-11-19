extends CharacterBody2D
## Walk/idle character driven by WASD or the arrow keys. The Camera child follows
## it; world bounds belong to the level, not to this script.

@export var speed: float = 320.0

@onready var sprite: AnimatedSprite2D = $Sprite


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_animate(direction)


func _animate(direction: Vector2) -> void:
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0
	var wanted := "walk" if direction != Vector2.ZERO else "idle"
	if sprite.animation != wanted:
		sprite.play(wanted)
