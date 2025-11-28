extends CharacterBody2D

@export_group("Movement")
@export var move_speed : float = 150.0
@export var acceleration : float = 600.0
@export var friction : float = 500.0

@export_group("References")
@export var sprite_container : Node2D

var current_velocity := Vector2.ZERO
var target_position : Vector2
var is_moving := false

## Animation
@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit

func _ready():
	## Falls sprite_container nicht manuell gesetzt wurde, nutze das "unit" Node
	if sprite_container == null:
		sprite_container = unit_node
	
	target_position = global_position

func _physics_process(delta: float):
	update_movement(delta)
	update_animation()
	update_sprite_direction()

func update_movement(delta: float):
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target > 5.0:
		## Richtung zum Ziel berechnen
		var direction = (target_position - global_position).normalized()
		
		## Beschleunigung anwenden
		current_velocity = current_velocity.move_toward(direction * move_speed, acceleration * delta)
		is_moving = true
	else:
		## Am Ziel angekommen -> Abbremsen
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
		is_moving = false
	
	velocity = current_velocity
	move_and_slide()

func update_animation():
	if is_moving:
		animation_player.play("walk")
	else:
		animation_player.play("idle")

func update_sprite_direction():
	## Basierend auf Bewegungsrichtung: Links (scale.x = -1) oder Rechts (scale.x = 1)
	if current_velocity.x != 0:
		sprite_container.scale.x = -1.0 if current_velocity.x < 0 else 1.0

## Wird vom GameHandler aufgerufen, wenn der Spieler einen Befehl gibt
func set_target(new_target: Vector2):
	target_position = new_target

func get_world_position() -> Vector2:
	return global_position

func is_idle() -> bool:
	return not is_moving
