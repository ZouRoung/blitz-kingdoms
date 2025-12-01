## res://SCRIPTS/UNITS/unit_base.gd
extends CharacterBody2D
class_name UnitBase

@export_group("Unit Stats")
@export var unit_name : String = "Unit"
@export var max_health : float = 100.0
@export var health_growth : float = 20.0 ## HP pro Level
@export var xp_to_next_level : int = 100
@export var xp_growth_factor : float = 1.5 ## Wie viel schwerer wird das nächste Level?

@export_group("Movement")
@export var move_speed : float = 25.0
@export var acceleration : float = 400.0
@export var friction : float = 600.0
@export var stop_distance : float = 2.0

@export_group("References")
@export var sprite_container : Node2D
@export var portrait_texture : Texture2D ## Hier das Portrait im Editor zuweisen!

## --- Runtime Vars ---
var current_health : float
var current_xp : int = 0
var current_level : int = 1
var current_velocity := Vector2.ZERO
var target_position : Vector2
var is_moving := false

@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit

signal stats_changed(unit) ## Signal an UI wenn sich was ändert

func _ready():
	current_health = max_health
	target_position = global_position
	if sprite_container == null:
		sprite_container = unit_node

func _physics_process(delta: float):
	update_movement(delta)
	update_animation()
	update_sprite_direction()

func update_movement(delta: float):
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target <= stop_distance:
		current_velocity = Vector2.ZERO
		is_moving = false
		target_position = global_position
	else:
		var direction = (target_position - global_position).normalized()
		current_velocity = current_velocity.move_toward(direction * move_speed, acceleration * delta)
		is_moving = true
	
	velocity = current_velocity
	move_and_slide()

## --- LEVEL SYSTEM ---
func add_xp(amount: int):
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()
	stats_changed.emit(self)

func level_up():
	current_xp -= xp_to_next_level
	current_level += 1
	
	## Stats erhöhen
	max_health += health_growth
	current_health = max_health ## Heilung beim Level Up? Oder nur max erhöhen: current_health += health_growth
	
	## Nächstes Level schwerer machen
	xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
	print(unit_name, " Level Up! New Level:", current_level, " MaxHP:", max_health)

## --- MOVEMENT & ANIMATION (Override in Child classes if needed) ---
func update_animation():
	if is_moving:
		animation_player.play("walk")
	else:
		animation_player.play("idle")

func update_sprite_direction():
	if current_velocity.x != 0:
		unit_node.scale.x = -abs(unit_node.scale.x) if current_velocity.x < 0 else abs(unit_node.scale.x)

func set_target(new_target: Vector2):
	target_position = new_target

func get_world_position() -> Vector2:
	return global_position
