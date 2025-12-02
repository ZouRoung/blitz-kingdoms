extends Camera2D

@export_group("Movement Settings")
@export var move_speed : float = 400.0
@export var edge_margin : int = 20
@export var edge_move_speed : float = 300.0

@export_group("Zoom Settings")
@export var zoom_speed : float = 0.1
@export var max_zoom : float = 4.0

@export_group("Map Boundaries")
@export var map_width : int = 100
@export var map_height : int = 100
@export var tile_size : int = 16

var viewport_size : Vector2
var min_zoom : float = 1.0

## Referenz zum GameHandler um UI-Status zu prüfen
@onready var game_handler = get_node("/root/game/gameHandler") ## PFAD GGF. ANPASSEN!

func _ready():
	viewport_size = get_viewport_rect().size
	calculate_min_zoom()
	zoom = Vector2(1.0, 1.0)
	
	## Fallback falls Pfad falsch ist:
	if game_handler == null:
		## Versuche Suche im Tree
		game_handler = get_tree().current_scene.find_child("gameHandler", true, false)

func _process(delta):
	handle_keyboard_movement(delta)
	handle_edge_scrolling(delta)
	apply_boundaries()

func _input(event):
	if event is InputEventMouseButton:
		handle_zoom(event)

func calculate_min_zoom():
	var map_width_px = map_width * tile_size
	var map_height_px = map_height * tile_size
	var zoom_x = viewport_size.x / map_width_px
	var zoom_y = viewport_size.y / map_height_px
	min_zoom = max(zoom_x, zoom_y)
	min_zoom *= 1.05

func handle_keyboard_movement(delta):
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("left"):
		direction.x -= 1
	if Input.is_action_pressed("down"):
		direction.y += 1
	if Input.is_action_pressed("up"):
		direction.y -= 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * move_speed * delta

func handle_edge_scrolling(delta):
	## FIX: Wenn Maus über UI ist, nicht scrollen!
	if game_handler and game_handler.is_mouse_over_ui:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var direction = Vector2.ZERO
	
	## Check X
	if mouse_pos.x < edge_margin:
		direction.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_margin:
		direction.x += 1
	
	## Check Y
	if mouse_pos.y < edge_margin:
		direction.y -= 1
	elif mouse_pos.y > viewport_size.y - edge_margin:
		direction.y += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * edge_move_speed * delta

func handle_zoom(event):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_in()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_out()

func zoom_in():
	var new_zoom = zoom + Vector2(zoom_speed, zoom_speed)
	zoom = new_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	apply_boundaries()

func zoom_out():
	var new_zoom = zoom - Vector2(zoom_speed, zoom_speed)
	zoom = new_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	apply_boundaries()

func apply_boundaries():
	var map_width_px = map_width * tile_size
	var map_height_px = map_height * tile_size
	var viewport_half = (viewport_size / zoom) * 0.5
	position.x = clamp(position.x, viewport_half.x, map_width_px - viewport_half.x)
	position.y = clamp(position.y, viewport_half.y, map_height_px - viewport_half.y)
