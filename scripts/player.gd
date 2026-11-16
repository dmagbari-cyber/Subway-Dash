extends CharacterBody2D

## Small keyboard-controlled platformer starter character.
@export var move_speed: float = 320.0
@export var jump_velocity: float = -520.0

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * move_speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	move_and_slide()
