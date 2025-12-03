## res://SCRIPTS/UNITS/unit_script.gd
extends CharacterBody2D
class_name UnitBase

@export_group("Unit Stats")
@export var unit_name : String = "Unit"
@export var max_health : float = 100.0 ## Dies wird nun überschrieben
@export var health_growth : float = 20.0 
@export var xp_to_next_level : int = 100
@export var xp_growth_factor : float = 1.5

## NEU: Truppenanzahl
var unit_amount : int = 1

@export_group("Movement")
@export var move_speed : float = 25.0
@export var acceleration : float = 400.0
@export var friction : float = 600.0
@export var stop_distance : float = 2.0

@export_group("Separation")
@export var separation_radius : float = 12.0 
@export var separation_force : float = 150.0 

@export_group("References")
@export var sprite_container : Node2D
@export var portrait_texture : Texture2D 

## --- Runtime Vars ---
var current_health : float
var current_xp : int = 0
var current_level : int = 1
var current_velocity := Vector2.ZERO
var target_position : Vector2
var is_moving := false

@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit

signal stats_changed(unit) 

func _ready():
	## Falls setup_unit noch nicht von außen aufgerufen wurde (Fallback)
	if current_health == 0:
		setup_stats()
		
	if sprite_container == null:
		sprite_container = unit_node
	
	var random_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	global_position += random_offset
	target_position = global_position
	
	await get_tree().process_frame
	update_movement(0.016) 

## NEU: Wird vom GameHandler nach dem Spawnen aufgerufen
func init_amount(amount: int):
	unit_amount = amount
	setup_stats()

func setup_stats():
	## Berechne HP: 10 Einheiten = 10 Leben -> 1 Einheit = 1 Leben
	max_health = float(unit_amount) 
	current_health = max_health
	
	## Name update (für UI Label, falls wir das später direkt an der Unit haben wollen)
	## Aktuell wird das UI vom GameHandler aktualisiert über stats_changed
	stats_changed.emit(self)

func _physics_process(delta: float):
	update_movement(delta)
	update_animation()
	update_sprite_direction()

func update_movement(delta: float):
	var distance_to_target = global_position.distance_to(target_position)
	var desired_velocity = Vector2.ZERO
	
	if distance_to_target > stop_distance:
		var direction = (target_position - global_position).normalized()
		desired_velocity = direction * move_speed
		is_moving = true
	else:
		is_moving = false
		desired_velocity = Vector2.ZERO
		target_position = global_position
	
	var separation = get_separation_vector()
	
	if is_moving:
		desired_velocity += separation
	else:
		desired_velocity = separation
	
	if desired_velocity != Vector2.ZERO:
		current_velocity = current_velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	velocity = current_velocity
	move_and_slide()

func get_separation_vector() -> Vector2:
	var separation_vector = Vector2.ZERO
	var neighbor_count = 0
	
	var parent = get_parent()
	if parent == null: return Vector2.ZERO
	
	for neighbor in parent.get_children():
		if neighbor == self or not neighbor is UnitBase:
			continue
			
		var dist = global_position.distance_to(neighbor.global_position)
		
		if dist < 0.1:
			dist = 0.1
			var random_push = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			separation_vector += random_push * separation_force
			neighbor_count += 1
			continue

		if dist < separation_radius:
			var push_dir = global_position - neighbor.global_position
			var strength = (separation_radius - dist) / separation_radius
			separation_vector += push_dir.normalized() * strength
			neighbor_count += 1
	
	if neighbor_count > 0:
		separation_vector = separation_vector / neighbor_count
		return separation_vector * separation_force
	
	return Vector2.ZERO

func add_xp(amount: int):
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()
	stats_changed.emit(self)

func level_up():
	current_xp -= xp_to_next_level
	current_level += 1
	max_health += health_growth
	current_health = max_health 
	xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
	print(unit_name, " Level Up! New Level:", current_level, " MaxHP:", max_health)

func update_animation():
	if is_moving:
		animation_player.play("walk")
	else:
		animation_player.play("idle")

func update_sprite_direction():
	if abs(current_velocity.x) > 1.0:
		unit_node.scale.x = -abs(unit_node.scale.x) if current_velocity.x < 0 else abs(unit_node.scale.x)

func set_target(new_target: Vector2):
	target_position = new_target
	is_moving = true 

func get_world_position() -> Vector2:
	return global_position
