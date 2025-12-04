extends CanvasModulate

@onready var anim_player = $ani
@onready var game_handler = get_parent().get_node("gameHandler") 

func _ready():
	if anim_player:
		anim_player.play("daytime")
		anim_player.pause() 

func _process(delta):
	if game_handler:
		update_day_night_cycle()

func update_day_night_cycle():
	if not anim_player: return
	
	var hours = game_handler.time_hours
	var minutes = game_handler.time_minutes
	
	## Fortschritt in der aktuellen 15-Minuten-Einheit (0.0 bis 1.0)
	var progress_in_quarter = game_handler.time_accumulator / game_handler.REAL_SECONDS_PER_GAME_15MIN
	
	## Umrechnung in Spiel-Minuten (0 bis 15)
	var additional_minutes = progress_in_quarter * 15.0
	
	## Totale Spielzeit in Stunden (als Fliesskommazahl)
	var total_hours = float(hours) + (float(minutes) + additional_minutes) / 60.0
	
	## Animation Seek
	var anim_length = anim_player.current_animation_length
	## Mappen von 0..24 Stunden auf 0..anim_length
	var seek_pos = (total_hours / 24.0) * anim_length
	
	anim_player.seek(seek_pos, true)
