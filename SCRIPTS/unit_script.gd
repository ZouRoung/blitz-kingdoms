## res://SCRIPTS/UNITS/unit_base.gd
extends CharacterBody2D
class_name UnitBase

@export_group("Unit Stats")
@export var unit_name : String = "Unit"
@export var max_health : float = 100.0 
@export var health_growth : float = 20.0 
@export var xp_to_next_level : int = 100
@export var xp_growth_factor : float = 1.5

var unit_amount : int = 1

@export_group("Movement")
@export var base_move_speed : float = 25.0 
@export var acceleration : float = 400.0
@export var friction : float = 600.0
@export var stop_distance : float = 2.0

## Geschwindigkeits-Faktoren
@export var speed_penalty_per_100_troops : float = 0.05 
@export var speed_penalty_per_100_resource : float = 0.1 
@export var min_speed_factor : float = 0.2 

@export_group("Farming")
@export var farm_interval : float = 5.0 
@export var base_farm_amount : int = 10 
var farm_amount : int = 10 
## HIER: Radius auf 10.0 verkleinert
@export var farm_range : float = 10.0 

@export_group("Separation")
@export var separation_radius : float = 6.0 
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

## INVENTAR
var inventory = { "wood": 0, "stone": 0, "iron": 0, "gold": 0, "food": 0 }

## FARMING & ACTION STATE
var target_resource_node = null 
var farm_target_global_position : Vector2 = Vector2.ZERO
var target_pickup_node = null 
var farm_timer : float = 0.0
var is_farming : bool = false
var is_delivering_resources : bool = false

@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit

signal stats_changed(unit) 
signal inventory_changed(unit)
signal arrived_at_base(unit)
signal arrived_at_pickup(unit, item) 

func _ready():
	if current_health == 0:
		setup_stats()
		
	if sprite_container == null:
		sprite_container = unit_node
	
	var random_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	global_position += random_offset
	target_position = global_position
	
	var gh = get_parent().get_parent().get_node("gameHandler")
	if gh and gh.has_method("_on_unit_arrived_at_pickup"):
		arrived_at_pickup.connect(gh._on_unit_arrived_at_pickup)
	
	await get_tree().process_frame
	update_movement(0.016) 

func init_amount(amount: int):
	unit_amount = amount
	setup_stats()
	update_farm_amount()

func setup_stats():
	max_health = float(unit_amount) 
	current_health = max_health
	stats_changed.emit(self)
	update_farm_amount()

func update_farm_amount():
	farm_amount = base_farm_amount + (unit_amount * 2)

func _physics_process(delta: float):
	update_movement(delta)
	update_farming(delta)
	update_animation()
	update_sprite_direction()

func get_current_speed() -> float:
	var speed = base_move_speed
	var troops_factor = 1.0 - (float(unit_amount) / 100.0 * speed_penalty_per_100_troops)
	var total_resources = 0
	for key in inventory:
		total_resources += inventory[key]
	var load_factor = 1.0 - (float(total_resources) / 100.0 * speed_penalty_per_100_resource)
	var final_factor = max(min_speed_factor, troops_factor * load_factor)
	return speed * final_factor

func update_movement(delta: float):
	var distance_to_target = global_position.distance_to(target_position)
	var desired_velocity = Vector2.ZERO
	var current_speed = get_current_speed()
	
	if distance_to_target > stop_distance:
		var direction = (target_position - global_position).normalized()
		desired_velocity = direction * current_speed
		is_moving = true
		
		## Wenn wir farmen aber uns bewegen müssen (weil geschubst oder noch nicht da):
		## Pausieren wir nur. Der harte Abbruch passiert in update_farming.
		if is_farming:
			is_farming = false
	else:
		## ANGEKOMMEN
		is_moving = false
		desired_velocity = Vector2.ZERO
		target_position = global_position 
		
		if target_resource_node != null and not is_farming:
			start_farming()
			
		if is_delivering_resources:
			is_delivering_resources = false
			arrived_at_base.emit(self)
			
		if target_pickup_node != null:
			if is_instance_valid(target_pickup_node):
				arrived_at_pickup.emit(self, target_pickup_node)
			target_pickup_node = null
	
	var separation = get_separation_vector()
	## Separation ist immer aktiv!
	if is_moving: desired_velocity += separation
	else: desired_velocity = separation
	
	if desired_velocity != Vector2.ZERO: current_velocity = current_velocity.move_toward(desired_velocity, acceleration * delta)
	else: current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	velocity = current_velocity
	move_and_slide()

func get_separation_vector() -> Vector2:
	var separation_vector = Vector2.ZERO
	var neighbor_count = 0
	var parent = get_parent()
	if parent == null: return Vector2.ZERO
	
	for neighbor in parent.get_children():
		if neighbor == self or not neighbor is UnitBase: continue
		
		## HIER GEÄNDERT: Wir ignorieren niemanden mehr. 
		## Auch wenn jemand farmt, wird er weggeschoben, wenn es zu eng ist.
		
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

func set_farm_target(res_data):
	target_resource_node = res_data
	target_pickup_node = null 
	farm_target_global_position = target_position

func set_pickup_target(item_node):
	target_pickup_node = item_node
	target_resource_node = null 
	stop_farming() 
	is_farming = false
	is_delivering_resources = false

func start_farming():
	if target_resource_node == null: return
	
	## EXKLUSIVES FARMEN: Prüfen, ob jemand anderes farmt
	if target_resource_node.current_farmer != null and target_resource_node.current_farmer != self:
		if is_instance_valid(target_resource_node.current_farmer):
			var old_farmer = target_resource_node.current_farmer
			
			## Alten Farmer stoppen
			if old_farmer.has_method("stop_farming"):
				old_farmer.stop_farming()
			
			## WICHTIG: Wir nutzen die Variable 'old_farmer'
			old_farmer.target_resource_node = null
	
	## Uns eintragen
	target_resource_node.current_farmer = self
	
	is_farming = true
	farm_timer = 0.0
	print(unit_name, " startet Farming an ", target_resource_node.resource_type)

func stop_farming():
	is_farming = false
	farm_timer = 0.0
	
	if target_resource_node != null:
		if target_resource_node.current_farmer == self:
			target_resource_node.current_farmer = null

func update_farming(delta):
	if not is_farming or target_resource_node == null: return
	
	if target_resource_node.current_farmer != self:
		is_farming = false
		target_resource_node = null 
		return

	## DISTANZ CHECK: Wenn wir > farm_range (10.0) entfernt sind -> ABBRUCH!
	if global_position.distance_to(farm_target_global_position) > farm_range:
		print(unit_name, " wurde weggeschoben. Farming gestoppt.")
		stop_farming()
		target_resource_node = null ## Ziel vergessen!
		return

	farm_timer += delta
	if farm_timer >= farm_interval:
		farm_timer = 0.0
		perform_farm_tick()

func perform_farm_tick():
	if target_resource_node == null or target_resource_node.current_supply <= 0:
		target_resource_node = null
		stop_farming()
		return
	
	## Sicherheitscheck Distanz auch hier nochmal
	if global_position.distance_to(farm_target_global_position) > farm_range:
		stop_farming()
		target_resource_node = null
		return
		
	var amount_to_take = min(farm_amount, target_resource_node.current_supply)
	target_resource_node.current_supply -= amount_to_take
	
	if target_resource_node.current_supply <= 0:
		var world_gen = get_parent().get_parent().get_node("worldGen")
		if world_gen and world_gen.has_method("on_resource_depleted"):
			world_gen.on_resource_depleted(target_resource_node)
		
		target_resource_node = null
		stop_farming()
		return
		
	var res_type = target_resource_node.resource_type
	var inv_key = res_type
	if res_type == "tree": inv_key = "wood"
	if res_type == "berry": inv_key = "food"
	
	if inventory.has(inv_key):
		inventory[inv_key] += amount_to_take
		inventory_changed.emit(self)

func drop_resource(type: String):
	if not inventory.has(type) or inventory[type] <= 0:
		return
	var amount = inventory[type]
	inventory[type] = 0
	inventory_changed.emit(self)
	get_parent().get_parent().get_node("gameHandler").spawn_item_drop(type, amount, global_position) 
	
func add_resource_from_drop(type: String, amount: int):
	if inventory.has(type):
		inventory[type] += amount
		inventory_changed.emit(self)

func clear_inventory() -> Dictionary:
	var dropped = inventory.duplicate()
	for k in inventory:
		inventory[k] = 0
	inventory_changed.emit(self)
	return dropped

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
	
	## Wenn manuell: Alles stoppen und vergessen
	is_farming = false
	if target_resource_node != null:
		if target_resource_node.current_farmer == self:
			target_resource_node.current_farmer = null
		target_resource_node = null
	
	is_delivering_resources = false
	target_pickup_node = null 
	is_moving = true 

func get_world_position() -> Vector2:
	return global_position
