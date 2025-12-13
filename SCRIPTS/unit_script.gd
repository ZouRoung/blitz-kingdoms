## res://SCRIPTS/UNITS/unit_base.gd
extends CharacterBody2D
class_name UnitBase

@export_group("Identity")
@export var unit_name : String = "Unit"
## 0 = Spieler, 1 = Gegner Team 1, etc.
@export var team_id : int = 0 

@export_group("Unit Stats")
@export var max_health : float = 100.0 
@export var health_growth : float = 20.0 
@export var xp_to_next_level : int = 100
@export var xp_growth_factor : float = 1.5

var unit_amount : int = 1

@export_group("Combat")
@export var unit_type_range = false
## Drag & Drop hier die projectile_arrow.tscn rein (nur wichtig für Archer)
@export var projectile_scene : PackedScene 

## Mindest-Reichweite für Archer (schießt nicht, wenn Gegner näher als das ist)
@export var min_attack_range : float = 50.0

## Cooldown für Fernkämpfer
@export var attack_cooldown : float = 2.0
## Schaden pro 1 Unit (0.1 bedeutet: 10 Units machen 1 Schaden)
@export var damage_per_unit : float = 0.1
## Reichweite um Kampf zu STARTEN
@export var attack_range : float = 16.0
## Reichweite um noch ZUSCHLAGEN zu dürfen
@export var infight_attack_range : float = 19.0
## Ab dieser Distanz ist der Kampf wirklich vorbei (wenn man FLIEHT)
@export var disengage_radius : float = 30.0
## Normale Geschwindigkeit im Kampf (0.5 = 50%)
@export var combat_speed_penalty : float = 0.5
## Starke Verlangsamung für den Angreifer in den ersten Sekunden
@export var heavy_combat_speed_penalty : float = 0.25
## Zeit bis die Leiche verschwindet (in Sekunden)
@export var corpse_decay_time : float = 60.0

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
@export var farm_range : float = 6.0 

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
var is_dead : bool = false

## INVENTAR
var inventory = { "wood": 0, "stone": 0, "iron": 0, "gold": 0, "food": 0 }

## FARMING & ACTION STATE
var target_resource_node = null 
var farm_target_global_position : Vector2 = Vector2.ZERO
var target_pickup_node = null 
var farm_timer : float = 0.0
var is_farming : bool = false
var is_delivering_resources : bool = false

## COMBAT STATE MACHINES
var combat_target : UnitBase = null
var is_engaged : bool = false
## is_chasing: Wollen wir den Gegner aktiv verfolgen? (False = Flucht oder manuelle Bewegung)
var is_chasing : bool = false
var has_turn : bool = false
var is_attacking_now : bool = false
var is_aggressor : bool = false
var combat_time : float = 0.0
## Timer für Fernkampf-Cooldown
var current_attack_cooldown : float = 0.0 

@onready var animation_player : AnimationPlayer = $ani
@onready var unit_node : Node2D = $unit
@onready var collision_shape : CollisionShape2D = $CollisionShape2D 

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
	
	var gh = get_tree().current_scene.find_child("gameHandler", true, false)
	if gh and gh.has_method("_on_unit_arrived_at_pickup"):
		if not arrived_at_pickup.is_connected(gh._on_unit_arrived_at_pickup):
			arrived_at_pickup.connect(gh._on_unit_arrived_at_pickup)
	
	await get_tree().process_frame
	if not is_dead:
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
	if is_dead: return 

	## Kampfzeit hochzählen wenn engagiert
	if is_engaged:
		combat_time += delta
	else:
		combat_time = 0.0
		
	## Cooldown für Archer runterzählen
	if current_attack_cooldown > 0:
		current_attack_cooldown -= delta

	## Priorität 1: Kampf-Management (Radius, Engagement)
	_process_combat_logic(delta)
	
	## Priorität 2: Bewegung (nur wenn nicht gerade geschlagen wird)
	if not is_attacking_now:
		update_movement(delta)
		
	update_farming(delta)
	update_animation()
	update_sprite_direction()

## --- KAMPFSYSTEM (Old Logic + New Archer Features) ---

func command_attack(target_unit: UnitBase):
	if target_unit == self or target_unit.team_id == team_id:
		return 
	
	## FIX: Wenn wir DIESE Unit bereits angreifen, nichts resetten!
	if combat_target == target_unit:
		is_chasing = true 
		return 

	## Reset Logic
	stop_farming()
	is_delivering_resources = false
	target_pickup_node = null
	
	combat_target = target_unit
	is_chasing = true ## Wir wollen verfolgen
	
	## Engagement resetten (wir sind ja erst auf dem Weg)
	is_engaged = false 
	
	## Wir sind der Angreifer (Aggressor)
	is_aggressor = true
	combat_time = 0.0
	
	## Als Angreifer starten wir den Turn
	is_attacking_now = false
	
	## Spezial Archer Reset
	if unit_type_range:
		has_turn = true
		current_attack_cooldown = 0.0
	else:
		has_turn = true

func _process_combat_logic(delta: float):
	if combat_target == null or combat_target.is_dead:
		exit_combat_state()
		return

	var dist = global_position.distance_to(combat_target.global_position)
	
	## --- LOGIK TRENNUNG: FLUCHT vs VERFOLGUNG ---
	
	## FALL A: Wir wollen FLIEHEN (is_chasing = false)
	## Hier gilt der kleine disengage_radius. Wenn wir draußen sind -> Abbruch.
	if not is_chasing:
		if dist > disengage_radius:
			exit_combat_state()
			return
			
	## FALL B: Wir wollen JAGEN (is_chasing = true)
	else:
		if not unit_type_range:
			## Warrior Break Condition
			if dist >= disengage_radius and is_engaged:
				exit_combat_state()
				return
		else:
			## Archer Break Condition (Darf größer sein)
			if dist >= attack_range * 2.0 and is_engaged:
				exit_combat_state()
				return

	## --- ENGAGEMENT MANAGEMENT ---
	
	## Wenn wir nah dran sind -> Engaged (Langsam)
	if dist <= attack_range:
		if not is_engaged:
			is_engaged = true
			
	## Wenn der Gegner wegrennt und wir etwas Abstand haben -> Nicht mehr Engaged (Schnell hinterher)
	## Warrior Logic (Old State: attack_range * 2.0)
	if dist > attack_range * 2.0:
		is_engaged = false
			
	## --- ANGRIFFS LOGIK ---
	## WICHTIG: Wir greifen nur an, wenn is_chasing == true ist!
	## Das garantiert, dass wir beim Fliehen (is_chasing = false) nicht stehen bleiben um zu schlagen.
	
	if is_engaged and is_chasing and not is_attacking_now:
		
		if unit_type_range:
			## ARCHER LOGIK
			if current_attack_cooldown <= 0:
				if dist > min_attack_range:
					start_attack_sequence()
				else:
					pass ## Zu nah für Bogen
		else:
			## WARRIOR LOGIK
			if has_turn and dist <= infight_attack_range:
				start_attack_sequence()

func start_attack_sequence():
	if combat_target == null: return
	
	is_attacking_now = true
	is_moving = false
	
	## --- FERNKAMPF ABLAUF ---
	if unit_type_range:
		## 1. Animation
		if animation_player.has_animation("attack"):
			animation_player.play("attack")
			
		## 2. Timing
		await get_tree().create_timer(0.4).timeout 
		
		## Check vor Spawn
		if not is_dead and combat_target != null:
			spawn_projectile()
		
		## 3. Cooldown
		current_attack_cooldown = attack_cooldown
		
		## 4. Ende
		await get_tree().create_timer(0.2).timeout
		is_attacking_now = false
		
	## --- NAHKAMPF ABLAUF ---
	else:
		## 1. Animation starten
		if animation_player.has_animation("attack"):
			animation_player.play("attack")
		
		## 2. Timing simulieren
		await get_tree().create_timer(0.25).timeout
		
		if is_dead or combat_target == null or combat_target.is_dead:
			is_attacking_now = false
			return
			
		## 3. Schaden austeilen (Prüfen ob noch in Hit Range)
		var dist = global_position.distance_to(combat_target.global_position)
		if dist <= infight_attack_range + 4.0: 
			var damage = float(unit_amount) * damage_per_unit
			combat_target.take_damage(damage, self)
		
		## 4. Turn abgeben
		has_turn = false
		
		## 5. Cooldown / Erholung
		await get_tree().create_timer(0.5).timeout
		is_attacking_now = false

func spawn_projectile():
	if projectile_scene == null:
		print("FEHLER: Keine Projectile Scene im Inspector zugewiesen!")
		return
	if combat_target == null: return
		
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position + Vector2(0, -10)
	
	var damage = float(unit_amount) * damage_per_unit
	var t_pos = combat_target.global_position
	
	if proj.has_method("setup"):
		proj.setup(t_pos, damage, combat_target, self)
		
	get_parent().add_child(proj)

func take_damage(amount: float, attacker: UnitBase):
	if is_dead: return
	
	current_health -= amount
	if current_health < 0: current_health = 0
	stats_changed.emit(self)
	
	## FIX: Warrior wird nicht engaged/chased wenn von Range getroffen
	var hit_by_ranged = attacker.unit_type_range
	
	if not hit_by_ranged:
		is_engaged = true
	
	## Der Verteidiger ist NICHT der Aggressor
	if combat_target == null:
		is_aggressor = false 
	
	## Visuelles Feedback
	var sprite = get_node("unit")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
	if animation_player.has_animation("hurt") and animation_player.current_animation != "attack":
		animation_player.play("hurt")

	## RHYTHMUS & RETALIATION
	if not is_dead:
		## Kleine Verzögerung bevor wir zurückschlagen
		await get_tree().create_timer(0.5).timeout
		has_turn = true
		
		## Auto-Retaliation
		if combat_target == null or combat_target != attacker:
			if hit_by_ranged:
				## Wenn Archer schießt -> Wir ignorieren es (kein Auto-Chase)
				pass
			else:
				## Wenn Warrior schlägt -> Wir drehen uns um und kämpfen
				combat_target = attacker
				is_chasing = true 
	
	if current_health <= 0:
		die()

func die():
	is_dead = true
	exit_combat_state()
	is_moving = false
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	var loot = clear_inventory()
	var gh = get_tree().current_scene.find_child("gameHandler", true, false)
	if gh:
		for type in loot:
			if loot[type] > 0:
				gh.spawn_item_drop(type, loot[type], global_position)
	
	if animation_player.has_animation("dead"):
		animation_player.play("dead")
	
	print(unit_name, " ist gestorben.")
	
	await get_tree().create_timer(corpse_decay_time).timeout
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func exit_combat_state():
	is_engaged = false
	combat_target = null
	is_chasing = false
	is_attacking_now = false
	has_turn = false
	is_aggressor = false ## Reset Aggressor
	combat_time = 0.0
	current_attack_cooldown = 0.0
	
	if not is_moving: 
		target_position = global_position

## --- MOVEMENT & SPEED ---

func get_current_speed() -> float:
	var speed = base_move_speed
	var troops_factor = 1.0 - (float(unit_amount) / 100.0 * speed_penalty_per_100_troops)
	
	var total_resources = 0
	for key in inventory:
		total_resources += inventory[key]
	var load_factor = 1.0 - (float(total_resources) / 100.0 * speed_penalty_per_100_resource)
	
	var final_factor = troops_factor * load_factor
	
	## KAMPF GESCHWINDIGKEIT
	if is_engaged:
		var penalty_active = true
		
		## SPEZIALREGEL: Wenn ich vom Archer angegriffen werde (und nicht selbst Aggressor bin)
		if not is_aggressor and combat_target != null and combat_target.unit_type_range:
			penalty_active = false
		
		if penalty_active:
			var slow_duration = 10.0
			if unit_type_range: slow_duration = 5.0
			
			if is_aggressor and combat_time < slow_duration:
				final_factor *= heavy_combat_speed_penalty 
			else:
				final_factor *= combat_speed_penalty 
		
	final_factor = max(min_speed_factor, final_factor)
	return speed * final_factor

func update_movement(delta: float):
	var effective_target = target_position
	
	## Verfolgungs-Logik:
	if is_chasing and combat_target != null and not combat_target.is_dead:
		effective_target = combat_target.global_position

	var distance_to_target = global_position.distance_to(effective_target)
	var desired_velocity = Vector2.ZERO
	var current_speed = get_current_speed()
	
	## Stop Distance
	var current_stop_dist = stop_distance
	## Wenn wir jagen, müssen wir nah ran
	if is_chasing and combat_target != null:
		if unit_type_range:
			current_stop_dist = attack_range * 0.8
		else:
			current_stop_dist = attack_range - 2.0 
	
	if distance_to_target > current_stop_dist:
		var direction = (effective_target - global_position).normalized()
		desired_velocity = direction * current_speed
		is_moving = true
		
		if is_farming: is_farming = false
	else:
		is_moving = false
		desired_velocity = Vector2.ZERO
		
		## Angekommen
		if not is_chasing: 
			target_position = global_position
		
		if target_resource_node != null and not is_farming and not is_engaged:
			start_farming()
			
		if is_delivering_resources:
			is_delivering_resources = false
			arrived_at_base.emit(self)
			
		if target_pickup_node != null:
			if is_instance_valid(target_pickup_node):
				arrived_at_pickup.emit(self, target_pickup_node)
			target_pickup_node = null
	
	var separation = get_separation_vector()
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
		if neighbor.is_dead: continue 
		
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

func set_target(new_target: Vector2):
	target_position = new_target
	
	is_farming = false
	if target_resource_node != null:
		if target_resource_node.current_farmer == self:
			target_resource_node.current_farmer = null
		target_resource_node = null
	
	is_delivering_resources = false
	target_pickup_node = null 
	
	## Manuelles Bewegen -> Verfolgung stoppen (Flucht)
	if is_chasing or is_engaged:
		exit_combat_state() ## Dies setzt is_chasing auf false und engaged auf false
	
	is_chasing = false 
	is_moving = true 

func set_farm_target(res_data):
	target_resource_node = res_data
	target_pickup_node = null 
	farm_target_global_position = target_position
	exit_combat_state() 

func set_pickup_target(item_node):
	target_pickup_node = item_node
	target_resource_node = null 
	stop_farming() 
	exit_combat_state() 
	is_farming = false
	is_delivering_resources = false

func start_farming():
	if target_resource_node == null: return
	
	if target_resource_node.current_farmer != null and target_resource_node.current_farmer != self:
		if is_instance_valid(target_resource_node.current_farmer):
			var old_farmer = target_resource_node.current_farmer
			if old_farmer.has_method("stop_farming"):
				old_farmer.stop_farming()
			old_farmer.target_resource_node = null
	
	target_resource_node.current_farmer = self
	is_farming = true
	farm_timer = 0.0

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

	if global_position.distance_to(farm_target_global_position) > farm_range:
		stop_farming()
		target_resource_node = null 
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
		
	if global_position.distance_to(farm_target_global_position) > farm_range:
		stop_farming()
		target_resource_node = null
		return
		
	var amount_to_take = min(farm_amount, target_resource_node.current_supply)
	target_resource_node.current_supply -= amount_to_take
	
	if target_resource_node.current_supply <= 0:
		var world_gen = get_tree().current_scene.find_child("worldGen", true, false)
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
	
	var gh = get_tree().current_scene.find_child("gameHandler", true, false)
	if gh:
		gh.spawn_item_drop(type, amount, global_position) 
	
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

func update_animation():
	if is_dead:
		if animation_player.current_animation != "dead":
			animation_player.play("dead")
		return

	if is_attacking_now: return 

	if animation_player.current_animation == "hurt" and animation_player.is_playing():
		return 

	if is_moving:
		animation_player.play("walk")
	else:
		if is_farming:
			if animation_player.has_animation("farming"):
				animation_player.play("farming")
			else:
				animation_player.play("idle")
		elif is_engaged:
			animation_player.play("idle")
		else:
			animation_player.play("idle")

func update_sprite_direction():
	if is_dead: return
	
	if is_engaged and combat_target != null:
		var dir_x = combat_target.global_position.x - global_position.x
		if abs(dir_x) > 1.0:
			unit_node.scale.x = -abs(unit_node.scale.x) if dir_x < 0 else abs(unit_node.scale.x)
	elif abs(current_velocity.x) > 1.0:
		unit_node.scale.x = -abs(unit_node.scale.x) if current_velocity.x < 0 else abs(unit_node.scale.x)

func get_world_position() -> Vector2:
	return global_position
