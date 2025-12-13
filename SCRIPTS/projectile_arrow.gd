## res://SCRIPTS/projectile_arrow.gd
extends CharacterBody2D

var target_pos : Vector2
var damage : float
var target_unit = null
var shooter_unit = null

var speed : float = 125.0
var flight_height : float = 0.0
var max_height : float = 20.0
var total_dist : float = 0.0
var start_pos : Vector2

var reached_target : bool = false

@onready var animation_player = $ani
@onready var sprite = $basic/arrow

func setup(t_pos: Vector2, dmg: float, target, shooter):
	target_pos = t_pos
	damage = dmg
	target_unit = target
	shooter_unit = shooter
	start_pos = global_position
	total_dist = start_pos.distance_to(target_pos)
	
	## Höhe basierend auf Distanz (weiter weg = höher)
	max_height = clamp(total_dist * 0.2, 10.0, 50.0)
	
	look_at(target_pos)

func _physics_process(delta):
	if reached_target: return
	
	var current_pos = global_position
	var dist_to_target = current_pos.distance_to(target_pos)
	
	## Bewegung zum Ziel
	var direction = (target_pos - current_pos).normalized()
	velocity = direction * speed
	move_and_slide()
	
	## --- Parabel Simulation (Visuell) ---
	var dist_traveled = start_pos.distance_to(current_pos)
	if total_dist > 0:
		var progress = dist_traveled / total_dist # 0.0 bis 1.0
		
		## Parabel Formel
		flight_height = 4 * max_height * progress * (1.0 - progress)
		sprite.position.y = -flight_height
		
		## Rotation & Tilt
		var tilt = lerp(-45.0, 45.0, progress)
		sprite.rotation_degrees = tilt
		
		## Scale anpassen (Dein gewünschter Look)
		var scale_mod = lerp(0.5, 0.9, progress) 
		if progress < 0.5:
			scale_mod = lerp(0.5, 0.9, progress * 2.0)
		else:
			scale_mod = lerp(0.9, 0.5, (progress - 0.5) * 2.0)
			
		sprite.scale = Vector2(scale_mod, scale_mod)

	## Ziel erreicht? (Sehr nah am Zielpunkt)
	if dist_to_target < 5.0:
		impact()

func impact():
	reached_target = true
	
	## Sprite fixieren
	sprite.position.y = 0
	sprite.rotation_degrees = 45.0 
	
	## Animation
	if animation_player.has_animation("landed"):
		animation_player.play("landed")
		sprite.scale = Vector2(0.5, 0.5)
	
	## Schaden Logik: Nur Schaden, wenn Unit noch am Einschlagort steht!
	if is_instance_valid(target_unit) and not target_unit.is_dead:
		var dist_arrow_to_unit = global_position.distance_to(target_unit.global_position)
		
		## TREFFERZONE: 16 Pixel (ca. 1 Tile Größe)
		if dist_arrow_to_unit <= 16.0: 
			target_unit.take_damage(damage, shooter_unit)
		else:
			print("Pfeil hat verfehlt! Unit ist ausgewichen.")
	
	## Warten und löschen
	await get_tree().create_timer(5.0).timeout
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()
