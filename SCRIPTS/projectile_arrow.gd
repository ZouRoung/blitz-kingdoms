## res://SCRIPTS/projectile_arrow.gd
extends CharacterBody2D

var target_pos : Vector2
var damage : float
var target_unit = null
var shooter_unit = null

var speed : float = 300.0
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
	## Wir berechnen, wie viel % der Strecke wir zurückgelegt haben
	var dist_traveled = start_pos.distance_to(current_pos)
	if total_dist > 0:
		var progress = dist_traveled / total_dist # 0.0 bis 1.0
		
		## Parabel Formel: 4 * h * x * (1-x)
		flight_height = 4 * max_height * progress * (1.0 - progress)
		
		## Sprite Offset anpassen (Y nach oben ist negativ)
		sprite.position.y = -flight_height
		
		## Rotation anpassen (hoch am Anfang, runter am Ende)
		## Wir addieren zur Basis-Rotation (zum Ziel) eine Neigung
		var tilt = lerp(-45.0, 45.0, progress)
		sprite.rotation_degrees = tilt
		
		## Scale anpassen (kleiner wenn oben, wirkt wie Entfernung)
		var scale_mod = lerp(1.0, 1.5, progress) # Wird größer wenn es nah kommt
		if progress < 0.5:
			scale_mod = lerp(1.0, 0.8, progress * 2.0) # Kleiner beim Aufstieg
		else:
			scale_mod = lerp(0.8, 1.0, (progress - 0.5) * 2.0) # Normal beim Abstieg
			
		sprite.scale = Vector2(scale_mod, scale_mod)

	## Ziel erreicht?
	if dist_to_target < 5.0:
		impact()

func impact():
	reached_target = true
	
	## Sprite Rotation auf "Einschlag" fixieren (nach unten)
	sprite.position.y = 0
	sprite.rotation_degrees = 45.0 
	
	## Animation
	if animation_player.has_animation("landed"):
		animation_player.play("landed")
	
	## Schaden an Unit (nur wenn sie noch da ist)
	if is_instance_valid(target_unit) and not target_unit.is_dead:
		## Prüfen ob Unit ausgewichen ist (zu weit weg vom Einschlag)
		var dist = global_position.distance_to(target_unit.global_position)
		if dist <= 16.0: ## Trefferzone
			target_unit.take_damage(damage, shooter_unit)
		else:
			print("Pfeil hat verfehlt!")
	
	## Warten und löschen
	await get_tree().create_timer(5.0).timeout ## Pfeil bleibt stecken
	
	## Ausfaden
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()
