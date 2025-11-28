extends CharacterBody2D

@export_group("Movement")
@export var move_speed : float = 25.0
@export var acceleration : float = 400.0
@export var friction : float = 600.0
@export var stop_distance : float = 2.0

@export_group("References")
@export var sprite_container : Node2D

var current_velocity := Vector2.ZERO
var target_position : Vector2
var is_moving := false

@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit

func _ready():
	if sprite_container == null:
		sprite_container = unit_node
	
	target_position = global_position

func _physics_process(delta: float):
	update_movement(delta)
	update_animation()
	update_sprite_direction()

func update_movement(delta: float):
	var distance_to_target = global_position.distance_to(target_position)
	
	## Wenn wir am Ziel sind -> Stoppen und zurücksetzen
	if distance_to_target <= stop_distance:
		current_velocity = Vector2.ZERO
		is_moving = false
		target_position = global_position
	else:
		## Noch nicht am Ziel -> Bewegen
		var direction = (target_position - global_position).normalized()
		current_velocity = current_velocity.move_toward(direction * move_speed, acceleration * delta)
		is_moving = true
	
	velocity = current_velocity
	move_and_slide()

func update_animation():
	if is_moving:
		animation_player.play("walk")
	else:
		animation_player.play("idle")

func update_sprite_direction():
	## Nur X-Scale ändern für Richtung
	if current_velocity.x != 0:
		$unit.scale.x = -2.0 if current_velocity.x < 0 else 2.0

func set_target(new_target: Vector2):
	target_position = new_target

func get_world_position() -> Vector2:
	return global_position

func is_idle() -> bool:
	return not is_moving
